{
  Bash Tool - Execute shell commands.
}
unit bash_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, Unix, types;

function ExecuteBash(const Command: string; const WorkingDir: string = ''): TToolExecutionResult;
function BashToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

function ExtractJSONString(const JSON, Key: string): string;
var
  KeyPos, ValueStart, ValueEnd, ColonPos: Integer;
  InString: Boolean;
begin
  Result := '';
  { Use "key": pattern for more accurate matching }
  KeyPos := Pos('"' + Key + '":', JSON);
  if KeyPos = 0 then Exit;
  
  ColonPos := KeyPos + Length(Key) + 2;
  if (ColonPos > Length(JSON)) or (JSON[ColonPos] <> ':') then Exit;
  
  ValueStart := ColonPos + 1;
  while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
    Inc(ValueStart);
  if ValueStart > Length(JSON) then Exit;
  
  if JSON[ValueStart] = '"' then
  begin
    Inc(ValueStart);
    ValueEnd := ValueStart;
    InString := True;
    while (ValueEnd <= Length(JSON)) and InString do
    begin
      if JSON[ValueEnd] = '\' then Inc(ValueEnd, 2) else if JSON[ValueEnd] = '"' then InString := False else Inc(ValueEnd);
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

function ExecuteBash(const Command: string; const WorkingDir: string): TToolExecutionResult;
var
  OutputFile, FullCommand, Line: string;
  F: TextFile;
begin
  Result.Success := False; Result.Output := ''; Result.ErrorMessage := '';
  if Command = '' then begin Result.ErrorMessage := 'No command'; Exit; end;
  OutputFile := GetTempFileName + '.out';
  FullCommand := Command;
  if WorkingDir <> '' then FullCommand := 'cd ' + WorkingDir + ' && ' + Command;
  FullCommand := FullCommand + ' > ' + OutputFile + ' 2>&1; echo $? >> ' + OutputFile;
  fpsystem(FullCommand);
  if FileExists(OutputFile) then
  begin
    AssignFile(F, OutputFile); Reset(F);
    try while not EOF(F) do begin ReadLn(F, Line); Result.Output := Result.Output + Line + LineEnding; end;
    finally CloseFile(F); end;
    DeleteFile(OutputFile);
  end;
  Result.Success := True;
end;

function BashToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var Command, Dir, WorkInput: string;
  i: Integer;
begin
  { Unescape JSON first }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  Command := ExtractJSONString(WorkInput, 'command');
  Dir := ExtractJSONString(WorkInput, 'directory');
  
  { Input validation }
  if Command = '' then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Error: command parameter is required';
    Exit;
  end;
  
  { Sanitize dangerous patterns }
  { Check for command chaining that could be dangerous }
  if (Pos('; rm', Command) > 0) or (Pos(';rm', Command) > 0) or
     (Pos('&& rm', Command) > 0) or (Pos('&&rm', Command) > 0) or
     (Pos('|| rm', Command) > 0) or (Pos('||rm', Command) > 0) then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Error: dangerous command pattern detected';
    Exit;
  end;
  
  { Check for pipe to dangerous commands }
  if (Pos('| sh', Command) > 0) or (Pos('|sh', Command) > 0) or
     (Pos('| bash', Command) > 0) or (Pos('|bash', Command) > 0) then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Error: suspicious pipe detected';
    Exit;
  end;
  
  Result := ExecuteBash(Command, Dir);
end;

end.