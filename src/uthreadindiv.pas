Unit uThreadIndiv;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

Type



  { TThreadIndic }

  TThreadIndic = Class(TThread)
  private
  public
    Procedure Execute(); override;
    Constructor Create(); reintroduce;
  End;

Implementation

{ TThreadIndic }

Constructor TThreadIndic.Create;
Begin
  Inherited Create(false);

End;

Procedure TThreadIndic.Execute;
Begin
  While Not Terminated Do Begin
    sleep(1);
  End;
End;

End.

