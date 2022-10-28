Unit uindiv;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, ubasicTypes, ugenome, usensoractions;

{$I c_types.inc}

// Indiv is the structure that represents one individual agent.

// Also see class Peeps.

Type

  { TIndiv }

  TIndiv = Object // Das sollte wahrscheinlich eine echt Classe werden !!
    alive: bool;
      index: uint16_t; // index into peeps[] container
    loc: TCoord; // refers to a location in grid[][]
    birthLoc: TCoord; // für die Challange: CHALLENGE_MIGRATE_DISTANCE
    age: unsigned;
    genome: TGenome;
    nnet: TNeuralNet; // derived from .genome
    responsiveness: float; // 0.0..1.0 (0 is like asleep)
    oscPeriod: unsigned; // 2..4*p.stepsPerGeneration (TBD, see executeActions())
    longProbeDist: unsigned; // distance for long forward probe for obstructions
    lastMoveDir: TDir; // direction of last movement
    challengeBits: unsigned; // modified when the indiv accomplishes some task
    Function feedForward(simStep: unsigned): TActionArray; // reads sensors, returns actions

    Function getSensor(sensorNum: TSensor; simStep: unsigned): float;
    Procedure initialize(index_: uint16_t; loc_: TCoord; genome_: TGenome);
    Procedure createWiringFromGenome(); // creates .nnet member from .genome member
    Procedure printNeuralNet();
    Procedure printIGraphEdgeList();
    Procedure printGenome();
  End;

  PIndiv = ^TIndiv;

Implementation

Uses uSimulator, uparams, Math, fgl, urandom, usignals;

Type

  // This structure is used while converting the connection list to a
  // neural net. This helps us to find neurons that don't feed anything
  // so that they can be removed along with all the connections that
  // feed the useless neurons. We'll cull neurons with .numOutputs == 0
  // or those that only feed themselves, i.e., .numSelfInputs == .numOutputs.
  // Finally, we'll renumber the remaining neurons sequentially starting
  // at zero using the .remappedNumber member.
  TNode = Record
    remappedNumber: uint16_t;
    numOutputs: uint16_t;
    numSelfInputs: uint16_t;
    numInputsFromSensorsOrOtherNeurons: uint16_t;
  End;

  TNodeMap = specialize TFPGMap < integer, TNode > ;

  TconnectionList = Array Of TGene;

  // Returns the number of locations to the next agent in the specified
  // direction, not including loc. If the probe encounters a boundary or a
  // barrier before reaching the longProbeDist distance, returns longProbeDist.
  // Returns 0..longProbeDist.

Function longProbePopulationFwd(loc: TCoord; dir: TDir; longProbeDist: unsigned): unsigned;
Var
  Count, numLocsToTest: unsigned;
Begin
  assert(longProbeDist > 0);
  count := 0;
  loc := loc + dir;
  numLocsToTest := longProbeDist;
  While (numLocsToTest > 0) And grid.isInBounds(loc) And grid.isEmptyAt(loc) Do Begin
    count := count + 1;
    loc := loc + dir;
    numLocsToTest := numLocsToTest - 1;
  End;
  If (numLocsToTest > 0) And (Not grid.isInBounds(loc) Or grid.isBarrierAt(loc)) Then Begin
    result := longProbeDist;
  End
  Else Begin
    result := count;
  End;
End;

// Returns the number of locations to the next barrier in the
// specified direction, not including loc. Ignores agents in the way.
// If the distance to the border is less than the longProbeDist distance
// and no barriers are found, returns longProbeDist.
// Returns 0..longProbeDist.

Function longProbeBarrierFwd(loc: TCoord; Dir: Tdir; longProbeDist: unsigned): unsigned;
Var
  numLocsToTest, Count: unsigned;

Begin
  assert(longProbeDist > 0);
  count := 0;
  loc := loc + dir;
  numLocsToTest := longProbeDist;
  While (numLocsToTest > 0) And grid.isInBounds(loc) And Not grid.isBarrierAt(loc) Do Begin
    count := count + 1;
    loc := loc + dir;
    numLocsToTest := numLocsToTest - 1;
  End;
  If (numLocsToTest > 0) And (Not grid.isInBounds(loc)) Then Begin
    result := longProbeDist;
  End
  Else Begin
    result := count;
  End;
End;

Var
  dirVecX, dirVecY, sum: Double;
  popcountloc: TCoord;

Procedure CountPopulationDensity(Coord: TCoord);
Var
  offset: TCoord;
  contrib, proj: Double;
Begin
  If (Coord <> popcountloc) And grid.isOccupiedAt(Coord) Then Begin
    offset := Coord - popcountloc;
    proj := dirVecX * offset.x + dirVecY * offset.y; // Magnitude of projection along dir
    contrib := proj / (offset.x * offset.x + offset.y * offset.y);
    sum := sum + contrib;
  End;
End;

Function getPopulationDensityAlongAxis(loc: TCoord; Dir: Tdir): float;
Var
  maxSumMag, len, sensorVal: Double;
  dirVec: TCoord;
Begin
  // Converts the population along the specified axis to the sensor range. The
  // locations of neighbors are scaled by the inverse of their distance times
  // the positive absolute cosine of the difference of their angle and the
  // specified axis. The maximum positive or negative magnitude of the sum is
  // about 2*radius. We don't adjust for being close to a border, so populations
  // along borders and in corners are commonly sparser than away from borders.
  // An empty neighborhood results in a sensor value exactly midrange; below
  // midrange if the population density is greatest in the reverse direction,
  // above midrange if density is greatest in forward direction.

  assert(dir <> CENTER); // require a defined axis

  sum := 0.0;
  dirVec := asNormalizedCoord(dir);
  len := sqrt(dirVec.x * dirVec.x + dirVec.y * dirVec.y);
  dirVecX := dirVec.x / len;
  dirVecY := dirVec.y / len; // Unit vector components along dir

  popcountloc := loc;

  visitNeighborhood(loc, p.populationSensorRadius, @CountPopulationDensity);

  maxSumMag := 6.0 * p.populationSensorRadius;
  assert((sum >= -maxSumMag) And (sum <= maxSumMag));

  sensorVal := sum / maxSumMag; // convert to -1.0..1.0
  sensorVal := (sensorVal + 1.0) / 2.0; // convert to 0.0..1.0

  result := sensorVal;
End;

// Converts the number of locations (not including loc) to the next barrier location
// along opposite directions of the specified axis to the sensor range. If no barriers
// are found, the result is sensor mid-range. Ignores agents in the path.

Function getShortProbeBarrierDistance(loc0: TCoord; Dir: Tdir; probeDistance: unsigned): Float;
Var
  sensorVal: Float;
  countRev, countFwd, numLocsToTest: unsigned;
  loc: TCoord;
Begin
  countFwd := 0;
  countRev := 0;
  loc := loc0 + dir;
  numLocsToTest := probeDistance;
  // Scan positive direction
  While (numLocsToTest > 0) And (grid.isInBounds(loc) And (Not grid.isBarrierAt(loc))) Do Begin
    countFwd := countFwd + 1;
    loc := loc + dir;
    numLocsToTest := numLocsToTest - 1;
  End;

  If (numLocsToTest > 0) And (Not grid.isInBounds(loc)) Then Begin
    countFwd := probeDistance;
  End;

  // Scan negative direction
  numLocsToTest := probeDistance;
  loc := loc0 - dir;
  While (numLocsToTest > 0) And (grid.isInBounds(loc) And (Not grid.isBarrierAt(loc))) Do Begin
    countRev := countRev + 1;
    loc := loc - dir;
    numLocsToTest := numLocsToTest - 1;
  End;
  If (numLocsToTest > 0) And (Not grid.isInBounds(loc)) Then Begin
    countRev := probeDistance;
  End;

  sensorVal := ((countFwd - countRev) + probeDistance); // convert to 0..2*probeDistance
  sensorVal := (sensorVal / 2.0) / probeDistance; // convert to 0.0..1.0
  result := sensorVal;
End;

Var
  CountLocs: unsigned;
  sumi64: uInt64;
  alayerNum: unsigned;

Procedure CountSignalDensity(Coord: TCoord);
Begin
  countLocs := countLocs + 1;
  sumi64 := sumi64 + signals.getMagnitude(alayerNum, Coord);
End;

Function getSignalDensity(layerNum: unsigned; loc: TCoord): float;
Var
  Center: TCoord;
  maxSum, sensorVal: Double;
Begin
  // returns magnitude of the specified signal layer in a neighborhood, with
  // 0.0..maxSignalSum converted to the sensor range.

  countLocs := 0;
  sumi64 := 0;
  center := loc;

  alayerNum := layerNum;

  visitNeighborhood(center, p.signalSensorRadius, @CountSignalDensity);
  maxSum := countLocs * SIGNAL_MAX;
  sensorVal := sumi64 / maxSum; // convert to 0.0..1.0

  result := sensorVal;
End;

Procedure CountSensorRadius(Coord: TCoord);
Var
  offset: TCoord;
  proj, contrib: Double;
Begin
  If (Coord <> popcountloc) Then Begin
    offset := Coord - popcountloc;
    proj := (dirVecX * offset.x + dirVecY * offset.y); // Magnitude of projection along dir
    contrib := (proj * signals.getMagnitude(alayerNum, Coord)) /
      (offset.x * offset.x + offset.y * offset.y);
    sum := sum + (contrib);
  End;
End;

Function getSignalDensityAlongAxis(layerNum: unsigned; loc: TCoord; Dir: Tdir): Float;
Var
  dirVec: TCoord;
  sensorVal, maxSumMag, len: Double;
Begin
  // Converts the signal density along the specified axis to sensor range. The
  // values of cell signal levels are scaled by the inverse of their distance times
  // the positive absolute cosine of the difference of their angle and the
  // specified axis. The maximum positive or negative magnitude of the sum is
  // about 2*radius*SIGNAL_MAX (?). We don't adjust for being close to a border,
  // so signal densities along borders and in corners are commonly sparser than
  // away from borders.

  assert(dir <> TCompass.CENTER); // require a defined axis

  sum := 0.0;
  dirVec := asNormalizedCoord(dir);
  len := sqrt(dirVec.x * dirVec.x + dirVec.y * dirVec.y);
  dirVecX := dirVec.x / len;
  dirVecY := dirVec.y / len; // Unit vector components along dir

  popcountloc := loc;
  alayerNum := layerNum;
  visitNeighborhood(loc, p.signalSensorRadius, @CountSensorRadius);

  maxSumMag := 6.0 * p.signalSensorRadius * SIGNAL_MAX;
  assert((sum >= -maxSumMag) And (sum <= maxSumMag));
  sensorVal := sum / maxSumMag; // convert to -1.0..1.0
  sensorVal := (sensorVal + 1.0) / 2.0; // convert to 0.0..1.0

  result := sensorVal;
End;

// During the culling process, we will remove any neuron that has no outputs,
// and all the connections that feed the useless neuron.

Procedure removeConnectionsToNeuron(Var connections: TConnectionList; Var nodeMap: TNodeMap; neuronNumber: uint16_t);
Var
  itConn, j: Integer;
  n: TNode;
Begin
  For itConn := high(connections) Downto 0 Do Begin
    If (connections[itConn].sinkType = NEURON) And (connections[itConn].sinkNum = neuronNumber) Then Begin
      // Remove the connection. If the connection source is from another
      // neuron, also decrement the other neuron's numOutputs:
      If (connections[itConn].sourceType = NEURON) Then Begin
        n := nodemap.KeyData[connections[itConn].sourceNum];
        n.numOutputs := n.numOutputs - 1;
        nodemap.KeyData[connections[itConn].sourceNum] := n;
      End;
      For j := itConn To high(connections) - 1 Do Begin
        connections[j] := connections[j + 1];
      End;
      SetLength(connections, high(connections));
    End;
  End;
End;

// If a neuron has no outputs or only outputs that feed itself, then we
// remove it along with all connections that feed it. Reiterative, because
// after we remove a connection to a useless neuron, it may result in a
// different neuron having no outputs.

Procedure cullUselessNeurons(Var connections: TConnectionList;
  Var nodeMap: TNodeMap);
Var
  allDone: Boolean;
  itNeuron: Integer;
Begin
  allDone := false;
  While (Not allDone) Do Begin
    allDone := true;
    For itNeuron := nodeMap.Count - 1 Downto 0 Do Begin
      assert(nodeMap.Keys[itNeuron] < p.maxNumberNeurons);
      // We're looking for neurons with zero outputs, or neurons that feed itself
      // and nobody else:
      If (nodeMap.Data[itNeuron].numOutputs = nodeMap.Data[itNeuron].numSelfInputs) Then Begin // could be 0
        allDone := false;
        // Find and remove connections from sensors or other neurons
        removeConnectionsToNeuron(connections, nodeMap, nodeMap.Keys[itNeuron]);
        nodeMap.Delete(itNeuron);
      End;
    End;
  End;
End;

// Convert the indiv's genome to a renumbered connection list.
// This renumbers the neurons from their uint16_t values in the genome
// to the range 0..p.maxNumberNeurons - 1 by using a modulo operator.
// Sensors are renumbered 0..Sensor::NUM_SENSES - 1
// Actions are renumbered 0..Action::NUM_ACTIONS - 1

Procedure makeRenumberedConnectionList(Out ConnectionList: TconnectionList; Var Genome: Tgenome);
Var
  gene: Integer;
Begin
  ConnectionList := Nil;
  setlength(ConnectionList, length(Genome));
  For gene := 0 To high(Genome) Do Begin
    ConnectionList[gene] := Genome[gene];

    If (ConnectionList[gene].sourceType = NEURON) Then Begin
      ConnectionList[gene].sourceNum := ConnectionList[gene].sourceNum Mod p.maxNumberNeurons;
    End
    Else Begin
      ConnectionList[gene].sourceNum := ConnectionList[gene].sourceNum Mod integer(NUM_SENSES);
    End;

    If (ConnectionList[gene].sinkType = NEURON) Then Begin
      ConnectionList[gene].sinkNum := ConnectionList[gene].sinkNum Mod p.maxNumberNeurons;
    End
    Else Begin
      ConnectionList[gene].sinkNum := ConnectionList[gene].sinkNum Mod integer(NUM_ACTIONS);
    End;
  End;
End;

Function NodeMapKeyCompare(Const Key1, Key2: Integer): Integer;
Begin
  result := Key1 - Key2;
End;

// Scan the connections and make a list of all the neuron numbers
// mentioned in the connections. Also keep track of how many inputs and
// outputs each neuron has.

Procedure makeNodeList(Out NodeMap: TnodeMap; Var ConnectionList: TconnectionList);
Var
  it, conn: Integer;
  n: TNode;
  cnt, i: integer;
Begin
  NodeMap := TNodeMap.Create;
  NodeMap.OnKeyCompare := @NodeMapKeyCompare;
  NodeMap.Sorted := true;
  nodeMap.clear();
  For conn := 0 To high(ConnectionList) Do Begin
    If (ConnectionList[conn].sinkType = NEURON) Then Begin
      it := NodeMap.IndexOf(ConnectionList[conn].sinkNum);
      If (it = -1) Then Begin
        assert(ConnectionList[conn].sinkNum < p.maxNumberNeurons);
        it := NodeMap.Add(ConnectionList[conn].sinkNum);
        assert(NodeMap.Keys[it] < p.maxNumberNeurons);
        n.numOutputs := 0;
        n.numSelfInputs := 0;
        n.numInputsFromSensorsOrOtherNeurons := 0;
        NodeMap.Data[it] := n;
      End;

      n := NodeMap.Data[it];
      If (ConnectionList[conn].sourceType = NEURON) And (ConnectionList[conn].sourceNum = ConnectionList[conn].sinkNum) Then Begin
        n.numSelfInputs := n.numSelfInputs + 1;
      End
      Else Begin
        n.numInputsFromSensorsOrOtherNeurons := n.numInputsFromSensorsOrOtherNeurons + 1;
      End;
      NodeMap.Data[it] := n;
      cnt := 0;
      For i := 0 To NodeMap.Count - 1 Do Begin
        If NodeMap.Keys[i] = ConnectionList[conn].sinkNum Then inc(cnt);
      End;
      assert(cnt = 1);
    End;
    If (ConnectionList[conn].sourceType = NEURON) Then Begin
      it := nodeMap.IndexOf(ConnectionList[conn].sourceNum);
      If (it = -1) Then Begin
        assert(ConnectionList[conn].sourceNum < p.maxNumberNeurons);
        it := NodeMap.Add(ConnectionList[conn].sourceNum);
        assert(NodeMap.Keys[it] < p.maxNumberNeurons);
        n.numOutputs := 0;
        n.numSelfInputs := 0;
        n.numInputsFromSensorsOrOtherNeurons := 0;
        NodeMap.Data[it] := n;
      End;
      n := NodeMap.Data[it];
      n.numOutputs := n.numOutputs + 1;
      NodeMap.Data[it] := n;
      cnt := 0;
      For i := 0 To NodeMap.Count - 1 Do Begin
        If NodeMap.Keys[i] = ConnectionList[conn].sourceNum Then inc(cnt);
      End;
      assert(cnt = 1);
    End;
  End;
End;

{ TIndiv }

// This is called when any individual is spawned.
// The responsiveness parameter will be initialized here to maximum value
// of 1.0, then depending on which action activation function is used,
// the default undriven value may be changed to 1.0 or action midrange.

Procedure TIndiv.initialize(index_: uint16_t; loc_: TCoord; genome_: TGenome);
Var
  i: Integer;
Begin
  index := index_;
  loc := loc_;
  nnet.connections := Nil;
  nnet.neurons := Nil;
  birthLoc := loc_;
  grid.Set_(loc_, index_);
  age := 0;
  oscPeriod := 34; // ToDo !!! define a constant
  alive := true;
  lastMoveDir := TDir.random8();
  responsiveness := 0.5; // range 0.0..1.0
  longProbeDist := p.longProbeDistance;
  challengeBits := 0; //(unsigned)false; // will be set true when some task gets accomplished
  setlength(genome, length(genome_));
  For i := 0 To high(genome) Do Begin
    genome[i] := genome_[i];
  End;
  createWiringFromGenome();
End;

// This function is used when an agent is spawned. This function converts the
// agent's inherited genome into the agent's neural net brain. There is a close
// correspondence between the genome and the neural net, but a connection
// specified in the genome will not be represented in the neural net if the
// connection feeds a neuron that does not itself feed anything else.
// Neurons get renumbered in the process:
// 1. Create a set of referenced neuron numbers where each index is in the
//    range 0..p.genomeMaxLength-1, keeping a count of outputs for each neuron.
// 2. Delete any referenced neuron index that has no outputs or only feeds itself.
// 3. Renumber the remaining neurons sequentially starting at 0.

Procedure TIndiv.createWiringFromGenome;
Var
  NodeMap: TNodeMap; // list of neurons and their number of inputs and outputs
  connectionList: TconnectionList; // synaptic connections
  newNumber: uint16_t;
  node, conn, newConn, neuronNum: Integer;
  n: TNode;
Begin
  // Convert the indiv's genome to a renumbered connection list
  makeRenumberedConnectionList(connectionList, genome);

  // Make a node (neuron) list from the renumbered connection list
  makeNodeList(nodeMap, connectionList);

  // Find and remove neurons that don't feed anything or only feed themself.
  // This reiteratively removes all connections to the useless neurons.
  cullUselessNeurons(connectionList, nodeMap);


  // The neurons map now has all the referenced neurons, their neuron numbers, and
  // the number of outputs for each neuron. Now we'll renumber the neurons
  // starting at zero.
  assert(nodeMap.Count <= p.maxNumberNeurons);
  newNumber := 0;
  For node := 0 To NodeMap.Count - 1 Do Begin
    assert(NodeMap.Data[node].numOutputs <> 0);
    n := NodeMap.Data[node];
    n.remappedNumber := newNumber;
    NodeMap.Data[node] := n;
    newNumber := newNumber + 1;
  End;

  // Create the indiv's connection list in two passes:
  // First the connections to neurons, then the connections to actions.
  // This ordering optimizes the feed-forward function in feedForward.cpp.

  setlength(nnet.connections, 0);

  // First, the connections from sensor or neuron to a neuron
  For conn := 0 To high(connectionList) Do Begin
    If (connectionList[conn].sinkType = NEURON) Then Begin
      setlength(nnet.connections, high(nnet.connections) + 2);
      newConn := high(nnet.connections);
      nnet.connections[newConn] := connectionList[conn];

      // fix the destination neuron number
      nnet.connections[newConn].sinkNum := NodeMap.KeyData[nnet.connections[newConn].sinkNum].remappedNumber;

      // if the source is a neuron, fix its number too
      If (nnet.connections[newConn].sourceType = NEURON) Then Begin
        nnet.connections[newConn].sourceNum := NodeMap.KeyData[nnet.connections[newConn].sourceNum].remappedNumber;
      End;
    End;
  End;

  // Last, the connections from sensor or neuron to an action
  For conn := 0 To high(connectionList) Do Begin
    If (connectionList[conn].sinkType = ACTION) Then Begin
      setlength(nnet.connections, high(nnet.connections) + 2);
      newConn := high(nnet.connections);
      nnet.connections[newConn] := connectionList[conn];
      newConn := high(nnet.connections);

      // if the source is a neuron, fix its number
      If (nnet.connections[newConn].sourceType = NEURON) Then Begin
        nnet.connections[newConn].sourceNum := nodeMap.KeyData[nnet.connections[newConn].sourceNum].remappedNumber;
      End;
    End;
  End;

  // Create the indiv's neural node list
  setlength(nnet.neurons, NodeMap.count);
  For neuronNum := 0 To NodeMap.Count - 1 Do Begin
    nnet.neurons[neuronNum].output := initialNeuronOutput;
    nnet.neurons[neuronNum].driven := (nodeMap.Data[neuronNum].numInputsFromSensorsOrOtherNeurons <> 0);
  End;
  NodeMap.Clear;
  NodeMap.Free;
  setlength(connectionList, 0);
End;

Procedure TIndiv.printNeuralNet;
Var
  conn, neuronNum: integer;
  neuronDisplayed, actionDisplayed: boolean;
  act: unsigned;
Begin
  For act := 0 To integer(NUM_ACTIONS) - 1 Do Begin
    actionDisplayed := false;
    For conn := 0 To high(nnet.connections) Do Begin
      assert(((nnet.connections[conn].sourceType = NEURON) And (nnet.connections[conn].sourceNum < p.maxNumberNeurons))
        Or ((nnet.connections[conn].sourceType = SENSOR) And (nnet.connections[conn].sourceNum < integer(TSensor.NUM_SENSES))));

      assert(((nnet.connections[conn].sinkType = NEURON) And (nnet.connections[conn].sinkNum < p.maxNumberNeurons))
        Or ((nnet.connections[conn].sinkType = ACTION) And (nnet.connections[conn].sinkNum < integer(TAction.NUM_ACTIONS))));

      If (nnet.connections[conn].sinkType = ACTION) And (nnet.connections[conn].sinkNum = act) Then Begin
        If (Not actionDisplayed) Then Begin
          writeln('Action ' + actionName(TAction(act)) + ' from:');
          actionDisplayed := true;
        End;
        If (nnet.connections[conn].sourceType = SENSOR) Then Begin
          writeln('   ' + sensorName(TSensor((nnet.connections[conn].sourceNum))));
        End
        Else Begin
          Writeln('   Neuron ' + inttostr(nnet.connections[conn].sourceNum Mod length(nnet.neurons)));
        End;
        writeln(' ' + floattostr(nnet.connections[conn].weightAsFloat()));
      End;
    End;
  End;

  For neuronNum := 0 To high(nnet.neurons) Do Begin
    neuronDisplayed := false;
    For conn := 0 To high(nnet.connections) Do Begin

      If (nnet.connections[conn].sinkType = NEURON) And (nnet.connections[conn].sinkNum = neuronNum) Then Begin
        If (Not neuronDisplayed) Then Begin
          writeln('Neuron ' + inttostr(neuronNum) + ' from:');
          neuronDisplayed := true;
        End;
        If (nnet.connections[conn].sourceType = SENSOR) Then Begin
          writeln('   ' + sensorName(TSensor((nnet.connections[conn].sourceNum))));
        End
        Else Begin
          Writeln('   Neuron ' + inttostr((nnet.connections[conn].sourceNum)));
        End;
        writeln(' ' + floattostr(nnet.connections[conn].weightAsFloat()));
      End;
    End;
  End;
End;

// This prints a neural net in a form that can be processed with
// graph-nnet.py to produce a graphic illustration of the net.

Procedure TIndiv.printIGraphEdgeList;
Var
  conn: Integer;
  s: String;
Begin
  For conn := 0 To high(nnet.connections) Do Begin
    If (nnet.connections[conn].sourceType = SENSOR) Then Begin
      s := sensorShortName(TSensor(nnet.connections[conn].sourceNum));
    End
    Else Begin
      s := 'N' + inttostr(nnet.connections[conn].sourceNum);
    End;

    s := s + ' ';

    If (nnet.connections[conn].sinkType = ACTION) Then Begin
      s := s + actionShortName(TAction(nnet.connections[conn].sinkNum));
    End
    Else Begin
      s := s + 'N' + inttostr(nnet.connections[conn].sinkNum);
    End;
    writeln(s + ' ' + inttostr(nnet.connections[conn].weight));
  End;
End;

// Format: 32-bit hex strings, one per gene

Procedure TIndiv.printGenome;
Const
  genesPerLine = 8;
Var
  count: unsigned;
  s: String;
  i: Integer;
  n: uint32_t;
Begin
  count := 0;
  s := '';
  For i := 0 To high(genome) Do Begin
    If (count = genesPerLine) Then Begin
      writeln(trim(s));
      s := '';
      count := 0;
    End;
    n := GetCompressedGene(genome[i]);
    s := s + format(' %0.8X', [n]);
    inc(count);
  End;
  writeln(trim(s));
End;

(********************************************************************************
This function does a neural net feed-forward operation, from sensor (input) neurons
through internal neurons to action (output) neurons. The feed-forward
calculations are evaluated once each simulator step (simStep).

There is no back-propagation in this simulator. Once an individual's neural net
brain is wired at birth, the weights and topology do not change during the
individual's lifetime.

The data structure Indiv::neurons contains internal neurons, and Indiv::connections
holds the connections between the neurons.

We have three types of neurons:

     input sensors - each gives a value in the range SENSOR_MIN.. SENSOR_MAX (0.0..1.0).
         Values are obtained from getSensor().

     internal neurons - each takes inputs from sensors or other internal neurons;
         each has output value in the range NEURON_MIN..NEURON_MAX (-1.0..1.0). The
         output value for each neuron is stored in Indiv::neurons[] and survives from
         one simStep to the next. (For example, a neuron that feeds itself will use
         its output value that was latched from the previous simStep.) Inputs to the
         neurons are summed each simStep in a temporary container and then discarded
         after the neurons' outputs are computed.

     action (output) neurons - each takes inputs from sensors or other internal
         neurons; In this function, each has an output value in an arbitrary range
         (because they are the raw sums of zero or more weighted inputs).
         The values of the action neurons are saved in local container
         actionLevels[] which is returned to the caller by value (thanks RVO).
********************************************************************************)

Function TIndiv.feedForward(simStep: unsigned): TActionArray;
Var
  actionLevels: TActionArray;
  neuronAccumulators: Array Of Float;
  neuronOutputsComputed: Boolean;
  gene, i, neuronIndex: Integer;
  inputVal: Float;
Begin
  // This container is used to return values for all the action outputs. This array
  // contains one value per action neuron, which is the sum of all its weighted
  // input connections. The sum has an arbitrary range. Return by value assumes compiler
  // return value optimization.
  actionLevels[0] := 0; // This is rubish, but kills the Compiler warning ;)
  FillChar(actionLevels, sizeof(actionLevels), 0); // undriven actions default to value 0.0

  // Weighted inputs to each neuron are summed in neuronAccumulators[]
  neuronAccumulators := nil;
  setlength(neuronAccumulators, length(nnet.neurons));
  For i := 0 To High(neuronAccumulators) Do Begin
    neuronAccumulators[i] := 0.0;
  End;

  // Connections were ordered at birth so that all connections to neurons get
  // processed here before any connections to actions. As soon as we encounter the
  // first connection to an action, we'll pass all the neuron input accumulators
  // through a transfer function and update the neuron outputs in the indiv,
  // except for undriven neurons which act as bias feeds and don't change. The
  // transfer function will leave each neuron's output in the range -1.0..1.0.

  neuronOutputsComputed := false;
  For gene := 0 To high(nnet.connections) Do Begin

    If (nnet.connections[gene].sinkType = ACTION) And (Not neuronOutputsComputed) Then Begin
      // We've handled all the connections from sensors and now we are about to
      // start on the connections to the action outputs, so now it's time to
      // update and latch all the neuron outputs to their proper range (-1.0..1.0)
      For neuronIndex := 0 To high(nnet.neurons) Do Begin
        If (nnet.neurons[neuronIndex].driven) Then Begin
          nnet.neurons[neuronIndex].output := TanH(neuronAccumulators[neuronIndex]);
        End;
      End;
      neuronOutputsComputed := true;
    End;

    // Obtain the connection's input value from a sensor neuron or other neuron
    // The values are summed for now, later passed through a transfer function

    If (nnet.connections[gene].sourceType = SENSOR) Then Begin
      inputVal := getSensor(TSensor(nnet.connections[gene].sourceNum), simStep);
    End
    Else Begin
      inputVal := nnet.neurons[nnet.connections[gene].sourceNum].output;
    End;

    // Weight the connection's value and add to neuron accumulator or action accumulator.
    // The action and neuron accumulators will therefore contain +- float values in
    // an arbitrary range.
    If (nnet.connections[gene].sinkType = ACTION) Then Begin
      actionLevels[nnet.connections[gene].sinkNum] := actionLevels[nnet.connections[gene].sinkNum] + inputVal * nnet.connections[gene].weightAsFloat();
    End
    Else Begin
      neuronAccumulators[nnet.connections[gene].sinkNum] := neuronAccumulators[nnet.connections[gene].sinkNum] + inputVal * nnet.connections[gene].weightAsFloat();
    End;
  End;
  result := actionLevels;
End;

Var
  countOccupied: Unsigned;

Procedure CountPopulation(Coord: TCoord);
Begin
  countLocs := countLocs + 1;
  If grid.isOccupiedAt(Coord) Then Begin
    countOccupied := countOccupied + 1;
  End;
End;

// Returned sensor values range SENSOR_MIN..SENSOR_MAX

Function TIndiv.getSensor(sensorNum: TSensor; simStep: unsigned): float;
Var
  sensorVal: float;
  lastY, lastX, minDistX, minDistY,
    maxPossible, distY, distX, closest: integer;
  phase, factor: Single;
  loc2, center: TCoord;
  indiv2: PIndiv;
Begin
  sensorVal := 0.0;
  Case Tsensor(sensorNum) Of
    tsensor.AGE: Begin
        // Converts age (units of simSteps compared to life expectancy)
        // linearly to normalized sensor range 0.0..1.0
        sensorVal := age / p.stepsPerGeneration;
      End;

    tSensor.BOUNDARY_DIST: Begin
        // Finds closest boundary, compares that to the max possible dist
        // to a boundary from the center, and converts that linearly to the
        // sensor range 0.0..1.0
        distX := min(loc.x, (p.sizeX - loc.x) - 1);
        distY := min(loc.y, (p.sizeY - loc.y) - 1);
        closest := min(distX, distY);
        maxPossible := max(p.sizeX Div 2 - 1, p.sizeY Div 2 - 1);
        sensorVal := closest / maxPossible;
      End;
    tSensor.BOUNDARY_DIST_X: Begin
        // Measures the distance to nearest boundary in the east-west axis,
        // max distance is half the grid width; scaled to sensor range 0.0..1.0.
        minDistX := min(loc.x, (p.sizeX - loc.x) - 1);
        sensorVal := minDistX / (p.sizeX / 2.0);
      End;
    TSensor.BOUNDARY_DIST_Y: Begin
        // Measures the distance to nearest boundary in the south-north axis,
        // max distance is half the grid height; scaled to sensor range 0.0..1.0.
        minDistY := min(loc.y, (p.sizeY - loc.y) - 1);
        sensorVal := minDistY / (p.sizeY / 2.0);
      End;
    TSensor.LAST_MOVE_DIR_X: Begin
        // X component -1,0,1 maps to sensor values 0.0, 0.5, 1.0
        lastX := asNormalizedCoord(lastMoveDir).x;
        If lastx = 0 Then Begin
          sensorVal := 0.5;
        End
        Else Begin
          If lastX = -1 Then Begin
            sensorVal := 0;
          End
          Else Begin
            sensorVal := 1;
          End;
        End;
      End;
    TSensor.LAST_MOVE_DIR_Y: Begin
        // Y component -1,0,1 maps to sensor values 0.0, 0.5, 1.0
        lastY := asNormalizedCoord(lastMoveDir).y;
        If lastY = 0 Then Begin
          sensorVal := 0.5;
        End
        Else Begin
          If lastY = -1 Then Begin
            sensorVal := 0;
          End
          Else Begin
            sensorVal := 1;
          End;
        End;
      End;
    TSensor.LOC_X: Begin
        // Maps current X location 0..p.sizeX-1 to sensor range 0.0..1.0
        sensorVal := loc.x / (p.sizeX - 1);
      End;
    TSensor.LOC_Y: Begin
        // Maps current Y location 0..p.sizeY-1 to sensor range 0.0..1.0
        sensorVal := loc.y / (p.sizeY - 1);
      End;
    TSensor.OSC1: Begin
        // Maps the oscillator sine wave to sensor range 0.0..1.0;
        // cycles starts at simStep 0 for everbody.
        phase := (simStep Mod oscPeriod) / oscPeriod; // 0.0..1.0
        factor := -cos(phase * 2.0 * Pi);
        assert((factor >= -1.0) And (factor <= 1.0));
        factor := factor + 1.0; // convert to 0.0..2.0
        factor := factor / 2.0; // convert to 0.0..1.0
        sensorVal := factor;
        // Clip any round-off error
        sensorVal := min(1.0, max(0.0, sensorVal));
      End;
    TSensor.LONGPROBE_POP_FWD: Begin
        // Measures the distance to the nearest other individual in the
        // forward direction. If non found, returns the maximum sensor value.
        // Maps the result to the sensor range 0.0..1.0.
        sensorVal := longProbePopulationFwd(loc, lastMoveDir, longProbeDist) / longProbeDist; // 0..1
      End;
    TSensor.LONGPROBE_BAR_FWD: Begin
        // Measures the distance to the nearest barrier in the forward
        // direction. If non found, returns the maximum sensor value.
        // Maps the result to the sensor range 0.0..1.0.
        sensorVal := longProbeBarrierFwd(loc, lastMoveDir, longProbeDist) / longProbeDist; // 0..1
      End;
    TSensor.POPULATION: Begin
        // Returns population density in neighborhood converted linearly from
        // 0..100% to sensor range
        countLocs := 0;
        countOccupied := 0;
        visitNeighborhood(center, p.populationSensorRadius, @CountPopulation);
        sensorVal := countOccupied / countLocs;
      End;
    TSensor.POPULATION_FWD: Begin
        // Sense population density along axis of last movement direction, mapped
        // to sensor range 0.0..1.0
        sensorVal := getPopulationDensityAlongAxis(loc, lastMoveDir);
      End;
    TSensor.POPULATION_LR: Begin
        // Sense population density along an axis 90 degrees from last movement direction
        sensorVal := getPopulationDensityAlongAxis(loc, lastMoveDir.rotate90DegCW());
      End;
    TSensor.BARRIER_FWD: Begin
        // Sense the nearest barrier along axis of last movement direction, mapped
        // to sensor range 0.0..1.0
        sensorVal := getShortProbeBarrierDistance(loc, lastMoveDir, p.shortProbeBarrierDistance);
      End;
    TSensor.BARRIER_LR: Begin
        // Sense the nearest barrier along axis perpendicular to last movement direction, mapped
        // to sensor range 0.0..1.0
        sensorVal := getShortProbeBarrierDistance(loc, lastMoveDir.rotate90DegCW(), p.shortProbeBarrierDistance);
      End;
    TSensor.RANDOM: Begin
        // Returns a random sensor value in the range 0.0..1.0.
        sensorVal := randomUint.rnd() / RANDOM_UINT_MAX;
      End;
    TSensor.SIGNAL0: Begin
        // Returns magnitude of signal0 in the local neighborhood, with
        // 0.0..maxSignalSum converted to sensorRange 0.0..1.0
        sensorVal := getSignalDensity(0, loc);
      End;
    TSensor.SIGNAL0_FWD: Begin
        // Sense signal0 density along axis of last movement direction
        sensorVal := getSignalDensityAlongAxis(0, loc, lastMoveDir);
      End;
    TSensor.SIGNAL0_LR: Begin
        // Sense signal0 density along an axis perpendicular to last movement direction
        sensorVal := getSignalDensityAlongAxis(0, loc, lastMoveDir.rotate90DegCW());
      End;
    TSensor.GENETIC_SIM_FWD: Begin
        // Return minimum sensor value if nobody is alive in the forward adjacent location,
        // else returns a similarity match in the sensor range 0.0..1.0
        loc2 := loc + lastMoveDir;
        If (grid.isInBounds(loc2) And grid.isOccupiedAt(loc2)) Then Begin
          indiv2 := peeps.getIndiv(loc2);
          If (indiv2^.alive) Then Begin
            sensorVal := genomeSimilarity(genome, indiv2^.genome); // 0.0..1.0
          End;
        End;
      End;
  Else
    assert(false);
  End;

  If IsNan(sensorVal) Or (sensorVal < -0.01) Or (sensorVal > 1.01) Then Begin
    writelN('sensorVal=' + inttostr(trunc(sensorVal)) + ' for ' + sensorName(TSensor(sensorNum)));
    sensorVal := max(0.0, min(sensorVal, 1.0)); // clip
  End;

  assert((Not isnan(sensorVal)) And (sensorVal >= -0.01) And (sensorVal <= 1.01));

  result := sensorVal;
End;

End.

