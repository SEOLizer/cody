# Vergleich: Free Pascal Agent vs TypeScript Original (Claude Code)

## Übersicht

| Aspekt | Free Pascal Agent (agent/) | TypeScript Original (original/) |
|--------|---------------------------|--------------------------------|
| **Sprache** | Free Pascal | TypeScript/React |
| **Runtime** | Native Binary | Node.js/Bun |
| **Größe** | ~18 Dateien, ~3500 Zeilen | ~500+ Dateien, ~100k+ Zeilen |

---

## ✅ Implementierte Features (in beiden)

### Basis-Tools

| Tool | Free Pascal | TypeScript |
|------|-------------|------------|
| Bash | ✓ `bash_tool.pas` | ✓ `BashTool.tsx` |
| Read | ✓ `read_tool.pas` | ✓ `FileReadTool.tsx` |
| Write | ✓ `write_tool.pas` | ✓ `FileWriteTool.tsx` |
| Edit | ✓ `edit_tool.pas` | ✓ `FileEditTool.tsx` |
| Glob | ✓ `glob_tool.pas` | ✓ `GlobTool.ts` |
| Grep | ✓ `grep_tool.pas` | ✓ `GrepTool.ts` |

### Task-Tools

| Tool | Free Pascal | TypeScript |
|------|-------------|------------|
| TaskCreate | ✓ `task_create_tool.pas` | ✓ `TaskCreateTool.ts` |
| TaskList | ✓ `task_list_tool.pas` | ✓ `TaskListTool.ts` |
| TaskUpdate | ✓ `task_update_tool.pas` | ✓ `TaskUpdateTool.ts` |

### Basis-Funktionen

| Feature | Free Pascal | TypeScript |
|---------|-------------|------------|
| CLI Interface | ✓ `cli.pas` | ✓ `cli.tsx` |
| LLM Client | ✓ `llmclient.pas` | ✓ (API calls in query.ts) |
| HTTP Client | ✓ `httpclient.pas` | ✓ (fetch/axios) |
| Chat History | ✓ `chathistory.pas` | ✓ (in-memory) |
| Message Formatting | ✓ `chathistory.pas` | ✓ `prompts.ts` |
| System Prompt | ✓ `cli.pas` (GetSystemPrompt) | ✓ `prompts.ts` |
| Context-Kompression | ✓ `chathistory.pas` | ✓ (token tracking) |
| Error Handling | ✓ (try/except) | ✓ (try/catch) |
| Recovery Mode | ✓ `cli.pas` | ✓ (error recovery) |
| Input Queue | ✓ `cli.pas` | ✓ (async generator) |

---

## ❌ Fehlende Features (nur in TypeScript)

### Erweiterte Tools

| Tool | TypeScript | Beschreibung |
|------|------------|---------------|
| Agent Tool | ✓ `AgentTool.tsx` | Sub-Agenten spawnen mit eigenem Context |
| TaskStop Tool | ✓ `TaskStopTool.ts` | Laufende Tasks stoppen |
| WebFetch Tool | ✓ `WebFetchTool.ts` | Web-Inhalte abrufen |
| WebSearch Tool | ✓ `WebSearchTool.ts` | Web-Suche durchführen |
| LSP Tool | ✓ `LSPTool.ts` | Language Server Protocol |
| MCP Tool | ✓ `MCPTool.ts` | Model Context Protocol |
| Skill Tool | ✓ `SkillTool.ts` | Skills ausführen |
| Config Tool | ✓ `ConfigTool.ts` | Konfiguration ändern |
| REPL Tool | ✓ `REPLTool.ts` | Interaktive Konsole |
| ExitPlanMode | ✓ `ExitPlanModeTool.ts` | Plan-Modus beenden |
| EnterPlanMode | ✓ `EnterPlanModeTool.ts` | Plan-Modus starten |
| NotebookEdit | ✓ `NotebookEditTool.ts` | Jupyter Notebooks bearbeiten |
| ListMcpResources | ✓ `ListMcpResourcesTool.ts` | MCP Resources auflisten |
| ReadMcpResource | ✓ `ReadMcpResourceTool.ts` | MCP Resource lesen |

### State Management

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| AppState Store | ✓ `store.ts` | Zentraler State mit subscribers |
| AppState Type | ✓ `AppStateStore.ts` | Vollständiger App-State (Tasks, MCP, Plugins, Settings) |
| State Selectors | ✓ `selectors.ts` | Helper für State-Zugriff |
| State Change Handler | ✓ `onChangeAppState.ts` | Side-effects bei State-Änderungen |

### Task System

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| LocalShellTask | ✓ | Shell-Befehle als Hintergrund-Tasks |
| LocalAgentTask | ✓ | Sub-Agenten als Tasks |
| RemoteAgentTask | ✓ | Remote Agenten ausführen |
| DreamTask | ✓ | Hintergrund-Träume |
| Task Stop | ✓ | Tasks stoppen |

### Command System

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| Command Registry | ✓ `commands.ts` | Alle /-Commands registrieren |
| Slash Commands | ✓ | /help, /clear, /commit, etc. |
| Skills System | ✓ | Automatisierte Fähigkeiten |
| MCP Commands | ✓ | MCP-Server Commands |

### Context & Memory

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| User Context | ✓ `context.ts` | Git-Status, Dateien, etc. |
| System Context | ✓ `context.ts` | Projekt-Informationen |
| CLAUDE.md Support | ✓ `context.ts` | Projekt-Notes einlesen |
| Memory System | ✓ `memdir/` | Langzeit-Gedächtnis |
| Session Memory | ✓ | Kontext-Zusammenfassung |

### Security & Permissions

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| Tool Permissions | ✓ | Auto-genehmigte vs. bestätigte Tools |
| Path Validation | ✓ | Zugriff auf Verzeichnisse beschränken |
| Sandbox Support | ✓ | Sichere Shell-Ausführung |
| Destructive Warning | ✓ | Warnung bei gefährlichen Commands |
| ReadOnly Validation | ✓ | Nur-Lesen Modus |

### UI/Output

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| Markdown Rendering | ✓ | Formatted output |
| Progress UI | ✓ | Fortschrittsanzeige |
| Diff Rendering | ✓ | Änderungen anzeigen |
| Table Rendering | ✓ | Tabellen formatieren |
| Syntax Highlighting | ✓ | Code-Hervorhebung |

### Remote/Bridge

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| Remote Sessions | ✓ | Remote LLM Sessions |
| WebSocket Transport | ✓ | Echtzeit-Kommunikation |
| Direct Connect | ✓ | Direkte Verbindungen |
| Session Management | ✓ | Session-Verwaltung |

### Weitere Features

| Feature | TypeScript | Beschreibung |
|---------|------------|---------------|
| Streaming | ✓ | SSE für Echtzeit-Output |
| Tool Caching | ✓ | Tool-Results cachen |
| Token Budget | ✓ | Token-Limit Tracking |
| Compact/Context | ✓ | Automatische Kontext-Kompression |
| Hooks System | ✓ | Pre/Post execution hooks |
| Plugin System | ✓ | Erweiterungen |
| Config System | ✓ | Benutzer-Einstellungen |

---

## Was wir haben (Free Pascal Agent)

### Kern-System
```
agent/src/
├── cli.pas              - Haupt-Loop, Kommando-Verarbeitung
├── llmclient.pas       - LLM API Client
├── httpclient.pas       - HTTP Wrapper (curl)
├── chathistory.pas      - Nachrichten-History, Kompression
├── tool_executor.pas   - Tool-Ausführung Dispatcher
├── tool_registry.pas   - Tool-Registrierung
├── types.pas           - Type-Definitionen
│
├── bash_tool.pas       - Shell Commands
├── read_tool.pas       - Datei lesen
├── write_tool.pas      - Datei schreiben
├── edit_tool.pas       - Datei bearbeiten
├── glob_tool.pas       - Dateien suchen
├── grep_tool.pas       - Inhalt durchsuchen
│
├── task_create_tool.pas
├── task_list_tool.pas
├── task_update_tool.pas
└── tasks.pas           - Task Storage
```

### Features
- ✅ LLM-Verbindung zu LM Studio / Ollama / OpenAI-kompatibel
- ✅ 6 basis Tools + 3 Task Tools
- ✅ Piped input mit Flush-Output
- ✅ Context-Kompression
- ✅ Input Queue
- ✅ Recovery Mode
- ✅ System Prompt mit CLAUDE.md Support
- ✅ Max Tool Call Limit (15)
- ✅ Input Validation für Bash
- ✅ Working Directory Validation

---

## Was fehlt (Prioritäten)

### Höchste Priorität (MVP)

1. **Agent Tool (Sub-Agents)** - Der wichtigste fehlende Feature
   - Sub-Agenten mit eigenem Context spawnen
   - Built-in Agents: explore, plan, verify
   - Recursion-Schutz

2. **Session Memory / Context Compression**
   - Automatische Zusammenfassung bei Token-Limit
   - Token Budget Tracking

3. **Bessere Output-Formattierung**
   - Markdown Rendering
   - Diff-Anzeige

### Mittlere Priorität

4. **WebFetch / WebSearch** - Web-Zugriff
5. **Tool Caching** - Wiederholte Tool-Calls vermeiden
6. **Streaming** - Echtzeit-Output

### Niedrige Priorität

7. **MCP Support** - Model Context Protocol
8. **Plugin System** - Erweiterungen
9. **Remote Sessions** - Remote LLM
10. **LSP Tool** - Language Server Protocol
11. **Config System** - Benutzer-Einstellungen

---

## Fazit

Unser Free Pascal Agent ist ein **funktionierender MVP** mit den Kern-Features:
- CLI Interface
- LLM-Verbindung
- 9 Tools (6 Basis + 3 Task)
- Context-Management
- Error Recovery

Der TypeScript Original hat **~50+ zusätzliche Features**,主要集中在:
- Sub-Agent System
- Erweiterte Tools
- Bessere UI/Output
- State Management
- Remote Features

Um auf dasselbe Level zu kommen, wäre der nächste Schritt das **Agent Tool** (Sub-Agents) zu implementieren - das ist der größte_missing piece.