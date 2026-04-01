{
  LLM Client - Generic HTTP API support with Tool support.
}
unit llmclient;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, httpclient, types;

type
  TLLMFormat = (
    lfOpenAI,
    lfOllama,
    lfLlamaCpp
  );

  TToolDef = record
    Name: string;
    Description: string;
    Parameters: string;
  end;
  TToolDefArray = array of TToolDef;

  TLLMClient = class
  private
    FHTTPClient: THTTPClient;
    FConfig: TLLMConfig;
    FFormat: TLLMFormat;
    FTools: TToolDefArray;
    function GetAPIPath: string;
    function BuildRequestBody(const Messages: TMessageArray; IncludeTools: Boolean = True): string;
    function ParseResponse(const ResponseJSON: string): TLLMResponse;
    function ParseOpenAIResponse(const JSON: string): TLLMResponse;
    function ParseOllamaResponse(const JSON: string): TLLMResponse;
    function ExtractJSONValue(const JSON, Key: string): string;
    function ExtractJSONValueFromPos(const JSON: string; StartPos: Integer; const Key: string): string;
    function FindKeyPosition(const JSON, Key: string): Integer;
  public
    constructor Create(const AConfig: TLLMConfig; AFormat: TLLMFormat = lfOpenAI);
    destructor Destroy; override;
    procedure SetTools(const Tools: TToolDefArray);
    function Chat(const Messages: TMessageArray; IncludeTools: Boolean = True): TLLMResponse;
    function RoleToString(Role: TRole): string;
  end;

implementation

constructor TLLMClient.Create(const AConfig: TLLMConfig; AFormat: TLLMFormat);
begin
  inherited Create;
  FConfig := AConfig;
  FFormat := AFormat;
  FHTTPClient := THTTPClient.Create(AConfig.BaseURL, AConfig.APIKey);
  SetLength(FTools, 0);
end;

destructor TLLMClient.Destroy;
begin
  SetLength(FTools, 0);
  FreeAndNil(FHTTPClient);
  inherited Destroy;
end;

procedure TLLMClient.SetTools(const Tools: TToolDefArray);
begin
  FTools := Tools;
end;

function TLLMClient.GetAPIPath: string;
begin
  case FFormat of
    lfOpenAI, lfLlamaCpp: 
    begin
      { Check if base URL already contains /v1 }
      if Pos('/v1', FConfig.BaseURL) > 0 then
        Result := '/chat/completions'
      else
        Result := '/v1/chat/completions';
    end;
    lfOllama: Result := '/api/chat';
  end;
end;

function TLLMClient.RoleToString(Role: TRole): string;
begin
  case Role of
    ruUser: Result := 'user';
    ruAssistant: Result := 'assistant';
    ruSystem: Result := 'system';
  end;
end;

function TLLMClient.BuildRequestBody(const Messages: TMessageArray; IncludeTools: Boolean = True): string;
var
  i: Integer;
  JSONBody, RoleStr, ContentStr: string;
begin
  JSONBody := '{"model":"' + FConfig.Model + '","stream":false';
  
  if FConfig.Temperature > 0 then
    JSONBody := JSONBody + ',"temperature":' + FloatToStr(FConfig.Temperature);
  if FConfig.MaxTokens > 0 then
    JSONBody := JSONBody + ',"max_tokens":' + IntToStr(FConfig.MaxTokens);
  
  { Tools - only include if requested and there are tools }
  if IncludeTools and (Length(FTools) > 0) then
  begin
    JSONBody := JSONBody + ',"tools":[';
    for i := Low(FTools) to High(FTools) do
    begin
      { Skip empty tool names }
      if FTools[i].Name = '' then
        Continue;
      if i > Low(FTools) then
        JSONBody := JSONBody + ',';
      JSONBody := JSONBody + '{"type":"function","function":{"name":"' + FTools[i].Name + '",' +
        '"description":"' + StringReplace(FTools[i].Description, '"', '\"', [rfReplaceAll]) + '",' +
        '"parameters":' + FTools[i].Parameters + '}}';
    end;
    JSONBody := JSONBody + ']';
  end;
  
  { Messages }
  JSONBody := JSONBody + ',"messages":[';
  for i := Low(Messages) to High(Messages) do
  begin
    if i > Low(Messages) then
      JSONBody := JSONBody + ',';
      
    RoleStr := RoleToString(Messages[i].Role);
    
    { Build content based on message type }
    ContentStr := Messages[i].TextContent;
    
    if Messages[i].HasToolUse then
    begin
      { Tool use message - plain text format - unescape the input }
      ContentStr := 'Executed tool: ' + Messages[i].ToolUseBlock.ToolName + 
        ' with input: ' + StringReplace(Messages[i].ToolUseBlock.Input_, '\"', '"', [rfReplaceAll]);
      { Escape for JSON }
      ContentStr := StringReplace(ContentStr, '\', '\\', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, '"', '\"', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #10, '\n', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #13, '\r', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #9, '\t', [rfReplaceAll]);
      ContentStr := '"' + ContentStr + '"';
    end
    else if Messages[i].HasToolResult then
    begin
      { Tool result message - plain text format }
      if Messages[i].ToolResultBlock.IsError then
        ContentStr := 'Error: ' + Messages[i].ToolResultBlock.Content
      else
        ContentStr := 'Result: ' + Messages[i].ToolResultBlock.Content;
      { Escape for JSON }
      ContentStr := StringReplace(ContentStr, '\', '\\', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, '"', '\"', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #10, '\n', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #13, '\r', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #9, '\t', [rfReplaceAll]);
      ContentStr := '"' + ContentStr + '"';
    end
    else
    begin
      { Escape newlines, tabs, and other control characters for valid JSON }
      ContentStr := StringReplace(Messages[i].TextContent, '\', '\\', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, '"', '\"', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #10, '\n', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #13, '\r', [rfReplaceAll]);
      ContentStr := StringReplace(ContentStr, #9, '\t', [rfReplaceAll]);
      ContentStr := '"' + ContentStr + '"';
    end;
    
    JSONBody := JSONBody + '{"role":"' + RoleStr + '","content":' + ContentStr + '}';
  end;
  
  JSONBody := JSONBody + ']}';
  Result := JSONBody;
end;

function TLLMClient.FindKeyPosition(const JSON, Key: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 1 to Length(JSON) - Length(Key) + 1 do
  begin
    if Copy(JSON, i, Length(Key)) = Key then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

{ Extract a JSON value starting from a specific position }
function TLLMClient.ExtractJSONValueFromPos(const JSON: string; StartPos: Integer; const Key: string): string;
var
  KeyPos, ValueStart, ValueEnd, BracketCount: Integer;
  InString: Boolean;
begin
  Result := '';
  
  { Find the key within the search range }
  KeyPos := 0;
  for ValueStart := StartPos to Length(JSON) - Length(Key) + 1 do
  begin
    if Copy(JSON, ValueStart, Length(Key) + 2) = '"' + Key + '"' then
    begin
      KeyPos := ValueStart;
      Break;
    end;
  end;
  
  if KeyPos = 0 then
    Exit;
  
  { Find the colon after the key }
  ValueStart := KeyPos + Length(Key) + 2;
  while ValueStart <= Length(JSON) do
  begin
    if JSON[ValueStart] = ':' then
    begin
      Inc(ValueStart);
      while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
        Inc(ValueStart);
      Break;
    end;
    Inc(ValueStart);
  end;
  
  if ValueStart > Length(JSON) then
    Exit;
  
  { Extract value based on type }
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
  else if JSON[ValueStart] = '{' then
  begin
    BracketCount := 1;
    ValueEnd := ValueStart + 1;
    while (ValueEnd <= Length(JSON)) and (BracketCount > 0) do
    begin
      if JSON[ValueEnd] = '{' then
        Inc(BracketCount)
      else if JSON[ValueEnd] = '}' then
        Dec(BracketCount);
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

function TLLMClient.ExtractJSONValue(const JSON, Key: string): string;
var
  KeyPos, ValueStart, ValueEnd, i: Integer;
  InString: Boolean;
  BracketCount: Integer;
begin
  Result := '';
  KeyPos := FindKeyPosition(JSON, '"' + Key + '"');
  if KeyPos = 0 then
    Exit;
  
  ValueStart := KeyPos + Length(Key) + 3;
  while ValueStart <= Length(JSON) do
  begin
    if JSON[ValueStart] = ':' then
    begin
      Inc(ValueStart);
      while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
        Inc(ValueStart);
      Break;
    end;
    Inc(ValueStart);
  end;
    
  if ValueStart > Length(JSON) then
    Exit;
  
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
  else if JSON[ValueStart] = '{' then
  begin
    { Object - extract as-is }
    BracketCount := 1;
    ValueEnd := ValueStart + 1;
    while (ValueEnd <= Length(JSON)) and (BracketCount > 0) do
    begin
      if JSON[ValueEnd] = '{' then
        Inc(BracketCount)
      else if JSON[ValueEnd] = '}' then
        Dec(BracketCount);
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

function TLLMClient.ParseOpenAIResponse(const JSON: string): TLLMResponse;
var
  ToolCallsStart, ToolCallObjStart: Integer;
  RawStopReason: string;
  ContentValue: string;
begin
  Result.Content := '';
  Result.Thinking := '';
  Result.ToolCallName := '';
  Result.ToolCallID := '';
  Result.ToolCallInput := '';
  Result.HasToolCall := False;
  Result.ResponseType := rtNone;
  Result.StopReason := srUnknown;
  Result.StopReasonRaw := '';
  Result.UsageInputTokens := 0;
  Result.UsageOutputTokens := 0;
  
  // Check for tool_calls first
  ToolCallsStart := FindKeyPosition(JSON, 'tool_calls');
  if ToolCallsStart > 0 then
  begin
    // Tool call detected - set stop reason accordingly
    Result.StopReason := srToolUse;
    Result.StopReasonRaw := 'tool_calls';
    
    // Find the first { in the tool_calls array
    ToolCallObjStart := ToolCallsStart;
    while (ToolCallObjStart <= Length(JSON)) and (JSON[ToolCallObjStart] <> '{') do
      Inc(ToolCallObjStart);
    
    if ToolCallObjStart <= Length(JSON) then
    begin
      // Extract tool_call object
      Result.ToolCallID := ExtractJSONValueFromPos(JSON, ToolCallObjStart, 'id');
      Result.ToolCallName := ExtractJSONValueFromPos(JSON, ToolCallObjStart, 'name');
      Result.ToolCallInput := ExtractJSONValueFromPos(JSON, ToolCallObjStart, 'arguments');
      Result.HasToolCall := (Result.ToolCallName <> '');
    end;
  end
  else
  begin
    if FindKeyPosition(JSON, '"choices"') = 0 then
      Exit;
    if FindKeyPosition(JSON, '"message"') = 0 then
      Exit;
    Result.Content := ExtractJSONValue(JSON, 'content');
    
    // Strip <end_of_turn> marker if present
    if Pos('<end_of_turn>', Result.Content) > 0 then
    begin
      Result.Content := Copy(Result.Content, 1, Pos('<end_of_turn>', Result.Content) - 1);
    end;
    
    // Check for tool call in content (Qwen3 format: [{"name": "...", "arguments": {...}}])
    if (Result.Content <> '') and (Length(Result.Content) > 2) then
    begin
      // Look for pattern [{"name": ...}] or similar
      if (Result.Content[1] = '[') then
      begin
        // Find first { after [
        ToolCallObjStart := 1;
        while ToolCallObjStart <= Length(Result.Content) do
        begin
          if Result.Content[ToolCallObjStart] = '{' then
            Break;
          Inc(ToolCallObjStart);
        end;
        
        // Check if there's a "name" key nearby (within first 50 chars after {)
        if (ToolCallObjStart <= Length(Result.Content)) and 
           (Pos('"name"', Copy(Result.Content, ToolCallObjStart, 50)) > 0) then
        begin
          Result.ToolCallName := ExtractJSONValueFromPos(Result.Content, ToolCallObjStart, 'name');
          Result.ToolCallInput := ExtractJSONValueFromPos(Result.Content, ToolCallObjStart, 'arguments');
          if Result.ToolCallName <> '' then
          begin
            Result.HasToolCall := True;
            Result.StopReason := srToolUse;
            Result.StopReasonRaw := 'tool_calls';
            Result.Content := ''; // Clear content since it's a tool call
          end;
        end;
      end;
    end;
    
    // Parse stop reason
    RawStopReason := ExtractJSONValue(JSON, 'finish_reason');
    Result.StopReasonRaw := RawStopReason;
    Result.StopReason := ParseStopReason(RawStopReason);
  end;
  
  Result.UsageInputTokens := StrToIntDef(ExtractJSONValue(JSON, 'prompt_tokens'), 0);
  Result.UsageOutputTokens := StrToIntDef(ExtractJSONValue(JSON, 'completion_tokens'), 0);
  
  { Determine response type }
  Result.ResponseType := DetermineResponseType(Result);
end;

function TLLMClient.ParseOllamaResponse(const JSON: string): TLLMResponse;
var
  ToolCallsPos: Integer;
  RawStopReason: string;
begin
  Result.Content := '';
  Result.Thinking := '';
  Result.ToolCallName := '';
  Result.ToolCallID := '';
  Result.ToolCallInput := '';
  Result.HasToolCall := False;
  Result.ResponseType := rtNone;
  Result.StopReason := srStop;
  Result.StopReasonRaw := 'stop';
  Result.UsageInputTokens := 0;
  Result.UsageOutputTokens := 0;
  
  if FindKeyPosition(JSON, '"message"') = 0 then
    Exit;
  
  // Check for tool_calls first
  ToolCallsPos := FindKeyPosition(JSON, 'tool_calls');
  if ToolCallsPos > 0 then
  begin
    // Tool call detected
    Result.StopReason := srToolUse;
    Result.StopReasonRaw := 'tool_calls';
    
    // Extract from tool_calls array
    Result.ToolCallName := ExtractJSONValue(JSON, 'name');
    Result.ToolCallID := ExtractJSONValue(JSON, 'id');
    Result.ToolCallInput := ExtractJSONValue(JSON, 'arguments');
    Result.HasToolCall := (Result.ToolCallName <> '');
  end
  else
  begin
    Result.Content := ExtractJSONValue(JSON, 'content');
    
    // Ollama doesn't always send stop reason, check for 'done' field
    RawStopReason := ExtractJSONValue(JSON, 'done_reason');
    if RawStopReason <> '' then
    begin
      Result.StopReasonRaw := RawStopReason;
      Result.StopReason := ParseStopReason(RawStopReason);
    end;
  end;
  
  { Determine response type }
  Result.ResponseType := DetermineResponseType(Result);
end;

function TLLMClient.ParseResponse(const ResponseJSON: string): TLLMResponse;
begin
  case FFormat of
    lfOpenAI, lfLlamaCpp: Result := ParseOpenAIResponse(ResponseJSON);
    lfOllama: Result := ParseOllamaResponse(ResponseJSON);
  end;
end;

function TLLMClient.Chat(const Messages: TMessageArray; IncludeTools: Boolean): TLLMResponse;
var
  Body: string;
  Response: string;
begin
  Body := BuildRequestBody(Messages, IncludeTools);
  Response := FHTTPClient.PostJSON(GetAPIPath, Body);
  Result := ParseResponse(Response);
end;

end.