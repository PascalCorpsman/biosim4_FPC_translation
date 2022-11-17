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
    moveQueue: Array Of TMoveQueue;
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

Implementation

Uses usimulator, uomp;

Function TPeeps.getIndividual(index: uint16_t): PIndiv;
Begin
  result := @individuals[index];
End;

Constructor TPeeps.Create;
Begin
  moveQueue := Nil;
End;

Destructor TPeeps.Destroy;
Begin

End;

Procedure TPeeps.init(population: unsigned);
Begin
  // Index 0 is reserved, so add one:
  setlength(individuals, population + 1);
End;

// Safe to call during multithread mode.
// Indiv will remain alive and in-world until end of sim step when
// drainDeathQueue() is called. It's ok if the same agent gets
// queued for death multiple times. It does not make sense to
// call this function for agents already dead.

Procedure TPeeps.queueForDeath(Indiv: PIndiv);
Begin
  assert(indiv^.alive);
  //    #pragma omp critical
  //    {
  EnterCodePoint(cpqueueForDeath);
  Try
    setlength(deathQueue, high(deathQueue) + 2);
    deathQueue[high(deathQueue)] := indiv^.index;
  Finally
    LeaveCodePoint(cpqueueForDeath);
  End;
  //    }
End;

// Called in single-thread mode at end of sim step. This executes all the
// queued deaths, removing the dead agents from the grid.

Procedure TPeeps.drainDeathQueue;
Var
  index: Integer;
Begin
  For index := 0 To high(deathQueue) Do Begin
    grid.set_(individuals[index].loc, 0);
    individuals[index].alive := false;
  End;
  setlength(deathQueue, 0);
End;

// Safe to call during multithread mode. Indiv won't move until end
// of sim step when drainMoveQueue() is called. Should only be called
// for living agents. It's ok if multiple agents are queued to move
// to the same location; only the first one will actually get moved.

Procedure TPeeps.queueForMove(Indiv: PIndiv; newLoc: TCoord);
Begin
  assert(indiv^.alive);
  //    #pragma omp critical
  //    {
  EnterCodePoint(cpqueueForMove);
  Try
    setlength(moveQueue, high(moveQueue) + 2);
    moveQueue[high(moveQueue)].index := Indiv^.index;
    moveQueue[high(moveQueue)].Loc := newLoc;
    assert(newLoc <> indiv^.loc);
  Finally
    LeaveCodePoint(cpqueueForMove);
  End;
  //    }
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
  moveDir: TDir;
Begin
  For moveRecord := 0 To high(moveQueue) Do Begin
    indiv := peeps.getIndividual(moveQueue[moveRecord].index);
    If (indiv^.alive) Then Begin
      newLoc := moveQueue[moveRecord].Loc;
      moveDir := (newLoc - indiv^.loc).asDir();
      assert(moveDir.asInt() <> integer(CENTER));
      If (grid.isEmptyAt(newLoc)) Then Begin
        grid.Set_(indiv^.loc, 0);
        grid.Set_(newLoc, indiv^.index);
        indiv^.loc := newLoc;
        indiv^.lastMoveDir := moveDir;
      End;
    End;
  End;
  setlength(moveQueue, 0);
End;

Function TPeeps.deathQueueSize: uint16;
Begin
  result := length(deathQueue);
End;

Function TPeeps.getIndiv(loc: TCoord): PIndiv;
Begin
  result := @individuals[grid.at(loc)];
End;

End.

