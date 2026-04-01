{
  Read Tool - Read file contents.
  Restricted to working directory.
}
unit read_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function ReadFileContent(const FilePath: string; const Limit, Offset: Integer): TToolExecutionResult;
function ReadToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor;

function ExtractJSONString(const JSON, Key: string): string;
var KeyPos, ValueStart, ValueEnd: Integer; InString: Boolean;
begin
  Result := ''; 
  KeyPos := Pos('"' + Key + '"', JSON);
  if KeyPos = 0 then Exit;
  
  { Find the closing quote of the key first }
  ValueStart := KeyPos + Length(Key) + 1;
  
  { Find the colon after this position }
  while ValueStart <= Length(JSON) do
  begin
    if JSON[ValueStart] = ':' then 
    begin 
      Inc(ValueStart); 
      while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do Inc(ValueStart); 
      Break; 
    end;
    Inc(ValueStart);
  end;
  
  if ValueStart > Length(JSON) then Exit;
  if JSON[ValueStart] = '"' then
  begin
    Inc(ValueStart); ValueEnd := ValueStart; InString := True;
    while (ValueEnd <= Length(JSON)) and InString do begin 
      if JSON[ValueEnd] = '\' then Inc(ValueEnd, 2) else if JSON[ValueEnd] = '"' then InString := False else Inc(ValueEnd); 
    end;
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end
  else
  begin
    ValueEnd := ValueStart;
    while (ValueEnd <= Length(JSON)) and not (JSON[ValueEnd] in [',', '}', ']']) do Inc(ValueEnd);
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end;
end;

function IsPathAllowed(const FilePath: string): Boolean;
var
  FullPath, WorkDir: string;
begin
  Result := False;
  
  { Handle empty path }
  if FilePath = '' then
    Exit;
  
  { Get working directory }
  WorkDir := GWorkingDirectory;
  if WorkDir = '' then
  begin
    WorkDir := GetCurrentDir;
    if WorkDir[Length(WorkDir)] <> '/' then
      WorkDir := WorkDir + '/';
  end;
  
  { Get absolute path - handle absolute paths in request }
  if (Length(FilePath) > 0) and (FilePath[1] = '/') then
    FullPath := FilePath
  else
    FullPath := WorkDir + FilePath;
  
  { Check if path starts with working directory }
  if Length(FullPath) < Length(WorkDir) then
    Exit;
    
  Result := Copy(FullPath, 1, Length(WorkDir)) = WorkDir;
end;

function ReadFileContent(const FilePath: string; const Limit, Offset: Integer): TToolExecutionResult;
var F: TextFile; Line: string; LineCount: Integer; FullPath: string;
begin
  Result.Success := False; Result.Output := ''; Result.ErrorMessage := '';
  
  { Validate path }
  if not IsPathAllowed(FilePath) then
  begin
    Result.ErrorMessage := 'Access denied: path outside working directory';
    Exit;
  end;
  
  { Build full path }
  if FilePath[1] = '/' then
    FullPath := FilePath
  else
    FullPath := GWorkingDirectory + FilePath;
    
  if not FileExists(FullPath) then begin Result.ErrorMessage := 'File not found: ' + FullPath; Exit; end;
  AssignFile(F, FullPath); Reset(F);
  try
    LineCount := 0;
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      if LineCount < Offset then begin Inc(LineCount); Continue; end;
      if (Limit > 0) and (LineCount >= Offset + Limit) then Break;
      Result.Output := Result.Output + Line + LineEnding;
      Inc(LineCount);
    end;
    Result.Success := True;
  except on E: Exception do Result.ErrorMessage := 'Error: ' + E.Message; end;
  CloseFile(F);
end;

function ReadToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var FilePath: string; Limit, Offset: Integer; WorkInput: string;
begin
  { Unescape the JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  FilePath := ExtractJSONString(WorkInput, 'file_path');
  if FilePath = '' then FilePath := ExtractJSONString(WorkInput, 'path');
  Limit := StrToIntDef(ExtractJSONString(WorkInput, 'limit'), 0);
  Offset := StrToIntDef(ExtractJSONString(WorkInput, 'offset'), 0);
  Result := ReadFileContent(FilePath, Limit, Offset);
end;

end.