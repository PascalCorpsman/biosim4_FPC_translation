Unit ubasicTypes;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

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

//
//extern bool unitTestBasicTypes();
Type
  TCompass = (SW = 0, S, SE, W, CENTER, E, NW, N, NE);


  //struct Dir;
  //struct Coord;
  //struct Polar;

  // Supports the eight directions in enum class Compass plus CENTER.

  { TDir }

  TDir = Packed Object // TODO: Das kann eigentlich komplett weg und wir basteln nur Helper Funktionen für TCompass
  private
    dir9: TCompass;
  public
    Function Dir(aDir: TCompass = CENTER): TDir static;

    Function random8(): TDir static;

    //    Dir(Compass dir = Compass::CENTER) : dir9{dir} {}
    //    Dir& operator=(const Compass& d) { dir9 = d; return *this; }
    Function asInt(): uint8;
    //    Polar asNormalizedPolar() const;

    //    Dir rotate(int n = 0) const;
    Function rotate(n: integer = 0): TDir;
    Function rotate90DegCW(): Tdir;
    Function rotate90DegCCW(): TDir;
    //    Dir rotate180Deg() const { return rotate(4); }

    //    bool operator==(Compass d) const { return asInt() == (uint8_t)d; }
    //    bool operator!=(Compass d) const { return asInt() != (uint8_t)d; }
    //    bool operator==(Dir d) const { return asInt() == d.asInt(); }
    //    bool operator!=(Dir d) const { return asInt() != d.asInt(); }

  End;


  // Coordinates range anywhere in the range of int16_t. Coordinate arithmetic
  // wraps like int16_t. Can be used, e.g., for a location in the simulator grid, or
  // for the difference between two locations.
  //struct __attribute__((packed)) Coord {

  { TCoord }

  TCoord = Packed Object // Umstellen auf Record mit Typehelpern
    //    Coord(int16_t x0 = 0, int16_t y0 = 0) : x{x0}, y{y0} { }
    //    bool isNormalized() const { return x >= -1 && x <= 1 && y >= -1 && y <= 1; }
    //    Coord normalize() const;
    //    Polar asPolar() const;

    //    bool operator==(Coord c) const { return x == c.x && y == c.y; }
    //    bool operator!=(Coord c) const { return x != c.x || y != c.y; }
    //    Coord operator+(Coord c) const { return Coord{(int16_t)(x + c.x), (int16_t)(y + c.y)}; }
    //    Coord operator-(Coord c) const { return Coord{(int16_t)(x - c.x), (int16_t)(y - c.y)}; }
    //    Coord operator*(int a) const { return Coord{(int16_t)(x * a), (int16_t)(y * a)}; }
    //    Coord operator+(Dir d) const { return *this + d.asNormalizedCoord(); }
    //    Coord operator-(Dir d) const { return *this - d.asNormalizedCoord(); }
    //
    //    float raySameness(Coord other) const; // returns -1.0 (opposite) .. 1.0 (same)
    //    float raySameness(Dir d) const; // returns -1.0 (opposite) .. 1.0 (same)
  public
    x: int16;
    y: int16;
    Function length(): integer;
    Function asDir(): TDir;
  End;

  TCoordArray = Array Of TCoord;

  //// Polar magnitudes are signed 32-bit integers so that they can extend across any 2D
  //// area defined by the Coord class.
  //struct __attribute__((packed)) Polar {
  //    explicit Polar(int mag0 = 0, Compass dir0 = Compass::CENTER)
  //         : mag{mag0}, dir{Dir{dir0}} { }
  //    explicit Polar(int mag0, Dir dir0)
  //         : mag{mag0}, dir{dir0} { }
  //    Coord asCoord() const;
  //public:
  //    int mag;
  //    Dir dir;
  //};
  //
  //} // end namespace BS
  //
  //#endif // BASICTYPES_H_INCLUDED

  TCoordProcedure = Procedure(Coord: TCoord);

Function asNormalizedCoord(Const Dir: TDir): TCoord; // (-1, -0, 1, -1, 0, 1)

Procedure Nop();

Procedure visitNeighborhood(loc: TCoord; radius: float; f: TCoordProcedure);

Function Coord(x, y: integer): TCoord;

Operator + (a: TCoord; d: TDir): TCoord;
Operator - (a: TCoord; d: TDir): TCoord;
Operator - (a, b: TCoord): TCoord;
Operator + (a, b: TCoord): TCoord;
Operator = (a, b: TCoord): Boolean;
Operator = (a: TDir; b: TCompass): Boolean;

Implementation

Uses urandom, Math, uparams;

Procedure Nop();
Begin

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

Function asNormalizedCoord(Const Dir: TDir): TCoord; // (-1, -0, 1, -1, 0, 1)
Begin
  result := NormalizedCoords[dir.asInt()];
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

Operator + (a: TCoord; d: TDir): TCoord;
Begin
  result := a + asNormalizedCoord(d);
End;

Operator - (a: TCoord; d: TDir): TCoord;
Begin
  result := a - asNormalizedCoord(d);
End;

Operator = (a, b: TCoord): Boolean;
Begin
  result := (a.x = b.x) And (a.y = b.y);
End;

Operator = (a: TDir; b: TCompass): Boolean;
Begin
  result := a.asInt() = integer(b);
End;

// This is a utility function used when inspecting a local neighborhood around
// some location. This function feeds each valid (in-bounds) location in the specified
// neighborhood to the specified function. Locations include self (center of the neighborhood).

Procedure visitNeighborhood(loc: TCoord; radius: float; f: TCoordProcedure);
Var
  dy, y, extentY, dx, x: Integer;
Begin
  For dx := -round(min(radius, loc.x)) To round(min(radius, (p.sizeX - loc.x) - 1)) Do Begin
    x := loc.x + dx;
    assert((x >= 0) And (x < p.sizeX));
    extentY := round(sqrt(max(0, radius * radius - dx * dx)));
    For dy := -round(min(extentY, loc.y)) To round(min(extentY, (p.sizeY - loc.y) - 1)) Do Begin
      y := loc.y + dy;
      assert((y >= 0) And (y < p.sizeY));
      f(Coord(x, y));
    End;
  End;
End;

// TODO: Wenn alles mal läuft, ersetzen wir die Routine oben durch eine die "echte" Kreise macht und auf die Wurzel verzichtet
//Procedure visitNeighborhood(loc: TCoord; radius: float; f: TCoordProcedure);
//Var
//  i, j, x, y: integer;
//Begin
//  For i := -round(radius) To +round(radius) Do Begin
//    For j := -round(radius) To +round(radius) Do Begin
//      If sqr(i) + sqr(j) <= sqr(radius) Then Begin
//        x := loc.x + i;
//        y := loc.y + j;
//        If (x >= 0) And (x < p.sizeX) And (y >= 0) And (y < p.sizeY) Then Begin
//          f(coord(x, y));
//        End;
//      End;
//    End;
//  End;
//End;

// basicTypes.cpp

//#include <cassert>
//#include "basicTypes.h"
//
//namespace BS {


  { TCoord }

Function TCoord.length: integer;
Begin
  result := trunc(sqrt(x * x + y * y)); // round down
End;

// Effectively, we want to check if a coordinate lies in a 45 degree region (22.5 degrees each side)
// centered on each compass direction. By first rotating the system by 22.5 degrees clockwise
// the boundaries to these regions become much easier to work with as they just align with the 8 axes.
// (Thanks to @Asa-Hopkins for this optimization -- drm)

Function TCoord.asDir: TDir;
Const
  tanN = 13860;
  tanD = 33461;
  conversion: Array[0..15] Of TCompass = (S, CENTER, SW, N, SE, E, N, N,
    N, N, W, NW, N, NE, N, N);
Var
  xp, yp: int32_t;
Begin
  // tanN/tanD is the best rational approximation to tan(22.5) under the constraint that
  // tanN + tanD < 2**16 (to avoid overflows). We don't care about the scale of the result,
  // only the ratio of the terms. The actual rotation is (22.5 - 1.5e-8) degrees, whilst
  // the closest a pair of int16_t's come to any of these lines is 8e-8 degrees, so the result is exact

  xp := x * tanD + y * tanN;
  yp := y * tanD - x * tanN;

  // We can easily check which side of the four boundary lines
  // the point now falls on, giving 16 cases, though only 9 are
  // possible.
  result := result.Dir(conversion[ord(yp > 0) * 8 + ord(xp > 0) * 4 + ord(yp > xp) * 2 + ord(yp >= -xp)]);
End;

//Dir Dir::rotate(int n) const
//{
//    return rotations[asInt() * 8 + (n & 7)];
//}
//
//
///*
//    A normalized Coord is a Coord with x and y == -1, 0, or 1.
//    A normalized Coord may be used as an offset to one of the
//    8-neighbors.
//
//    A Dir value maps to a normalized Coord using
//
//       Coord { (d%3) - 1, (trunc)(d/3) - 1  }
//
//       0 => -1, -1  SW
//       1 =>  0, -1  S
//       2 =>  1, -1, SE
//       3 => -1,  0  W
//       4 =>  0,  0  CENTER
//       5 =>  1   0  E
//       6 => -1,  1  NW
//       7 =>  0,  1  N
//       8 =>  1,  1  NE
//*/

//
//
//Coord Dir::asNormalizedCoord() const
//{
//    return NormalizedCoords[asInt()];
//}
//
//
//Polar Dir::asNormalizedPolar() const
//{
//    return Polar{1, dir9};
//}
//
//
///*
//    A normalized Coord has x and y == -1, 0, or 1.
//    A normalized Coord may be used as an offset to one of the
//    8-neighbors.
//    We'll convert the Coord into a Dir, then convert Dir to normalized Coord.
//*/
//Coord Coord::normalize() const
//{
//    return asDir().asNormalizedCoord();
//}
//
//
//Polar Coord::asPolar() const
//{
//    return Polar{(int)length(), asDir()};
//}
//
//
///*
//    Compass values:
//
//        6  7  8
//        3  4  5
//        0  1  2
//*/
//Coord Polar::asCoord() const
//{
//    // (Thanks to @Asa-Hopkins for this optimized function -- drm)
//
//    // 3037000500 is 1/sqrt(2) in 32.32 fixed point
//    constexpr int64_t coordMags[9] = {
//        3037000500,  // SW
//        1LL << 32,   // S
//        3037000500,  // SE
//        1LL << 32,   // W
//        0,           // CENTER
//        1LL << 32,   // E
//        3037000500,  // NW
//        1LL << 32,   // N
//        3037000500   // NE
//    };
//
//    int64_t len = coordMags[dir.asInt()] * mag;
//
//    // We need correct rounding, the idea here is to add/sub 1/2 (in fixed point)
//    // and truncate. We extend the sign of the magnitude with a cast,
//    // then shift those bits into the lower half, giving 0 for mag >= 0 and
//    // -1 for mag<0. An XOR with this copies the sign onto 1/2, to be exact
//    // we'd then also subtract it, but we don't need to be that precise.
//
//    int64_t temp = ((int64_t)mag >> 32) ^ ((1LL << 31) - 1);
//    len = (len + temp) / (1LL << 32); // Divide to make sure we get an arithmetic shift
//
//    return NormalizedCoords[dir.asInt()] * len;
//}
//
//
//// returns -1.0 (opposite directions) .. +1.0 (same direction)
//// returns 1.0 if either vector is (0,0)
//float Coord::raySameness(Coord other) const
//{
//    int64_t mag = ((int64_t)x * x + y * y) * (other.x * other.x + other.y * other.y);
//    if (mag == 0) {
//        return 1.0; // anything is "same" as zero vector
//    }
//
//    return (x * other.x + y * other.y) / std::sqrt(mag);
//}
//
//
//// returns -1.0 (opposite directions) .. +1.0 (same direction)
//// returns 1.0 if self is (0,0) or d is CENTER
//float Coord::raySameness(Dir d) const
//{
//    return raySameness(d.asNormalizedCoord());
//}
//
//} // end namespace BS


{ TDir }

Function TDir.Dir(aDir: TCompass): TDir;
Begin
  Result.dir9 := aDir;
End;

Function TDir.random8: TDir;
Begin
  result := Dir(TCompass.N).rotate(randomUint.RndRange(0, 7));
  assert(integer(result) <= 8);
End;

Function TDir.asInt: uint8;
Begin
  result := uint8(dir9);
  assert(result <= 8);
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

Function TDir.rotate(n: integer): TDir;
Var
  tmp1: integer;

Begin
  While n < 0 Do
    n := n + 8;
  tmp1 := asInt() * 8 + (n Mod 8);
  assert(tmp1 >= 0);
  assert(tmp1 <= high(rotations));
  result := dir(rotations[tmp1]);
End;

Function TDir.rotate90DegCW: Tdir;
Begin
  result := rotate(2);
End;

Function TDir.rotate90DegCCW: TDir;
Begin
  result := rotate(-2);
End;

End.

