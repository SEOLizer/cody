{
  Main program for the AI Assistant.
  
  Free Pascal implementation of a generic LLM CLI client.
  Supports Ollama, llama.cpp, and OpenAI-compatible APIs.
}
program agent;

{$mode objfpc}{$H+}

uses
  SysUtils, cli;

var
  App: TCLI;

begin
  App := TCLI.Create;
  try
    App.StartAgent;
  finally
    App.Free;
  end;
end.
