Unit uomp;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

Function omp_get_thread_num(): integer;

Implementation

// TODO: das ganze Ding hier ist quatsch !

Function omp_get_thread_num(): integer;
Begin
  result := 0;
End;

End.

