Unit uEndOfGeneration;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

Procedure endOfGeneration(generation: unsigned);

Implementation

Uses uparams, uSimulator, uImageWriter;

// At the end of each generation, we save a video file (if p.saveVideo is true) and
// print some genomic statistics to stdout (if p.updateGraphLog is true).

Procedure endOfGeneration(generation: unsigned);
Begin

  If (p.saveVideo And
    (((generation Mod p.videoStride) = 0)
    Or (generation <= p.videoSaveFirstFrames)
    Or ((generation >= p.parameterChangeGenerationNumber)
    And (generation <= p.parameterChangeGenerationNumber + p.videoSaveFirstFrames)))) Then Begin
    imageWriter.saveGenerationVideo(generation);
  End;
  If (p.updateGraphLog And ((generation = 1) Or ((generation Mod p.updateGraphLogStride) = 0))) Then Begin
    //#pragma GCC diagnostic ignored "-Wunused-result"
    // writeln(p.graphLogUpdateCommand); -- Das schreibt ja nur einen Text, mehr net, wo ist da die Aktion ?
  End;
End;

End.

