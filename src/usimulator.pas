Unit uSimulator;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, uparams, ugrid, usignals, upeeps, uImageWriter, ugenome;

{$I c_types.inc}
{$INTERFACES corba}
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

Type

  TLoadSim = Record
    parentGenomes: TGenomeArray;
    Generation: Integer;
  End;

  { TSimulator }

  TSimulator = Class
  private
    (*
     * Variablen welche von LoadSim initialisiert werden damit
     *)
    fLoadSim: TLoadSim;
    (*
     * Rest
     *)
    fParamManager: TParamManager; // manages simulator params from the config file plus more
    Procedure PrintHelp;

    Procedure OnWritelnCallback(Sender: TObject; Line: String);
    Procedure SetCrashed(AValue: Boolean);

    Function LoadSim(Const Filename: String): String;
  public
    Property Crashed: Boolean write SetCrashed;
    Constructor Create();
    Destructor Destroy(); override;
    Class Procedure SaveSim(Generation: integer; Const parentGenomes: TGenomeArray); // This container will hold the genomes of the survivors

    Procedure Simulator(Filename: String); // Init Procedure
  End;

Var
  grid: TGrid = Nil; // The 2D world where the creatures live
  signals: TSignals = Nil; // A 2D array of pheromones that overlay the world grid
  peeps: TPeeps = Nil; // The container of all the individuals in the population
  ImageWriter: IImageWriterInterface = Nil; // This is for generating the movies
  AdditionalVideoFrame: Boolean = false; // If true, the next generation will definitly write a video

Implementation

Uses usensoractions, urandom, uspawnNewGeneration, uindiv, uexecuteActions,
  uEndOfSimStep, uEndOfGeneration, uanalysis, crt, uUnittests;

Var
  fFilename: String = ''; // Das hier ist nicht gerade Ideal, aber die Class function braucht ne Variable auf die sie zugreifen kann

  // This file contains simulator(), the top-level entry point of the simulator.
  // simulator() is called from main.cpp with a copy of argc and argv.
  // If there is no command line argument, the simulator will read the default
  // config file ("biosim4.ini" in the current directory) to get the simulation
  // parameters for this run. If there are one or more command line args, then
  // argv[1] must contain the name of the config file which will be read instead
  // of biosim4.ini. Any args after that are ignored. The simulator code is
  // in namespace BS (for "biosim").


  (**********************************************************************************************
  Execute one simStep for one individual.

  This executes in its own thread, invoked from the main simulator thread. First we execute
  indiv.feedForward() which computes action values to be executed here. Some actions such as
  signal emission(s) (pheromones), agent movement, or deaths will have been queued for
  later execution at the end of the generation in single-threaded mode (the deferred queues
  allow the main data structures (e.g., grid, signals) to be freely accessed read-only in all threads).

  In order to be thread-safe, the main simulator-wide data structures and their
  accessibility are:

      grid - read-only
      signals - (pheromones) read-write for the location where our agent lives
          using signals.increment(), read-only for other locations
      peeps - for other individuals, we can only read their index and genome.
          We have read-write access to our individual through the indiv argument.

  The other important variables are:

      simStep - the current age of our agent, reset to 0 at the start of each generation.
           For many simulation scenarios, this matches our indiv.age member.
      randomUint - global random number generator, a private instance is given to each thread
  **********************************************************************************************)

Procedure simStepOneIndiv(Indiv: Pindiv; simStep: unsigned);
Var
  actionLevels: TActionArray;
Begin
  indiv^.age := indiv^.age + 1; // for this implementation, tracks simStep
  actionLevels := indiv^.feedForward(simStep);
  executeActions(indiv, actionLevels);
End;

{ TSimulator }

Procedure TSimulator.PrintHelp;
Begin
  // TODO: Bessere Meldungen einbauen..
  writeln('biosim, ported by corpsman to lazarus /fpc');
  writeln('press ESC to end simulation after next full generation.');
  writeln('press V to force video rendering on the next generation simulation.');
End;

Procedure TSimulator.OnWritelnCallback(Sender: TObject; Line: String);
Begin
  writeln(Line);
End;

Procedure TSimulator.SetCrashed(AValue: Boolean);
Begin
  If assigned(ImageWriter) Then Begin
    ImageWriter.SetCrashed(AValue);
  End;
End;

Class Procedure TSimulator.SaveSim(Generation: integer;
  Const parentGenomes: TGenomeArray);
Var
  s, t: String; // Ziel Dateiname !
  sl: TStringList;
  i, j: Integer;
  u32: uint32_t;
  g: TGene;
Begin
  If trim(fFilename) = '' Then Begin
    writeln('Error, could not store simulation.');
    exit; // Fehler
  End;
  (*
   * Speichert alles was notwendig ist um ggf bei einem Späteren Neustart davon aus weiter rechnen zu können
   *)
  s := ExtractFileName(fFilename);
  s := Copy(s, 1, length(s) - length(ExtractFileExt(s))) + '.sim';
  sl := TStringList.Create;
  sl.add(fFilename); // 1. Die Biosim.ini merken
  sl.add(inttostr(Generation)); // Die Aktuelle Generation
  sl.Add(inttostr(length(parentGenomes)));
  For i := 0 To high(parentGenomes) Do Begin
    t := inttostr(length(parentGenomes[i])) + ' ';
    For j := 0 To high(parentGenomes[i]) Do Begin
      g := parentGenomes[i][j];
      u32 := GetCompressedGene(g);
      t := t + format('%0.8X ', [u32]);
    End;
    // Pro Zeile 1 Gen und Gut ;)
    sl.add(t);
  End;
  writeln('Store simulation data to: ' + ExtractFileName(s));
  sl.SaveToFile(s);
  sl.free;
End;

Function TSimulator.LoadSim(Const Filename: String): String;

  Function StrToGene(Value: String): TGene;
  Var
    u32: uint32_t;
    dummy: integer;
  Begin
    val('$' + Value, u32, dummy);
    If dummy <> 0 Then Begin
      u32 := 0;
      writeln('Error could not convert ' + value + ' to a gene.');
    End;
    result := GetGeneFromUInt(u32);
  End;

  Function StrToGenom(Value: String): TGenome;
  Var
    Elements: TStringArray;
    i: Integer;
  Begin
    result := Nil;
    Elements := trim(value).Split(' ');
    If length(Elements) < 2 Then exit;
    If high(Elements) <> strtointdef(Elements[0], -2) Then exit;
    setlength(result, strtoint(Elements[0]));
    For i := 0 To high(result) Do Begin
      result[i] := StrToGene(Elements[i + 1]);
    End;
  End;

Var
  sl: TStringList;
  GeneCount, i: integer;
Begin
  result := '';
  fLoadSim.Generation := -1;
  If Not FileExists(Filename) Then exit;
  sl := TStringList.Create;
  sl.LoadFromFile(Filename);
  If sl.count < 3 Then Begin // Da kann was nicht Stimmen,
    sl.free;
    exit;
  End;
  Result := sl[0];
  fLoadSim.Generation := StrToIntDef(sl[1], 0);
  GeneCount := StrToIntDef(sl[2], 0);
  setlength(fLoadSim.parentGenomes, GeneCount);
  For i := 0 To GeneCount - 1 Do Begin
    fLoadSim.parentGenomes[i] := StrToGenom(sl[3 + i]);
    If Not assigned(fLoadSim.parentGenomes[i]) Then Begin
      sl.free;
      result := '';
      fLoadSim.Generation := -1;
      exit;
    End;
  End;
  sl.free;
  writeln('Successfully loaded: ' + Filename);
End;

Constructor TSimulator.Create;
Begin
  fParamManager := TParamManager.Create;
  grid := TGrid.Create();
  signals := TSignals.Create();
  peeps := TPeeps.Create();
  ImageWriter := Nil;
End;

Destructor TSimulator.Destroy;
Begin
  If p.numThreads > 1 Then Begin
    writeln('Waiting for threads to shut down.');
  End;
  fParamManager.free;
  grid.Free;
  signals.Free;
  peeps.free;
  If assigned(ImageWriter) Then ImageWriter.free;
  writeln('Simulator exit.');
End;

(********************************************************************************
Start of simulator

All the agents are randomly placed with random genomes at the start. The outer
loop is generation, the inner loop is simStep. There is a fixed number of
simSteps in each generation. Agents can die at any simStep and their corpses
remain until the end of the generation. At the end of the generation, the
dead corpses are removed, the survivors reproduce and then die. The newborns
are placed at random locations, signals (pheromones) are updated, simStep is
reset to 0, and a new generation proceeds.

The paramManager manages all the simulator parameters. It starts with defaults,
then keeps them updated as the config file (biosim4.ini) changes.

The main simulator-wide data structures are:
    grid - where the agents live (identified by their non-zero index). 0 means empty.
    signals - multiple layers overlay the grid, hold pheromones
    peeps - an indexed set of agents of type Indiv; indexes start at 1

The important simulator-wide variables are:
    generation - starts at 0, then increments every time the agents die and reproduce.
    simStep - reset to 0 at the start of each generation; fixed number per generation.
    randomUint - global random number generator

The threads are:
    main thread - simulator
    simStepOneIndiv() - child threads created by the main simulator thread
    imageWriter - saves image frames used to make a movie (possibly not threaded
        due to unresolved bugs when threaded)
********************************************************************************)

Procedure TSimulator.Simulator(Filename: String);
Var
  murderCount, generation: unsigned;
  SimStep, indivIndex: Integer;
  //indiv: TIndiv;
  numberSurvivors: unsigned;
  key: Char;
  lastRound: Boolean;
Begin
  PrintHelp();
  printSensorsActions(); // show the agents' capabilities
  fLoadSim.parentGenomes := Nil;
  fLoadSim.Generation := -1;
  If LowerCase(ExtractFileExt(Filename)) = '.sim' Then Begin
    Filename := LoadSim(Filename);
  End;
  If (trim(Filename) = '') Or (Not FileExists(Filename)) Then Begin
    writeln('Error during loading:');
    WriteLn('  "' + Filename + '"');
    writeln('does not exist, is not loadable. Simulation will close now.');
    exit;
  End;
  fFilename := Filename; // For das SaveSim

  // Simulator parameters are available read-only through the global
  // variable p after paramManager is initialized.
  // Todo: remove the hardcoded parameter filename.
  fparamManager.setDefaults();
  fparamManager.registerConfigFile(Filename);
  fparamManager.updateFromConfigFile(0);
  fparamManager.checkParameters(); // check and report any problems

  If p.numThreads <> 0 Then Begin
    ImageWriter := TImageWriterThread.create(true, @OnWritelnCallback);
  End
  Else Begin
    ImageWriter := TimageWriter.create();
  End;

  randomUint.initialize(); // seed the RNG for main-thread use

  // Allocate container space. Once allocated, these container elements
  // will be reused in each new generation.
  grid.init(p.sizeX, p.sizeY); // the land on which the peeps live
  signals.init(p.signalLayers, p.sizeX, p.sizeY); // where the pheromones waft

  peeps.init(p.population); // the peeps themselves

  // If imageWriter is to be run in its own thread, start it here:
//    //std::thread t(&ImageWriter::saveFrameThread, &imageWriter);

  // Unit tests:
  //unitTestConnectNeuralNetWiringFromGenome();
  //unitTestGridVisitNeighborhood();

  If fLoadSim.Generation <> -1 Then Begin
    writeln('Restart simulation from generation: ' + inttostr(fLoadSim.Generation));
    generation := fLoadSim.Generation + 1;
    If length(fLoadSim.parentGenomes) = 0 Then Begin
      writeln('No survivors, -> restart simulation.');
      initializeGeneration0(); // starting population
      generation := 0;
    End
    Else Begin
      initializeNewGeneration(fLoadSim.parentGenomes, generation);
    End;
  End
  Else Begin
    generation := 0;
    initializeGeneration0(); // starting population
  End;
  runMode := rmRUN;

  // Inside the parallel region, be sure that shared data is not modified. Do the
  // modifications in the single-thread regions.
//    #pragma omp parallel num_threads(p.numThreads) default(shared)
//    {

  lastRound := false;
  While (runMode = rmRun) And (generation < p.maxGenerations) Do Begin
    //            #pragma omp single
    murderCount := 0; // for reporting purposes

    For SimStep := 0 To p.stepsPerGeneration - 1 Do Begin

      // multithreaded loop: index 0 is reserved, start at 1
//                #pragma omp for schedule(auto)
      For indivIndex := 1 To p.population Do Begin
        If (peeps[indivIndex]^.alive) Then Begin
          simStepOneIndiv(peeps[indivIndex], simStep);
        End;
      End;

      // In single-thread mode: this executes deferred, queued deaths and movements,
      // updates signal layers (pheromone), etc.
//                #pragma omp single
//                {
      murderCount := murderCount + peeps.deathQueueSize();
      endOfSimStep(simStep, generation);
      //                }
    End;

    //            #pragma omp single
    //            {
    endOfGeneration(generation);
    fparamManager.updateFromConfigFile(generation + 1);
    If lastRound Then Begin
      p.maxGenerations := generation + 1;
    End;
    numberSurvivors := spawnNewGeneration(generation, murderCount);
    If ((numberSurvivors > 0) And (generation Mod p.genomeAnalysisStride = 0)) Then Begin
      displaySampleGenomes(p.displaySampleGenomes);
    End;
    If (numberSurvivors = 0) Then Begin
      writeln('No survivors, -> restart simulation.');
      generation := 0; // start over
    End
    Else Begin
      inc(generation);
    End;
    AdditionalVideoFrame := false;
    While KeyPressed Do Begin
      key := ReadKey;
      Case key Of
        #27: Begin
            If Not lastRound Then Begin
              lastRound := true;
              writeln('--- Abort by user, will simulate one last generation with images (if enabled), then close. ---');
              p.maxGenerations := generation + 1;
            End;
          End;
        'V', 'v': Begin // Nächste generation soll ein Videostride gerendert werden.
            writeln('--- next generation a video generation will be forced. ---');
            AdditionalVideoFrame := true;
          End;
      End;
    End;
    If p.numThreads <> 0 Then Begin
      CheckSynchronize(1);
    End;
    //            } -- Ende Pragma
  End;
  //    } -- Ende Pragma

  displaySampleGenomes(3); // final report, for debugging

  // If imageWriter is in its own thread, stop it and wait for it here:
  //imageWriter.abort();
End;

End.

