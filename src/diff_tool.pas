{
  Diff Tool - Compare two files and show differences.
  Uses line-by-line comparison to show differences.
}
unit diff_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function DiffFiles(const FilePath1, FilePath2: string): TToolExecutionResult;
function DiffToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

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

{ Compare two files - line by line }
function DiffFiles(const FilePath1, FilePath2: string): TToolExecutionResult;
var
  FullPath1, FullPath2: string;
  F1, F2: TextFile;
  Line1, Line2: string;
  LineNum: Integer;
  Differences: string;
  Identical: Boolean;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';

  { Validate paths }
  if not IsPathAllowed(FilePath1) then
  begin
    Result.ErrorMessage := 'Access denied: path1 outside working directory';
    Exit;
  end;

  if not IsPathAllowed(FilePath2) then
  begin
    Result.ErrorMessage := 'Access denied: path2 outside working directory';
    Exit;
  end;

  { Build full paths }
  FullPath1 := BuildFullPath(FilePath1);
  FullPath2 := BuildFullPath(FilePath2);

  { Check if files exist }
  if not FileExists(FullPath1) then
  begin
    Result.ErrorMessage := 'File not found: ' + FullPath1;
    Exit;
  end;

  if not FileExists(FullPath2) then
  begin
    Result.ErrorMessage := 'File not found: ' + FullPath2;
    Exit;
  end;

  { Read and compare files line by line }
  Differences := '';
  LineNum := 1;
  Identical := True;

  try
    AssignFile(F1, FullPath1);
    Reset(F1);
    AssignFile(F2, FullPath2);
    Reset(F2);

    try
      while (not EOF(F1)) or (not EOF(F2)) do
      begin
        if EOF(F1) then
        begin
          Differences := Differences + 'Line ' + IntToStr(LineNum) + ': + ' + Line2 + LineEnding;
          Identical := False;
          if not EOF(F2) then ReadLn(F2, Line2);
        end
        else if EOF(F2) then
        begin
          Differences := Differences + 'Line ' + IntToStr(LineNum) + ': - ' + Line1 + LineEnding;
          Identical := False;
          if not EOF(F1) then ReadLn(F1, Line1);
        end
        else
        begin
          ReadLn(F1, Line1);
          ReadLn(F2, Line2);
          if Line1 <> Line2 then
          begin
            Differences := Differences + 'Line ' + IntToStr(LineNum) + ':' + LineEnding;
            Differences := Differences + '  - ' + Line1 + LineEnding;
            Differences := Differences + '  + ' + Line2 + LineEnding;
            Identical := False;
          end;
        end;
        Inc(LineNum);
      end;
    finally
      CloseFile(F1);
      CloseFile(F2);
    end;
  except
    on E: Exception do
    begin
      Result.ErrorMessage := 'Error reading files: ' + E.Message;
      Exit;
    end;
  end;

  if Identical then
  begin
    Result.Success := True;
    Result.Output := 'Files are identical: ' + FilePath1 + ' and ' + FilePath2;
  end
  else
  begin
    Result.Success := True;
    Result.Output := 'Files differ at ' + IntToStr(LineNum - 1) + ' lines:' + LineEnding + LineEnding + Differences;
  end;
end;

{ Main tool execution function }
function DiffToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  FilePath1, FilePath2: string;
  WorkInput: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  { Extract parameters }
  FilePath1 := ExtractJSONString(WorkInput, 'file_path1');
  if FilePath1 = '' then FilePath1 := ExtractJSONString(WorkInput, 'path1');
  if FilePath1 = '' then FilePath1 := ExtractJSONString(WorkInput, 'file1');

  FilePath2 := ExtractJSONString(WorkInput, 'file_path2');
  if FilePath2 = '' then FilePath2 := ExtractJSONString(WorkInput, 'path2');
  if FilePath2 = '' then FilePath2 := ExtractJSONString(WorkInput, 'file2');

  { Validate required parameters }
  if (FilePath1 = '') or (FilePath2 = '') then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Missing required parameters: file_path1 and file_path2 are required';
    Exit;
  end;

  { Compare files }
  Result := DiffFiles(FilePath1, FilePath2);
end;

end.