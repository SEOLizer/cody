{
  Thinking and Planning - Autonomous planning and task creation.
  - Automatic task detection for complex tasks (3+ steps)
  - Plan verification before execution
  - Thinking mode with multi-iteration support
}
unit thinking_planning;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  TTaskComplexity = (
    tcSimple,     { Single task, can be done directly }
    tcModerate,   { 2-3 steps, may need tasks }
    tcComplex     { 4+ steps, definitely needs tasks }
  );

  TPlanStep = record
    StepNumber: Integer;
    Description: string;
    ToolName: string;
    ExpectedOutcome: string;
  end;
  TPlanStepArray = array of TPlanStep;

  TThinkingState = record
    IterationCount: Integer;
    MaxIterations: Integer;
    CurrentPlan: TPlanStepArray;
    TaskCreated: Boolean;
    VerifiedPlan: Boolean;
  end;

const
  COMPLEX_TASK_THRESHOLD = 3;  { Steps > this = complex }

{ Complexity Analysis }
function AnalyzeTaskComplexity(const UserInput: string): TTaskComplexity;
function EstimateSteps(const Input: string): Integer;
function ContainsMultiStepIndicators(const Input: string): Boolean;

{ Plan Generation }
function GeneratePlanFromInput(const Input: string): TPlanStepArray;
function AddStepToPlan(var Plan: TPlanStepArray; StepNum: Integer; const Desc, Tool, Outcome: string): Integer;

{ Plan Verification }
function VerifyPlan(const Plan: TPlanStepArray): Boolean;
function ValidateStep(const Step: TPlanStep): Boolean;
function GetPlanSummary(const Plan: TPlanStepArray): string;
function GetTaskPlanInfo(const Input: string): string;

{ Thinking State Management }
procedure InitThinkingState(var State: TThinkingState);
function ShouldContinueThinking(const State: TThinkingState): Boolean;

implementation

procedure InitThinkingState(var State: TThinkingState);
begin
  State.IterationCount := 0;
  State.MaxIterations := 20;
  SetLength(State.CurrentPlan, 0);
  State.TaskCreated := False;
  State.VerifiedPlan := False;
end;

function ShouldContinueThinking(const State: TThinkingState): Boolean;
begin
  Result := (State.IterationCount < State.MaxIterations) and (not State.VerifiedPlan);
end;

function ContainsMultiStepIndicators(const Input: string): Boolean;
var
  LowerInput: string;
begin
  LowerInput := LowerCase(Input);
  
  Result := False;
  if Pos('first', LowerInput) > 0 then Result := True;
  if Pos('then', LowerInput) > 0 then Result := True;
  if Pos('next', LowerInput) > 0 then Result := True;
  if Pos('finally', LowerInput) > 0 then Result := True;
  if Pos('after that', LowerInput) > 0 then Result := True;
  if Pos('step 1', LowerInput) > 0 then Result := True;
  if Pos('step 2', LowerInput) > 0 then Result := True;
  if Pos('steps', LowerInput) > 0 then Result := True;
  if Pos('multiple', LowerInput) > 0 then Result := True;
  if Pos('several', LowerInput) > 0 then Result := True;
  if Pos('parts', LowerInput) > 0 then Result := True;
end;

function EstimateSteps(const Input: string): Integer;
var
  i, Count: Integer;
  LowerInput: string;
begin
  Result := 1;
  LowerInput := LowerCase(Input);
  
  { Count explicit step indicators }
  Count := 0;
  for i := 1 to 9 do
  begin
    if Pos('step ' + IntToStr(i), LowerInput) > 0 then
      Count := i;
  end;
  if Count > Result then Result := Count;
  
  { Count conjunction-based steps }
  Count := 1;
  if Pos(' and then ', LowerInput) > 0 then Inc(Count);
  if Pos('; then ', LowerInput) > 0 then Inc(Count);
  if Pos('. then ', LowerInput) > 0 then Inc(Count);
  if Pos(' after ', LowerInput) > 0 then Inc(Count);
  if Pos(' finally', LowerInput) > 0 then Inc(Count);
  
  Result := Result + Count;
end;

function AnalyzeTaskComplexity(const UserInput: string): TTaskComplexity;
var
  StepCount: Integer;
begin
  if ContainsMultiStepIndicators(UserInput) or (Length(UserInput) > 200) then
  begin
    StepCount := EstimateSteps(UserInput);
    if StepCount >= COMPLEX_TASK_THRESHOLD + 1 then
      Result := tcComplex
    else if StepCount >= 2 then
      Result := tcModerate
    else
      Result := tcSimple;
  end
  else
    Result := tcSimple;
end;

function AddStepToPlan(var Plan: TPlanStepArray; StepNum: Integer; const Desc, Tool, Outcome: string): Integer;
var
  Len: Integer;
begin
  Len := Length(Plan);
  SetLength(Plan, Len + 1);
  Plan[Len].StepNumber := StepNum;
  Plan[Len].Description := Desc;
  Plan[Len].ToolName := Tool;
  Plan[Len].ExpectedOutcome := Outcome;
  Result := Len;
end;

function GeneratePlanFromInput(const Input: string): TPlanStepArray;
var
  Complexity: TTaskComplexity;
begin
  SetLength(Result, 0);
  
  Complexity := AnalyzeTaskComplexity(Input);
  
  { For complex tasks, generate a basic plan structure }
  if Complexity = tcComplex then
  begin
    AddStepToPlan(Result, 1, 'Analyze the task and break down requirements', 'Read', 'Understanding of requirements');
    AddStepToPlan(Result, 2, 'Implement the first part of the solution', 'Write', 'Code or file created');
    AddStepToPlan(Result, 3, 'Verify the implementation works', 'Bash', 'Test results');
  end
  else if Complexity = tcModerate then
  begin
    AddStepToPlan(Result, 1, 'Complete the task', 'Bash', 'Task completed');
  end;
end;

function ValidateStep(const Step: TPlanStep): Boolean;
begin
  Result := True;
  if Step.Description = '' then Result := False;
  if Step.ToolName = '' then Result := False;
end;

function VerifyPlan(const Plan: TPlanStepArray): Boolean;
var
  i: Integer;
begin
  Result := True;
  
  if Length(Plan) = 0 then
  begin
    Result := False;
    Exit;
  end;
  
  for i := 0 to Length(Plan) - 1 do
  begin
    if not ValidateStep(Plan[i]) then
    begin
      Result := False;
      Exit;
    end;
  end;
end;

function GetPlanSummary(const Plan: TPlanStepArray): string;
var
  i: Integer;
begin
  Result := '=== Plan Summary ===' + LineEnding;
  Result := Result + 'Total Steps: ' + IntToStr(Length(Plan)) + LineEnding + LineEnding;
  
  for i := 0 to Length(Plan) - 1 do
  begin
    Result := Result + IntToStr(Plan[i].StepNumber) + '. ' + Plan[i].Description + LineEnding;
    Result := Result + '   Tool: ' + Plan[i].ToolName + LineEnding;
    Result := Result + '   Expected: ' + Plan[i].ExpectedOutcome + LineEnding + LineEnding;
  end;
end;

{ Plan info for CLI to use }
function GetTaskPlanInfo(const Input: string): string;
var
  Plan: TPlanStepArray;
  Complexity: TTaskComplexity;
begin
  Complexity := AnalyzeTaskComplexity(Input);
  Plan := GeneratePlanFromInput(Input);
  
  case Complexity of
    tcComplex:
      Result := 'Complex task detected (' + IntToStr(Length(Plan)) + ' steps planned). Use Task tools for tracking.';
    tcModerate:
      Result := 'Moderate task - single step execution.';
    tcSimple:
      Result := 'Simple task - direct execution.';
  end;
end;

end.