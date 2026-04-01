{
  FileTree Tool - Display directory tree structure.
  Shows the contents of a directory in a tree format.
}
unit file_tree_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function FileTree(const Path: string; MaxDepth: Integer): TToolExecutionResult;
function FileTreeToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

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
    Result := GWorkingDirectory;
    Exit;
  end;

  if FilePath[1] = '/' then
    Result := FilePath
  else
    Result := GWorkingDirectory + FilePath;
end;

{ Count files and directories recursively }
procedure CountItems(const Path: string; CurrentDepth: Integer; MaxDepth: Integer; var FileCount, DirCount: Integer);
var
  SearchRec: TSearchRec;
  Found: Integer;
begin
  if CurrentDepth > MaxDepth then Exit;

  Found := FindFirst(Path + '*', faAnyFile, SearchRec);
  try
    while Found = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          Inc(DirCount);
          CountItems(Path + SearchRec.Name + '/', CurrentDepth + 1, MaxDepth, FileCount, DirCount);
        end
        else
        begin
          Inc(FileCount);
        end;
      end;
      Found := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;
end;

{ List directory tree recursively }
procedure ListTree(const Path: string; const Indent: string; CurrentDepth: Integer; MaxDepth: Integer; var Output: string);
var
  SearchRec: TSearchRec;
  Found: Integer;
  DirList: array of string;
  FileList: array of string;
  DirCount, FileCount: Integer;
  i: Integer;
begin
  if CurrentDepth > MaxDepth then Exit;

  DirCount := 0;
  FileCount := 0;
  SetLength(DirList, 0);
  SetLength(FileList, 0);

  { Collect directories first }
  Found := FindFirst(Path + '*', faDirectory, SearchRec);
  try
    while Found = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if (SearchRec.Attr and faDirectory) <> 0 then
        begin
          SetLength(DirList, DirCount + 1);
          DirList[DirCount] := SearchRec.Name;
          Inc(DirCount);
        end;
      end;
      Found := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;

  { Collect files }
  Found := FindFirst(Path + '*', faDirectory, SearchRec);
  try
    while Found = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if (SearchRec.Attr and faDirectory) = 0 then
        begin
          SetLength(FileList, FileCount + 1);
          FileList[FileCount] := SearchRec.Name;
          Inc(FileCount);
        end;
      end;
      Found := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;

  { Output directories }
  for i := 0 to DirCount - 1 do
  begin
    Output := Output + Indent + '├── ' + DirList[i] + '/' + LineEnding;
    if CurrentDepth < MaxDepth then
      ListTree(Path + DirList[i] + '/', Indent + '│   ', CurrentDepth + 1, MaxDepth, Output);
  end;

  { Output files }
  for i := 0 to FileCount - 1 do
  begin
    if i = FileCount - 1 then
      Output := Output + Indent + '└── ' + FileList[i] + LineEnding
    else
      Output := Output + Indent + '├── ' + FileList[i] + LineEnding;
  end;
end;

{ Main FileTree function }
function FileTree(const Path: string; MaxDepth: Integer): TToolExecutionResult;
var
  FullPath: string;
  Output: string;
  FileCount, DirCount: Integer;
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

  { Check if directory exists }
  if not DirectoryExists(FullPath) then
  begin
    Result.ErrorMessage := 'Directory not found: ' + FullPath;
    Exit;
  end;

  { Ensure trailing slash }
  if FullPath[Length(FullPath)] <> '/' then
    FullPath := FullPath + '/';

  { Count items }
  FileCount := 0;
  DirCount := 0;
  CountItems(FullPath, 0, MaxDepth, FileCount, DirCount);

  { Build tree }
  Output := '';
  ListTree(FullPath, '', 0, MaxDepth, Output);

  { Format output }
  Result.Success := True;
  Result.Output := 'Directory: ' + Path + LineEnding +
    'Files: ' + IntToStr(FileCount) + LineEnding +
    'Directories: ' + IntToStr(DirCount) + LineEnding + LineEnding +
    Output;
end;

{ Main tool execution function }
function FileTreeToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  Path: string;
  MaxDepth: Integer;
  WorkInput, DepthStr: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  { Extract parameters }
  Path := ExtractJSONString(WorkInput, 'path');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'directory');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'dir');

  { Default max depth is 3 }
  MaxDepth := 3;
  DepthStr := ExtractJSONString(WorkInput, 'max_depth');
  if DepthStr <> '' then
  begin
    try
      MaxDepth := StrToInt(DepthStr);
    except
      MaxDepth := 3;
    end;
  end;

  { Default to current directory }
  if Path = '' then
    Path := '.';

  { Execute }
  Result := FileTree(Path, MaxDepth);
end;

end.