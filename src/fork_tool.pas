{
  Fork Tool - Fork sub-agents with context inheritance.
  Extends Agent tool with fork capabilities and recursion protection.
}
unit fork_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function ForkToolExecute(ToolName: string; InputJSON: string): TToolExecutionResult;
procedure InitializeForkTool;

implementation

uses tool_executor, chathistory, llmclient, agent_tool, Unix;

const
  MAX_FORK_DEPTH = 2;
  MAX_PARALLEL_FORKS = 3;

var
  GForkCount: Integer = 0;
  GForkHistory: string = '';

{ Extract JSON value - helper function }
function ExtractJSONString(JSON: string; Key: string): string;
var
  KeyPos, ValueStart, ValueEnd, ColonPos: Integer;
  InString: Boolean;
begin
  Result := '';
  KeyPos := Pos('"' + Key + '":', JSON);
  if KeyPos = 0 then Exit;

  ColonPos := KeyPos + Length(Key) + 2;
  if (ColonPos > Length(JSON)) or (JSON[ColonPos] <> ':') then Exit;

  ValueStart := ColonPos + 1;
  while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
    Inc(ValueStart);
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

{ Get agent definition from agent_tool }
function GetAgentDef(AgentType: string): TAgentDefinition;
var
  LLMClient: TObject;
begin
  Result.AgentType := AgentType;
  Result.ModelOverride := '';
  Result.SubAgentType := satCustom;
  Result.WhenToUse := 'General-purpose agent';
  Result.IsReadOnly := False;
  
  { Set system prompt based on type }
  if LowerCase(AgentType) = 'explore' then
  begin
    Result.SubAgentType := satExplore;
    Result.WhenToUse := 'Fast agent for exploring codebases.';
    Result.IsReadOnly := True;
  end
  else if LowerCase(AgentType) = 'plan' then
  begin
    Result.SubAgentType := satPlan;
    Result.WhenToUse := 'Agent for creating plans.';
    Result.IsReadOnly := False;
  end;
end;

{ Get system prompt based on agent type }
function GetSystemPromptForType(AgentType: string): string;
begin
  if LowerCase(AgentType) = 'explore' then
  begin
    Result := 'You are a file search assistant. Your job is to find files and list them.' + LineEnding +
      'Instructions:' + LineEnding +
      '- Use Bash with "ls -la" to list files in directories' + LineEnding +
      '- Use Glob patterns like "*.pas" to find specific files' + LineEnding +
      '- Report your findings as a simple list of file paths';
  end
  else if LowerCase(AgentType) = 'plan' then
  begin
    Result := 'You are a planning assistant.' + LineEnding +
      'Your job is to create a detailed plan for the given task.' + LineEnding +
      'Break down the task into clear, numbered steps.';
  end
  else
  begin
    Result := 'You are a helpful AI assistant.' + LineEnding +
      'Your job is to complete the task given by the user.' + LineEnding +
      'When done, provide a summary of what you accomplished.';
  end;
end;

{ Run forked sub-agent with parent context inheritance }
function RunForkedAgent(Prompt, AgentType: string): string;
var
  LLMClient: TLLMClient;
  Messages: TMessageArray;
  AgentDef: TAgentDefinition;
  Response: TLLMResponse;
  ToolCallCount, MaxToolCalls: Integer;
  ToolResult: TToolExecutionResult;
  ParentContext: string;
begin
  Result := '';
  
  Inc(GForkCount);
  
  { Check fork depth limit }
  if GForkCount > MAX_FORK_DEPTH then
  begin
    Result := 'Error: Maximum fork depth exceeded (' + IntToStr(MAX_FORK_DEPTH) + ')';
    Dec(GForkCount);
    Exit;
  end;
  
  { Get LLM client }
  LLMClient := TLLMClient(tool_executor.GetLLMClient);
  if LLMClient = nil then
  begin
    Result := 'Error: LLM client not available';
    Dec(GForkCount);
    Exit;
  end;

  { Get agent definition }
  AgentDef := GetAgentDef(AgentType);
  
  { Build parent context for inheritance }
  ParentContext := '[Forked from parent agent]' + LineEnding +
    'Agent type: ' + AgentType + LineEnding +
    'Working directory: ' + tool_executor.GWorkingDirectory + LineEnding;
  
  { Initialize fresh chat history for fork }
  ChatHistory_Init;
  ChatHistory_AddMessage(Ord(ruSystem), GetSystemPromptForType(AgentType));
  ChatHistory_AddMessage(Ord(ruSystem), ParentContext);
  ChatHistory_AddMessage(Ord(ruUser), Prompt);
  
  WriteLn('[Fork] Starting forked agent (depth: ', GForkCount, ')');
  Flush(Output);
  
  ToolCallCount := 0;
  MaxToolCalls := 5;
  
  { Tool loop for forked agent }
  while ToolCallCount < MaxToolCalls do
  begin
    Messages := ChatHistory_GetMessagesForLMStudio(True);
    Response := LLMClient.Chat(Messages, True);
    
    { If we have content without tool calls, we're done }
    if (Response.Content <> '') and not Response.HasToolCall then
    begin
      Result := Response.Content;
      Break;
    end;
    
    { If no content and no tool call, something is wrong }
    if (Response.Content = '') and not Response.HasToolCall then
    begin
      Result := 'Forked agent completed but returned no result.';
      Break;
    end;
    
    { Execute tool call }
    Inc(ToolCallCount);
    WriteLn('[Fork] Tool call #', ToolCallCount, ': ', Response.ToolCallName);
    Flush(Output);
    
    { Execute tool }
    ToolResult := tool_executor.ExecuteToolByName(Response.ToolCallName, Response.ToolCallInput);
    
    { Log tool call }
    GForkHistory := GForkHistory + '  - ' + Response.ToolCallName + ': ' + 
      Copy(Response.ToolCallInput, 1, 80) + LineEnding;
    
    { Add tool result to chat }
    ChatHistory_AddToolUse(Response.ToolCallName, Response.ToolCallID, Response.ToolCallInput);
    if ToolResult.Success then
      ChatHistory_AddToolResult(Response.ToolCallID, ToolResult.Output)
    else
      ChatHistory_AddToolResultError(Response.ToolCallID, ToolResult.ErrorMessage);
  end;
  
  if Result = '' then
    Result := 'Forked agent reached maximum tool calls.';
    
  Dec(GForkCount);
end;

{ Fork Tool execution function }
function ForkToolExecute(ToolName: string; InputJSON: string): TToolExecutionResult;
var
  Prompt, AgentType, ForkType: string;
  ForkCount, MaxForks, i: Integer;
  ForkIDs: array of string;
  ForkResults: array of string;
  WorkInput: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';

  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  { Extract parameters }
  Prompt := ExtractJSONString(WorkInput, 'prompt');
  AgentType := ExtractJSONString(WorkInput, 'agent_type');
  ForkType := ExtractJSONString(WorkInput, 'fork_type');
  
  { Default values }
  if AgentType = '' then
    AgentType := 'GeneralPurpose';
  if ForkType = '' then
    ForkType := 'single';
    
  { Validate prompt }
  if Prompt = '' then
  begin
    Result.ErrorMessage := 'Missing required parameter: prompt';
    Exit;
  end;

  { Check fork count limit }
  GForkCount := 0;
  GForkHistory := '';

  if LowerCase(ForkType) = 'parallel' then
  begin
    { Parallel fork mode - execute multiple forks }
    MaxForks := MAX_PARALLEL_FORKS;
    SetLength(ForkIDs, MaxForks);
    SetLength(ForkResults, MaxForks);
    
    WriteLn('[Fork] Starting parallel forks (count: ', MaxForks, ')');
    Flush(Output);
    
    { Execute forks sequentially for now }
    for i := 0 to MaxForks - 1 do
    begin
      ForkIDs[i] := 'fork_' + IntToStr(i);
      ForkResults[i] := RunForkedAgent(Prompt + ' [Task ' + IntToStr(i+1) + ' of ' + 
        IntToStr(MaxForks) + ']', AgentType);
    end;
    
    { Build combined result }
    Result.Output := 'Parallel forks completed: ' + IntToStr(MaxForks) + LineEnding + LineEnding;
    for i := 0 to MaxForks - 1 do
    begin
      Result.Output := Result.Output + 'Fork ' + IntToStr(i+1) + ':' + LineEnding;
      Result.Output := Result.Output + ForkResults[i] + LineEnding + LineEnding;
    end;
  end
  else
  begin
    { Single fork mode }
    WriteLn('[Fork] Starting single fork');
    Flush(Output);
    
    Result.Output := RunForkedAgent(Prompt, AgentType);
  end;
  
  { Append fork history to result }
  if GForkHistory <> '' then
  begin
    Result.Output := Result.Output + LineEnding + '## Fork History' + LineEnding + GForkHistory;
  end;
  
  if Result.Output <> '' then
    Result.Success := True
  else
    Result.ErrorMessage := 'Fork returned no result';
end;

procedure InitializeForkTool;
begin
  { Initialization if needed }
end;

end.