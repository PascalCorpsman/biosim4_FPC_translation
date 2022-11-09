Program biosim;

{$MODE objfpc}{$H+}

Uses
{$IFDEF UNIX}
  cthreads,
{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Classes, SysUtils, uSimulator
  ;

Var
  Simulator: TSimulator;
  Crashed: Boolean;

Begin
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

  // TODO: Alles unterhalb "Löschen", nur zum Debuggen
//  writeln('');
//  writeln('Debugg, press return to close.');
//  readln();

End.

