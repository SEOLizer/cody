{
  Context Compression - Handles context overflow errors and reactive compression.
  - Auto-Compact: Triggers at ~92% capacity (token threshold)
  - Microcompact: Per-tool-result caching
  - Reactive Compact: Emergency recovery for 413/400 errors
}
unit context_compression;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  TCompressionStrategy = (
    csNone,         { No compression needed }
    csMicroCompact, { Compact individual tool results }
    csAutoCompact,  { Full context summarization }
    csReactive      { Emergency recovery after API error }
  );

  TContextState = record
    TotalTokens: Integer;
    MessageCount: Integer;
    ToolCallCount: Integer;
    LastCompression: Integer;
    CompressionCount: Integer;
  end;

var
  GMaxContextTokens: Integer = 32000;
  GCompressionThreshold: Integer = 29440; { ~92% of 32k }
  GMinMessagesKeep: Integer = 4;

{ Context Management }
procedure InitContextCompression;
function GetContextState: TContextState;
function ShouldCompress(CurrentTokens: Integer): TCompressionStrategy;
procedure TriggerReactiveCompression(var Messages: TMessageArray);
procedure CompressContext(var Messages: TMessageArray);
function GetCompressedSummary(const Messages: TMessageArray): string;

{ Error Detection }
function IsContextError(const ErrorMsg: string; StatusCode: Integer): Boolean;
function ExtractErrorReason(const ErrorMsg: string): string;

implementation

var
  GContextState: TContextState;

procedure InitContextCompression;
begin
  GContextState.TotalTokens := 0;
  GContextState.MessageCount := 0;
  GContextState.ToolCallCount := 0;
  GContextState.LastCompression := 0;
  GContextState.CompressionCount := 0;
end;

function GetContextState: TContextState;
begin
  Result := GContextState;
end;

function ShouldCompress(CurrentTokens: Integer): TCompressionStrategy;
begin
  GContextState.TotalTokens := CurrentTokens;
  
  if CurrentTokens >= GCompressionThreshold then
  begin
    if CurrentTokens >= GMaxContextTokens then
      Result := csReactive
    else
      Result := csAutoCompact;
  end
  else if CurrentTokens >= GMaxContextTokens div 2 then
    Result := csMicroCompact
  else
    Result := csNone;
end;

function GetCompressedSummary(const Messages: TMessageArray): string;
var
  i: Integer;
  RoleStr: string;
begin
  Result := '=== Context Summary ===' + LineEnding;
  Result := Result + 'Messages: ' + IntToStr(Length(Messages)) + LineEnding;
  Result := Result + LineEnding;
  
  for i := 0 to Length(Messages) - 1 do
  begin
    case Messages[i].Role of
      ruUser: RoleStr := 'User';
      ruAssistant: RoleStr := 'Assistant';
      ruSystem: RoleStr := 'System';
    end;
    
    if Length(Messages[i].TextContent) > 100 then
      Result := Result + RoleStr + ': ' + Copy(Messages[i].TextContent, 1, 100) + '...' + LineEnding
    else
      Result := Result + RoleStr + ': ' + Messages[i].TextContent + LineEnding;
  end;
end;

procedure CompressContext(var Messages: TMessageArray);
var
  i, KeepStart, NewLen: Integer;
  Compressed: TMessageArray;
begin
  if Length(Messages) <= GMinMessagesKeep then
    Exit;
  
  { Keep first message (system), last user message, and last few messages }
  KeepStart := Length(Messages) - GMinMessagesKeep;
  if KeepStart < 1 then
    KeepStart := 1;
  
  NewLen := 1 + GMinMessagesKeep; { system + last messages }
  SetLength(Compressed, NewLen);
  
  { Keep system message }
  Compressed[0] := Messages[0];
  
  { Add summary message }
  Compressed[1].Role := ruSystem;
  Compressed[1].TextContent := '[Previous context was compressed. Key information preserved.]';
  Compressed[1].HasToolUse := False;
  Compressed[1].HasToolResult := False;
  
  { Copy last messages }
  for i := 1 to GMinMessagesKeep - 1 do
  begin
    if KeepStart + i - 1 < Length(Messages) then
      Compressed[i + 1] := Messages[KeepStart + i - 1];
  end;
  
  Messages := Compressed;
  Inc(GContextState.CompressionCount);
  GContextState.LastCompression := GContextState.CompressionCount;
end;

procedure TriggerReactiveCompression(var Messages: TMessageArray);
begin
  { Emergency compression - keep only essential messages }
  if Length(Messages) > 0 then
  begin
    { Keep system message }
    SetLength(Messages, 3);
    Messages[1].Role := ruSystem;
    Messages[1].TextContent := '[Context collapsed due to API error. Please continue with minimal context.]';
    Messages[1].HasToolUse := False;
    Messages[1].HasToolResult := False;
    Messages[2].Role := ruUser;
    Messages[2].TextContent := 'Continue';
    Messages[2].HasToolUse := False;
    Messages[2].HasToolResult := False;
  end;
  
  Inc(GContextState.CompressionCount);
  GContextState.LastCompression := GContextState.CompressionCount;
end;

function IsContextError(const ErrorMsg: string; StatusCode: Integer): Boolean;
begin
  Result := False;
  
  { Check HTTP status codes }
  if (StatusCode = 413) or (StatusCode = 400) then
  begin
    Result := True;
    Exit;
  end;
  
  { Check error message patterns }
  if Pos('too long', LowerCase(ErrorMsg)) > 0 then
    Result := True
  else if Pos('context', LowerCase(ErrorMsg)) > 0 then
    Result := True
  else if Pos('prompt', LowerCase(ErrorMsg)) > 0 then
    Result := True
  else if Pos('token', LowerCase(ErrorMsg)) > 0 then
    Result := True;
end;

function ExtractErrorReason(const ErrorMsg: string): string;
begin
  if Pos('413', ErrorMsg) > 0 then
    Result := 'Request payload too large'
  else if Pos('400', ErrorMsg) > 0 then
    Result := 'Bad request - possibly context too long'
  else if Pos('too long', LowerCase(ErrorMsg)) > 0 then
    Result := 'Prompt exceeds model context limit'
  else if Pos('max_tokens', LowerCase(ErrorMsg)) > 0 then
    Result := 'Output token limit reached'
  else
    Result := 'Unknown context error';
end;

end.