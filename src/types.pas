{
  This unit defines the core types for the LLM client.
  Based on Claude Code's approach to message handling and API types.
  Extended with Tool support.
}
unit types;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  { Helper type for string array }
  TStringArray = array of string;

  { Role types for messages }
  TRole = (ruUser, ruAssistant, ruSystem);

  { Stop reasons from LLM responses }
  TStopReason = (
    srEndTurn,      { Task completed, LLM has finished }
    srToolUse,      { LLM wants to use a tool }
    srMaxTokens,    { Output limit reached }
    srStop,          { Normal stop (Ollama) }
    srLength,        { Length limit (OpenAI) }
    srUnknown        { Unknown or error }
  );

  { Message content block types }
  TContentBlockType = (cbText, cbToolUse, cbToolResult);

  { Tool use block - stored separately from message }
  TToolUse = record
    ID: string;
    ToolName: string;
    Input_: string;
  end;

  { Tool result block - stored separately from message }
  TToolResult = record
    ToolUseID: string;
    Content: string;
    IsError: Boolean;
  end;

  { Message structure for chat - simplified to just text for now }
  TMessage = record
    Role: TRole;
    TextContent: string;
    HasToolUse: Boolean;
    ToolUseBlock: TToolUse;
    HasToolResult: Boolean;
    ToolResultBlock: TToolResult;
  end;
  TMessageArray = array of TMessage;

  { Request payload for LLM API }
  TLLMRequest = record
    Model: string;
    Messages: TMessageArray;
    Temperature: Double;
    MaxTokens: Integer;
    Stream: Boolean;
  end;

  { Response from LLM - simplified }
  TLLMResponse = record
    Content: string;
    ToolCallName: string;
    ToolCallID: string;
    ToolCallInput: string;
    HasToolCall: Boolean;
    StopReason: TStopReason;
    StopReasonRaw: string;  { Raw string for debugging }
    UsageInputTokens: Integer;
    UsageOutputTokens: Integer;
  end;

  { Configuration for LLM client }
  TLLMConfig = record
    BaseURL: string;
    APIKey: string;
    Model: string;
    Temperature: Double;
    MaxTokens: Integer;
    WorkingDirectory: string;
  end;

  { Tool types }
  TToolType = (ttBash, ttRead, ttWrite, ttEdit, ttGlob, ttGrep);

  { Tool definition }
  TToolDefinition = record
    Name: string;
    Description: string;
    InputSchema: string;
    ToolType: TToolType;
  end;
  TToolDefinitionArray = array of TToolDefinition;

  { Tool execution result }
  TToolExecutionResult = record
    Success: Boolean;
    Output: string;
    ErrorMessage: string;
  end;

  { Convert raw stop reason string to TStopReason enum }
  function ParseStopReason(const RawReason: string): TStopReason;

implementation

{ Convert raw stop reason string to TStopReason enum }
function ParseStopReason(const RawReason: string): TStopReason;
var
  S: string;
begin
  S := LowerCase(Trim(RawReason));
  
  if (S = 'end_turn') or (S = 'stop') or (S = '') then
    Result := srEndTurn
  else if (S = 'tool_calls') or (S = 'tool_use') then
    Result := srToolUse
  else if (S = 'max_tokens') or (S = 'length') then
    Result := srMaxTokens
  else if S = 'stop' then
    Result := srStop
  else if S = 'length' then
    Result := srLength
  else
    Result := srUnknown;
end;

end.