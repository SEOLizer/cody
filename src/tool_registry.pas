{
  Tool Registry - Manages all available tools.
  Inspired by Claude Code's tool management.
}
unit tool_registry;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, types;

type
  { Tool executor function type }
  TToolExecutorFunc = function(const ToolName: string; const InputJSON: string): TToolExecutionResult;

  { Tool registry entry }
  TToolEntry = record
    Definition: TToolDefinition;
    Executor: TToolExecutorFunc;
  end;

  { Tool registry }
  TToolRegistry = class
  private
    FTools: array of TToolEntry;
    function FindTool(const ToolName: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    { Register a tool }
    procedure RegisterTool(const Definition: TToolDefinition; Executor: TToolExecutorFunc);
    
    { Get tool definitions for LLM }
    function GetToolDefinitions: TToolDefinitionArray;
    
    { Execute a tool }
    function ExecuteTool(const ToolName: string; const InputJSON: string): TToolExecutionResult;
    
    { Get tool names as comma-separated string for system prompt }
    function GetToolNames: string;
  end;

{ Global tool registry }
var
  GlobalToolRegistry: TToolRegistry;

implementation

constructor TToolRegistry.Create;
begin
  inherited Create;
  SetLength(FTools, 0);
end;

destructor TToolRegistry.Destroy;
begin
  SetLength(FTools, 0);
  inherited Destroy;
end;

function TToolRegistry.FindTool(const ToolName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Length(FTools) - 1 do
  begin
    if FTools[i].Definition.Name = ToolName then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TToolRegistry.RegisterTool(const Definition: TToolDefinition; Executor: TToolExecutorFunc);
var
  Len: Integer;
begin
  Len := Length(FTools);
  SetLength(FTools, Len + 1);
  FTools[Len].Definition := Definition;
  FTools[Len].Executor := Executor;
end;

function TToolRegistry.GetToolDefinitions: TToolDefinitionArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FTools));
  for i := 0 to Length(FTools) - 1 do
    Result[i] := FTools[i].Definition;
end;

function TToolRegistry.ExecuteTool(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  idx: Integer;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := 'Tool not found: ' + ToolName;
  
  idx := FindTool(ToolName);
  if idx >= 0 then
  begin
    Result := FTools[idx].Executor(ToolName, InputJSON);
  end;
end;

function TToolRegistry.GetToolNames: string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Length(FTools) - 1 do
  begin
    if Result <> '' then
      Result := Result + ', ';
    Result := Result + FTools[i].Definition.Name;
  end;
end;

{ Tool definition helpers }
function CreateBashToolDefinition: TToolDefinition;
begin
  Result.Name := 'Bash';
  Result.Description := 'Execute shell commands in a terminal. Use this to run git, npm, docker, or other command-line tools.';
  Result.InputSchema := '{"type":"object","properties":{"command":{"type":"string","description":"The command to execute"},"directory":{"type":"string","description":"Working directory for the command"}},"required":["command"]}';
  Result.ToolType := ttBash;
end;

function CreateReadToolDefinition: TToolDefinition;
begin
  Result.Name := 'Read';
  Result.Description := 'Read the contents of a file. Returns the file content as text.';
  Result.InputSchema := '{"type":"object","properties":{"file_path":{"type":"string","description":"Path to the file to read"},"limit":{"type":"integer","description":"Maximum number of lines to read"},"offset":{"type":"integer","description":"Line number to start reading from"}},"required":["file_path"]}';
  Result.ToolType := ttRead;
end;

function CreateWriteToolDefinition: TToolDefinition;
begin
  Result.Name := 'Write';
  Result.Description := 'Write content to a file. Creates the file if it does not exist, overwrites if it does.';
  Result.InputSchema := '{"type":"object","properties":{"file_path":{"type":"string","description":"Path to the file to write"},"content":{"type":"string","description":"Content to write to the file"}},"required":["file_path","content"]}';
  Result.ToolType := ttWrite;
end;

function CreateEditToolDefinition: TToolDefinition;
begin
  Result.Name := 'Edit';
  Result.Description := 'Make edits to a file by replacing a specific string with a new string.';
  Result.InputSchema := '{"type":"object","properties":{"file_path":{"type":"string","description":"Path to the file to edit"},"old_string":{"type":"string","description":"The text to find and replace"},"new_string":{"type":"string","description":"The replacement text"}},"required":["file_path","old_string","new_string"]}';
  Result.ToolType := ttEdit;
end;

function CreateGlobToolDefinition: TToolDefinition;
begin
  Result.Name := 'Glob';
  Result.Description := 'Search for files by name pattern. Supports * and ? wildcards.';
  Result.InputSchema := '{"type":"object","properties":{"pattern":{"type":"string","description":"File name pattern (e.g., *.ts, **/*.js)"},"path":{"type":"string","description":"Directory to search in"}},"required":["pattern"]}';
  Result.ToolType := ttGlob;
end;

function CreateGrepToolDefinition: TToolDefinition;
begin
  Result.Name := 'Grep';
  Result.Description := 'Search for text content in files. Returns matching lines with file and line numbers.';
  Result.InputSchema := '{"type":"object","properties":{"pattern":{"type":"string","description":"Text pattern to search for"},"path":{"type":"string","description":"Directory to search in"},"include":{"type":"string","description":"File pattern to include (e.g., *.ts, *.js)"}},"required":["pattern"]}';
  Result.ToolType := ttGrep;
end;

initialization
  GlobalToolRegistry := TToolRegistry.Create;
  GlobalToolRegistry.RegisterTool(CreateBashToolDefinition, nil);
  GlobalToolRegistry.RegisterTool(CreateReadToolDefinition, nil);
  GlobalToolRegistry.RegisterTool(CreateWriteToolDefinition, nil);
  GlobalToolRegistry.RegisterTool(CreateEditToolDefinition, nil);
  GlobalToolRegistry.RegisterTool(CreateGlobToolDefinition, nil);
  GlobalToolRegistry.RegisterTool(CreateGrepToolDefinition, nil);

finalization
  GlobalToolRegistry.Free;

end.