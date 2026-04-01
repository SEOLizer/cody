{
  Edit Tool - Edit file by find/replace.
  Restricted to working directory.
}
unit edit_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function EditFileContent(const FilePath, OldString, NewString: string): TToolExecutionResult;
function EditToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor;

function ExtractJSONString(const JSON, Key: string): string;
var KeyPos, ValueStart, ValueEnd: Integer; InString: Boolean;
begin
  Result := ''; KeyPos := Pos('"' + Key + '"', JSON);
  if KeyPos = 0 then Exit;
  ValueStart := KeyPos + Length(Key) + 3;
  while ValueStart <= Length(JSON) do
  begin
    if JSON[ValueStart] = ':' then begin Inc(ValueStart); while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do Inc(ValueStart); Break; end;
    Inc(ValueStart);
  end;
  if ValueStart > Length(JSON) then Exit;
  if JSON[ValueStart] = '"' then
  begin
    Inc(ValueStart); ValueEnd := ValueStart; InString := True;
    while (ValueEnd <= Length(JSON)) and InString do begin if JSON[ValueEnd] = '\' then Inc(ValueEnd, 2) else if JSON[ValueEnd] = '"' then InString := False else Inc(ValueEnd); end;
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end
  else
  begin
    ValueEnd := ValueStart;
    while (ValueEnd <= Length(JSON)) and not (JSON[ValueEnd] in [',', '}', ']']) do Inc(ValueEnd);
    Result := Copy(JSON, ValueStart, ValueEnd - ValueStart);
  end;
end;

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

function EditFileContent(const FilePath, OldString, NewString: string): TToolExecutionResult;
var F: TextFile; Content, Line: string; FullPath: string;
begin
  Result.Success := False; Result.Output := ''; Result.ErrorMessage := '';
  
  { Validate path }
  if not IsPathAllowed(FilePath) then
  begin
    Result.ErrorMessage := 'Access denied: path outside working directory';
    Exit;
  end;
  
  { Build full path }
  if FilePath[1] = '/' then
    FullPath := FilePath
  else
    FullPath := GWorkingDirectory + FilePath;
    
  if (FullPath = '') or (OldString = '') then begin Result.ErrorMessage := 'Missing params'; Exit; end;
  if not FileExists(FullPath) then begin Result.ErrorMessage := 'File not found: ' + FullPath; Exit; end;
  Content := ''; AssignFile(F, FullPath); Reset(F);
  try while not EOF(F) do begin ReadLn(F, Line); Content := Content + Line + LineEnding; end; finally CloseFile(F); end;
  if Pos(OldString, Content) = 0 then begin Result.ErrorMessage := 'old_string not found'; Exit; end;
  Content := StringReplace(Content, OldString, NewString, []);
  try AssignFile(F, FullPath); Rewrite(F); Write(F, Content); CloseFile(F); Result.Success := True; Result.Output := 'File edited: ' + FullPath; except on E: Exception do Result.ErrorMessage := 'Error: ' + E.Message; end;
end;

function EditToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var FilePath, OldStr, NewStr: string; WorkInput: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  FilePath := ExtractJSONString(WorkInput, 'file_path');
  if FilePath = '' then FilePath := ExtractJSONString(WorkInput, 'path');
  OldStr := ExtractJSONString(WorkInput, 'old_string');
  if OldStr = '' then OldStr := ExtractJSONString(WorkInput, 'replace');
  NewStr := ExtractJSONString(WorkInput, 'new_string');
  if NewStr = '' then NewStr := ExtractJSONString(WorkInput, 'with');
  Result := EditFileContent(FilePath, OldStr, NewStr);
end;

end.