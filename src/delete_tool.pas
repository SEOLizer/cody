{
  Delete Tool - Delete files and directories.
}
unit delete_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function DeletePath(const Path: string; Recursive: Boolean): TToolExecutionResult;
function DeleteToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor;

{ Extract JSON string value - helper function }
function ExtractJSONString(const JSON, Key: string): string;
var
  KeyPos, ValueStart, ValueEnd: Integer;
  InString: Boolean;
begin
  Result := '';
  KeyPos := Pos('"' + Key + '"', JSON);
  if KeyPos = 0 then Exit;

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

  if ValueStart > Length(JSON) then Exit;

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
  else
  begin
    ValueEnd := ValueStart;
    while (ValueEnd <= Length(JSON)) and not (JSON[ValueEnd] in [',', '}', ']']) do
      Inc(ValueEnd);
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end;
end;

{ Check if path is within working directory }
function IsPathAllowed(const FilePath: string): Boolean;
var
  FullPath, WorkDir: string;
begin
  Result := False;

  if FilePath = '' then Exit;

  if FilePath[1] = '/' then
    FullPath := FilePath
  else
    FullPath := GWorkingDirectory + FilePath;

  WorkDir := GWorkingDirectory;
  if WorkDir = '' then WorkDir := GetCurrentDir + '/';

  if Length(FullPath) < Length(WorkDir) then
    Exit;

  Result := Copy(FullPath, 1, Length(WorkDir)) = WorkDir;
end;

{ Build full path from relative path }
function BuildFullPath(const FilePath: string): string;
begin
  if FilePath = '' then
  begin
    Result := '';
    Exit;
  end;

  if FilePath[1] = '/' then
    Result := FilePath
  else
    Result := GWorkingDirectory + FilePath;
end;

{ Delete a file or directory }
function DeletePath(const Path: string; Recursive: Boolean): TToolExecutionResult;
var
  FullPath: string;
  IsDir: Boolean;
  F: TextFile;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';

  { Validate path }
  if not IsPathAllowed(Path) then
  begin
    Result.ErrorMessage := 'Access denied: path outside working directory';
    Exit;
  end;

  { Build full path }
  FullPath := BuildFullPath(Path);

  { Check if path exists }
  if not FileExists(FullPath) and not DirectoryExists(FullPath) then
  begin
    Result.ErrorMessage := 'Path not found: ' + FullPath;
    Exit;
  end;

  { Check if it's a file or directory }
  IsDir := DirectoryExists(FullPath);

  { Try to delete }
  try
    if IsDir then
    begin
      { Delete directory }
      RmDir(FullPath);
      Result.Success := True;
      Result.Output := 'Directory deleted: ' + Path;
    end
    else
    begin
      { Delete file using Erase }
      AssignFile(F, FullPath);
      Erase(F);
      Result.Success := True;
      Result.Output := 'File deleted: ' + Path;
    end;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Failed to delete: ' + E.Message;
    end;
  end;
end;

{ Main tool execution function }
function DeleteToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  Path: string;
  Recursive: Boolean;
  WorkInput, RecursiveStr: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  { Extract parameters }
  Path := ExtractJSONString(WorkInput, 'path');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'file_path');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'file');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'directory');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'dir');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'target');

  { Default: non-recursive for safety }
  Recursive := False;
  RecursiveStr := ExtractJSONString(WorkInput, 'recursive');
  if RecursiveStr <> '' then
  begin
    Recursive := (LowerCase(RecursiveStr) = 'true') or (RecursiveStr = '1');
  end;

  { Validate required parameters }
  if Path = '' then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Missing required parameter: path is required';
    Exit;
  end;

  { Execute delete }
  Result := DeletePath(Path, Recursive);
end;

end.