{
  TaskCreate Tool - Create a new task
}
unit task_create_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function TaskCreateExecute(const ToolName, InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor, tasks;

function ExtractJSONString(const JSON, Key: string): string;
var KeyPos, ValueStart, ValueEnd, ColonPos: Integer; InString: Boolean;
begin
  Result := ''; 
  { Search for "key": pattern }
  KeyPos := Pos('"' + Key + '":', JSON);
  if KeyPos = 0 then Exit;
  
  { The colon is AT KeyPos + Length(Key) + 1 (after closing quote) }
  ColonPos := KeyPos + Length(Key) + 2;
  if JSON[ColonPos] = ':' then
  begin
    ValueStart := ColonPos + 1;
    while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
      Inc(ValueStart);
  end
  else
    Exit;
    
  if ValueStart > Length(JSON) then Exit;
  
  if JSON[ValueStart] = '"' then
  begin
    Inc(ValueStart); ValueEnd := ValueStart; InString := True;
    while (ValueEnd <= Length(JSON)) and InString do begin if JSON[ValueEnd] = '\' then Inc(ValueEnd, 2) else if JSON[ValueEnd] = '"' then InString := False else Inc(ValueEnd); end;
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end
  else
  begin
    ValueEnd := ValueStart;
    while (ValueEnd <= Length(JSON)) and not (JSON[ValueEnd] in [',', '}', ']']) do Inc(ValueEnd);
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end;
end;

function TaskCreateExecute(const ToolName, InputJSON: string): TToolExecutionResult;
var
  Subject, Description, ActiveForm, TaskID: string;
  Store: TTaskStore;
  WorkInput: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';
  
  { Unescape JSON }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  Subject := ExtractJSONString(WorkInput, 'subject');
  if Subject = '' then
  begin
    Result.ErrorMessage := 'Missing required parameter: subject';
    Exit;
  end;
  
  Description := ExtractJSONString(WorkInput, 'description');
  ActiveForm := ExtractJSONString(WorkInput, 'activeForm');
  
  { Create task store }
  Store := TTaskStore.Create(GWorkingDirectory + '.tasks');
  try
    TaskID := Store.CreateTask(Subject, Description, ActiveForm);
    if TaskID <> '' then
    begin
      Result.Success := True;
      Result.Output := 'Task #' + TaskID + ' created: ' + Subject;
    end
    else
    begin
      Result.ErrorMessage := 'Failed to create task';
    end;
  finally
    Store.Free;
  end;
end;

end.