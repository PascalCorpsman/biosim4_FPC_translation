Unit uspawnNewGeneration;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, ugenome;

{$I c_types.inc}

Var
  LastSpawnTime: uint64 = 0; // Zum Aussmessen der Dauer der Berechnung einer Generation

  // Requires that the grid, signals, and peeps containers have been allocated.
  // This will erase the grid and signal layers, then create a new population in
  // the peeps container at random locations with random genomes.
Procedure initializeGeneration0();
Procedure initializeNewGeneration(Var parentGenomes: TGenomeArray);

// At this point, the deferred death queue and move queue have been processed
// and we are left with zero or more individuals who will repopulate the
// world grid.
// In order to redistribute the new population randomly, we will save all the
// surviving genomes in a container, then clear the grid of indexes and generate
// new individuals. This is inefficient when there are lots of survivors because
// we could have reused (with mutations) the survivors' genomes and neural
// nets instead of rebuilding them.
// Returns number of survivor-reproducers.
// Must be called in single-thread mode between generations.
Function spawnNewGeneration(generation, murderCount: unsigned; ThreadTimes: String): unsigned;

Implementation

Uses uSimulator, uparams, uindiv, uanalysis, ubasicTypes, math, urandom;

Type
  TBoolPair = Record
    first: Boolean;
    second: Float;
  End;

Procedure VisitOccupied(Coord: TCoord; UserData: Pointer);
Var
  occupiedCount: Pinteger;
Begin
  occupiedCount := UserData;
  If (grid.isOccupiedAt(Coord)) Then inc(occupiedCount^);
End;

Function passedSurvivalCriterion(indiv: PIndiv; challenge: unsigned): TBoolPair;
  Function Pair(First: Boolean; Second: Float): TBoolPair;
  Begin
    result.first := First;
    result.second := Second;
  End;
Const
  minNeighbors_CHALLENGE_CENTER_SPARSE = 5; // includes self
  maxNeighbors_CHALLENGE_CENTER_SPARSE = 8;
  minNeighbors_CHALLENGE_STRING = 22;
  maxNeighbors_CHALLENGE_STRING = 2;

Var
  tloc1, tloc, offset, safeCenter: tcoord;
  outerRadius, innerRadius, distance, radius: float;
  center, n, maxNumberOfBits, bits, Count: unsigned;
  barrierCenters: TCoordArray;
  minDistance: Single;
  onEdge: Boolean;
  occupiedCount, x, y, x1, y1: integer;
Begin
  result := Pair(false, 0.0);
  If (Not indiv^.alive) Then Begin
    exit;
  End;

  Case (challenge) Of
    // Survivors are those inside the circular area defined by
    // safeCenter and radius
    CHALLENGE_CIRCLE: Begin
        safeCenter := Coord(trunc(p.sizeX / 4.0), trunc(p.sizeY / 4.0));
        radius := p.sizeX / 4.0;

        offset := safeCenter - indiv^.loc;
        distance := offset.length();
        If distance <= radius Then Begin
          result := pair(true, (radius - distance) / radius);
          exit;
        End;
      End;

    // Survivors are all those on the right side of the arena
    CHALLENGE_RIGHT_HALF: Begin
        If indiv^.loc.x > p.sizeX Div 2 Then Begin
          result := Pair(true, 1);
          exit;
        End
      End;

    // Survivors are all those on the right quarter of the arena
    CHALLENGE_RIGHT_QUARTER: Begin
        If (indiv^.loc.x > p.sizeX Div 2 + p.sizeX Div 4) Then Begin
          result := Pair(true, 1);
          exit;
        End;
      End;

    // Survivors are all those on the left eighth of the arena
    CHALLENGE_LEFT_EIGHTH: Begin
        If indiv^.loc.x < p.sizeX Div 8 Then Begin
          result := Pair(true, 1);
          exit;
        End;
      End;

    // Survivors are those not touching the border and with exactly the number
    // of neighbors defined by neighbors and radius, where neighbors includes self
    CHALLENGE_STRING: Begin
        radius := 1.5;

        If (grid.isBorder(indiv^.loc)) Then Begin
          exit;
        End;

        occupiedCount := 0;
        visitNeighborhood(indiv^.loc, radius, @VisitOccupied, @occupiedCount);
        If (occupiedCount >= minNeighbors_CHALLENGE_STRING) And (occupiedCount <= maxNeighbors_CHALLENGE_STRING) Then Begin
          result := Pair(true, 1);
          exit;
        End;
      End;

    // Survivors are those within the specified radius of the center. The score
    // is linearly weighted by distance from the center.
    CHALLENGE_CENTER_WEIGHTED: Begin
        safeCenter := coord((p.sizeX Div 2), (p.sizeY Div 2));
        radius := p.sizeX / 3.0;

        offset := safeCenter - indiv^.loc;
        distance := offset.length();
        If distance <= radius Then Begin
          result := pair(true, (radius - distance) / radius);
          exit;
        End;
      End;

    // Survivors are those within the specified radius of the center
    CHALLENGE_CENTER_UNWEIGHTED: Begin
        safeCenter := Coord(p.sizeX Div 2, p.sizeY Div 2);
        radius := p.sizeX / 3.0;

        offset := safeCenter - indiv^.loc;
        distance := offset.length();
        If distance <= radius Then Begin
          result := Pair(true, 1.0);
          exit;
        End;
      End;

    // Survivors are those within the specified outer radius of the center and with
    // the specified number of neighbors in the specified inner radius.
    // The score is not weighted by distance from the center.
    CHALLENGE_CENTER_SPARSE: Begin
        safeCenter := Coord((p.sizeX Div 2), (p.sizeY Div 2));
        outerRadius := p.sizeX / 4.0;
        innerRadius := 1.5;


        offset := safeCenter - indiv^.loc;
        distance := offset.length();
        If (distance <= outerRadius) Then Begin
          occupiedCount := 0;
          visitNeighborhood(indiv^.loc, innerRadius, @VisitOccupied, @occupiedCount);
          If (occupiedCount >= minNeighbors_CHALLENGE_CENTER_SPARSE) And (occupiedCount <= maxNeighbors_CHALLENGE_CENTER_SPARSE) Then Begin
            result := pair(true, 1.0);
            exit;
          End;
        End;
      End;

    // Survivors are those within the specified radius of any corner.
    // Assumes square arena.
    CHALLENGE_CORNER: Begin
        If (p.sizeX <> p.sizeY) Then Begin
          Raise exception.Create('Width needs to be equal to height.');
        End;
        radius := p.sizeX / 8.0;

        distance := (Coord(0, 0) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, 1);
          exit;
        End;
        distance := (Coord(0, p.sizeY - 1) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, 1);
          exit;
        End;
        distance := (Coord(p.sizeX - 1, 0) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, 1);
          exit;
        End;
        distance := (Coord(p.sizeX - 1, p.sizeY - 1) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, 1);
          exit;
        End;
      End;

    // Survivors are those within the specified radius of any corner. The score
    // is linearly weighted by distance from the corner point.
    CHALLENGE_CORNER_WEIGHTED: Begin
        If (p.sizeX <> p.sizeY) Then Begin
          Raise exception.Create('Width needs to be equal to height.');
        End;
        radius := p.sizeX / 4.0;

        distance := (Coord(0, 0) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, (radius - distance) / radius);
          exit;
        End;
        distance := (Coord(0, p.sizeY - 1) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, (radius - distance) / radius);
          exit;
        End;
        distance := (Coord(p.sizeX - 1, 0) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, (radius - distance) / radius);
          exit;
        End;
        distance := (Coord(p.sizeX - 1, p.sizeY - 1) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := pair(true, (radius - distance) / radius);
          exit;
        End;
      End;

    // This challenge is handled in endOfSimStep(), where individuals may die
    // at the end of any sim step. There is nothing else to do here at the
    // end of a generation. All remaining alive become parents.
    CHALLENGE_RADIOACTIVE_WALLS: result := pair(true, 1.0);

    // Survivors are those touching any wall at the end of the generation
    CHALLENGE_AGAINST_ANY_WALL: Begin
        If (indiv^.loc.x = 0) Or (indiv^.loc.x = p.sizeX - 1) Or
          (indiv^.loc.y = 0) Or (indiv^.loc.y = p.sizeY - 1) Then Begin
          result := pair(true, 1.0);
          exit;
        End;
      End;

    // This challenge is partially handled in endOfSimStep(), where individuals
    // that are touching a wall are flagged in their Indiv record. They are
    // allowed to continue living. Here at the end of the generation, any that
    // never touch a wall will die. All that touched a wall at any time during
    // their life will become parents.
    CHALLENGE_TOUCH_ANY_WALL: Begin
        If (indiv^.challengeBits <> 0) Then Begin
          result := pair(true, 1.0);
          exit;
        End;
      End;

    // Everybody survives and are candidate parents, but scored by how far
    // they migrated from their birth location.
    CHALLENGE_MIGRATE_DISTANCE: Begin
        //requiredDistance := p.sizeX / 2.0;
        distance := (indiv^.loc - indiv^.birthLoc).length();
        distance := distance / (max(p.sizeX, p.sizeY));
        result := pair(true, distance);
        exit;
      End;

    // Survivors are all those on the left or right eighths of the arena
    CHALLENGE_EAST_WEST_EIGHTHS: Begin
        If (indiv^.loc.x < p.sizeX Div 8) Or (indiv^.loc.x >= (p.sizeX - (p.sizeX Div 8))) Then Begin
          result := pair(true, 1.0);
          exit;
        End;
      End;

    // Survivors are those within radius of any barrier center. Weighted by distance.
    CHALLENGE_NEAR_BARRIER: Begin

        //radius = 20.0;
        radius := p.sizeX / 2;
        //radius = p.sizeX / 4;

        barrierCenters := grid.getBarrierCenters();
        minDistance := 1E8;
        //            for (auto& center : barrierCenters) {
        For center := 0 To high(barrierCenters) Do Begin
          distance := (indiv^.loc - barrierCenters[center]).length();
          If (distance < minDistance) Then Begin
            minDistance := distance;
          End;
        End;
        If (minDistance <= radius) Then Begin
          result := pair(true, 1.0 - (minDistance / radius));
          exit;
        End;
      End;

    // Survivors are those not touching a border and with exactly one neighbor which has no other neighbor
    CHALLENGE_PAIRS: Begin
        onEdge := (indiv^.loc.x = 0) Or (indiv^.loc.x = p.sizeX - 1)
          Or (indiv^.loc.y = 0) Or (indiv^.loc.y = p.sizeY - 1);

        If (onEdge) Then exit;

        count := 0;
        For x := indiv^.loc.x - 1 To indiv^.loc.x + 1 Do Begin
          For y := indiv^.loc.y - 1 To indiv^.loc.y + 1 Do Begin
            tloc := Coord(x, y);
            If (tloc <> indiv^.loc) And grid.isInBounds(tloc) And grid.isOccupiedAt(tloc) Then Begin
              count := Count + 1;
              If (count = 1) Then Begin
                For x1 := tloc.x - 1 To tloc.x + 1 Do Begin
                  For y1 := tloc.y - 1 To tloc.y + 1 Do Begin
                    tloc1 := Coord(x1, y1);
                    If (tloc1 <> tloc) And (tloc1 <> indiv^.loc) And grid.isInBounds(tloc1) And grid.isOccupiedAt(tloc1) Then Begin
                      exit;
                    End;
                  End;
                End;
              End
              Else Begin
                exit;
              End;
            End;
          End;
        End;
        If (count = 1) Then Begin
          result := pair(true, 1.0);
          exit;
        End;
      End;

    // Survivors are those that contacted one or more specified locations in a sequence,
    // ranked by the number of locations contacted. There will be a bit set in their
    // challengeBits member for each location contacted.
    CHALLENGE_LOCATION_SEQUENCE: Begin
        count := 0;
        bits := indiv^.challengeBits;
        maxNumberOfBits := sizeof(bits) * 8;

        For n := 0 To maxNumberOfBits - 1 Do Begin
          If ((bits And (1 Shl n)) <> 0) Then Begin
            inc(count);
          End;
        End;
        If (count > 0) Then Begin
          result := pair(true, count / maxNumberOfBits);
          exit;
        End;
      End;

    // Survivors are all those within the specified radius of the NE corner
    CHALLENGE_ALTRUISM_SACRIFICE: Begin
        //float radius = p.sizeX / 3.0; // in 128^2 world, holds 1429 agents
        radius := p.sizeX / 4.0; // in 128^2 world, holds 804 agents
        //float radius = p.sizeX / 5.0; // in 128^2 world, holds 514 agents

        distance := (Coord(p.sizeX - p.sizeX Div 4, p.sizeY - p.sizeY Div 4) - indiv^.loc).length();
        If (distance <= radius) Then Begin
          result := Pair(true, (radius - distance) / radius);
          exit;
        End;
      End;

    // Survivors are those inside the circular area defined by
    // safeCenter and radius
    CHALLENGE_ALTRUISM: Begin
        safeCenter := coord(p.sizeX Div 4, p.sizeY Div 4);
        radius := p.sizeX / 4.0; // in a 128^2 world, holds 3216

        offset := safeCenter - indiv^.loc;
        distance := offset.length();
        If distance <= radius Then Begin
          result := pair(true, (radius - distance) / radius);
          exit;
        End;
      End;

  Else Begin
      Raise exception.create('Error invalid challange, not known.');
    End;
  End;
End;

Procedure initializeGeneration0();
Var
  index: Integer;
Begin
  // The grid, signals, and peeps containers have already been allocated, just
  // clear them if needed and reuse the elements
  grid.zeroFill();
  grid.createBarrier(p.barrierType);
  signals.zeroFill();

  // Spawn the population. The peeps container has already been allocated,
  // just clear and reuse it
  For index := 1 To p.population Do Begin
    peeps[index]^.initialize(index, grid.findEmptyLocation(), makeRandomGenome());
  End;
End;

// Requires a container with one or more parent genomes to choose from.
// Called from spawnNewGeneration(). This requires that the grid, signals, and
// peeps containers have been allocated. This will erase the grid and signal
// layers, then create a new population in the peeps container with random
// locations and genomes derived from the container of parent genomes.

Procedure initializeNewGeneration(Var parentGenomes: TGenomeArray);
Var
  index: Integer;
Begin
  // The grid, signals, and peeps containers have already been allocated, just
  // clear them if needed and reuse the elements
  grid.zeroFill();
  grid.createBarrier(p.barrierType);
  signals.zeroFill();

  // Spawn the population. This overwrites all the elements of peeps[]
  For index := 1 To p.population Do Begin
    peeps[index]^.initialize(index, grid.findEmptyLocation(), generateChildGenome(parentGenomes));
  End;
End;

Type

  TParentElement = Record // <indiv index, score>
    first: uint16_t;
    Second: Single;
  End;

  TParents = Array Of TParentElement;

Procedure Sort(Var Parents: TParents; li, re: integer);
Var
  l, r: Integer;
  p: Single;
  h: TParentElement;
Begin
  If Li < Re Then Begin
    p := Parents[Trunc((li + re) / 2)].Second; // Auslesen des Pivo Elementes
    l := Li;
    r := re;
    While l < r Do Begin
      While Parents[l].Second > p Do
        inc(l);
      While Parents[r].Second < p Do
        dec(r);
      If L <= R Then Begin
        h := Parents[l];
        Parents[l] := Parents[r];
        Parents[r] := h;
        inc(l);
        dec(r);
      End;
    End;
    Sort(Parents, li, r);
    Sort(Parents, l, re);
  End;
End;

Function spawnNewGeneration(generation, murderCount: unsigned; ThreadTimes: String): unsigned;
Const
  altruismFactor = 10; // the saved:sacrificed ratio
  generationToApplyKinship = 10;

Var
  sacrificedCount: unsigned;
  // This container will hold the indexes and survival scores (0.0..1.0)
  // of all the survivors who will provide genomes for repopulation.
  parents: TParents;
  parentGenomes: TGenomeArray; // This container will hold the genomes of the survivors
  index, parent, Passes, sacrificedIndex, count, i: Integer;
  passed: TBoolPair;
  considerKinship: Boolean;
  sacrificesIndexes: Array Of Integer; // those who gave their lives for the greater good
  numberSaved, startIndex: unsigned;
  threshold: Float;
  survivingKin: TParents;
  possibleParent: TParentElement;
  g2, g1: TGenome;
  similarity, gendiversity: ugenome.float;
  at: UInt64;
  tmp: String;
Begin
  sacrificesIndexes := Nil;
  sacrificedCount := 0; // for the altruism challenge
  parentGenomes := Nil;
  parents := Nil;

  If (p.challenge <> CHALLENGE_ALTRUISM) Then Begin
    // First, make a list of all the individuals who will become parents; save
    // their scores for later sorting. Indexes start at 1.
    setlength(parents, p.population);
    i := 0;
    For index := 1 To p.population Do Begin
      passed := passedSurvivalCriterion(peeps[index], p.challenge);
      // Save the parent genome if it results in valid neural connections
      If (passed.first And assigned(peeps[index]^.nnet.connections)) Then Begin
        parents[i].first := index;
        parents[i].Second := passed.second;
        inc(i);
      End;
    End;
    setlength(parents, i);
  End
  Else Begin
    // For the altruism challenge, test if the agent is inside either the sacrificial
    // or the spawning area. We'll count the number in the sacrificial area and
    // save the genomes of the ones in the spawning area, saving their scores
    // for later sorting. Indexes start at 1.

    considerKinship := true;

    For index := 1 To p.population Do Begin
      // This the test for the spawning area:
      passed := passedSurvivalCriterion(peeps[index], CHALLENGE_ALTRUISM);
      If (passed.first And assigned(peeps[index]^.nnet.connections)) Then Begin
        setlength(parents, high(parents) + 2); // TODO: Speedup Implementieren
        parents[high(parents)].first := index;
        parents[high(parents)].Second := passed.second;
      End
      Else Begin
        // This is the test for the sacrificial area:
        passed := passedSurvivalCriterion(peeps[index], CHALLENGE_ALTRUISM_SACRIFICE);
        If (passed.first) And (assigned(peeps[index]^.nnet.connections)) Then Begin
          If (considerKinship) Then Begin
            // TODO: Kann man das hier noch optimieren ?
            setlength(sacrificesIndexes, high(sacrificesIndexes) + 2);
            sacrificesIndexes[high(sacrificesIndexes)] := index;
          End
          Else Begin
            sacrificedCount := sacrificedCount + 1;
          End;
        End;
      End;
    End;

    If (considerKinship) Then Begin
      If (generation > generationToApplyKinship) Then Begin
        threshold := 0.7;
        survivingKin := Nil;
        For Passes := 0 To altruismFactor - 1 Do Begin
          For sacrificedIndex := 0 To high(sacrificesIndexes) Do Begin
            // randomize the next loop so we don't keep using the first one repeatedly
            startIndex := randomUint.RndRange(0, length(parents) - 1);
            For count := 0 To length(parents) - 1 Do Begin
              possibleParent := parents[(startIndex + count) Mod length(parents)];
              g1 := peeps[sacrificedIndex]^.genome;
              g2 := peeps[possibleParent.first]^.genome;
              similarity := genomeSimilarity(g1, g2);
              If (similarity >= threshold) Then Begin
                setlength(survivingKin, high(survivingKin) + 2); // TODO: Speedup Implementieren
                survivingKin[high(survivingKin)] := possibleParent;
                // mark this one so we don't use it again?
                break;
              End;
            End;
          End;
        End;
        writeln(inttostr(length(parents)) + ' passed, ' + inttostr(length(sacrificesIndexes)) + ' sacrificed, '
          + inttostr(length(survivingKin)) + ' saved'); // !!!
        setlength(parents, length(survivingKin));
        For i := 0 To high(parents) Do Begin
          parents[i] := survivingKin[i];
        End;
      End;
    End
    Else Begin
      // Limit the parent list
      numberSaved := sacrificedCount * altruismFactor;
      writeln(inttostr(length(parents)) + ' passed, ' + inttostr(sacrificedCount) + ' sacrificed, ' + inttostr(numberSaved) + ' saved'); // !!!
      If assigned(parents) And (numberSaved < length(parents)) Then Begin
        SetLength(parents, numberSaved);
      End;
    End;
  End;
  // Sort the indexes of the parents by their fitness scores
  sort(Parents, 0, high(parents));

  // Assemble a list of all the parent genomes. These will be ordered by their
  // scores if the parents[] container was sorted by score
  setlength(parentGenomes, length(parents));
  For parent := 0 To high(parents) Do Begin
    parentGenomes[parent] := peeps.Individual[parents[parent].first]^.genome;
  End;

  at := GetTickCount64;
  tmp := '';
  If LastSpawnTime <> 0 Then Begin
    tmp := ', time to calculate = ' + PrettyTime(at - LastSpawnTime);
    If ThreadTimes <> '' Then Begin
      tmp := tmp + '(' + ThreadTimes + ')';
    End;
  End;
  LastSpawnTime := at;

  gendiversity := geneticDiversity();
  writeln('Gen ' + inttostr(generation) + ', ' +
    inttostr(length(parentGenomes)) + ' survivors = ' + format('%0.2d%%', [round((length(parentGenomes) * 100) / p.population)]) +
    ', genetic diversity = ' + format('%d%', [round(gendiversity * 100)]) +
    tmp
    );
  appendEpochLog(generation, length(parentGenomes), murderCount, gendiversity);
  // displaySignalUse(); // for debugging only

  // Now we have a container of zero or more parents' genomes

  If assigned(parentGenomes) Then Begin
    // Spawn a new generation
    initializeNewGeneration(parentGenomes);
  End
  Else Begin
    // Special case: there are no surviving parents: start the simulation over
    // from scratch with randomly-generated genomes
    initializeGeneration0();
  End;
  (* Store Simulation settings for continueing on a later time :-) *)
  If generation = p.maxGenerations - 1 Then Begin
    TSimulator.SaveSim(generation, parentGenomes);
  End;

  result := length(parentGenomes);
End;

End.

