Unit usensoractions;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

// This file defines which sensor input neurons and which action output neurons
// are compiled into the simulator. This file can be modified to create a simulator
// executable that supports only a subset of all possible sensor or action neurons.

// Neuron Sources (Sensors) and Sinks (Actions)

// These sensor, neuron, and action value ranges are here for documentation
// purposes. Most functions now assume these ranges. We no longer support changes
// to these ranges.

Const
  SENSOR_MIN = 0.0;
  SENSOR_MAX = 1.0;
  SENSOR_RANGE = SENSOR_MAX - SENSOR_MIN;

  NEURON_MIN = -1.0;
  NEURON_MAX = 1.0;
  NEURON_RANGE = NEURON_MAX - NEURON_MIN;

  ACTION_MIN = 0.0;
  ACTION_MAX = 1.0;
  ACTION_RANGE = ACTION_MAX - ACTION_MIN;

Type
  // Place the sensor neuron you want enabled prior to NUM_SENSES. Any
  // that are after NUM_SENSES will be disabled in the simulator.
  // If new items are added to this enum, also update the name functions
  // in analysis.cpp.
  // I means data about the individual, mainly stored in Indiv
  // W means data about the environment, mainly stored in Peeps or Grid
  TSensor = (
    LOC_X = 0, // I distance from left edge
    LOC_Y, // I distance from bottom
    // TODO: BLOC_X, BLOC_Y -> Die Position an der das Objekt "geboren" wurde
    BOUNDARY_DIST_X, // I X distance to nearest edge of world
    BOUNDARY_DIST, // I distance to nearest edge of world
    BOUNDARY_DIST_Y, // I Y distance to nearest edge of world
    GENETIC_SIM_FWD, // I genetic similarity forward
    LAST_MOVE_DIR_X, // I +- amount of X movement in last movement
    LAST_MOVE_DIR_Y, // I +- amount of Y movement in last movement
    LONGPROBE_POP_FWD, // W long look for population forward
    LONGPROBE_BAR_FWD, // W long look for barriers forward
    POPULATION, // W population density in neighborhood
    POPULATION_FWD, // W population density in the forward-reverse axis
    POPULATION_LR, // W population density in the left-right axis
    OSC1, // I oscillator +-value
    AGE, // I
    BARRIER_FWD, // W neighborhood barrier distance forward-reverse axis
    BARRIER_LR, // W neighborhood barrier distance left-right axis
    RANDOM, //   random sensor value, uniform distribution
    SIGNAL0, // W strength of signal0 in neighborhood
    SIGNAL0_FWD, // W strength of signal0 in the forward-reverse axis
    SIGNAL0_LR, // W strength of signal0 in the left-right axis
    NUM_SENSES // <<------------------ END OF ACTIVE SENSES MARKER
    );


  // Place the action neuron you want enabled prior to NUM_ACTIONS. Any
  // that are after NUM_ACTIONS will be disabled in the simulator.
  // If new items are added to this enum, also update the name functions
  // in analysis.cpp.
  // I means the action affects the individual internally (Indiv)
  // W means the action also affects the environment (Peeps or Grid)
  TAction = (
    MOVE_X, // W +- X component of movement
    MOVE_Y, // W +- Y component of movement
    MOVE_FORWARD, // W continue last direction
    MOVE_RL, // W +- component of movement
    MOVE_RANDOM, // W
    SET_OSCILLATOR_PERIOD, // I
    SET_LONGPROBE_DIST, // I
    SET_RESPONSIVENESS, // I
    EMIT_SIGNAL0, // W
    MOVE_EAST, // W
    MOVE_WEST, // W
    MOVE_NORTH, // W
    MOVE_SOUTH, // W
    MOVE_LEFT, // W
    MOVE_RIGHT, // W
    MOVE_REVERSE, // W
    NUM_ACTIONS, // <<----------------- END OF ACTIVE ACTIONS MARKER
    KILL_FORWARD // W
    );

  TActionArray = Array[0..Integer(NUM_ACTIONS) - 1] Of Float;


Function sensorName(sensor: TSensor): String; // This converts sensor numbers to descriptive strings.
Function sensorShortName(Sensor: Tsensor): String;

Function actionName(action: TAction): String; // Converts action numbers to descriptive strings.
Function actionShortName(Action: Taction): String;
(*
 *List the names of the active sensors and actions to stdout.
 * "Active" means those sensors and actions that are compiled into
 * the code. See sensors-actions.h for how to define the enums.
 *)
Procedure printSensorsActions;

Implementation

// This converts sensor numbers to mnemonic strings.
// Useful for later processing by graph-nnet.py.

Function sensorShortName(Sensor: Tsensor): String;
Begin
  Case sensor Of
    AGE: result := 'Age';
    BOUNDARY_DIST: result := 'ED';
    BOUNDARY_DIST_X: result := 'EDx';
    BOUNDARY_DIST_Y: result := 'EDy';
    LAST_MOVE_DIR_X: result := 'LMx';
    LAST_MOVE_DIR_Y: result := 'LMy';
    LOC_X: result := 'Lx';
    LOC_Y: result := 'Ly';
    LONGPROBE_POP_FWD: result := 'LPf';
    LONGPROBE_BAR_FWD: result := 'LPb';
    BARRIER_FWD: result := 'Bfd';
    BARRIER_LR: result := 'Blr';
    OSC1: result := 'Osc';
    POPULATION: result := 'Pop';
    POPULATION_FWD: result := 'Pfd';
    POPULATION_LR: result := 'Plr';
    RANDOM: result := 'Rnd';
    SIGNAL0: result := 'Sg';
    SIGNAL0_FWD: result := 'Sfd';
    SIGNAL0_LR: result := 'Slr';
    GENETIC_SIM_FWD: result := 'Gen';
  Else
    assert(false);
  End;
End;

Function sensorName(sensor: TSensor): String;
Begin
  Case sensor Of
    AGE: result := 'age';
    BOUNDARY_DIST: result := 'boundary dist';
    BOUNDARY_DIST_X: result := 'boundary dist X';
    BOUNDARY_DIST_Y: result := 'boundary dist Y';
    LAST_MOVE_DIR_X: result := 'last move dir X';
    LAST_MOVE_DIR_Y: result := 'last move dir Y';
    LOC_X: result := 'loc X';
    LOC_Y: result := 'loc Y';
    LONGPROBE_POP_FWD: result := 'long probe population fwd';
    LONGPROBE_BAR_FWD: result := 'long probe barrier fwd';
    BARRIER_FWD: result := 'short probe barrier fwd - rev';
    BARRIER_LR: result := 'short probe barrier left - right';
    OSC1: result := 'osc1';
    POPULATION: result := 'population';
    POPULATION_FWD: result := 'population fwd';
    POPULATION_LR: result := 'population LR';
    RANDOM: result := 'random';
    SIGNAL0: result := 'signal 0';
    SIGNAL0_FWD: result := 'signal 0 fwd';
    SIGNAL0_LR: result := 'signal 0 LR';
    GENETIC_SIM_FWD: result := 'genetic similarity fwd';
  Else Begin
      assert(false);
    End;
  End;
End;

Function actionName(action: TAction): String;
Begin
  Case action Of
    MOVE_EAST: result := 'move east';
    MOVE_WEST: result := 'move west';
    MOVE_NORTH: result := 'move north';
    MOVE_SOUTH: result := 'move south';
    MOVE_FORWARD: result := 'move fwd';
    MOVE_X: result := 'move X';
    MOVE_Y: result := 'move Y';
    SET_RESPONSIVENESS: result := 'set inv-responsiveness';
    SET_OSCILLATOR_PERIOD: result := 'set osc1';
    EMIT_SIGNAL0: result := 'emit signal 0';
    KILL_FORWARD: result := 'kill fwd';
    MOVE_REVERSE: result := 'move reverse';
    MOVE_LEFT: result := 'move left';
    MOVE_RIGHT: result := 'move right';
    MOVE_RL: result := 'move R-L';
    MOVE_RANDOM: result := 'move random';
    SET_LONGPROBE_DIST: result := 'set longprobe dist';
  Else Begin
      assert(false);
    End;
  End;
End;

// Converts action numbers to mnemonic strings.
// Useful for later processing by graph-nnet.py.

Function actionShortName(Action: Taction): String;
Begin
  Case (action) Of
    MOVE_EAST: result := 'MvE';
    MOVE_WEST: result := 'MvW';
    MOVE_NORTH: result := 'MvN';
    MOVE_SOUTH: result := 'MvS';
    MOVE_X: result := 'MvX';
    MOVE_Y: result := 'MvY';
    MOVE_FORWARD: result := 'Mfd';
    SET_RESPONSIVENESS: result := 'Res';
    SET_OSCILLATOR_PERIOD: result := 'OSC';
    EMIT_SIGNAL0: result := 'SG';
    KILL_FORWARD: result := 'Klf';
    MOVE_REVERSE: result := 'Mrv';
    MOVE_LEFT: result := 'MvL';
    MOVE_RIGHT: result := 'MvR';
    MOVE_RL: result := 'MRL';
    MOVE_RANDOM: result := 'Mrn';
    SET_LONGPROBE_DIST: result := 'LPD';
  Else
    assert(false);
  End;
End;

Procedure printSensorsActions;
Var
  i: integer;
Begin
  writeln('Sensors:');
  For i := 0 To Integer(NUM_SENSES) - 1 Do Begin
    writeln('  ' + sensorName(TSensor(i)));
  End;
  writeln('Actions:');
  For i := 0 To integer(NUM_ACTIONS) - 1 Do Begin
    writeln('  ' + actionName(TAction(i)));
  End;
  writeln('');
End;

End.

