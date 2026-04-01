{
  Claude.md Integration - Project Memory System.
  Reads CLAUDE.md files from multiple sources and injects into system prompt.
  Based on Claude Code's CLAUDE.md support.
}
unit claude_md;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  { CLAUDE.md source }
  TClaudeMDSource = record
    Path: string;
    Content: string;
    Exists: Boolean;
  end;

  TClaudeMDArray = array of TClaudeMDSource;

{ Load all CLAUDE.md files from various sources }
function LoadClaudeMD(): TClaudeMDArray;

{ Get combined CLAUDE.md content for system prompt }
function GetClaudeMDForSystemPrompt(): string;

{ Check if any CLAUDE.md files exist }
function HasClaudeMD(): Boolean;

{ Get specific source content }
function GetClaudeMDFromSource(Source: Integer): string;

{ Initialize CLAUDE.md system }
procedure InitializeClaudeMD(const WorkingDir: string);

implementation

uses Unix;

var
  GClaudeMDContent: string = '';
  GClaudeMDInitialized: Boolean = False;
  GWorkingDirectory: string = '';

const
  CLAUDE_MD_FILENAME = 'CLAUDE.md';
  GLOBAL_CLAUDE_DIR = '.claude';

{ Read file content }
function ReadFileContent(const FilePath: string): string;
var
  F: Text;
  Line: string;
begin
  Result := '';
  if not FileExists(FilePath) then
    Exit;

  try
    AssignFile(F, FilePath);
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
  except
    Result := '';
  end;
end;

{ Get home directory }
function GetHomeDirectory(): string;
var
  HomeEnv: string;
begin
  HomeEnv := GetEnvironmentVariable('HOME');
  if HomeEnv <> '' then
    Result := HomeEnv
  else
    Result := GetEnvironmentVariable('USERPROFILE');
    
  if Result = '' then
    Result := GetCurrentDir;
end;

{ Load global CLAUDE.md (~/.claude/CLAUDE.md) }
function LoadGlobalClaudeMD(): TClaudeMDSource;
var
  HomeDir: string;
  FilePath: string;
begin
  Result.Path := '';
  Result.Content := '';
  Result.Exists := False;

  HomeDir := GetHomeDirectory();
  if HomeDir = '' then
    Exit;

  FilePath := HomeDir + DirectorySeparator + GLOBAL_CLAUDE_DIR + DirectorySeparator + CLAUDE_MD_FILENAME;
  
  if FileExists(FilePath) then
  begin
    Result.Path := FilePath;
    Result.Content := ReadFileContent(FilePath);
    Result.Exists := True;
  end;
end;

{ Load project root CLAUDE.md }
function LoadProjectClaudeMD(const ProjectDir: string): TClaudeMDSource;
var
  FilePath: string;
begin
  Result.Path := '';
  Result.Content := '';
  Result.Exists := False;

  if ProjectDir = '' then
    Exit;

  FilePath := ProjectDir + DirectorySeparator + CLAUDE_MD_FILENAME;
  
  if FileExists(FilePath) then
  begin
    Result.Path := FilePath;
    Result.Content := ReadFileContent(FilePath);
    Result.Exists := True;
  end;
end;

{ Load CLAUDE.md from subdirectories }
function LoadSubdirClaudeMD(const ProjectDir: string): TClaudeMDArray;
var
  SearchRec: TSearchRec;
  Found: Integer;
  FilePath: string;
  Count: Integer;
begin
  SetLength(Result, 0);
  Count := 0;

  { Search for CLAUDE.md in subdirectories }
  Found := FindFirst(ProjectDir + DirectorySeparator + '*', faDirectory, SearchRec);
  try
    while Found = 0 do
    begin
      if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
      begin
        FilePath := ProjectDir + DirectorySeparator + SearchRec.Name + DirectorySeparator + CLAUDE_MD_FILENAME;
        if FileExists(FilePath) then
        begin
          SetLength(Result, Count + 1);
          Result[Count].Path := FilePath;
          Result[Count].Content := ReadFileContent(FilePath);
          Result[Count].Exists := True;
          Inc(Count);
        end;
      end;
      Found := FindNext(SearchRec);
    end;
  finally
    FindClose(SearchRec);
  end;
end;

{ Load all CLAUDE.md files }
function LoadClaudeMD(): TClaudeMDArray;
var
  GlobalMD: TClaudeMDSource;
  ProjectMD: TClaudeMDSource;
  SubdirMDs: TClaudeMDArray;
  i: Integer;
  TotalCount: Integer;
begin
  SetLength(Result, 0);

  { Load global }
  GlobalMD := LoadGlobalClaudeMD();
  if GlobalMD.Exists then
  begin
    SetLength(Result, 1);
    Result[0] := GlobalMD;
  end;

  { Load project root }
  ProjectMD := LoadProjectClaudeMD(GWorkingDirectory);
  if ProjectMD.Exists then
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := ProjectMD;
  end;

  { Load subdirectories }
  SubdirMDs := LoadSubdirClaudeMD(GWorkingDirectory);
  for i := 0 to Length(SubdirMDs) - 1 do
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := SubdirMDs[i];
  end;

  { Combine all content }
  GClaudeMDContent := '';
  for i := 0 to Length(Result) - 1 do
  begin
    if Result[i].Content <> '' then
    begin
      GClaudeMDContent := GClaudeMDContent + '## From: ' + Result[i].Path + LineEnding;
      GClaudeMDContent := GClaudeMDContent + Result[i].Content + LineEnding;
    end;
  end;
  
  GClaudeMDInitialized := True;
end;

{ Get combined CLAUDE.md content for system prompt }
function GetClaudeMDForSystemPrompt(): string;
begin
  Result := '';
  
  if not GClaudeMDInitialized then
    InitializeClaudeMD(GWorkingDirectory);
    
  Result := GClaudeMDContent;
end;

{ Check if any CLAUDE.md files exist }
function HasClaudeMD(): Boolean;
var
  Sources: TClaudeMDArray;
  i: Integer;
begin
  Result := False;
  
  if not GClaudeMDInitialized then
    InitializeClaudeMD(GWorkingDirectory);
    
  Result := (GClaudeMDContent <> '');
end;

{ Get specific source content }
function GetClaudeMDFromSource(Source: Integer): string;
var
  Sources: TClaudeMDArray;
begin
  Result := '';
  
  if not GClaudeMDInitialized then
    InitializeClaudeMD(GWorkingDirectory);
    
  { Not implemented - would need to store sources }
  Result := GClaudeMDContent;
end;

{ Initialize CLAUDE.md system }
procedure InitializeClaudeMD(const WorkingDir: string);
begin
  GWorkingDirectory := WorkingDir;
  if GWorkingDirectory = '' then
    GWorkingDirectory := GetCurrentDir;
    
  { Add trailing slash if needed }
  if (Length(GWorkingDirectory) > 0) and (GWorkingDirectory[Length(GWorkingDirectory)] <> DirectorySeparator) then
    GWorkingDirectory := GWorkingDirectory + DirectorySeparator;
    
  LoadClaudeMD();
end;

end.