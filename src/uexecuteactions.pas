Unit uexecuteActions;

{$MODE ObjFPC}{$H+}

Interface

{$I biosim_config.inc}

Uses
  Classes, SysUtils, urandom, uindiv, usensoractions, ubasicTypes;

Procedure executeActions(Const randomUint: RandomUintGenerator; Indiv: Pindiv; actionLevels: TActionArray);

Implementation

Uses math, uparams, usignals, ugrid, upeeps;

// Given a factor in the range 0.0..1.0, return a bool with the
// probability of it being true proportional to factor. For example, if
// factor == 0.2, then there is a 20% chance this function will
// return true.

Function prob2bool(Const randomUint: RandomUintGenerator; factor: float): Boolean;
Begin
  assert((factor >= 0.0) And (factor <= 1.0));
  result := (randomUint.Rnd() / RANDOM_UINT_MAX) < factor;
End;

// This takes a probability from 0.0..1.0 and adjusts it according to an
// exponential curve. The steepness of the curve is determined by the K factor
// which is a small positive integer. This tends to reduce the activity level
// a bit (makes the peeps less reactive and jittery).

Function responseCurve(r: float): float;
Var
  k: Float;
Begin
  k := p.responsivenessCurveKFactor;
  result := power((r - 2.0), -2.0 * k) - power(2.0, -2.0 * k) * (1.0 - r);
End;

(**********************************************************************************
Action levels are driven by sensors or internal neurons as connected by an agent's
neural net brain. Each agent's neural net is reevaluated once each simulator
step (simStep). After evaluating the action neuron outputs, this function is
called to execute the actions according to their output levels. This function is
called in multi-threaded mode and operates on a single individual while other
threads are doing to the same to other individuals.

Action (their output) values arrive here as floating point values of arbitrary
range (because they are the raw sums of zero or more weighted inputs) and will
eventually be converted in this function to a probability 0.0..1.0 of actually
getting executed.

For the various possible action neurons, if they are driven by a sufficiently
strong level, we do this:

    MOVE_* actions- queue our agent for deferred movement with peeps.queueForMove(); the
         queue will be executed at the end of the multithreaded loop in a single thread.
    SET_RESPONSIVENESS action - immediately change indiv.responsiveness to the action
         level scaled to 0.0..1.0 (because we have exclusive access to this member in
         our own individual during this function)
    SET_OSCILLATOR_PERIOD action - immediately change our individual's indiv.oscPeriod
         to the action level exponentially scaled to 2..2048 (TBD)
    EMIT_SIGNALn action(s) - immediately increment the signal level at our agent's
         location using signals.increment() (using a thread-safe call)
    KILL_FORWARD action - queue the other agent for deferred death with
         peeps.queueForDeath()

The deferred movement and death queues will be emptied by the caller at the end of the
simulator step by endOfSimStep() in a single thread after all individuals have been
evaluated multithreadedly.
**********************************************************************************)

Procedure executeActions(Const randomUint: RandomUintGenerator; Indiv: Pindiv; actionLevels: TActionArray);
Const
  maxLongProbeDistance = 32;
  emitThreshold = 0.5; // 0.0..1.0; 0.5 is midlevel
  killThreshold = 0.5; // 0.0..1.0; 0.5 is midlevel

Var
  newPeriodf01, periodf, responsivenessAdjusted, Level: Float;
  newPeriod: unsigned;
  otherLoc, lastMoveOffset, offset, movementOffset, newLoc: TCoord;
  indiv2: PIndiv;
  moveX, moveY: Single;
  probX, probY: int16_t;
  signumX, signumy: Integer;
Begin
  // Responsiveness action - convert neuron action level from arbitrary float range
  // to the range 0.0..1.0. If this action neuron is enabled but not driven, will
  // default to mid-level 0.5.
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(SET_RESPONSIVENESS)) Then
{$ENDIF}Begin
    level := actionLevels[integer(SET_RESPONSIVENESS)]; // default 0.0
    level := (Sigmoid(level) + 1.0) / 2.0; // convert to 0.0..1.0
    indiv^.responsiveness := level;
  End;

  // For the rest of the action outputs, we'll apply an adjusted responsiveness
  // factor (see responseCurve() for more info). Range 0.0..1.0.
  responsivenessAdjusted := responseCurve(indiv^.responsiveness);

  // Oscillator period action - convert action level nonlinearly to
  // 2..4*p.stepsPerGeneration. If this action neuron is enabled but not driven,
  // will default to 1.5 + e^(3.5) = a period of 34 simSteps.
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(SET_OSCILLATOR_PERIOD)) Then
{$ENDIF}Begin
    periodf := actionLevels[integer(SET_OSCILLATOR_PERIOD)];
    newPeriodf01 := (Sigmoid(periodf) + 1.0) / 2.0; // convert to 0.0..1.0
    newPeriod := 1 + trunc(1.5 + exp(7.0 * newPeriodf01));
    assert((newPeriod >= 2) And (newPeriod <= 2048));
    indiv^.oscPeriod := newPeriod;
  End;

  // Set longProbeDistance - convert action level to 1..maxLongProbeDistance.
  // If this action neuron is enabled but not driven, will default to
  // mid-level period of 17 simSteps.
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(SET_LONGPROBE_DIST)) Then
{$ENDIF}Begin
    level := actionLevels[integer(SET_LONGPROBE_DIST)];
    level := (Sigmoid(level) + 1.0) / 2.0; // convert to 0.0..1.0
    level := 1 + level * maxLongProbeDistance;
    indiv^.longProbeDist := trunc(level);
  End;

  // Emit signal0 - if this action value is below a threshold, nothing emitted.
  // Otherwise convert the action value to a probability of emitting one unit of
  // signal (pheromone).
  // Pheromones may be emitted immediately (see signals.cpp). If this action neuron
  // is enabled but not driven, nothing will be emitted.
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(EMIT_SIGNAL0)) Then
{$ENDIF}Begin
    level := actionLevels[integer(EMIT_SIGNAL0)];
    level := (Sigmoid(level) + 1.0) / 2.0; // convert to 0.0..1.0
    level := level * responsivenessAdjusted;
    If ((level > emitThreshold) And prob2bool(randomUint, level)) Then Begin
      signals.increment(0, indiv^.loc); // Das ist Thread sicher aus zu führen ?!
    End;
  End;

  // Kill forward -- if this action value is > threshold, value is converted to probability
  // of an attempted murder. Probabilities under the threshold are considered 0.0.
  // If this action neuron is enabled but not driven, the neighbors are safe.
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(KILL_FORWARD))
{$ELSE}
  If p.killEnable
{$ENDIF}
  Then Begin
    level := actionLevels[integer(KILL_FORWARD)];
    level := (Sigmoid(level) + 1.0) / 2.0; // convert to 0.0..1.0
    level := level * responsivenessAdjusted;
    If (level > killThreshold) And (prob2bool(randomUint, (level - ACTION_MIN) / ACTION_RANGE)) Then Begin
      otherLoc := indiv^.loc + indiv^.lastMoveDir;
      If (grid.isInBounds(otherLoc) And grid.isOccupiedAt(otherLoc)) Then Begin
        indiv2 := peeps.getIndiv(otherLoc);
        assert((indiv^.loc - indiv2^.loc).length() = 1);
        peeps.queueForDeath(indiv2);
      End;
    End;
  End;

  // ------------- Movement action neurons ---------------

  // There are multiple action neurons for movement. Each type of movement neuron
  // urges the individual to move in some specific direction. We sum up all the
  // X and Y components of all the movement urges, then pass the X and Y sums through
  // a transfer function (tanh()) to get a range -1.0..1.0. The absolute values of the
  // X and Y values are passed through prob2bool() to convert to -1, 0, or 1, then
  // multiplied by the component's signum. This results in the x and y components of
  // a normalized movement offset. I.e., the probability of movement in either
  // dimension is the absolute value of tanh of the action level X,Y components and
  // the direction is the sign of the X, Y components. For example, for a particular
  // action neuron:
  //     X, Y == -5.9, +0.3 as raw action levels received here
  //     X, Y == -0.999, +0.29 after passing raw values through tanh()
  //     Xprob, Yprob == 99.9%, 29% probability of X and Y becoming 1 (or -1)
  //     X, Y == -1, 0 after applying the sign and probability
  //     The agent will then be moved West (an offset of -1, 0) if it's a legal move.

  lastMoveOffset := asNormalizedCoord(indiv^.lastMoveDir);

  // moveX,moveY will be the accumulators that will hold the sum of all the
  // urges to move along each axis. (+- floating values of arbitrary range)
{$IFDEF EvalActionEnables}
  If IsActionEnabled(MOVE_X) Then Begin
    moveX := actionLevels[integer(MOVE_X)];
  End
  Else Begin
    moveX := 0.0;
  End;
{$ELSE}
  moveX := 0.0;
{$ENDIF}
{$IFDEF EvalActionEnables}
  If IsActionEnabled(MOVE_Y) Then Begin
    moveY := actionLevels[integer(MOVE_Y)];
  End
  Else Begin
    moveY := 0.0;
  End;
{$ELSE}
  movey := 0.0;
{$ENDIF}
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_EAST)) Then
{$ENDIF}
    moveX := moveX + actionLevels[integer(MOVE_EAST)];
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_WEST)) Then
{$ENDIF}
    moveX := moveX - actionLevels[integer(MOVE_WEST)];
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_NORTH)) Then
{$ENDIF}
    moveY := moveY + actionLevels[integer(MOVE_NORTH)];
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_SOUTH)) Then
{$ENDIF}
    moveY := moveY - actionLevels[integer(MOVE_SOUTH)];
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_FORWARD)) Then
{$ENDIF}Begin
    level := actionLevels[integer(MOVE_FORWARD)];
    moveX := moveX + lastMoveOffset.x * level;
    moveY := moveY + lastMoveOffset.y * level;
  End;
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_REVERSE)) Then
{$ENDIF}Begin
    level := actionLevels[integer(MOVE_REVERSE)];
    moveX := moveX - lastMoveOffset.x * level;
    moveY := moveY - lastMoveOffset.y * level;
  End;
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_LEFT)) Then
{$ENDIF}Begin
    level := actionLevels[integer(MOVE_LEFT)];
    offset := asNormalizedCoord(rotate90DegCCW(indiv^.lastMoveDir));
    moveX := moveX + offset.x * level;
    moveY := moveY + offset.y * level;
  End;
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_RIGHT)) Then
{$ENDIF}Begin
    level := actionLevels[integer(MOVE_RIGHT)];
    offset := asNormalizedCoord(rotate90DegCW(indiv^.lastMoveDir));
    moveX := moveX + offset.x * level;
    moveY := moveY + offset.y * level;
  End;
{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_RL)) Then
{$ENDIF}Begin
    level := actionLevels[integer(MOVE_RL)];
    offset := asNormalizedCoord(rotate90DegCW(indiv^.lastMoveDir));
    moveX := moveX + offset.x * level;
    moveY := moveY + offset.y * level;
  End;

{$IFDEF EvalActionEnables}
  If (IsActionEnabled(MOVE_RANDOM)) Then
{$ENDIF}Begin
    level := actionLevels[integer(MOVE_RANDOM)];
    offset := asNormalizedCoord(random8(randomUint));
    moveX := moveX + offset.x * level;
    moveY := moveY + offset.y * level;
  End;

  // Convert the accumulated X, Y sums to the range -1.0..1.0 and scale by the
  // individual's responsiveness (0.0..1.0) (adjusted by a curve)
  moveX := Sigmoid(moveX);
  moveY := Sigmoid(moveY);
  moveX := moveX * responsivenessAdjusted;
  moveY := moveY * responsivenessAdjusted;

  // The probability of movement along each axis is the absolute value
  probX := ord(prob2bool(randomUint, abs(moveX))); // convert abs(level) to 0 or 1
  probY := ord(prob2bool(randomUint, abs(moveY))); // convert abs(level) to 0 or 1

  // The direction of movement (if any) along each axis is the sign
  If moveX < 0 Then
    signumX := -1
  Else
    signumX := 1;
  If moveY < 0 Then
    signumy := -1
  Else
    signumy := 1;

  // Generate a normalized movement offset, where each component is -1, 0, or 1
  movementOffset := coord(trunc(probX * signumX), trunc(probY * signumY));

  // Move there if it's a valid location
  //  If (movementOffset.x <> 0) or (movementOffset.y <> 0) Then Begin // Skip no movement -> Das Braucht es nicht, weil das Indiv ja auf newLoc sitzt und deswegen isEmptyAt fehl schlägt !
  newLoc := indiv^.loc + movementOffset;
  If (grid.isInBounds(newLoc) And grid.isEmptyAt(newLoc)) Then Begin
    peeps.queueForMove(indiv, newLoc);
  End;
  //  End;
End;

End.

