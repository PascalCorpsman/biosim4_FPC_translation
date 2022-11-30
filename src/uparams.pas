
Unit uparams;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils;

{$I c_types.inc}

Type

  TRunMode = (rmStop, rmRun, rmPause, rmAbort);

  // Global simulator parameters

  // To add a new parameter:
  //    1. Add a member to struct Params in params.h.
  //    2. Add a member and its default value to privParams in ParamManager::setDefault()
  //          in params.cpp.
  //    3. Add an else clause to ParamManager::ingestParameter() in params.cpp.
  //    4. Add a line to the user's parameter file (default name biosim4.ini)

  // A private copy of Params is initialized by ParamManager::init(), then modified by
  // UI events by ParamManager::uiMonitor(). The main simulator thread can get an
  // updated, read-only, stable snapshot of Params with ParamManager::paramsSnapshot.

  TParams = Record
    population: unsigned; // >= 0
    stepsPerGeneration: unsigned; // > 0
    maxGenerations: unsigned; // >= 0
    numThreads: unsigned; // > 0
    signalLayers: unsigned; // >= 0
    genomeMaxLength: unsigned; // > 0
    maxNumberNeurons: unsigned; // > 0
    pointMutationRate: double; // 0.0..1.0
    geneInsertionDeletionRate: double; // 0.0..1.0
    deletionRatio: double; // 0.0..1.0
    killEnable: bool;
    sexualReproduction: bool;
    chooseParentsByFitness: bool;
    populationSensorRadius: float; // > 0.0
    signalSensorRadius: float; // > 0
    responsiveness: float; // >= 0.0
    responsivenessCurveKFactor: unsigned; // 1, 2, 3, or 4
    longProbeDistance: unsigned; // > 0
    shortProbeBarrierDistance: unsigned; // > 0
    valenceSaturationMag: float;
    saveVideo: bool;
    videoStride: unsigned; // > 0
    videoSaveFirstFrames: unsigned; // >= 0, overrides videoStride
    displayScale: unsigned;
    agentSize: Double;
    genomeAnalysisStride: unsigned; // > 0
    displaySampleGenomes: unsigned; // >= 0
    genomeComparisonMethod: unsigned; // 0 = Jaro-Winkler; 1 = Hamming
    updateGraphLog: bool;
    updateGraphLogStride: unsigned; // > 0
    challenge: unsigned;
    barrierType: unsigned; // >= 0
    deterministic: bool;
    RNGSeed: unsigned; // >= 0

    // These must not change after initialization
    sizeX: uint16; // 2..0x10000
    sizeY: uint16; // 2..0x10000
    genomeInitialLengthMin: unsigned; // > 0 and < genomeInitialLengthMax
    genomeInitialLengthMax: unsigned; // > 0 and < genomeInitialLengthMin
    logDir: String;
    imageDir: String;
    graphLogUpdateCommand: String;
    VisualizeChallenge: Boolean;

    // These are updated automatically and not set via the parameter file
    parameterChangeGenerationNumber: unsigned; // the most recent generation number that an automatic parameter change occured at
  End;

  { TParamManager }

  // The paramManager maintains a private copy of the parameter values, and a copy
  // is available read-only through global variable p. Although this is not
  // foolproof, you should be able to modify the config file during a simulation
  // run and modify many of the parameters. See params.cpp and params.h for more info.

  TParamManager = Class
  private
    privParams: TParams;
    configFilename: String;
    configFileContent: TStringlist;
    //   lastModTime:    time_t ; // when config file was last read
    Procedure ingestParameter(aname, aval: String);

  public
    Constructor Create();
    Destructor Destroy(); override;
    //    const Params &getParamRef() const { return privParams; } // for public read-only access
    Procedure setDefaults();
    Procedure registerConfigFile(filename: String);
    Procedure updateFromConfigFile(generationNumber: unsigned);
    Procedure checkParameters();
  End;

Var
  p: TParams; // Read Only Zugrif auf TParam.PrivParams
  runMode: TRunMode = rmStop;

Implementation

Uses uSimulator, ubasicTypes;

Function checkIfUint(s: String): Bool;
Var
  i: Integer;
Begin
  result := false;
  If s = '' Then exit;
  For i := 1 To length(s) Do Begin
    If (Not (s[i] In ['0'..'9'])) Then exit;
  End;
  result := true;
End;

//bool checkIfInt(const std::string &s)
//{
//    //return s.find_first_not_of("-0123456789") == std::string::npos;
//    std::istringstream iss(s);
//    int i;
//    iss >> std::noskipws >> i; // noskipws considers leading whitespace invalid
//    // Check the entire string was consumed and if either failbit or badbit is set
//    return iss.eof() && !iss.fail();
//}

Function checkIfFloat(s: String): Boolean;
Begin
  Try
    FormatSettings.DecimalSeparator := '.';
    strtofloat(s);
    result := true;
  Except
    result := false;
  End;
End;

Function checkIfBool(s: String): Boolean;
Begin
  result := (s = '0') Or (s = '1') Or (s = 'true') Or (s = 'false');
End;

Function getBoolVal(s: String): Boolean;
Begin
  result := (s = '1') Or (s = 'true');
End;

{ TParamManager }

Procedure TParamManager.ingestParameter(aname, aval: String);
Var
  isUint, isFloat, isBool, bVal: Boolean;
  uVal: unsigned;
  dval: double;
Begin
  aname := LowerCase(aname);
  //std::cout << aname << " " << aval << '\n' << std::endl;

  isUint := checkIfUint(aval);
  If isUint Then Begin
    uval := strtoint(aval);
  End
  Else Begin
    uVal := 0;
  End;
  isFloat := checkIfFloat(aval);
  If isFloat Then Begin
    FormatSettings.DecimalSeparator := '.';
    dval := StrToFloat(aval);
  End
  Else Begin
    dval := 0.0;
  End;
  isBool := checkIfBool(aval);
  bVal := getBoolVal(aval);
  aval := LowerCase(aval);
  Case aname Of
    'sizex': Begin
        If (isUint) And (uVal >= 2) And (uVal <= High(UInt16) - 1) Then Begin
          privParams.sizeX := uVal;
        End;
      End;
    'sizey': Begin
        If (isUint) And (uVal >= 2) And (uVal <= High(UInt16) - 1) Then Begin
          privParams.sizeY := uVal;
        End;
      End;
    'challenge': Begin
        If (isUint) And (uVal < high(UInt16) - 1) Then Begin
          privParams.challenge := uVal;
        End;
      End;
    'genomeinitiallengthmin': Begin
        If (isUint) And (uVal > 0) And (uVal < high(uint16) - 1) Then Begin
          privParams.genomeInitialLengthMin := uVal;
        End;
      End;
    'genomeinitiallengthmax': Begin
        If (isUint) And (uVal > 0) And (uVal < high(uint16) - 1) Then Begin
          privParams.genomeInitialLengthMax := uVal;
        End;
      End;
    'logdir': privParams.logDir := FixPathDelimeter(aval);
    'imagedir': privParams.imageDir := FixPathDelimeter(aval);
    'population': Begin
        If (isUint) And (uVal > 0) And (uVal < high(uint32) - 1) Then Begin
          privParams.population := uVal;
        End;
      End;
    'stepspergeneration': Begin
        If (isUint) And (uVal > 0) And (uVal < high(uint16) - 1) Then Begin
          privParams.stepsPerGeneration := uVal;
        End;
      End;
    'maxgenerations': Begin
        If (isUint) And (uVal > 0) And (uVal < $7FFFFFFF) Then Begin
          privParams.maxGenerations := uVal;
        End;
      End;
    'barriertype': Begin
        If (isUint) And (uVal < high(uint32) - 1) Then Begin
          privParams.barrierType := uVal;
        End;
      End;
    'numthreads': Begin
        If (isUint) And (uVal > 0) And (uVal < high(uint16) - 1) Then Begin
          privParams.numThreads := uVal;
        End;
      End;
    'signallayers': Begin
        If (isUint) And (uVal < high(uint16) - 1) Then Begin
          privParams.signalLayers := uVal;
        End;
      End;
    'genomemaxlength': Begin
        If (isUint) And (uVal > 0) And (uVal < high(uint16) - 1) Then Begin
          privParams.genomeMaxLength := uVal;
        End;
      End;
    'maxnumberneurons': Begin
        If (isUint) And (uVal > 0) And (uVal < high(uint16) - 1) Then Begin
          privParams.maxNumberNeurons := uVal;
        End;
      End;
    'pointmutationrate': Begin
        If (isFloat) And (dVal >= 0.0) And (dVal <= 1.0) Then Begin
          privParams.pointMutationRate := dVal;
        End;
      End;
    'geneinsertiondeletionrate': Begin
        If (isFloat) And (dVal >= 0.0) And (dVal <= 1.0) Then Begin
          privParams.geneInsertionDeletionRate := dVal;
        End;
      End;
    'deletionratio': Begin
        If (isFloat) And (dVal >= 0.0) And (dVal <= 1.0) Then Begin
          privParams.deletionRatio := dVal;
        End;
      End;
    'killenable': Begin
        If (isBool) Then Begin
          privParams.killEnable := bVal;
        End;
      End;
    'sexualreproduction': Begin
        If (isBool) Then Begin
          privParams.sexualReproduction := bVal;
        End;
      End;
    'chooseparentsbyfitness': Begin
        If (isBool) Then Begin
          privParams.chooseParentsByFitness := bVal;
        End;
      End;
    'populationsensorradius': Begin
        If (isFloat) And (dVal > 0.0) Then Begin
          privParams.populationSensorRadius := dVal;
        End;
      End;
    'signalsensorradius': Begin
        If (isFloat) And (dVal > 0.0) Then Begin
          privParams.signalSensorRadius := dVal;
        End;
      End;
    'responsiveness': Begin
        If (isFloat) And (dVal >= 0.0) Then Begin
          privParams.responsiveness := dVal;
        End;
      End;
    'responsivenesscurvekfactor': Begin
        If (isUint) And (uVal >= 1) And (uVal <= 20) Then Begin
          privParams.responsivenessCurveKFactor := uVal;
        End;
      End;
    'longprobedistance': Begin
        If (isUint) And (uVal > 0) Then Begin
          privParams.longProbeDistance := uVal;
        End;
      End;
    'shortprobebarrierdistance': Begin
        If (isUint) And (uVal > 0) Then Begin
          privParams.shortProbeBarrierDistance := uVal;
        End;
      End;
    'valencesaturationmag': Begin
        If (isFloat) And (dVal >= 0.0) Then Begin
          privParams.valenceSaturationMag := dVal;
        End;
      End;
    'savevideo': Begin
        If (isBool) Then Begin
          privParams.saveVideo := bVal;
        End;
      End;
    'videostride': Begin
        If (isUint) And (uVal > 0) Then Begin
          privParams.videoStride := uVal;
        End;
      End;
    'videosavefirstframes': Begin
        If (isUint) Then Begin
          privParams.videoSaveFirstFrames := uVal;
        End;
      End;
    'displayscale': Begin
        If (isUint) And (uVal > 0) Then Begin
          privParams.displayScale := uVal;
        End;
      End;
    'agentsize': Begin
        If (isFloat) And (dVal > 0.0) Then Begin
          privParams.agentSize := dVal;
        End;
      End;
    'genomeanalysisstride': Begin
        If (isUint) And (uVal > 0) Then Begin
          privParams.genomeAnalysisStride := uVal;
        End;
        If (aval = 'videostride') Then Begin
          privParams.genomeAnalysisStride := privParams.videoStride;
        End;
      End;
    'displaysamplegenomes': Begin
        If (isUint) Then Begin
          privParams.displaySampleGenomes := uVal;
        End;
      End;
    'genomecomparisonmethod': Begin
        If (isUint) Then Begin
          privParams.genomeComparisonMethod := uVal;
        End;
      End;
    'updategraphlog': Begin
        If (isBool) Then Begin
          privParams.updateGraphLog := bVal;
        End;
      End;
    'updategraphlogstride': Begin
        If (isUint) And (uVal > 0) Then Begin
          privParams.updateGraphLogStride := uVal;
        End;
        If (aval = 'videostride') Then Begin
          privParams.updateGraphLogStride := privParams.videoStride;
        End;
      End;
    'deterministic': Begin
        If (isBool) Then Begin
          privParams.deterministic := bVal;
        End;
      End;
    'visualizechallenge': Begin
        If (isBool) Then Begin
          privParams.VisualizeChallenge := bVal;
        End;
      End;
    'graphlogupdatecommand': Begin
        privParams.graphLogUpdateCommand := aval;
      End;
    'rngseed': Begin
        If (isUint) Then Begin
          privParams.RNGSeed := uVal;
        End;
      End
  Else Begin
      Raise exception.create('Invalid param: ' + aname + ' = "' + aval + '"');
    End;
  End;
End;

Constructor TParamManager.Create;
Begin
  configFileContent := Nil;
End;

Destructor TParamManager.Destroy;
Begin
  If assigned(configFileContent) Then configFileContent.free;
  configFileContent := Nil;
End;

Procedure TParamManager.setDefaults;
Begin
  privParams.sizeX := 128;
  privParams.sizeY := 128;
  privParams.challenge := CHALLENGE_CORNER_WEIGHTED;

  privParams.genomeInitialLengthMin := 24;
  privParams.genomeInitialLengthMax := 24;
  privParams.genomeMaxLength := 300;
  privParams.logDir := 'logs'; // Das Orig hat hier mit Pathdelims
  privParams.imageDir := 'images'; // Das Orig hat hier mit Pathdelims
  privParams.population := 3000;
  privParams.stepsPerGeneration := 300;
  privParams.maxGenerations := 200000;
  privParams.barrierType := 0;
  privParams.numThreads := 4;
  privParams.signalLayers := 1;
  privParams.maxNumberNeurons := 5;
  privParams.pointMutationRate := 0.001;
  privParams.geneInsertionDeletionRate := 0.0;
  privParams.deletionRatio := 0.5;
  privParams.killEnable := false;
  privParams.sexualReproduction := true;
  privParams.chooseParentsByFitness := true;
  privParams.populationSensorRadius := 2.5;
  privParams.signalSensorRadius := 2.0;
  privParams.responsiveness := 0.5;
  privParams.responsivenessCurveKFactor := 2;
  privParams.longProbeDistance := 16;
  privParams.shortProbeBarrierDistance := 4;
  privParams.valenceSaturationMag := 0.5;
  privParams.saveVideo := true;
  privParams.videoStride := 25;
  privParams.videoSaveFirstFrames := 2;
  privParams.VisualizeChallenge := false; // Added by Corpsman
  privParams.displayScale := 8;
  privParams.agentSize := 4;
  privParams.genomeAnalysisStride := privParams.videoStride;
  privParams.displaySampleGenomes := 5;
  privParams.genomeComparisonMethod := 1;
  privParams.updateGraphLog := true;
  privParams.updateGraphLogStride := privParams.videoStride;
  privParams.deterministic := false;
  privParams.RNGSeed := 12345678;
  privParams.graphLogUpdateCommand := 'gnuplot --persist tools' + Pathdelim + 'graphlog.gp';
  privParams.parameterChangeGenerationNumber := 0;
End;

Procedure TParamManager.registerConfigFile(filename: String);
Begin
  configFilename := filename;
  If assigned(configFileContent) Then configFileContent.free;
  configFileContent := TStringList.Create;
  If Not FileExists(configFilename) Then Begin
    writeln('Couldn''t open config file ' + configFilename + '.');
    exit;
  End;
  configFileContent.LoadFromFile(configFilename);
End;

Procedure TParamManager.updateFromConfigFile(generationNumber: unsigned);
Var
  i: Integer;
  value, value0, generationSpecifier, name, line: String;
  delimiterComment, delimeterPos, generationDelimiterPos: Integer;
  isUint: Boolean;
  activeFromGeneration: unsigned;
Begin
  // TODO: Hier sollten je nach Generation (0 = alle, sonst nur die "Updatefähigen")
  If ReloadConfigini Then Begin
    registerConfigFile(configFilename);
  End;
  For i := 0 To configFileContent.Count - 1 Do Begin
    line := trim(configFileContent[i]);
    If (line = '') Or (line[1] = '#') Then Continue;
    delimeterPos := pos('=', line);
    name := trim(copy(line, 1, delimeterPos - 1));

    // Process the generation specifier if present:
    generationDelimiterPos := pos('@', name);
    If (generationDelimiterPos > 0) Then Begin
      generationSpecifier := copy(name, generationDelimiterPos + 1, length(name));
      isUint := checkIfUint(generationSpecifier);
      If (Not isUint) Then Begin
        writeln('Invalid generation specifier: ' + name + '.');
        continue;
      End;
      activeFromGeneration := strtoint(generationSpecifier);
      If (activeFromGeneration > generationNumber) Then Begin
        continue; // This parameter value is not active yet
      End
      Else If (activeFromGeneration = generationNumber) Then Begin
        // Parameter value became active at exactly this generation number
        privParams.parameterChangeGenerationNumber := generationNumber;
      End;
      name := copy(name, 1, generationDelimiterPos - 1);
    End;

    value0 := lowercase(copy(line, delimeterPos + 1, length(line)));
    delimiterComment := pos('#', value0);
    If delimiterComment = 0 Then Begin
      value := value0;
    End
    Else Begin
      value := copy(value0, 1, delimiterComment - 1);
    End;
    value := trim(value);
    // Nur beim 1. Mal anzeigen, sonst flippt die Konsole unnötig aus weil das Config File ständig eingelesen wird !
    ingestParameter(name, value);
  End;
  // Aktualisieren der "Globalen" Parameter
  p := privParams;
End;

// Check parameter ranges, reasonableness, coherency, whatever. This is
// typically called only once after the parameters are first read.

Procedure TParamManager.checkParameters;
Begin
  If (privParams.deterministic) And (privParams.numThreads <> 1) Then Begin
    Writeln('Warning: When deterministic is true, you probably want to set numThreads = 1.');
  End;
End;

End.

