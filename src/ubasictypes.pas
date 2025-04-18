Unit ubasicTypes;

{$MODE ObjFPC}{$H+}
{$MODESWITCH ADVANCEDRECORDS} // for typehelpers

Interface

Uses
  Classes, urandom, SysUtils;

{$I c_types.inc}
{$I biosim_config.inc}

Const
  // Some of the survival challenges to try. Some are interesting, some
  // not so much. Fine-tune the challenges by tweaking the corresponding code
  // in survival-criteria.cpp.
  CHALLENGE_CIRCLE = 0;
  CHALLENGE_RIGHT_HALF = 1;
  CHALLENGE_RIGHT_QUARTER = 2;
  CHALLENGE_STRING = 3;
  CHALLENGE_CENTER_WEIGHTED = 4;
  CHALLENGE_CENTER_UNWEIGHTED = 40;
  CHALLENGE_CORNER = 5;
  CHALLENGE_CORNER_WEIGHTED = 6;
  CHALLENGE_MIGRATE_DISTANCE = 7;
  CHALLENGE_CENTER_SPARSE = 8;
  CHALLENGE_LEFT_EIGHTH = 9;
  CHALLENGE_RADIOACTIVE_WALLS = 10;
  CHALLENGE_AGAINST_ANY_WALL = 11;
  CHALLENGE_TOUCH_ANY_WALL = 12;
  CHALLENGE_EAST_WEST_EIGHTHS = 13;
  CHALLENGE_NEAR_BARRIER = 14;
  CHALLENGE_PAIRS = 15;
  CHALLENGE_LOCATION_SEQUENCE = 16;
  CHALLENGE_ALTRUISM = 17;
  CHALLENGE_ALTRUISM_SACRIFICE = 18;
  CHALLENGE_RADIOACTIVE_BARRIER = 19;


(*
Basic types used throughout the project:

Compass - an enum with enumerants SW, S, SE, W, CENTER, E, NW, N, NE

    Compass arithmetic values:

        6  7  8
        3  4  5
        0  1  2

Dir, Coord, Polar, and their constructors:

    Dir - abstract type for 8 directions plus center
    ctor Dir(Compass = CENTER)

    Coord - signed int16_t pair, absolute location or difference of locations
    ctor Coord() = 0,0

    Polar - signed magnitude and direction
    ctor Polar(Coord = 0,0)

Conversions

    uint8_t = Dir.asInt()

    Dir = Coord.asDir()
    Dir = Polar.asDir()

    Coord = Dir.asNormalizedCoord()
    Coord = Polar.asCoord()

    Polar = Dir.asNormalizedPolar()
    Polar = Coord.asPolar()

Arithmetic

    Dir.rotate(int n = 0)

    Coord = Coord + Dir
    Coord = Coord + Coord
    Coord = Coord + Polar

    Polar = Polar + Coord (additive)
    Polar = Polar + Polar (additive)
    Polar = Polar * Polar (dot product)
*)

Type
  TCompass = (SW = 0, S, SE, W, CENTER, E, NW, N, NE);

  // Coordinates range anywhere in the range of int16_t. Coordinate arithmetic
  // wraps like int16_t. Can be used, e.g., for a location in the simulator grid, or
  // for the difference between two locations.

  { TCoord }

  TCoord = Record
    x: int16;
    y: int16;
  End;

  TCoordHelper = Record Helper For TCoord
    Function length(): integer;
    Function asCompass(): TCompass;
    Function Init(): TCoord; overload;
    Function Init(ax, ay: integer): TCoord; overload;
    Function IsNormalized(): Boolean;
    Function normalize(): TCoord;
  End;

  TCoordArray = Array Of TCoord;

  TCoordProcedure = Procedure(Coord: TCoord; UserData: Pointer);

Function asNormalizedCoord(Const Dir: TCompass): TCoord; // (-1, -0, 1, -1, 0, 1)

Procedure Nop();

Procedure visitNeighborhood(Const loc, dim: TCoord; Const radius: float; Const f: TCoordProcedure; UserData: Pointer);

Function Coord(x, y: integer): TCoord;

Operator * (a: TCoord; s: integer): TCoord;
Operator + (a: TCoord; d: TCompass): TCoord;
Operator - (a: TCoord; d: TCompass): TCoord;
Operator - (a, b: TCoord): TCoord;
Operator + (a, b: TCoord): TCoord;
Operator = (a, b: TCoord): Boolean;

Function FixPathDelimeter(Path: String): String;
Function prettyTime(TimeInMs: int64): String; // Code entliehen aus CCM

Function rotate90DegCW(Const aCompass: TCompass): TCompass;
Function rotate90DegCCW(Const aCompass: TCompass): TCompass;
Function random8(Const randomUint: RandomUintGenerator): TCompass; // gives a random Compass excluding center !

Function Sigmoid(x: Single): Single Inline;

Implementation

{$IFDEF SigmoidTanh}
Uses
  math;
{$ENDIF}

{$IFDEF SigmoidTable}
Uses
  math;
{$ENDIF}

{$IFDEF SigmoidTanh}

Function Sigmoid(x: Single): Single Inline;
Begin
  result := tanh(x);
End;

{$ENDIF}

{$IFDEF SigmoidTable}
Var
  (*
   * The bigger the buffer, the finer the sampling.
   * To big will result in to much costs due to referencing the buffer
   * 16-Bit seems to be the optimum (at least for the CPU the test runned of)
   *)
  TanHBuffer: Array[0..65535] Of Single;

Const
  (*
   * has to be choosen in that way that
   * high(TanHBuffer) / TanTableScaling is at least >= 2.6 (see SigmoidApprox
   * for that reason)
   *
   * 25000 ~ high(TanHBuffer) / 2.6
   *)
  TanTableScaling = 25000;

Procedure InitTanH();
Var
  i: Integer;
Begin
  For i := 0 To high(TanHBuffer) Do Begin
    TanHBuffer[i] := tanh(i / TanTableScaling);
  End;
End;

Function Sigmoid(x: Single): Single;
Var
  y: integer;
{$IFDEF SigmoidTableInterpolated}
  xx: Single;
  //  s: Integer;
{$ENDIF}
Begin
{$IFDEF SigmoidTableInterpolated}
  // -- Lookup mit Interpolation zwischen den Discreten stellen
  (*
    This code has one branch less, which should in theory be faster as the CPU Pipeline will less often thrown away
    but at least by testing with deterministic0.ini the expected results could not be reproduced.
    The code was 1 to 2 seconds slower. So i keept the old design and only show the "test" version within the comment.
  s := ord(x > 0.0) - ord(x < 0.0); // Calculate Sign of x
  x := s * x; // x := abs(x);
  x := x * TanTableScaling;
  y := trunc(x);
  If y < high(TanHBuffer) Then Begin
    xx := x - y; // [0.. 1[
    result := s * (TanHBuffer[y] * (1 - xx) + TanHBuffer[y + 1] * xx);
  End
  Else Begin
    result := s;
  End;
  // *)
  If x < 0 Then Begin
    x := -x;
    x := x * TanTableScaling;
    y := trunc(x);
    If y >= high(TanHBuffer) Then Begin
      result := -1.0;
    End
    Else Begin
      xx := x - y; // [0.. 1[
      result := -(TanHBuffer[y] * (1 - xx) + TanHBuffer[y + 1] * xx);
    End;
  End
  Else Begin
    x := x * TanTableScaling;
    y := trunc(x);
    If y >= high(TanHBuffer) Then Begin
      result := 1.0;
    End
    Else Begin
      xx := x - y; // [0.. 1[
      result := (TanHBuffer[y] * (1 - xx) + TanHBuffer[y + 1] * xx);
    End;
  End;
  // *)
{$ELSE}
  // -- Einfache Lookup version
  If x < 0 Then Begin
    y := trunc((-x) * TanTableScaling);
    If y > high(TanHBuffer) Then Begin
      result := -1.0;
    End
    Else Begin
      result := -TanHBuffer[y];
    End;
  End
  Else Begin
    y := trunc(x * TanTableScaling);
    If y > high(TanHBuffer) Then Begin
      result := 1.0;
    End
    Else Begin
      result := TanHBuffer[y];
    End;
  End;
{$ENDIF}
End;
{$ENDIF}

{$IFDEF SigmoidXdix1plusX}

Function Sigmoid(x: Single): Single;
Begin
  If x < 0 Then Begin
    result := X / (1 - x);
  End
  Else Begin
    result := X / (1 + x);
  End;
End;
{$ENDIF}

(*
 * Source:  https://www.musicdsp.org/en/latest/Other/238-rational-tanh-approximation.html?highlight=tanh
 * Autor:  cschueler
 *)
{$IFDEF SigmoidApprox}

Function Sigmoid(x: Single): Single;
Var
  y: Single;
Begin
  //result := tanh(x); -- This is really slow (see: https://forum.lazarus.freepascal.org/index.php?topic=47937.50)
  (*
   * If you do the analytical math, sigmoid(x) for x in [-3 .. 3]
   * stays perfect in [-1 .. 1] as (x * (27 + x * x)) / (27 + 9 * x * x) is
   * 1 for x = 3, and -1 for x = -3 with a maximum difference to tanh(x) at
   * x = +- 1.56603 with arround +-2.352% (see zero crossings of derivative of:
   * (x * (27 + x * x)) / (27 + 9 * x * x) - tanh(x) )
   * additional sigmoid can be cropped to +-1 at x = +-3 with C0 / C1 / C2 continuity.
   *
   * But in a computer with all its rounding / IEEE errors it could be that
   * result is slightly bigger / lower than wanted
   * => as the simulation needs sigmoid(x) to be exactly in [-1 .. 1] we have 2 options here:
   *  -Option 1: Clamp the result to [-1 .. 1]
   *   -> this will need further 2 comparisons on each evaluation of Sigmoid
   *      as sigmoid is called massivly in the simulator this is "too" much.
   *  -Option 2: Clamp the range to +-2.6
   *   -> Sigmoid(+-2.6) is +-0.999 and tanh(+-2.6) is 0.989 clamping here to 1
   *      gives a error of 1.1% which is still better then the above worst of 2.352%.
   *      Due to the discret evaluations we do not have C0 / C1 / C2 continuity
   *      anyways so this could be accepted ;)
   *)
  If x <= -2.6 Then Begin // Orig code has had -3 here
    result := -1;
  End
  Else Begin
    If x >= 2.6 Then Begin // Orig code has had 3 here
      result := 1;
    End
    Else Begin
      //y := sqr(x);
      y := x * x; // Akkording to runtests x*x is actually faster then sqr(x)
      result := (x * (27 + y)) / (27 + 9 * y);
      (* -- This is "More" correct but slower than option 2 (see above)
        If result > 1.0 Then Begin
          result := 1.0;
        End
        Else Begin
          If result < -1.0 Then Begin
            result := -1.0;
          End;
        End;
       *)
    End;
  End;
End;
{$ENDIF}

Procedure Nop();
Begin

End;

Function prettyTime(TimeInMs: int64): String; // Code entliehen aus CCM
Var
  suffix: String;
  rest: int64;
  Time_In_Seconds: int64;
Begin
  Time_In_Seconds := TimeInMs Div 1000;
  If Time_in_Seconds = 0 Then Begin
    result := inttostr(TimeInMs) + 'ms';
    exit;
  End;
  suffix := 's';
  rest := 0;
  If Time_In_Seconds > 60 Then Begin
    suffix := 'min';
    rest := Time_In_Seconds Mod 60;
    Time_In_Seconds := Time_In_Seconds Div 60;
  End;
  If Time_In_Seconds > 60 Then Begin
    suffix := 'h';
    rest := Time_In_Seconds Mod 60;
    Time_In_Seconds := Time_In_Seconds Div 60;
  End;
  If (Time_In_Seconds > 24) And (suffix = 'h') Then Begin
    suffix := 'd';
    rest := Time_In_Seconds Mod 24;
    Time_In_Seconds := Time_In_Seconds Div 24;
  End;
  If suffix <> 's' Then Begin
    If rest < 10 Then Begin
      result := inttostr(Time_In_Seconds) + ':0' + inttostr(rest) + suffix;
    End
    Else Begin
      result := inttostr(Time_In_Seconds) + ':' + inttostr(rest) + suffix;
    End;
  End
  Else Begin
    result := inttostr(Time_In_Seconds) + suffix;
  End;
End;

Function FixPathDelimeter(Path: String): String;
Var
  i: Integer;
Begin
  // No matter which pathdelim the user enteres (Linux or Windows style) the correct will be choosen.
  result := Path;
  For i := 1 To length(result) Do Begin
    If result[i] In AllowDirectorySeparators Then Begin
      result[i] := PathDelim;
    End;
  End;
End;

Const
  NormalizedCoords: Array[0..8] Of TCoord = (
    (x: - 1; y: - 1), // SW
    (x: 0; y: - 1), // S
    (x: 1; y: - 1), // SE
    (x: - 1; y: 0), // W
    (x: 0; y: 0), // CENTER
    (x: 1; y: 0), // E
    (x: - 1; y: 1), // NW
    (x: 0; y: 1), // N
    (x: 1; y: 1) // NE
    );

Function asNormalizedCoord(Const Dir: TCompass): TCoord; // (-1, -0, 1, -1, 0, 1)
Begin
  result := NormalizedCoords[integer(dir)];
End;

Function Coord(x, y: integer): TCoord;
Begin
  result.x := x;
  result.y := y;
End;

Operator + (a, b: TCoord): TCoord;
Begin
  result.x := a.x + b.x;
  result.y := a.y + b.y;
End;

Operator - (a, b: TCoord): TCoord;
Begin
  result.x := a.x - b.x;
  result.y := a.y - b.y;
End;

Operator * (a: TCoord; s: integer): TCoord;
Begin
  result.x := a.x * s;
  result.y := a.y * s;
End;

Operator + (a: TCoord; d: TCompass): TCoord;
Begin
  result := a + asNormalizedCoord(d);
End;

Operator - (a: TCoord; d: TCompass): TCoord;
Begin
  result := a - asNormalizedCoord(d);
End;

Operator = (a, b: TCoord): Boolean;
Begin
  result := (a.x = b.x) And (a.y = b.y);
End;

// This is a utility function used when inspecting a local neighborhood around
// some location. This function feeds each valid (in-bounds) location in the specified
// neighborhood to the specified function. Locations include self (center of the neighborhood).

Procedure visitNeighborhood(Const loc, dim: TCoord; Const radius: float; Const f: TCoordProcedure; UserData: Pointer);
Var
  ii, i, j, x, y: integer;
Begin
  For i := -trunc(radius) To +trunc(radius) Do Begin
    ii := sqr(i);
    For j := -trunc(radius) To +trunc(radius) Do Begin
      If ii + sqr(j) <= sqr(radius) Then Begin
        x := loc.x + i;
        y := loc.y + j;
        If (x >= 0) And (x < dim.x) And (y >= 0) And (y < Dim.Y) Then Begin
          f(coord(x, y), UserData);
        End;
      End;
    End;
  End;
End;

{ TCoordHelper }

Function TCoordHelper.length: integer;
Begin
  result := trunc(sqrt(x * x + y * y)); // round down
End;

// Effectively, we want to check if a coordinate lies in a 45 degree region (22.5 degrees each side)
// centered on each compass direction. By first rotating the system by 22.5 degrees clockwise
// the boundaries to these regions become much easier to work with as they just align with the 8 axes.
// (Thanks to @Asa-Hopkins for this optimization -- drm)

Function TCoordHelper.asCompass: TCompass;
Const
  tanN = 13860;
  tanD = 33461;
  conversion: Array[0..15] Of TCompass = (S, CENTER, SW, N, SE, E, N, N,
    N, N, W, NW, N, NE, N, N);
Var
  xp, yp: int32_t;
Begin
  // tanN/tanD is the best rational approximation to tan(22.5) under the constraint that
  // tanN + tanD < 2^16 (to avoid overflows). We don't care about the scale of the result,
  // only the ratio of the terms. The actual rotation is (22.5 - 1.5e-8) degrees, whilst
  // the closest a pair of int16_t's come to any of these lines is 8e-8 degrees, so the result is exact

  xp := x * tanD + y * tanN;
  yp := y * tanD - x * tanN;

  // We can easily check which side of the four boundary lines
  // the point now falls on, giving 16 cases, though only 9 are
  // possible.
  result := conversion[ord(yp > 0) * 8 + ord(xp > 0) * 4 + ord(yp > xp) * 2 + ord(yp >= -xp)];
End;

Function TCoordHelper.Init: TCoord;
Begin
  result.x := 0;
  result.y := 0;
End;

Function TCoordHelper.Init(ax, ay: integer): TCoord;
Begin
  result.x := ax;
  result.y := ay;
End;

Function TCoordHelper.IsNormalized: Boolean;
Begin
  result := (x >= -1) And (x <= 1) And (y >= -1) And (y <= 1);
End;

Function TCoordHelper.normalize: TCoord;
Begin
  result := asNormalizedCoord(asCompass());
End;

// This rotates a Dir value by the specified number of steps. There are
// eight steps per full rotation. Positive values are clockwise; negative
// values are counterclockwise. E.g., rotate(4) returns a direction 90
// degrees to the right.
Const
  rotations: Array[0..71] Of TCompass =
  (SW, W, NW, N, NE, E, SE, S,
    S, SW, W, NW, N, NE, E, SE,
    SE, S, SW, W, NW, N, NE, E,
    W, NW, N, NE, E, SE, S, SW,
    CENTER, CENTER, CENTER, CENTER, CENTER, CENTER, CENTER, CENTER,
    E, SE, S, SW, W, NW, N, NE,
    NW, N, NE, E, SE, S, SW, W,
    N, NE, E, SE, S, SW, W, NW,
    NE, E, SE, S, SW, W, NW, N);

Function rotate(Const aCompass: TCompass; n: integer): TCompass;
Var
  tmp1: integer;
Begin
  While n < 0 Do
    n := n + 8;
  tmp1 := integer(aCompass) * 8 + (n Mod 8);
  assert(tmp1 >= 0);
  assert(tmp1 <= high(rotations));
  result := rotations[tmp1];
End;

Function rotate90DegCW(Const aCompass: TCompass): TCompass;
Begin
  result := rotate(aCompass, 2);
End;

Function rotate90DegCCW(Const aCompass: TCompass): TCompass;
Begin
  result := rotate(aCompass, -2);
End;

Function random8(Const randomUint: RandomUintGenerator): TCompass;
Begin
  (*
   * giving a Random TCompass could give a 1 in 8 Chance for Center -> Fail
   *)
  result := rotate(N, randomUint.RndRange(0, 7));
  assert(integer(result) <= 8);
End;

{$IFDEF SigmoidTable}
Initialization
  InitTanH();
{$ENDIF}

End.

