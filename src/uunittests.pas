Unit uUnittests;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

Procedure unitTestConnectNeuralNetWiringFromGenome();
Procedure unitTestGridVisitNeighborhood();
Function unitTestBasicTypes(): Boolean;

Implementation

Uses ugenome, uindiv, ubasicTypes, uparams;

Procedure unitTestConnectNeuralNetWiringFromGenome();
//Function MakeGene(Sourcetype: integer; SourceNum: integer; SinkType: integer; SinkNum: integer; Weight: Single): TGene;
  Function MakeGene(Sourcetype: integer; SourceNum: integer; SinkType: integer; SinkNum: integer; Weight: integer): TGene;
  Begin
    result.sourceType := Sourcetype;
    result.SourceNum := SourceNum;
    result.SinkType := SinkType;
    result.SinkNum := SinkNum;
    //    result.Weight := trunc(Weight * 8192);
    result.Weight := Weight;
  End;

Var
  genome1: TGenome;
  indiv: TIndiv;
  conn: Integer;
  s: String;
Begin
  genome1 := Nil;
  setlength(genome1, 12);
  genome1[0] := MakeGene(SENSOR, 0, NEURON, 0, 0);
  genome1[1] := MakeGene(SENSOR, 1, NEURON, 2, 2);
  genome1[2] := MakeGene(SENSOR, 13, NEURON, 9, 3);
  genome1[3] := MakeGene(NEURON, 4, NEURON, 5, 4);
  genome1[4] := MakeGene(NEURON, 4, NEURON, 4, 5);
  genome1[5] := MakeGene(NEURON, 5, NEURON, 9, 6);
  genome1[6] := MakeGene(NEURON, 0, NEURON, 0, 7);
  genome1[7] := MakeGene(NEURON, 5, NEURON, 9, 8);
  genome1[8] := MakeGene(SENSOR, 0, ACTION, 1, 9);
  genome1[9] := MakeGene(SENSOR, 2, ACTION, 12, 10);
  genome1[10] := MakeGene(NEURON, 0, ACTION, 1, 11);
  genome1[11] := MakeGene(NEURON, 4, ACTION, 2, 12);

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
    If indiv.nnet.connections[conn].sinkType = ACTION Then
      s := s + 'ACTION'
    Else
      s := s + 'NEURON';
    s := s + ' ';
    FormatSettings.DecimalSeparator := '.';
    s := s + IntToStr(indiv.nnet.connections[conn].sinkNum) + ' at ' +
      //FloatToStr(indiv.nnet.connections[conn].weightAsFloat())
      inttostr(indiv.nnet.connections[conn].weight)

      ;
    writeln(s);
  End;
End;

Procedure printLoc(Coord: TCoord; UserData: Pointer);
Begin
  writeln(inttostr(Coord.x) + ', ' + inttostr(Coord.y));
End;

Procedure unitTestGridVisitNeighborhood();
Begin
  Writeln('Test loc 10,10 radius 1');
  visitNeighborhood(Coord(10, 10), 1.0, @printLoc, Nil);

  Writeln('Test loc 0,0 radius 1');
  visitNeighborhood(Coord(0, 0), 1.0, @printLoc, Nil);

  Writeln('Test loc 10,10 radius 1.4');
  visitNeighborhood(Coord(10, 10), 1.4, @printLoc, Nil);

  Writeln('Test loc 10,10 radius 1.5');
  visitNeighborhood(Coord(10, 10), 1.5, @printLoc, Nil);
  //
  Writeln('Test loc 1,1 radius 1.4');
  visitNeighborhood(Coord(1, 1), 1.4, @printLoc, Nil);

  Writeln('Test loc 10,10 radius 2.0');
  visitNeighborhood(Coord(10, 10), 2.0, @printLoc, Nil);

  Writeln('Test loc p.sizeX-1, p.sizeY-1 radius 2.0');
  visitNeighborhood(Coord((p.sizeX - 1), (p.sizeY - 1)), 2.0, @printLoc, Nil);
End;

Function unitTestBasicTypes(): Boolean;
Var
  d1, d2: TDir;
  c1, c2: TCoord;
Begin
  // Dir

  // ctor from Compass
  // .asInt()
  // copy assignment
  d1 := TDir.dir(TCompass.N);
  d2 := TDir.dir(TCompass.CENTER);
  d1 := d2;
  assert(d1.asInt() = integer(TCompass.CENTER));
  d1 := TDir.dir(TCompass.SW);
  assert(d1.asInt() = 0);
  d1 := TDir.dir(TCompass.S);
  assert(d1.asInt() = 1);
  d1 := TDir.Dir(TCompass.SE);
  assert(d1.asInt() = 2);
  d1 := TDir.Dir(TCompass.W);
  assert(d1.asInt() = 3);
  d1 := TDir.Dir(TCompass.CENTER);
  assert(d1.asInt() = 4);
  d1 := TDir.Dir(TCompass.E);
  assert(d1.asInt() = 5);
  d1 := TDir.Dir(TCompass.NW);
  assert(d1.asInt() = 6);
  d1 := TDir.Dir(TCompass.N);
  assert(d1.asInt() = 7);
  d1 := TDir.Dir(TCompass.NE);
  assert(d1.asInt() = 8);

  assert(TDir.Dir(TCompass.SW).asInt() = 0);
  assert(TDir.Dir(TCompass.S).asInt() = 1);
  assert(TDir.Dir(TCompass.SE).asInt() = 2);
  assert(TDir.Dir(TCompass.W).asInt() = 3);
  assert(TDir.Dir(TCompass.CENTER).asInt() = 4);
  assert(TDir.Dir(TCompass.E).asInt() = 5);
  assert(TDir.Dir(TCompass.NW).asInt() = 6);
  assert(TDir.Dir(TCompass.N).asInt() = 7);
  assert(TDir.Dir(TCompass.NE).asInt() = 8);
  assert(TDir.Dir(TCompass(8)).asInt() = 8);
  assert(TDir.Dir(TCompass(((TDir.Dir(TCompass(8))).asInt()))).asInt() = 8);
  assert(TDir.Dir(TCompass((TDir.Dir(TCompass.NE).asInt()))).asInt() = 8);
  d2 := TDir.Dir(TCompass.E);
  d1 := d2;
  assert(d1.asInt() = 5);
  d2 := d1;
  assert(d1.asInt() = 5);

  // .operator=() from Compass
  d1 := TDir.Dir(TCompass.SW);
  assert(d1.asInt() = 0);
  d1 := TDir.dir(TCompass.SE);
  assert(d1.asInt() = 2);

  // [in]equality with Compass
  d1 := Tdir.dir(TCompass.CENTER);
  assert(d1 = TCompass.CENTER);
  d1 := TDir.dir(TCompass.SE);
  assert(d1 = TCompass.SE);
  assert(Tdir.Dir(TCompass.W) = TCompass.W);
  assert(TDir.Dir(TCompass.W) <> TCompass.NW);

  // [in]equality with Dir
  d1 := TDir.dir(TCompass.N);
  d2 := TDir.dir(TCompass.N);
  assert(d1 = d2);
  assert(d2 = d1);
  d1 := TDir.Dir(TCompass.NE);
  assert(d1 <> d2);
  assert(d2 <> d1);

  // .rotate()
  assert(d1.rotate(1) = TCompass.E);
  assert(d1.rotate(2) = TCompass.SE);
  assert(d1.rotate(-1) = TCompass.N);
  assert(d1.rotate(-2) = TCompass.NW);
  assert(Tdir.Dir(TCompass.N).rotate(1) = d1);
  assert(Tdir.Dir(TCompass.SW).rotate(-2) = TCompass.SE);

  // .asNormalizedCoord()
  c1 := asNormalizedCoord(TDir.Dir(TCompass.CENTER));
  assert((c1.x = 0) And (c1.y = 0));
  d1 := TDir.dir(TCompass.SW);
  c1 := asNormalizedCoord(d1);
  assert((c1.x = -1) And (c1.y = -1));
  c1 := asNormalizedCoord(TDir.Dir(TCompass.S));
  assert((c1.x = 0) And (c1.y = -1));
  c1 := asNormalizedCoord(Tdir.Dir(TCompass.SE));
  assert((c1.x = 1) And (c1.y = -1));
  c1 := asNormalizedCoord(Tdir.Dir(TCompass.W));
  assert((c1.x = -1) And (c1.y = 0));
  c1 := asNormalizedCoord(Tdir.Dir(TCompass.E));
  assert((c1.x = 1) And (c1.y = 0));
  c1 := asNormalizedCoord(Tdir.Dir(TCompass.NW));
  assert((c1.x = -1) And (c1.y = 1));
  c1 := asNormalizedCoord(Tdir.Dir(TCompass.N));
  assert((c1.x = 0) And (c1.y = 1));
  c1 := asNormalizedCoord(Tdir.Dir(TCompass.NE));
  assert((c1.x = 1) And (c1.y = 1));

  // .asNormalizedPolar() -- Polar Coordinaten werden nirgends genutz ..
  //d1 := TDir.dir(TCompass.SW);
  //Polar p1 = d1.asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::SW);
  //p1 = Dir(Compass::S).asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::S);
  //p1 = Dir(Compass::SE).asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::SE);
  //p1 = Dir(Compass::W).asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::W);
  //p1 = Dir(Compass::E).asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::E);
  //p1 = Dir(Compass::NW).asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::NW);
  //p1 = Dir(Compass::N).asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::N);
  //p1 = Dir(Compass::NE).asNormalizedPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::NE);

  // Coord
  // ctor from int16_t,int16_t
  c1 := TCoord.Init;
  assert((c1.x = 0) And (c1.y = 0));
  c1 := TCoord.Init(1, 1);
  assert((c1.x = 1) And (c1.y = 1));
  c1 := Coord(-6, 12);
  assert((c1.x = -6) And (c1.y = 12));

  // copy assignment
  c2 := TCoord.init(9, 101);
  assert((c2.x = 9) And (c2.y = 101));
  c1 := c2;
  assert((c1.x = 9) And (c2.y = 101));

  //// .isNormalized()
  assert(Not c1.isNormalized());
  assert(TCoord.init(0, 0).isNormalized());
  assert(TCoord.init(0, 1).isNormalized());
  assert(TCoord.init(1, 1).isNormalized());
  assert(TCoord.init(-1, 0).isNormalized());
  assert(TCoord.init(-1, -1).isNormalized());
  assert(Not TCoord.init(0, 2).isNormalized());
  assert(Not TCoord.init(1, 2).isNormalized());
  assert(Not TCoord.init(-1, 2).isNormalized());
  assert(Not TCoord.init(-2, 0).isNormalized());

  // .normalize()
  // .asDir()
  c1 := TCoord.init(0, 0);
  c2 := c1.normalize();
  assert((c2.x = 0) And (c2.y = 0));
  assert(c2.asDir() = TCompass.CENTER);
  c1 := TCoord.init(0, 1).normalize();
  assert((c1.x = 0) And (c1.y = 1));
  assert(c1.asDir() = TCompass.N);
  c1 := TCoord.init(-1, 1).normalize();
  assert((c1.x = -1) And (c1.y = 1));
  assert(c1.asDir() = TCompass.NW);
  c1 := TCoord.init(100, 5).normalize();
  assert((c1.x = 1) And (c1.y = 0));
  assert(c1.asDir() = TCompass.E);
  c1 := TCoord.init(100, 105).normalize();
  assert((c1.x = 1) And (c1.y = 1));
  assert(c1.asDir() = TCompass.NE);
  c1 := TCoord.init(-5, 101).normalize();
  assert((c1.x = 0) And (c1.y = 1));
  assert(c1.asDir() = TCompass.N);
  c1 := TCoord.init(-500, 10).normalize();
  assert((c1.x = -1) And (c1.y = 0));
  assert(c1.asDir() = TCompass.W);
  c1 := TCoord.init(-500, -490).normalize();
  assert((c1.x = -1) And (c1.y = -1));
  assert(c1.asDir() = TCompass.SW);
  c1 := TCoord.init(-1, -490).normalize();
  assert((c1.x = 0) And (c1.y = -1));
  assert(c1.asDir() = TCompass.S);
  c1 := TCoord.init(1101, -1090).normalize();
  assert((c1.x = 1) And (c1.y = -1));
  assert(c1.asDir() = TCompass.SE);
  c1 := TCoord.init(1101, -3).normalize();
  assert((c1.x = 1) And (c1.y = 0));
  assert(c1.asDir() = TCompass.E);

  // .length()
  assert(TCoord.init(0, 0).length() = 0);
  assert(TCoord.init(0, 1).length() = 1);
  assert(TCoord.init(-1, 0).length() = 1);
  assert(TCoord.init(-1, -1).length() = 1); // round down
  assert(TCoord.init(22, 0).length() = 22);
  assert(TCoord.init(22, 22).length() = 31); // round down
  assert(TCoord.init(10, -10).length() = 14); // round down
  assert(TCoord.init(-310, 0).length() = 310);

  //// .asPolar()
  //p1 = Coord(0, 0).asPolar();
  //assert(p1.mag == 0 && p1.dir == Compass::CENTER);
  //p1 = Coord(0, 1).asPolar();
  //assert(p1.mag == 1 && p1.dir == Compass::N);
  //p1 = Coord(-10, -10).asPolar();
  //assert(p1.mag == 14 && p1.dir == Compass::SW); // round down mag
  //p1 = Coord(100, 1).asPolar();
  //assert(p1.mag == 100 && p1.dir == Compass::E); // round down mag

  // operator+(Coord), operator-(Coord)
  c1 := TCoord.init(0, 0) + TCoord.init(6, 8);
  assert((c1.x = 6) And (c1.y = 8));
  c1 := TCoord.init(-70, 20) + TCoord.init(10, -10);
  assert((c1.x = -60) And (c1.y = 10));
  c1 := TCoord.init(-70, 20) - TCoord.init(10, -10);
  assert((c1.x = -80) And (c1.y = 30));

  // operator*(int)
  c1 := TCoord.init(0, 0) * 1;
  assert((c1.x = 0) And (c1.y = 0));
  c1 := TCoord.init(1, 1) * (-5);
  assert((c1.x = -5) And (c1.y = -5));
  c1 := TCoord.init(11, 5) * -5;
  assert((c1.x = -55) And (c1.y = -25));

  // operator+(Dir), operator-(Dir)
  c1 := TCoord.Init(0, 0);
  c2 := c1 + Tdir.Dir(TCompass.CENTER);
  assert((c2.x = 0) And (c2.y = 0));
  c2 := c1 + TDir.Dir(TCompass.E);
  assert((c2.x = 1) And (c2.y = 0));
  c2 := c1 + Tdir.Dir(TCompass.W);
  assert((c2.x = -1) And (c2.y = 0));
  c2 := c1 + TDir.Dir(TCompass.SW);
  assert((c2.x = -1) And (c2.y = -1));

  c2 := c1 - TDir.Dir(TCompass.CENTER);
  assert((c2.x = 0) And (c2.y = 0));
  c2 := c1 - Tdir.Dir(TCompass.E);
  assert((c2.x = -1) And (c2.y = 0));
  c2 := c1 - TDir.Dir(TCompass.W);
  assert((c2.x = 1) And (c2.y = 0));
  c2 := c1 - TDir.Dir(TCompass.SW);
  assert((c2.x = 1) And (c2.y = 1));

  //// raySameness()
  //c1 = Coord { 0, 0 };
  //c2 = Coord { 10, 11 };
  //d1 = Compass::CENTER;
  //assert(c1.raySameness(c2) == 1.0); // special case - zero vector
  //assert(c2.raySameness(c1) == 1.0); // special case - zero vector
  //assert(c2.raySameness(d1) == 1.0); // special case - zero vector
  //c1 = c2;
  //assert(c1.raySameness(c2) == 1.0);
  //assert(areClosef(Coord(-10,-10).raySameness(Coord(10,10)), -1.0));
  //c1 = Coord{0,11};
  //c2 = Coord{20,0};
  //assert(areClosef(c1.raySameness(c2), 0.0));
  //assert(areClosef(c2.raySameness(c1), 0.0));
  //c1 = Coord{0,444};
  //c2 = Coord{113,113};
  //assert(areClosef(c1.raySameness(c2), 0.707106781));
  //c2 = Coord{113,-113};
  //assert(areClosef(c1.raySameness(c2), -0.707106781));

  //// Polar
  //// ctor from mag, dir
  //p1 = Polar();
  //assert(p1.mag == 0 && p1.dir == Compass::CENTER);
  //p1 = Polar(0, Compass::S);
  //assert(p1.mag == 0 && p1.dir == Compass::S);
  //p1 = Polar(10, Compass::SE);
  //assert(p1.mag == 10 && p1.dir == Compass::SE);
  //p1 = Polar(-10, Compass::NW);
  //assert(p1.mag == -10 && p1.dir == Compass::NW);

  //// .asCoord()
  //c1 = Polar(0, Compass::CENTER).asCoord();
  //assert(c1.x == 0 && c1.y == 0);
  //c1 = Polar(10, Compass::CENTER).asCoord();
  //assert(c1.x == 0 && c1.y == 0);
  //c1 = Polar(20, Compass::N).asCoord();
  //assert(c1.x == 0 && c1.y == 20);
  ////c1 = Polar(12, Compass::W).asCoord();
  //p1 = Polar(12, Compass::W);
  //c1 = p1.asCoord();
  //assert(c1.x == -12 && c1.y == 0);
  //c1 = Polar(14, Compass::NE).asCoord();
  //assert(c1.x == 10 && c1.y == 10);
  //c1 = Polar(-14, Compass::NE).asCoord();
  //assert(c1.x == -10 && c1.y == -10);
  //c1 = Polar(14, Compass::E).asCoord();
  //assert(c1.x == 14 && c1.y == 0);
  //c1 = Polar(-14, Compass::E).asCoord();
  //assert(c1.x == -14 && c1.y == 0);

  result := true;
End;

End.

