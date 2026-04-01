{
  Tools initialization - wires up all tool executors.
}
unit tools_init;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, types, tool_registry, bash_tool, read_tool, write_tool, edit_tool, glob_tool, grep_tool;

procedure InitializeTools;

implementation

procedure InitializeTools;
begin
  { Register tool executors }
  { Note: We can't use the functions directly from other units in initialization
    because of unit dependency order. The actual execution is handled by the
    CLI which imports these tools directly. }
end;

end.