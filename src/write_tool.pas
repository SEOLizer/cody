{
  Write Tool - Write content to a file.
  Restricted to working directory.
}
unit write_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function WriteFileContent(const FilePath, Content: string): TToolExecutionResult;
function WriteToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor;

function ExtractJSONString(const JSON, Key: string): string;
var KeyPos, ValueStart, ValueEnd: Integer; InString: Boolean;
begin
  Result := '';
  { Search for "key": - the colon ensures we find a key, not a value }
  KeyPos := Pos('"' + Key + '":', JSON);
  if KeyPos = 0 then Exit;
  
  { Value starts after the colon }
  ValueStart := KeyPos + Length(Key) + 3; { Past "key": }
  while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
    Inc(ValueStart);
  if ValueStart > Length(JSON) then Exit;
  
  if JSON[ValueStart] = '"' then
  begin
    Inc(ValueStart); ValueEnd := ValueStart; InString := True;
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

function WriteFileContent(const FilePath, Content: string): TToolExecutionResult;
var F: TextFile; Dir: string; FullPath: string;
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
    
  if FullPath = '' then begin Result.ErrorMessage := 'No file path'; Exit; end;
  Dir := ExtractFilePath(FullPath);
  if (Dir <> '') and not DirectoryExists(Dir) then
  begin
    try ForceDirectories(Dir) except on E: Exception do begin Result.ErrorMessage := 'Cannot create dir'; Exit; end; end;
  end;
  try
    AssignFile(F, FullPath); Rewrite(F); Write(F, Content); CloseFile(F);
    Result.Success := True; Result.Output := 'File written: ' + FullPath;
  except on E: Exception do Result.ErrorMessage := 'Error: ' + E.Message; end;
end;

function WriteToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var FilePath, Content, WorkInput: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  { Extract file path and content }
  FilePath := ExtractJSONString(WorkInput, 'file_path');
  if FilePath = '' then FilePath := ExtractJSONString(WorkInput, 'path');
  if FilePath = '' then FilePath := ExtractJSONString(WorkInput, 'filename');
  if FilePath = '' then FilePath := ExtractJSONString(WorkInput, 'name');
  
  Content := ExtractJSONString(WorkInput, 'content');
  if Content = '' then Content := ExtractJSONString(WorkInput, 'text');
  if Content = '' then Content := ExtractJSONString(WorkInput, 'body');
  if Content = '' then Content := ExtractJSONString(WorkInput, 'data');
  if Content = '' then Content := ExtractJSONString(WorkInput, 'value');
  
  Result := WriteFileContent(FilePath, Content);
end;

end.