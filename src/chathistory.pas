{
  Chat History Manager - Ultra Simple Global approach.
  Using global variables and procedures instead of class to avoid memory issues.
}
unit chathistory;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

var
  { Global chat history state }
  ChatHistory_Roles: array[0..19] of Integer;  { 0=user, 1=assistant, 2=system }
  ChatHistory_Content: array[0..19] of string;
  ChatHistory_Count: Integer;

procedure ChatHistory_Init;
procedure ChatHistory_AddMessage(ARole: Integer; const Content: string);
procedure ChatHistory_AddToolUse(const ToolName, ToolID, ToolInput: string);
procedure ChatHistory_AddToolResult(const ToolID, Result: string);
procedure ChatHistory_AddToolResultError(const ToolID, Error: string);
procedure ChatHistory_Clear;
function ChatHistory_GetMessages: TMessageArray;
function ChatHistory_GetMessagesForLMStudio(IncludeTools: Boolean): TMessageArray;
procedure ChatHistory_Reset;
procedure ChatHistory_SaveToFile(const AFilename: string);
function ChatHistory_LoadFromFile(const AFilename: string): Boolean;

implementation

procedure ChatHistory_Init;
var
  i: Integer;
begin
  for i := 0 to 19 do
  begin
    ChatHistory_Roles[i] := 0;
    ChatHistory_Content[i] := '';
  end;
  ChatHistory_Count := 0;
end;

procedure ChatHistory_AddMessage(ARole: Integer; const Content: string);
begin
  if ChatHistory_Count >= 20 then Exit;
  ChatHistory_Roles[ChatHistory_Count] := ARole;
  ChatHistory_Content[ChatHistory_Count] := Content;
  Inc(ChatHistory_Count);
end;

procedure ChatHistory_AddToolUse(const ToolName, ToolID, ToolInput: string);
begin
  if ChatHistory_Count >= 20 then Exit;
  ChatHistory_Roles[ChatHistory_Count] := 1; { ruAssistant }
  ChatHistory_Content[ChatHistory_Count] := 'TOOL_USE:' + ToolName + ':' + ToolID + ':' + ToolInput;
  Inc(ChatHistory_Count);
end;

procedure ChatHistory_AddToolResult(const ToolID, Result: string);
begin
  if ChatHistory_Count >= 20 then Exit;
  ChatHistory_Roles[ChatHistory_Count] := 0; { ruUser }
  ChatHistory_Content[ChatHistory_Count] := 'TOOL_RESULT:' + ToolID + ':' + Result;
  Inc(ChatHistory_Count);
end;

procedure ChatHistory_AddToolResultError(const ToolID, Error: string);
begin
  if ChatHistory_Count >= 20 then Exit;
  ChatHistory_Roles[ChatHistory_Count] := 0; { ruUser }
  ChatHistory_Content[ChatHistory_Count] := 'TOOL_RESULT_ERROR:' + ToolID + ':' + Error;
  Inc(ChatHistory_Count);
end;

procedure ChatHistory_Clear;
var
  i: Integer;
begin
  for i := 0 to 19 do
  begin
    ChatHistory_Roles[i] := 0;
    ChatHistory_Content[i] := '';
  end;
  ChatHistory_Count := 0;
end;

function ChatHistory_GetMessages: TMessageArray;
var
  i: Integer;
begin
  SetLength(Result, ChatHistory_Count);
  for i := 0 to ChatHistory_Count - 1 do
  begin
    Result[i].Role := TRole(ChatHistory_Roles[i]);
    Result[i].TextContent := ChatHistory_Content[i];
    Result[i].HasToolUse := False;
    Result[i].HasToolResult := False;
  end;
end;

function ChatHistory_GetMessagesForLMStudio(IncludeTools: Boolean): TMessageArray;
var
  HasDummy: Boolean;
  k, NewLen: Integer;
  NewMsg: TMessageArray;
begin
  Result := ChatHistory_GetMessages;
  if IncludeTools and (Length(Result) > 0) and (Result[0].Role <> ruUser) then
  begin
    HasDummy := False;
    for k := 0 to Length(Result)-1 do
      if (Result[k].Role = ruUser) and (Result[k].TextContent = 'Continue') then 
        HasDummy := True;
    if not HasDummy then
    begin
      NewLen := Length(Result) + 1;
      SetLength(NewMsg, NewLen);
      NewMsg[0].Role := ruUser;
      NewMsg[0].TextContent := 'Continue';
      for k := 0 to Length(Result)-1 do 
        NewMsg[k+1] := Result[k];
      Result := NewMsg;
    end;
  end;
end;

procedure ChatHistory_Reset;
begin
  ChatHistory_Clear;
end;

procedure ChatHistory_SaveToFile(const AFilename: string);
var
  F: TextFile;
  i: Integer;
  s: string;
begin
  AssignFile(F, AFilename);
  Rewrite(F);
  try
    for i := 0 to ChatHistory_Count - 1 do
    begin
      case ChatHistory_Roles[i] of
        0: s := 'USER';
        1: s := 'ASSISTANT';
        2: s := 'SYSTEM';
      end;
      WriteLn(F, s + ': ', ChatHistory_Content[i]);
    end;
  finally 
    CloseFile(F); 
  end;
end;

function ChatHistory_LoadFromFile(const AFilename: string): Boolean;
var
  F: TextFile;
  Line, Content: string;
  Role: Integer;
  ColonPos: Integer;
begin
  Result := False;
  
  if not FileExists(AFilename) then
    Exit;
    
  ChatHistory_Clear;
  
  AssignFile(F, AFilename);
  Reset(F);
  try
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      
      if Line = '' then
        Continue;
        
      { Parse role prefix }
      if Pos('USER: ', Line) = 1 then
      begin
        Role := 0;
        Content := Copy(Line, 7, Length(Line) - 6);
      end
      else if Pos('ASSISTANT: ', Line) = 1 then
      begin
        Role := 1;
        Content := Copy(Line, 12, Length(Line) - 11);
      end
      else if Pos('SYSTEM: ', Line) = 1 then
      begin
        Role := 2;
        Content := Copy(Line, 9, Length(Line) - 8);
      end
      else
        Continue; { Unknown format, skip line }
        
      ChatHistory_AddMessage(Role, Content);
    end;
    
    Result := True;
  finally
    CloseFile(F);
  end;
end;

end.