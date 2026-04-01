{
  LS Tool - List directory contents.
  Similar to 'ls' command - shows files and directories in a flat list.
}
unit ls_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function ListDirectory(const Path: string; ShowHidden: Boolean): TToolExecutionResult;
function LSToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor;

{ Extract JSON string value - helper function }
function ExtractJSONString(const JSON, Key: string): string;
var
  KeyPos, ValueStart, ValueEnd: Integer;
  InString: Boolean;
begin
  Result := '';
  { Search for "key": - the colon ensures we find a key, not a value }
  KeyPos := Pos('"' + Key + '":', JSON);
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

{ List directory contents }
function ListDirectory(const Path: string; ShowHidden: Boolean): TToolExecutionResult;
var
  FullPath: string;
  SearchRec: TSearchRec;
  Found: Integer;
  Output: string;
  DirCount, FileCount: Integer;
  IsLastDir: Boolean;
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
  if (Length(FullPath) > 0) and (FullPath[Length(FullPath)] <> '/') then
    FullPath := FullPath + '/';

  { Initialize counters }
  DirCount := 0;
  FileCount := 0;
  Output := '';

  { First pass: count directories }
  Found := FindFirst(FullPath + '*', faAnyFile, SearchRec);
  try
    while Found = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if ShowHidden or (SearchRec.Name[1] <> '.') then
        begin
          if (SearchRec.Attr and faDirectory) <> 0 then
            Inc(DirCount)
          else
            Inc(FileCount);
        end;
      end;
      Found := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;

  { Second pass: output directories first }
  Found := FindFirst(FullPath + '*', faDirectory, SearchRec);
  try
    while Found = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if ShowHidden or (SearchRec.Name[1] <> '.') then
        begin
          if (SearchRec.Attr and faDirectory) <> 0 then
            Output := Output + SearchRec.Name + '/' + LineEnding;
        end;
      end;
      Found := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;

  { Third pass: output files }
  Found := FindFirst(FullPath + '*', faDirectory, SearchRec);
  try
    IsLastDir := (DirCount = 0);
    while Found = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if ShowHidden or (SearchRec.Name[1] <> '.') then
        begin
          if (SearchRec.Attr and faDirectory) = 0 then
          begin
            Output := Output + SearchRec.Name + LineEnding;
          end;
        end;
      end;
      Found := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;

  { Format output }
  Result.Success := True;
  if Output = '' then
    Output := '(empty directory)';
  
  Result.Output := 'Path: ' + Path + LineEnding +
    'Files: ' + IntToStr(FileCount) + LineEnding +
    'Directories: ' + IntToStr(DirCount) + LineEnding + LineEnding +
    Output;
end;

{ Main tool execution function }
function LSToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  Path: string;
  ShowHidden: Boolean;
  WorkInput, HiddenStr: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  { Extract parameters }
  Path := ExtractJSONString(WorkInput, 'path');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'directory');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'dir');

  { Default: no hidden files }
  ShowHidden := False;
  HiddenStr := ExtractJSONString(WorkInput, 'show_hidden');
  if HiddenStr <> '' then
    ShowHidden := (LowerCase(HiddenStr) = 'true') or (HiddenStr = '1');
  
  HiddenStr := ExtractJSONString(WorkInput, 'all');
  if HiddenStr <> '' then
    ShowHidden := (LowerCase(HiddenStr) = 'true') or (HiddenStr = '1');

  { Default to current directory }
  if Path = '' then
    Path := '.';

  { Execute }
  Result := ListDirectory(Path, ShowHidden);
end;

end.