Unit uThreadIndiv;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

Type

  TThreadIndivState = (isIdle, isRunning);

  { TThreadIndivs }

  TThreadIndivs = Class(TThread)
  private
    FFirstindex, FLastIndex, fsimStep: Integer;
    fState: TThreadIndivState;
    fWorkingDelta, fWorkingStartTime: uint64;
  public
    Property GetWorkingDelta: uint64 read fWorkingDelta;
    Procedure ResetCounter();
    Procedure Execute(); override;
    Constructor Create(); reintroduce;
    Function IsStateIdle(): Boolean;
    Function StartWork(FirstIndex, LastIndex, simStep: integer): Boolean;
  End;

Implementation

Uses upeeps, uSimulator;

{ TThreadIndic }

Constructor TThreadIndivs.Create;
Begin
  Inherited Create(true);
  FreeOnTerminate := true;
  fState := isIdle;
  Start;
End;

Function TThreadIndivs.IsStateIdle: Boolean;
Begin
  result := fState = IsIdle;
End;

Function TThreadIndivs.StartWork(FirstIndex, LastIndex, simStep: integer
  ): Boolean;
Begin
  result := IsStateIdle();
  If Not Result Then exit;
  FFirstindex := FirstIndex;
  FLastIndex := LastIndex;
  fsimStep := simStep;
  fState := isRunning;
End;

Procedure TThreadIndivs.ResetCounter();
Begin
  fWorkingDelta := 0;
End;

Procedure TThreadIndivs.Execute;
Var
  indivIndex: Integer;
Begin
  While Not Terminated Do Begin
    Case fState Of
      isIdle: Begin
          sleep(1);
        End;
      isRunning: Begin
          fWorkingStartTime := GetTickCount64;
          // Mache die Arbeit
          For indivIndex := FFirstindex To FLastIndex Do Begin
            If (peeps[indivIndex]^.alive) Then Begin
              simStepOneIndiv(peeps[indivIndex], fsimStep);
            End;
          End;
          fWorkingDelta := fWorkingDelta + (GetTickCount64() - fWorkingStartTime);
          fState := isIdle; // Arbeit getan, dann wieder zurück in Idle
        End;
    End;
  End;
End;

End.

