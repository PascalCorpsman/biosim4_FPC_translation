Unit uomp;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

Type
  (*
   * Liste aller Codestellen, welche eine Critical Section benötigen
   * Implementierung, siehe die bereits implementierten !
   *)
  TCodePoint = (
    cpSignals_increment,
    cpqueueForDeath,
    cpqueueForMove
    );

Function omp_get_thread_num(): integer; // wird in der Zufallszahlen generierung genutzt

(*
 * Alles was die Threads zum Synchronisieren brauchen
 *)
Procedure InitCriticalSections();
Procedure FreeCriticalSections();

Procedure EnterCodePoint(CP: TCodePoint);
Procedure LeaveCodePoint(CP: TCodePoint);

Implementation

Uses uparams;

Procedure NOP();
Begin

End;

Var
  CSs: Array[TCodePoint] Of TRTLCriticalSection;

Function omp_get_thread_num(): integer;
Begin
  result := p.numThreads;
End;

Procedure InitCriticalSections;
Var
  i: TCodePoint;
Begin
  For i := low(CSs) To high(CSs) Do Begin
    InitCriticalSection(CSs[i]);
  End;
End;

Procedure FreeCriticalSections;
Var
  i: TCodePoint;
Begin
  For i := low(CSs) To high(CSs) Do Begin
    DoneCriticalSection(CSs[i]);
  End;
End;

Procedure EnterCodePoint(CP: TCodePoint);
Begin
  EnterCriticalSection(CSs[cp]);
End;

Procedure LeaveCodePoint(CP: TCodePoint);
Begin
  LeaveCriticalSection(CSs[cp]);
End;

End.

