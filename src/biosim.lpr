Program biosim;

{$MODE objfpc}{$H+}

Uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Classes, SysUtils, uSimulator, crt
  ;

Var
  Simulator: TSimulator;
  Crashed: Boolean;

Begin
  (*
   * Known Bugs:
   *           - Wenn man zum ersten mal die Simulation Beendet und dann eine .sim Datei lädt, dann macht die Survivers Rate einen deutlichen Sprung nach unten, warum ?
   *             \-> Bei widerhohltem neustarten passiert das aber nicht 8-\
   *             \-> Das Problem tritt auch nicht immer auf, bei Challange 1 scheint das nicht der fall zu sein ...
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
  // Den Puffer "Leer" lesen, falls der user viel zu Oft ESC oder etwas gedrückt hat ..
  While KeyPressed Do Begin
    ReadKey();
  End;

  // TODO: Alles unterhalb "Löschen", nur zum Debuggen
//  writeln('');
//  writeln('Debugg, press return to close.');
//  readln();

End.

