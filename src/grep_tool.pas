{
  Grep Tool - Search for content in files.
}
unit grep_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function GrepSearch(const Pattern, Path, Include: string): TToolExecutionResult;
function GrepToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

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

function MatchesInclude(const Filename, Include: string): Boolean;
var Ext: string;
begin
  if Include = '' then Exit(True);
  Ext := ExtractFileExt(Filename);
  if Ext <> '' then Ext := Copy(Ext, 2, Length(Ext) - 1);
  Result := Pos('*.' + Ext, Include) > 0;
end;

function GrepInFile(const Filename: string; const Pattern: string; var Output: string): Boolean;
var F: TextFile; Line: string; LineNum: Integer;
begin Result := False; Output := '';
  if not FileExists(Filename) then Exit;
  try AssignFile(F, Filename); Reset(F); LineNum := 0;
    while not EOF(F) do begin ReadLn(F, Line); Inc(LineNum);
      if Pos(Pattern, Line) > 0 then begin Output := Output + Filename + ':' + IntToStr(LineNum) + ': ' + Line + LineEnding; Result := True; end;
    end;
  except end;
  CloseFile(F);
end;

procedure GrepSearchDir(const BaseDir: string; const Pattern, Include: string; var Output: string);
var SearchRec: TSearchRec; FullPath: string; FileResults: string;
begin
  FullPath := BaseDir; if FullPath[Length(FullPath)] <> '/' then FullPath := FullPath + '/';
  if FindFirst(BaseDir + '/*', faAnyFile, SearchRec) = 0 then
  begin repeat if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
    begin if (SearchRec.Attr and faDirectory) = faDirectory then GrepSearchDir(FullPath + SearchRec.Name, Pattern, Include, Output)
      else if MatchesInclude(SearchRec.Name, Include) then if GrepInFile(FullPath + SearchRec.Name, Pattern, FileResults) then Output := Output + FileResults; end;
    until FindNext(SearchRec) <> 0; end;
  FindClose(SearchRec);
end;

function GrepSearch(const Pattern, Path, Include: string): TToolExecutionResult;
var SearchPath: string;
begin
  Result.Success := False; Result.Output := ''; Result.ErrorMessage := '';
  if Pattern = '' then begin Result.ErrorMessage := 'No pattern'; Exit; end;
  if Path = '' then 
    SearchPath := GWorkingDirectory
  else
    SearchPath := Path;
  GrepSearchDir(SearchPath, Pattern, Include, Result.Output);
  Result.Success := True;
  if Result.Output = '' then Result.Output := 'No matches found';
end;

function GrepToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var Pattern, Path, Include: string;
  WorkInput: string;
begin
  { Unescape the JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  Pattern := ExtractJSONString(WorkInput, 'pattern');
  Path := ExtractJSONString(WorkInput, 'path');
  if Path = '' then Path := ExtractJSONString(WorkInput, 'directory');
  Include := ExtractJSONString(WorkInput, 'include');
  if Include = '' then Include := ExtractJSONString(WorkInput, 'glob');
  Result := GrepSearch(Pattern, Path, Include);
end;

end.