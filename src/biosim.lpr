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

Begin

  //Video ca. bei 14:00 bis 15:00 die auswertung !

  Randomize;
  //  RandSeed := 42; // -- Zum Fehlersuchen
  Simulator := TSimulator.Create();
  Try
    Try
      If ParamCount >= 1 Then Begin
        Simulator.Simulator(ParamStr(1));
      End
      Else Begin
        Simulator.Simulator('biosim4.ini');
      End;
    Except
      On av: exception Do Begin
        writeln('Simulator crashed: ' + av.Message);
      End;
    End;
  Finally
    Simulator.Free;
  End;
  Simulator := Nil;

  // TODO: Alles unterhalb "Löschen", nur zum Debuggen
//  writeln('');
//  writeln('Debugg, press return to close.');
//  readln();

End.

