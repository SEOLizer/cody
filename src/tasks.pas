{
  Task Management System
  Simple file-based task storage
}
unit tasks;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TTaskStatus = (tsPending, tsInProgress, tsCompleted, tsCancelled);
  
  TTask = record
    ID: string;
    Subject: string;
    Description: string;
    Status: TTaskStatus;
    activeForm: string;
    blockedBy: string;
    blocks: string;
    createdAt: string;
    updatedAt: string;
  end;
  TTaskArray = array of TTask;

  TTaskStore = class
  private
    FTaskDir: string;
    function GetTaskPath(const ID: string): string;
    function StatusToString(Status: TTaskStatus): string;
    function StringToStatus(const S: string): TTaskStatus;
    function FindHighestID: Integer;
    function TaskToText(const Task: TTask): string;
    function ParseLine(const Line: string): string; { just returns value after = }
  public
    constructor Create(const TaskDir: string);
    function CreateTask(const Subject, Description, ActiveForm: string): string;
    function ListTasks: TTaskArray;
    function GetTask(const ID: string): TTask;
    function UpdateTaskStatus(const ID: string; Status: TTaskStatus): Boolean;
    function UpdateTask(const ID: string; const Subject, Description, Status, BlockedBy, Blocks: string): Boolean;
    function DeleteTask(const ID: string): Boolean;
  end;

implementation

{ Parse a key=value line and return the value }
function TTaskStore.ParseLine(const Line: string): string;
var
  PosEq: Integer;
begin
  Result := '';
  PosEq := Pos('=', Line);
  if PosEq > 0 then
    Result := Trim(Copy(Line, PosEq + 1, Length(Line) - PosEq));
end;

constructor TTaskStore.Create(const TaskDir: string);
begin
  inherited Create;
  FTaskDir := TaskDir;
  if not DirectoryExists(FTaskDir) then
    ForceDirectories(FTaskDir);
end;

function TTaskStore.GetTaskPath(const ID: string): string;
begin
  Result := FTaskDir + '/task_' + ID + '.txt';
end;

function TTaskStore.StatusToString(Status: TTaskStatus): string;
begin
  case Status of
    tsPending: Result := 'pending';
    tsInProgress: Result := 'in_progress';
    tsCompleted: Result := 'completed';
    tsCancelled: Result := 'cancelled';
  else
    Result := 'pending';
  end;
end;

function TTaskStore.StringToStatus(const S: string): TTaskStatus;
begin
  if S = 'pending' then Result := tsPending
  else if S = 'in_progress' then Result := tsInProgress
  else if S = 'completed' then Result := tsCompleted
  else if S = 'cancelled' then Result := tsCancelled
  else Result := tsPending;
end;

function TTaskStore.FindHighestID: Integer;
var
  SR: TSearchRec;
  IdStr: string;
  id: Integer;
begin
  Result := 0;
  if FindFirst(FTaskDir + '/task_*.txt', faAnyFile, SR) = 0 then
  begin
    repeat
      try
        if Pos('task_', SR.Name) = 1 then
        begin
          IdStr := Copy(SR.Name, 6, Length(SR.Name) - 9);
          id := StrToIntDef(IdStr, 0);
          if id > Result then Result := id;
        end;
      except
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function TTaskStore.TaskToText(const Task: TTask): string;
begin
  Result := 'id=' + Task.ID + LineEnding;
  Result := Result + 'subject=' + Task.Subject + LineEnding;
  Result := Result + 'description=' + Task.Description + LineEnding;
  Result := Result + 'status=' + StatusToString(Task.Status) + LineEnding;
  Result := Result + 'activeForm=' + Task.activeForm + LineEnding;
  Result := Result + 'blockedBy=' + Task.blockedBy + LineEnding;
  Result := Result + 'blocks=' + Task.blocks + LineEnding;
  Result := Result + 'createdAt=' + Task.createdAt + LineEnding;
  Result := Result + 'updatedAt=' + Task.updatedAt + LineEnding;
end;

function TTaskStore.GetTask(const ID: string): TTask;
var
  F: TextFile;
  Line: string;
begin
  Result.ID := '';
  try
    AssignFile(F, GetTaskPath(ID));
    Reset(F);
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      if Pos('id=', Line) = 1 then Result.ID := ParseLine(Line)
      else if Pos('subject=', Line) = 1 then Result.Subject := ParseLine(Line)
      else if Pos('description=', Line) = 1 then Result.Description := ParseLine(Line)
      else if Pos('status=', Line) = 1 then Result.Status := StringToStatus(ParseLine(Line))
      else if Pos('activeForm=', Line) = 1 then Result.activeForm := ParseLine(Line)
      else if Pos('blockedBy=', Line) = 1 then Result.blockedBy := ParseLine(Line)
      else if Pos('blocks=', Line) = 1 then Result.blocks := ParseLine(Line)
      else if Pos('createdAt=', Line) = 1 then Result.createdAt := ParseLine(Line)
      else if Pos('updatedAt=', Line) = 1 then Result.updatedAt := ParseLine(Line);
    end;
    CloseFile(F);
  except
    Result.ID := '';
  end;
end;

function TTaskStore.CreateTask(const Subject, Description, ActiveForm: string): string;
var
  Task: TTask;
  F: TextFile;
  Path: string;
  newID: Integer;
begin
  Result := '';
  try
    newID := FindHighestID + 1;
    Result := IntToStr(newID);
    
    Task.ID := Result;
    Task.Subject := Subject;
    Task.Description := Description;
    Task.Status := tsPending;
    Task.activeForm := ActiveForm;
    Task.blockedBy := '';
    Task.blocks := '';
    Task.createdAt := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    Task.updatedAt := Task.createdAt;
    
    Path := GetTaskPath(Result);
    AssignFile(F, Path);
    Rewrite(F);
    try
      Write(F, TaskToText(Task));
    finally
      CloseFile(F);
    end;
  except
    Result := '';
  end;
end;

function TTaskStore.ListTasks: TTaskArray;
var
  SR: TSearchRec;
  F: TextFile;
  Line: string;
  Task: TTask;
begin
  SetLength(Result, 0);
  
  if FindFirst(FTaskDir + '/task_*.txt', faAnyFile, SR) = 0 then
  begin
    repeat
      try
        Task.ID := '';
        AssignFile(F, FTaskDir + '/' + SR.Name);
        Reset(F);
        while not EOF(F) do
        begin
          ReadLn(F, Line);
          if Pos('id=', Line) = 1 then Task.ID := ParseLine(Line)
          else if Pos('subject=', Line) = 1 then Task.Subject := ParseLine(Line)
          else if Pos('description=', Line) = 1 then Task.Description := ParseLine(Line)
          else if Pos('status=', Line) = 1 then Task.Status := StringToStatus(ParseLine(Line))
          else if Pos('activeForm=', Line) = 1 then Task.activeForm := ParseLine(Line)
          else if Pos('blockedBy=', Line) = 1 then Task.blockedBy := ParseLine(Line)
          else if Pos('blocks=', Line) = 1 then Task.blocks := ParseLine(Line)
          else if Pos('createdAt=', Line) = 1 then Task.createdAt := ParseLine(Line)
          else if Pos('updatedAt=', Line) = 1 then Task.updatedAt := ParseLine(Line);
        end;
        CloseFile(F);
        
        if Task.ID <> '' then
        begin
          SetLength(Result, Length(Result) + 1);
          Result[Length(Result) - 1] := Task;
        end;
      except
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function TTaskStore.UpdateTaskStatus(const ID: string; Status: TTaskStatus): Boolean;
var
  Task: TTask;
  F: TextFile;
  Path: string;
begin
  Result := False;
  try
    Task := GetTask(ID);
    if Task.ID = '' then
      Exit;
    
    Task.Status := Status;
    Task.updatedAt := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    
    Path := GetTaskPath(ID);
    AssignFile(F, Path);
    Rewrite(F);
    try
      Write(F, TaskToText(Task));
    finally
      CloseFile(F);
    end;
    Result := True;
  except
  end;
end;

function TTaskStore.UpdateTask(const ID: string; const Subject, Description, Status, BlockedBy, Blocks: string): Boolean;
var
  Task: TTask;
  F: TextFile;
  Path: string;
begin
  Result := False;
  try
    Task := GetTask(ID);
    if Task.ID = '' then
      Exit;
    
    if Subject <> '' then Task.Subject := Subject;
    if Description <> '' then Task.Description := Description;
    if Status <> '' then Task.Status := StringToStatus(Status);
    if BlockedBy <> '' then Task.blockedBy := BlockedBy;
    if Blocks <> '' then Task.blocks := Blocks;
    Task.updatedAt := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
    
    Path := GetTaskPath(ID);
    AssignFile(F, Path);
    Rewrite(F);
    try
      Write(F, TaskToText(Task));
    finally
      CloseFile(F);
    end;
    Result := True;
  except
  end;
end;

function TTaskStore.DeleteTask(const ID: string): Boolean;
begin
  Result := False;
  try
    if FileExists(GetTaskPath(ID)) then
    begin
      DeleteFile(GetTaskPath(ID));
      Result := True;
    end;
  except
  end;
end;

end.