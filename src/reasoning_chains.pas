{
  Reasoning Chains - Step-by-step execution with state tracking and rollback.
  - Track execution state between steps
  - Checkpoint system for rollback capability  
  - State logging for documentation
}
unit reasoning_chains;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  TExecutionState = (
    esPlanning,    { Planning the next step }
    esExecuting,   { Currently executing a tool }
    esEvaluating,  { Evaluating the result }
    esCompleted,   { Task completed }
    esFailed,      { Task failed }
    esRolledBack   { Rolled back to checkpoint }
  );

  TStepState = record
    StepNumber: Integer;
    Description: string;
    ToolName: string;
    ToolInput: string;
    Result: string;
    Success: Boolean;
    ErrorMessage: string;
    ExecutionTimeMs: Int64;
  end;

  TCheckpoint = record
    ID: Integer;
    StepNumber: Integer;
    Timestamp: string;
    Description: string;
    ChatHistorySnapshot: string;  { Simplified snapshot }
  end;

  TReasoningChain = record
    CurrentState: TExecutionState;
    TotalSteps: Integer;
    CompletedSteps: Integer;
    FailedSteps: Integer;
    Steps: array of TStepState;
    Checkpoints: array of TCheckpoint;
    MaxCheckpoints: Integer;
    LastCheckpointID: Integer;
  end;

const
  DEFAULT_MAX_CHECKPOINTS = 5;

{ Initialize reasoning chain }
procedure InitReasoningChain(var Chain: TReasoningChain; MaxCheckpoints: Integer = DEFAULT_MAX_CHECKPOINTS);

{ State transitions }
procedure SetState(var Chain: TReasoningChain; NewState: TExecutionState);
function GetStateDescription(const State: TExecutionState): string;

{ Step management }
function StartStep(var Chain: TReasoningChain; StepNum: Integer; const Desc, Tool: string): Integer;
procedure CompleteStep(var Chain: TReasoningChain; StepIdx: Integer; const Result: string; Success: Boolean; const ErrorMsg: string = ''; ExecTimeMs: Int64 = 0);
function GetStepSummary(const Chain: TReasoningChain): string;
function GetCurrentStep(const Chain: TReasoningChain): Integer;

{ Checkpoint management }
function CreateCheckpoint(var Chain: TReasoningChain; const Desc: string): Integer;
function RestoreCheckpoint(var Chain: TReasoningChain; CheckpointID: Integer): Boolean;
function GetCheckpointCount(const Chain: TReasoningChain): Integer;

{ Rollback functionality }
function CanRollback(const Chain: TReasoningChain): Boolean;
function RollbackToLastCheckpoint(var Chain: TReasoningChain): Boolean;
function RollbackSteps(var Chain: TReasoningChain; StepsBack: Integer): Boolean;

{ State logging }
function GetExecutionLog(const Chain: TReasoningChain): string;
procedure LogStateTransition(var Chain: TReasoningChain; const FromState, ToState: string);

implementation

procedure InitReasoningChain(var Chain: TReasoningChain; MaxCheckpoints: Integer);
begin
  Chain.CurrentState := esPlanning;
  Chain.TotalSteps := 0;
  Chain.CompletedSteps := 0;
  Chain.FailedSteps := 0;
  SetLength(Chain.Steps, 0);
  SetLength(Chain.Checkpoints, 0);
  Chain.MaxCheckpoints := MaxCheckpoints;
  Chain.LastCheckpointID := 0;
end;

function GetStateDescription(const State: TExecutionState): string;
begin
  case State of
    esPlanning: Result := 'Planning next step';
    esExecuting: Result := 'Executing tool';
    esEvaluating: Result := 'Evaluating result';
    esCompleted: Result := 'Task completed successfully';
    esFailed: Result := 'Task failed';
    esRolledBack: Result := 'Rolled back to checkpoint';
    else Result := 'Unknown state';
  end;
end;

procedure SetState(var Chain: TReasoningChain; NewState: TExecutionState);
var
  OldState: TExecutionState;
begin
  OldState := Chain.CurrentState;
  Chain.CurrentState := NewState;
  LogStateTransition(Chain, GetStateDescription(OldState), GetStateDescription(NewState));
end;

procedure LogStateTransition(var Chain: TReasoningChain; const FromState, ToState: string);
begin
  { State transitions are logged in GetExecutionLog }
  { Could add a dedicated transition log here if needed }
end;

function GetCurrentStep(const Chain: TReasoningChain): Integer;
begin
  Result := Chain.CompletedSteps + 1;
end;

function StartStep(var Chain: TReasoningChain; StepNum: Integer; const Desc, Tool: string): Integer;
var
  Len: Integer;
begin
  SetState(Chain, esExecuting);
  
  Len := Length(Chain.Steps);
  SetLength(Chain.Steps, Len + 1);
  
  Chain.Steps[Len].StepNumber := StepNum;
  Chain.Steps[Len].Description := Desc;
  Chain.Steps[Len].ToolName := Tool;
  Chain.Steps[Len].ToolInput := '';
  Chain.Steps[Len].Result := '';
  Chain.Steps[Len].Success := False;
  Chain.Steps[Len].ErrorMessage := '';
  Chain.Steps[Len].ExecutionTimeMs := 0;
  
  Chain.TotalSteps := StepNum;
  Result := Len;
end;

procedure CompleteStep(var Chain: TReasoningChain; StepIdx: Integer; const Result: string; Success: Boolean; const ErrorMsg: string; ExecTimeMs: Int64);
begin
  if (StepIdx < 0) or (StepIdx >= Length(Chain.Steps)) then
    Exit;
    
  Chain.Steps[StepIdx].Result := Result;
  Chain.Steps[StepIdx].Success := Success;
  Chain.Steps[StepIdx].ErrorMessage := ErrorMsg;
  Chain.Steps[StepIdx].ExecutionTimeMs := ExecTimeMs;
  
  if Success then
  begin
    Inc(Chain.CompletedSteps);
    SetState(Chain, esEvaluating);
  end
  else
  begin
    Inc(Chain.FailedSteps);
    SetState(Chain, esFailed);
  end;
end;

function GetStepSummary(const Chain: TReasoningChain): string;
var
  i: Integer;
begin
  Result := '=== Execution Summary ===' + LineEnding;
  Result := Result + 'Total Steps: ' + IntToStr(Chain.TotalSteps) + LineEnding;
  Result := Result + 'Completed: ' + IntToStr(Chain.CompletedSteps) + LineEnding;
  Result := Result + 'Failed: ' + IntToStr(Chain.FailedSteps) + LineEnding;
  Result := Result + 'Current State: ' + GetStateDescription(Chain.CurrentState) + LineEnding + LineEnding;
  
  if Length(Chain.Steps) > 0 then
  begin
    Result := Result + '=== Steps ===' + LineEnding;
    for i := 0 to Length(Chain.Steps) - 1 do
    begin
      Result := Result + 'Step ' + IntToStr(Chain.Steps[i].StepNumber) + ': ';
      if Chain.Steps[i].Success then
        Result := Result + '✓' + LineEnding
      else if Chain.Steps[i].ErrorMessage <> '' then
        Result := Result + '✗ - ' + Chain.Steps[i].ErrorMessage + LineEnding
      else
        Result := Result + '?' + LineEnding;
      Result := Result + '  Tool: ' + Chain.Steps[i].ToolName + LineEnding;
      Result := Result + '  ' + Chain.Steps[i].Description + LineEnding;
      if Chain.Steps[i].ExecutionTimeMs > 0 then
        Result := Result + '  Time: ' + IntToStr(Chain.Steps[i].ExecutionTimeMs) + 'ms' + LineEnding;
      Result := Result + LineEnding;
    end;
  end;
end;

function CreateCheckpoint(var Chain: TReasoningChain; const Desc: string): Integer;
var
  Len: Integer;
  Timestamp: string;
begin
  { Remove oldest checkpoint if at max }
  if Length(Chain.Checkpoints) >= Chain.MaxCheckpoints then
  begin
    if Length(Chain.Checkpoints) > 0 then
    begin
      for Len := 0 to Length(Chain.Checkpoints) - 2 do
        Chain.Checkpoints[Len] := Chain.Checkpoints[Len + 1];
      SetLength(Chain.Checkpoints, Length(Chain.Checkpoints) - 1);
    end;
  end;
  
  Inc(Chain.LastCheckpointID);
  Len := Length(Chain.Checkpoints);
  SetLength(Chain.Checkpoints, Len + 1);
  
  Chain.Checkpoints[Len].ID := Chain.LastCheckpointID;
  Chain.Checkpoints[Len].StepNumber := Chain.CompletedSteps;
  { Simple timestamp - could use DateTimeToStr(Now) }
  Chain.Checkpoints[Len].Timestamp := 'Step ' + IntToStr(Chain.CompletedSteps);
  Chain.Checkpoints[Len].Description := Desc;
  Chain.Checkpoints[Len].ChatHistorySnapshot := 'checkpoint_' + IntToStr(Chain.LastCheckpointID);
  
  Result := Chain.LastCheckpointID;
end;

function GetCheckpointCount(const Chain: TReasoningChain): Integer;
begin
  Result := Length(Chain.Checkpoints);
end;

function RestoreCheckpoint(var Chain: TReasoningChain; CheckpointID: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  
  for i := 0 to Length(Chain.Checkpoints) - 1 do
  begin
    if Chain.Checkpoints[i].ID = CheckpointID then
    begin
      { Restore state }
      Chain.CompletedSteps := Chain.Checkpoints[i].StepNumber;
      SetState(Chain, esRolledBack);
      Result := True;
      Exit;
    end;
  end;
end;

function CanRollback(const Chain: TReasoningChain): Boolean;
begin
  Result := Length(Chain.Checkpoints) > 0;
end;

function RollbackToLastCheckpoint(var Chain: TReasoningChain): Boolean;
begin
  Result := False;
  
  if Length(Chain.Checkpoints) > 0 then
  begin
    Result := RestoreCheckpoint(Chain, Chain.Checkpoints[Length(Chain.Checkpoints) - 1].ID);
  end;
end;

function RollbackSteps(var Chain: TReasoningChain; StepsBack: Integer): Boolean;
var
  TargetStep: Integer;
  i: Integer;
begin
  Result := False;
  
  if StepsBack <= 0 then
    Exit;
    
  TargetStep := Chain.CompletedSteps - StepsBack;
  if TargetStep < 0 then
    TargetStep := 0;
  
  { Find checkpoint closest to target }
  for i := Length(Chain.Checkpoints) - 1 downto 0 do
  begin
    if Chain.Checkpoints[i].StepNumber <= TargetStep then
    begin
      Result := RestoreCheckpoint(Chain, Chain.Checkpoints[i].ID);
      Exit;
    end;
  end;
  
  { No checkpoint found, just reset to target }
  Chain.CompletedSteps := TargetStep;
  SetState(Chain, esRolledBack);
  Result := True;
end;

function GetExecutionLog(const Chain: TReasoningChain): string;
var
  i: Integer;
begin
  Result := '=== Execution Log ===' + LineEnding;
  Result := Result + 'State: ' + GetStateDescription(Chain.CurrentState) + LineEnding + LineEnding;
  
  for i := 0 to Length(Chain.Steps) - 1 do
  begin
    Result := Result + '[' + IntToStr(Chain.Steps[i].StepNumber) + '] ';
    if Chain.Steps[i].Success then
      Result := Result + 'SUCCESS' + LineEnding
    else if Chain.Steps[i].ErrorMessage <> '' then
      Result := Result + 'FAILED: ' + Chain.Steps[i].ErrorMessage + LineEnding
    else
      Result := Result + 'PENDING' + LineEnding;
    Result := Result + '  ' + Chain.Steps[i].ToolName + ' - ' + Chain.Steps[i].Description + LineEnding;
  end;
  
  if Length(Chain.Checkpoints) > 0 then
  begin
    Result := Result + LineEnding + '=== Checkpoints ===' + LineEnding;
    for i := 0 to Length(Chain.Checkpoints) - 1 do
    begin
      Result := Result + 'Checkpoint #' + IntToStr(Chain.Checkpoints[i].ID) + 
                ' at ' + Chain.Checkpoints[i].Timestamp + 
                ': ' + Chain.Checkpoints[i].Description + LineEnding;
    end;
  end;
end;

end.