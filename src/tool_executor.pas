{
  Tool Executor - Wires all tool executors together.
}
unit tool_executor;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

var
  GWorkingDirectory: string = '';
  GLLMClient: TObject = nil;  { Global reference to LLM client }

procedure SetWorkingDirectory(const Dir: string);
procedure SetLLMClient(Client: TObject);
function GetLLMClient: TObject;
function ExecuteToolByName(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses bash_tool, read_tool, write_tool, edit_tool, diff_tool, file_tree_tool, move_tool, mkdir_tool, delete_tool, glob_tool, grep_tool, task_create_tool, task_list_tool, task_update_tool, agent_tool, init_tool, llmclient;

procedure SetWorkingDirectory(const Dir: string);
begin
  GWorkingDirectory := Dir;
  { Ensure trailing slash for consistent path handling }
  if (Length(GWorkingDirectory) > 0) and (GWorkingDirectory[Length(GWorkingDirectory)] <> '/') then
    GWorkingDirectory := GWorkingDirectory + '/';
end;

procedure SetLLMClient(Client: TObject);
begin
  GLLMClient := Client;
end;

function GetLLMClient: TObject;
begin
  Result := GLLMClient;
end;

function ExecuteToolByName(const ToolName: string; const InputJSON: string): TToolExecutionResult;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := 'Tool not found: ' + ToolName;
  
  if ToolName = 'Bash' then
    Result := BashToolExecute(ToolName, InputJSON)
  else if ToolName = 'Read' then
    Result := ReadToolExecute(ToolName, InputJSON)
  else if ToolName = 'Write' then
    Result := WriteToolExecute(ToolName, InputJSON)
  else if ToolName = 'Edit' then
    Result := EditToolExecute(ToolName, InputJSON)
  else if ToolName = 'Diff' then
    Result := DiffToolExecute(ToolName, InputJSON)
  else if ToolName = 'FileTree' then
    Result := FileTreeToolExecute(ToolName, InputJSON)
  else if ToolName = 'Move' then
    Result := MoveToolExecute(ToolName, InputJSON)
  else if ToolName = 'Mkdir' then
    Result := MkdirToolExecute(ToolName, InputJSON)
  else if ToolName = 'Delete' then
    Result := DeleteToolExecute(ToolName, InputJSON)
  else if ToolName = 'Glob' then
    Result := GlobToolExecute(ToolName, InputJSON)
  else if ToolName = 'Grep' then
    Result := GrepToolExecute(ToolName, InputJSON)
  else if ToolName = 'TaskCreate' then
    Result := TaskCreateExecute(ToolName, InputJSON)
  else if ToolName = 'TaskList' then
    Result := TaskListExecute(ToolName, InputJSON)
  else if ToolName = 'TaskUpdate' then
    Result := TaskUpdateExecute(ToolName, InputJSON)
  else if ToolName = 'Agent' then
    Result := AgentToolExecute(ToolName, InputJSON)
  else if ToolName = 'Init' then
    Result := InitToolExecute(ToolName, InputJSON);
end;

end.