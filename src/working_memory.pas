{
  Working Memory - Speichert und lädt Todo-Listen für den Agenten.
  Ermöglicht Persistenz zwischen Sessions.
}
unit working_memory;

{$mode objfpc}{$H+}

interface

uses SysUtils, types, tasks;

const
  WORKING_MEMORY_FILE = '.agent_working_memory.json';

{ Todo-Liste speichern }
procedure SaveWorkingMemory(const TaskList: TTASKARRAY);

{ Todo-Liste laden }
function LoadWorkingMemory(): TTASKARRAY;

{ Prüfen ob Working Memory existiert }
function HasWorkingMemory(): Boolean;

{ Working Memory löschen }
procedure ClearWorkingMemory();

implementation

{ JSON-Hilfsfunktionen }
function EscapeJSONString(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #9, '\t', [rfReplaceAll]);
end;

function UnescapeJSONString(const S: string): string;
begin
  Result := S;
  Result := StringReplace(Result, '\n', #10, [rfReplaceAll]);
  Result := StringReplace(Result, '\r', #13, [rfReplaceAll]);
  Result := StringReplace(Result, '\t', #9, [rfReplaceAll]);
  Result := StringReplace(Result, '\"', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '\\', '\', [rfReplaceAll]);
end;

{ TTASKSTATUS zu String }
function StatusToString(Status: TTASKSTATUS): string;
begin
  case Status of
    TSPending: Result := 'pending';
    TSInProgress: Result := 'in_progress';
    TSCompleted: Result := 'completed';
    TSCancelled: Result := 'cancelled';
  else
    Result := 'pending';
  end;
end;

{ String zu TTASKSTATUS }
function StringToStatus(const S: string): TTASKSTATUS;
begin
  if S = 'in_progress' then
    Result := TSInProgress
  else if S = 'completed' then
    Result := TSCompleted
  else if S = 'cancelled' then
    Result := TSCancelled
  else
    Result := TSPending;
end;

procedure SaveWorkingMemory(const TaskList: TTASKARRAY);
var
  F: TextFile;
  i: Integer;
  FilePath: string;
begin
  FilePath := GetCurrentDir + DirectorySeparator + WORKING_MEMORY_FILE;
  
  AssignFile(F, FilePath);
  try
    Rewrite(F);
    WriteLn(F, '{');
    WriteLn(F, '  "tasks": [');
    
    for i := Low(TaskList) to High(TaskList) do
    begin
      Write(F, '    {');
      Write(F, '"id": "' + EscapeJSONString(TaskList[i].ID) + '", ');
      Write(F, '"subject": "' + EscapeJSONString(TaskList[i].Subject) + '", ');
      Write(F, '"description": "' + EscapeJSONString(TaskList[i].Description) + '", ');
      Write(F, '"status": "' + StatusToString(TaskList[i].Status) + '", ');
      Write(F, '"activeForm": "' + EscapeJSONString(TaskList[i].ActiveForm) + '"');
      
      if i < High(TaskList) then
        WriteLn(F, ' },')
      else
        WriteLn(F, ' }');
    end;
    
    WriteLn(F, '  ]');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;
end;

function LoadWorkingMemory(): TTASKARRAY;
var
  F: TextFile;
  Line: string;
  FilePath: string;
  InTasks: Boolean;
  InTask: Boolean;
  CurrentTask: TTASK;
  Key, Value: string;
  i: Integer;
begin
  SetLength(Result, 0);
  FilePath := GetCurrentDir + DirectorySeparator + WORKING_MEMORY_FILE;
  
  if not FileExists(FilePath) then
    Exit;
    
  AssignFile(F, FilePath);
  try
    Reset(F);
    InTasks := False;
    InTask := False;
    
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      
      { Find "tasks": [ }
      if Pos('"tasks"', Line) > 0 then
        InTasks := True;
        
      { Start of a task }
      if (Pos('{', Line) > 0) and InTasks then
      begin
        InTask := True;
        CurrentTask.ID := '';
        CurrentTask.Subject := '';
        CurrentTask.Description := '';
        CurrentTask.Status := TSPending;
        CurrentTask.ActiveForm := '';
      end;
      
      { End of a task }
      if (Pos('}', Line) > 0) and InTask then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := CurrentTask;
        InTask := False;
      end;
      
      { Parse key-value pairs }
      if InTask and (Pos('"', Line) > 0) then
      begin
        { Extract key }
        i := Pos('"', Line);
        if i > 0 then
        begin
          Delete(Line, 1, i);
          i := Pos('"', Line);
          if i > 0 then
          begin
            Key := Copy(Line, 1, i - 1);
            Delete(Line, 1, i + 1); { after " }
            
            { Find : }
            i := Pos(':', Line);
            if i > 0 then
            begin
              Delete(Line, 1, i);
              Line := Trim(Line);
              
              { Remove quotes if present }
              if (Length(Line) >= 2) and (Line[1] = '"') and (Line[Length(Line)] = '"') then
                Value := Copy(Line, 2, Length(Line) - 2)
              else
                Value := Line;
              
              Value := UnescapeJSONString(Value);
              
              if Key = 'id' then
                CurrentTask.ID := Value
              else if Key = 'subject' then
                CurrentTask.Subject := Value
              else if Key = 'description' then
                CurrentTask.Description := Value
              else if Key = 'status' then
                CurrentTask.Status := StringToStatus(Value)
              else if Key = 'activeForm' then
                CurrentTask.ActiveForm := Value;
            end;
          end;
        end;
      end;
    end;
  finally
    CloseFile(F);
  end;
end;

function HasWorkingMemory(): Boolean;
var
  FilePath: string;
begin
  FilePath := GetCurrentDir + DirectorySeparator + WORKING_MEMORY_FILE;
  Result := FileExists(FilePath);
end;

procedure ClearWorkingMemory();
var
  FilePath: string;
begin
  FilePath := GetCurrentDir + DirectorySeparator + WORKING_MEMORY_FILE;
  if FileExists(FilePath) then
    DeleteFile(FilePath);
end;

end.