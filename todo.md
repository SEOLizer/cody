# TODO: Free Pascal Agent - Claude Code Feature Implementation

Dieses Dokument listet alle Funktionen, die implementiert werden müssen, um einen vollständig funktionierenden Agenten zu haben, der mit einem lokalen LLM komplexe Aufgaben bearbeiten kann.

---

## Phase 1: Kern-Infrastruktur (Foundation)

### 1.1 Erweiterte Nachrichtenverwaltung
- [x] **Message History Management** (2026-04-01 implementiert)
  - [x] Speichern/Laden von Konversationen (session persistence)
  - [x] Context-Kompression bei Überschreitung der Token-Limit
  - [x] Mikrofokus-Kompression für Tool-Ergebnisse
  - [x] Reaktive Komprimierung bei API-Fehlern

- [x] **Three-Layer Memory System** (2026-04-01 implementiert)
  - [x] CLAUDE.md Unterstützung (Projekt-Memory)
    - [x] Lesen von ~/.claude/CLAUDE.md
    - [x] Lesen von ./CLAUDE.md im Projektverzeichnis
  - [ ] Session Memory (Hintergrund-Agent für Informations-Extraktion)
  - [x] Todo-Listen als Working Memory
    - [x] Working Memory Modul implementiert (working_memory.pas)
    - [x] Speichern/Laden von Todo-Listen zwischen Sessions

### 1.2 LLM Client Erweiterungen
- [ ] **Streaming Response Handling**
  - [ ] SSE (Server-Sent Events) Support für Streaming
  - [ ] Echtzeit-Verarbeitung von Antwort-Blöcken

- [x] **Response Types**
  - [x] Text-Response Verarbeitung (TResponseType: rtText)
  - [x] Tool-Use Block Erkennung (TResponseType: rtToolCall)
  - [x] Thinking/Reasoning Verarbeitung (TResponseType: rtThinking)
  - [x] Tool-Result Rückführung (via ChatHistory)

- [x] **Stop Reasons**
  - [x] end_turn: Task abgeschlossen (srEndTurn)
  - [x] tool_use: Mehr Arbeit nötig (srToolUse)
  - [x] max_tokens: Output-Limit erreicht (srMaxTokens)
  - [x] Fehlerbehandlung bei jedem Stop-Grund (CLI output)

---

## Phase 2: Tool-System (Tools)

### 2.1 Bestehende Tools (bereits implementiert)
- [x] Bash - Shell-Befehle ausführen
- [x] Read - Dateien lesen
- [x] Write - Dateien schreiben
- [x] Edit - Dateien bearbeiten
- [x] Diff - Dateien vergleichen (2024-04-01 hinzugefügt)
- [x] FileTree - Verzeichnisbaum anzeigen (2024-04-01 hinzugefügt)
- [x] Move - Dateien verschieben/umbenennen (2024-04-01 hinzugefügt)
- [x] Mkdir - Verzeichnisse erstellen (2024-04-01 hinzugefügt)
- [x] Delete - Dateien/Verzeichnisse löschen (2024-04-01 hinzugefügt)
- [x] Glob - Dateien nach Pattern suchen
- [x] Grep - Inhalten in Dateien suchen
- [x] TaskCreate - Aufgaben erstellen
- [x] TaskList - Aufgaben auflisten
- [x] TaskUpdate - Aufgaben aktualisieren

### 2.2 Erweiterte Tool-Features

- [x] **Tool Permission System**
  - [x] Auto-genehmigte Tools (Read, Glob, Grep, FileTree, Diff, TaskList)
  - [x] Schreib-Operationen mit Bestätigung (permission modes: Auto/Ask/Strict)
  - [x] Command Sanitization (backticks, $() entfernen, dangerous patterns)

- [x] **Tool Orchestration**
  - [x] Parallele Ausführung von Read-only Tools (TExecutionMode: emParallel)
  - [x] Serielle Ausführung von Schreib-Operationen (TExecutionMode: emSerial)
  - [x] Batch-Tool für mehrere Reads (OrchestrateTools)

- [x] **Tool Validation**
  - [x] Input-Validierung mit Required Fields (ValidateToolInput)
  - [x] Pre-Tool Hooks (PreToolHook - validation + permissions)
  - [x] Post-Tool Hooks (PostToolHook - statistics tracking)

### 2.3 Fehlende Tools (implementieren)
- [x] **LS** - Verzeichnisinhalt auflisten
- [x] **WebFetch** - Web-Inhalte abrufen
- [x] **WebSearch** - Web-Suche durchführen
- [ ] **Edit** - Erweitern mit mehr Optionen (regex, line numbers)
- [ ] **Bash** - Erweitern mit git-tools, docker, etc.

---

## Phase 3: Sub-Agents und Parallelität (Advanced)

### 3.1 Sub-Agent System
- [x] **Task Tool (Sub-Agent)**
  - [x] Erstelle Sub-Agent mit sauberem Slate
  - [x] Begrenzte Konversationstiefe (eine Ebene)
  - [x] Summary-Rückgabe an Haupt-Agent
  - [x] Integrierte Typen: Explore, Plan, Custom

- [x] **Fork Subagents**
  - [x] Hintergrundausführung
  - [x] Voller Parent-Kontext vererbt
  - [x] Asynchrone Ausführung
  - [x] Rekursions-Schutz

### 3.2 Parallele Verarbeitung
- [ ] **Concurrent Tool Execution**
  - [ ] Read-only Tools parallel (bis zu 10 gleichzeitig)
  - [ ] Write Operations seriell
  - [ ] StreamingToolExecutor für Parallelität

- [ ] **Request Batching**
  - [ ] Mehrere Reads in einem API-Call bündeln
  - [ ] Batch-Response Parsing

---

## Phase 4: Context Management (Memory)

### 4.1 Context-Kompression
- [ ] **Auto-Compact**
  - [ ] Token-Schwellenwert erkennen (~92% Kapazität)
  - [ ] Konversation zusammenfassen
  - [ ] Task-Ziel, Entscheidungen, geänderte Dateien behalten
  - [ ] Frühe Details können verloren gehen

- [ ] **Microcompact**
  - [ ] Pro-Tool-Result Caching
  - [ ] Cache-Invalidierung bei großen Ergebnissen

- [x] **Reactive Compact**
  - [x] Notfall-Wiederherstellung bei 413-Fehlern (2026-04-01 implementiert)
  - [x] Vollständige Neuzusammenfassung (context_compression.pas)

### 4.2 Session Memory
- [ ] **Hintergrund-Speicher-Extraktion**
  - [ ] Token-Schwellenwert oder Tool-Call-Anzahl erkennen
  - [ ] Key-Informationen extrahieren
  - [ ] Markdown-Datei mit Notizen pflegen

### 4.3 Project Memory (CLAUDE.md)
- [x] **Multi-Source Reading**
  - [x] ~/.claude/CLAUDE.md (global)
  - [x] ./CLAUDE.md (Projekt-Wurzel)
  - [x] ./CLAUDE.md in Unterverzeichnissen
- [x] **Injection in System Prompt**
  - [x] Jede Anfrage injizieren
  - [x] Durch Komprimierung überleben

---

## Phase 5: Zustandsverwaltung (State)

### 5.1 AppState Management
- [ ] **State Structure**
  - [ ] Tasks: Hintergrund-Aufgaben
  - [ ] MCP: MCP-Server-Verbindungen
  - [ ] Plugins: Aktivierte/Deaktivierte Plugins
  - [ ] Settings: Benutzer-Konfiguration
  - [ ] ToolPermissionContext: Permission-Modus und Regeln

- [ ] **State Updates**
  - [ ] Immutable Updates
  - [ ] Selektive Propagation zu Subagents

### 5.2 Query Tracking
- [ ] **Chain-ID System**
  - [ ] Eindeutige ID für gesamte Query-Session
  - [ ] Nesting-Tiefe (0 = Haupt, 1+ = Subagent)

---

## Phase 6: Fehlerbehandlung und Wiederherstellung (Error Recovery)

### 6.1 API-Fehler
- [ ] **Model Fallback**
  - [ ] Auf Fallback-Modell wechseln bei hoher Last
  - [ ] Max-Output-Token Wiederherstellung (8k → 64k)

- [x] **Reaktive Komprimierung**
  - [x] Vollständige Neuzusammenfassung bei "prompt too long" (2026-04-01 implementiert)
  - [x] Context-Collapse-Drain: Staged Collapses freigeben vor Retry

### 6.2 Tool-Ausführungsfehler
- [ ] **Tool Error Handling**
  - [ ] Syntax-Fehler erkennen
  - [ ] Berechtigungs-Fehler
  - [ ] Datei-nicht-gefunden-Fehler
  - [ ] Zeitüberschreitungs-Fehler

- [ ] **Retry-Logik**
  - [ ] Automatische Wiederholung bei transienten Fehlern
  - [ ] Max-Retries konfigurierbar

### 6.3 Session-Wiederherstellung
- [ ] **Fehlerzustand erkennen**
  - [ ] HTTP-Fehler (400, 413, 429, 500)
  - [ ] Zeitüberschreitung
  - [ ] Leere Antworten

- [ ] **Wiederherstellungs-Strategien**
  - [ ] Chat-History zurücksetzen
  - [ ] Mit neuem Context neu starten
  - [ ] Letzte erfolgreiche Position merken

---

## Phase 7: Planung und Denken (Thinking)

### 7.1 Autonomous Planning
- [x] **Task Creation**
  - [x] Automatische Todo-Erstellung für komplexe Aufgaben (3+ Schritte) (2026-04-01 implementiert)
  - [x] TaskUpdate für Status (in_progress/completed)
  - [x] TaskList für Fortschrittsprüfung

- [x] **Thinking Mode**
  - [x] Mehrfache LLM-Iterationen mit Zwischenergebnissen (2026-04-01 implementiert)
  - [x] Gedankenkette anzeigen
  - [x] Planungsverifikation

### 7.2 Reasoning Chains
- [x] **Step-by-Step Execution**
  - [x] Jeden Schritt planen bevor handeln (2026-04-01 implementiert)
  - [x] Zwischenzustände dokumentieren
  - [x] Bei Fehlern zurück zum letzten gültigen Zustand

---

## Phase 8: Integration und APIs

### 8.1 CLI Interface
- [x] **Befehlsverarbeitung** (2026-04-01 implementiert)
  - [x] /help, /clear, /save, /load, /quit
  - [x] /think für Thinking-Mode
  - [x] /model für Modell-Info
  - [x] /url für Server-Info
  - [x] /run <file> - Prompts aus Datei ausführen

- [x] **Eingabe-Modi** (2026-04-01 implementiert)
  - [x] Interaktiver Modus
  - [x] Nicht-interaktiver Modus ( piped input)
  - [x] Datei-basiertes Input mit -f Parameter

### 8.2 LM Studio / Ollama Integration
- [x] **Ollama API Format** (2026-04-01 implementiert)
  - [x] /api/chat Endpunkt
  - [x] Stream: false support
  - [x] Tool-Call parsing

- [x] **OpenAI-kompatibles Format** (2026-04-01 implementiert)
  - [x] /v1/chat/completions Endpunkt
  - [x] tools array im Request
  - [x] tool_calls in Response

### 8.3 Model Management
- [x] **Model-Konfiguration** (2026-04-01 implementiert)
  - [x] -m modelname
  - [x] -u baseurl
  - [x] -k apikey
  - [x] Temperature, MaxTokens

---

## Phase 9: Performance Optimierung

### 9.1 Request-Optimierung
- [ ] **Prompt Caching**
  - [ ] System-Prompt wird gecached vom API
  - [ ] Eigene Cache-Strategien

- [ ] **Response-Prediction**
  - [ ] Speculation für schnellere Responses
  - [ ] Pre-fetching von erwarteten Tools

### 9.2 Caching-Strategien
- [ ] **Tool-Result Caching**
  - [ ] SHA-hash basierend auf Tool-Input
  - [ ] TTL für verschiedene Tool-Typen
  - [ ] Cache-Invalidierung bei Änderungen

---

## Phase 10: Sicherheit und Berechtigungen

### 10.1 Permission Modes
- [ ] **Auto-Modus**
  - [ ] Read-Operationen automatisch erlauben
  - [ ] Schreib-Operationen bestätigen

- [ ] **Bash Permissions**
  - [ ] Gefährliche Commands blockieren
  - [ ] Regeln für Shell-Injection
  - [ ] Pfad-Validation

### 10.2 Input-Sanitization
- [ ] **Command Sanitization**
  - [ ] Backticks entfernen
  - [ ] $() entfernen
  - [ ] Environment-Variablen schützen

---

## Implementierungs-Reihenfolge

### Priority 1: Basis-Funktionalität
1. Erweiterte Message History (speichern/laden)
2. Context-Kompression (Token-Limit)
3. Bessere Fehlerbehandlung (Wiederherstellung)
4. [x] Todo-Listen als Working Memory (IMPLEMENTIERT)

### Priority 2: Tool-System
5. Tool Permission System
6. Parallele Tool-Ausführung
7. LS, WebFetch, WebSearch Tools

### Priority 3: Fortgeschritten
8. Sub-Agent System (Task Tool)
9. CLAUDE.md Integration
10. Session Memory

### Priority 4: Optimierung
11. Request-Optimierung
12. Performance-Metriken
13. Caching-Strategien

---

## Erfolgskriterien

Der Agent gilt als "vollständig funktionierend" wenn:

- [x] CLI startet ohne Fehler mit lokalem LLM
- [x] Einfache Prompts werden korrekt beantwortet
- [x] Tools werden korrekt ausgeführt (Read, Write, Edit, Glob, Grep, TaskCreate/List/Update)
- [x] Nach Tool-Ausführung wird die Konversation fortgesetzt (mit LM Studio Fix)
- [x] Context-Kompression verhindert Token-Limit-Fehler (implementiert)
- [x] Fehler werden erkannt und der Agent erholt sich (Recovery-Modus)
- [x] Todo-Listen funktionieren für komplexe Aufgaben
- [x] Mehrfache Prompts in einer Session funktionieren (mit MAX_TOOL_CALLS Limit)
- [x] Der Agent den Faden nicht verliert bei komplexen Aufgaben (Thinking Mode)
- [x] Unnötige Tool-Aufrufe werden durch verbesserten System-Prompt reduziert

---

## Offene Probleme

1. [x] **Tool Loop**: Der LLM ruft kontinuierlich Tools auf (besonders Grep) statt die gewünschte Aktion auszuführen
   - Gelöst durch MAX_TOOL_CALLS Limit (15) und verbesserten System-Prompt
2. **Piped Input**: Bei piped input gibt es Output-Probleme (vermutlich Pufferung)
3. **LM Studio Limitierung**: "Cannot put tools in the first user message" erfordert Workaround

---

## Nächste Schritte

1. **Tool-Call Validierung**: Nur erlauben wenn Input valide ist
2. **Max-Tool-Calls**: Limitieren wie oft ein Tool in einer Session aufgerufen werden kann
3. ** Bessere Prompt-Engineering**: System-Prompt verbessern um unnötige Tool-Aufrufe zu vermeiden

---

## Neue Erweiterungen (2024-04-01)

### 🚀 Neue Tools

| # | Feature | Beschreibung | Status | Priorität |
|---|---------|--------------|--------|-----------|
| 1 | **SearchWeb** | Websuche für aktuelle Informationen | [x] Implementiert (2026-04-01) | Mittel |
| 2 | **WebFetch** | URL-Inhalte abrufen | [x] Implementiert (2026-04-01) | Mittel |
| 3 | **FileTree** | Verzeichnisbaum anzeigen | [x] Implementiert (2024-04-01) | Niedrig |
| 4 | **Diff** | Dateien vergleichen | [x] Implementiert (2024-04-01) | Niedrig |
| 5 | **Move/Rename** | Dateien verschieben/umbenennen | [x] Implementiert (2024-04-01) | Niedrig |
| 6 | **Delete** | Dateien löschen | [x] Implementiert (2024-04-01) | Niedrig |
| 7 | **Mkdir** | Verzeichnisse erstellen | [x] Implementiert (2024-04-01) | Niedrig |
| 8 | **LS** | Verzeichnisinhalt auflisten | [x] Implementiert (2026-04-01) | Niedrig |

---

### 🔧 Funktionserweiterungen

| # | Feature | Beschreibung | Status | Priorität |
|---|---------|--------------|--------|-----------|
| 1 | **Streaming** | Stream LLM Responses für schnellere Ausgabe | [ ] Nicht umgesetzt | **Hoch** |
| 2 | **Konfiguration** | Config-Datei (JSON) statt nur CLI-Parameter | [ ] Nicht umgesetzt | Mittel |
| 3 | **History** | Persistenter Chat-Verlauf zwischen Sessions | [ ] Nicht umgesetzt | Mittel |
| 4 | **Multi-Agent** | Mehrere Sub-Agents gleichzeitig | [ ] Nicht umgesetzt | Niedrig |
| 5 | **Context Compression** | Automatische/reaktive Context-Komprimierung bei Token-Limit | [x] Implementiert (2026-04-01) | Mittel |
| 6 | **Thinking/Planning** | Automatische Aufgabenanalyse und Planungsverifikation | [x] Implementiert (2026-04-01) | Mittel |

---

### 🧠 Intelligence-Erweiterungen

| # | Feature | Beschreibung | Status | Priorität |
|---|---------|--------------|--------|-----------|
| 1 | **Code-Language Detection** | Automatische Erkennung der Programmiersprache | [ ] Nicht umgesetzt | Mittel |
| 2 | **Auto-Context** | Relevante Dateien automatisch laden basierend auf Task | [ ] Nicht umgesetzt | Mittel |
| 3 | **Session-Memory** | Zwischen Sessions lernen (ohne Datenbank) | [ ] Nicht umgesetzt | Niedrig |
| 4 | **Self-Correction** | Agent erkennt eigene Fehler und korrigiert | [ ] Nicht umgesetzt | Niedrig |

---

### 🔌 API-Erweiterungen

| # | Feature | Beschreibung | Status | Priorität |
|---|---------|--------------|--------|-----------|
| 1 | **Retry-Logic** | Automatische Wiederholung bei Netzwerkfehlern | [ ] Nicht umgesetzt | Mittel |
| 2 | **OAuth Support** | OAuth-Authentifizierung für APIs | [ ] Nicht umgesetzt | Niedrig |
| 3 | **Rate-Limiting** | Respektieren von API-Limits | [ ] Nicht umgesetzt | Niedrig |
| 4 | **JSON-Mode** | Force JSON Output für strukturierte Antworten | [ ] Nicht umgesetzt | Niedrig |

---

### 📊 Monitoring & Debugging

| # | Feature | Beschreibung | Status | Priorität |
|---|---------|--------------|--------|-----------|
| 1 | **Verbose Mode** | Detaillierte Debug-Ausgabe | [ ] Nicht umgesetzt | Niedrig |
| 2 | **Token-Counter** | Anzeige von Token-Verbrauch | [ ] Nicht umgesetzt | Niedrig |
| 3 | **Performance-Metrics** | Zeitmessung für Tool-Ausführungen | [ ] Nicht umgesetzt | Niedrig |
| 4 | **Logging** | Log-Datei für Fehleranalyse | [ ] Nicht umgesetzt | Niedrig |

---

## Zusammenfassung nach Priorität

### 🔴 Hoch Priorität
- Streaming - LLM Responses streamen für Echtzeit-Feedback

### 🟠 Mittel Priorität
- Konfiguration - Config-Datei (JSON)
- History - Persistenter Chat-Verlauf
- SearchWeb - Websuche
- WebFetch - URL-Inhalte abrufen
- Retry-Logic - Automatische Wiederholung
- Code-Language Detection - Spracherkennung
- Auto-Context - Automatisches Laden von relevanten Dateien

### 🟢 Niedrig
- FileTree, Diff, Move/Rename, Delete, Mkdir
- Multi-Agent, Tool-Chaining
- Session-Memory, Self-Correction
- OAuth, Rate-Limiting, JSON-Mode
- Verbose Mode, Token-Counter, Performance-Metrics, Logging