Unit usignals;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, ubasicTypes;

{$I c_types.inc}

// Usage: uint8_t magnitude = signals[layer][x][y];
// or             magnitude = signals.getMagnitude(layer, Coord);


Const
  SIGNAL_MIN = 0;
  SIGNAL_MAX = UINT8_MAX;

Type

  { TSignals }

  TSignals = Class
  private
    fdata: Array Of Array Of Array Of uint8;
    Function getData(layernum, colNum, rowNum: integer): uint8;
    Procedure setData(layernum, colNum, rowNum: integer; AValue: uint8);
  public
    Property Data[layernum, colNum, rowNum: integer]: uint8 read getData write setData; default;
    Procedure zeroFill();
    Constructor Create();
    Procedure init(numLayers, sizeX, sizeY: uint16_t);
    //    Layer& operator[](uint16_t layerNum) { return data[layerNum]; }
    //    const Layer& operator[](uint16_t layerNum) const { return data[layerNum]; }
    Function getMagnitude(layernum: uint16_t; loc: TCoord): uint8_t;
    Procedure increment(layerNum: int16_t; loc: TCoord);
    //    void zeroFill() { for (Layer &layer : data) { layer.zeroFill(); } }
    Procedure fade(layerNum: unsigned);
  End;

Implementation

Uses uparams, uSimulator, Math;

{ TSignals }

Function TSignals.getData(layernum, colNum, rowNum: integer): uint8;
Begin
  result := fdata[layernum, colNum, rowNum];
End;

Procedure TSignals.setData(layernum, colNum, rowNum: integer; AValue: uint8);
Begin
  fdata[layernum, colNum, rowNum] := AValue;
End;

Procedure TSignals.zeroFill;
Var
  i, j, k: integer;
Begin
  For i := 0 To high(fdata) Do
    For j := 0 To high(fdata[i]) Do
      For k := 0 To high(fdata[i, j]) Do
        fdata[i, j, k] := 0;
End;

Constructor TSignals.Create;
Begin
  fdata := Nil;
End;

Procedure TSignals.init(numLayers, sizeX, sizeY: uint16_t);
Begin
  setlength(fdata, numLayers, sizex, sizey);
End;

Function TSignals.getMagnitude(layernum: uint16_t; loc: TCoord): uint8_t;
Begin
  Result := fdata[layernum, loc.x, loc.y];
End;

// Fades the signals

Procedure TSignals.fade(layerNum: unsigned);
Const
  fadeAmount = 1;
Var
  x, y: integer;
Begin
  For x := 0 To p.sizeX - 1 Do Begin
    For y := 0 To p.sizeY - 1 Do Begin
      If (signals[layerNum, x, y] >= fadeAmount) Then Begin
        signals[layerNum, x, y] := signals[layerNum, x, y] - fadeAmount; // fade center cell
      End
      Else Begin
        signals[layerNum, x, y] := 0;
      End;
    End;
  End;
End;

Var
  DummyLayer: Integer;

Const
  centerIncreaseAmount = 2;
  neighborIncreaseAmount = 1;

Procedure visitNeighborhoodCallback(loc: TCoord);
Begin
  If (signals.fdata[DummyLayer][loc.x][loc.y] < SIGNAL_MAX) Then Begin
    signals.fdata[DummyLayer][loc.x][loc.y] :=
      min(SIGNAL_MAX,
      signals.fdata[DummyLayer][loc.x][loc.y] + neighborIncreaseAmount);
  End;
End;

// Increases the specified location by centerIncreaseAmount,
// and increases the neighboring cells by neighborIncreaseAmount

// Is it ok that multiple readers are reading this container while
// this single thread is writing to it?  todo!!!

Procedure TSignals.increment(layerNum: int16_t; loc: TCoord);
Const
  radius = 1.5;
Begin
  DummyLayer := layerNum;

  //#pragma omp critical
  //    {
  visitNeighborhood(loc, radius, @visitNeighborhoodCallback);

  If (signals.fdata[layerNum][loc.x][loc.y] < SIGNAL_MAX) Then Begin
    signals.fdata[layerNum][loc.x][loc.y] :=
      min(SIGNAL_MAX,
      signals.fdata[layerNum][loc.x][loc.y] + centerIncreaseAmount);
  End;
  //    }
End;

End.

