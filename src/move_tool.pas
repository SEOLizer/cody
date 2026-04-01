{
  Move/Rename Tool - Move or rename files and directories.
}
unit move_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function MoveFile(const SourcePath, DestPath: string): TToolExecutionResult;
function MoveToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

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

{ Move or rename a file/directory }
function MoveFile(const SourcePath, DestPath: string): TToolExecutionResult;
var
  FullSource, FullDest: string;
  IsDir: Boolean;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';

  { Validate source path }
  if not IsPathAllowed(SourcePath) then
  begin
    Result.ErrorMessage := 'Access denied: source path outside working directory';
    Exit;
  end;

  { Validate destination path }
  if not IsPathAllowed(DestPath) then
  begin
    Result.ErrorMessage := 'Access denied: destination path outside working directory';
    Exit;
  end;

  { Build full paths }
  FullSource := BuildFullPath(SourcePath);
  FullDest := BuildFullPath(DestPath);

  { Check if source exists }
  if not FileExists(FullSource) and not DirectoryExists(FullSource) then
  begin
    Result.ErrorMessage := 'Source not found: ' + FullSource;
    Exit;
  end;

  { Check if it's a file or directory }
  IsDir := DirectoryExists(FullSource);

  { Check if destination already exists }
  if FileExists(FullDest) or DirectoryExists(FullDest) then
  begin
    Result.ErrorMessage := 'Destination already exists: ' + FullDest;
    Exit;
  end;

  { Try to rename/move }
  try
    if IsDir then
    begin
      { Move directory }
      RenameFile(FullSource, FullDest);
      Result.Success := True;
      Result.Output := 'Directory moved/renamed from ' + SourcePath + ' to ' + DestPath;
    end
    else
    begin
      { Move file }
      RenameFile(FullSource, FullDest);
      Result.Success := True;
      Result.Output := 'File moved/renamed from ' + SourcePath + ' to ' + DestPath;
    end;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Failed to move/rename: ' + E.Message;
    end;
  end;
end;

{ Main tool execution function }
function MoveToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  SourcePath, DestPath: string;
  WorkInput: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  { Extract parameters }
  { Source path - various possible names }
  SourcePath := ExtractJSONString(WorkInput, 'source');
  if SourcePath = '' then SourcePath := ExtractJSONString(WorkInput, 'source_path');
  if SourcePath = '' then SourcePath := ExtractJSONString(WorkInput, 'path');
  if SourcePath = '' then SourcePath := ExtractJSONString(WorkInput, 'file_path');
  if SourcePath = '' then SourcePath := ExtractJSONString(WorkInput, 'from');

  { Destination path - various possible names }
  DestPath := ExtractJSONString(WorkInput, 'destination');
  if DestPath = '' then DestPath := ExtractJSONString(WorkInput, 'dest');
  if DestPath = '' then DestPath := ExtractJSONString(WorkInput, 'dest_path');
  if DestPath = '' then DestPath := ExtractJSONString(WorkInput, 'target');
  if DestPath = '' then DestPath := ExtractJSONString(WorkInput, 'to');
  if DestPath = '' then DestPath := ExtractJSONString(WorkInput, 'new_path');
  if DestPath = '' then DestPath := ExtractJSONString(WorkInput, 'new_name');

  { Validate required parameters }
  if (SourcePath = '') or (DestPath = '') then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Missing required parameters: source and destination are required';
    Exit;
  end;

  { Execute move/rename }
  Result := MoveFile(SourcePath, DestPath);
end;

end.