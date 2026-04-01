{
  TaskList Tool - List all tasks
}
unit task_list_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function TaskListExecute(const ToolName, InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor, tasks;

function TaskListExecute(const ToolName, InputJSON: string): TToolExecutionResult;
var
  Store: TTaskStore;
  TaskList: TTaskArray;
  i: Integer;
  StatusStr: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';
  
  Store := TTaskStore.Create(GWorkingDirectory + '.tasks');
  try
    TaskList := Store.ListTasks;
    
    if Length(TaskList) = 0 then
    begin
      Result.Success := True;
      Result.Output := 'No tasks found';
      Exit;
    end;
    
    Result.Output := '';
    for i := 0 to Length(TaskList) - 1 do
    begin
      case TaskList[i].Status of
        tsPending: StatusStr := '[pending]';
        tsInProgress: StatusStr := '[in_progress]';
        tsCompleted: StatusStr := '[completed]';
        tsCancelled: StatusStr := '[cancelled]';
      end;
      
      Result.Output := Result.Output + '#' + TaskList[i].ID + ' ' + StatusStr + ' ' + TaskList[i].Subject;
      if TaskList[i].blockedBy <> '' then
        Result.Output := Result.Output + ' [blocked by: ' + TaskList[i].blockedBy + ']';
      Result.Output := Result.Output + LineEnding;
    end;
    
    Result.Success := True;
  finally
    Store.Free;
  end;
end;

end.