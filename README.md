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
| **Glob** | Dateien nach Pattern suchen |
| **Grep** | Inhalten in Dateien suchen |
| **TaskCreate** | Aufgabe in Task-Liste erstellen |
| **TaskList** | Alle Tasks auflisten |
| **TaskUpdate** | Task-Status aktualisieren |
| **Init** | PROJECT.md Dokumentation erstellen |

### 🧠 Intelligente Fähigkeiten

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
| `-w <dir>` | Working Directory | aktuelles Verzeichnis |
| `--openai` | OpenAI-Format verwenden | Ollama-Format |
| `--ollama` | Ollama-Format verwenden | Standard |
| `-h, --help` | Hilfe anzeigen | - |

## Dateistruktur

```
agent/
├── src/
│   ├── agent.lpr       # Main program
│   ├── cli.pas         # CLI Interface & System Prompt
│   ├── chathistory.pas # Chat-Verwaltung (global)
│   ├── llmclient.pas  # LLM API Client
│   ├── httpclient.pas # HTTP Client
│   ├── types.pas       # Type-Definitionen
│   ├── tool_executor.pas # Tool-Ausführung
│   ├── bash_tool.pas   # Bash Tool
│   ├── read_tool.pas   # Read Tool
│   ├── write_tool.pas  # Write Tool
│   ├── edit_tool.pas   # Edit Tool
│   ├── glob_tool.pas   # Glob Tool
│   ├── grep_tool.pas   # Grep Tool
│   ├── agent_tool.pas  # Sub-Agent Tool
│   ├── init_tool.pas   # Init Tool (PROJECT.md)
│   └── skills.pas      # Skills System
├── scripts/
│   └── http-post.sh    # HTTP Helper Script
└── README.md          # Diese Datei
```

## Unterstützte LLM-Server

- **Ollama** (Standard)
- **LM Studio**
- **llama.cpp**
- **OpenAI-kompatible APIs** (auch Remote-Server)
- **Any OpenAI-kompatibler Server** (z.B. localai, text-generation-webui)

## Thinking Mode

Der Agent verwendet standardmäßig den "Thinking Mode" mit Evaluations-Loop:

1. User-Input empfangen
2. LLM mit Tools aufrufen
3. Tool ausführen
4. **Ergebnis evaluieren**: War es erfolgreich? Gab es Fehler?
5. Bei Bedarf alternative Ansätze versuchen
6. Weiter bis keine Tools mehr benötigt werden

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