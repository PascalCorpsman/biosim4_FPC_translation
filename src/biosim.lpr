Program biosim;

{$MODE objfpc}{$H+}

Uses
{$IFDEF UNIX}
  cthreads,
  cmem, // Akkording to https://wiki.freepascal.org/Parallel_procedures this also speeds up the execution
{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Classes, SysUtils, uSimulator, crt
  ;

Var
  Simulator: TSimulator;
  Crashed: Boolean;

Begin
  (*
   * Known Bugs: - keine
   *
   *)

// Gesehen bis 34:14
// Challange 13 Im Video 30:28
//   https://www.youtube.com/watch?v=N3tRFayqVtk&t=1s

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

