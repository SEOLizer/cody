{
  Request Optimizer - Caching and optimization for LLM requests.
  - System prompt caching with hash tracking
  - Tool result caching with TTL
  - Request deduplication
}
unit request_optimizer;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  { Cache entry for tool results }
  TToolCacheEntry = record
    ToolName: string;
    ToolInput: string;
    Result: string;
    Timestamp: Int64;
    HitCount: Integer;
  end;

  { Cache entry for LLM responses }
  TResponseCacheEntry = record
    RequestHash: string;
    Response: TLLMResponse;
    Timestamp: Int64;
    HitCount: Integer;
  end;

  { Request optimizer }
  TRequestOptimizer = class
  private
    FToolCache: array of TToolCacheEntry;
    FResponseCache: array of TResponseCacheEntry;
    FSystemPromptHash: string;
    FSystemPromptChanged: Boolean;
    FCacheEnabled: Boolean;
    FToolCacheTTL: Int64;  { Time-to-live in milliseconds }
    FResponseCacheTTL: Int64;
    FMaxToolCacheSize: Integer;
    FMaxResponseCacheSize: Integer;
    function HashString(const S: string): string;
    function GetCurrentTimeMs: Int64;
  public
    constructor Create;
    destructor Destroy; override;
    
    { System prompt tracking }
    procedure UpdateSystemPromptHash(const SystemPrompt: string);
    function IsSystemPromptChanged: Boolean;
    function GetSystemPromptHash: string;
    
    { Tool result caching }
    function GetCachedToolResult(const ToolName, ToolInput: string; out CachedResult: string): Boolean;
    procedure CacheToolResult(const ToolName, ToolInput, ToolResult: string);
    procedure InvalidateToolCache;
    function GetToolCacheStats: string;
    
    { Response caching }
    function GetCachedResponse(const Messages: TMessageArray; out Response: TLLMResponse): Boolean;
    procedure CacheResponse(const Messages: TMessageArray; const Response: TLLMResponse);
    procedure InvalidateResponseCache;
    function GetResponseCacheStats: string;
    
    { Configuration }
    procedure SetCacheEnabled(Enabled: Boolean);
    procedure SetToolCacheTTL(TTLms: Int64);
    procedure SetResponseCacheTTL(TTLms: Int64);
    
    { Statistics }
    procedure ClearAllCaches;
    function GetStats: string;
  end;

var
  GRequestOptimizer: TRequestOptimizer;

{ Initialize request optimizer }
procedure InitRequestOptimizer;

{ Get global optimizer instance }
function GetRequestOptimizer: TRequestOptimizer;

implementation

constructor TRequestOptimizer.Create;
begin
  inherited Create;
  SetLength(FToolCache, 0);
  SetLength(FResponseCache, 0);
  FSystemPromptHash := '';
  FSystemPromptChanged := False;
  FCacheEnabled := True;
  FToolCacheTTL := 300000;  { 5 minutes }
  FResponseCacheTTL := 60000;  { 1 minute }
  FMaxToolCacheSize := 100;
  FMaxResponseCacheSize := 50;
end;

destructor TRequestOptimizer.Destroy;
begin
  SetLength(FToolCache, 0);
  SetLength(FResponseCache, 0);
  inherited Destroy;
end;

function TRequestOptimizer.HashString(const S: string): string;
var
  i, Hash: Integer;
begin
  { Simple hash for tracking changes }
  Hash := 0;
  for i := 1 to Length(S) do
  begin
    Hash := ((Hash shl 5) + Hash) + Ord(S[i]);
  end;
  Result := IntToHex(Hash, 8);
end;

function TRequestOptimizer.GetCurrentTimeMs: Int64;
begin
  { Use GetTickCount64 if available, otherwise use a simple counter }
  Result := Int64(Trunc(Now * 86400000));  { Convert to milliseconds }
end;

procedure TRequestOptimizer.UpdateSystemPromptHash(const SystemPrompt: string);
var
  NewHash: string;
begin
  NewHash := HashString(SystemPrompt);
  FSystemPromptChanged := (NewHash <> FSystemPromptHash);
  FSystemPromptHash := NewHash;
end;

function TRequestOptimizer.IsSystemPromptChanged: Boolean;
begin
  Result := FSystemPromptChanged;
end;

function TRequestOptimizer.GetSystemPromptHash: string;
begin
  Result := FSystemPromptHash;
end;

function TRequestOptimizer.GetCachedToolResult(const ToolName, ToolInput: string; out CachedResult: string): Boolean;
var
  i: Integer;
  CurrentTime: Int64;
begin
  Result := False;
  CachedResult := '';
  
  if not FCacheEnabled then
    Exit;
    
  CurrentTime := GetCurrentTimeMs;
  
  for i := 0 to Length(FToolCache) - 1 do
  begin
    if (FToolCache[i].ToolName = ToolName) and (FToolCache[i].ToolInput = ToolInput) then
    begin
      { Check TTL }
      if (CurrentTime - FToolCache[i].Timestamp) <= FToolCacheTTL then
      begin
        CachedResult := FToolCache[i].Result;
        Inc(FToolCache[i].HitCount);
        Exit(True);
      end
      else
      begin
        { Expired - remove entry }
        FToolCache[i].ToolName := '';
      end;
    end;
  end;
end;

procedure TRequestOptimizer.CacheToolResult(const ToolName, ToolInput, ToolResult: string);
var
  i, EmptyIdx: Integer;
begin
  if not FCacheEnabled then
    Exit;
    
  { Find empty slot or oldest entry }
  EmptyIdx := -1;
  for i := 0 to Length(FToolCache) - 1 do
  begin
    if FToolCache[i].ToolName = '' then
    begin
      EmptyIdx := i;
      Break;
    end;
  end;
  
  if EmptyIdx = -1 then
  begin
    if Length(FToolCache) < FMaxToolCacheSize then
    begin
      EmptyIdx := Length(FToolCache);
      SetLength(FToolCache, EmptyIdx + 1);
    end
    else
    begin
      { Replace oldest }
      EmptyIdx := 0;
      for i := 1 to Length(FToolCache) - 1 do
      begin
        if FToolCache[i].Timestamp < FToolCache[EmptyIdx].Timestamp then
          EmptyIdx := i;
      end;
    end;
  end;
  
  FToolCache[EmptyIdx].ToolName := ToolName;
  FToolCache[EmptyIdx].ToolInput := ToolInput;
  FToolCache[EmptyIdx].Result := ToolResult;
  FToolCache[EmptyIdx].Timestamp := GetCurrentTimeMs;
  FToolCache[EmptyIdx].HitCount := 0;
end;

procedure TRequestOptimizer.InvalidateToolCache;
var
  i: Integer;
begin
  for i := 0 to Length(FToolCache) - 1 do
  begin
    FToolCache[i].ToolName := '';
  end;
end;

function TRequestOptimizer.GetToolCacheStats: string;
var
  i, Count, TotalHits: Integer;
begin
  Count := 0;
  TotalHits := 0;
  
  for i := 0 to Length(FToolCache) - 1 do
  begin
    if FToolCache[i].ToolName <> '' then
    begin
      Inc(Count);
      Inc(TotalHits, FToolCache[i].HitCount);
    end;
  end;
  
  Result := 'Tool Cache: ' + IntToStr(Count) + ' entries, ' + IntToStr(TotalHits) + ' hits';
end;

function TRequestOptimizer.GetCachedResponse(const Messages: TMessageArray; out Response: TLLMResponse): Boolean;
var
  RequestHash: string;
  i: Integer;
  CurrentTime: Int64;
begin
  Result := False;
  
  if not FCacheEnabled then
    Exit;
    
  { Build hash from messages }
  RequestHash := '';
  for i := 0 to Length(Messages) - 1 do
  begin
    RequestHash := RequestHash + Messages[i].TextContent;
  end;
  RequestHash := HashString(RequestHash);
  
  CurrentTime := GetCurrentTimeMs;
  
  for i := 0 to Length(FResponseCache) - 1 do
  begin
    if FResponseCache[i].RequestHash = RequestHash then
    begin
      if (CurrentTime - FResponseCache[i].Timestamp) <= FResponseCacheTTL then
      begin
        Response := FResponseCache[i].Response;
        Inc(FResponseCache[i].HitCount);
        Exit(True);
      end;
    end;
  end;
end;

procedure TRequestOptimizer.CacheResponse(const Messages: TMessageArray; const Response: TLLMResponse);
var
  RequestHash: string;
  i, EmptyIdx: Integer;
begin
  if not FCacheEnabled then
    Exit;
    
  { Build hash from messages }
  RequestHash := '';
  for i := 0 to Length(Messages) - 1 do
  begin
    RequestHash := RequestHash + Messages[i].TextContent;
  end;
  RequestHash := HashString(RequestHash);
  
  { Find empty slot }
  EmptyIdx := -1;
  for i := 0 to Length(FResponseCache) - 1 do
  begin
    if FResponseCache[i].RequestHash = '' then
    begin
      EmptyIdx := i;
      Break;
    end;
  end;
  
  if EmptyIdx = -1 then
  begin
    if Length(FResponseCache) < FMaxResponseCacheSize then
    begin
      EmptyIdx := Length(FResponseCache);
      SetLength(FResponseCache, EmptyIdx + 1);
    end
    else
    begin
      { Replace oldest }
      EmptyIdx := 0;
      for i := 1 to Length(FResponseCache) - 1 do
      begin
        if FResponseCache[i].Timestamp < FResponseCache[EmptyIdx].Timestamp then
          EmptyIdx := i;
      end;
    end;
  end;
  
  FResponseCache[EmptyIdx].RequestHash := RequestHash;
  FResponseCache[EmptyIdx].Response := Response;
  FResponseCache[EmptyIdx].Timestamp := GetCurrentTimeMs;
  FResponseCache[EmptyIdx].HitCount := 0;
end;

procedure TRequestOptimizer.InvalidateResponseCache;
var
  i: Integer;
begin
  for i := 0 to Length(FResponseCache) - 1 do
  begin
    FResponseCache[i].RequestHash := '';
  end;
end;

function TRequestOptimizer.GetResponseCacheStats: string;
var
  i, Count, TotalHits: Integer;
begin
  Count := 0;
  TotalHits := 0;
  
  for i := 0 to Length(FResponseCache) - 1 do
  begin
    if FResponseCache[i].RequestHash <> '' then
    begin
      Inc(Count);
      Inc(TotalHits, FResponseCache[i].HitCount);
    end;
  end;
  
  Result := 'Response Cache: ' + IntToStr(Count) + ' entries, ' + IntToStr(TotalHits) + ' hits';
end;

procedure TRequestOptimizer.SetCacheEnabled(Enabled: Boolean);
begin
  FCacheEnabled := Enabled;
  if not Enabled then
    ClearAllCaches;
end;

procedure TRequestOptimizer.SetToolCacheTTL(TTLms: Int64);
begin
  FToolCacheTTL := TTLms;
end;

procedure TRequestOptimizer.SetResponseCacheTTL(TTLms: Int64);
begin
  FResponseCacheTTL := TTLms;
end;

procedure TRequestOptimizer.ClearAllCaches;
begin
  InvalidateToolCache;
  InvalidateResponseCache;
end;

function TRequestOptimizer.GetStats: string;
begin
  Result := GetToolCacheStats + ' | ' + GetResponseCacheStats;
end;

procedure InitRequestOptimizer;
begin
  if GRequestOptimizer = nil then
    GRequestOptimizer := TRequestOptimizer.Create;
end;

function GetRequestOptimizer: TRequestOptimizer;
begin
  if GRequestOptimizer = nil then
    InitRequestOptimizer;
  Result := GRequestOptimizer;
end;

initialization
  GRequestOptimizer := nil;

finalization
  FreeAndNil(GRequestOptimizer);

end.
