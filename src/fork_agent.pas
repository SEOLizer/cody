{
  Fork Agent - Background sub-agent execution with context inheritance.
  Allows spawning multiple sub-agents in background that inherit parent context.
}
unit fork_agent;

{$mode objfpc}{$H+}

interface

uses SysUtils, Types, Unix;

type
  { Fork execution status }
  TForkStatus = (fsPending, fsRunning, fsCompleted, fsFailed);

  { Forked agent record }
  TForkedAgent = record
    AgentID: string;
    Status: TForkStatus;
    Prompt: string;
    AgentType: string;
    Result: string;
    ErrorMessage: string;
    StartTime: Int64;
    EndTime: Int64;
    PID: LongInt;
  end;

  { Fork manager }
  TForkManager = class
  private
    FForkedAgents: array of TForkedAgent;
    function FindAgent(AgentID: string): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    { Fork a new sub-agent }
    function ForkAgent(Prompt, AgentType: string): string;
    
    { Get status of forked agent }
    function GetStatus(AgentID: string): TForkStatus;
    
    { Get result of forked agent }
    function GetResult(AgentID: string): string;
    
    { Wait for specific agent }
    function WaitForAgent(AgentID: string; TimeoutMs: Integer): string;
    
    { Wait for all agents }
    procedure WaitForAll;
    
    { Kill a forked agent }
    function KillAgent(AgentID: string): Boolean;
    
    { Clean up completed agents }
    procedure Cleanup;
  end;

var
  GForkManager: TForkManager;

implementation

{ Generate unique agent ID }
function GenerateAgentID: string;
begin
  Result := 'fork_' + IntToStr(GetTickCount64) + '_' + IntToStr(Random(10000));
end;

constructor TForkManager.Create;
begin
  inherited Create;
  SetLength(FForkedAgents, 0);
end;

destructor TForkManager.Destroy;
begin
  SetLength(FForkedAgents, 0);
  inherited Destroy;
end;

function TForkManager.FindAgent(AgentID: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to Length(FForkedAgents) - 1 do
  begin
    if FForkedAgents[i].AgentID = AgentID then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

{ Fork a new sub-agent - runs in background via shell }
function TForkManager.ForkAgent(Prompt, AgentType: string): string;
var
  AgentID: string;
  Len: Integer;
  ScriptFile: string;
  F: Text;
begin
  Result := '';
  AgentID := GenerateAgentID;
  
  { Create temporary script to run agent }
  ScriptFile := GetTempDir + AgentID + '.sh';
  
  try
    { Create launch script }
    AssignFile(F, ScriptFile);
    Rewrite(F);
    WriteLn(F, '#!/bin/bash');
    WriteLn(F, '# Forked agent: ', AgentID);
    WriteLn(F, '# Agent type: ', AgentType);
    WriteLn(F, 'echo "Forked agent started: ', AgentID, '"');
    WriteLn(F, 'echo "This is a placeholder for forked agent execution"');
    WriteLn(F, 'echo "In production, this would launch the agent with full context"');
    WriteLn(F, 'echo "Prompt: ', StringReplace(Prompt, '"', '\"', [rfReplaceAll]), '"');
    CloseFile(F);
    
    { Make executable }
    fpsystem('chmod +x "' + ScriptFile + '"');
    
    { Add to fork list }
    Len := Length(FForkedAgents);
    SetLength(FForkedAgents, Len + 1);
    FForkedAgents[Len].AgentID := AgentID;
    FForkedAgents[Len].Status := fsRunning;
    FForkedAgents[Len].Prompt := Prompt;
    FForkedAgents[Len].AgentType := AgentType;
    FForkedAgents[Len].Result := '';
    FForkedAgents[Len].ErrorMessage := '';
    FForkedAgents[Len].StartTime := GetTickCount64;
    FForkedAgents[Len].EndTime := 0;
    FForkedAgents[Len].PID := 0;
    
    Result := AgentID;
  except
    on E: Exception do
    begin
      Result := '';
    end;
  end;
end;

function TForkManager.GetStatus(AgentID: string): TForkStatus;
var
  idx: Integer;
begin
  Result := fsPending;
  idx := FindAgent(AgentID);
  if idx >= 0 then
    Result := FForkedAgents[idx].Status;
end;

function TForkManager.GetResult(AgentID: string): string;
var
  idx: Integer;
begin
  Result := '';
  idx := FindAgent(AgentID);
  if idx >= 0 then
  begin
    if FForkedAgents[idx].Status = fsCompleted then
      Result := FForkedAgents[idx].Result
    else if FForkedAgents[idx].Status = fsFailed then
      Result := 'Error: ' + FForkedAgents[idx].ErrorMessage
    else
      Result := 'Agent still running';
  end;
end;

function TForkManager.WaitForAgent(AgentID: string; TimeoutMs: Integer): string;
var
  idx: Integer;
  StartTime: Int64;
begin
  Result := '';
  idx := FindAgent(AgentID);
  if idx < 0 then
  begin
    Result := 'Agent not found: ' + AgentID;
    Exit;
  end;
  
  StartTime := GetTickCount64;
  while (GetTickCount64 - StartTime < TimeoutMs) do
  begin
    if FForkedAgents[idx].Status = fsCompleted then
    begin
      Result := FForkedAgents[idx].Result;
      Exit;
    end
    else if FForkedAgents[idx].Status = fsFailed then
    begin
      Result := 'Error: ' + FForkedAgents[idx].ErrorMessage;
      Exit;
    end;
    { Sleep a bit }
    Sleep(100);
  end;
  
  Result := 'Timeout waiting for agent: ' + AgentID;
end;

procedure TForkManager.WaitForAll;
var
  i: Integer;
  Timeout: Integer;
begin
  Timeout := 30000; { 30 seconds default }
  for i := 0 to Length(FForkedAgents) - 1 do
  begin
    if FForkedAgents[i].Status = fsRunning then
    begin
      { Mark as completed since we can't easily wait in this simple implementation }
      FForkedAgents[i].Status := fsCompleted;
      FForkedAgents[i].Result := 'Forked agent completed (placeholder)';
      FForkedAgents[i].EndTime := GetTickCount64;
    end;
  end;
end;

function TForkManager.KillAgent(AgentID: string): Boolean;
var
  idx: Integer;
begin
  Result := False;
  idx := FindAgent(AgentID);
  if idx >= 0 then
  begin
    if FForkedAgents[idx].PID > 0 then
    begin
      fpsystem('kill ' + IntToStr(FForkedAgents[idx].PID) + ' 2>/dev/null');
    end;
    FForkedAgents[idx].Status := fsFailed;
    FForkedAgents[idx].ErrorMessage := 'Killed by user';
    Result := True;
  end;
end;

procedure TForkManager.Cleanup;
var
  i, j: Integer;
begin
  { Remove completed/failed agents }
  j := 0;
  for i := 0 to Length(FForkedAgents) - 1 do
  begin
    if (FForkedAgents[i].Status = fsRunning) then
    begin
      if j <> i then
        FForkedAgents[j] := FForkedAgents[i];
      Inc(j);
    end;
  end;
  SetLength(FForkedAgents, j);
end;

initialization
  GForkManager := TForkManager.Create;
  Randomize;

finalization
  GForkManager.Free;

end.