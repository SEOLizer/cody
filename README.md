# Free Pascal AI Agent

Ein AI-coding-Assistent in Free Pascal, der sich mit lokalen LLM-Servern (Ollama, LM Studio, llama.cpp, etc.) verbindet.

## Übersicht

Dieser Agent ist ein CLI-Tool, das Large Language Models für Code-Analyse, Review und Refactoring nutzt. Er verbindet sich mit jedem OpenAI-kompatiblen API-Server und bietet Tools für Dateiverwaltung, Code-Analyse und Aufgabenplanung.

## Funktionen

### 🎯 Kernfähigkeiten

| Fähigkeit | Beschreibung |
|-----------|--------------|
| **Code-Analyse** | Analysiert existierenden Code und identifiziert Issues, Patterns und Qualitätsprobleme |
| **Code-Review** | Bewertet Code auf Bugs, Sicherheitslücken, Performance-Probleme |
| **Refactoring** | Plant und implementiert Verbesserungen an existierendem Code |
| **Architektur** | Empfiehlt passende Patterns und Strukturen für Projekte |

### 🔧 Verfügbare Tools

| Tool | Beschreibung |
|------|---------------|
| **Bash** | Shell-Befehle ausführen (Tests, Builds, etc.) |
| **Read** | Dateiinhalte lesen |
| **Write** | Neue Dateien erstellen |
| **Edit** | Dateien via Find/Replace bearbeiten |
| **Diff** | Zwei Dateien vergleichen und Unterschiede anzeigen |
| **FileTree** | Verzeichnisbaum Struktur anzeigen |
| **Move** | Dateien/Verzeichnisse verschieben oder umbenennen |
| **Mkdir** | Neues Verzeichnis erstellen |
| **Delete** | Dateien/Verzeichnisse löschen |
| **Glob** | Dateien nach Pattern suchen |
| **Grep** | Inhalten in Dateien suchen |
| **TaskCreate** | Aufgabe in Task-Liste erstellen |
| **TaskList** | Alle Tasks auflisten |
| **TaskUpdate** | Task-Status aktualisieren |
| **Init** | PROJECT.md Dokumentation erstellen |
| **Agent** | Sub-Agent für komplexe Aufgaben |

### 🛡️ Sicherheit & Berechtigungen

| Feature | Beschreibung |
|---------|--------------|
| **Auto-Approve** | Lese-Tools (Read, Glob, Grep, FileTree, Diff, TaskList) werden automatisch erlaubt |
| **Permission Modes** | Drei Modi: Auto (Standard), Ask (Bestätigung für alles), Strict (nur Lesen) |
| **Command Sanitization** | Blockiert gefährliche Commands (rm -rf, Pipes zu Shell, etc.) |
| **Path Validation** | Nur Zugriff innerhalb des Working Directory erlaubt |

### 💾 Session & Memory

| Feature | Beschreibung |
|---------|--------------|
| **Working Memory** | Todo-Listen werden automatisch zwischen Sessions gespeichert/geladen |
| **Context-Kompression** | Verhindert Token-Limit-Fehler durch automatische Kontext-Zusammenfassung |
| **Reaktive Kompression** | Automatische Wiederherstellung bei 413-Fehlern |
| **Reasoning Chains** | Schritt-für-Schritt Ausführung mit Checkpoints für Rollback |
| **Error Recovery** | Automatische Wiederherstellung bei API-Fehlern |

### 🧠 Intelligente Verarbeitung

| Feature | Beschreibung |
|---------|--------------|
| **Stop Reasons** | Erkennt: end_turn (fertig), tool_use (Tool nötig), max_tokens (Limit erreicht) |
| **Response Types** | Kategorisiert: Text, Tool-Use, Thinking/Reasoning |
| **Thinking Mode** | Iterative Evaluation mit Selbstkorrektur |
| **Task Analysis** | Automatische Komplexitätserkennung (Simple/Moderate/Complex) |
| **Plan Verification** | Überprüfung der Aufgaben-Vervollständigung |
| **MAX_TOOL_CALLS Limit** | Verhindert endlose Tool-Schleifen (Standard: 15) |

### 🎮 Verfügbare Commands

- **Code-Qualitätsbewertung**: Erkennt Code-Smells wie:
  - Duplikate
  - Lange Funktionen
  - Enge Kopplung
  - Inkonsistente Namensgebung
  - "God Classes"

- **Sicherheitsanalyse**:
  - SQL Injection
  - XSS
  - Buffer Overflows
  - Hardcoded Secrets
  - Input-Validierung

- **SOLID Principles**: Bewertet Code nach:
  - Single Responsibility
  - Open/Closed
  - Liskov Substitution
  - Interface Segregation
  - Dependency Inversion

- **Architektur-Patterns**: Kennt und empfiehlt:
  - MVC / MVP / MVVM
  - Repository Pattern
  - Factory Pattern
  - Singleton
  - Clean Architecture
  - Dependency Injection

### 🎮 Verfügbare Commands

| Command | Beschreibung |
|---------|--------------|
| `/help` | Hilfe anzeigen |
| `/clear` | Chat-Verlauf löschen |
| `/save [file]` | Chat speichern |
| `/load [file]` | Chat laden |
| `/quit` | Beenden |
| `/think <prompt>` | Thinking-Mode aktivieren |
| `/no-think <prompt>` | Ohne Thinking-Mode |
| `/skills` | Skills verwalten |
| `/run <file>` | Prompts aus Datei ausführen |
| `/model` | Modell-Info anzeigen |
| `/url` | Server-URL anzeigen |

## Beispiel-Prompts

### Code-Analyse
```
Analyze the code in the src folder and identify any issues
```
```
What code quality issues can you find in this project?
```
```
Review the UserService class and suggest improvements
```

### Code-Review
```
Review this code for security vulnerabilities
```
```
Check this module for performance bottlenecks
```
```
What bugs might be in this function?
```

### Refactoring
```
Refactor the UserService class to follow SOLID principles
```
```
Simplify this complex function by extracting smaller helpers
```
```
Improve the naming in this file to be more descriptive
```

### Architektur
```
What architecture pattern would you recommend for this project?
```
```
Suggest how to improve the separation of concerns in this code
```
```
How can we make this code more testable?
```

### Projekterkundung
```
Find all TypeScript files in the src directory
```
```
Show me the structure of this project
```
```
What files are related to user authentication?
```

## Installation & Ausführung

### Kompilieren

```bash
cd agent
fpc -O2 -g -XX src/agent.lpr
```

### Ausführen

```bash
# Mit Ollama (Standard)
./src/agent -u http://localhost:11434 -m llama3

# Mit LM Studio oder OpenAI-kompatiblen Server
./src/agent -u http://localhost:8080/v1 -m llama3 --openai

# Mit API Key
./src/agent -u https://api.example.com/v1 -m gpt-4 -k YOUR_KEY

# Working Directory angeben
./src/agent -u http://localhost:11434 -m llama3 -w /path/to/project
```

### Parameter

| Parameter | Beschreibung | Standard |
|-----------|--------------|----------|
| `-u <url>` | API Base URL | http://localhost:11434 |
| `-m <model>` | Modellname | llama3 |
| `-k <key>` | API Key | (leer) |
| `-f <file>` | Prompts aus Datei ausführen (non-interaktiv) | - |
| `-w <dir>` | Working Directory | aktuelles Verzeichnis |
| `--openai` | OpenAI-Format verwenden | Ollama-Format |
| `--ollama` | Ollama-Format verwenden | Standard |
| `-h, --help` | Hilfe anzeigen | - |

### Eingabe-Modi

| Modus | Beschreibung |
|-------|--------------|
| **Interaktiv** | Direkte Eingabe im Terminal (Standard) |
| **Datei-basiert** | Prompts aus Datei mit `-f` Parameter |
| **Piped Input** | `echo "prompt" \| ./agent` oder `./agent < prompts.txt` |

## Dateistruktur

```
agent/
├── src/
│   ├── agent.lpr           # Main program
│   ├── cli.pas             # CLI Interface & System Prompt
│   ├── chathistory.pas     # Chat-Verwaltung (global)
│   ├── llmclient.pas       # LLM API Client (Ollama + OpenAI)
│   ├── httpclient.pas      # HTTP Client
│   ├── types.pas           # Type-Definitionen (inkl. StopReasons, ResponseTypes)
│   ├── tool_executor.pas   # Tool-Ausführung mit Permission-Checks
│   ├── tool_permissions.pas # Permission System (Auto/Ask/Strict)
│   ├── reasoning_chains.pas # Reasoning Chains & Checkpoints
│   ├── context_compression.pas # Context Kompression
│   ├── thinking_planning.pas # Task Analysis & Planning
│   ├── ui_helper.pas       # Terminal UI Hilfsfunktionen
│   ├── cursor_helper.pas   # Cursor Kontrolle
│   ├── working_memory.pas  # Todo-Listen Persistenz
│   ├── bash_tool.pas       # Bash Tool
│   ├── read_tool.pas       # Read Tool
│   ├── write_tool.pas      # Write Tool
│   ├── edit_tool.pas       # Edit Tool
│   ├── glob_tool.pas       # Glob Tool
│   ├── grep_tool.pas       # Grep Tool
│   ├── diff_tool.pas       # Diff Tool
│   ├── file_tree_tool.pas  # FileTree Tool
│   ├── move_tool.pas       # Move Tool
│   ├── mkdir_tool.pas      # Mkdir Tool
│   ├── delete_tool.pas     # Delete Tool
│   ├── task_create_tool.pas # TaskCreate Tool
│   ├── task_list_tool.pas  # TaskList Tool
│   ├── task_update_tool.pas # TaskUpdate Tool
│   ├── agent_tool.pas      # Sub-Agent Tool
│   ├── init_tool.pas       # Init Tool (PROJECT.md)
│   └── skills.pas          # Skills System
├── scripts/
│   └── http-post.sh        # HTTP Helper Script
└── README.md               # Diese Datei
```

## Unterstützte LLM-Server

| Server | Status | Format | Endpoint |
|--------|--------|--------|----------|
| **Ollama** | ✅ Standard | Ollama API | `/api/chat` |
| **LM Studio** | ✅ | OpenAI-kompatibel | `/v1/chat/completions` |
| **llama.cpp** | ✅ | OpenAI-kompatibel | `/v1/chat/completions` |
| **LocalAI** | ✅ | OpenAI-kompatibel | `/v1/chat/completions` |
| **vLLM** | ✅ | OpenAI-kompatibel | `/v1/chat/completions` |
| **OpenAI API** | ✅ | OpenAI | `/v1/chat/completions` |

### API Features

| Feature | Ollama | OpenAI-kompatibel |
|---------|--------|-------------------|
| **Tool Calls** | ✅ | ✅ |
| **Streaming** | ✅ (stream: false) | ✅ (stream: false) |
| **Temperature** | ✅ | ✅ |
| **Max Tokens** | ✅ | ✅ |
| **Tool-Call Parsing** | ✅ | ✅ |

### Beispiel-Server URLs

```bash
# Ollama (Standard)
./src/agent -u http://localhost:11434 -m llama3

# LM Studio
./src/agent -u http://localhost:1234/v1 -m llama3 --openai

# llama.cpp
./src/agent -u http://localhost:8080/v1 -m llama3 --openai

# OpenAI API
./src/agent -u https://api.openai.com/v1 -m gpt-4 -k sk-xxxxx --openai
```

## Thinking Mode

Der Agent verwendet standardmäßig den "Thinking Mode" mit Evaluations-Loop:

1. User-Input empfangen
2. Task-Komplexität analysieren (Simple/Moderate/Complex)
3. LLM mit Tools aufrufen
4. Checkpoint vor Tool-Ausführung erstellen
5. Tool ausführen
6. **Ergebnis evaluieren**: War es erfolgreich? Gab es Fehler?
7. Bei Fehlern: Rollback zum letzten Checkpoint und alternative Ansätze versuchen
8. Schritt-Zusammenfassung anzeigen
9. Weiter bis keine Tools mehr benötigt werden

### Reasoning Chains

Jede Tool-Ausführung wird in einer Reasoning Chain verfolgt:

- **State Tracking**: Planning → Executing → Evaluating → Completed/Failed
- **Checkpoints**: Vor jedem Schritt wird ein Checkpoint erstellt
- **Rollback**: Bei Fehlern kann zum letzten Checkpoint zurückgerollt werden
- **Step Summary**: Nach Abschluss wird eine Zusammenfassung aller Schritte angezeigt

Dies ermöglicht dem Agenten, autonom zu arbeiten und seine Aktionen kritisch zu bewerten.

## PROJEKT.md

Der Agent kann eine `PROJECT.md` Datei erstellen, die das Projekt dokumentiert:

```
/init
```

Oder mit benutzerdefiniertem Inhalt:

```
/init Hier steht die vollständige Projektdokumentation...
```

## Tipps

1. **Für Analysen**: Gib dem Agenten einen klaren Fokus ("analysiere nur die Authentifizierung")
2. **Für Refactoring**: Bitte um einen Plan bevor Änderungen gemacht werden
3. **Für Reviews**: Specifiziere die Art des Reviews (Sicherheit, Performance, Style)
4. **Für große Projekte**: Verwende Tasks um den Fortschritt zu verfolgen

## Lizenz

MIT License