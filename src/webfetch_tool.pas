{
  WebFetch Tool - Fetch content from URLs.
  Uses curl to retrieve web page content.
}
unit webfetch_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, Types, Unix;

function FetchURL(URL: string; MaxLength: Integer): TToolExecutionResult;
function WebFetchToolExecute(ToolName: string; InputJSON: string): TToolExecutionResult;

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

{ Check if URL is valid and allowed }
function IsURLAllowed(URL: string): Boolean;
var
  LowerURL: string;
begin
  Result := False;
  if URL = '' then Exit;

  LowerURL := LowerCase(URL);
  if (Pos('http://', LowerURL) = 1) or (Pos('https://', LowerURL) = 1) then
    Result := True;
end;

{ Truncate content to max length }
function TruncateContent(Content: string; MaxLength: Integer): string;
begin
  if (MaxLength > 0) and (Length(Content) > MaxLength) then
  begin
    Result := Copy(Content, 1, MaxLength) + LineEnding + '... [truncated]';
    Result := Result + LineEnding + 'Original length: ' + IntToStr(Length(Content)) + ' characters';
  end
  else
    Result := Content;
end;

{ Fetch URL content using curl }
function FetchURL(URL: string; MaxLength: Integer): TToolExecutionResult;
var
  Command: string;
  OutputFile: string;
  ExitCode: Integer;
  FileContent: string;
  F: Text;
  Line: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';

  if not IsURLAllowed(URL) then
  begin
    Result.ErrorMessage := 'Invalid URL: only http:// and https:// URLs are allowed';
    Exit;
  end;

  OutputFile := GetTempDir + 'webfetch_' + IntToStr(GetTickCount64) + '.txt';
  Command := 'curl -s -L --max-time 30 --max-filesize 10485760 "' + URL + '" > "' + OutputFile + '" 2>&1';
  
  ExitCode := fpsystem(Command);
  
  if ExitCode <> 0 then
  begin
    Result.ErrorMessage := 'Failed to fetch URL: curl exited with code ' + IntToStr(ExitCode);
    Exit;
  end;

  if FileExists(OutputFile) then
  begin
    FileContent := '';
    AssignFile(F, OutputFile);
    Reset(F);
    try
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        FileContent := FileContent + Line + LineEnding;
      end;
    finally
      CloseFile(F);
    end;

    if FileExists(OutputFile) then
      DeleteFile(OutputFile);

    if Trim(FileContent) = '' then
    begin
      Result.ErrorMessage := 'Empty response from URL';
    end
    else
    begin
      Result.Output := TruncateContent(FileContent, MaxLength);
      Result.Success := True;
    end;
  end
  else
  begin
    Result.ErrorMessage := 'Failed to create output file';
  end;
end;

{ Main tool execution function }
function WebFetchToolExecute(ToolName: string; InputJSON: string): TToolExecutionResult;
var
  URL: string;
  MaxLength: Integer;
  WorkInput: string;
  MaxLenStr: string;
begin
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);

  URL := ExtractJSONString(WorkInput, 'url');
  if URL = '' then URL := ExtractJSONString(WorkInput, 'href');
  if URL = '' then URL := ExtractJSONString(WorkInput, 'link');
  if URL = '' then URL := ExtractJSONString(WorkInput, 'address');

  MaxLength := 50000;
  MaxLenStr := ExtractJSONString(WorkInput, 'max_length');
  if MaxLenStr <> '' then
  begin
    try
      MaxLength := StrToInt(MaxLenStr);
    except
      MaxLength := 50000;
    end;
  end;

  if URL = '' then
  begin
    Result.Success := False;
    Result.ErrorMessage := 'URL is required';
    Exit;
  end;

  Result := FetchURL(URL, MaxLength);
end;

end.