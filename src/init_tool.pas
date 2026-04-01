{
  Init Tool - Creates or updates PROJECT.md with project documentation.
  This is the main documentation file for the coding agent.
}
unit init_tool;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

function InitToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;

implementation

uses tool_executor;

function ExtractJSONString(const JSON, Key: string): string;
var KeyPos, ValueStart, ValueEnd: Integer; InString: Boolean;
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

function InitToolExecute(const ToolName: string; const InputJSON: string): TToolExecutionResult;
var
  WorkDir, FilePath, Content: string;
  F: TextFile;
  WorkInput: string;
begin
  Result.Success := False;
  Result.Output := '';
  Result.ErrorMessage := '';
  
  { Get working directory from tool_executor }
  WorkDir := GWorkingDirectory;
  if WorkDir = '' then
    WorkDir := GetCurrentDir;
  
  { Ensure trailing slash }
  if (Length(WorkDir) > 0) and (WorkDir[Length(WorkDir)] <> '/') then
    WorkDir := WorkDir + '/';
  
  { Unescape JSON input }
  WorkInput := InputJSON;
  WorkInput := StringReplace(WorkInput, '\"', '"', [rfReplaceAll]);
  WorkInput := StringReplace(WorkInput, '\\', '\', [rfReplaceAll]);
  
  { Extract optional file_path parameter }
  FilePath := ExtractJSONString(WorkInput, 'file_path');
  if FilePath = '' then
    FilePath := 'PROJECT.md';
  
  { Build full path }
  if (Length(FilePath) > 0) and (FilePath[1] = '/') then
    FilePath := FilePath
  else
    FilePath := WorkDir + FilePath;
  
  { Extract content }
  Content := ExtractJSONString(WorkInput, 'content');
  
  { If no content provided, generate a template }
  if Content = '' then
  begin
    Content := 
      '# Project Name' + LineEnding + LineEnding +
      '## Overview' + LineEnding +
      'Add a brief description of your project here.' + LineEnding + LineEnding +
      '## Technology Stack' + LineEnding +
      '- Language: ' + LineEnding +
      '- Framework: ' + LineEnding +
      '- Dependencies: ' + LineEnding + LineEnding +
      '## Project Structure' + LineEnding +
      'Describe the directory structure of your project.' + LineEnding + LineEnding +
      '## Getting Started' + LineEnding +
      '### Prerequisites' + LineEnding +
      'List any prerequisites needed to run the project.' + LineEnding + LineEnding +
      '### Installation' + LineEnding +
      'Step-by-step installation instructions.' + LineEnding + LineEnding +
      '### Build & Run' + LineEnding +
      'Commands to build and run the project.' + LineEnding + LineEnding +
      '## Available Commands' + LineEnding +
      'List of available npm scripts or build commands.' + LineEnding + LineEnding +
      '## Coding Standards' + LineEnding +
      'Describe coding conventions, linting rules, and best practices.' + LineEnding + LineEnding +
      '## Testing' + LineEnding +
      'How to run tests and coverage reports.' + LineEnding + LineEnding +
      '## Deployment' + LineEnding +
      'Instructions for deploying the project.' + LineEnding + LineEnding +
      '## Notes' + LineEnding +
      'Additional notes, tips, or known issues.' + LineEnding;
  end;
  
  { Write to file }
  try
    AssignFile(F, FilePath);
    Rewrite(F);
    try
      Write(F, Content);
      Result.Success := True;
      Result.Output := 'PROJECT.md created/updated: ' + FilePath;
    finally
      CloseFile(F);
    end;
  except
    on E: Exception do
      Result.ErrorMessage := 'Error writing file: ' + E.Message;
  end;
end;

end.
