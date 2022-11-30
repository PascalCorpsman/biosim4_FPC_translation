Unit uEndOfGeneration;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

Procedure endOfGeneration(generation: unsigned);

Implementation

Uses uparams, uSimulator, uImageWriter, process, UTF8Process;

// At the end of each generation, we save a video file (if p.saveVideo is true) and
// print some genomic statistics to stdout (if p.updateGraphLog is true).

Procedure endOfGeneration(generation: unsigned);
Var
  pr: TProcessUTF8;
Begin
  If ((p.saveVideo And (
    ((generation Mod p.videoStride) = 0)
    Or (generation <= p.videoSaveFirstFrames)
    Or ((generation >= p.parameterChangeGenerationNumber) And (generation <= p.parameterChangeGenerationNumber + p.videoSaveFirstFrames))
    Or (generation = p.maxGenerations - 1) // Shure save the last simulated generation ;)
    ))) Or AdditionalVideoFrame Then Begin
    imageWriter.saveGenerationVideo(generation);
  End;
  If (p.updateGraphLog And ((generation = 1) Or ((generation Mod p.updateGraphLogStride) = 0))) Then Begin
    // TODO: Hier sauber aufspalten nach path, binary und params damit TProcess glücklich ist.

    // TODO: Das hier geht net unter Windows, ist der Command falsch oder woran liegt das ?

    If trim(p.graphLogUpdateCommand) <> '' Then Begin
      pr := TProcessUTF8.Create(Nil);
      pr.CommandLine := p.graphLogUpdateCommand;
      pr.Options := [poNoConsole];
      Try
        pr.Execute;
      Finally
        pr.Free;
      End;
    End;
  End;
End;

End.

