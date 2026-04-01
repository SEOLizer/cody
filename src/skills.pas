{
  Skills Unit - Custom slash commands support.
  Inspired by Claude Code Skills feature.
  
  Skills are custom commands that execute predefined prompts.
  Stored in ~/.claude/skills.json
  
  Uses simple manual JSON parsing without fpjson dependency.
}
unit skills;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Dos;

type
  { Single skill definition }
  TSkill = record
    Name: string;
    Description: string;
    Prompt: string;
  end;
  TSkillArray = array of TSkill;

  { Skills manager }
  TSkillsManager = class
  private
    FSkills: TSkillArray;
    FSkillsFilePath: string;
    procedure LoadFromFile;
    procedure SaveToFile;
    function GetSkillsFilePath: string;
    { Simple JSON helpers }
    function ExtractString(const JSON, Key: string): string;
    function FindArrayStart(const JSON: string): Integer;
    function FindObjectEnd(const JSON: string; Start: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    
    { Load skills from default location }
    procedure LoadSkills;
    
    { Get all skills }
    function GetSkills: TSkillArray;
    
    { Find skill by name (without slash) }
    function FindSkill(const SkillName: string): string;
    
    { Add a new skill }
    procedure AddSkill(const Name, Description, Prompt: string);
    
    { Remove a skill }
    procedure RemoveSkill(const Name: string);
    
    { List all skill names - returns as dynamic array of strings }
    function ListSkills: TStringArray;
    
    { Check if skill exists }
    function HasSkill(const SkillName: string): Boolean;
  end;

implementation

{ Returns the default skills file path }
function TSkillsManager.GetSkillsFilePath: string;
var
  HomeDir: string;
begin
  Result := GetUserDir;
  if Result = '' then
    Result := GetEnv('HOME');
  if Result <> '' then
    Result := Result + '/.claude/skills.json'
  else
    Result := '/root/.claude/skills.json';
end;

{ Find position where array starts after "skills": }
function TSkillsManager.FindArrayStart(const JSON: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  i := 1;
  while i <= Length(JSON) - 8 do
  begin
    if Copy(JSON, i, 8) = '"skills"' then
    begin
      { Find the [ after the : }
      while (i <= Length(JSON)) and (JSON[i] <> '[') do
        Inc(i);
      if (i <= Length(JSON)) and (JSON[i] = '[') then
      begin
        Result := i;
        Exit;
      end;
    end;
    Inc(i);
  end;
end;

{ Find matching closing brace }
function TSkillsManager.FindObjectEnd(const JSON: string; Start: Integer): Integer;
var
  Depth: Integer;
  i: Integer;
  InString: Boolean;
begin
  Result := -1;
  Depth := 1;
  InString := False;
  
  i := Start + 1;
  while i <= Length(JSON) do
  begin
    if InString then
    begin
      if JSON[i] = '"' then
        InString := False;
    end
    else
    begin
      case JSON[i] of
        '"': InString := True;
        '{': Inc(Depth);
        '}': begin
          Dec(Depth);
          if Depth = 0 then
          begin
            Result := i;
            Exit;
          end;
        end;
      end;
    end;
    Inc(i);
  end;
end;

{ Extract string value for a key from JSON object }
function TSkillsManager.ExtractString(const JSON, Key: string): string;
var
  KeyStr: string;
  i, ObjStart, ObjEnd: Integer;
begin
  Result := '';
  KeyStr := '"' + Key + '":';
  
  { Find key in JSON }
  i := Pos(KeyStr, JSON);
  if i = 0 then
    Exit;
    
  { Move past the key }
  i := i + Length(KeyStr);
  
  { Skip whitespace }
  while (i <= Length(JSON)) and (JSON[i] in [' ', #9, #10, #13]) do
    Inc(i);
    
  if JSON[i] <> '"' then
    Exit;
    
  { Extract string value }
  Inc(i);
  while i <= Length(JSON) do
  begin
    if JSON[i] = '"' then
    begin
      if (i < Length(JSON)) and (JSON[i + 1] = '"') then
      begin
        { Escaped quote }
        Result := Result + '"';
        Inc(i, 2);
      end
      else
        Break;
    end
    else
    begin
      Result := Result + JSON[i];
      Inc(i);
    end;
  end;
end;

constructor TSkillsManager.Create;
begin
  inherited Create;
  FSkillsFilePath := GetSkillsFilePath;
  SetLength(FSkills, 0);
  LoadSkills;
end;

destructor TSkillsManager.Destroy;
begin
  SetLength(FSkills, 0);
  inherited Destroy;
end;

{ Load skills from JSON file using manual parsing }
procedure TSkillsManager.LoadFromFile;
var
  F: TextFile;
  Line: string;
  JSONStr: string;
  i, ArrayStart, ObjStart, ObjEnd: Integer;
  SkillName, SkillDesc, SkillPrompt: string;
begin
  SetLength(FSkills, 0);
  
  if not FileExists(FSkillsFilePath) then
    Exit;
    
  try
    { Read entire file }
    JSONStr := '';
    AssignFile(F, FSkillsFilePath);
    Reset(F);
    try
      while not EOF(F) do
      begin
        ReadLn(F, Line);
        JSONStr := JSONStr + Line;
      end;
    finally
      CloseFile(F);
    end;
    
    if JSONStr = '' then
      Exit;
      
    { Find array start }
    ArrayStart := FindArrayStart(JSONStr);
    if ArrayStart = -1 then
      Exit;
      
    { Parse each skill object }
    i := ArrayStart + 1;
    while i < Length(JSONStr) do
    begin
      { Skip whitespace }
      while (i <= Length(JSONStr)) and (JSONStr[i] in [' ', #9, #10, #13]) do
        Inc(i);
        
      if JSONStr[i] = '{' then
      begin
        ObjStart := i;
        ObjEnd := FindObjectEnd(JSONStr, ObjStart);
        
        if ObjEnd > ObjStart then
        begin
          { Extract fields }
          SkillName := ExtractString(Copy(JSONStr, ObjStart, ObjEnd - ObjStart + 1), 'name');
          SkillDesc := ExtractString(Copy(JSONStr, ObjStart, ObjEnd - ObjStart + 1), 'description');
          SkillPrompt := ExtractString(Copy(JSONStr, ObjStart, ObjEnd - ObjStart + 1), 'prompt');
          
          if SkillName <> '' then
          begin
            SetLength(FSkills, Length(FSkills) + 1);
            FSkills[Length(FSkills) - 1].Name := SkillName;
            FSkills[Length(FSkills) - 1].Description := SkillDesc;
            FSkills[Length(FSkills) - 1].Prompt := SkillPrompt;
          end;
          
          i := ObjEnd + 1;
        end
        else
          Break;
      end
      else if JSONStr[i] = ']' then
        Break
      else
        Inc(i);
    end;
  except
    on E: Exception do
    begin
      WriteLn('Warning: Could not load skills: ', E.Message);
    end;
  end;
end;

{ Save skills to JSON file }
procedure TSkillsManager.SaveToFile;
var
  F: TextFile;
  i: Integer;
begin
  { Ensure directory exists }
  if not DirectoryExists(ExtractFilePath(FSkillsFilePath)) then
    CreateDir(ExtractFilePath(FSkillsFilePath));
    
  try
    AssignFile(F, FSkillsFilePath);
    Rewrite(F);
    try
      WriteLn(F, '{');
      WriteLn(F, '  "skills": [');
      
      for i := 0 to Length(FSkills) - 1 do
      begin
        WriteLn(F, '    {');
        WriteLn(F, '      "name": "' + FSkills[i].Name + '",');
        WriteLn(F, '      "description": "' + FSkills[i].Description + '",');
        Write(F, '      "prompt": "');
        
        { Write prompt with escaped quotes }
        Write(F, StringReplace(FSkills[i].Prompt, '"', '\"', [rfReplaceAll]));
        
        WriteLn(F, '"');
        
        if i < Length(FSkills) - 1 then
          WriteLn(F, '    },')
        else
          WriteLn(F, '    }');
      end;
      
      WriteLn(F, '  ]');
      WriteLn(F, '}');
    finally
      CloseFile(F);
    end;
  except
    on E: Exception do
    begin
      WriteLn('Error: Could not save skills: ', E.Message);
    end;
  end;
end;

{ Load skills - public interface }
procedure TSkillsManager.LoadSkills;
begin
  LoadFromFile;
end;

{ Get all skills }
function TSkillsManager.GetSkills: TSkillArray;
begin
  Result := FSkills;
end;

{ Find skill by name - returns prompt if found, empty string otherwise }
function TSkillsManager.FindSkill(const SkillName: string): string;
var
  i: Integer;
  LowerName: string;
begin
  Result := '';
  LowerName := LowerCase(SkillName);
  
  for i := 0 to Length(FSkills) - 1 do
  begin
    if LowerCase(FSkills[i].Name) = LowerName then
    begin
      Result := FSkills[i].Prompt;
      Exit;
    end;
  end;
end;

{ Add a new skill }
procedure TSkillsManager.AddSkill(const Name, Description, Prompt: string);
var
  Len: Integer;
begin
  { Check if skill already exists - remove to update }
  if HasSkill(Name) then
    RemoveSkill(Name);
  
  Len := Length(FSkills);
  SetLength(FSkills, Len + 1);
  FSkills[Len].Name := Name;
  FSkills[Len].Description := Description;
  FSkills[Len].Prompt := Prompt;
  
  SaveToFile;
end;

{ Remove a skill }
procedure TSkillsManager.RemoveSkill(const Name: string);
var
  i, j: Integer;
  Found: Boolean;
  NewSkills: TSkillArray;
begin
  Found := False;
  SetLength(NewSkills, 0);
  
  for i := 0 to Length(FSkills) - 1 do
  begin
    if LowerCase(FSkills[i].Name) = LowerCase(Name) then
    begin
      Found := True;
      Continue;
    end;
    
    j := Length(NewSkills);
    SetLength(NewSkills, j + 1);
    NewSkills[j] := FSkills[i];
  end;
  
  if Found then
  begin
    FSkills := NewSkills;
    SaveToFile;
  end;
end;

{ List all skills - returns as string array }
function TSkillsManager.ListSkills: TStringArray;
var
  i, Len: Integer;
  Temp: TStringArray;
begin
  SetLength(Temp, 0);
  
  if Length(FSkills) = 0 then
  begin
    SetLength(Temp, 2);
    Temp[0] := 'No skills defined.';
    Temp[1] := 'Use /skills add <name> <description> <prompt> to create one.';
    Result := Temp;
    Exit;
  end;
  
  SetLength(Temp, Length(FSkills) + 4);
  Temp[0] := 'Available skills:';
  for i := 0 to Length(FSkills) - 1 do
  begin
    Temp[i + 1] := '  /' + FSkills[i].Name + ' - ' + FSkills[i].Description;
  end;
  
  Len := Length(FSkills);
  Temp[Len + 1] := '';
  Temp[Len + 2] := 'Use /skills add <name> <description> <prompt> to create a new skill.';
  Temp[Len + 3] := 'Use /skills remove <name> to delete a skill.';
  
  Result := Temp;
end;

{ Check if skill exists }
function TSkillsManager.HasSkill(const SkillName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Length(FSkills) - 1 do
  begin
    if LowerCase(FSkills[i].Name) = LowerCase(SkillName) then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

end.
