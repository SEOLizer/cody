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
    FinishReason: string;
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

implementation

end.