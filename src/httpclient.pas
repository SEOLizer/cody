{
  HTTP client wrapper for LLM API requests.
  Uses curl via shell for maximum compatibility.
}
unit httpclient;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Unix;

type
  EHTTPError = class(Exception)
  public
    StatusCode: Integer;
    constructor Create(const AMsg: string; AStatusCode: Integer);
  end;

  THTTPClient = class
  private
    FBaseURL: string;
    FAPIKey: string;
    FTimeout: Integer;
  public
    constructor Create(const ABaseURL, AAPIKey: string);
    destructor Destroy; override;
    function PostJSON(const APath: string; AJSON: string): string;
    property Timeout: Integer read FTimeout write FTimeout;
  end;

implementation

constructor EHTTPError.Create(const AMsg: string; AStatusCode: Integer);
begin
  inherited Create(AMsg);
  StatusCode := AStatusCode;
end;

constructor THTTPClient.Create(const ABaseURL, AAPIKey: string);
begin
  inherited Create;
  FBaseURL := ABaseURL;
  if (Length(FBaseURL) > 0) and (FBaseURL[Length(FBaseURL)] = '/') then
    SetLength(FBaseURL, Length(FBaseURL) - 1);
  FAPIKey := AAPIKey;
  FTimeout := 120;
end;

destructor THTTPClient.Destroy;
begin
  inherited Destroy;
end;

function THTTPClient.PostJSON(const APath: string; AJSON: string): string;
var
  FullURL, Cmd, JsonFile, OutFile, StatusFile: string;
  F: TextFile;
  Line: string;
  ResultCode: Integer;
  StatusCode: Integer;
  StatusStr: string;
begin
  FullURL := FBaseURL + APath;
  JsonFile := GetTempFileName + '.json';
  OutFile := GetTempFileName + '.txt';
  StatusFile := GetTempFileName + '.status';
  
  { Write JSON to temp file }
  AssignFile(F, JsonFile);
  Rewrite(F);
  Write(F, AJSON);
  CloseFile(F);
  
  { Build curl command - write status to separate file }
  Cmd := 'curl -s -X POST -H "Content-Type: application/json" ';
  if FAPIKey <> '' then
    Cmd := Cmd + '-H "Authorization: Bearer ' + FAPIKey + '" ';
  Cmd := Cmd + '--max-time ' + IntToStr(FTimeout) + ' ';
  Cmd := Cmd + '-d @' + JsonFile + ' ';
  Cmd := Cmd + '-o ' + OutFile + ' ';
  Cmd := Cmd + '-w "%{http_code}" > ' + StatusFile + ' ';
  Cmd := Cmd + '"' + FullURL + '"';
  
  { Run curl }
  ResultCode := fpsystem(Cmd);
  
  { Check for errors }
  if ResultCode <> 0 then
  begin
    DeleteFile(JsonFile);
    if FileExists(OutFile) then
      DeleteFile(OutFile);
    if FileExists(StatusFile) then
      DeleteFile(StatusFile);
    raise EHTTPError.Create('curl failed with code: ' + IntToStr(ResultCode), 0);
  end;
  
  { Read status code from status file }
  StatusCode := 0;
  if FileExists(StatusFile) then
  begin
    AssignFile(F, StatusFile);
    Reset(F);
    try
      ReadLn(F, StatusStr);
      StatusCode := StrToIntDef(Trim(StatusStr), 0);
    finally
      CloseFile(F);
    end;
    DeleteFile(StatusFile);
  end;
  
  { Read response body }
  if (StatusCode >= 200) and (StatusCode < 300) then
  begin
    if FileExists(OutFile) then
    begin
      AssignFile(F, OutFile);
      Reset(F);
      try
        Result := '';
        while not EOF(F) do
        begin
          ReadLn(F, Line);
          Result := Result + Line;
        end;
      finally
        CloseFile(F);
      end;
      DeleteFile(OutFile);
    end;
  end
  else
  begin
    DeleteFile(JsonFile);
    if FileExists(OutFile) then
      DeleteFile(OutFile);
    raise EHTTPError.Create('HTTP Error: ' + IntToStr(StatusCode), StatusCode);
  end;
  
  DeleteFile(JsonFile);
end;

end.