{
  Command Line Interface for the AI Assistant with Tool support.
  Includes CLAUDE.md integration for project memory.
}
unit cli;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, types, llmclient, chathistory, skills, bash_tool, ui_helper, cursor_helper, context_compression, thinking_planning, reasoning_chains, request_optimizer, tool_error_handler, config, session_memory;

type
  TCLI = class
  private
    FLLMClient: TLLMClient;
    FSkillsManager: TSkillsManager;
    FConfig: TLLMConfig;
    FFormat: TLLMFormat;
    FInRecovery: Boolean;
    FIsProcessing: Boolean;
    FInputQueue: array of string;
    FQueueCount: Integer;
    FToolCallCount: Integer;
    FGitInitialized: Boolean;
    FGitAvailable: Boolean;
    FSystemPrompt: string;
    FInputFile: string;
    const MAX_TOOL_CALLS = 15;
    procedure PrintWelcome;
    procedure PrintHelp;
    procedure PrintPrompt;
    procedure ProcessCommand(const Input: string);
    procedure HandleChatWithThinking(const Input: string);
    procedure HandleToolCall(const ToolName: string; const ToolInput: string; const ToolID: string; out Success: Boolean; out ErrorMsg: string);
    function ParseArgs: Boolean;
    procedure InitializeTools;
    function GetSystemPrompt: string;
    function GetClaudeMDFromPath(const Path: string): string;
    procedure EnqueueInput(const Input: string);
    function DequeueInput: string;
    { Check if there's queued input - for stdin detection }
    function HasQueuedInput: Boolean;
    { Try to get queued input without blocking }
    function TryDequeueInput: string;
    { Handle skill commands }
    procedure HandleSkillCommand(const Input: string);
    { Run commands from file }
    procedure HandleRunFile(const Filename: string);
    { Git detection and initialization }
    procedure DetectGit;
    function CheckGitAvailable: Boolean;
    function IsGitInitialized: Boolean;
    function TryInitGit: Boolean;
    constructor Create;
    destructor Destroy; override;
  public
    procedure StartAgent;
  end;

implementation

uses
  tool_executor;

procedure TCLI.PrintWelcome;
var
  FrameLines: array[0..6] of string;
begin
  { Initialize UI }
  InitUI;
  
  { Create welcome content }
  FrameLines[0] := 'AI Assistant - Generic LLM CLI with Tools';
  FrameLines[1] := '';
  FrameLines[2] := 'Commands: /help, /clear, /save, /load, /quit, /think, /skills, /no-think';
  FrameLines[3] := 'Default: All prompts use Thinking Mode with evaluation loop';
  FrameLines[4] := '';
  FrameLines[5] := 'Available Tools: Bash, Read, Write, Edit, Diff, FileTree, Move, Mkdir, Delete, Glob, Grep';
  FrameLines[6] := 'Task Tools: TaskCreate, TaskList, TaskUpdate, Agent, Init';
  
  PrintFrame('AI ASSISTANT', FrameLines);
  WriteLn('');
  Flush(Output);
end;

procedure TCLI.PrintHelp;
var
  FrameLines: array[0..11] of string;
begin
  FrameLines[0] := 'Commands: /help, /clear, /save [f], /load [f], /quit, /model, /url, /no-think';
  FrameLines[1] := '          /run <file> - Run prompts from file (one per line)';
  FrameLines[2] := '          /stats - Show cache statistics';
  FrameLines[3] := '          /cache [clear|on|off] - Manage cache';
  FrameLines[4] := '          /errors - Show error statistics';
  FrameLines[5] := '          /retry [reset|max N] - Configure retry settings';
  FrameLines[6] := '          /config [save|create|path] - Configuration management';
  FrameLines[7] := '          /memory [extract|show|path] - Session memory management';
  FrameLines[8] := 'Default: All prompts use Thinking Mode (evaluation loop)';
  FrameLines[9] := 'Use /no-think for simple prompts without evaluation';
  FrameLines[10] := 'Tools: Bash, Read, Write, Edit, Diff, FileTree, Move, Mkdir, Delete, Glob, Grep';
  FrameLines[11] := 'Pipe mode: echo "prompt" | ./agent or ./agent < prompts.txt';
  PrintFrame('HELP', FrameLines);
  WriteLn('');
  Flush(Output);
end;

procedure TCLI.PrintPrompt;
begin
  Write('> ');
  Flush(Output);
end;

function TCLI.GetSystemPrompt: string;
var
  GlobalClaudeMD, ProjectClaudeMD: string;
begin
  Result := 
    'You are an expert AI coding assistant specialized in software architecture, code analysis, and refactoring.' + LineEnding +
    LineEnding +
    '=== CORE CAPABILITIES ===' + LineEnding +
    '1. CODE ANALYSIS: You can analyze existing code to identify issues, patterns, and quality' + LineEnding +
    '2. CODE REVIEW: Evaluate code for bugs, security vulnerabilities, performance issues' + LineEnding +
    '3. REFACTORING: Suggest and implement improvements to existing code' + LineEnding +
    '4. ARCHITECTURE: Recommend appropriate patterns and structures for projects' + LineEnding +
    LineEnding +
    '=== CODE ANALYSIS APPROACH ===' + LineEnding +
    '- When asked to analyze code, read the relevant files first using the Read tool' + LineEnding +
    '- Check for: code smells, potential bugs, security issues, performance bottlenecks' + LineEnding +
    '- Evaluate: code organization, naming conventions, documentation, test coverage' + LineEnding +
    '- Consider: maintainability, readability, extensibility, SOLID principles' + LineEnding +
    '- Use Glob to find related files and understand the project structure' + LineEnding +
    LineEnding +
    '=== REFACTORING GUIDELINES ===' + LineEnding +
    '- Always make small, focused changes rather than large rewrites' + LineEnding +
    '- Before refactoring, read and understand the existing code thoroughly' + LineEnding +
    '- Preserve the external behavior while improving internal structure' + LineEnding +
    '- Use Edit tool for precise find/replace operations' + LineEnding +
    '- After refactoring, verify the changes work correctly' + LineEnding +
    '- If asked to refactor, explain what you will change and why' + LineEnding +
    LineEnding +
    '=== CODE QUALITY CRITERIA ===' + LineEnding +
    'Good code:' + LineEnding +
    '- Has clear, descriptive names for variables, functions, classes' + LineEnding +
    '- Is well-organized with consistent formatting' + LineEnding +
    '- Has appropriate comments for complex logic' + LineEnding +
    '- Follows the language conventions and idioms' + LineEnding +
    '- Handles errors gracefully' + LineEnding +
    '- Is modular with single responsibility' + LineEnding +
    LineEnding +
    'Code smells to identify:' + LineEnding +
    '- Duplicate code that should be extracted' + LineEnding +
    '- Long functions that should be split' + LineEnding +
    '- Tight coupling between modules' + LineEnding +
    '- Missing abstraction layers' + LineEnding +
    '- Inconsistent naming' + LineEnding +
    '- God classes that do too much' + LineEnding +
    LineEnding +
    '=== ARCHITECTURE PATTERNS ===' + LineEnding +
    '- MVC (Model-View-Controller): Separate data (Model), UI (View), and logic (Controller)' + LineEnding +
    '- MVP (Model-View-Presenter): Similar to MVC, but Presenter handles all UI logic' + LineEnding +
    '- MVVM (Model-View-ViewModel): Used in modern UI frameworks, data binding' + LineEnding +
    '- Repository Pattern: Abstract data access layer' + LineEnding +
    '- Factory Pattern: Object creation logic' + LineEnding +
    '- Singleton Pattern: One instance, global access' + LineEnding +
    '- Dependency Injection: Pass dependencies instead of creating them' + LineEnding +
    '- Clean Architecture: Layer separation (UI, Business Logic, Data)' + LineEnding +
    '- SOLID Principles: Single responsibility, Open/Closed, Liskov substitution, Interface segregation, Dependency inversion' + LineEnding +
    LineEnding +
    '=== SECURITY AWARENESS ===' + LineEnding +
    '- Be alert for security vulnerabilities in code: SQL injection, XSS, buffer overflows' + LineEnding +
    '- Check for hardcoded secrets, passwords, API keys' + LineEnding +
    '- Validate input and sanitize output' + LineEnding +
    '- Use parameterized queries instead of string concatenation' + LineEnding +
    '- When you find security issues, clearly highlight them in your analysis' + LineEnding +
    LineEnding +
    '=== RESPONSE GUIDELINES ===' + LineEnding +
    '- For simple questions, answer directly WITHOUT using tools' + LineEnding +
    '- Use tools ONLY when you need to read files, run commands, or make changes' + LineEnding +
    '- When analyzing code, first read the files then provide your assessment' + LineEnding +
    '- When refactoring, explain your plan before making changes' + LineEnding +
    '- IMPORTANT: When you need to use a tool, output ONLY in this JSON format: [{"name": "TOOL_NAME", "arguments": {"param1": "value1", "param2": "value2"}}]' + LineEnding +
    '- Example: For Bash tool with "ls -la": [{"name": "Bash", "arguments": {"command": "ls -la"}}]' + LineEnding +
    '- After the JSON, add <end_of_turn> marker' + LineEnding +
    LineEnding +
    'AVAILABLE TOOLS:' + LineEnding +
    '- Bash: Execute shell commands (use for running tests, build commands)' + LineEnding +
    '- Read: Read file contents (use when you need to see code)' + LineEnding +
    '- Write: Write file contents (use for creating new files)' + LineEnding +
    '- Edit: Edit file by find/replace (use for refactoring)' + LineEnding +
    '- Glob: Find files by pattern (use to explore project structure)' + LineEnding +
    '- Grep: Search content in files (use to find specific code patterns)' + LineEnding +
    '- TaskCreate: Create a task in the task list (use for planning complex tasks)' + LineEnding +
    '- TaskList: List all tasks (use to check progress)' + LineEnding +
    '- TaskUpdate: Update task status (use to mark tasks as in_progress/completed)' + LineEnding +
    '- Init: Create or update PROJECT.md with project documentation' + LineEnding +
    LineEnding +
    'AUTONOMOUS PLANNING:' + LineEnding +
    '- For code analysis: Read files, examine structure, identify issues, provide report' + LineEnding +
    '- For refactoring: Plan changes, explain rationale, implement step by step, verify' + LineEnding +
    '- For complex tasks, create a task list to track progress' + LineEnding +
    '- After creating tasks, set the first task to in_progress using TaskUpdate' + LineEnding +
    LineEnding +
    'THINKING PROCESS:' + LineEnding +
    '- For code analysis: Read the code, identify patterns, spot issues, evaluate quality' + LineEnding +
    '- For refactoring: Understand current state, plan improvements, implement carefully' + LineEnding +
    '- After tool execution, evaluate the result: did it work? Did you encounter errors?' + LineEnding +
    '- If problems occur, analyze what went wrong and try an alternative approach' + LineEnding +
    LineEnding +
    'Think step by step. Plan before acting. Analyze code thoroughly before making changes.';
    
  { Add CLAUDE.md content if available }
  GlobalClaudeMD := GetClaudeMDFromPath(GetUserDir + '.claude/CLAUDE.md');
  ProjectClaudeMD := GetClaudeMDFromPath(FConfig.WorkingDirectory + '/CLAUDE.md');
  
  if GlobalClaudeMD <> '' then
  begin
    Result := Result + LineEnding + LineEnding + '=== GLOBAL PROJECT NOTES ===' + LineEnding + GlobalClaudeMD;
  end;
  
  if ProjectClaudeMD <> '' then
  begin
    Result := Result + LineEnding + LineEnding + '=== PROJECT SPECIFIC NOTES ===' + LineEnding + ProjectClaudeMD;
  end;
  
  { Add PROJECT.md content if available }
  GlobalClaudeMD := GetClaudeMDFromPath(GetUserDir + '.claude/PROJECT.md');
  ProjectClaudeMD := GetClaudeMDFromPath(FConfig.WorkingDirectory + '/PROJECT.md');
  
  if GlobalClaudeMD <> '' then
  begin
    Result := Result + LineEnding + LineEnding + '=== GLOBAL PROJECT DOCUMENTATION ===' + LineEnding + GlobalClaudeMD;
  end;
  
  if ProjectClaudeMD <> '' then
  begin
    Result := Result + LineEnding + LineEnding + '=== PROJECT DOCUMENTATION ===' + LineEnding + ProjectClaudeMD;
  end;
  
  { Add Git context - detected at startup }
  if FGitAvailable then
  begin
    if FGitInitialized then
    begin
      Result := Result + LineEnding + LineEnding + '=== GIT STATUS ===' + LineEnding +
        'This project uses Git. You should use Git to track changes and work with version control.' + LineEnding +
        'Use Bash tool to run git commands: git status, git add, git commit, git push, etc.';
    end
    else
    begin
      Result := Result + LineEnding + LineEnding + '=== GIT STATUS ===' + LineEnding +
        'Git is available but not initialized in this project.' + LineEnding +
        'Only use Git commands when explicitly requested by the user.' + LineEnding +
        'Do NOT initialize Git unless the user specifically asks you to.';
    end;
  end
  else
  begin
    Result := Result + LineEnding + LineEnding + '=== GIT STATUS ===' + LineEnding +
      'Git is not available on this system.';
  end;
end;

{ Check if git is available on the system }
function TCLI.CheckGitAvailable: Boolean;
var
  ExecResult: TToolExecutionResult;
begin
  ExecResult := ExecuteBash('git --version');
  Result := ExecResult.Success;
end;

{ Check if git is initialized in working directory }
function TCLI.IsGitInitialized: Boolean;
var
  GitDir: string;
begin
  GitDir := FConfig.WorkingDirectory + '/.git';
  Result := DirectoryExists(GitDir);
end;

{ Try to initialize git in the working directory }
function TCLI.TryInitGit: Boolean;
var
  ExecResult: TToolExecutionResult;
begin
  if FGitInitialized or (not FGitAvailable) then
  begin
    Result := False;
    Exit;
  end;
  
  { Run git init }
  ExecResult := ExecuteBash('git init', FConfig.WorkingDirectory);
  
  if ExecResult.Success then
  begin
    FGitInitialized := True;
    WriteLn('Git initialized in: ', FConfig.WorkingDirectory);
    Flush(Output);
    Result := True;
  end
  else
    Result := False;
end;

{ Detect Git availability and initialization status }
procedure TCLI.DetectGit;
begin
  FGitAvailable := CheckGitAvailable;
  FGitInitialized := False;
  
  if FGitAvailable then
  begin
    FGitInitialized := IsGitInitialized;
    
    WriteLn('');
    if FGitInitialized then
      WriteLn('[Git] Detected: Git repository initialized')
    else
      WriteLn('[Git] Detected: Git available but not initialized');
    Flush(Output);
  end
  else
  begin
    WriteLn('');
    WriteLn('[Git] Not available on this system');
    Flush(Output);
  end;
end;

function TCLI.GetClaudeMDFromPath(const Path: string): string;
var
  F: TextFile;
  Line: string;
begin
  Result := '';
  if not FileExists(Path) then
    Exit;
    
  try
    AssignFile(F, Path);
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

procedure TCLI.InitializeTools;
var
  Tools: array of TToolDef;
begin
  SetLength(Tools, 17);
  
  Tools[0].Name := 'Bash';
  Tools[0].Description := 'Execute shell commands';
  Tools[0].Parameters := '{"type":"object","properties":{"command":{"type":"string"}},"required":["command"]}';
  
  Tools[1].Name := 'Read';
  Tools[1].Description := 'Read file contents';
  Tools[1].Parameters := '{"type":"object","properties":{"file_path":{"type":"string"}},"required":["file_path"]}';
  
  Tools[2].Name := 'Write';
  Tools[2].Description := 'Write file contents';
  Tools[2].Parameters := '{"type":"object","properties":{"file_path":{"type":"string"},"content":{"type":"string"}},"required":["file_path","content"]}';
  
  Tools[3].Name := 'Edit';
  Tools[3].Description := 'Edit file by find/replace';
  Tools[3].Parameters := '{"type":"object","properties":{"file_path":{"type":"string"},"old_string":{"type":"string"},"new_string":{"type":"string"}},"required":["file_path","old_string","new_string"]}';
  
  Tools[4].Name := 'Diff';
  Tools[4].Description := 'Compare two files and show differences';
  Tools[4].Parameters := '{"type":"object","properties":{"file_path1":{"type":"string","description":"First file to compare"},"file_path2":{"type":"string","description":"Second file to compare"}},"required":["file_path1","file_path2"]}';
  
  Tools[5].Name := 'FileTree';
  Tools[5].Description := 'Display directory tree structure';
  Tools[5].Parameters := '{"type":"object","properties":{"path":{"type":"string","description":"Directory path (default: current directory)"},"max_depth":{"type":"integer","description":"Maximum depth (default: 3)"}},"required":[]}';
  
  Tools[6].Name := 'Move';
  Tools[6].Description := 'Move or rename a file or directory';
  Tools[6].Parameters := '{"type":"object","properties":{"source":{"type":"string","description":"Source file or directory path"},"destination":{"type":"string","description":"Destination path or new name"}},"required":["source","destination"]}';
  
  Tools[7].Name := 'Mkdir';
  Tools[7].Description := 'Create a new directory';
  Tools[7].Parameters := '{"type":"object","properties":{"path":{"type":"string","description":"Directory path to create"},"parents":{"type":"boolean","description":"Create parent directories (default: true)"}},"required":["path"]}';
  
  Tools[8].Name := 'Delete';
  Tools[8].Description := 'Delete a file or directory';
  Tools[8].Parameters := '{"type":"object","properties":{"path":{"type":"string","description":"File or directory path to delete"},"recursive":{"type":"boolean","description":"Delete directories recursively (default: false)"}},"required":["path"]}';
  
  Tools[9].Name := 'Glob';
  Tools[9].Description := 'Find files by pattern';
  Tools[9].Parameters := '{"type":"object","properties":{"pattern":{"type":"string"}},"required":["pattern"]}';
  
  Tools[10].Name := 'Grep';
  Tools[10].Description := 'Search content in files';
  Tools[10].Parameters := '{"type":"object","properties":{"pattern":{"type":"string"}},"required":["pattern"]}';
  
  // Task tools
  Tools[11].Name := 'TaskCreate';
  Tools[11].Description := 'Create a new task in the task list';
  Tools[11].Parameters := '{"type":"object","properties":{"subject":{"type":"string"},"description":{"type":"string"},"activeForm":{"type":"string"}},"required":["subject"]}';
  
  Tools[12].Name := 'TaskList';
  Tools[12].Description := 'List all tasks';
  Tools[12].Parameters := '{"type":"object","properties":{}}';
  
  Tools[13].Name := 'TaskUpdate';
  Tools[13].Description := 'Update task status and fields';
  Tools[13].Parameters := '{"type":"object","properties":{"id":{"type":"string"},"subject":{"type":"string"},"description":{"type":"string"},"status":{"type":"string"},"blockedBy":{"type":"string"},"blocks":{"type":"string"}},"required":["id"]}';
  
  // Agent tool
  Tools[14].Name := 'Agent';
  Tools[14].Description := 'Spawn a sub-agent to perform a complex multi-step task';
  Tools[14].Parameters := '{"type":"object","properties":{"description":{"type":"string"},"prompt":{"type":"string"},"subagent_type":{"type":"string"}},"required":["description","prompt"]}';
  
  // Init tool
  Tools[15].Name := 'Init';
  Tools[15].Description := 'Create or update PROJECT.md with project documentation';
  Tools[15].Parameters := '{"type":"object","properties":{"file_path":{"type":"string","description":"Optional: filename (default: PROJECT.md)"},"content":{"type":"string","description":"Optional: full markdown content. If empty, creates template"}},"required":[]}';
  
  // WebFetch tool
  Tools[16].Name := 'WebFetch';
  Tools[16].Description := 'Fetch content from a URL';
  Tools[16].Parameters := '{"type":"object","properties":{"url":{"type":"string","description":"URL to fetch"},"format":{"type":"string","description":"Output format: text, markdown, or html (default: markdown)"}},"required":["url"]}';
  
  FLLMClient.SetTools(Tools);
end;

procedure TCLI.HandleToolCall(const ToolName: string; const ToolInput: string; const ToolID: string; out Success: Boolean; out ErrorMsg: string);
var
  Result: TToolExecutionResult;
begin
  Success := False;
  ErrorMsg := '';
  
  WriteLn('');
  Write('⚡ Executing ');
  Write(ToolName);
  WriteLn('...');
  Flush(Output);
    
  { Pass through the input as-is - the JSON parsing will handle it }
  Result := ExecuteToolByName(ToolName, ToolInput);
  
  Success := Result.Success;
  
  if Result.Success then
  begin
    WriteLn('');
    WriteLn('✓ [Result] ' + Result.Output);
    WriteLn('');
    Flush(Output);
    ChatHistory_AddToolResult(ToolID, Result.Output);
  end
  else
  begin
    ErrorMsg := Result.ErrorMessage;
    WriteLn('');
    WriteLn('✗ [Error] ' + Result.ErrorMessage);
    WriteLn('');
    Flush(Output);
    ChatHistory_AddToolResultError(ToolID, Result.ErrorMessage);
  end;
end;

{ Thinking mode: iterative thinking with evaluation loop }
procedure TCLI.HandleChatWithThinking(const Input: string);
var
  Messages: TMessageArray;
  Response: TLLMResponse;
  Iterations: Integer;
  MaxIterations: Integer;
  ToolExecutionSuccessful: Boolean;
  HasResult: Boolean;
  EvalPrompt: string;
  ToolErrorMsg: string;
  ReasoningChain: TReasoningChain;
  StepStartTime: Int64;
begin
  MaxIterations := 20;
  Iterations := 0;
  FToolCallCount := 0;
  HasResult := False;
  
  { Initialize reasoning chain for step tracking }
  InitReasoningChain(ReasoningChain, 5);
  
  { Add user input }
  ChatHistory_AddMessage(Ord(ruUser), Input);
  
  { Ensure messages start with user for LM Studio compatibility }
  { ChatHistory_EnsureStartsWithUser; }
  
  { Initial thinking phase }
  WriteLn('');
  WriteLn('=== Thinking Phase ===');
  Flush(Output);
  try
    Messages := ChatHistory_GetMessagesForLMStudio(True);
    Response := FLLMClient.Chat(Messages, True);
    
    { Check for context errors and trigger reactive compression }
    if (Response.Content = '') and (GetContextState.CompressionCount > 0) then
    begin
      { Previous compression failed, try more aggressive compression }
      WriteLn('[Context Warning] Previous compression not sufficient, attempting aggressive recovery...');
      Messages := ChatHistory_GetMessagesForLMStudio(True);
      TriggerReactiveCompression(Messages);
      Response := FLLMClient.Chat(Messages, True);
    end;
    
    { Display thinking }
    WriteLn(Response.Content);
    Flush(Output);
    
    { Analyze task complexity and potentially create tasks }
    if not Response.HasToolCall then
    begin
      case AnalyzeTaskComplexity(Input) of
        tcComplex:
        begin
          WriteLn('');
          WriteLn('[Task Analysis] Complex task detected. Generating plan...');
          Flush(Output);
          { Generate plan and show summary }
          { (Plan generation happens during thinking, not enforced) }
        end;
        tcModerate:
        begin
          WriteLn('[Task Analysis] Moderate complexity - single step sufficient');
          Flush(Output);
        end;
        tcSimple:
        begin
          WriteLn('[Task Analysis] Simple task - direct execution');
          Flush(Output);
        end;
      end;
    end;
    
    { Add thinking to history }
    ChatHistory_AddMessage(Ord(ruAssistant), Response.Content);
    Inc(Iterations);
    
    { Main evaluation loop - continue until no more tool calls }
    while Response.HasToolCall and (Iterations < MaxIterations) and (FToolCallCount < MAX_TOOL_CALLS) do
    begin
      { Execute tool and track success }
      Inc(FToolCallCount);
      ToolExecutionSuccessful := True;
      
      { Create checkpoint before executing step }
      CreateCheckpoint(ReasoningChain, 'Before step ' + IntToStr(FToolCallCount) + ': ' + Response.ToolCallName);
      
      WriteLn('');
      WriteLn('[Tool Call: ', Response.ToolCallName, '] (', FToolCallCount, '/', MAX_TOOL_CALLS, ')');
      WriteLn('[Step ', GetCurrentStep(ReasoningChain), '] ', GetStateDescription(ReasoningChain.CurrentState));
      Flush(Output);
      ChatHistory_AddToolUse(Response.ToolCallName, Response.ToolCallID, Response.ToolCallInput);
      
      { Track step start }
      StepStartTime := GetTickCount64;
      SetState(ReasoningChain, esExecuting);
      
      { Execute the tool and capture result }
      HandleToolCall(Response.ToolCallName, Response.ToolCallInput, Response.ToolCallID, ToolExecutionSuccessful, ToolErrorMsg);
      
      { Record execution time }
      StepStartTime := GetTickCount64 - StepStartTime;
      
      { Handle tool failure with rollback option }
      if not ToolExecutionSuccessful then
      begin
        WriteLn('');
        WriteLn('[Tool Error] Tool execution failed: ', ToolErrorMsg);
        WriteLn('[Rollback] Checking if rollback is possible...');
        Flush(Output);
        
        { Try to rollback if checkpoints exist }
        if CanRollback(ReasoningChain) then
        begin
          WriteLn('[Rollback] Rolling back to last checkpoint...');
          Flush(Output);
          RollbackToLastCheckpoint(ReasoningChain);
          SetState(ReasoningChain, esPlanning);
          
          { Add error context to prompt for retry }
          ChatHistory_AddMessage(Ord(ruUser), 
            'The previous tool execution failed: ' + ToolErrorMsg + 
            '. Please try a different approach or alternative tool.');
        end
        else
        begin
          WriteLn('[Rollback] No checkpoints available. Continuing with error context.');
          Flush(Output);
          SetState(ReasoningChain, esFailed);
          
          { Add error context for recovery attempt }
          ChatHistory_AddMessage(Ord(ruUser), 
            'The previous tool execution failed: ' + ToolErrorMsg + 
            '. Please try an alternative approach.');
        end;
      end;
      
      { Record step completion }
      SetState(ReasoningChain, esEvaluating);
      
      { Check if tool execution was successful - look for error in last message }
      { (we need to check the last tool result in history) }
      { Now ask LLM to evaluate the result and decide next steps }
      WriteLn('');
      WriteLn('=== Evaluating Result ===');
      Flush(Output);
      
      { Build evaluation prompt }
      EvalPrompt := 
        'Evaluate the tool execution result above. ' +
        'Answer these questions:' + LineEnding +
        '1. Was the tool execution successful? ' +
        '2. Did you encounter any errors or unexpected results? ' +
        '3. If there were issues, what alternative approach could you try? ' +
        '4. Is the task complete, or do you need more steps? ' +
        '5. What is your next step?' + LineEnding +
        'Be honest and critical in your evaluation. If something failed, acknowledge it and try a different approach.';
      
      { Add evaluation request to history }
      ChatHistory_AddMessage(Ord(ruUser), EvalPrompt);
      
      { Get messages and call LLM (with tools for autonomous continuation) }
      Messages := ChatHistory_GetMessagesForLMStudio(True);
      Response := FLLMClient.Chat(Messages, True);
      
      { Display evaluation }
      WriteLn('');
      WriteLn('=== Evaluation ===');
      WriteLn(Response.Content);
      Flush(Output);
      
      { Plan verification during execution }
      if Response.HasToolCall then
      begin
        { Continue - we're still executing steps }
      end
      else
      begin
        { No more tool calls - verify task completion }
        WriteLn('');
        WriteLn('[Verification] Task completion check...');
        Flush(Output);
        
        { Check if the response indicates task is done }
        if Pos('complete', LowerCase(Response.Content)) > 0 then
        begin
          WriteLn('[Verification] Task appears to be completed.');
        end
        else if Pos('done', LowerCase(Response.Content)) > 0 then
        begin
          WriteLn('[Verification] Task appears to be completed.');
        end
        else
        begin
          WriteLn('[Verification] Task may require further steps.');
        end;
      end;
      
      { Add response to history }
      if Response.Content <> '' then
      begin
        ChatHistory_AddMessage(Ord(ruAssistant), Response.Content);
      end;
      
      Inc(Iterations);
      
      { Check if we should continue }
      if not Response.HasToolCall then
      begin
        { No more tool calls - task might be done }
        WriteLn('');
        WriteLn('--- Task completed or no further actions needed ---');
        Flush(Output);
      end;
    end;
    
    { Check if we hit the limit }
    if FToolCallCount >= MAX_TOOL_CALLS then
    begin
      WriteLn('');
      WriteLn('⚠ Reached maximum tool call limit (', MAX_TOOL_CALLS, '). Ending thinking loop.');
      WriteLn('');
      Flush(Output);
    end;
    
    HasResult := True;
  except
    on E: Exception do
    begin
      WriteLn('[Thinking Error]: ', E.Message);
      Flush(Output);
      
      { Check if it's a context error - try reactive compression }
      if Pos('413', E.Message) > 0 then
      begin
        WriteLn('[Context Error] Request too large. Attempting reactive compression...');
        { Reset and try with minimal context }
        ChatHistory_Reset;
        ChatHistory_AddMessage(Ord(ruSystem), GetSystemPrompt);
        ChatHistory_AddMessage(Ord(ruUser), Input);
        try
          Messages := ChatHistory_GetMessagesForLMStudio(True);
          TriggerReactiveCompression(Messages);
          Response := FLLMClient.Chat(Messages, True);
          if Response.Content <> '' then
          begin
            WriteLn('[Recovery] Successfully recovered with compressed context!');
            WriteLn(Response.Content);
            HasResult := True;
          end;
        except
          WriteLn('[Recovery Failed] Could not recover from context error.');
        end;
      end
      else
      begin
        FInRecovery := True;
        ChatHistory_Reset;
        ChatHistory_AddMessage(Ord(ruSystem), GetSystemPrompt);
      end;
    end;
  end;
  
  { Display execution summary }
  WriteLn('');
  WriteLn(GetStepSummary(ReasoningChain));
  Flush(Output);
  
  { Final response to user }
  if HasResult then
  begin
    WriteLn('');
    WriteLn('=== Final Result ===');
    WriteLn(Response.Content);
    WriteLn('');
    Flush(Output);
  end;
end;

{ Handle skill-related commands }
procedure TCLI.HandleSkillCommand(const Input: string);
var
  Cmd, Args: string;
  PosSpace: Integer;
  SkillPrompt, SkillName, SkillDesc: string;
  Lines: TStringArray;
  i: Integer;
begin
  if Input = '' then
  begin
    { List all skills }
    Lines := FSkillsManager.ListSkills;
    for i := 0 to Length(Lines) - 1 do
      WriteLn(Lines[i]);
    Exit;
  end;
  
  { Parse subcommand }
  PosSpace := Pos(' ', Input);
  if PosSpace > 0 then
  begin
    Cmd := LowerCase(Copy(Input, 1, PosSpace - 1));
    Args := Trim(Copy(Input, PosSpace + 1, Length(Input) - PosSpace));
  end
  else
  begin
    Cmd := LowerCase(Input);
    Args := '';
  end;
  
  if (Cmd = 'list') or (Cmd = 'ls') then
  begin
    Lines := FSkillsManager.ListSkills;
    for i := 0 to Length(Lines) - 1 do
      WriteLn(Lines[i]);
  end
  else if (Cmd = 'add') then
  begin
    { Format: /skills add <name> <description> <prompt> }
    if Args = '' then
    begin
      WriteLn('Usage: /skills add <name> <description> <prompt>');
      WriteLn('Example: /skills add review "Review code for issues" Please review the following code for bugs and security issues:');
      Flush(Output);
      Exit;
    end;
    
    { Simple parsing: first word is name, rest is description|prompt }
    PosSpace := Pos(' ', Args);
    if PosSpace > 0 then
    begin
      SkillName := Copy(Args, 1, PosSpace - 1);  { name }
      Args := Trim(Copy(Args, PosSpace + 1, Length(Args) - PosSpace));
      
      { Check for description|prompt separator }
      PosSpace := Pos(' ', Args);
      if PosSpace > 0 then
      begin
        SkillDesc := Copy(Args, 1, PosSpace - 1);  { description (first word) }
        SkillPrompt := Trim(Copy(Args, PosSpace + 1, Length(Args) - PosSpace));  { rest is prompt }
      end
      else
      begin
        { No prompt provided }
        WriteLn('Error: Prompt required');
        WriteLn('Usage: /skills add <name> <description> <prompt>');
        Flush(Output);
        Exit;
      end;
    end
    else
    begin
      WriteLn('Error: Name and description required');
      WriteLn('Usage: /skills add <name> <description> <prompt>');
      Flush(Output);
      Exit;
    end;
    
    FSkillsManager.AddSkill(SkillName, SkillDesc, SkillPrompt);
    WriteLn('Skill added: /' + SkillName);
    Flush(Output);
  end
  else if (Cmd = 'remove') or (Cmd = 'delete') or (Cmd = 'rm') then
  begin
    if Args = '' then
    begin
      WriteLn('Usage: /skills remove <name>');
      Flush(Output);
      Exit;
    end;
    
    FSkillsManager.RemoveSkill(Args);
    WriteLn('Skill removed: /' + Args);
    Flush(Output);
  end
  else
  begin
    { Treat as skill name - try to execute }
    SkillPrompt := FSkillsManager.FindSkill(Cmd);
    if SkillPrompt <> '' then
    begin
      WriteLn('Executing skill: /' + Cmd);
      Flush(Output);
      HandleChatWithThinking(SkillPrompt);
    end
    else
    begin
      WriteLn('Unknown skill command: ', Cmd);
      WriteLn('Use /skills to list available skills');
      Flush(Output);
    end;
  end;
end;

procedure TCLI.ProcessCommand(const Input: string);
var
  Cmd, Arg: string;
  PosSpace: Integer;
begin
  if Input = '' then
    Exit;
    
  PosSpace := Pos(' ', Input);
  if PosSpace > 0 then
  begin
    Cmd := LowerCase(Copy(Input, 1, PosSpace - 1));
    Arg := Trim(Copy(Input, PosSpace + 1, Length(Input) - PosSpace));
  end
  else
  begin
    Cmd := LowerCase(Input);
    Arg := '';
  end;
  
  if (Cmd = '/help') or (Cmd = 'help') then
    PrintHelp
  else if (Cmd = '/quit') or (Cmd = 'quit') or (Cmd = '/exit') then
  begin
    WriteLn('Goodbye!');
    Flush(Output);
    SwitchToMainScreen;
    Halt(0);
  end
  else if (Cmd = '/clear') then
  begin
    ChatHistory_Clear;
    ChatHistory_AddMessage(Ord(ruSystem), GetSystemPrompt);
    WriteLn('Chat cleared.');
    Flush(Output);
  end
  else if (Cmd = '/save') then
  begin
    if Arg = '' then Arg := 'chat.txt';
    ChatHistory_SaveToFile(Arg);
    WriteLn('Saved to: ', Arg);
    Flush(Output);
  end
  else if (Cmd = '/load') then
  begin
    if Arg = '' then Arg := 'chat.txt';
    if ChatHistory_LoadFromFile(Arg) then
    begin
      WriteLn('Loaded chat history from: ', Arg);
    end
    else
    begin
      WriteLn('Failed to load from: ', Arg);
    end;
    Flush(Output);
  end
  else if (Cmd = '/run') then
  begin
    { Run commands/prompts from file }
    if Arg = '' then
    begin
      WriteLn('Usage: /run <filename> - Run prompts from file (one per line)');
      Flush(Output);
    end
    else
    begin
      HandleRunFile(Arg);
    end;
  end
  else if (Cmd = '/model') then
  begin
    WriteLn('Model: ', FConfig.Model);
    Flush(Output);
  end
  else if (Cmd = '/url') then
  begin
    WriteLn('URL: ', FConfig.BaseURL);
    Flush(Output);
  end
  else if (Cmd = '/think') then
  begin
    { Enable thinking mode for this input }
    if Arg <> '' then
      HandleChatWithThinking(Arg)
    else
    begin
      WriteLn('Usage: /think <prompt> - Enable thinking mode for the prompt');
      Flush(Output);
    end;
  end
  else if (Cmd = '/skills') or (Cmd = '/skill') then
  begin
    HandleSkillCommand(Arg);
  end
  else if (Cmd = '/stats') then
  begin
    { Show cache statistics }
    WriteLn('=== Cache Statistics ===');
    WriteLn(GetRequestOptimizer.GetStats);
    Flush(Output);
  end
  else if (Cmd = '/cache') then
  begin
    { Cache management }
    if Arg = 'clear' then
    begin
      GetRequestOptimizer.ClearAllCaches;
      WriteLn('All caches cleared.');
    end
    else if Arg = 'on' then
    begin
      GetRequestOptimizer.SetCacheEnabled(True);
      WriteLn('Cache enabled.');
    end
    else if Arg = 'off' then
    begin
      GetRequestOptimizer.SetCacheEnabled(False);
      WriteLn('Cache disabled.');
    end
    else
    begin
      WriteLn('Usage: /cache [clear|on|off]');
    end;
    Flush(Output);
  end
  else if (Cmd = '/errors') then
  begin
    { Show error statistics }
    WriteLn(GetErrorStats);
    Flush(Output);
  end
  else if (Cmd = '/retry') then
  begin
    { Configure retry settings }
    if Arg = 'reset' then
    begin
      ResetErrorStats;
      WriteLn('Error statistics reset.');
    end
    else if Pos('max ', Arg) = 1 then
    begin
      { Set max retries }
      GRetryConfig.MaxRetries := StrToIntDef(Copy(Arg, 5, Length(Arg) - 4), 3);
      WriteLn('Max retries set to: ', GRetryConfig.MaxRetries);
    end
    else
    begin
      WriteLn('=== Retry Configuration ===');
      WriteLn('Max Retries: ', GRetryConfig.MaxRetries);
      WriteLn('Retry Delay: ', GRetryConfig.RetryDelayMs, 'ms');
      WriteLn('Retry on Transient: ', GRetryConfig.RetryOnTransient);
      WriteLn('Retry on Timeout: ', GRetryConfig.RetryOnTimeout);
      WriteLn('');
      WriteLn('Usage: /retry [reset|max <N>]');
    end;
    Flush(Output);
  end
  else if (Cmd = '/config') then
  begin
    { Show or edit configuration }
    if Arg = 'save' then
    begin
      { Save current config }
      SaveConfig(MergeConfig(LoadConfig, FConfig.BaseURL, FConfig.Model, FConfig.APIKey,
        FConfig.Temperature, FConfig.MaxTokens));
      WriteLn('Configuration saved to: ', GetConfigFilePath);
    end
    else if Arg = 'path' then
    begin
      WriteLn('Config file: ', GetConfigFilePath);
      if ConfigExists then
        WriteLn('Status: exists')
      else
        WriteLn('Status: not found');
    end
    else if Arg = 'create' then
    begin
      { Create default config file }
      SaveConfig(GetDefaultConfig);
      WriteLn('Default configuration created at: ', GetConfigFilePath);
    end
    else
    begin
      { Show current config }
      WriteLn(FormatConfig(MergeConfig(LoadConfig, FConfig.BaseURL, FConfig.Model, FConfig.APIKey,
        FConfig.Temperature, FConfig.MaxTokens)));
      WriteLn('');
      WriteLn('Usage: /config [save|create|path]');
    end;
    Flush(Output);
  end
  else if (Cmd = '/memory') then
  begin
    { Session memory commands }
    if Arg = 'extract' then
    begin
      { Force memory extraction }
      WriteLn('Extracting session memory...');
      Flush(Output);
      { This would normally extract from chat history }
      WriteLn('Memory saved to: ', GetMemoryFilePath);
    end
    else if Arg = 'show' then
    begin
      { Show current memory file }
      WriteLn(LoadMemoryFromFile);
    end
    else if Arg = 'path' then
    begin
      WriteLn('Memory file: ', GetMemoryFilePath);
    end
    else
    begin
      { Show session summary }
      WriteLn(GetSessionSummary);
      WriteLn('');
      WriteLn('Usage: /memory [extract|show|path]');
    end;
    Flush(Output);
  end
  else if (Cmd = '/no-think') then
  begin
    { Explicitly disable thinking mode for this input }
    if Arg <> '' then
      HandleChatWithThinking(Arg)
    else
    begin
      WriteLn('Usage: /no-think <prompt> - Run without thinking mode');
      Flush(Output);
    end;
  end
  else
    { Default: Use thinking mode for all prompts }
    HandleChatWithThinking(Input);
end;

procedure TCLI.HandleRunFile(const Filename: string);
var
  F: TextFile;
  Line: string;
  LineNum: Integer;
begin
  if not FileExists(Filename) then
  begin
    WriteLn('Error: File not found: ', Filename);
    Flush(Output);
    Exit;
  end;
  
  WriteLn('Running prompts from: ', Filename);
  Flush(Output);
  
  AssignFile(F, Filename);
  Reset(F);
  try
    LineNum := 0;
    while not EOF(F) do
    begin
      ReadLn(F, Line);
      Inc(LineNum);
      
      { Skip empty lines and comments }
      if (Trim(Line) = '') or (Trim(Line)[1] = '#') then
        Continue;
        
      WriteLn('');
      WriteLn('--- [Line ', LineNum, '] ', Line, ' ---');
      Flush(Output);
      
      { Execute the prompt }
      ProcessCommand(Line);
      Flush(Output);
    end;
    
    WriteLn('');
    WriteLn('Finished running: ', Filename);
    Flush(Output);
  finally
    CloseFile(F);
  end;
end;

function TCLI.ParseArgs: Boolean;
var
  i: Integer;
  FileConfig: TAgentConfig;
  SavedURL: string;
  SavedModel: string;
  SavedKey: string;
  SavedTemp: Double;
  SavedTokens: Integer;
begin
  Result := False;
  
  { Load config from file first }
  FileConfig := LoadConfig;
  
  { Use config file values as defaults }
  FConfig.BaseURL := FileConfig.BaseURL;
  FConfig.APIKey := FileConfig.APIKey;
  FConfig.Model := FileConfig.Model;
  FConfig.Temperature := FileConfig.Temperature;
  FConfig.MaxTokens := FileConfig.MaxTokens;
  FConfig.WorkingDirectory := FileConfig.WorkingDirectory;
  FFormat := lfOllama;
  FInputFile := '';
  
  { Store values to detect overrides }
  SavedURL := FConfig.BaseURL;
  SavedModel := FConfig.Model;
  SavedKey := FConfig.APIKey;
  SavedTemp := FConfig.Temperature;
  SavedTokens := FConfig.MaxTokens;
  
  i := 1;
  while i <= ParamCount do
  begin
    if ParamStr(i) = '-u' then
    begin
      if i + 1 <= ParamCount then
      begin
        FConfig.BaseURL := ParamStr(i + 1);
        Inc(i, 2);
        Continue;
      end;
    end
    else if ParamStr(i) = '-m' then
    begin
      if i + 1 <= ParamCount then
      begin
        FConfig.Model := ParamStr(i + 1);
        Inc(i, 2);
        Continue;
      end;
    end
    else if ParamStr(i) = '-k' then
    begin
      if i + 1 <= ParamCount then
      begin
        FConfig.APIKey := ParamStr(i + 1);
        Inc(i, 2);
        Continue;
      end;
    end
    else if (ParamStr(i) = '-w') or (ParamStr(i) = '--workdir') then
    begin
      if i + 1 <= ParamCount then
      begin
        FConfig.WorkingDirectory := ParamStr(i + 1);
        Inc(i, 2);
        Continue;
      end;
    end
    else if (ParamStr(i) = '-f') or (ParamStr(i) = '--file') then
    begin
      if i + 1 <= ParamCount then
      begin
        FInputFile := ParamStr(i + 1);
        Inc(i, 2);
        Continue;
      end;
    end
    else if (ParamStr(i) = '--openai') or (ParamStr(i) = '--openAI') then
    begin
      FFormat := lfOpenAI;
    end
    else if (ParamStr(i) = '--help') or (ParamStr(i) = '-h') then
    begin
      WriteLn('Usage: agent [-u URL] [-m MODEL] [-k KEY] [-w DIR] [-f FILE] [--openai|--ollama]');
      WriteLn('');
      WriteLn('Options:');
      WriteLn('  -u URL       API Base URL (default: http://localhost:11434)');
      WriteLn('  -m MODEL     Model name (default: llama3)');
      WriteLn('  -k KEY       API Key (optional)');
      WriteLn('  -f FILE      Run prompts from file (non-interactive mode)');
      WriteLn('  -w DIR       Working directory');
      WriteLn('  --openai     Use OpenAI-compatible API format');
      WriteLn('  --ollama     Use Ollama API format (default)');
      WriteLn('');
      WriteLn('Pipe mode:');
      WriteLn('  echo "prompt" | ./agent');
      WriteLn('  ./agent < prompts.txt');
      Exit(False);
    end;
    Inc(i);
  end;
  
  Result := True;
end;

constructor TCLI.Create;
begin
  inherited Create;
  ChatHistory_Init;
  FSkillsManager := nil;
  FInRecovery := False;
  FIsProcessing := False;
  FQueueCount := 0;
  FToolCallCount := 0;
  FGitInitialized := False;
  FGitAvailable := False;
  FSystemPrompt := '';
  SetLength(FInputQueue, 0);
end;

destructor TCLI.Destroy;
begin
  FreeAndNil(FLLMClient);
  FreeAndNil(FSkillsManager);
  SetLength(FInputQueue, 0);
  inherited Destroy;
end;

{ Input Queue Management - wie Claude }
procedure TCLI.EnqueueInput(const Input: string);
begin
  if FQueueCount >= Length(FInputQueue) then
    SetLength(FInputQueue, FQueueCount + 4);
  FInputQueue[FQueueCount] := Input;
  Inc(FQueueCount);
end;

function TCLI.DequeueInput: string;
var
  i: Integer;
begin
  Result := '';
  if FQueueCount = 0 then
    Exit;
    
  Result := FInputQueue[0];
  { Shift all items down }
  for i := 0 to FQueueCount - 2 do
    FInputQueue[i] := FInputQueue[i + 1];
  Dec(FQueueCount);
end;

{ Try to get queued input without blocking - returns '' if queue is empty }
function TCLI.TryDequeueInput: string;
begin
  if FQueueCount > 0 then
    Result := DequeueInput
  else
    Result := '';
end;

{ Check if there's queued input - for stdin detection }
function TCLI.HasQueuedInput: Boolean;
begin
  Result := FQueueCount > 0;
end;

procedure TCLI.StartAgent;
var
  Input: string;
begin
  if not ParseArgs then
    Exit;
  
  { Switch to alternate screen buffer at start }
  { Debug: Print ESC sequence directly }
  Write(#27'[?1049h');  { Switch to alternate screen }
  Write(#27'[2J');      { Clear entire screen }
  Write(#27'[1;1H');    { Go to position 1,1 }
  Flush(Output);
  
  try
    FLLMClient := TLLMClient.Create(FConfig, FFormat);
    InitializeTools;
    SetWorkingDirectory(FConfig.WorkingDirectory);
    SetLLMClient(FLLMClient);  { Register LLM client globally for Agent tool }
    InitContextCompression;  { Initialize context compression module }
    InitRequestOptimizer;  { Initialize request optimizer/caching }
    InitSessionMemory;  { Initialize session memory/extraction }
    WriteLn('Working directory: ', FConfig.WorkingDirectory);
    Flush(Output);
  except
    on E: Exception do
    begin
      WriteLn('Failed to create LLM client: ', E.Message);
      Flush(Output);
      SwitchToMainScreen;
      Exit;
    end;
  end;
  
  { Detect Git BEFORE creating system prompt }
  DetectGit;
  
  PrintWelcome;
  
  WriteLn('Getting system prompt...');
  Flush(Output);
  try
    WriteLn('Calling GetSystemPrompt...');
    Flush(Output);
    WriteLn('System prompt length: ', Length(GetSystemPrompt));
    Flush(Output);
    WriteLn('Adding system message...');
    Flush(Output);
    ChatHistory_AddMessage(Ord(ruSystem), 'You are a helpful assistant.');
    WriteLn('System message added');
  except
    on E: Exception do
    begin
      WriteLn('CRASH in AddMessage: ', E.Message);
      Flush(Output);
    end;
  end;

  WriteLn('Entering main loop...');
  Flush(Output);
  
  { Check if running in file mode }
  if FInputFile <> '' then
  begin
    { File mode - run prompts from file and exit }
    WriteLn('Running in file mode: ', FInputFile);
    Flush(Output);
    HandleRunFile(FInputFile);
    SwitchToMainScreen;
    Exit;
  end;
  
  { Print initial status bar }
  PrintStatusBar;
  
  while True do
  begin
    { Process queue first if available }
    if FQueueCount > 0 then
    begin
      WriteLn('');
      WriteLn('--- Processing queued input ---');
      Flush(Output);
      Input := DequeueInput;
    end
    else
    begin
      PrintPrompt;
      ReadLn(Input);
    end;
    
    try
      FIsProcessing := True;
      ProcessCommand(Input);
      Flush(Output);
    except
      on E: Exception do
      begin
        WriteLn('[Thinking Error]: ', E.Message);
        Flush(Output);
        FInRecovery := True;
        ChatHistory_Reset;
        ChatHistory_AddMessage(Ord(ruSystem), GetSystemPrompt);
      end;
    end;
    FIsProcessing := False;
    
    { Update and print status bar after each command }
    PrintStatusBar;
  end;
end;

end.