Unit uSimulator;

{$MODE ObjFPC}{$H+}

Interface

// Needed by mtprocs tu support pointer to nested methods
{$MODESWITCH nestedprocvars}
Uses
  Classes, SysUtils, uparams, ugrid, usignals, upeeps, uImageWriter, ugenome, urandom, uindiv, mtprocs;

{$I c_types.inc}
{$INTERFACES corba} // Für TImageWriter, so kann man Interfaces ohne den .net Gruscht nutzen

Const
  (*
   * History: 0.01 - Initialversion
   *          0.02 - Fix Bug in Video creation (invalid frame count)
   *                 Fix crash when continuing a .sim file without having the "old" data.
   *                 ADD Rudimentary sensor / Action Checks into .sim files to prevent total garbage beeing produced (still possible if user "changes" sensor actions but not adding / deleting them)
   *          0.03 - on some systems the access to epoch log file is blocked due to a virus scanner, implemented a second try after user input!
   *)
  biosimVersion = '0.03';

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
    fThreadRandomGenerators: Array Of RandomUintGenerator; // Im MultiThread Modus hat jeder Thread seinen eigenen Zufallszahlen Generator
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
    Procedure SaveSim(Generation: integer; Const parentGenomes: TGenomeArray); // This container will hold the genomes of the survivors

    Procedure Simulator(Filename: String); // Init Procedure
  End;

Var
  ReloadConfigini: Boolean = false; // If true, the next generation the config will will be reloaded from disk

Procedure simStepOneIndiv(Const randomUint: RandomUintGenerator; Indiv: Pindiv; simStep: unsigned); // Für die weiteren Sim Threads

Implementation

Uses usensoractions, uspawnNewGeneration, uexecuteActions,
  uEndOfSimStep, uEndOfGeneration, uanalysis, crt, uomp, ubasicTypes, UTF8Process
  //  , uUnittests -- Enable if running unittests
  ;

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

Procedure simStepOneIndiv(Const randomUint: RandomUintGenerator; Indiv: Pindiv; simStep: unsigned);
Var
  actionLevels: TActionArray;
Begin
  indiv^.age := indiv^.age + 1; // for this implementation, tracks simStep
  actionLevels := indiv^.feedForward(randomUint, simStep);
  executeActions(randomUint, indiv, actionLevels);
End;

{ TSimulator }

Procedure TSimulator.PrintHelp;
Begin
  // TODO: Bessere Meldungen einbauen..
  //       12345678901234567890123456789012345678901234567890123456789012345678901234567890
  writeln('biosim, ported by corpsman to lazarus /fpc, ver.' + biosimVersion);
  writeln('press ESC to end simulation after next full generation.');
  writeln('press V to force video rendering on the next generation simulation.');
  writeln('press I display sample genome in console.');
  writeln('press R to force reloading .ini file from disk on the next generation simulation');
  writeln('press P to pause the simulation until Return is pressed.');
End;

Procedure TSimulator.OnWritelnCallback(Sender: TObject; Line: String);
Begin
  // Get rid of that warning, that sender is not used..
  If assigned(Sender) Then Begin
  End;
  writeln(Line);
End;

Procedure TSimulator.SetCrashed(AValue: Boolean);
Begin
  If assigned(ImageWriter) Then Begin
    ImageWriter.SetCrashed(AValue);
  End;
End;

Procedure TSimulator.SaveSim(Generation: integer;
  Const parentGenomes: TGenomeArray);
Var
  SimFilename, t: String; // Ziel Dateiname !
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
  SimFilename := ExtractFileName(fFilename);
  SimFilename := Copy(SimFilename, 1, length(SimFilename) - length(ExtractFileExt(SimFilename))) + '.sim';
  sl := TStringList.Create;
  sl.add(fFilename); // 1. Die Biosim.ini merken
  sl.add(inttostr(Generation)); // Die Aktuelle Generation
  (*
   * Eigentlich sollte der Check über die Sensoren / actoren deutlich "Krasser" sein, aber so ist er wenigstens ein bisschen da..
   *)
  sl.add(inttostr(integer(NUM_SENSES)));
  sl.add(inttostr(integer(NUM_ACTIONS)));
  // Die Eigentlichen Gene
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
  If FileExists(SimFilename) Then Begin
    If Not DeleteFile(SimFilename) Then Begin
      writeln('Error no write access to: ' + SimFilename);
      sl.free;
      exit;
    End;
  End;
  writeln('Store simulation data to: ' + ExtractFileName(SimFilename));
  sl.SaveToFile(SimFilename);
  If Not FileExists(SimFilename) Then Begin
    writeln('Error no write access to: ' + SimFilename);
  End;
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
  If sl.count < 5 Then Begin // Da kann was nicht Stimmen,
    writeln('Error, invalid .sim file: ' + Filename);
    sl.free;
    exit;
  End;
  Result := FixPathDelimeter(sl[0]);
  fLoadSim.Generation := StrToIntDef(sl[1], 0);
  (*
   * Eigentlich sollte der Check über die Sensoren / actoren deutlich "Krasser" sein, aber so ist er wenigstens ein bisschen da..
   *)
  If integer(NUM_SENSES) <> StrToIntDef(sl[2], 0) Then Begin
    result := '';
    writeln('Error, invalid sensor mapping in .sim file, result will be garbage. Abort now.');
    exit;
  End;
  If integer(NUM_ACTIONS) <> StrToIntDef(sl[3], 0) Then Begin
    result := '';
    writeln('Error, invalid action mapping in .sim file, result will be garbage. Abort now.');
    exit;
  End;
  GeneCount := StrToIntDef(sl[4], 0);
  setlength(fLoadSim.parentGenomes, GeneCount);
  For i := 0 To GeneCount - 1 Do Begin
    fLoadSim.parentGenomes[i] := StrToGenom(sl[5 + i]);
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
  InitCriticalSections();
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
  FreeCriticalSections();
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
  SimStep: integer;

  Procedure DoSomeThingParallel(Index: PtrInt; Data: Pointer; Item: TMultiThreadProcItem);
  Var
    BlockStart, BlockEnd: PtrInt;
    IndivIndex: integer;
  Begin
    // get rid of that annouing not used warning.
    If assigned(data) And assigned(item) Then Begin

    End;
    (*
     * Jeder Thread bearbeitet einen gleich großen Teil der population
     * da dieses Array aber 1 Bassiert ist wird Blockstart um 1 erhöht
     * anstatt wie üblich Blockend um 1 verringert.
     *)
    BlockStart := Index * (p.population Div p.numThreads) + 1;
    BlockEnd := (Index + 1) * (p.population Div p.numThreads);
    If BlockEnd > p.population Then BlockEnd := p.population;
    For IndivIndex := BlockStart To BlockEnd Do Begin
      assert(IndivIndex > 0);
      assert(IndivIndex <= p.population);
      If (peeps[IndivIndex]^.alive) Then Begin
        simStepOneIndiv(fThreadRandomGenerators[Index], peeps[IndivIndex], SimStep);
      End;
    End;
  End;

Var
  murderCount, generation: unsigned;
  numberSurvivors: unsigned;
  key: Char;
  ShowGenomeInfo, inPause, lastRound: Boolean;
  i: integer;
  tmps: String;
  AdditionalVideoFrameSaver, AdditionalVideoFrame: Boolean; // If true, the next generation will definitly write a video
  cores: Integer;
Begin
  PrintHelp();
  printSensorsActions(); // show the agents' capabilities
  fLoadSim.parentGenomes := Nil;
  fLoadSim.Generation := -1;
  Filename := FixPathDelimeter(Filename);
  If LowerCase(ExtractFileExt(Filename)) = '.sim' Then Begin
    Filename := LoadSim(Filename);
  End
  Else Begin
    // Schauen ob es zu dieser Challenge schon eine .sim datei gibt, wenn ja Warnung
    For i := length(Filename) Downto 1 Do Begin
      If Filename[i] = '.' Then Begin
        tmps := ExtractFileName(Filename);
        tmps := copy(tmps, 1, i - 1) + '.sim';
        If FileExists(tmps) Then Begin
          writeln('Warning, there already exists a .sim file. if you continue');
          writeln('this results will be overwriten.');
          writeln('If you accidential startet the simulator with the .ini file');
          writeln('instead of the .sim file as param, this is the time where');
          writeln('can kill the process and start over.');
          writeln('');
          writeln('If you want to overwrite the "old" results hit return and');
          writeln('start the calculations.');
          readln();
        End;
        break;
      End;
    End;
  End;
  If (trim(Filename) = '') Or (Not FileExists(Filename)) Then Begin
    writeln('Error during loading first parameter:');
    WriteLn('  "' + Filename + '"');
    writeln('does not exist, is not loadable. Simulation will close now.');
    If trim(Filename) = '' Then Begin
      writeln('You need to pass a .ini or .sim file as first parameter!.');
    End;
    exit;
  End;
  fFilename := Filename; // For das SaveSim

  // Simulator parameters are available read-only through the global
  // variable p after paramManager is initialized.
  fparamManager.setDefaults(CHALLENGE_CORNER_WEIGHTED);
  fparamManager.registerConfigFile(Filename);
  fparamManager.updateFromConfigFile(0, ReloadConfigini);
  fparamManager.checkParameters(); // check and report any problems

  If p.numThreads > 1 Then Begin
    cores := GetSystemThreadCount;
    If p.numThreads > cores Then Begin
      writeln(format('Warning, your system has %d cores, using more threads could slowdown all calculations.', [cores]));
    End;
  End;
  // Always use the Imagewriter Thread !
  ImageWriter := TImageWriterThread.create(true, @OnWritelnCallback);

  // Init all random number generators for all threads
  setlength(fThreadRandomGenerators, p.numThreads);
  For i := 0 To p.numThreads - 1 Do Begin
    fThreadRandomGenerators[i].initialize(i, p.deterministic, p.RNGSeed);
  End;
  AdditionalVideoFrame := false;
  ShowGenomeInfo := false;

  // Allocate container space. Once allocated, these container elements
  // will be reused in each new generation.
  grid.init(p.sizeX, p.sizeY); // the land on which the peeps live
  signals.init(p.signalLayers, p.sizeX, p.sizeY); // where the pheromones waft

  peeps.init(p.population); // the peeps themselves

  // Unit tests:
  //  unitTestConnectNeuralNetWiringFromGenome();
  //  unitTestGridVisitNeighborhood();
  //  unitTestBasicTypes();
  //  unitTestgenerateChildGenome();
  //  unitTestIndivSensors();

  If fLoadSim.Generation <> -1 Then Begin
    writeln('Restart simulation from generation: ' + inttostr(fLoadSim.Generation));
    generation := fLoadSim.Generation + 1;
    // Nachladen aller "Konfigurationen" der Bisherigen Generationen
    For i := 0 To fLoadSim.Generation Do Begin
      fparamManager.updateFromConfigFile(i, ReloadConfigini);
    End;

    If length(fLoadSim.parentGenomes) = 0 Then Begin
      writeln('No survivors, -> restart simulation.');
      initializeGeneration0(fThreadRandomGenerators[0]); // starting population
      generation := 0;
    End
    Else Begin
      initializeNewGeneration(fThreadRandomGenerators[0], fLoadSim.parentGenomes);
    End;
  End
  Else Begin
    generation := 0;
    initializeGeneration0(fThreadRandomGenerators[0]); // starting population
  End;
  runMode := rmRUN;

  // Inside the parallel region, be sure that shared data is not modified. Do the
  // modifications in the single-thread regions.

  lastRound := false;

  //TODO:  Einmal mit Haltepunkten Prüfen In wie weiter die 1. Generation des Deterministic0.ini
  (*       => Folgende Dinge fehlen noch:
   *       Procedure executeActions: Kill Forward !
   *       Procedure randomInsertDeletion Komplett
   *)

  While (runMode = rmRun) And (generation < p.maxGenerations) Do Begin

    murderCount := 0; // for reporting purposes
    For SimStep := 0 To p.stepsPerGeneration - 1 Do Begin
      (*
       * Da jeder Thread seinen eigenen Zufallszahlengenerator hat, muss die Schleife
       * über die Anzahl der Threads laufen und nicht über p.Population !
       *
       * Der Threadpool unterstützt dies auch mittels der "Blockbearbeitung", auf diese wurde
       * hier aber bewust verzichtet, da die Zahl der Threads unter umständen schwankt und damit
       * im deterministic modus sonst keine Reproduzierbaren Ergebnisse mehr entstehen.
       *)
      ProcThreadPool.DoParallelNested(@DoSomeThingParallel, 0, p.numThreads - 1, Nil, p.numThreads);
      // In single-thread mode: this executes deferred, queued deaths and movements,
      // updates signal layers (pheromone), etc.
      murderCount := murderCount + peeps.deathQueueSize();
      endOfSimStep(fThreadRandomGenerators[0], simStep, generation, AdditionalVideoFrame);
    End;
    (*
     * Das Einlesen der Variablen wird hier platt gemacht, aber AdditionalVideoFrame wird danach noch mal benötigt, damit das dann stimmt
     * braucht es den "Saver" der den unteren Code entsprechend 1-Pass Verzögert ablaufen lässt.
     *)
    AdditionalVideoFrameSaver := AdditionalVideoFrame;
    AdditionalVideoFrame := false;
    ReloadConfigini := false;
    While KeyPressed Do Begin
      key := ReadKey;
      Case key Of
        #27: Begin
            If Not lastRound Then Begin
              writeln('--- Abort by user, will close. ---');
            End;
            lastRound := true;
          End;
        'I', 'i': Begin
            If Not ShowGenomeInfo Then Begin
              writeln('--- activated genome plot as soon as possible. ---');
              ShowGenomeInfo := true;
            End;
          End;
        'V', 'v': Begin // Nächste generation soll ein Videostride gerendert werden.
            If Not AdditionalVideoFrame Then Begin
              writeln('--- next generation a video generation will be forced. ---');
            End;
            AdditionalVideoFrame := true;
          End;
        'R', 'r': Begin // In der Nächsten Iterration das .ini File neu von der Platte einlesen
            If Not ReloadConfigini Then Begin
              writeln('--- next generation ' + ExtractFileName(fFilename) + ' will be reloaded from disk. ---');
            End;
            ReloadConfigini := true;
          End;
        'P', 'p': Begin
            writeln('--- Entering pause mode, to exit pause mode press return ---');
            writeln('--- Imagewriter thread will not paused! ---');
            inPause := true;
            While KeyPressed Do Begin // Sollte der User mehrfach p gedrückt haben, dann lesen wir diese "P" weg damit da nicht zig mal steht "p, ignoriert"
              key := ReadKey;
            End;
            While inPause Do Begin
              While KeyPressed Do Begin
                key := ReadKey;
                If (key = #13) Or (key = #10) Then Begin
                  writeln('--- Leaving Pause mode. ---');
                  inPause := false;
                  LastSpawnTime := GetTickCount64; // Die Zeit der letzten Berechnung anpassen, sonst sieht der User hier nur die Zeit der Pause
                End
                Else Begin
                  writeln('--- Key "' + key + '" will be ignored. ---');
                End;
              End;
              If p.numThreads <> 0 Then Begin
                CheckSynchronize(1);
              End;
              sleep(1);
            End;
          End;
      End;
    End;

    (*
     * Das muss vor Spawn new Generation sein, damit so geschichten wie die
     * "Barrier" korrekt in SpawnNewGeneration gesetzt werden, sonst kommt
     * das seine Gen zu spät !
     *)
    fparamManager.updateFromConfigFile(generation + 1, ReloadConfigini);

    (*
     * Das Muss vor spawnNewGeneration gemacht werden, weil dort auch das
     * Autosaving gemacht wird !
     *)
    If lastRound Then Begin
      p.maxGenerations := generation + 1; // Abbruch durch User
      (*
       * Der User will noch mal ein Video und danach abbrechen -> dann muss der
       * Simulator das hier auch Berücksichtigen und die Schwelle noch mal aushebeln.
       *)
      If AdditionalVideoFrame Then Begin
        p.maxGenerations := generation + 2;
      End;
    End;

    numberSurvivors := spawnNewGeneration(fThreadRandomGenerators[0], generation, murderCount, @SaveSim);
    endOfGeneration(generation, AdditionalVideoFrameSaver); // Das muss nach der spawnNewGeneration gemacht werden, da diese ja erst die Epochlog erstellt !

    If ((numberSurvivors > 0) And (generation Mod p.genomeAnalysisStride = 0)) Or ShowGenomeInfo Then Begin
      displaySampleGenomes(p.displaySampleGenomes, peeps);
    End;
    ShowGenomeInfo := false;

    If (numberSurvivors = 0) Then Begin
      If Not lastRound Then Begin
        writeln('No survivors, -> restart simulation.');
        generation := 0; // start over
      End;
    End
    Else Begin
      inc(generation);
    End;
    If p.numThreads <> 0 Then Begin
      CheckSynchronize(1);
    End;
  End;

  // displaySampleGenomes(3); // final report, for debugging
End;

End.

