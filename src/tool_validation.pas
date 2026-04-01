{
  Tool Validation - Validates tool inputs and provides pre/post execution hooks.
  - Input validation with required fields
  - Pre-tool hooks for permissions and checks
  - Post-tool hooks for logging and statistics
}
unit tool_validation;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  { Validation result }
  TValidationResult = record
    Valid: Boolean;
    ErrorMessage: string;
    ErrorCode: string;
  end;

  { Tool statistics }
  TToolStats = record
    ToolName: string;
    ExecCount: Int64;
    SuccessCount: Int64;
    FailureCount: Int64;
    TotalExecutionTime: Int64;
    LastExecutionTime: Int64;
    LastSuccess: Boolean;
  end;
  TToolStatsArray = array of TToolStats;

var
  GToolStats: TToolStatsArray;
  GTotalToolCalls: Int64 = 0;
  GTotalExecutionTime: Int64 = 0;

{ Validate tool input JSON }
function ValidateToolInput(const ToolName: string; const InputJSON: string): TValidationResult;

{ Validate required fields in JSON }
function ValidateRequiredFields(const InputJSON: string; const RequiredFields: array of string): TValidationResult;

{ Validate JSON structure }
function ValidateJSONStructure(const JSON: string): TValidationResult;

{ Pre-execution hook - called before tool runs }
function PreToolHook(const ToolName: string; const InputJSON: string): TValidationResult;

{ Post-execution hook - called after tool runs }
procedure PostToolHook(const ToolName: string; const InputJSON: string; const Result: TToolExecutionResult; const ExecutionTime: Int64);

{ Get tool statistics }
function GetToolStats(const ToolName: string): TToolStats;

{ Get all tool statistics }
function GetAllToolStats(): TToolStatsArray;

{ Reset tool statistics }
procedure ResetToolStats();

implementation

uses tool_permissions;

{ Helper: Extract JSON string value - local implementation }
function ExtractJSONValue(const JSON, Key: string): string;
var
  KeyPos, ValueStart, ValueEnd: Integer;
  InString: Boolean;
begin
  Result := '';
  KeyPos := Pos('"' + Key + '":', JSON);
  if KeyPos = 0 then Exit;
  
  { Find colon: skip past both quotes of the key, then find the colon }
  ValueStart := KeyPos + Length(Key) + 2;
  while ValueStart <= Length(JSON) do
  begin
    if JSON[ValueStart] = ':' then
    begin
      Inc(ValueStart);
      while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
        Inc(ValueStart);
      Break;
    end;
    Inc(ValueStart);
  end;
  
  if ValueStart > Length(JSON) then Exit;
  
  if JSON[ValueStart] = '"' then
  begin
    Inc(ValueStart);
    ValueEnd := ValueStart;
    InString := True;
    while (ValueEnd <= Length(JSON)) and InString do
    begin
      if JSON[ValueEnd] = '\' then
        Inc(ValueEnd, 2)
      else if JSON[ValueEnd] = '"' then
        InString := False
      else
        Inc(ValueEnd);
    end;
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end
  else
  begin
    ValueEnd := ValueStart;
    while (ValueEnd <= Length(JSON)) and not (JSON[ValueEnd] in [',', '}', ']']) do
      Inc(ValueEnd);
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end;
end;

{ Validate JSON structure }
function ValidateJSONStructure(const JSON: string): TValidationResult;
begin
  Result.Valid := False;
  Result.ErrorMessage := '';
  Result.ErrorCode := '';
  
  if JSON = '' then
  begin
    Result.Valid := False;
    Result.ErrorMessage := 'Input JSON is empty';
    Result.ErrorCode := 'EMPTY_INPUT';
    Exit;
  end;
  
  if (JSON[1] <> '{') and (JSON[1] <> '[') then
  begin
    Result.Valid := False;
    Result.ErrorMessage := 'Invalid JSON structure - must start with { or [';
    Result.ErrorCode := 'INVALID_JSON';
    Exit;
  end;
  
  Result.Valid := True;
end;

{ Validate required fields in JSON }
function ValidateRequiredFields(const InputJSON: string; const RequiredFields: array of string): TValidationResult;
var
  WorkJSON, FieldValue: string;
  i: Integer;
begin
  Result.Valid := True;
  Result.ErrorMessage := '';
  Result.ErrorCode := '';
  
  WorkJSON := InputJSON;
  WorkJSON := StringReplace(WorkJSON, '\"', '"', [rfReplaceAll]);
  
  for i := Low(RequiredFields) to High(RequiredFields) do
  begin
    FieldValue := ExtractJSONValue(WorkJSON, RequiredFields[i]);
    if FieldValue = '' then
    begin
      Result.Valid := False;
      Result.ErrorMessage := 'Missing required field: ' + RequiredFields[i];
      Result.ErrorCode := 'MISSING_FIELD_' + UpperCase(RequiredFields[i]);
      Exit;
    end;
  end;
end;

{ Validate tool input based on tool type }
function ValidateToolInput(const ToolName: string; const InputJSON: string): TValidationResult;
var
  Name: string;
begin
  Result.Valid := True;
  Result.ErrorMessage := '';
  Result.ErrorCode := '';
  
  Name := LowerCase(ToolName);
  
  Result := ValidateJSONStructure(InputJSON);
  if not Result.Valid then
    Exit;
  
  if Name = 'read' then
    Result := ValidateRequiredFields(InputJSON, ['file_path'])
  else if Name = 'write' then
    Result := ValidateRequiredFields(InputJSON, ['file_path', 'content'])
  else if Name = 'edit' then
    Result := ValidateRequiredFields(InputJSON, ['file_path', 'old_string', 'new_string'])
  else if Name = 'bash' then
    Result := ValidateRequiredFields(InputJSON, ['command'])
  else if Name = 'mkdir' then
    Result := ValidateRequiredFields(InputJSON, ['path'])
  else if Name = 'delete' then
    Result := ValidateRequiredFields(InputJSON, ['path'])
  else if Name = 'move' then
    Result := ValidateRequiredFields(InputJSON, ['source', 'destination'])
  else if Name = 'glob' then
    Result := ValidateRequiredFields(InputJSON, ['pattern'])
  else if Name = 'grep' then
    Result := ValidateRequiredFields(InputJSON, ['pattern'])
  else if Name = 'diff' then
    Result := ValidateRequiredFields(InputJSON, ['file_path1', 'file_path2']);
end;

{ Pre-execution hook }
function PreToolHook(const ToolName: string; const InputJSON: string): TValidationResult;
begin
  Result.Valid := True;
  Result.ErrorMessage := '';
  Result.ErrorCode := '';
  
  Result := ValidateToolInput(ToolName, InputJSON);
  if not Result.Valid then
    Exit;
  
  if CheckToolPermission(ToolName, InputJSON) = prDenied then
  begin
    Result.Valid := False;
    Result.ErrorMessage := 'Permission denied for tool: ' + ToolName;
    Result.ErrorCode := 'PERMISSION_DENIED';
  end;
end;

{ Find or create tool stats entry }
function FindOrCreateToolStats(const ToolName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Length(GToolStats) - 1 do
  begin
    if GToolStats[i].ToolName = ToolName then
    begin
      Result := i;
      Exit;
    end;
  end;
  
  Result := Length(GToolStats);
  SetLength(GToolStats, Result + 1);
  GToolStats[Result].ToolName := ToolName;
  GToolStats[Result].ExecCount := 0;
  GToolStats[Result].SuccessCount := 0;
  GToolStats[Result].FailureCount := 0;
  GToolStats[Result].TotalExecutionTime := 0;
  GToolStats[Result].LastExecutionTime := 0;
  GToolStats[Result].LastSuccess := False;
end;

{ Post-execution hook - records statistics }
procedure PostToolHook(const ToolName: string; const InputJSON: string; const Result: TToolExecutionResult; const ExecutionTime: Int64);
var
  StatsIndex: Integer;
begin
  Inc(GTotalToolCalls);
  GTotalExecutionTime := GTotalExecutionTime + ExecutionTime;
  
  StatsIndex := FindOrCreateToolStats(ToolName);
  if StatsIndex >= 0 then
  begin
    Inc(GToolStats[StatsIndex].ExecCount);
    GToolStats[StatsIndex].LastExecutionTime := ExecutionTime;
    
    if Result.Success then
    begin
      Inc(GToolStats[StatsIndex].SuccessCount);
      GToolStats[StatsIndex].LastSuccess := True;
    end
    else
    begin
      Inc(GToolStats[StatsIndex].FailureCount);
      GToolStats[StatsIndex].LastSuccess := False;
    end;
    
    GToolStats[StatsIndex].TotalExecutionTime := GToolStats[StatsIndex].TotalExecutionTime + ExecutionTime;
  end;
end;

{ Get tool statistics }
function GetToolStats(const ToolName: string): TToolStats;
var
  i: Integer;
begin
  Result.ToolName := ToolName;
  Result.ExecCount := 0;
  Result.SuccessCount := 0;
  Result.FailureCount := 0;
  Result.TotalExecutionTime := 0;
  Result.LastExecutionTime := 0;
  Result.LastSuccess := False;
  
  for i := 0 to Length(GToolStats) - 1 do
  begin
    if GToolStats[i].ToolName = ToolName then
    begin
      Result := GToolStats[i];
      Exit;
    end;
  end;
end;

{ Get all tool statistics }
function GetAllToolStats(): TToolStatsArray;
begin
  Result := GToolStats;
end;

{ Reset tool statistics }
procedure ResetToolStats();
begin
  SetLength(GToolStats, 0);
  GTotalToolCalls := 0;
  GTotalExecutionTime := 0;
end;

end.