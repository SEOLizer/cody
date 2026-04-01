{
  Tool Permission System - Manages tool execution permissions.
  Implements auto-approve for read-only tools and confirmation for write operations.
}
unit tool_permissions;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  { Tool categories for permission handling }
  TToolCategory = (
    tcRead,       { Read-only tools: Read, Glob, Grep, FileTree, Diff, TaskList }
    tcWrite,      { Write tools: Write, Edit, Mkdir, Delete, Move }
    tcExecute,    { Execute tools: Bash }
    tcSystem      { System tools: Init, TaskCreate, TaskUpdate, Agent }
  );

  { Permission modes }
  TPermissionMode = (
    pmAuto,       { Auto-approve safe operations, confirm dangerous ones }
    pmAsk,        { Ask for confirmation on all operations }
    pmStrict      { Block all potentially dangerous operations }
  );

  { Permission result }
  TPermissionResult = (
    prAllowed,    { Operation allowed }
    prDenied,     { Operation denied }
    prAsk         { Needs user confirmation }
  );

var
  { Global permission settings }
  GPermissionMode: TPermissionMode = pmAuto;
  GAutoApproveRead: Boolean = True;
  GAutoApproveWrite: Boolean = False;

{ Get tool category by tool name }
function GetToolCategory(const ToolName: string): TToolCategory;

{ Check if tool is auto-approved (read-only) }
function IsAutoApproved(const ToolName: string): Boolean;

{ Check if tool requires confirmation }
function RequiresConfirmation(const ToolName: string): Boolean;

{ Check if tool is allowed under current permission settings }
function CheckToolPermission(const ToolName: string; const InputJSON: string): TPermissionResult;

{ Sanitize command - remove dangerous patterns }
function SanitizeCommand(const Command: string): string;

{ Check if command contains dangerous patterns }
function IsCommandDangerous(const Command: string): Boolean;

implementation

{ Map tool name to category }
function GetToolCategory(const ToolName: string): TToolCategory;
var
  Name: string;
begin
  Name := LowerCase(ToolName);
  
  { Read-only tools }
  if (Name = 'read') or (Name = 'glob') or (Name = 'grep') or 
     (Name = 'filetree') or (Name = 'diff') or (Name = 'tasklist') then
    Result := tcRead
  { Write tools }
  else if (Name = 'write') or (Name = 'edit') or (Name = 'mkdir') or 
          (Name = 'delete') or (Name = 'move') then
    Result := tcWrite
  { Execute tools }
  else if (Name = 'bash') then
    Result := tcExecute
  { System tools }
  else if (Name = 'init') or (Name = 'taskcreate') or (Name = 'taskupdate') or 
          (Name = 'agent') then
    Result := tcSystem
  { Default to write for unknown tools }
  else
    Result := tcWrite;
end;

{ Check if tool is auto-approved }
function IsAutoApproved(const ToolName: string): Boolean;
var
  Category: TToolCategory;
begin
  Category := GetToolCategory(ToolName);
  
  case Category of
    tcRead:
      Result := GAutoApproveRead;
    tcWrite:
      Result := GAutoApproveWrite;
    tcExecute, tcSystem:
      Result := False;  { Never auto-approve dangerous tools }
  else
    Result := False;
  end;
end;

{ Check if tool requires confirmation }
function RequiresConfirmation(const ToolName: string): Boolean;
var
  Category: TToolCategory;
begin
  Category := GetToolCategory(ToolName);
  
  case GPermissionMode of
    pmAuto:
      case Category of
        tcRead:    Result := not GAutoApproveRead;
        tcWrite:   Result := not GAutoApproveWrite;
        tcExecute, tcSystem: Result := True;
      else
        Result := True;
      end;
    pmAsk:
      Result := True;
    pmStrict:
      Result := True;
  else
    Result := True;
  end;
end;

{ Main permission check function }
function CheckToolPermission(const ToolName: string; const InputJSON: string): TPermissionResult;
var
  Category: TToolCategory;
begin
  Category := GetToolCategory(ToolName);
  
  case GPermissionMode of
    pmAuto:
    begin
      { Auto mode: allow read-only, ask for write/execute }
      if Category = tcRead then
        Result := prAllowed
      else if IsAutoApproved(ToolName) then
        Result := prAllowed
      else
        Result := prAsk;
    end;
    pmAsk:
    begin
      { Ask mode: always ask }
      Result := prAsk;
    end;
    pmStrict:
    begin
      { Strict mode: only allow read-only }
      if Category = tcRead then
        Result := prAllowed
      else
        Result := prDenied;
    end;
  else
    Result := prDenied;
  end;
  
  { Additional check for dangerous commands in Bash tool }
  if (Result = prAllowed) and (Category = tcExecute) then
  begin
    if IsCommandDangerous(InputJSON) then
      Result := prDenied;
  end;
end;

{ Check if command contains dangerous patterns }
function IsCommandDangerous(const Command: string): Boolean;
var
  Cmd: string;
begin
  Cmd := LowerCase(Command);
  Result := False;
  
  { Check for command chaining that could be dangerous }
  if (Pos('; rm', Cmd) > 0) or (Pos(';rm', Cmd) > 0) or
     (Pos('; rmdir', Cmd) > 0) or (Pos(';rmdir', Cmd) > 0) or
     (Pos('&& rm', Cmd) > 0) or (Pos('&&rm', Cmd) > 0) or
     (Pos('|| rm', Cmd) > 0) or (Pos('||rm', Cmd) > 0) then
  begin
    Result := True;
    Exit;
  end;
  
  { Check for pipe to shell }
  if (Pos('| sh', Cmd) > 0) or (Pos('|sh', Cmd) > 0) or
     (Pos('| bash', Cmd) > 0) or (Pos('|bash', Cmd) > 0) or
     (Pos('| zsh', Cmd) > 0) or (Pos('|zsh', Cmd) > 0) then
  begin
    Result := True;
    Exit;
  end;
  
  { Check for dangerous commands }
  if (Pos('curl ', Cmd) > 0) or (Pos('wget ', Cmd) > 0) or
     (Pos('nc ', Cmd) > 0) or (Pos('netcat', Cmd) > 0) or
     (Pos('ssh ', Cmd) > 0) or (Pos('scp ', Cmd) > 0) or
     (Pos('mkfs', Cmd) > 0) or (Pos('dd if=', Cmd) > 0) then
  begin
    Result := True;
    Exit;
  end;
end;

{ Sanitize command - remove dangerous patterns }
function SanitizeCommand(const Command: string): string;
var
  Cmd: string;
begin
  Result := Command;
  
  { Check if dangerous - return empty if so }
  if IsCommandDangerous(Command) then
  begin
    Result := '';
    Exit;
  end;
  
  { Remove backticks and $() which could be command substitution }
  Cmd := Result;
  Cmd := StringReplace(Cmd, '`', '', [rfReplaceAll]);
  while Pos('$()', Cmd) > 0 do
    Delete(Cmd, Pos('$()', Cmd), 3);
  Result := Cmd;
end;

end.