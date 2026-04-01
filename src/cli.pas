{
  Command Line Interface for the AI Assistant with Tool support.
}
unit cli;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, types, llmclient, chathistory, skills, bash_tool;

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
    const MAX_TOOL_CALLS = 15;
    procedure PrintWelcome;
    procedure PrintHelp;
    procedure PrintPrompt;
    procedure ProcessCommand(const Input: string);
    procedure HandleChat(const Input: string);
    procedure HandleChatWithThinking(const Input: string);
    procedure HandleToolCall(const ToolName: string; const ToolInput: string; const ToolID: string);
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
begin
  WriteLn('=================================================');
  WriteLn('  AI Assistant - Generic LLM CLI with Tools');
  WriteLn('=================================================');
  WriteLn('');
  WriteLn('Commands: /help, /clear, /save, /load, /quit, /think, /skills, /no-think');
  WriteLn('Default: All prompts use Thinking Mode with evaluation loop');
  WriteLn('Available Tools: Bash, Read, Write, Edit, Glob, Grep, TaskCreate, TaskList, TaskUpdate, Agent');
  WriteLn('');
  Flush(Output);
end;

procedure TCLI.PrintHelp;
begin
  WriteLn('Commands: /help, /clear, /save [f], /load [f], /quit, /model, /url, /no-think');
  WriteLn('Default: All prompts use Thinking Mode (evaluation loop)');
  WriteLn('Use /no-think for simple prompts without evaluation');
  WriteLn('Tools: Bash, Read, Write, Edit, Glob, Grep');
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
  SetLength(Tools, 11);
  
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
  
  Tools[4].Name := 'Glob';
  Tools[4].Description := 'Find files by pattern';
  Tools[4].Parameters := '{"type":"object","properties":{"pattern":{"type":"string"}},"required":["pattern"]}';
  
  Tools[5].Name := 'Grep';
  Tools[5].Description := 'Search content in files';
  Tools[5].Parameters := '{"type":"object","properties":{"pattern":{"type":"string"}},"required":["pattern"]}';
  
  // Task tools
  Tools[6].Name := 'TaskCreate';
  Tools[6].Description := 'Create a new task in the task list';
  Tools[6].Parameters := '{"type":"object","properties":{"subject":{"type":"string"},"description":{"type":"string"},"activeForm":{"type":"string"}},"required":["subject"]}';
  
  Tools[7].Name := 'TaskList';
  Tools[7].Description := 'List all tasks';
  Tools[7].Parameters := '{"type":"object","properties":{}}';
  
  Tools[8].Name := 'TaskUpdate';
  Tools[8].Description := 'Update task status and fields';
  Tools[8].Parameters := '{"type":"object","properties":{"id":{"type":"string"},"subject":{"type":"string"},"description":{"type":"string"},"status":{"type":"string"},"blockedBy":{"type":"string"},"blocks":{"type":"string"}},"required":["id"]}';
  
  // Agent tool
  Tools[9].Name := 'Agent';
  Tools[9].Description := 'Spawn a sub-agent to perform a complex multi-step task';
  Tools[9].Parameters := '{"type":"object","properties":{"description":{"type":"string"},"prompt":{"type":"string"},"subagent_type":{"type":"string"}},"required":["description","prompt"]}';
  
  // Init tool
  Tools[10].Name := 'Init';
  Tools[10].Description := 'Create or update PROJECT.md with project documentation';
  Tools[10].Parameters := '{"type":"object","properties":{"file_path":{"type":"string","description":"Optional: filename (default: PROJECT.md)"},"content":{"type":"string","description":"Optional: full markdown content. If empty, creates template"}},"required":[]}';
  
  FLLMClient.SetTools(Tools);
end;

procedure TCLI.HandleToolCall(const ToolName: string; const ToolInput: string; const ToolID: string);
var
  Result: TToolExecutionResult;
begin
  WriteLn('');
  Write('⚡ Executing ');
  Write(ToolName);
  WriteLn('...');
  Flush(Output);
    
  { Pass through the input as-is - the JSON parsing will handle it }
  Result := ExecuteToolByName(ToolName, ToolInput);
  
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
    WriteLn('');
    WriteLn('✗ [Error] ' + Result.ErrorMessage);
    WriteLn('');
    Flush(Output);
    ChatHistory_AddToolResultError(ToolID, Result.ErrorMessage);
  end;
end;

procedure TCLI.HandleChat(const Input: string);
var
  Messages: TMessageArray;
  Response: TLLMResponse;
begin
  { Reset tool call counter for new conversation }
  FToolCallCount := 0;
  
  { If in recovery mode, reset and start fresh }
  if FInRecovery then
  begin
    ChatHistory_Reset;
    ChatHistory_AddMessage(Ord(ruSystem), GetSystemPrompt);
    ChatHistory_AddMessage(Ord(ruUser), Input);
    FInRecovery := False;
  end
  else
  begin
    ChatHistory_AddMessage(Ord(ruUser), Input);
  end;
  
  { Use GetMessagesForLMStudio which handles LM Studio compatibility }
  Messages := ChatHistory_GetMessagesForLMStudio(True);
  
  Write('⋯ Calling LLM');
  WriteLn('...');
  Flush(Output);
  try
    Response := FLLMClient.Chat(Messages, True); { First call - WITH tools }
    
    { Loop through tool calls until no more or limit reached }
    while Response.HasToolCall and (FToolCallCount < MAX_TOOL_CALLS) do
    begin
      Inc(FToolCallCount);
      Write('[Tool Call: ');
      Write(Response.ToolCallName);
      WriteLn('] (', FToolCallCount, '/', MAX_TOOL_CALLS, ')');
      Flush(Output);
      ChatHistory_AddToolUse(Response.ToolCallName, Response.ToolCallID, Response.ToolCallInput);
      HandleToolCall(Response.ToolCallName, Response.ToolCallInput, Response.ToolCallID);
      
      WriteLn('→ Calling LLM again...');
      Flush(Output);
      Messages := ChatHistory_GetMessagesForLMStudio(False);
      { Second call - WITHOUT tools to avoid loop, LM Studio handles tool loop internally }
      Response := FLLMClient.Chat(Messages, False);
    end;
    
    { Check if we hit the limit }
    if FToolCallCount >= MAX_TOOL_CALLS then
    begin
      WriteLn('');
      WriteLn('⚠ Reached maximum tool call limit (', MAX_TOOL_CALLS, '). Ending tool loop.');
      WriteLn('');
      Flush(Output);
    end;
    
    WriteLn('');
    WriteLn(Response.Content);
    WriteLn('');
    WriteLn('');
    Flush(Output);
    
    { Only add non-empty assistant messages to history }
    if Response.Content <> '' then
      ChatHistory_AddMessage(Ord(ruAssistant), Response.Content);
  except
    on E: Exception do
    begin
      WriteLn('Error: ', E.Message);
      { Set recovery flag and clear history }
      FInRecovery := True;
      ChatHistory_Clear;
      ChatHistory_AddMessage(Ord(ruSystem), GetSystemPrompt);
    end;
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
begin
  MaxIterations := 20;
  Iterations := 0;
  FToolCallCount := 0;
  HasResult := False;
  
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
    
    { Display thinking }
    WriteLn(Response.Content);
    Flush(Output);
    
    { Add thinking to history }
    ChatHistory_AddMessage(Ord(ruAssistant), Response.Content);
    Inc(Iterations);
    
    { Main evaluation loop - continue until no more tool calls }
    while Response.HasToolCall and (Iterations < MaxIterations) and (FToolCallCount < MAX_TOOL_CALLS) do
    begin
      { Execute tool and track success }
      Inc(FToolCallCount);
      ToolExecutionSuccessful := True;
      
      WriteLn('');
      WriteLn('[Tool Call: ', Response.ToolCallName, '] (', FToolCallCount, '/', MAX_TOOL_CALLS, ')');
      Flush(Output);
      ChatHistory_AddToolUse(Response.ToolCallName, Response.ToolCallID, Response.ToolCallInput);
      
      { Execute the tool and capture result }
      HandleToolCall(Response.ToolCallName, Response.ToolCallInput, Response.ToolCallID);
      
      { Check if tool execution was successful }
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
      FInRecovery := True;
      ChatHistory_Reset;
      ChatHistory_AddMessage(Ord(ruSystem), GetSystemPrompt);
    end;
  end;
  
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
      HandleChat(SkillPrompt);
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
    { ChatHistory_LoadFromFile(Arg); }
    WriteLn('Loaded from: ', Arg);
    Flush(Output);
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
  else if (Cmd = '/no-think') then
  begin
    { Explicitly disable thinking mode for this input }
    if Arg <> '' then
      HandleChat(Arg)
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

function TCLI.ParseArgs: Boolean;
var
  i: Integer;
begin
  Result := False;
  
  FConfig.BaseURL := 'http://localhost:11434';
  FConfig.APIKey := '';
  FConfig.Model := 'llama3';
  FConfig.Temperature := 0.7;
  FConfig.MaxTokens := 2048;
  FConfig.WorkingDirectory := GetCurrentDir;
  FFormat := lfOllama;
  
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
    else if (ParamStr(i) = '--openai') or (ParamStr(i) = '--openAI') then
    begin
      FFormat := lfOpenAI;
    end
    else if (ParamStr(i) = '--help') or (ParamStr(i) = '-h') then
    begin
      WriteLn('Usage: agent [-u URL] [-m MODEL] [-k KEY] [-w DIR] [--openai|--ollama]');
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
    
  try
    FLLMClient := TLLMClient.Create(FConfig, FFormat);
    InitializeTools;
    SetWorkingDirectory(FConfig.WorkingDirectory);
    SetLLMClient(FLLMClient);  { Register LLM client globally for Agent tool }
    WriteLn('Working directory: ', FConfig.WorkingDirectory);
    Flush(Output);
  except
    on E: Exception do
    begin
      WriteLn('Failed to create LLM client: ', E.Message);
      Flush(Output);
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
  end;
end;

end.