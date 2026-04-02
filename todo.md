# TODO: Free Pascal Agent - Offene Aufgaben

Dieses Dokument listet alle noch offenen Funktionen auf, die implementiert werden müssen.

---

## 🔴 Hoch Priorität

### Streaming Response Handling
- [ ] SSE (Server-Sent Events) Support für Streaming
- [ ] Echtzeit-Verarbeitung von Antwort-Blöcken
- [ ] Streaming im LLM Client aktivieren

### Config-Datei ✅ (2026-04-01 implementiert)
- [x] JSON-Config-Datei (~/.agent/config.json)
- [x] Persistente Einstellungen (Model, URL, Temperature, MaxTokens)
- [x] Config-Editor via /config Command
- [x] Automatisches Laden beim Start
- [x] Command Line Args überschreiben Config

---

## 🟠 Mittel Priorität

### Session Memory
- [ ] Hintergrund-Speicher-Extraktion
- [ ] Token-Schwellenwert oder Tool-Call-Anzahl erkennen
- [ ] Key-Informationen extrahieren
- [ ] Markdown-Datei mit Notizen pflegen

### MCP Integration (Model Context Protocol)
- [ ] MCP Server Verbindungen
- [ ] MCP Tools registrieren
- [ ] MCP Resources lesen

### Erweiterte Tools
- [ ] Edit mit Regex und Zeilennummern
- [ ] Bash mit Git-Tools, Docker, etc.
- [ ] AskUserQuestion - Interaktive Benutzerabfragen
- [ ] REPL - Read-Eval-Print Loop
- [ ] LSP - Language Server Protocol Integration

### Git Integration
- [ ] /commit - Commit erstellen
- [ ] /branch - Branch Management
- [ ] /pr - Pull Request erstellen
- [ ] /diff - Erweiterte Diff-Anzeige

### Persistenter Chat-Verlauf
- [ ] History speichern/laden zwischen Sessions
- [ ] Session Management (/session Command)
- [ ] /resume - Letzte Session fortsetzen

---

## 🟢 Niedrig Priorität

### AppState Management
- [ ] Zentraler State Store
- [ ] Immutable Updates
- [ ] Selektive Propagation zu Subagents

### Query Tracking
- [ ] Chain-ID System für Query-Session
- [ ] Nesting-Tiefe (0 = Haupt, 1+ = Subagent)

### Parallele Verarbeitung
- [ ] Read-only Tools parallel (bis zu 10 gleichzeitig)
- [ ] StreamingToolExecutor für Parallelität
- [ ] Request Batching

### Erweiterte Fehlerbehandlung
- [ ] Model Fallback bei hoher Last
- [ ] HTTP-Fehler Recovery (400, 413, 429, 500)
- [ ] Letzte erfolgreiche Position merken

### Plugins System
- [ ] Plugin Manager
- [ ] Plugin Loader
- [ ] Custom Commands via Plugins

### Sicherheit
- [ ] OAuth Support
- [ ] Rate-Limiting
- [ ] JSON-Mode für strukturierte Antworten

### Monitoring & Debugging
- [ ] Verbose Mode
- [ ] Token-Counter
- [ ] Performance-Metrics
- [ ] Logging System

### Remote Features
- [ ] Remote Agents
- [ ] Team Management
- [ ] Voice Input/Output

### Erweiterte Task-Verwaltung
- [ ] TaskGet - Task Details anzeigen
- [ ] TaskOutput - Task-Ergebnisse anzeigen
- [ ] TaskStop - Task abbrechen
- [ ] TodoWrite - Todo-Liste schreiben

### Weitere Commands aus Original
- [ ] /compact - Context komprimieren
- [ ] /doctor - System-Check
- [ ] /export - Chat exportieren
- [ ] /cost - Kosten anzeigen
- [ ] /stats - Erweiterte Statistiken
- [ ] /model - Model wechseln
- [ ] /permissions - Berechtigungen verwalten
- [ ] /plan - Planungsmodus
- [ ] /theme - Theme wechseln
- [ ] /keybindings - Tastenkürzel anzeigen

---

## Erledigt (bereits in README.md dokumentiert)

### Kern-Funktionen ✅
- CLI Interface mit Commands (/help, /clear, /save, /load, /quit, etc.)
- Tool System (Bash, Read, Write, Edit, Glob, Grep, etc.)
- Tool Permission System
- Tool Validation & Orchestration
- Sub-Agent System (Task Tool, Fork)
- CLAUDE.md Integration
- Context Kompression (Auto/Micro/Reactive)
- Reasoning Chains
- Thinking Mode
- Request Caching
- Error Handling & Retry

### Tools ✅
- Bash, Read, Write, Edit, Diff, FileTree, Move, Mkdir, Delete
- Glob, Grep, LS, WebFetch, WebSearch
- TaskCreate, TaskList, TaskUpdate
- Agent, Init, Fork

### LLM Integration ✅
- Ollama API Support
- OpenAI-kompatible APIs
- Tool-Call Parsing
- Stop Reasons
- Response Types
