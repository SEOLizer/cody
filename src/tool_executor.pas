{
  Tool Executor - Wires all tool executors together.
  Includes permission checking, command sanitization, and tool orchestration.
}
unit tool_executor;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

var
  GWorkingDirectory: string = '';
  GLLMClient: TObject = nil;  { Global reference to LLM client }
  GPermissionMode: Integer = 0;  { 0=Auto, 1=Ask, 2=Strict }
  GMaxParallelReads: Integer = 10;  { Maximum parallel read operations }
  GExecutionMode: Integer = 0;  { 0=Auto, 1=Serial, 2=Parallel }

procedure SetWorkingDirectory(const Dir: string);
procedure SetLLMClient(Client: TObject);
function GetLLMClient: TObject;
function ExecuteToolByName(const ToolName: string; const InputJSON: string): TToolExecutionResult;
function ExecuteToolWithOrchestration(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses bash_tool, read_tool, write_tool, edit_tool, diff_tool, file_tree_tool, move_tool, mkdir_tool, delete_tool, glob_tool, grep_tool, task_create_tool, task_list_tool, task_update_tool, agent_tool, init_tool, llmclient, tool_permissions, tool_orchestration, tool_validation;

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
var
  PermResult: TPermissionResult;
  ValidResult: TValidationResult;
  StartTime: Int64;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := 'Tool not found: ' + ToolName;
  StartTime := GetTickCount64;
  
  { Pre-execution validation hook }
  ValidResult := PreToolHook(ToolName, InputJSON);
  if not ValidResult.Valid then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Validation failed: ' + ValidResult.ErrorMessage;
    Result.ErrorCode := ValidResult.ErrorCode;
    { Record stats for failed validation }
    PostToolHook(ToolName, InputJSON, Result, GetTickCount64 - StartTime);
    Exit;
  end;
  
  { Check permissions first }
  PermResult := CheckToolPermission(ToolName, InputJSON);
  
  if PermResult = prDenied then
  begin
    Result.ErrorMessage := 'Permission denied: ' + ToolName + ' is not allowed in strict mode';
    Exit;
  end
  else if PermResult = prAsk then
  begin
    { In Auto mode, we allow read-only tools automatically }
    if not IsAutoApproved(ToolName) then
    begin
      { For now, allow in auto mode but could prompt user }
      { TODO: Add interactive confirmation prompt }
    end;
  end;
  
  { Execute the tool }
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
    
  { Post-execution hook - record statistics }
  PostToolHook(ToolName, InputJSON, Result, GetTickCount64 - StartTime);
end;

{ Execute tool with orchestration support - categorizes and decides execution strategy }
function ExecuteToolWithOrchestration(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  ExecutionMode: TExecutionMode;
begin
  { Check execution mode setting }
  if GExecutionMode = 1 then
  begin
    { Serial mode - execute directly }
    Result := ExecuteToolByName(ToolName, InputJSON);
    Exit;
  end;
  
  { Get execution mode based on tool type }
  ExecutionMode := GetExecutionMode(ToolName);
  
  case ExecutionMode of
    emParallel:
    begin
      { Read-only tool - can be parallelized }
      if GExecutionMode = 2 then
      begin
        { Force parallel - for now, execute directly }
        Result := ExecuteToolByName(ToolName, InputJSON);
      end
      else
      begin
        { Auto mode - execute directly (parallelization would require threading) }
        Result := ExecuteToolByName(ToolName, InputJSON);
      end;
    end;
    emSerial, emBatch:
    begin
      { Write tool - always serial }
      Result := ExecuteToolByName(ToolName, InputJSON);
    end;
  else
    Result := ExecuteToolByName(ToolName, InputJSON);
  end;
end;

end.