Unit uanalysis;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

Procedure displaySignalUse();
Procedure displaySampleGenomes(count: unsigned);
Procedure appendEpochLog(generation, numberSurvivors, murderCount: unsigned);

Implementation

Uses
  uparams, uSimulator, ugenome, urandom, usensoractions, ubasicTypes, uindiv;

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

Function averageGenomeLength(): Float;
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
// ToDo: remove hardcoded filename.

Procedure appendEpochLog(generation, numberSurvivors, murderCount: unsigned);
Var
  sl: TStringlist;
Begin
  sl := TStringList.Create;
  If (generation <> 0) Then Begin
    sl.LoadFromFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt');
  End
  Else Begin
    sl.clear;
  End;
  sl.add(inttostr(generation) + ' ' + inttostr(numberSurvivors) + ' ' + floattostr(geneticDiversity()) + ' ' + floattostr(averageGenomeLength()) + ' ' + inttostr(murderCount));
  If Not ForceDirectories(ExcludeTrailingPathDelimiter(p.logDir)) Then Begin
    sl.free;
    Raise exception.create('Error, unable to write into folder:' + p.logDir);
    exit;
  End;
  sl.SaveToFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt');
  sl.free;
End;

// Print stats about pheromone usage.

Procedure displaySignalUse();
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
  writeln('Signal spread ' + format('%0.2f', [count / (p.sizeX * p.sizeY)]) + '%, average ' + format('%f', [sum / (p.sizeX * p.sizeY)]));
End;


// Print how many connections occur from each kind of sensor neuron and to
// each kind of action neuron over the entire population. This helps us to
// see which sensors and actions are most useful for survival.

Procedure displaySensorActionReferenceCounts();
Var
  index, gene, i: Integer;
  Indiv: PIndiv;
  sensorCounts: Array[0..integer(NUM_SENSES)] Of unsigned;
  actionCounts: Array[0..integer(NUM_ACTIONS)] Of unsigned;
Begin
  FillChar(sensorCounts, sizeof(sensorCounts), 0);
  FillChar(actionCounts, sizeof(actionCounts), 0);

  For index := 1 To p.population Do Begin
    If (peeps[index]^.alive) Then Begin
      indiv := peeps.Individual[index];
      For gene := 0 To high(indiv^.nnet.connections) Do Begin

        If (indiv^.nnet.connections[gene].sourceType = SENSOR) Then Begin
          assert(indiv^.nnet.connections[gene].sourceNum < integer(NUM_SENSES));
          sensorCounts[indiv^.nnet.connections[gene].sourceNum] := sensorCounts[indiv^.nnet.connections[gene].sourceNum] + 1;
        End;
        If (indiv^.nnet.connections[gene].sinkType = ACTION) Then Begin
          assert(indiv^.nnet.connections[gene].sinkNum < integer(NUM_ACTIONS));
          actionCounts[indiv^.nnet.connections[gene].sinkNum] := actionCounts[indiv^.nnet.connections[gene].sinkNum] + 1;
        End;
      End;
    End;
  End;

  writeln('Sensors in use:');
  For i := 0 To length(sensorCounts) - 1 Do Begin
    If (sensorCounts[i] > 0) Then Begin
      writeln('  ' + inttostr(sensorCounts[i]) + ' - ' + sensorName(TSensor(i)));
    End;
  End;
  writeln('Actions in use:');
  For i := 0 To high(actionCounts) Do Begin
    If (actionCounts[i] > 0) Then Begin
      writeln('  ' + inttostr(actionCounts[i]) + ' - ' + actionName(TAction(i)));
    End;
  End;
End;

Procedure displaySampleGenomes(count: unsigned);
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

  displaySensorActionReferenceCounts();
End;

End.

