{
  Tool Orchestration - Manages tool execution order and parallelization.
  - Read-only tools can be executed in parallel
  - Write operations are always executed serially
  - Batch processing for multiple read operations
}
unit tool_orchestration;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

const
  MAX_PARALLEL_READS = 10;

type
  { Execution mode for tools }
  TExecutionMode = (
    emSerial,     { Execute one at a time }
    emParallel,   { Execute multiple at once }
    emBatch       { Batch multiple reads together }
  );

  { Tool execution queue item }
  TToolQueueItem = record
    ToolName: string;
    InputJSON: string;
    ToolID: string;
    Category: string;  { 'read' or 'write' }
  end;
  TToolQueue = array of TToolQueueItem;

  { Execution result for orchestration }
  TOrchestrationResult = record
    Success: Boolean;
    Output: string;
    ErrorMessage: string;
    ExecutionTime: Int64;  { Milliseconds }
    ParallelExecutions: Integer;
  end;

{ Get execution mode based on tool type }
function GetExecutionMode(const ToolName: string): TExecutionMode;

{ Check if tool is read-only }
function IsReadOnlyTool(const ToolName: string): Boolean;

{ Check if tool is write operation }
function IsWriteTool(const ToolName: string): Boolean;

{ Add tool to execution queue }
procedure QueueTool(var Queue: TToolQueue; const ToolName, InputJSON, ToolID: string);

{ Clear the execution queue }
procedure ClearQueue(var Queue: TToolQueue);

{ Get queue size }
function GetQueueSize(const Queue: TToolQueue): Integer;

{ Categorize tools into read and write lists }
procedure CategorizeTools(const Queue: TToolQueue; var ReadQueue, WriteQueue: TToolQueue);

{ Execute reads in batch (single call for multiple reads) }
function ExecuteReadsBatch(const ReadQueue: TToolQueue): string;

{ Execute all tools in queue serially }
function ExecuteQueueSerial(const Queue: TToolQueue): string;

{ Main orchestration function - decides execution strategy }
function OrchestrateTools(const Queue: TToolQueue): TOrchestrationResult;

implementation

{ Check if tool is read-only }
function IsReadOnlyTool(const ToolName: string): Boolean;
var
  Name: string;
begin
  Name := LowerCase(ToolName);
  Result := (Name = 'read') or (Name = 'glob') or (Name = 'grep') or 
             (Name = 'filetree') or (Name = 'diff') or (Name = 'tasklist');
end;

{ Check if tool is write operation }
function IsWriteTool(const ToolName: string): Boolean;
var
  Name: string;
begin
  Name := LowerCase(ToolName);
  Result := (Name = 'write') or (Name = 'edit') or (Name = 'mkdir') or 
             (Name = 'delete') or (Name = 'move') or (Name = 'bash');
end;

{ Get execution mode based on tool type }
function GetExecutionMode(const ToolName: string): TExecutionMode;
begin
  if IsReadOnlyTool(ToolName) then
    Result := emParallel
  else
    Result := emSerial;
end;

{ Add tool to execution queue }
procedure QueueTool(var Queue: TToolQueue; const ToolName, InputJSON, ToolID: string);
var
  Index: Integer;
begin
  Index := Length(Queue);
  SetLength(Queue, Index + 1);
  Queue[Index].ToolName := ToolName;
  Queue[Index].InputJSON := InputJSON;
  Queue[Index].ToolID := ToolID;
  if IsReadOnlyTool(ToolName) then
    Queue[Index].Category := 'read'
  else
    Queue[Index].Category := 'write';
end;

{ Clear the execution queue }
procedure ClearQueue(var Queue: TToolQueue);
begin
  SetLength(Queue, 0);
end;

{ Get queue size }
function GetQueueSize(const Queue: TToolQueue): Integer;
begin
  Result := Length(Queue);
end;

{ Categorize tools into read and write lists }
procedure CategorizeTools(const Queue: TToolQueue; var ReadQueue, WriteQueue: TToolQueue);
var
  i: Integer;
begin
  SetLength(ReadQueue, 0);
  SetLength(WriteQueue, 0);
  
  for i := 0 to Length(Queue) - 1 do
  begin
    if Queue[i].Category = 'read' then
    begin
      SetLength(ReadQueue, Length(ReadQueue) + 1);
      ReadQueue[High(ReadQueue)] := Queue[i];
    end
    else
    begin
      SetLength(WriteQueue, Length(WriteQueue) + 1);
      WriteQueue[High(WriteQueue)] := Queue[i];
    end;
  end;
end;

{ Execute reads in batch - combines multiple reads }
function ExecuteReadsBatch(const ReadQueue: TToolQueue): string;
var
  i: Integer;
begin
  Result := '';
  { Note: Actual batch execution would require changes to how the LLM 
    processes tool results. This provides info about batched reads. }
  Result := 'Batch execution: ' + IntToStr(Length(ReadQueue)) + ' read operations' + LineEnding;
  for i := 0 to Length(ReadQueue) - 1 do
  begin
    Result := Result + '- ' + ReadQueue[i].ToolName + ': ' + ReadQueue[i].ToolID + LineEnding;
  end;
end;

{ Execute all tools in queue serially }
function ExecuteQueueSerial(const Queue: TToolQueue): string;
var
  i: Integer;
begin
  Result := '';
  for i := 0 to Length(Queue) - 1 do
  begin
    Result := Result + '[queued] ' + Queue[i].ToolName + ': ' + Queue[i].ToolID + LineEnding;
  end;
end;

{ Main orchestration function }
function OrchestrateTools(const Queue: TToolQueue): TOrchestrationResult;
var
  ReadQueue, WriteQueue: TToolQueue;
  StartTime: Int64;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';
  Result.ExecutionTime := 0;
  Result.ParallelExecutions := 0;
  
  if Length(Queue) = 0 then
  begin
    Result.ErrorMessage := 'Empty queue';
    Exit;
  end;
  
  StartTime := GetTickCount64;
  
  { Categorize tools }
  CategorizeTools(Queue, ReadQueue, WriteQueue);
  
  { First execute all read operations (can be parallel) }
  if Length(ReadQueue) > 0 then
  begin
    if Length(ReadQueue) = 1 then
    begin
      { Single read - execute directly }
      Result.Output := Result.Output + 'Execute read: ' + ReadQueue[0].ToolName + LineEnding;
    end
    else
    begin
      { Multiple reads - could be parallel/batch }
      Result.Output := Result.Output + ExecuteReadsBatch(ReadQueue) + LineEnding;
      Result.ParallelExecutions := Length(ReadQueue);
    end;
  end;
  
  { Then execute write operations serially }
  if Length(WriteQueue) > 0 then
  begin
    { Write operations would be executed serially }
    Result.Output := Result.Output + 'Serial write operations: ' + IntToStr(Length(WriteQueue)) + LineEnding;
    Result.Output := Result.Output + ExecuteQueueSerial(WriteQueue);
  end;
  
  Result.ExecutionTime := GetTickCount64 - StartTime;
  Result.Success := True;
end;

end.