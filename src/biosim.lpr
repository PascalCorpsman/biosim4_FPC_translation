Program biosim;

{$MODE objfpc}{$H+}

Uses
{$IFDEF UNIX}
  cthreads,
  cmem, // Acording to https://wiki.freepascal.org/Parallel_procedures this also speeds up the execution
{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Classes, SysUtils, uSimulator, crt
  ;
(*
 * This .inc is not needed here, its only listed here to give easy and fast access to the configurable compiler switches.
 *)
{$I biosim_config.inc}

Var
  Simulator: TSimulator;
  Crashed: Boolean;

Begin
  (*
   * Known Bugs: - keine
   *
   *)
  Randomize;
  //  RandSeed := 42; // -- Zum Fehlersuchen
  Simulator := TSimulator.Create();
  Crashed := false;
  Try
    Try
      If ParamCount >= 1 Then Begin
        Simulator.Simulator(ParamStr(1));
      End
      Else Begin
        Simulator.Simulator('');
      End;
    Except
      On av: exception Do Begin
        Crashed := true;
        writeln('Simulator crashed: ' + av.Message);
      End;
    End;
  Finally
    If Crashed Then Begin
      Simulator.Crashed := true;
    End;
    Simulator.Free;
  End;
  Simulator := Nil;
  // Den Puffer "Leer" lesen, falls der user viel zu Oft ESC oder etwas anderes gedrückt hat ..
  While KeyPressed Do Begin
    ReadKey();
  End;

End.

