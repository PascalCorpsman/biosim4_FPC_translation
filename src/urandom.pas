Unit urandom;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

Const
  RANDOM_UINT_MAX = $FFFFFFFF;

Type

  { RandomUintGenerator }

  RandomUintGenerator = Object
  private
    // for the Marsaglia algorithm
    rngx: uint32;
    rngy: uint32;
    rngz: uint32;
    rngc: uint32;
    // for the Jenkins algorithm
    a, b, c, d: uint32;
  public
    Procedure initialize(InitSeedOffset: integer); // must be called to seed the RNG
    Function Rnd(): uint32_t;
    Function RndRange(min, max: unsigned): unsigned;
  End;

Implementation

Uses uparams;

// This file provides a random number generator (RNG) for the main thread
// and child threads. The global-scoped RNG instance named randomUint is declared
// "threadprivate" for OpenMP, meaning that each thread will instantiate its
// own private instance. A side effect is that the object cannot have a
// non-trivial ctor, so it has an initialize() member function that must be
// called to seed the RNG instance, typically in simulator() in simulator.cpp
// after the config parameters have been read. The biosim4.ini parameters named
// "deterministic" and "RNGSeed" determine whether to initialize the RNG with
// a user-defined deterministic seed or with a random seed.


// If parameter p.deterministic is true, we'll initialize the RNG with
// the seed specified in parameter p.RNGSeed, otherwise we'll initialize
// the RNG with a random seed. This initializes both the Marsaglia and
// the Jenkins algorithms. The member function operator() determines
// which algorithm is actually used.

Procedure RandomUintGenerator.initialize(InitSeedOffset: integer);
Begin

  If (p.deterministic) Then Begin
    // Initialize Marsaglia. Overflow wrap-around is ok. We just want
    // the four parameters to be unrelated. In the extremely unlikely
    // event that a coefficient is zero, we'll force it to an arbitrary
    // non-zero value. Each thread uses a different seed, yet
    // deterministic per-thread.
    rngx := p.RNGSeed + 123456789 + InitSeedOffset;
    rngy := p.RNGSeed + 362436000 + InitSeedOffset;
    rngz := p.RNGSeed + 521288629 + InitSeedOffset;
    rngc := p.RNGSeed + 7654321 + InitSeedOffset;
    If rngx = 0 Then rngx := 123456789;
    If rngy = 0 Then rngy := 123456789;
    If rngz = 0 Then rngz := 123456789;
    If rngc = 0 Then rngc := 123456789;

    // Initialize Jenkins determinstically per-thread:
    a := $F1EA5EED;
    b := p.RNGSeed + InitSeedOffset;
    c := p.RNGSeed + InitSeedOffset;
    d := p.RNGSeed + InitSeedOffset;
    If (b = 0) Then Begin
      b := d + 123456789;
      c := d + 123456789;
    End;
  End
  Else Begin
    // Non-deterministic initialization.
    // First we will get a random number from the built-in mt19937
    // (Mersenne twister) generator and use that to derive the
    // starting coefficients for the Marsaglia and Jenkins RNGs.
    // We'll seed mt19937 with time(), but that has a coarse
    // resolution and multiple threads might be initializing their
    // instances at nearly the same time, so we'll add the thread
    // number to uniquely seed mt19937 per-thread.

    // Initialize Marsaglia, but don't let any of the values be zero:
    Repeat
      rngx := Random(high(uint32_t));
    Until (rngx <> 0);
    Repeat
      rngy := Random(high(uint32_t));
    Until (rngy <> 0);
    Repeat
      rngz := Random(high(uint32_t));
    Until (rngz <> 0);
    Repeat
      rngc := Random(high(uint32_t));
    Until (rngc <> 0);

    // Initialize Jenkins, but don't let any of the values be zero:
    a := $F1EA5EED;
    Repeat
      b := Random(high(uint32_t));
      c := b;
      d := b;
    Until (b <> 0);
  End;
End;

// This returns a random 32-bit integer. Neither the Marsaglia nor the Jenkins
// algorithms are of cryptographic quality, but we don't need that. We just need
// randomness of shotgun quality. The Jenkins algorithm is the fastest.
// The Marsaglia algorithm is from http://www0.cs.ucl.ac.uk/staff/d.jones/GoodPracticeRNG.pdf
// where it is attributed to G. Marsaglia.

Function RandomUintGenerator.Rnd: uint32_t;

  Function rot32(x, k: uint32_t): uint32_t Inline;
  Begin
    result := (((x) Shl (k)) Or ((x) Shr (32 - (k))));
  End;

Var
  e: uint32;
Begin
  //    if (false) {
  //        // Marsaglia algorithm
  //        uint64_t t, a = 698769069ULL;
  //        rngx = 69069 * rngx + 12345;
  //        rngy ^= (rngy << 13);
  //        rngy ^= (rngy >> 17);
  //        rngy ^= (rngy << 5); /* y must never be set to zero! */
  //        t = a * rngz + rngc;
  //        rngc = (t >> 32);/* Also avoid setting z=c=0! */
  //        return rngx + rngy + (rngz = t);
  //    } else {
          // Jenkins algorithm

  e := a - rot32(b, 27);
  a := b Xor rot32(c, 17);
  b := c + d;
  c := d + e;
  d := e + a;
  result := d;
  //    }
End;

// Returns an unsigned integer between min and max, inclusive.
// Sure, there's a bias when using modulus operator where (max - min) is not
// a power of two, but we don't care if we generate one value a little more
// often than another. Our randomness does not have to be high quality.
// We do care about speed, because this will get called inside deeply nested
// inner loops. Alternatively, we could create a standard C++ "distribution"
// object here, but we would first need to investigate its overhead.

Function RandomUintGenerator.RndRange(min, max: unsigned): unsigned;
Begin
  assert(max >= min);
  Result := (Rnd() Mod (max - min + 1)) + min;
End;

End.

