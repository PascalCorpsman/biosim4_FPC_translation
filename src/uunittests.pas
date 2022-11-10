Unit uUnittests;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

Procedure unitTestConnectNeuralNetWiringFromGenome();
Procedure unitTestGridVisitNeighborhood();

Implementation

Uses ugenome, uindiv, ubasicTypes, uparams;

Procedure unitTestConnectNeuralNetWiringFromGenome();
  Function MakeGene(Sourcetype: integer; SourceNum: integer; SinkType: integer; SinkNum: integer; Weight: Single): TGene;
  Begin
    result.sourceType := Sourcetype;
    result.SourceNum := SourceNum;
    result.SinkType := SinkType;
    result.SinkNum := SinkNum;
    result.Weight := trunc(Weight * 8192);
  End;

Var
  genome1: TGenome;
  indiv: TIndiv;
  conn: Integer;
  s: String;
Begin
  genome1 := Nil;
  setlength(genome1, 12);
  genome1[0] := MakeGene(SENSOR, 0, NEURON, 0, 0.0);
  genome1[1] := MakeGene(SENSOR, 1, NEURON, 2, 2.2);
  genome1[2] := MakeGene(SENSOR, 13, NEURON, 9, 3.3);
  genome1[3] := MakeGene(NEURON, 4, NEURON, 5, 4.4);
  genome1[4] := MakeGene(NEURON, 4, NEURON, 4, 5.5);
  genome1[5] := MakeGene(NEURON, 5, NEURON, 9, 6.6);
  genome1[6] := MakeGene(NEURON, 0, NEURON, 0, 7.7);
  genome1[7] := MakeGene(NEURON, 5, NEURON, 9, 8.8);
  genome1[8] := MakeGene(SENSOR, 0, ACTION, 1, 9.9);
  genome1[9] := MakeGene(SENSOR, 2, ACTION, 12, 10.1);
  genome1[10] := MakeGene(NEURON, 0, ACTION, 1, 11.0);
  genome1[11] := MakeGene(NEURON, 4, ACTION, 2, 12.0);

  indiv.genome := genome1;

  indiv.createWiringFromGenome();


  For conn := 0 To high(indiv.nnet.connections) Do Begin
    s := '';
    If indiv.nnet.connections[conn].sourceType = SENSOR Then
      s := 'SENSOR'
    Else
      s := 'NEURON';
    s := s + ' ';
    s := s + inttostr(indiv.nnet.connections[conn].sourceNum) + ' -> ';
    If indiv.nnet.connections[conn].sourceType = ACTION Then
      s := s + 'ACTION'
    Else
      s := s + 'NEURON';
    s := s + ' ';
    FormatSettings.DecimalSeparator := '.';
    s := s + IntToStr(indiv.nnet.connections[conn].sinkNum) + ' at ' +
      FloatToStr(indiv.nnet.connections[conn].weightAsFloat());
    writeln(s);
  End;
End;

Procedure printLoc(Coord: TCoord);
Begin
  writeln(inttostr(Coord.x) + ', ' + inttostr(Coord.y));
End;

Procedure unitTestGridVisitNeighborhood();
Begin
  Writeln('Test loc 10,10 radius 1');
  visitNeighborhood(Coord(10, 10), 1.0, @printLoc);

  Writeln('Test loc 0,0 radius 1');
  visitNeighborhood(Coord(0, 0), 1.0, @printLoc);

  Writeln('Test loc 10,10 radius 1.4');
  visitNeighborhood(Coord(10, 10), 1.4, @printLoc);

  Writeln('Test loc 10,10 radius 1.5');
  visitNeighborhood(Coord(10, 10), 1.5, @printLoc);
  //
  Writeln('Test loc 1,1 radius 1.4');
  visitNeighborhood(Coord(1, 1), 1.4, @printLoc);

  Writeln('Test loc 10,10 radius 2.0');
  visitNeighborhood(Coord(10, 10), 2.0, @printLoc);

  Writeln('Test loc p.sizeX-1, p.sizeY-1 radius 2.0');
  visitNeighborhood(Coord((p.sizeX - 1), (p.sizeY - 1)), 2.0, @printLoc);
End;


End.

