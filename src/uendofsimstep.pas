Unit uEndOfSimStep;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, urandom, uindiv;

{$I c_types.inc}

Procedure endOfSimStep(Const randomUint: RandomUintGenerator; simStep, generation: unsigned);

Implementation

Uses uparams, uSimulator, uImageWriter, ubasicTypes;

(*
At the end of each sim step, this function is called in single-thread
mode to take care of several things:

1. We may kill off some agents if a "radioactive" scenario is in progress.
2. We may flag some agents as meeting some challenge criteria, if such
   a scenario is in progress.
3. We then drain the deferred death queue.
4. We then drain the deferred movement queue.
5. We fade the signal layer(s) (pheromones).
6. We save the resulting world condition as a single image frame (if
   p.saveVideo is true).
*)

Procedure endOfSimStep(Const randomUint: RandomUintGenerator; simStep, generation: unsigned);
Const
  radius = 9.0;
Var
  radioactiveX: int16_t;
  indiv: PIndiv;
  n, distanceFromRadioactiveWall, index: integer;
  chanceOfDeath: Float;
  BarierCenters: TCoordArray;
  bit: uint32_t;
Begin
  If (p.challenge = CHALLENGE_RADIOACTIVE_WALLS) Then Begin
    // During the first half of the generation, the west wall is radioactive,
    // where X == 0. In the last half of the generation, the east wall is
    // radioactive, where X = the area width - 1. There's an exponential
    // falloff of the danger, falling off to zero at the arena half line.
    If (simStep < p.stepsPerGeneration / 2) Then
      radioactiveX := 0
    Else
      radioactiveX := p.sizeX - 1;

    For index := 1 To p.population Do Begin // index 0 is reserved
      indiv := peeps.Individual[index];
      If (indiv^.alive) Then Begin
        distanceFromRadioactiveWall := abs(indiv^.loc.x - radioactiveX);
        If (distanceFromRadioactiveWall < p.sizeX / 2) Then Begin
          If distanceFromRadioactiveWall = 0 Then Begin // Das Objekt berührt die Radioaktive Wand -> instant death
            peeps.queueForDeath(indiv);
          End
          Else Begin
            chanceOfDeath := 1.0 / distanceFromRadioactiveWall;
            If ((randomUint.Rnd() / RANDOM_UINT_MAX) < chanceOfDeath) Then Begin
              peeps.queueForDeath(indiv);
            End;
          End;
        End;
      End;
    End;
  End;

  // If the individual is touching any wall, we set its challengeFlag to true.
  // At the end of the generation, all those with the flag true will reproduce.
  If (p.challenge = CHALLENGE_TOUCH_ANY_WALL) Then Begin
    For index := 1 To p.population Do Begin // index 0 is reserved
      indiv := peeps.Individual[index];
      If (indiv^.loc.x = 0) Or (indiv^.loc.x = p.sizeX - 1)
        Or (indiv^.loc.y = 0) Or (indiv^.loc.y = p.sizeY - 1) Then Begin
        indiv^.challengeBits := ord(true);
      End;
    End;
  End;

  // If this challenge is enabled, the individual gets a bit set in their challengeBits
  // member if they are within a specified radius of a barrier center. They have to
  // visit the barriers in sequential order.
  If (p.challenge = CHALLENGE_LOCATION_SEQUENCE) Then Begin
    For index := 1 To p.population Do Begin // index 0 is reserved
      indiv := peeps.Individual[index];
      BarierCenters := grid.getBarrierCenters();
      For n := 0 To high(BarierCenters) Do Begin
        bit := 1 Shl n;
        If ((indiv^.challengeBits And bit) = 0) Then Begin
          If ((indiv^.loc - BarierCenters[n]).length() <= radius) Then Begin
            indiv^.challengeBits := indiv^.challengeBits Or bit;
          End;
          break;
        End;
      End;
    End;
  End;

  peeps.drainDeathQueue();
  peeps.drainMoveQueue();
  signals.fade(0); // takes layerNum  todo!!!

  If ((p.saveVideo And
    (((generation Mod p.videoStride) = 0)
    Or (generation <= p.videoSaveFirstFrames)
    Or ((generation >= p.parameterChangeGenerationNumber) And (generation <= p.parameterChangeGenerationNumber + p.videoSaveFirstFrames))
    Or (generation = p.maxGenerations - 1) // Shure save the last simulated generation ;)
    ))) Or AdditionalVideoFrame Then Begin
    // Die Auswertung ist Quatsch weil der Thread immer annimt.
    If (Not imageWriter.saveVideoFrameSync(simStep, generation, p.challenge)) Then
      writeln('imageWriter busy');
  End;
End;

End.

