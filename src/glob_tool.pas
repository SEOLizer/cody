{
  Glob Tool - Search for files by pattern (simplified).
}
unit glob_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function GlobFiles(const Pattern, Path: string): TToolExecutionResult;
function GlobToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

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
  ValueStart := KeyPos + Length(Key) + 3;
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

{ Simple glob matching - * matches anything between characters }
function SimpleMatch(const Filename, Pattern: string): Boolean;
var
  PatternPos, FilePos: Integer;
begin
  Result := False;
  PatternPos := 1;
  FilePos := 1;
  
  while (FilePos <= Length(Filename)) and (PatternPos <= Length(Pattern)) do
  begin
    if Pattern[PatternPos] = '*' then
    begin
      { Handle * - can match zero or more characters }
      if PatternPos = Length(Pattern) then
      begin
        { * at end matches everything remaining }
        Exit(True);
      end;
      { Advance past the * and find the next non-* character in pattern }
      Inc(PatternPos);
      while (PatternPos <= Length(Pattern)) and (Pattern[PatternPos] = '*') do
        Inc(PatternPos);
      
      if PatternPos > Length(Pattern) then
      begin
        { Pattern ends with *, matches everything }
        Exit(True);
      end;
      
      { Try to find the remaining pattern in filename }
      while (FilePos <= Length(Filename)) do
      begin
        if (Length(Filename) - FilePos + 1) < (Length(Pattern) - PatternPos + 1) then
          Exit(False);
        { Check if remaining pattern matches }
        if Copy(Filename, FilePos, Length(Pattern) - PatternPos + 1) = 
           Copy(Pattern, PatternPos, Length(Pattern) - PatternPos + 1) then
        begin
          Exit(True);
        end;
        Inc(FilePos);
      end;
      Exit(False);
    end
    else if Pattern[PatternPos] = '?' then
    begin
      { ? matches any single character }
      Inc(PatternPos);
      Inc(FilePos);
    end
    else if Pattern[PatternPos] <> Filename[FilePos] then
    begin
      Exit(False);
    end
    else
    begin
      Inc(PatternPos);
      Inc(FilePos);
    end;
  end;
  
  { Handle trailing * in pattern }
  while (PatternPos <= Length(Pattern)) and (Pattern[PatternPos] = '*') do
    Inc(PatternPos);
    
  Result := (PatternPos > Length(Pattern)) and (FilePos > Length(Filename));
end;

procedure GlobSearch(const BaseDir: string; const Pattern: string; var Output: string);
var SearchRec: TSearchRec; FullPath: string;
begin
  FullPath := BaseDir;
  if (Length(FullPath) > 0) and (FullPath[Length(FullPath)] <> '/') then FullPath := FullPath + '/';
  if FindFirst(BaseDir + '/*', faAnyFile, SearchRec) = 0 then
  begin
    repeat
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        if (SearchRec.Attr and faDirectory) = faDirectory then
          GlobSearch(FullPath + SearchRec.Name, Pattern, Output)
        else if SimpleMatch(SearchRec.Name, Pattern) then
          Output := Output + FullPath + SearchRec.Name + LineEnding;
      end;
    until FindNext(SearchRec) <> 0;
  end;
  FindClose(SearchRec);
end;

function GlobFiles(const Pattern, Path: string): TToolExecutionResult;
var SearchPath: string;
begin
  Result.Success := False; Result.Output := ''; Result.ErrorMessage := '';
  if Pattern = '' then begin Result.ErrorMessage := 'No pattern'; Exit; end;
  if Path = '' then 
    SearchPath := GWorkingDirectory
  else
    SearchPath := Path;
  GlobSearch(SearchPath, Pattern, Result.Output);
  Result.Success := True;
  if Result.Output = '' then Result.Output := 'No files found';
end;

function GlobToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var Pattern, Path, WorkInput: string;
begin
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  Pattern := ExtractJSONString(WorkInput, 'pattern');
  if Pattern = '' then
    Pattern := ExtractJSONString(WorkInput, 'glob');
  if Pattern = '' then
    Pattern := ExtractJSONString(WorkInput, 'query');
  if Pattern = '' then
    Pattern := ExtractJSONString(WorkInput, 'search');
  if Pattern = '' then
    Pattern := ExtractJSONString(WorkInput, 'file_pattern');
    
  Path := ExtractJSONString(WorkInput, 'path');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'directory');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'folder');
  
  Result := GlobFiles(Pattern, Path);
end;

end.