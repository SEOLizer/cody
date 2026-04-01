{
  Cursor Helper - ANSI Escape Codes for cursor control and screen positioning.
  Allows positioning output at specific screen locations.
}
unit cursor_helper;

{$mode objfpc}{$H+}

interface

uses SysUtils, Dos;

{ ANSI Escape Code Variables }
var
  ESC: string;
  CSI: string;
  
  { Cursor Movement }
  CURSOR_HOME: string;
  CURSOR_SAVE: string;
  CURSOR_RESTORE: string;
  CURSOR_UP: string;
  CURSOR_DOWN: string;
  CURSOR_RIGHT: string;
  CURSOR_LEFT: string;
  
  { Screen Operations }
  SCREEN_CLEAR: string;
  SCREEN_CLEAR_LINE: string;
  LINE_CLEAR: string;
  
  { Style Codes }
  STYLE_RESET: string;
  STYLE_BOLD: string;
  STYLE_DIM: string;
  STYLE_ITALIC: string;
  STYLE_UNDERLINE: string;
  
  { Color Codes }
  COLOR_BLACK: string;
  COLOR_RED: string;
  COLOR_GREEN: string;
  COLOR_YELLOW: string;
  COLOR_BLUE: string;
  COLOR_MAGENTA: string;
  COLOR_CYAN: string;
  COLOR_WHITE: string;
  COLOR_DEFAULT: string;
  
  { Background Colors }
  BG_BLACK: string;
  BG_RED: string;
  BG_GREEN: string;
  BG_YELLOW: string;
  BG_BLUE: string;
  BG_MAGENTA: string;
  BG_CYAN: string;
  BG_WHITE: string;

var
  ScreenWidth: Integer;
  ScreenHeight: Integer;

{ Initialize - setup ANSI codes }
procedure InitCursorHelper;

{ Switch to alternate screen buffer }
procedure SwitchToAlternateScreen;

{ Switch back to main screen buffer }
procedure SwitchToMainScreen;

{ Check if terminal supports alternate buffer }
function HasAlternateBufferSupport: Boolean;

{ Move cursor to specific position (1-based) }
procedure GotoXY(X, Y: Integer);

{ Get current cursor position - returns true if successful }
function GetXY(var X, Y: Integer): Boolean;

{ Save current cursor position }
procedure SaveCursor;

{ Restore saved cursor position }
procedure RestoreCursor;

{ Move cursor up N lines }
procedure CursorUp(Lines: Integer);

{ Move cursor down N lines }
procedure CursorDown(Lines: Integer);

{ Move cursor forward N columns }
procedure CursorForward(Cols: Integer);

{ Move cursor back N columns }
procedure CursorBack(Cols: Integer);

{ Clear entire screen }
procedure ClearScreen;

{ Clear current line }
procedure ClearLine;

{ Clear from cursor to end of line }
procedure ClearLineToEnd;

{ Erase from cursor to end of screen }
procedure EraseDown;

{ Scroll screen up N lines }
procedure ScrollUp(Lines: Integer);

{ Scroll screen down N lines }
procedure ScrollDown(Lines: Integer);

{ Delete N lines at cursor position }
procedure DeleteLines(N: Integer);

{ Insert N blank lines at cursor position }
procedure InsertLines(N: Integer);

{ Get screen dimensions }
procedure GetScreenSize(var Width, Height: Integer);

{ Print at specific position }
procedure PrintAt(X, Y: Integer; const Text: string);

{ Print centered at specific row }
procedure PrintCentered(Y: Integer; const Text: string);

{ Print at bottom row }
procedure PrintAtBottom(const Text: string);

{ Get terminal dimensions - called at startup }
function DetectTerminalSize: Boolean;

implementation

{ Initialize cursor helper }
procedure InitCursorHelper;
begin
  { Setup ANSI escape code strings }
  ESC := #27;
  CSI := #27 + '[';
  
  CURSOR_HOME := CSI + 'H';
  CURSOR_SAVE := CSI + 's';
  CURSOR_RESTORE := CSI + 'u';
  CURSOR_UP := CSI + 'A';
  CURSOR_DOWN := CSI + 'B';
  CURSOR_RIGHT := CSI + 'C';
  CURSOR_LEFT := CSI + 'D';
  
  SCREEN_CLEAR := CSI + '2J';
  SCREEN_CLEAR_LINE := CSI + '2K';
  LINE_CLEAR := CSI + 'K';
  
  STYLE_RESET := #27 + '[0m';
  STYLE_BOLD := #27 + '[1m';
  STYLE_DIM := #27 + '[2m';
  STYLE_ITALIC := #27 + '[3m';
  STYLE_UNDERLINE := #27 + '[4m';
  
  COLOR_BLACK := #27 + '[30m';
  COLOR_RED := #27 + '[31m';
  COLOR_GREEN := #27 + '[32m';
  COLOR_YELLOW := #27 + '[33m';
  COLOR_BLUE := #27 + '[34m';
  COLOR_MAGENTA := #27 + '[35m';
  COLOR_CYAN := #27 + '[36m';
  COLOR_WHITE := #27 + '[37m';
  COLOR_DEFAULT := #27 + '[39m';
  
  BG_BLACK := #27 + '[40m';
  BG_RED := #27 + '[41m';
  BG_GREEN := #27 + '[42m';
  BG_YELLOW := #27 + '[43m';
  BG_BLUE := #27 + '[44m';
  BG_MAGENTA := #27 + '[45m';
  BG_CYAN := #27 + '[46m';
  BG_WHITE := #27 + '[47m';
  
  DetectTerminalSize;
end;

{ Move cursor to specific position (1-based) }
procedure GotoXY(X, Y: Integer);
begin
  if X < 1 then X := 1;
  if Y < 1 then Y := 1;
  Write(CSI + IntToStr(Y) + ';' + IntToStr(X) + 'H');
end;

{ Get current cursor position }
function GetXY(var X, Y: Integer): Boolean;
begin
  X := 1;
  Y := 1;
  Result := False;
end;

{ Save current cursor position }
procedure SaveCursor;
begin
  Write(CURSOR_SAVE);
end;

{ Restore saved cursor position }
procedure RestoreCursor;
begin
  Write(CURSOR_RESTORE);
end;

{ Move cursor up N lines }
procedure CursorUp(Lines: Integer);
begin
  if Lines > 0 then
    Write(CSI + IntToStr(Lines) + 'A');
end;

{ Move cursor down N lines }
procedure CursorDown(Lines: Integer);
begin
  if Lines > 0 then
    Write(CSI + IntToStr(Lines) + 'B');
end;

{ Move cursor forward N columns }
procedure CursorForward(Cols: Integer);
begin
  if Cols > 0 then
    Write(CSI + IntToStr(Cols) + 'C');
end;

{ Move cursor back N columns }
procedure CursorBack(Cols: Integer);
begin
  if Cols > 0 then
    Write(CSI + IntToStr(Cols) + 'D');
end;

{ Clear entire screen }
procedure ClearScreen;
begin
  Write(SCREEN_CLEAR);
  GotoXY(1, 1);
end;

{ Switch to alternate screen buffer (hides previous content) }
procedure SwitchToAlternateScreen;
begin
  { ESC [ ? 1 0 4 9 h - Enter alternate screen }
  Write(CSI + '?1049h');
end;

{ Switch back to main screen buffer (restores previous content) }
procedure SwitchToMainScreen;
begin
  { ESC [ ? 1 0 4 9 l - Leave alternate screen }
  Write(CSI + '?1049l');
end;

{ Check if terminal supports alternate buffer }
function HasAlternateBufferSupport: Boolean;
begin
  { Most modern terminals support this }
  Result := True;
end;

{ Clear current line }
procedure ClearLine;
begin
  Write(CSI + '2K');
end;

{ Clear from cursor to end of line }
procedure ClearLineToEnd;
begin
  Write(LINE_CLEAR);
end;

{ Erase from cursor to end of screen }
procedure EraseDown;
begin
  Write(CSI + 'J');
end;

{ Scroll screen up N lines }
procedure ScrollUp(Lines: Integer);
begin
  if Lines > 0 then
    Write(CSI + IntToStr(Lines) + 'S');
end;

{ Scroll screen down N lines }
procedure ScrollDown(Lines: Integer);
begin
  if Lines > 0 then
    Write(CSI + IntToStr(Lines) + 'T');
end;

{ Delete N lines at cursor position }
procedure DeleteLines(N: Integer);
begin
  if N > 0 then
    Write(CSI + IntToStr(N) + 'M');
end;

{ Insert N blank lines at cursor position }
procedure InsertLines(N: Integer);
begin
  if N > 0 then
    Write(CSI + IntToStr(N) + 'L');
end;

{ Get screen dimensions }
procedure GetScreenSize(var Width, Height: Integer);
begin
  Width := ScreenWidth;
  Height := ScreenHeight;
end;

{ Detect terminal size }
function DetectTerminalSize: Boolean;
var
  Rows, Cols: Integer;
  EnvLines, EnvCols: string;
begin
  Cols := 80;
  Rows := 24;
  
  EnvLines := GetEnv('LINES');
  EnvCols := GetEnv('COLUMNS');
  
  if EnvLines <> '' then
  begin
    try
      Rows := StrToInt(EnvLines);
    except
    end;
  end;
  
  if EnvCols <> '' then
  begin
    try
      Cols := StrToInt(EnvCols);
    except
    end;
  end;
  
  ScreenWidth := Cols;
  ScreenHeight := Rows;
  Result := True;
end;

{ Print at specific position }
procedure PrintAt(X, Y: Integer; const Text: string);
begin
  SaveCursor;
  GotoXY(X, Y);
  Write(Text);
  RestoreCursor;
end;

{ Print centered at specific row }
procedure PrintCentered(Y: Integer; const Text: string);
var
  X: Integer;
begin
  if Length(Text) >= ScreenWidth then
    X := 1
  else
    X := (ScreenWidth - Length(Text)) div 2;
  
  SaveCursor;
  GotoXY(X, Y);
  Write(Text);
  RestoreCursor;
end;

{ Print at bottom row }
procedure PrintAtBottom(const Text: string);
begin
  GotoXY(1, ScreenHeight);
  ClearLine;
  Write(Text);
end;

end.