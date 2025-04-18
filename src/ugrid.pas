Unit ugrid;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, ubasicTypes, urandom;

{$I c_types.inc}

// The grid is the 2D arena where the agents live.

// Grid is a somewhat dumb 2D container of unsigned 16-bit values.
// Grid understands that the elements are either EMPTY, BARRIER, or
// otherwise an index value into the peeps container.
// The elements are allocated and cleared to EMPTY in the ctor.
// Prefer .at() and .set() for random element access. Or use Grid[x][y]
// for direct access where the y index is the inner loop.
// Element values are not otherwise interpreted by class Grid.

Const
  EMPTY = 0; // Index value 0 is reserved
  BARRIER = $FFFF;

Type

  { TGrid }

  TGrid = Class
  private
    barrierLocations: TCoordArray;
    barrierCenters: TCoordArray;
    // Column order here allows us to access grid elements as data[x][y]
    // while thinking of x as column and y as row
    data: Array Of Array Of UInt16;
  public
    Constructor Create(); virtual;
    Destructor Destroy(); override;

    Procedure init(sizeX, sizeY: uint16_t);
    Procedure zeroFill();
    Function isInBounds(loc: TCoord): Boolean;
    Function isEmptyAt(loc: TCoord): Boolean;
    Function isBarrierAt(loc: TCoord): Boolean;
    // Occupied means an agent is living there.
    Function isOccupiedAt(loc: TCoord): boolean;
    Function isBorder(loc: TCoord): Boolean;
    Function at(loc: TCoord): uint16_t;

    Procedure Set_(loc: TCoord; val: uint16_t); overload;
    Procedure Set_(x, y, val: uint16_t); overload;
    Function findEmptyLocation(Const randomUint: RandomUintGenerator): TCoord;
    Procedure createBarrier(Const randomUint: RandomUintGenerator; barrierType: unsigned);
    Function getBarrierLocations(): TCoordArray;
    Function getBarrierCenters(): TCoordArray;
  End;

Var
  grid: TGrid = Nil; // The 2D world where the creatures live

Implementation

Uses uparams;

{ TGrid }

Constructor TGrid.Create;
Begin
  Inherited create;
  data := Nil;
  barrierLocations := Nil;
  barrierCenters := Nil;
End;

Destructor TGrid.Destroy;
Var
  i: Integer;
Begin
  setlength(barrierLocations, 0);
  setlength(barrierCenters, 0);
  For i := 0 To high(data) Do Begin
    setlength(data[i], 0);
  End;
  setlength(data, 0);
End;

Procedure TGrid.init(sizeX, sizeY: uint16_t);
Begin
  // Allocates space for the 2D grid
  setlength(data, sizeX, sizeY);
End;

Procedure TGrid.zeroFill;
Var
  i, j: Integer;
Begin
  { for (Column &column : data) column.zeroFill(); }
  For i := 0 To high(data) Do Begin
    For j := 0 To high(data[i]) Do Begin
      data[i, j] := 0;
    End;
  End;
End;

Function TGrid.isInBounds(loc: TCoord): Boolean;
Begin
  result := (loc.x >= 0) And (loc.x < length(data)) And (loc.y >= 0) And (loc.y < length(data[0]));
End;

Function TGrid.isEmptyAt(loc: TCoord): Boolean;
Begin
  result := at(loc) = EMPTY;
End;

Function TGrid.isBarrierAt(loc: TCoord): Boolean;
Begin
  result := at(loc) = BARRIER;
End;

Function TGrid.isOccupiedAt(loc: TCoord): boolean;
Begin
  result := (at(loc) <> EMPTY) And (at(loc) <> BARRIER);
End;

Function TGrid.isBorder(loc: TCoord): Boolean;
Begin
  result := (loc.x = 0) Or (loc.x = length(data) - 1) Or (loc.y = 0) Or (loc.y = length(data[0]) - 1);
End;

Function TGrid.at(loc: TCoord): uint16_t;
Begin
  result := data[loc.x, loc.y];
End;

Procedure TGrid.Set_(loc: TCoord; val: uint16_t);
Begin
  data[loc.x][loc.y] := val;
End;

Procedure TGrid.Set_(x, y, val: uint16_t);
Begin
  data[x][y] := val;
End;

// Finds a random unoccupied location in the grid

Function TGrid.findEmptyLocation(Const randomUint: RandomUintGenerator): TCoord;
Var
  cnt: integer;
Begin
  cnt := 0;
  While true Do Begin
    result.x := randomUint.RndRange(0, p.sizeX - 1);
    result.y := randomUint.RndRange(0, p.sizeY - 1);
    If isEmptyAt(result) Then exit;
    inc(cnt);
    If cnt > p.sizeX * p.sizey Then Begin
      Raise exception.Create('TGrid.findEmptyLocation: endless detection, overflow, do you have to less space to place all individuals ?');
    End;
  End;
End;

Function RandomLoc(Const randomUint: RandomUintGenerator; margin: integer): tCoord;
Begin
  result := Coord(randomUint.RndRange(margin, p.sizeX - margin), randomUint.RndRange(margin, p.sizeY - margin));
End;

Procedure SetBarierCoord(Coord: TCoord; UserData: Pointer);
Var
  BarrierCoordTmp: TCoordArray;
Begin
  // TODO: Kann man das hier noch optimieren ?
  BarrierCoordTmp := TCoordArray(UserData);
  setlength(BarrierCoordTmp, high(BarrierCoordTmp) + 2);
  BarrierCoordTmp[high(BarrierCoordTmp)] := Coord;
End;

// This generates barrier points, which are grid locations with value
// BARRIER. A list of barrier locations is saved in private member
// Grid::barrierLocations and, for some scenarios, Grid::barrierCenters.
// Those members are available read-only with Grid::getBarrierLocations().
// This function assumes an empty grid. This is typically called by
// the main simulator thread after Grid::init() or Grid::zeroFill().

Procedure TGrid.createBarrier(Const randomUint: RandomUintGenerator; barrierType: unsigned);
Var
  BarrierCoordTmp: TCoordArray;

  Procedure drawBox(minX, minY, maxX, maxY: int16_t);
  Var
    x, y: integer;
  Begin
    For x := minX To maxX Do Begin
      For y := minY To maxY Do Begin
        Set_(x, y, BARRIER);
        // TODO: Kann man das hier noch optimieren ?
        setlength(barrierLocations, high(barrierLocations) + 2);
        barrierLocations[high(barrierLocations)].x := x;
        barrierLocations[high(barrierLocations)].y := y;
      End;
    End;
  End;

  Procedure SetBarrierCoordTmp();
  Var
    x: SizeInt;
    y: Integer;
  Begin
    x := length(barrierLocations);
    setlength(barrierLocations, x + length(BarrierCoordTmp));
    For y := 0 To high(BarrierCoordTmp) Do Begin
      set_(BarrierCoordTmp[y].x, BarrierCoordTmp[y].y, BARRIER);
      barrierLocations[x + y] := BarrierCoordTmp[y];
    End;
    setlength(BarrierCoordTmp, 0);
  End;

Const
  numberOfLocations = 5;

Var
  verticalSliceSize, margin, blockSizeX, blockSizeY, x, y, minx, maxx, miny, maxy, x0, y0, x1, y1: int16_t;
  radius: Single;
  loc, center0, center1, center2: TCoord;
Begin

  setlength(barrierLocations, 0);
  setlength(barrierCenters, 0); // used only for some barrier types

  Case barrierType Of
    0: Begin
      End;

    // Vertical bar in constant location
    1: Begin
        minX := p.sizeX Div 2;
        maxX := minX + 1;
        minY := p.sizeY Div 4;
        maxY := minY + p.sizeY Div 2;

        For x := minx To maxx Do Begin
          For y := miny To maxy Do Begin
            set_(x, y, BARRIER);
            // TODO: Kann man das hier noch optimieren ?
            setlength(barrierLocations, high(barrierLocations) + 2);
            barrierLocations[high(barrierLocations)].x := x;
            barrierLocations[high(barrierLocations)].y := y;
          End;
        End;
      End;

    // Vertical bar in random location
    2: Begin
        minX := randomUint.RndRange(20, p.sizeX - 20);
        maxX := minX + 1;
        minY := randomUint.RndRange(20, p.sizeY Div 2 - 20);
        maxY := minY + p.sizeY Div 2;


        For x := minx To maxx Do Begin
          For y := miny To maxy Do Begin
            Set_(x, y, BARRIER);
            // TODO: Kann man das hier noch optimieren ?
            setlength(barrierLocations, high(barrierLocations) + 2);
            barrierLocations[high(barrierLocations)].x := x;
            barrierLocations[high(barrierLocations)].y := y;
          End;
        End;
      End;

    // five blocks staggered
    3: Begin
        blockSizeX := 2;
        blockSizeY := p.sizeX Div 3;

        x0 := p.sizeX Div 4 - blockSizeX Div 2;
        y0 := p.sizeY Div 4 - blockSizeY Div 2;
        x1 := x0 + blockSizeX;
        y1 := y0 + blockSizeY;

        drawBox(x0, y0, x1, y1);
        x0 := x0 + p.sizeX Div 2;
        x1 := x0 + blockSizeX;
        drawBox(x0, y0, x1, y1);
        y0 := y0 + p.sizeY Div 2;
        y1 := y0 + blockSizeY;
        drawBox(x0, y0, x1, y1);
        x0 := x0 - p.sizeX Div 2;
        x1 := x0 + blockSizeX;
        drawBox(x0, y0, x1, y1);
        x0 := p.sizeX Div 2 - blockSizeX Div 2;
        x1 := x0 + blockSizeX;
        y0 := p.sizeY Div 2 - blockSizeY Div 2;
        y1 := y0 + blockSizeY;
        drawBox(x0, y0, x1, y1);
      End;

    // Horizontal bar in constant location
    4: Begin
        minX := p.sizeX Div 4;
        maxX := minX + p.sizeX Div 2;
        minY := p.sizeY Div 2 + p.sizeY Div 4;
        maxY := minY + 2;

        For x := minx To maxx Do Begin
          For y := miny To maxy Do Begin
            Set_(x, y, BARRIER);
            // TODO: Kann man das hier noch optimieren ?
            setlength(barrierLocations, high(barrierLocations) + 2);
            barrierLocations[high(barrierLocations)].x := x;
            barrierLocations[high(barrierLocations)].y := y;
          End;
        End;
      End;

    // Three floating islands -- different locations every generation
    5: Begin
        radius := 3.0;
        margin := 2 * trunc(radius);


        center0 := randomLoc(randomUint, margin);

        Repeat
          center1 := RandomLoc(randomUint, margin);
        Until ((center0 - center1).length() >= margin);
        Repeat
          center2 := RandomLoc(randomUint, margin);
        Until ((center0 - center2).length() >= margin) And ((center1 - center2).length() >= margin);

        // TODO: Kann man das hier noch optimieren ?
        setlength(barrierLocations, high(barrierLocations) + 2);
        barrierLocations[high(barrierLocations)] := center0;

        // TODO: Klären warum nur die 1. Insel aktiv ist ?

        //setlength(barrierLocations, high(barrierLocations) + 2);
        //barrierLocations[high(barrierLocations)] := center1;
        //setlength(barrierLocations, high(barrierLocations) + 2);
        //barrierLocations[high(barrierLocations)] := center2;

        BarrierCoordTmp := Nil;
        visitNeighborhood(center0, Coord(p.sizeX, p.sizeY), radius, @SetBarierCoord, @BarrierCoordTmp);
        //visitNeighborhood(center1, radius, @SetBarierCoord);
        //visitNeighborhood(center2, radius, @SetBarierCoord);

        SetBarrierCoordTmp();

      End;

    // Spots, specified number, radius, locations
    6: Begin
        radius := 5.0;

        verticalSliceSize := p.sizeY Div (numberOfLocations + 1);

        BarrierCoordTmp := Nil;
        For x := 1 To numberOfLocations Do Begin
          loc := coord((p.sizeX Div 2), (x * verticalSliceSize));
          visitNeighborhood(loc, Coord(p.sizeX, p.sizeY), radius, @SetBarierCoord, @BarrierCoordTmp);
        End;
        SetBarrierCoordTmp();
      End;

    // ]-shaped barrier
    7: Begin
        // Rechter Senkrechter Strich
        minX := (p.sizeX * 3) Div 4;
        maxX := minX + 1;
        minY := p.sizeY Div 4;
        maxY := minY + p.sizeY Div 2;
        For x := minx To maxx Do Begin
          For y := miny To maxy Do Begin
            set_(x, y, BARRIER);
            // TODO: Kann man das hier noch optimieren ?
            setlength(barrierLocations, high(barrierLocations) + 2);
            barrierLocations[high(barrierLocations)].x := x;
            barrierLocations[high(barrierLocations)].y := y;
          End;
        End;
        // Obere Kante
        minX := round(p.sizeX * 0.6);
        maxX := (p.sizeX * 3) Div 4;
        minY := p.sizeY Div 4;
        maxY := minY + 1;
        For x := minx To maxx Do Begin
          For y := miny To maxy Do Begin
            set_(x, y, BARRIER);
            // TODO: Kann man das hier noch optimieren ?
            setlength(barrierLocations, high(barrierLocations) + 2);
            barrierLocations[high(barrierLocations)].x := x;
            barrierLocations[high(barrierLocations)].y := y;
          End;
        End;
        // Untere Kante
        minX := round(p.sizeX * 0.6);
        maxX := (p.sizeX * 3) Div 4;
        minY := p.sizeY Div 4 + p.sizeY Div 2 - 1;
        maxY := minY + 1;
        For x := minx To maxx Do Begin
          For y := miny To maxy Do Begin
            set_(x, y, BARRIER);
            // TODO: Kann man das hier noch optimieren ?
            setlength(barrierLocations, high(barrierLocations) + 2);
            barrierLocations[high(barrierLocations)].x := x;
            barrierLocations[high(barrierLocations)].y := y;
          End;
        End;
      End
  Else Begin
      Raise exception.create('Error, unknown barrier: ' + inttostr(barrierType));
    End;
  End;
End;

Function TGrid.getBarrierLocations: TCoordArray;
Begin
  result := barrierLocations;
End;

Function TGrid.getBarrierCenters: TCoordArray;
Begin
  result := barrierCenters;
End;

End.

