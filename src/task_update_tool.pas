{
  TaskUpdate Tool - Update task status and fields
}
unit task_update_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function TaskUpdateExecute(const ToolName, InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor, tasks;

function ExtractJSONString(const JSON, Key: string): string;
var KeyPos, ValueStart, ValueEnd: Integer; InString: Boolean;
begin
  Result := ''; KeyPos := Pos('"' + Key + '"', JSON);
  if KeyPos = 0 then Exit;
  ValueStart := KeyPos + Length(Key) + 3;
  while ValueStart <= Length(JSON) do
  begin
    if JSON[ValueStart] = ':' then begin Inc(ValueStart); while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do Inc(ValueStart); Break; end;
    Inc(ValueStart);
  end;
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

function TaskUpdateExecute(const ToolName, InputJSON: string): TToolExecutionResult;
var
  TaskID, Subject, Description, Status, BlockedBy, Blocks: string;
  Store: TTaskStore;
  Task: TTask;
  WorkInput: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';
  
  { Unescape JSON }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  TaskID := ExtractJSONString(WorkInput, 'id');
  if TaskID = '' then
  begin
    Result.ErrorMessage := 'Missing required parameter: id';
    Exit;
  end;
  
  Subject := ExtractJSONString(WorkInput, 'subject');
  Description := ExtractJSONString(WorkInput, 'description');
  Status := ExtractJSONString(WorkInput, 'status');
  BlockedBy := ExtractJSONString(WorkInput, 'blockedBy');
  Blocks := ExtractJSONString(WorkInput, 'blocks');
  
  Store := TTaskStore.Create(GWorkingDirectory + '.tasks');
  try
    Task := Store.GetTask(TaskID);
    if Task.ID = '' then
    begin
      Result.ErrorMessage := 'Task #' + TaskID + ' not found';
      Exit;
    end;
    
    if Store.UpdateTask(TaskID, Subject, Description, Status, BlockedBy, Blocks) then
    begin
      Result.Success := True;
      Result.Output := 'Task #' + TaskID + ' updated';
    end
    else
    begin
      Result.ErrorMessage := 'Failed to update task';
    end;
  finally
    Store.Free;
  end;
end;

end.