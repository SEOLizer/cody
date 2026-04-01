{
  Mkdir Tool - Create directories.
}
unit mkdir_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function CreateDirectory(const Path: string; CreateParents: Boolean): TToolExecutionResult;
function MkdirToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

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

{ Create directory }
function CreateDirectory(const Path: string; CreateParents: Boolean): TToolExecutionResult;
var
  FullPath: string;
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

  { Check if directory already exists }
  if DirectoryExists(FullPath) then
  begin
    Result.ErrorMessage := 'Directory already exists: ' + FullPath;
    Exit;
  end;

  { Check if a file with the same name exists }
  if FileExists(FullPath) then
  begin
    Result.ErrorMessage := 'A file with this name already exists: ' + FullPath;
    Exit;
  end;

  { Create directory }
  try
    if CreateParents then
      CreateDir(FullPath)  { This creates parent dirs }
    else
      MkDir(FullPath);    { This requires parent to exist }
      
    Result.Success := True;
    Result.Output := 'Directory created: ' + Path;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Failed to create directory: ' + E.Message;
    end;
  end;
end;

{ Main tool execution function }
function MkdirToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  Path: string;
  CreateParents: Boolean;
  WorkInput, ParentsStr: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  { Extract parameters }
  Path := ExtractJSONString(WorkInput, 'path');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'directory');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'dir');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'name');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'folder');

  { Default: create parent directories }
  CreateParents := True;
  ParentsStr := ExtractJSONString(WorkInput, 'parents');
  if ParentsStr <> '' then
  begin
    CreateParents := (LowerCase(ParentsStr) = 'true') or (ParentsStr = '1');
  end;

  { Validate required parameters }
  if Path = '' then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Missing required parameter: path is required';
    Exit;
  end;

  { Execute create directory }
  Result := CreateDirectory(Path, CreateParents);
end;

end.