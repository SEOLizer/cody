{
  Configuration Module - Persists agent settings to ~/.agent/config.json
  - Saves API URL, model, temperature, max tokens
  - Loads config on startup
  - Provides /config command for viewing/editing
}
unit config;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  { Agent configuration }
  TAgentConfig = record
    BaseURL: string;
    Model: string;
    APIKey: string;
    Temperature: Double;
    MaxTokens: Integer;
    WorkingDirectory: string;
    PermissionMode: string;  { auto, ask, strict }
    MaxRetries: Integer;
    CacheEnabled: Boolean;
    ThinkingMode: Boolean;
  end;

{ Get config file path }
function GetConfigFilePath: string;

{ Load configuration from file }
function LoadConfig: TAgentConfig;

{ Save configuration to file }
procedure SaveConfig(const Config: TAgentConfig);

{ Check if config file exists }
function ConfigExists: Boolean;

{ Get default configuration }
function GetDefaultConfig: TAgentConfig;

{ Merge config with command line args }
function MergeConfig(const FileConfig: TAgentConfig; const BaseURL, Model, APIKey: string;
  Temperature: Double; MaxTokens: Integer): TAgentConfig;

{ Format config as display string }
function FormatConfig(const Config: TAgentConfig): string;

implementation

function GetConfigFilePath: string;
var
  HomeDir: string;
begin
  HomeDir := GetEnvironmentVariable('HOME');
  if HomeDir = '' then
    HomeDir := GetEnvironmentVariable('USERPROFILE');
  if HomeDir = '' then
    HomeDir := GetCurrentDir;
    
  Result := HomeDir + DirectorySeparator + '.agent' + DirectorySeparator + 'config.json';
end;

function GetDefaultConfig: TAgentConfig;
begin
  Result.BaseURL := 'http://localhost:11434';
  Result.Model := 'llama3';
  Result.APIKey := '';
  Result.Temperature := 0.7;
  Result.MaxTokens := 2048;
  Result.WorkingDirectory := GetCurrentDir;
  Result.PermissionMode := 'auto';
  Result.MaxRetries := 3;
  Result.CacheEnabled := True;
  Result.ThinkingMode := True;
end;

{ Simple JSON extraction }
function ExtractJSONString(const JSON, Key: string): string;
var
  KeyPos, ValueStart, ValueEnd: Integer;
  InString: Boolean;
begin
  Result := '';
  KeyPos := Pos('"' + Key + '"', JSON);
  if KeyPos = 0 then Exit;
  
  ValueStart := KeyPos + Length(Key) + 2;
  while ValueStart <= Length(JSON) do
  begin
    if JSON[ValueStart] = ':' then
    begin
      Inc(ValueStart);
      while (ValueStart <= Length(JSON)) and (JSON[ValueStart] in [' ', #9]) do
        Inc(ValueStart);
      Break;
    end;
    Inc(ValueStart);
  end;
  
  if ValueStart > Length(JSON) then Exit;
  
  if JSON[ValueStart] = '"' then
  begin
    Inc(ValueStart);
    ValueEnd := ValueStart;
    InString := True;
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
    while (ValueEnd <= Length(JSON)) and not (JSON[ValueEnd] in [',', '}', ']']) do
      Inc(ValueEnd);
    Result := Trim(Copy(JSON, ValueStart, ValueEnd - ValueStart));
  end;
end;

function ExtractJSONNumber(const JSON, Key: string): Double;
var
  Str: string;
begin
  Str := ExtractJSONString(JSON, Key);
  if Str = '' then
    Result := 0
  else
    Result := StrToFloatDef(Str, 0);
end;

function ExtractJSONBool(const JSON, Key: string): Boolean;
var
  Str: string;
begin
  Str := LowerCase(ExtractJSONString(JSON, Key));
  Result := (Str = 'true');
end;

function LoadConfig: TAgentConfig;
var
  ConfigPath: string;
  F: TextFile;
  JSON: string;
  Line: string;
begin
  Result := GetDefaultConfig;
  ConfigPath := GetConfigFilePath;
  
  if not FileExists(ConfigPath) then
    Exit;
    
  JSON := '';
  AssignFile(F, ConfigPath);
  Reset(F);
  try
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      JSON := JSON + Trim(Line);
    end;
  finally
    CloseFile(F);
  end;
  
  { Parse JSON }
  if Pos('"base_url"', JSON) > 0 then
    Result.BaseURL := ExtractJSONString(JSON, 'base_url');
  if Pos('"model"', JSON) > 0 then
    Result.Model := ExtractJSONString(JSON, 'model');
  if Pos('"api_key"', JSON) > 0 then
    Result.APIKey := ExtractJSONString(JSON, 'api_key');
  if Pos('"temperature"', JSON) > 0 then
    Result.Temperature := ExtractJSONNumber(JSON, 'temperature');
  if Pos('"max_tokens"', JSON) > 0 then
    Result.MaxTokens := Round(ExtractJSONNumber(JSON, 'max_tokens'));
  if Pos('"working_directory"', JSON) > 0 then
    Result.WorkingDirectory := ExtractJSONString(JSON, 'working_directory');
  if Pos('"permission_mode"', JSON) > 0 then
    Result.PermissionMode := ExtractJSONString(JSON, 'permission_mode');
  if Pos('"max_retries"', JSON) > 0 then
    Result.MaxRetries := Round(ExtractJSONNumber(JSON, 'max_retries'));
  if Pos('"cache_enabled"', JSON) > 0 then
    Result.CacheEnabled := ExtractJSONBool(JSON, 'cache_enabled');
  if Pos('"thinking_mode"', JSON) > 0 then
    Result.ThinkingMode := ExtractJSONBool(JSON, 'thinking_mode');
end;

procedure SaveConfig(const Config: TAgentConfig);
var
  ConfigPath: string;
  F: TextFile;
  DirPath: string;
begin
  ConfigPath := GetConfigFilePath;
  DirPath := ExtractFilePath(ConfigPath);
  
  { Create directory if not exists }
  if not DirectoryExists(DirPath) then
    CreateDir(DirPath);
    
  AssignFile(F, ConfigPath);
  Rewrite(F);
  try
    WriteLn(F, '{');
    WriteLn(F, '  "base_url": "', Config.BaseURL, '",');
    WriteLn(F, '  "model": "', Config.Model, '",');
    WriteLn(F, '  "api_key": "', Config.APIKey, '",');
    WriteLn(F, '  "temperature": ', Config.Temperature:0:1, ',');
    WriteLn(F, '  "max_tokens": ', Config.MaxTokens, ',');
    WriteLn(F, '  "working_directory": "', Config.WorkingDirectory, '",');
    WriteLn(F, '  "permission_mode": "', Config.PermissionMode, '",');
    WriteLn(F, '  "max_retries": ', Config.MaxRetries, ',');
    if Config.CacheEnabled then
      WriteLn(F, '  "cache_enabled": true,')
    else
      WriteLn(F, '  "cache_enabled": false,');
    if Config.ThinkingMode then
      WriteLn(F, '  "thinking_mode": true')
    else
      WriteLn(F, '  "thinking_mode": false');
    WriteLn(F, '}');
  finally
    CloseFile(F);
  end;
end;

function ConfigExists: Boolean;
begin
  Result := FileExists(GetConfigFilePath);
end;

function MergeConfig(const FileConfig: TAgentConfig; const BaseURL, Model, APIKey: string;
  Temperature: Double; MaxTokens: Integer): TAgentConfig;
begin
  Result := FileConfig;
  
  { Command line args override config file }
  if BaseURL <> '' then
    Result.BaseURL := BaseURL;
  if Model <> '' then
    Result.Model := Model;
  if APIKey <> '' then
    Result.APIKey := APIKey;
  if Temperature > 0 then
    Result.Temperature := Temperature;
  if MaxTokens > 0 then
    Result.MaxTokens := MaxTokens;
end;

function FormatConfig(const Config: TAgentConfig): string;
begin
  Result := '=== Agent Configuration ===' + LineEnding;
  Result := Result + 'Config File: ' + GetConfigFilePath + LineEnding;
  Result := Result + LineEnding;
  Result := Result + 'Base URL: ' + Config.BaseURL + LineEnding;
  Result := Result + 'Model: ' + Config.Model + LineEnding;
  if Config.APIKey <> '' then
    Result := Result + 'API Key: [configured]' + LineEnding
  else
    Result := Result + 'API Key: [not set]' + LineEnding;
  Result := Result + 'Temperature: ' + FloatToStr(Config.Temperature) + LineEnding;
  Result := Result + 'Max Tokens: ' + IntToStr(Config.MaxTokens) + LineEnding;
  Result := Result + 'Working Directory: ' + Config.WorkingDirectory + LineEnding;
  Result := Result + 'Permission Mode: ' + Config.PermissionMode + LineEnding;
  Result := Result + 'Max Retries: ' + IntToStr(Config.MaxRetries) + LineEnding;
  if Config.CacheEnabled then
    Result := Result + 'Cache: enabled' + LineEnding
  else
    Result := Result + 'Cache: disabled' + LineEnding;
  if Config.ThinkingMode then
    Result := Result + 'Thinking Mode: enabled' + LineEnding
  else
    Result := Result + 'Thinking Mode: disabled' + LineEnding;
end;

end.
