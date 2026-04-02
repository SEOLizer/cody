{
  Session Memory - Hintergrund-Speicher-Extraktion.
  - Erkennt Token-Schwellenwert oder Tool-Call-Anzahl
  - Extrahiert Key-Informationen aus dem Kontext
  - Speichert in Markdown-Datei (~/.agent/sessions/)
}
unit session_memory;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  { Session Memory State }
  TSessionMemoryState = record
    SessionID: string;
    StartTime: TDateTime;
    ToolCallCount: Integer;
    EstimatedTokens: Integer;
    LastExtraction: Integer;  { Tool call count at last extraction }
    ExtractionCount: Integer;
    MemoryFilePath: string;
  end;

  { Key Information extracted from context }
  TExtractedInfo = record
    TaskSummary: string;
    FilesModified: array of string;
    Decisions: array of string;
    Errors: array of string;
    KeyFindings: array of string;
  end;

{ Initialize session memory }
procedure InitSessionMemory;

{ Get current session state }
function GetSessionState: TSessionMemoryState;

{ Update token/tool call tracking }
procedure UpdateSessionTracking(TokenCount, ToolCallCount: Integer);

{ Check if extraction should trigger }
function ShouldExtractMemory: Boolean;

{ Extract key information from conversation }
function ExtractKeyInformation(const Messages: TMessageArray): TExtractedInfo;

{ Save extracted info to markdown file }
procedure SaveMemoryToFile(const Info: TExtractedInfo);

{ Load existing memory file }
function LoadMemoryFromFile: string;

{ Get memory file path }
function GetMemoryFilePath: string;

{ Get session summary }
function GetSessionSummary: string;

implementation

var
  GSessionState: TSessionMemoryState;
  GExtractionThreshold: Integer = 10;  { Extract every 10 tool calls }
  GTokenThreshold: Integer = 16000;    { Extract when tokens exceed this }

procedure InitSessionMemory;
var
  HomeDir: string;
  SessionDir: string;
begin
  { Generate session ID from timestamp }
  GSessionState.SessionID := FormatDateTime('yyyymmdd-hhnnss', Now);
  GSessionState.StartTime := Now;
  GSessionState.ToolCallCount := 0;
  GSessionState.EstimatedTokens := 0;
  GSessionState.LastExtraction := 0;
  GSessionState.ExtractionCount := 0;
  
  { Create session directory }
  HomeDir := GetEnvironmentVariable('HOME');
  if HomeDir = '' then
    HomeDir := GetEnvironmentVariable('USERPROFILE');
  if HomeDir = '' then
    HomeDir := GetCurrentDir;
    
  SessionDir := HomeDir + DirectorySeparator + '.agent' + DirectorySeparator + 'sessions';
  
  if not DirectoryExists(SessionDir) then
    CreateDir(SessionDir);
    
  GSessionState.MemoryFilePath := SessionDir + DirectorySeparator + 
    'session-' + GSessionState.SessionID + '.md';
end;

function GetSessionState: TSessionMemoryState;
begin
  Result := GSessionState;
end;

procedure UpdateSessionTracking(TokenCount, ToolCallCount: Integer);
begin
  GSessionState.EstimatedTokens := TokenCount;
  GSessionState.ToolCallCount := ToolCallCount;
end;

function ShouldExtractMemory: Boolean;
var
  CallsSinceLastExtraction: Integer;
begin
  Result := False;
  
  { Check tool call threshold }
  CallsSinceLastExtraction := GSessionState.ToolCallCount - GSessionState.LastExtraction;
  if CallsSinceLastExtraction >= GExtractionThreshold then
  begin
    Result := True;
    Exit;
  end;
  
  { Check token threshold }
  if GSessionState.EstimatedTokens >= GTokenThreshold then
  begin
    Result := True;
    Exit;
  end;
end;

function ExtractKeyInformation(const Messages: TMessageArray): TExtractedInfo;
var
  i: Integer;
  Content: string;
  LowerContent: string;
begin
  { Initialize result }
  Result.TaskSummary := '';
  SetLength(Result.FilesModified, 0);
  SetLength(Result.Decisions, 0);
  SetLength(Result.Errors, 0);
  SetLength(Result.KeyFindings, 0);
  
  { Scan messages for key information }
  for i := 0 to Length(Messages) - 1 do
  begin
    Content := Messages[i].TextContent;
    LowerContent := LowerCase(Content);
    
    { Extract file references }
    if (Pos('.pas', LowerContent) > 0) or (Pos('.ts', LowerContent) > 0) or
       (Pos('.js', LowerContent) > 0) or (Pos('.py', LowerContent) > 0) or
       (Pos('.md', LowerContent) > 0) then
    begin
      { Track files mentioned }
      if Length(Result.FilesModified) < 20 then
      begin
        SetLength(Result.FilesModified, Length(Result.FilesModified) + 1);
        Result.FilesModified[High(Result.FilesModified)] := Copy(Content, 1, 100);
      end;
    end;
    
    { Extract errors }
    if (Pos('error', LowerContent) > 0) or (Pos('failed', LowerContent) > 0) or
       (Pos('exception', LowerContent) > 0) then
    begin
      if Length(Result.Errors) < 10 then
      begin
        SetLength(Result.Errors, Length(Result.Errors) + 1);
        Result.Errors[High(Result.Errors)] := Copy(Content, 1, 150);
      end;
    end;
    
    { Extract decisions (messages with "should", "will", "going to") }
    if (Pos('should', LowerContent) > 0) or (Pos('will', LowerContent) > 0) or
       (Pos('going to', LowerContent) > 0) or (Pos('decided', LowerContent) > 0) then
    begin
      if Length(Result.Decisions) < 10 then
      begin
        SetLength(Result.Decisions, Length(Result.Decisions) + 1);
        Result.Decisions[High(Result.Decisions)] := Copy(Content, 1, 150);
      end;
    end;
    
    { Extract findings (messages with "found", "discovered", "issue") }
    if (Pos('found', LowerContent) > 0) or (Pos('discovered', LowerContent) > 0) or
       (Pos('issue', LowerContent) > 0) or (Pos('problem', LowerContent) > 0) then
    begin
      if Length(Result.KeyFindings) < 10 then
      begin
        SetLength(Result.KeyFindings, Length(Result.KeyFindings) + 1);
        Result.KeyFindings[High(Result.KeyFindings)] := Copy(Content, 1, 150);
      end;
    end;
  end;
  
  { Generate summary }
  Result.TaskSummary := 'Session ' + GSessionState.SessionID + ': ' +
    IntToStr(GSessionState.ToolCallCount) + ' tool calls, ' +
    IntToStr(GSessionState.EstimatedTokens) + ' estimated tokens';
end;

procedure SaveMemoryToFile(const Info: TExtractedInfo);
var
  F: TextFile;
  i: Integer;
begin
  AssignFile(F, GSessionState.MemoryFilePath);
  Rewrite(F);
  try
    WriteLn(F, '# Session Memory: ', GSessionState.SessionID);
    WriteLn(F, '');
    WriteLn(F, '**Started:** ', FormatDateTime('yyyy-mm-dd hh:nn:ss', GSessionState.StartTime));
    WriteLn(F, '**Tool Calls:** ', GSessionState.ToolCallCount);
    WriteLn(F, '**Estimated Tokens:** ', GSessionState.EstimatedTokens);
    WriteLn(F, '**Extractions:** ', GSessionState.ExtractionCount);
    WriteLn(F, '');
    
    { Task Summary }
    WriteLn(F, '## Summary');
    WriteLn(F, '');
    WriteLn(F, Info.TaskSummary);
    WriteLn(F, '');
    
    { Files Modified }
    if Length(Info.FilesModified) > 0 then
    begin
      WriteLn(F, '## Files Referenced');
      WriteLn(F, '');
      for i := 0 to High(Info.FilesModified) do
        WriteLn(F, '- ', Info.FilesModified[i]);
      WriteLn(F, '');
    end;
    
    { Decisions }
    if Length(Info.Decisions) > 0 then
    begin
      WriteLn(F, '## Decisions Made');
      WriteLn(F, '');
      for i := 0 to High(Info.Decisions) do
        WriteLn(F, '- ', Info.Decisions[i]);
      WriteLn(F, '');
    end;
    
    { Errors }
    if Length(Info.Errors) > 0 then
    begin
      WriteLn(F, '## Errors Encountered');
      WriteLn(F, '');
      for i := 0 to High(Info.Errors) do
        WriteLn(F, '- ', Info.Errors[i]);
      WriteLn(F, '');
    end;
    
    { Key Findings }
    if Length(Info.KeyFindings) > 0 then
    begin
      WriteLn(F, '## Key Findings');
      WriteLn(F, '');
      for i := 0 to High(Info.KeyFindings) do
        WriteLn(F, '- ', Info.KeyFindings[i]);
      WriteLn(F, '');
    end;
    
    WriteLn(F, '---');
    WriteLn(F, '*Last updated: ', FormatDateTime('yyyy-mm-dd hh:nn:ss', Now), '*');
  finally
    CloseFile(F);
  end;
  
  { Update extraction tracking }
  GSessionState.LastExtraction := GSessionState.ToolCallCount;
  Inc(GSessionState.ExtractionCount);
end;

function LoadMemoryFromFile: string;
var
  F: TextFile;
  Line: string;
begin
  Result := '';
  
  if not FileExists(GSessionState.MemoryFilePath) then
    Exit;
    
  AssignFile(F, GSessionState.MemoryFilePath);
  Reset(F);
  try
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      Result := Result + Line + LineEnding;
    end;
  finally
    CloseFile(F);
  end;
end;

function GetMemoryFilePath: string;
begin
  Result := GSessionState.MemoryFilePath;
end;

function GetSessionSummary: string;
var
  Duration: TDateTime;
  Hours, Minutes, Seconds, MSec: Word;
begin
  Duration := Now - GSessionState.StartTime;
  DecodeTime(Duration, Hours, Minutes, Seconds, MSec);
  
  Result := '=== Session Summary ===' + LineEnding;
  Result := Result + 'Session ID: ' + GSessionState.SessionID + LineEnding;
  Result := Result + 'Duration: ';
  
  if Hours > 0 then
    Result := Result + IntToStr(Hours) + 'h ';
  if Minutes > 0 then
    Result := Result + IntToStr(Minutes) + 'm ';
  Result := Result + IntToStr(Seconds) + 's' + LineEnding;
  
  Result := Result + 'Tool Calls: ' + IntToStr(GSessionState.ToolCallCount) + LineEnding;
  Result := Result + 'Estimated Tokens: ' + IntToStr(GSessionState.EstimatedTokens) + LineEnding;
  Result := Result + 'Memory Extractions: ' + IntToStr(GSessionState.ExtractionCount) + LineEnding;
  Result := Result + 'Memory File: ' + GSessionState.MemoryFilePath + LineEnding;
end;

initialization
  FillChar(GSessionState, SizeOf(GSessionState), 0);

end.
