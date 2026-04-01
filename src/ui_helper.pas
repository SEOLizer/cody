{
  UI Helper - Frame and Status Bar for CLI Interface.
  Uses cursor_helper for positioning status bar at bottom of screen.
}
unit ui_helper;

{$mode objfpc}{$H+}

interface

uses SysUtils, cursor_helper;

var
  { Performance metrics }
  TotalTokensUsed: Integer;
  TotalToolCalls: Integer;
  SessionStartTime: LongInt;
  TotalErrors: Integer;

{ Initialize UI }
procedure InitUI;

{ Print frame with content }
procedure PrintFrame(const Title: string; const Lines: array of string);

{ Print simple frame around text }
procedure PrintBoxedText(const Title: string; const Text: string);

{ Print status bar at bottom - using cursor positioning }
procedure PrintStatusBar;

{ Update status bar info }
procedure UpdateMetrics(Tokens, Tools, Errors: Integer);

{ Get elapsed time since start }
function GetElapsedTime: string;

{ Get status bar line }
function GetStatusLine: string;

implementation

{ Get current timestamp for timing }
function GetElapsedTime: string;
var
  Elapsed: LongInt;
  Hours, Minutes, Seconds: Integer;
begin
  if SessionStartTime = 0 then
  begin
    Result := '00:00:00';
    Exit;
  end;

  Elapsed := GetTickCount64 div 1000 - SessionStartTime;
  
  Hours := Elapsed div 3600;
  Minutes := (Elapsed mod 3600) div 60;
  Seconds := Elapsed mod 60;
  
  Result := Format('%.2d:%.2d:%.2d', [Hours, Minutes, Seconds]);
end;

{ Initialize UI }
procedure InitUI;
begin
  { Initialize cursor helper first }
  InitCursorHelper;
  
  SessionStartTime := GetTickCount64 div 1000;
  TotalTokensUsed := 0;
  TotalToolCalls := 0;
  TotalErrors := 0;
end;

{ Get status line }
function GetStatusLine: string;
var
  TimeStr, TokenStr, ToolStr, ErrorStr: string;
begin
  TimeStr := 'Time: ' + GetElapsedTime;
  TokenStr := 'Tokens: ' + IntToStr(TotalTokensUsed);
  ToolStr := 'Tools: ' + IntToStr(TotalToolCalls);
  ErrorStr := 'Errors: ' + IntToStr(TotalErrors);
  
  Result := TimeStr + ' | ' + TokenStr + ' | ' + ToolStr + ' | ' + ErrorStr;
end;

{ Update metrics }
procedure UpdateMetrics(Tokens, Tools, Errors: Integer);
begin
  TotalTokensUsed := Tokens;
  TotalToolCalls := Tools;
  TotalErrors := Errors;
end;

{ Print status bar at bottom using cursor positioning }
procedure PrintStatusBar;
var
  StatusLine: string;
  i, FrameWidth: Integer;
begin
  StatusLine := GetStatusLine;
  
  { Go to bottom row }
  GotoXY(1, ScreenHeight);
  ClearLine;
  
  { Print status bar with colors }
  Write(COLOR_CYAN + STYLE_BOLD);
  Write(' ');
  Write(COLOR_YELLOW + GetElapsedTime);
  Write(' | ');
  Write(COLOR_GREEN + 'Tokens: ' + IntToStr(TotalTokensUsed));
  Write(' | ');
  Write(COLOR_CYAN + 'Tools: ' + IntToStr(TotalToolCalls));
  Write(' | ');
  if TotalErrors > 0 then
    Write(COLOR_RED + 'Errors: ' + IntToStr(TotalErrors))
  else
    Write(COLOR_GREEN + 'Errors: 0');
  Write(' ');
  Write(STYLE_RESET);
  
  { Move to prompt position (one line after status) }
  GotoXY(1, ScreenHeight - 1);
end;

{ Print simple frame around text }
procedure PrintBoxedText(const Title: string; const Text: string);
var
  Lines: array of string;
begin
  SetLength(Lines, 1);
  Lines[0] := Text;
  PrintFrame(Title, Lines);
end;

{ Print frame with content }
procedure PrintFrame(const Title: string; const Lines: array of string);
var
  MaxWidth, i, j, LineCount: Integer;
  TopLine, BottomLine, MiddleLine: string;
begin
  LineCount := Length(Lines);
  
  { Calculate max width }
  MaxWidth := 40;
  if Title <> '' then
  begin
    if Length(Title) + 4 > MaxWidth then
      MaxWidth := Length(Title) + 4;
  end;
  
  for i := 0 to LineCount - 1 do
  begin
    if Length(Lines[i]) > MaxWidth then
      MaxWidth := Length(Lines[i]);
  end;
  if MaxWidth > ScreenWidth - 4 then
    MaxWidth := ScreenWidth - 4;
  
  { Build border lines }
  TopLine := COLOR_BLUE + '+' + STYLE_RESET;
  BottomLine := COLOR_BLUE + '+' + STYLE_RESET;
  MiddleLine := COLOR_BLUE + '+' + STYLE_RESET;
  for i := 1 to MaxWidth do
  begin
    TopLine := TopLine + COLOR_BLUE + '-' + STYLE_RESET;
    BottomLine := BottomLine + COLOR_BLUE + '-' + STYLE_RESET;
    MiddleLine := MiddleLine + COLOR_BLUE + '-' + STYLE_RESET;
  end;
  TopLine := TopLine + COLOR_BLUE + '+' + STYLE_RESET;
  BottomLine := BottomLine + COLOR_BLUE + '+' + STYLE_RESET;
  MiddleLine := MiddleLine + COLOR_BLUE + '+' + STYLE_RESET;
  
  { Print top border }
  WriteLn(TopLine);
  
  { Print title }
  if Title <> '' then
  begin
    Write(COLOR_BLUE + '| ' + STYLE_BOLD + COLOR_CYAN + Title + STYLE_RESET + COLOR_BLUE);
    for i := Length(Title) + 1 to MaxWidth do
      Write(' ');
    WriteLn(' |' + STYLE_RESET);
    WriteLn(MiddleLine);
  end;
  
  { Print lines }
  for i := 0 to LineCount - 1 do
  begin
    Write(COLOR_BLUE + '| ' + STYLE_RESET);
    Write(Lines[i]);
    for j := Length(Lines[i]) + 1 to MaxWidth do
      Write(' ');
    WriteLn(COLOR_BLUE + ' |' + STYLE_RESET);
  end;
  
  { Print bottom border }
  WriteLn(BottomLine);
end;

end.