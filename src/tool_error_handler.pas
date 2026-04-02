{
  Tool Error Handler - Comprehensive error handling and retry logic for tool execution.
  - Error categorization (syntax, permission, file not found, timeout)
  - Retry logic with configurable retries
  - Error statistics tracking
}
unit tool_error_handler;

{$mode objfpc}{$H+}

interface

uses SysUtils, types;

type
  { Error categories }
  TToolErrorType = (
    teNone,           { No error }
    teSyntax,         { Syntax/JSON parsing error }
    tePermission,     { Permission denied }
    teFileNotFound,   { File not found }
    teTimeout,        { Execution timeout }
    teTransient,      { Transient error (network, etc.) }
    teFatal           { Fatal error - no retry }
  );

  { Error details }
  TToolError = record
    ErrorType: TToolErrorType;
    ErrorMessage: string;
    ErrorCode: string;
    ToolName: string;
    InputJSON: string;
    RetryCount: Integer;
    IsRetryable: Boolean;
  end;

  { Retry configuration }
  TRetryConfig = record
    MaxRetries: Integer;
    RetryDelayMs: Int64;
    RetryOnTransient: Boolean;
    RetryOnTimeout: Boolean;
  end;

var
  { Global retry configuration }
  GRetryConfig: TRetryConfig = (
    MaxRetries: 3;
    RetryDelayMs: 1000;
    RetryOnTransient: True;
    RetryOnTimeout: True
  );

  { Error statistics }
  GTotalErrors: Integer = 0;
  GErrorsByType: array[TToolErrorType] of Integer = (
    0, 0, 0, 0, 0, 0, 0
  );

{ Categorize error from result }
function CategorizeError(const ToolName: string; const ToolResult: TToolExecutionResult): TToolErrorType;

{ Create error record }
function CreateToolError(const ToolName, InputJSON: string; ErrorType: TToolErrorType; const Message: string): TToolError;

{ Check if error is retryable }
function IsRetryableError(ErrorType: TToolErrorType): Boolean;

{ Get error description }
function GetErrorDescription(ErrorType: TToolErrorType): string;

{ Get error statistics }
function GetErrorStats: string;

{ Reset error statistics }
procedure ResetErrorStats;

{ Execute with retry logic }
function ExecuteWithRetry(ToolName: string; InputJSON: string; MaxRetries: Integer = 3): TToolExecutionResult;

implementation

uses tool_executor;

function CategorizeError(const ToolName: string; const ToolResult: TToolExecutionResult): TToolErrorType;
var
  ErrorMsg: string;
begin
  if ToolResult.Success then
  begin
    Result := teNone;
    Exit;
  end;
  
  ErrorMsg := LowerCase(ToolResult.ErrorMessage);
  
  { Syntax errors }
  if (Pos('syntax', ErrorMsg) > 0) or
     (Pos('json', ErrorMsg) > 0) or
     (Pos('invalid', ErrorMsg) > 0) or
     (Pos('missing', ErrorMsg) > 0) or
     (Pos('empty', ErrorMsg) > 0) then
  begin
    Exit(teSyntax);
  end;
  
  { Permission errors }
  if (Pos('permission', ErrorMsg) > 0) or
     (Pos('denied', ErrorMsg) > 0) or
     (Pos('access', ErrorMsg) > 0) or
     (Pos('not allowed', ErrorMsg) > 0) then
  begin
    Exit(tePermission);
  end;
  
  { File not found errors }
  if (Pos('not found', ErrorMsg) > 0) or
     (Pos('does not exist', ErrorMsg) > 0) or
     (Pos('no such file', ErrorMsg) > 0) or
     (Pos('file not found', ErrorMsg) > 0) then
  begin
    Exit(teFileNotFound);
  end;
  
  { Timeout errors }
  if (Pos('timeout', ErrorMsg) > 0) or
     (Pos('timed out', ErrorMsg) > 0) or
     (Pos('deadline', ErrorMsg) > 0) then
  begin
    Exit(teTimeout);
  end;
  
  { Network/transient errors }
  if (Pos('network', ErrorMsg) > 0) or
     (Pos('connection', ErrorMsg) > 0) or
     (Pos('temporarily', ErrorMsg) > 0) or
     (Pos('unavailable', ErrorMsg) > 0) then
  begin
    Exit(teTransient);
  end;
  
  { Default to fatal }
  Result := teFatal;
end;

function CreateToolError(const ToolName, InputJSON: string; ErrorType: TToolErrorType; const Message: string): TToolError;
begin
  Result.ErrorType := ErrorType;
  Result.ErrorMessage := Message;
  Result.ErrorCode := GetErrorDescription(ErrorType);
  Result.ToolName := ToolName;
  Result.InputJSON := InputJSON;
  Result.RetryCount := 0;
  Result.IsRetryable := IsRetryableError(ErrorType);
  
  { Update statistics }
  Inc(GTotalErrors);
  Inc(GErrorsByType[ErrorType]);
end;

function IsRetryableError(ErrorType: TToolErrorType): Boolean;
begin
  case ErrorType of
    teTransient: Result := GRetryConfig.RetryOnTransient;
    teTimeout: Result := GRetryConfig.RetryOnTimeout;
  else
    Result := False;
  end;
end;

function GetErrorDescription(ErrorType: TToolErrorType): string;
begin
  case ErrorType of
    teNone: Result := 'No error';
    teSyntax: Result := 'Syntax error';
    tePermission: Result := 'Permission denied';
    teFileNotFound: Result := 'File not found';
    teTimeout: Result := 'Execution timeout';
    teTransient: Result := 'Transient error';
    teFatal: Result := 'Fatal error';
  else
    Result := 'Unknown error';
  end;
end;

function GetErrorStats: string;
var
  ErrorType: TToolErrorType;
begin
  Result := '=== Error Statistics ===' + LineEnding;
  Result := Result + 'Total Errors: ' + IntToStr(GTotalErrors) + LineEnding;
  Result := Result + LineEnding + 'By Type:' + LineEnding;
  
  for ErrorType := Low(TToolErrorType) to High(TToolErrorType) do
  begin
    if GErrorsByType[ErrorType] > 0 then
      Result := Result + '  ' + GetErrorDescription(ErrorType) + ': ' + IntToStr(GErrorsByType[ErrorType]) + LineEnding;
  end;
end;

procedure ResetErrorStats;
var
  ErrorType: TToolErrorType;
begin
  GTotalErrors := 0;
  for ErrorType := Low(TToolErrorType) to High(TToolErrorType) do
    GErrorsByType[ErrorType] := 0;
end;

function ExecuteWithRetry(ToolName: string; InputJSON: string; MaxRetries: Integer): TToolExecutionResult;
var
  RetryCount: Integer;
  ErrorType: TToolErrorType;
  LastError: string;
begin
  RetryCount := 0;
  LastError := '';
  
  while RetryCount <= MaxRetries do
  begin
    Result := ExecuteToolByName(ToolName, InputJSON);
    
    if Result.Success then
      Exit;
      
    ErrorType := CategorizeError(ToolName, Result);
    LastError := Result.ErrorMessage;
    
    { Update statistics }
    Inc(GTotalErrors);
    Inc(GErrorsByType[ErrorType]);
    
    { Check if retryable }
    if not IsRetryableError(ErrorType) then
    begin
      { Not retryable - return error }
      Result.ErrorMessage := GetErrorDescription(ErrorType) + ': ' + LastError;
      Exit;
    end;
    
    { Check retry limit }
    if RetryCount >= MaxRetries then
    begin
      Result.ErrorMessage := 'Max retries (' + IntToStr(MaxRetries) + ') exceeded. Last error: ' + LastError;
      Exit;
    end;
    
    { Wait before retry }
    if GRetryConfig.RetryDelayMs > 0 then
      Sleep(GRetryConfig.RetryDelayMs);
      
    Inc(RetryCount);
  end;
  
  { Should not reach here }
  Result.Success := False;
  Result.ErrorMessage := 'Retry logic failed unexpectedly';
end;

end.
