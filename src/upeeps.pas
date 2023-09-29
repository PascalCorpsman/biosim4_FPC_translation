Unit upeeps;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, uindiv, ubasicTypes;

{$I c_types.inc}

// This class keeps track of alive and dead Indiv's and where they
// are in the Grid.
// Peeps allows spawning a live Indiv at a random or specific location
// in the grid, moving Indiv's from one grid location to another, and
// killing any Indiv.
// All the Indiv instances, living and dead, are stored in the private
// .individuals member. The .cull() function will remove dead members and
// replace their slots in the .individuals container with living members
// from the end of the container for compacting the container.
// Each Indiv has an identifying index in the range 1..0xfffe that is
// stored in the Grid at the location where the Indiv resides, such that
// a Grid element value n refers to .individuals[n]. Index value 0 is
// reserved, i.e., .individuals[0] is not a valid individual.
// This class does not manage properties inside Indiv except for the
// Indiv's location in the grid and its aliveness.
Type
  TMoveQueue = Record
    index: uint16_t;
    Loc: TCoord;
  End;

  { TPeeps }

  TPeeps = Class
  private
    individuals: Array Of TIndiv; // Index value 0 is reserved
    deathQueue: Array Of uint16_t;
    deathQueueLen: integer;
    moveQueue: Array Of TMoveQueue;
    moveQueueLen: integer;
    Function getIndividual(index: uint16_t): PIndiv;
  public
    // Direct access:
    Property Individual[index: uint16_t]: PIndiv read getIndividual; default;
    Constructor Create(); // makes zero individuals
    Destructor Destroy(); override;

    Procedure init(population: unsigned);
    Procedure queueForDeath(Indiv: PIndiv);
    Procedure drainDeathQueue();
    Procedure queueForMove(Indiv: PIndiv; newLoc: TCoord);
    Procedure drainMoveQueue();
    Function deathQueueSize(): uint16;
    // getIndiv() does no error checking -- check first that loc is occupied
    Function getIndiv(loc: TCoord): PIndiv;
  End;

Var
  peeps: TPeeps = Nil; // The container of all the individuals in the population

Implementation

Uses uomp, ugrid;

Function TPeeps.getIndividual(index: uint16_t): PIndiv;
Begin
  result := @individuals[index];
End;

Constructor TPeeps.Create;
Begin
  moveQueue := Nil;
  moveQueueLen := 0;
  deathQueue := Nil;
  deathQueueLen := 0;
End;

Destructor TPeeps.Destroy;
Var
  i: Integer;
Begin
  setlengtH(deathQueue, 0);
  deathQueueLen := 0;
  setlengtH(moveQueue, 0);
  moveQueueLen := 0;
  For i := 0 To high(individuals) Do Begin
    individuals[i].free;
  End;
End;

Procedure TPeeps.init(population: unsigned);
Var
  i: Integer;
Begin
  // Index 0 is reserved, so add one:
  setlength(individuals, population + 1);
  For i := 0 To high(individuals) Do Begin
    individuals[i] := TIndiv.Create();
  End;
  individuals[0].alive := false; // Das 1. Element ist nur ein Platzhalter, warum auch immer, aber es wird mal "Tot" initialisiert !
  setlength(deathQueue, population); // Give enough space for everyone to die
  setlength(moveQueue, population); // Give enough space for everyone to move
End;

// Safe to call during multithread mode.
// Indiv will remain alive and in-world until end of sim step when
// drainDeathQueue() is called. It's ok if the same agent gets
// queued for death multiple times. It does not make sense to
// call this function for agents already dead.

Procedure TPeeps.queueForDeath(Indiv: PIndiv);
Begin
  assert(indiv^.alive);
  EnterCodePoint(cpqueueForDeath);
  Try
    deathQueue[deathQueueLen] := indiv^.index;
    inc(deathQueueLen);
  Finally
    LeaveCodePoint(cpqueueForDeath);
  End;
End;

// Called in single-thread mode at end of sim step. This executes all the
// queued deaths, removing the dead agents from the grid.

Procedure TPeeps.drainDeathQueue;
Var
  index: Integer;
Begin
  For index := 0 To deathQueueLen - 1 Do Begin
    grid.set_(individuals[deathQueue[index]].loc, 0);
    individuals[deathQueue[index]].alive := false;
  End;
  deathQueueLen := 0;
End;

// Safe to call during multithread mode. Indiv won't move until end
// of sim step when drainMoveQueue() is called. Should only be called
// for living agents. It's ok if multiple agents are queued to move
// to the same location; only the first one will actually get moved.

Procedure TPeeps.queueForMove(Indiv: PIndiv; newLoc: TCoord);
Begin
  assert(indiv^.alive);
  EnterCodePoint(cpqueueForMove);
  Try
    moveQueue[moveQueueLen].index := Indiv^.index;
    moveQueue[moveQueueLen].Loc := newLoc;
    inc(moveQueueLen);
  Finally
    LeaveCodePoint(cpqueueForMove);
  End;
End;

// Called in single-thread mode at end of sim step. This executes all the
// queued movements. Each movement is typically one 8-neighbor cell distance
// but this function can move an individual any arbitrary distance. It is
// possible that an agent queued for movement was recently killed when the
// death queue was drained, so we'll ignore already-dead agents.

Procedure TPeeps.drainMoveQueue;
Var
  moveRecord: Integer;
  indiv: PIndiv;
  newLoc: TCoord;
  moveDir: TCompass;
Begin
  For moveRecord := 0 To moveQueueLen - 1 Do Begin
    indiv := peeps.getIndividual(moveQueue[moveRecord].index);
    If (indiv^.alive) Then Begin
      newLoc := moveQueue[moveRecord].Loc;
      moveDir := (newLoc - indiv^.loc).asCompass();
      assert(moveDir <> CENTER);
      If (grid.isEmptyAt(newLoc)) Then Begin
        grid.Set_(indiv^.loc, 0);
        grid.Set_(newLoc, indiv^.index);
        indiv^.loc := newLoc;
        indiv^.lastMoveDir := moveDir;
      End;
    End;
  End;
  moveQueueLen := 0;
End;

Function TPeeps.deathQueueSize: uint16;
Begin
  result := deathQueueLen;
End;

Function TPeeps.getIndiv(loc: TCoord): PIndiv;
Begin
  result := @individuals[grid.at(loc)];
End;

End.

