Unit uanalysis;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, urandom, SysUtils;

{$I c_types.inc}

Procedure displaySignalUse();
Procedure displaySampleGenomes(count: unsigned);
Procedure appendEpochLog(Const randomUint: RandomUintGenerator; generation, numberSurvivors, murderCount: unsigned; aGeneticDiversity: Float);

Implementation

Uses
  uparams, uSimulator, ugenome, usensoractions, ubasicTypes, uindiv;

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

Function averageGenomeLength(Const randomUint: RandomUintGenerator): Float;
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

Procedure appendEpochLog(Const randomUint: RandomUintGenerator; generation, numberSurvivors, murderCount: unsigned; aGeneticDiversity: Float);
Var
  sl: TStringlist;
Begin
  sl := TStringList.Create;
  If (generation <> 0) Then Begin
    sl.LoadFromFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt');
  End
  Else Begin
    sl.clear;
    // Beschriftung der Spalten ;)
    sl.add('Generation;Number of survivors;genetic diversity;average genome length;murder count');
  End;
  FormatSettings.DecimalSeparator := '.';
  sl.add(inttostr(generation) + ';' + inttostr(numberSurvivors) + ';' + floattostr(aGeneticDiversity) + ';' + floattostr(averageGenomeLength(randomUint)) + ';' + inttostr(murderCount));
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
  FormatSettings.DecimalSeparator := '.';
  writeln('Signal spread ' + format('%0.2f', [count / (p.sizeX * p.sizeY)]) + '%, average ' + format('%f', [sum / (p.sizeX * p.sizeY)]));
End;

// Print how many connections occur from each kind of sensor neuron and to
// each kind of action neuron over the entire population. This helps us to
// see which sensors and actions are most useful for survival.

Procedure displaySensorActionReferenceCounts();
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

