{
  Agent Tool - Spawn sub-agents for complex multi-step tasks.
  Based on Claude Code's AgentTool implementation.
  
  Features:
  - Sub-Agent with clean slate (fresh chat history)
  - Limited conversation depth (one level)
  - Summary return to main agent
  - Integrated types: Explore, Plan, Custom
}
unit agent_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types, llmclient;

type
  { Sub-agent types }
  TSubAgentType = (
    satExplore,   { File search and exploration }
    satPlan,       { Task planning }
    satCustom      { Custom task execution }
  );

  TAgentDefinition = record
    AgentType: string;
    SubAgentType: TSubAgentType;
    WhenToUse: string;
    GetSystemPrompt: function: string;
    ModelOverride: string;
    IsReadOnly: Boolean;
  end;

function GetLLMClient: TObject;
function GetWorkingDirectory: string;
function AgentToolExecute(const ToolName, InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor, chathistory;

var
  GCurrentAgentDepth: Integer = 0;
  const MAX_AGENT_DEPTH = 1;  { Limited to one level of sub-agents }
  GToolCallsMade: Integer = 0;
  GToolCallLog: string = '';

{ Wrapper functions to access tool_executor globals }
function GetLLMClient: TObject;
begin
  Result := tool_executor.GetLLMClient;
end;

function GetWorkingDirectory: string;
begin
  Result := tool_executor.GWorkingDirectory;
end;

{ Extract JSON value - helper function }
function ExtractJSONString(const JSON, Key: string): string;
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

{ Get system prompt for Explore agent }
function GetExploreSystemPrompt: string;
begin
  Result := 
    'You are a file search assistant. Your job is to find files and list them.' + LineEnding +
    LineEnding +
    'Instructions:' + LineEnding +
    '- Use Bash with "ls -la" to list files in directories' + LineEnding +
    '- Use Glob patterns like "*.pas" to find specific files' + LineEnding +
    '- Report your findings as a simple list of file paths' + LineEnding +
    LineEnding +
    'Just list the files you find. Be thorough and check subdirectories.';
end;

{ Get system prompt for General Purpose agent }
function GetGeneralPurposeSystemPrompt: string;
begin
  Result :=
    'You are a helpful AI assistant.' + LineEnding +
    'Your job is to complete the task given by the user.' + LineEnding +
    'Use any tools as needed to accomplish the task.' + LineEnding +
    LineEnding +
    'When done, provide a summary of what you accomplished.';
end;

{ Get system prompt for Plan agent }
function GetPlanSystemPrompt: string;
begin
  Result :=
    'You are a planning assistant.' + LineEnding +
    LineEnding +
    'Your job is to create a detailed plan for the given task.' + LineEnding +
    'Break down the task into clear, numbered steps.';
end;

function GetAgentDefinition(AgentType: string): TAgentDefinition;
begin
  Result.AgentType := AgentType;
  Result.ModelOverride := '';
  Result.SubAgentType := satCustom;

  if LowerCase(AgentType) = 'explore' then
  begin
    Result.SubAgentType := satExplore;
    Result.WhenToUse := 'Fast agent for exploring codebases.';
    Result.GetSystemPrompt := @GetExploreSystemPrompt;
    Result.IsReadOnly := True;
  end
  else if LowerCase(AgentType) = 'plan' then
  begin
    Result.SubAgentType := satPlan;
    Result.WhenToUse := 'Agent for creating plans.';
    Result.GetSystemPrompt := @GetPlanSystemPrompt;
    Result.IsReadOnly := False;
  end
  else
  begin
    Result.SubAgentType := satCustom;
    Result.WhenToUse := 'General-purpose agent for multi-step tasks.';
    Result.GetSystemPrompt := @GetGeneralPurposeSystemPrompt;
    Result.IsReadOnly := False;
  end;
end;

{ Generate summary from tool call log }
function GenerateSummary: string;
var
  LogLines: TStringArray;
  i: Integer;
begin
  Result := '';
  if GToolCallLog = '' then Exit;
  
  Result := '## Sub-Agent Summary' + LineEnding + LineEnding;
  Result := Result + 'Tools executed: ' + IntToStr(GToolCallsMade) + LineEnding + LineEnding;
  Result := Result + 'Tool call log:' + LineEnding;
  Result := Result + GToolCallLog;
end;

{ Run sub-agent with clean slate }
function RunSubAgent(Prompt, AgentType, WorkingDir: string): string;
var
  LLMClient: TLLMClient;
  Messages: TMessageArray;
  AgentDef: TAgentDefinition;
  Response: TLLMResponse;
  ToolCallCount, MaxToolCalls: Integer;
  ToolResult: TToolExecutionResult;
begin
  Result := '';
  GToolCallsMade := 0;
  GToolCallLog := '';
  
  LLMClient := TLLMClient(GetLLMClient);
  if LLMClient = nil then
  begin
    Result := 'Error: LLM client not available';
    Exit;
  end;

  Inc(GCurrentAgentDepth);
  if GCurrentAgentDepth > MAX_AGENT_DEPTH then
  begin
    Dec(GCurrentAgentDepth);
    Result := 'Error: Maximum agent recursion depth reached.';
    Exit;
  end;

  AgentDef := GetAgentDefinition(AgentType);
  
  { Use global chat history }
  ChatHistory_Init;
  ChatHistory_AddMessage(Ord(ruSystem), AgentDef.GetSystemPrompt());
  ChatHistory_AddMessage(Ord(ruUser), Prompt);
  
  WriteLn('[Agent] Running sub-agent (depth: ', GCurrentAgentDepth, ')');
  Flush(Output);
  
  ToolCallCount := 0;
  MaxToolCalls := 5;
  
  { Tool loop }
  while ToolCallCount < MaxToolCalls do
  begin
    { Use TRUE to get LM Studio compatibility (adds dummy user message) }
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
      Result := 'Sub-agent completed but returned no result.';
      Break;
    end;
    
    { Execute tool call }
    Inc(ToolCallCount);
    Inc(GToolCallsMade);
    WriteLn('[Agent] Tool call #', ToolCallCount, ': ', Response.ToolCallName, ' - ', Response.ToolCallInput);
    Flush(Output);
    
    { Log tool call }
    GToolCallLog := GToolCallLog + '- ' + Response.ToolCallName + ': ' + Copy(Response.ToolCallInput, 1, 100) + LineEnding;
    
    { Execute tool via tool_executor }
    ToolResult := tool_executor.ExecuteToolByName(Response.ToolCallName, Response.ToolCallInput);
    
    WriteLn('[Agent] Tool result: ', ToolResult.Success, ' - ', Copy(ToolResult.Output, 1, 50));
    Flush(Output);
    
    { Add tool result to chat }
    ChatHistory_AddToolUse(Response.ToolCallName, Response.ToolCallID, Response.ToolCallInput);
    if ToolResult.Success then
      ChatHistory_AddToolResult(Response.ToolCallID, ToolResult.Output)
    else
      ChatHistory_AddToolResultError(Response.ToolCallID, ToolResult.ErrorMessage);
  end;
  
  if Result = '' then
    Result := 'Sub-agent reached maximum tool calls without producing final result.'
  else if GToolCallsMade > 0 then
  begin
    { Append summary to result }
    Result := Result + LineEnding + LineEnding + GenerateSummary;
  end;
    
  WriteLn('[Agent] Sub-agent done. Result length: ', Length(Result), ', Tools used: ', GToolCallsMade);
  Flush(Output);
  
  Dec(GCurrentAgentDepth);
end;

{ Main Agent Tool execution function }
function AgentToolExecute(const ToolName, InputJSON: string): TToolExecutionResult;
var
  Description, Prompt, AgentType, WorkingDir: string;
  AgentDef: TAgentDefinition;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';

  Prompt := InputJSON;
  Prompt := StringReplace(Prompt, '\"', '"', [rfReplaceAll]);
  Prompt := StringReplace(Prompt, '\\', '\', [rfReplaceAll]);

  Description := ExtractJSONString(Prompt, 'description');
  Prompt := ExtractJSONString(Prompt, 'prompt');
  AgentType := ExtractJSONString(Prompt, 'subagent_type');
  
  WorkingDir := GetWorkingDirectory;

  if Description = '' then
  begin
    Result.ErrorMessage := 'Missing required parameter: description';
    Exit;
  end;
  if Prompt = '' then
  begin
    Result.ErrorMessage := 'Missing required parameter: prompt';
    Exit;
  end;

  if AgentType = '' then
    AgentType := 'GeneralPurpose';

  AgentDef := GetAgentDefinition(AgentType);

  WriteLn('');
  WriteLn('Spawning sub-agent: ', AgentType);
  WriteLn('   Task: ', Description);
  WriteLn('   Read-only: ', AgentDef.IsReadOnly);
  Flush(Output);

  Result.Output := RunSubAgent(Prompt, AgentType, WorkingDir);

  if Result.Output <> '' then
    Result.Success := True
  else
    Result.ErrorMessage := 'Sub-agent returned no result';
end;

end.