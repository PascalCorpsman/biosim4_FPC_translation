Unit ugenome;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

// Each gene specifies one synaptic connection in a neural net. Each
// connection has an input (source) which is either a sensor or another neuron.
// Each connection has an output, which is either an action or another neuron.
// Each connection has a floating point weight derived from a signed 16-bit
// value. The signed integer weight is scaled to a small range, then cubed
// to provide fine resolution near zero.

Const
  SENSOR = 1; // always a source
  ACTION = 1; // always a sink
  NEURON = 0; // can be either a source or sink

  // When a new population is generated and every individual is given a
  // neural net, the neuron outputs must be initialized to something:
  // constexpr float initialNeuronOutput() { return (NEURON_RANGE / 2.0) + NEURON_MIN; }
  initialNeuronOutput = 0.5;

Type

  { TGene }

  TGene = Object //__attribute__((packed)) Gene {
    sourceType: uint16_t; // SENSOR or NEURON 1-Bit
    sourceNum: uint16_t; // 7-Bit
    sinkType: uint16_t; // NEURON or ACTION 1-Bit
    sinkNum: uint16_t; // 7-Bit
    weight: int16_t;
    Function weightAsFloat(): Float;
    Function makeRandomWeight(): int16_t;
  End;


  // An individual's genome is a set of Genes (see Gene comments above). Each
  // gene is equivalent to one connection in a neural net. An individual's
  // neural net is derived from its set of genes.
  TGenome = Array Of TGene;

  // An individual's "brain" is a neural net specified by a set
  // of Genes where each Gene specifies one connection in the neural net (see
  // Genome comments above . Each neuron has a single output which is
  // connected to a set of sinks where each sink is either an action output
  // or another neuron. Each neuron has a set of input sources where each
  // source is either a sensor or another neuron. There is no concept of
  // layers in the net: it's a free-for-all topology with forward, backwards,
  // and sideways connection allowed. Weighted connections are allowed
  // directly from any source to any action.

  // Currently the genome does not specify the activation function used in
  // the neurons. (May be hardcoded to std::tanh() !!!)

  // When the input is a sensor, the input value to the sink is the raw
  // sensor value of type float and depends on the sensor. If the output
  // is an action, the source's output value is interpreted by the action
  // node and whether the action occurs or not depends on the action's
  // implementation.

  // In the genome, neurons are identified by 15-bit unsigned indices,
  // which are reinterpreted as values in the range 0..p.genomeMaxLength-1
  // by taking the 15-bit index modulo the max number of allowed neurons.
  // In the neural net, the neurons that end up connected get new indices
  // assigned sequentially starting at 0.

  TNeuron = Record
    output: float;
    driven: bool; // undriven neurons have fixed output values
  End;

  TNeuralNet = Record
    connections: Array Of TGene; // connections are equivalent to genes
    neurons: Array Of TNeuron; //    std::vector<Neuron> neurons;
  End;

  TGenomeArray = Array Of TGenome;

Function makeRandomGene(): TGene;

// Returns by value a single genome with random genes.
Function makeRandomGenome(): TGenome;

Function generateChildGenome(Var parentGenomes: TGenomeArray): TGenome;

Function geneticDiversity(): float;

Function genomeSimilarity(Const g1, g2: TGenome): Float;
Function GetCompressedGene(Const gene: TGene): uint32_t; // Komprimiert die TGene Datenstruktur in 32-Bit (damit die dann "Packed" ist).
Function GetGeneFromUInt(value: uint32_t): TGene; // Umkehrfunktion zu GetCompressedGene

Operator = (g1, g2: TGene): Boolean; // True if genes are identical

Implementation

Uses uparams, urandom, Math, upeeps, uSimulator;

Operator = (g1, g2: TGene): Boolean;
Begin
  result :=
    (g1.sourceType = g2.sourceType) And
    (g1.sourceNum = g2.sourceNum) And
    (g1.sinkType = g2.sinkType) And
    (g1.sinkNum = g2.sinkNum) And
    (g1.weight = g2.weight);
End;

Function GetCompressedGene(Const gene: TGene): uint32_t;
Var
  sot, son, sit, sin, w: uint32_t;
  wsi: int16;
  wi: uint16 absolute wsi;
Begin
  (*
   * Die Datenstruktur von TGene ist im Prinzip 32-Bit Groß
   * Hier werden diese 32-Bit zusammengepackt zu
   * <16:weight> <7:sinkNum> <1:sinkType> <7:sourceNum> <1:sourceType>
   * weight ist dabei eine Fließkommazahl in [-4 .. 4]
   *)
  sot := gene.sourceType And $0001;
  son := gene.sourceNum And $007F;
  sit := gene.sinkType And $0001;
  sin := gene.sinkNum And $007F;
  wsi := gene.weight;

  //sot := sot Shl 0;
  son := son Shl 1;
  sit := sit Shl 8;
  sin := sin Shl 9;
  w := wi Shl 16;

  result := sot + son + sit + sin + w;
End;

Function GetGeneFromUInt(value: uint32_t): TGene; // Umkehrfunktion zu GetCompressedGene
Begin
  result.sourceType := (value Shr 0) And $0001;
  result.sourceNum := (value Shr 1) And $007F;
  result.sinkType := (value Shr 8) And $0001;
  result.sinkNum := (value Shr 9) And $007F;
  result.weight := (value Shr 16) And $FFFF;
  assert(value = GetCompressedGene(result));
End;

(*
 * __builtin_popcount(x) is a function in C++ returns the number of 1-bits set
 * in an int x. In fact, "popcount" stands for "population count," so this is a
 * function to determine how "populated" an integer is.
 *)

Function __builtin_popcount(v: uint32_t): integer;
Var
  i: Integer;
Begin
  result := 0;
  For i := 0 To 31 Do Begin
    If ((1 Shl i) And v) <> 0 Then Begin
      result := result + 1;
    End;
  End;
End;

// Returns by value a single gene with random members.
// See genome.h for the width of the members.

Function makeRandomGene(): TGene;
Var
  Gene: Tgene;
Begin
  gene.sourceType := randomUint.Rnd() And 1;
  gene.sourceNum := randomUint.RndRange(0, $7F); // Beschränken auf die 7-Bit die wir im Gen haben - Sonst geht das Laden / Speichern Schief weil dort ja definitiv auf 7-Bit gekürzt wird!
  gene.sinkType := randomUint.rnd() And 1;
  gene.sinkNum := randomUint.RndRange(0, $7F); // Beschränken auf die 7-Bit die wir im Gen haben - Sonst geht das Laden / Speichern Schief weil dort ja definitiv auf 7-Bit gekürzt wird!
  gene.weight := Gene.makeRandomWeight();

  result := gene;
End;

Function makeRandomGenome: TGenome;
Var
  genome: TGenome;
  length: unsigned;
  n: Integer;
Begin
  genome := Nil;
  length := randomUint.RndRange(p.genomeInitialLengthMin, p.genomeInitialLengthMax);
  setlength(genome, length);
  For n := 0 To high(genome) Do Begin
    genome[n] := makeRandomGene();
  End;
  result := genome;
End;

Procedure overlayWithSliceOf(Var Genome: TGenome; gshorter: TGenome);
Var
  index0, index1, t, i: integer;
Begin
  index0 := randomUint.RndRange(0, length(gShorter) - 1);
  index1 := randomUint.RndRange(0, length(gShorter));
  If (index0 > index1) Then Begin
    t := index0;
    index0 := index1;
    index1 := t;
  End;
  For i := index0 To index1 - 1 Do Begin
    Genome[i] := gshorter[i];
  End;
End;

// If the genome is longer than the prescribed length, and if it's longer
// than one gene, then we remove genes from the front or back. This is
// used only when the simulator is configured to allow genomes of
// unequal lengths during a simulation.

Procedure cropLength(Var genome: TGenome; nlength: unsigned);
Var
  numberElementsToTrim, i: integer;
Begin
  If (length(genome) > nlength) And (nlength > 0) Then Begin
    If (randomUint.Rnd() / RANDOM_UINT_MAX < 0.5) Then Begin
      // trim front
      numberElementsToTrim := length(genome) - nlength;
      For i := numberElementsToTrim To length(genome) - 1 Do Begin
        genome[i - numberElementsToTrim] := genome[i];
      End;
      setlength(genome, nlength);
    End
    Else Begin
      // trim back
      setlength(genome, nlength);
    End;
  End;
End;

// Inserts or removes a single gene from the genome. This is
// used only when the simulator is configured to allow genomes of
// unequal lengths during a simulation.

Procedure randomInsertDeletion(Var Genome: Tgenome);
Var
  probability: Float;
  index, i: unsigned;
Begin
  probability := p.geneInsertionDeletionRate;
  If (randomUint.Rnd() / RANDOM_UINT_MAX < probability) Then Begin
    If (randomUint.Rnd() / RANDOM_UINT_MAX < p.deletionRatio) Then Begin
      // deletion
      If (length(genome) > 1) Then Begin
        index := randomUint.RndRange(0, length(genome) - 1);
        For i := index To high(Genome) - 1 Do Begin
          Genome[i] := Genome[i + 1];
        End;
        setlength(Genome, high(Genome));
      End;
    End
    Else If (length(genome) < p.genomeMaxLength) Then Begin
      // insertion
      (*
       * Ist aus welchem Grund auch immer Deaktiviert, aber wahrscheinlich ist
       * es egal wo das Gen steht, da sie alle Gleichwertig sind.
       * => also einfach hinten dran.
       *)
      //index := randomUint.RndRange(0, length(genome) - 1);
      //setlength(Genome, high(Genome) + 2);
      //For i := high(Genome) Downto index + 1 Do Begin
      //  Genome[i] := Genome[i - 1];
      //End;
      //Genome[index] := makeRandomGene();
      setlength(Genome, high(Genome) + 2);
      Genome[high(Genome)] := makeRandomGene();
    End;
  End;
End;


// This applies a point mutation at a random bit in a genome.

Procedure randomBitFlip(Var Genome: Tgenome);
Var
  elementIndex, bitIndex8: unsigned;
  chance: Single;
Begin
  elementIndex := randomUint.RndRange(0, length(genome) - 1);
  bitIndex8 := 1 Shl randomUint.RndRange(0, 7);

  chance := randomUint.Rnd() / RANDOM_UINT_MAX; // 0..1
  If (chance < 0.2) Then Begin // sourceType
    genome[elementIndex].sourceType := genome[elementIndex].sourceType Xor 1;
  End
  Else If (chance < 0.4) Then Begin // sinkType
    genome[elementIndex].sinkType := genome[elementIndex].sinkType Xor 1;
  End
  Else If (chance < 0.6) Then Begin // sourceNum
    genome[elementIndex].sourceNum := genome[elementIndex].sourceNum Xor bitIndex8;
  End
  Else If (chance < 0.8) Then Begin // sinkNum
    genome[elementIndex].sinkNum := genome[elementIndex].sinkNum Xor bitIndex8;
  End
  Else Begin // weight
    genome[elementIndex].weight := genome[elementIndex].weight Xor (1 Shl randomUint.RndRange(1, 15));
  End;
End;

// This function causes point mutations in a genome with a probability defined
// by the parameter p.pointMutationRate.

Procedure applyPointMutations(Var Genome: Tgenome);
Var
  numberOfGenes: unsigned;
  i: Integer;
Begin
  If p.pointMutationRate = 0 Then exit; // wenn es eh keine Mutationen gibt sparen wir uns die Rechenzeit ;)
  numberOfGenes := length(genome);
  For i := 0 To numberOfGenes - 1 Do Begin
    //while (numberOfGenes-- > 0) {
    If ((randomUint.Rnd() / RANDOM_UINT_MAX) < p.pointMutationRate) Then Begin
      randomBitFlip(genome);
    End;
  End;
End;

// This generates a child genome from one or two parent genomes.
// If the parameter p.sexualReproduction is true, two parents contribute
// genes to the offspring. The new genome may undergo mutation.
// Must be called in single-thread mode between generations

Function generateChildGenome(Var parentGenomes: TGenomeArray): TGenome;
Var
  // random parent (or parents if sexual reproduction) with random
  // mutations
  g1, g2, genome: TGenome;
  parent1Idx, parent2Idx, j: Integer;
  sum: unsigned;
Begin
  genome := Nil;
  // Choose two parents randomly from the candidates. If the parameter
  // p.chooseParentsByFitness is false, then we choose at random from
  // all the candidate parents with equal preference. If the parameter is
  // true, then we give preference to candidate parents according to their
  // score. Their score was computed by the survival/selection algorithm
  // in survival-criteria.cpp.
  If p.chooseParentsByFitness And (length(parentGenomes) > 1) Then Begin
    parent1Idx := randomUint.RndRange(1, length(parentGenomes) - 1);
    parent2Idx := randomUint.RndRange(0, parent1Idx - 1);
  End
  Else Begin
    parent1Idx := randomUint.RndRange(0, length(parentGenomes) - 1);
    parent2Idx := randomUint.RndRange(0, length(parentGenomes) - 1);
  End;

  g1 := parentGenomes[parent1Idx];
  g2 := parentGenomes[parent2Idx];

  If (length(g1) = 0) Or (length(g2) = 0) Then Begin
    writeln('invalid genome');
    assert(false);
  End;

  If (p.sexualReproduction) Then Begin
    If length(g1) > length(g2) Then Begin
      setlength(genome, length(g1));
      For j := 0 To high(g1) Do Begin
        genome[j] := g1[j];
      End;
      overlayWithSliceOf(genome, g2);
      assert(length(genome) <> 0);
    End
    Else Begin
      setlength(genome, length(g2));
      For j := 0 To high(g2) Do Begin
        genome[j] := g2[j];
      End;
      overlayWithSliceOf(genome, g1);
      assert(length(genome) <> 0);
    End;
    // Trim to length = average length of parents
    sum := length(g1) + length(g2);
    // If average length is not an integral number, add one half the time
    If ((sum And 1 = 1) And (randomUint.Rnd() And 1 = 1)) Then Begin
      sum := sum + 1;
    End;

    cropLength(genome, sum Div 2);
    assert(length(genome) <> 0);
  End
  Else Begin
    setlength(genome, length(g2));
    For j := 0 To high(g2) Do Begin
      genome[j] := g2[j];
    End;
    assert(length(genome) <> 0);
  End;

  randomInsertDeletion(genome);
  assert(length(genome) <> 0);
  applyPointMutations(genome);
  assert(length(genome) <> 0);
  assert(length(genome) <= p.genomeMaxLength);

  result := genome;
End;

Function geneticDiversity(): float;
Var
  count: unsigned;
  numSamples: integer;
  similaritySum: Float;
  index0, index1: unsigned;
Begin
  If (p.population < 2) Then Begin
    result := 0.0;
    exit;
  End;

  // count limits the number of genomes sampled for performance reasons.
  count := min(1000, p.population); // todo: !!! p.analysisSampleSize;
  numSamples := 0;
  similaritySum := 0.0;

  While count > 0 Do Begin
    index0 := randomUint.RndRange(1, p.population - 1); // skip first and last elements
    index1 := index0 + 1;
    similaritySum := similaritySum + genomeSimilarity(peeps[index0]^.genome, peeps[index1]^.genome);
    count := Count - 1;
    numSamples := numSamples + 1;
  End;

  result := 1.0 - (similaritySum / numSamples);
End;

// Approximate gene match: Has to match same source, sink, with similar weight

Function genesMatch(Const g1, g2: TGene): Boolean;
Begin
  result := (g1.sinkNum = g2.sinkNum)
    And (g1.sourceNum = g2.sourceNum)
    And (g1.sinkType = g2.sinkType)
    And (g1.sourceType = g2.sourceType)
    And (g1.weight = g2.weight);
End;


// The jaro_winkler_distance() function is adapted from the C version at
// https://github.com/miguelvps/c/blob/master/jarowinkler.c
// under a GNU license, ver. 3. This comparison function is useful if
// the simulator allows genomes to change length, or if genes are allowed
// to relocate to different offsets in the genome. I.e., this function is
// tolerant of gaps, relocations, and genomes of unequal lengths.

Function jaro_winkler_distance(Const genome1, genome2: TGenome): float;
(*
 * The Orig c++ code is dropped, instead i took the code from:
 *  https://rosettacode.org/wiki/Jaro_similarity#Pascal
 * and integrated the maxNumGenesToCompare feature
 *)
Const
  maxNumGenesToCompare = 20;
Var
  l1, l2, match_distance, matches, i, k, trans: integer;
  bs1, bs2: Array[1..255] Of boolean; //used to avoid getmem, max string length is 255
Begin
  l1 := min(maxNumGenesToCompare, length(genome1));
  l2 := min(maxNumGenesToCompare, length(genome2));
  bs1[1] := false; // This is rubish, but kills the Compiler warning ;)
  bs2[1] := false; // This is rubish, but kills the Compiler warning ;)
  fillchar(bs1, sizeof(bs1), 0); //set booleans to false
  fillchar(bs2, sizeof(bs2), 0);
  If l1 = 0 Then
    If l2 = 0 Then
      exit(1)
    Else
      exit(0);
  match_distance := (max(l1, l2) Div 2) - 1;
  matches := 0;
  trans := 0;
  For i := 1 To l1 Do Begin
    For k := max(1, i - match_distance) To min(i + match_distance, l2) Do Begin
      If bs2[k] Then
        continue;
      If Not genesMatch(genome1[i], genome2[k]) Then
        continue;
      bs1[i] := true;
      bs2[k] := true;
      inc(matches);
      break;
    End;
  End;
  If matches = 0 Then
    exit(0);
  k := 1;
  For i := 1 To l1 Do Begin
    If (bs1[i] = false) Then
      continue;
    While (bs2[k] = false) Do
      inc(k);
    If Not genesMatch(genome1[i], genome2[k]) Then
      inc(trans);
    inc(k);
  End;
  trans := trans Div 2;
  result := ((matches / l1) + (matches / l2) + ((matches - trans) / matches)) / 3;
End;

// Works only for genomes of equal length

Function hammingDistanceBits(Const genome1, genome2: TGenome): float;
Var
  bitCount, lengthBits, lengthBytes, bytesPerElement, numElements: unsigned;
  index: Integer;
Begin
  If (length(genome1) <> length(genome2)) Then Begin
    Raise exception.create('Error, hammingDistanceBits only works for genes with equal length.');
  End;

  numElements := length(genome1);
  bytesPerElement := sizeof(GetCompressedGene(genome1[0]));
  lengthBytes := numElements * bytesPerElement;
  lengthBits := lengthBytes * 8;
  bitCount := 0;

  For index := 0 To length(genome1) - 1 Do Begin
    bitCount := bitCount + __builtin_popcount(GetCompressedGene(genome1[index]) Xor GetCompressedGene(genome2[index]));
  End;

  // For two completely random bit patterns, about half the bits will differ,
  // resulting in c. 50% match. We will scale that by 2X to make the range
  // from 0 to 1.0. We clip the value to 1.0 in case the two patterns are
  // negatively correlated for some reason.
  result := 1.0 - min(1.0, (2.0 * bitCount) / lengthBits);
End;


// Works only for genomes of equal length

Function hammingDistanceBytes(Const genome1, genome2: TGenome): FLoat;
Var
  numElements: unsigned;
  bytesPerElement, lengthBytes, byteCount, index: Integer;
  a, b: uint32_t;
Begin
  If (length(genome1) <> length(genome2)) Then Begin
    Raise exception.create('Error, hammingDistanceBytes only works for genes with equal length.');
  End;

  numElements := length(genome1);
  bytesPerElement := sizeof(GetCompressedGene(genome1[0]));
  lengthBytes := numElements * bytesPerElement;
  byteCount := 0;

  For index := 0 To length(genome1) - 1 Do Begin
    a := GetCompressedGene(genome1[index]);
    b := GetCompressedGene(genome2[index]);
    If a = b Then Begin
      inc(byteCount);
    End;
  End;
  result := byteCount / lengthBytes;
End;

Function genomeSimilarity(Const g1, g2: TGenome): Float;
Begin
  Case (p.genomeComparisonMethod) Of
    0: result := jaro_winkler_distance(g1, g2);
    1: result := hammingDistanceBits(g1, g2);
    2: result := hammingDistanceBytes(g1, g2);
  Else Begin
      assert(false);
    End;
  End;
End;

{ TGene }

Function TGene.weightAsFloat: Float;
Begin
  result := weight / 8192.0;
End;

Function TGene.makeRandomWeight: int16_t;
Begin
  result := randomUint.RndRange(0, $FFFF) - $8000;
End;

End.

