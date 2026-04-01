{
  WebSearch Tool - Search the web for information.
  Uses search APIs to find relevant results.
}
unit websearch_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, Types, Unix;

function SearchWeb(Query: string; NumResults: Integer): TToolExecutionResult;
function WebSearchToolExecute(ToolName: string; InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor;

{ Extract JSON string value - helper function }
function ExtractJSONString(JSON: string; Key: string): string;
var
  KeyPos, ValueStart, ValueEnd: Integer;
  InString: Boolean;
begin
  Result := '';
  KeyPos := Pos('"' + Key + '":', JSON);
  if KeyPos = 0 then Exit;
  
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

{ URL encode a string }
function URLEncode(S: string): string;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    case S[i] of
      'A'..'Z', 'a'..'z', '0'..'9', '-', '_', '.', '~':
        Result := Result + S[i];
      ' ':
        Result := Result + '%20';
      else
        Result := Result + '%' + IntToHex(Ord(S[i]), 2);
    end;
  end;
end;

{ Extract search results from DuckDuckGo HTML }
procedure ParseSearchResults(HTML: string; var Results: string; MaxResults: Integer);
var
  Pos1, Pos2, Pos3: Integer;
  Title, URL, Snippet: string;
  Count: Integer;
  TempStr: string;
begin
  Results := '';
  Count := 0;
  Pos1 := 1;

  while (Count < MaxResults) and (Pos1 < Length(HTML)) do
  begin
    Pos1 := Pos('class="result__body"', Copy(HTML, Pos1, Length(HTML) - Pos1 + 1));
    if Pos1 = 0 then Break;
    Pos1 := Pos1 + Pos1 - 1;

    Pos2 := Pos('<a class="result__a"', Copy(HTML, Pos1, Length(HTML) - Pos1 + 1));
    if Pos2 = 0 then Break;
    Pos2 := Pos1 + Pos2 - 1;
    
    Pos3 := Pos('>', Copy(HTML, Pos2, Length(HTML) - Pos2 + 1));
    if Pos3 = 0 then Break;
    Pos3 := Pos2 + Pos3;
    
    Pos2 := Pos('</a>', Copy(HTML, Pos3, Length(HTML) - Pos3 + 1));
    if Pos2 = 0 then Break;
    
    Title := Copy(HTML, Pos3, Pos2 - Pos3);
    Title := Trim(StringReplace(Title, '&amp;', '&', [rfReplaceAll]));
    Title := Trim(StringReplace(Title, '&quot;', '"', [rfReplaceAll]));
    Title := Trim(StringReplace(Title, '&#39;', '''', [rfReplaceAll]));

    Pos2 := Pos('href="', Copy(HTML, Pos1, Length(HTML) - Pos1 + 1));
    if Pos2 > 0 then
    begin
      Pos2 := Pos1 + Pos2 - 1 + 6;
      Pos3 := Pos('"', Copy(HTML, Pos2, Length(HTML) - Pos2 + 1));
      if Pos3 > 0 then
        URL := Copy(HTML, Pos2, Pos3 - 1)
      else
        URL := '(unknown)';
    end
    else
      URL := '(unknown)';

    Pos2 := Pos('class="result__snippet"', Copy(HTML, Pos1, Length(HTML) - Pos1 + 1));
    if Pos2 > 0 then
    begin
      Pos2 := Pos1 + Pos2 - 1;
      Pos3 := Pos('>', Copy(HTML, Pos2, Length(HTML) - Pos2 + 1));
      if Pos3 > 0 then
      begin
        Pos3 := Pos2 + Pos3;
        Pos2 := Pos('</a>', Copy(HTML, Pos3, Length(HTML) - Pos3 + 1));
        if Pos2 > 0 then
        begin
          Snippet := Copy(HTML, Pos3, Pos2 - Pos3);
          Snippet := Trim(StringReplace(Snippet, '&amp;', '&', [rfReplaceAll]));
          Snippet := Trim(StringReplace(Snippet, '&quot;', '"', [rfReplaceAll]));
          Snippet := Trim(StringReplace(Snippet, '&#39;', '''', [rfReplaceAll]));
          Snippet := Trim(StringReplace(Snippet, '&hellip;', '...', [rfReplaceAll]));
        end
        else
          Snippet := '';
      end
      else
        Snippet := '';
    end
    else
      Snippet := '';

    Inc(Count);
    Results := Results + IntToStr(Count) + '. ' + Title + LineEnding;
    Results := Results + '   URL: ' + URL + LineEnding;
    if Snippet <> '' then
      Results := Results + '   ' + Snippet + LineEnding;
    Results := Results + LineEnding;
  end;

  if Count = 0 then
    Results := 'No results found. The search format may have changed.';
end;

{ Perform web search using DuckDuckGo }
function SearchWeb(Query: string; NumResults: Integer): TToolExecutionResult;
var
  Command: string;
  OutputFile: string;
  ExitCode: Integer;
  HTML: string;
  Results: string;
  F: Text;
  Line: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';

  if Trim(Query) = '' then
  begin
    Result.ErrorMessage := 'Search query is required';
    Exit;
  end;

  if NumResults < 1 then NumResults := 5;
  if NumResults > 20 then NumResults := 20;

  OutputFile := GetTempDir + 'websearch_' + IntToStr(GetTickCount64) + '.html';
  Command := 'curl -s -L --max-time 30 "https://html.duckduckgo.com/html/?q=' + URLEncode(Query) + '" > "' + OutputFile + '" 2>&1';

  ExitCode := fpsystem(Command);
  
  if ExitCode <> 0 then
  begin
    Result.ErrorMessage := 'Search failed: curl exited with code ' + IntToStr(ExitCode);
    Exit;
  end;

  if FileExists(OutputFile) then
  begin
    HTML := '';
    AssignFile(F, OutputFile);
    Reset(F);
    try
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        HTML := HTML + Line + LineEnding;
      end;
    finally
      CloseFile(F);
    end;

    if FileExists(OutputFile) then
      DeleteFile(OutputFile);

    if Trim(HTML) = '' then
    begin
      Result.ErrorMessage := 'Empty response from search engine';
    end
    else
    begin
      ParseSearchResults(HTML, Results, NumResults);
      if Results = '' then
        Results := 'No results found. The search format may have changed.';
      Result.Output := 'Search query: ' + Query + LineEnding;
      Result.Output := Result.Output + 'Results: ' + IntToStr(NumResults) + LineEnding + LineEnding;
      Result.Output := Result.Output + Results;
      Result.Success := True;
    end;
  end
  else
  begin
    Result.ErrorMessage := 'Failed to create output file';
  end;
end;

{ Main tool execution function }
function WebSearchToolExecute(ToolName: string; InputJSON: string): TToolExecutionResult;
var
  Query: string;
  NumResults: Integer;
  WorkInput: string;
  NumResultsStr: string;
begin
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  Query := ExtractJSONString(WorkInput, 'query');
  if Query = '' then Query := ExtractJSONString(WorkInput, 'search');
  if Query = '' then Query := ExtractJSONString(WorkInput, 'term');
  if Query = '' then Query := ExtractJSONString(WorkInput, 'q');

  NumResults := 5;
  NumResultsStr := ExtractJSONString(WorkInput, 'num_results');
  if NumResultsStr <> '' then
  begin
    try
      NumResults := StrToInt(NumResultsStr);
    except
      NumResults := 5;
    end;
  end;
  
  if NumResultsStr = '' then
  begin
    NumResultsStr := ExtractJSONString(WorkInput, 'limit');
    if NumResultsStr <> '' then
    begin
      try
        NumResults := StrToInt(NumResultsStr);
      except
        NumResults := 5;
      end;
    end;
  end;

  if Query = '' then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'Search query is required';
    Exit;
  end;

  Result := SearchWeb(Query, NumResults);
end;

end.