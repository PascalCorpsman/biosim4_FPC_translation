Unit uanalysis;

{$MODE ObjFPC}{$H+}
(*
 * This kills the warning in displaySignalUse, which only is due to the fact that
 * the killing feature is enabled, the orig C++ Source needed to be recompiled to
 * Disable killing neuron, the FPC version does not need that
 *)
{$WARN 6018 off : unreachable code}
Interface

Uses
  Classes, urandom, SysUtils, usignals, upeeps;

{$I c_types.inc}

Procedure displaySignalUse(Const signals: TSignals);
Procedure displaySampleGenomes(count: unsigned; Const Peeps: TPeeps);
Procedure appendEpochLog(Const randomUint: RandomUintGenerator; generation, numberSurvivors, murderCount: unsigned; aGeneticDiversity: Float; Const peeps: TPeeps);
Function geneticDiversity(Const randomUint: RandomUintGenerator): float;

Implementation

Uses
  math, uparams, ugenome, usensoractions, ubasicTypes, uindiv;

Function geneticDiversity(Const randomUint: RandomUintGenerator): float;
Var
  count: unsigned;
  numSamples: integer;
  similaritySum: Float;
  index0, index1: unsigned;
Begin
  If (p.population < 2) Then Begin
    result := 0.0;
    exit;
  End;

  // count limits the number of genomes sampled for performance reasons.
  count := min(1000, p.population);
  numSamples := 0;
  similaritySum := 0.0;

  While count > 0 Do Begin
    index0 := randomUint.RndRange(1, p.population - 1); // skip first and last elements
    index1 := index0 + 1;
    similaritySum := similaritySum + genomeSimilarity(peeps[index0]^.genome, peeps[index1]^.genome);
    count := Count - 1;
    numSamples := numSamples + 1;
  End;

  result := 1.0 - (similaritySum / numSamples);
End;

(*
Example format:

    ACTION_NAMEa from:
    ACTION_NAMEb from:
        SENSOR i
        SENSOR j
        NEURON n
        NEURON m
    Neuron x from:
        SENSOR i
        SENSOR j
        NEURON n
        NEURON m
    Neuron y ...
*)

Function averageGenomeLength(Const randomUint: RandomUintGenerator; Const peeps: TPeeps): Float;
Var
  count, numberSamples: unsigned;
  sum: uint32_t;
Begin
  count := 100;
  numberSamples := 0;
  sum := 0;
  While (count > 0) Do Begin
    sum := sum + length(peeps[randomUint.RndRange(1, p.population)]^.genome);
    numberSamples := numberSamples + 1;
    count := count - 1;
  End;
  result := sum / numberSamples;
End;

// The epoch log contains one line per generation in a format that can be
// fed to graphlog.gp to produce a chart of the simulation progress.

Procedure appendEpochLog(Const randomUint: RandomUintGenerator; generation, numberSurvivors, murderCount: unsigned; aGeneticDiversity: Float; Const peeps: TPeeps);
Var
  sl: TStringlist;
Begin
  sl := TStringList.Create;
  If (generation <> 0) Then Begin
    If FileExists(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt') Then // In case of a restart of a sim file without having any data, the file could be not existing.
      sl.LoadFromFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt');
  End
  Else Begin
    sl.clear;
    // Beschriftung der Spalten ;)
    sl.add('Generation;Number of survivors;genetic diversity;average genome length;murder count');
  End;
  FormatSettings.DecimalSeparator := '.';
  sl.add(inttostr(generation) + ';' + inttostr(numberSurvivors) + ';' + floattostr(aGeneticDiversity) + ';' + floattostr(averageGenomeLength(randomUint, peeps)) + ';' + inttostr(murderCount));
  If Not ForceDirectories(ExcludeTrailingPathDelimiter(p.logDir)) Then Begin
    sl.free;
    Raise exception.create('Error, unable to write into folder:' + p.logDir);
    exit;
  End;
  Try
    (*
     * If there is a Virus scanner on the computer, this scanner sometimes
     * blocks the writing of the epoch-log.txt as it is written really often.
     *
     * Instead of crashing and loosing all data the program waits 100ms and
     * then retries to save. If this also fail it will prompt the user for
     * a last try. If this also fails something "harder" to solve is happening
     * -> The program is going down and tries at least to create the .sim file.
     *)
    sl.SaveToFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt');
  Except
    On av: exception Do Begin
      writeln('Error could not store: epoch-log.txt');
      writeln('Reason: ' + av.Message);
      writeln('Will wait and retry in 100ms..');
      sleep(100);
      Try
        sl.SaveToFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt');
        writeln('retry suceed, continue as normal..');
      Except
        writeln('Second try also failed, simulation halted, press return for last retry.');
        readln();
        Try
          sl.SaveToFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt');
          writeln('Suceed, continue..');
        Except
          writeln('Failed again, trying to save what possible and going down.');
          // Das sollte ein SaveSim triggern..
          p.maxGenerations := generation + 1;
        End;
      End;
    End;
  End;
  sl.free;
End;

// Print stats about pheromone usage.

Procedure displaySignalUse(Const signals: TSignals);
Var
  sum: uint64;
  magnitude, count: unsigned;
  x, y: Integer;
Begin
  If (integer(SIGNAL0) > integer(NUM_SENSES)) And (integer(SIGNAL0_FWD) > integer(NUM_SENSES)) And (integer(SIGNAL0_LR) > integer(NUM_SENSES)) Then Begin
    exit;
  End;

  sum := 0;
  count := 0;

  For x := 0 To p.sizeX - 1 Do Begin
    For y := 0 To p.sizey - 1 Do Begin
      magnitude := signals.getMagnitude(0, coord(x, y));
      If (magnitude <> 0) Then Begin
        count := count + 1;
        sum := sum + magnitude;
      End;
    End;
  End;
  FormatSettings.DecimalSeparator := '.';
  writeln('Signal spread ' + format('%0.2f', [count / (p.sizeX * p.sizeY)]) + '%, average ' + format('%f', [sum / (p.sizeX * p.sizeY)]));
End;

// Print how many connections occur from each kind of sensor neuron and to
// each kind of action neuron over the entire population. This helps us to
// see which sensors and actions are most useful for survival.

Procedure displaySensorActionReferenceCounts(Const Peeps: TPeeps);
Type
  TindexPair = Record
    index, Value: integer;
  End;

  TIndexPairArray = Array Of TindexPair;

  Procedure Sort(Var Data: TIndexPairArray; li, re: integer);
  Var
    l, r, p: Integer;
    h: TindexPair;
  Begin
    If Li < Re Then Begin
      p := Data[Trunc((li + re) / 2)].Value; // Auslesen des Pivo Elementes
      l := Li;
      r := re;
      While l < r Do Begin
        While Data[l].Value > p Do
          inc(l);
        While Data[r].Value < p Do
          dec(r);
        If L <= R Then Begin
          h := Data[l];
          Data[l] := Data[r];
          Data[r] := h;
          inc(l);
          dec(r);
        End;
      End;
      Sort(Data, li, r);
      Sort(Data, l, re);
    End;
  End;

Var
  index, gene, i: Integer;
  Indiv: PIndiv;
  sensorCounts: TIndexPairArray;
  actionCounts: TIndexPairArray;
Begin
  sensorCounts := Nil;
  actionCounts := Nil;
  setlength(sensorCounts, integer(NUM_SENSES) + 1);
  setlength(actionCounts, integer(NUM_ACTIONS) + 1);
  For i := 0 To high(sensorCounts) Do Begin
    sensorCounts[i].index := i;
    sensorCounts[i].Value := 0;
  End;
  For i := 0 To high(actionCounts) Do Begin
    actionCounts[i].index := i;
    actionCounts[i].Value := 0;
  End;
  For index := 1 To p.population Do Begin
    If (peeps[index]^.alive) Then Begin
      indiv := peeps.Individual[index];
      For gene := 0 To high(indiv^.nnet.connections) Do Begin
        If (indiv^.nnet.connections[gene].sourceType = SENSOR) Then Begin
          assert(indiv^.nnet.connections[gene].sourceNum < integer(NUM_SENSES));
          sensorCounts[indiv^.nnet.connections[gene].sourceNum].Value := sensorCounts[indiv^.nnet.connections[gene].sourceNum].Value + 1;
        End;
        If (indiv^.nnet.connections[gene].sinkType = ACTION) Then Begin
          assert(indiv^.nnet.connections[gene].sinkNum < integer(NUM_ACTIONS));
          actionCounts[indiv^.nnet.connections[gene].sinkNum].Value := actionCounts[indiv^.nnet.connections[gene].sinkNum].Value + 1;
        End;
      End;
    End;
  End;
  // die Sensoren und Actions absteigend sortieren, so dass man immer gleich sehen kann welches die "Meist" genutzten sine !
  Sort(sensorCounts, 0, high(sensorCounts));
  Sort(actionCounts, 0, high(actionCounts));
  writeln('Sensors in use:');
  For i := 0 To length(sensorCounts) - 1 Do Begin
    If (sensorCounts[i].Value > 0) Then Begin
      writeln('  ' + inttostr(sensorCounts[i].Value) + ' - ' + sensorName(TSensor(sensorCounts[i].index)));
    End;
  End;
  writeln('Actions in use:');
  For i := 0 To high(actionCounts) Do Begin
    If (actionCounts[i].Value > 0) Then Begin
      writeln('  ' + inttostr(actionCounts[i].Value) + ' - ' + actionName(TAction(actionCounts[i].index)));
    End;
  End;
End;

Procedure displaySampleGenomes(count: unsigned; Const Peeps: TPeeps);
Var
  index: unsigned;
Begin
  For index := 1 To p.population Do Begin // indexes start at 1
    If (peeps[index]^.alive) Then Begin
      Writeln('---------------------------');
      writeln('Individual ID ' + inttostr(index));
      peeps[index]^.printGenome();

      peeps[index]^.printNeuralNet();
      peeps[index]^.printIGraphEdgeList();

      Writeln('---------------------------');
      dec(count);
      If count = 0 Then break;
    End;
  End;

  displaySensorActionReferenceCounts(Peeps);
End;

End.

