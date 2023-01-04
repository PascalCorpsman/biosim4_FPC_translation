Unit uImageWriter;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Graphics, Classes, SysUtils, ubasicTypes, ufifo, ugwavi, usimplechart;

{$I c_types.inc}

// Creates a graphic frame for each simStep, then
// assembles them into a video at the end of a generation.

Type

  TWritelnEvent = Procedure(Value: String) Of Object;
  TWritelnCallback = Procedure(Sender: TObject; Line: String) Of Object;

  // This holds all data needed to construct one image frame. The data is
  // cached in this structure so that the image writer can work on it in
  // a separate thread while the main thread starts a new simstep.
  TImageFrameData = Record
    simStep: unsigned;
    generation: unsigned;
    Challenge: unsigned;
    // TODO:  indivLocs und indivColors in ein Record zusammenfassen
    indivLocs: Array Of TCoord;
    indivColors: Array Of uint8_t;
    barrierLocs: Array Of TCoord;
  End;

  { TImageWriter }

  TImageWriter = Class
  private
    fimagelist: Array Of TJPEGImage;
    data: TImageFrameData;
    fAVI: tgwavi;
    fWritelnEvent: TWritelnEvent;
    Procedure saveOneFrameImmed(Const adata: TImageFrameData);
    Procedure Writeln(Value: String);
    Procedure RenderChallengeToImage(Const Image: TBitmap; generation, simStep, Challenge: integer);
  public
    Constructor Create(); virtual;
    Destructor Destroy(); override;
    Procedure startNewGeneration();
    Function saveVideoFrameSync(simStep, generation, Challenge: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
    Procedure SetCrashed(Value: Boolean);
    Procedure AddChartRendererToQueue(Const SC: TSimpleChart);
  End;

  tStringQueue = specialize TFifo < String > ;

  TJobKind = (jkFrame, jksaveGenerationVideo);

  TJob = Record
    Kind: TJobKind;
    Data: TImageFrameData;
  End;

  TJobQueue = Specialize TFifo < TJob > ;
  TSimpleChartQueue = Specialize TFifo < TSimpleChart > ;

  { TImageWriterThread }

  TImageWriterThread = Class(TThread)
  private
    fscq: TSimpleChartQueue;
    fImageWriter: TImageWriter;
    fWritelnCallback: TWritelnCallback;
    fstringFivo: tStringQueue;
    fJobQueue: TJobQueue;
    fcrashed: Boolean;
    // Alles ab hier wird im Kontext des Mainthreads ausgeführt.
    Procedure WritelnEvent;

    // Alles ab hier wird im Kontext des Threads ausgeführt.
    Procedure Setup;
    Procedure TearDown;
    Procedure Writeln(Value: String);
    Procedure HandleJob(Const Job: TJob);
    Procedure HandleSCEvent(Const SC: TSimpleChart);
  public
    Procedure Execute(); override;
    Constructor Create(CreateSuspended: Boolean; WritelnCallback: TWritelnCallback;
      Const StackSize: SizeUInt = DefaultStackSize);

    Function saveVideoFrameSync(simStep, generation, Challenge: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
    Procedure SetCrashed(Value: Boolean);
    Procedure AddChartRendererToQueue(Const SC: TSimpleChart);
    Procedure Free;
  End;

Implementation

Uses uparams, uindiv, uSimulator, ugenome, crt;

// Pushes a new image frame onto .imageList.

Procedure TImageWriter.saveOneFrameImmed(Const adata: TImageFrameData);
Const
  maxColorVal = $B0;
  maxLumaVal = $B0;

  Function rgbToLuma(r, g, b: uint8_t): uint8;
  Begin
    result := (r + r + r + b + g + g + g + g) Div 8;
  End;

Var
  image: TBitmap;
  //png: TPortableNetworkGraphic; // -- Zum Abspeichern der Einzelbilder
  jp: TJPEGImage;
  imageFilename: String;
  color: TColor;
  x, y, d, r, g, b, c, i: Integer;
Begin
  image := Tbitmap.create();

  image.Width := p.sizeX * p.displayScale;
  image.height := p.sizeY * p.displayScale;
  image.canvas.brush.color := clwhite;
  image.canvas.rectangle(-1, -1, image.Width + 1, image.Height + 1);
  imageFilename := IncludeTrailingPathDelimiter(p.imageDir) + format('frame-%0.6d-%0.6d.png', [adata.generation, adata.simStep]);

  // Draw barrier locations
  Color := $00888888;
  For i := 0 To high(adata.barrierLocs) Do Begin
    image.Canvas.pen.Color := color;
    image.Canvas.Brush.Color := color;
    image.Canvas.Rectangle(
      adata.barrierLocs[i].x * p.displayScale, ((p.sizeY - adata.barrierLocs[i].y) - 1) * p.displayScale,
      (adata.barrierLocs[i].x + 1) * p.displayScale, ((p.sizeY - (adata.barrierLocs[i].y - 0))) * p.displayScale);
  End;
  (* Taken from : https://github.com/cavac/biosim4/commit/29c83f80667c5ca6e400b383169da442ab3359ea
  // Draw standard pheromone trails (signal layer 0)
      color[0] = 0x00;
      color[1] = 0x00;
      color[2] = 0xff;
      for (int16_t x = 0; x < p.sizeX; ++x) {
          for (int16_t y = 0; y < p.sizeY; ++y) {
              temp = data.signalLayers[0][x][y];
              if(temp > 0) {
                  alpha = ((float)temp / 255.0) / 3.0;
                  // max alpha 0.33
                  if(alpha > 0.33) {
                      alpha = 0.33;
                  }

                  image.draw_rectangle(
                      ((x - 1)    * p.displayScale) + 1,
                      (((p.sizeY - y) - 2))   * p.displayScale + 1,
                      //x       * p.displayScale - (p.displayScale / 2), ((p.sizeY - y) - 1)   * p.displayScale - (p.displayScale / 2),
                      (x + 1) * p.displayScale,
                      ((p.sizeY - (y - 0))) * p.displayScale,
                      color,  // rgb
                      alpha);  // alpha

              }
          }
      }
  *)

  // Draw agents
  For i := 0 To high(adata.indivLocs) Do Begin
    c := adata.indivColors[i];
    r := (c); // R: 0..255
    g := ((c And $1F) Shl 3); // G: 0..255
    b := ((c And 7) Shl 5); // B: 0..255

    // Prevent color mappings to very bright colors (hard to see):
    If (rgbToLuma(r, g, b) > maxLumaVal) Then Begin
      If (r > maxColorVal) Then r := r Mod maxColorVal;
      If (g > maxColorVal) Then g := g Mod maxColorVal;
      If (b > maxColorVal) Then b := b Mod maxColorVal;
    End;
    color := (b Shl 16) Or (g Shl 8) Or r;
    image.Canvas.pen.Color := color;
    image.Canvas.Brush.Color := color;
    x := adata.indivLocs[i].x * p.displayScale;
    y := ((p.sizeY - adata.indivLocs[i].y) - 1) * p.displayScale;
    d := trunc(p.agentSize);
    image.Canvas.Ellipse(x, y, x + 2 * d, y + 2 * d); // Shift nach Rechts unten, um 0.5 displayScale damit es "ordentlich" aussieht.
  End;

  // Draw Challenge if Possible
  If p.VisualizeChallenge Then Begin
    RenderChallengeToImage(Image, adata.generation, adata.simStep, adata.Challenge);
  End;

  If ForceDirectories(ExtractFileDir(imageFilename)) Then Begin // Das ForceDir bleibt drin, damit die Filme ein Verzeichnis zum Ablegen haben !
    // Der Orig Code speichert auch keine Einzelbilder, da er ja die Videos Speichert
    // Sollten doch einzelbilder gespeichert werden, dann muss dieser Code hier wieder mit rein !
    //png := TPortableNetworkGraphic.Create;
    //png.Assign(image);
    //png.SaveToFile(imageFilename);
    //png.free;
  End
  Else Begin
    writeln('Error, could not store: ' + imageFilename);
  End;
  (*
   * Dieser Code wird aus einem Thread Context heraus aufgerufen.
   * Sämtliche Prüfungen wurden da schon gemacht
   * -> hier nicht mehr prüfen, wäre auch falsch weil durch das Asynchrone die
   *    Bedingungen nicht mehr aktuell sein könnten !
   *)
  //If p.saveVideo Or AdditionalVideoFrame Then Begin
  jp := TJPEGImage.Create;
  jp.Assign(image);
  // TODO: Kann man das hier noch optimieren ?
  setlength(fimagelist, high(fimagelist) + 2);
  fimagelist[high(fimagelist)] := jp;
  //End;
  image.free;
End;

Procedure TImageWriter.Writeln(Value: String);
Begin
  If assigned(fWritelnEvent) Then Begin
    fWritelnEvent(Value);
  End
  Else Begin
    system.Writeln(Value);
  End;
End;

Procedure TImageWriter.RenderChallengeToImage(Const Image: TBitmap; generation,
  simStep, Challenge: integer);
Var
  radioactiveX, w, h, R: integer;
Begin
  image.canvas.brush.Style := bsClear; // Brush ausschalten
  (*
   * In Grün die "Schwelle" die es zu überschreiten gillt ;-)
   *)
  image.canvas.Pen.Color := clGreen;
  image.canvas.Pen.Width := 2;
  w := p.displayScale * p.sizeX;
  h := p.displayScale * p.sizeY;
  (*
   * Nicht alle Challenges können Visualisiert werden, aber man kann es wenigstens versuchen ;)
   *)
  Case Challenge Of
    CHALLENGE_CIRCLE: Begin
        r := (w) Div 4;
        image.canvas.Ellipse(-r + w Div 4, -r + h Div 4, r + w Div 4, r + h Div 4);
      End;
    CHALLENGE_RIGHT_HALF: Begin
        image.canvas.Line(w Div 2, 0, w Div 2, h);
      End;
    CHALLENGE_RIGHT_QUARTER: Begin
        image.canvas.Line(w Div 2 + w Div 4, 0, w Div 2 + w Div 4, h);
      End;
    CHALLENGE_RADIOACTIVE_BARRIER: Begin
        image.canvas.Line(w Div 2 + w Div 4, 0, w Div 2 + w Div 4, h);
        // Die Radioaktive Linie
        image.canvas.Pen.Color := clred;
        image.canvas.Pen.Width := 2;
        image.canvas.Line(w Div 2 + w Div 4, h Div 4 + p.displayScale, w Div 2 + w Div 4, h Div 4 + h Div 2 - 2 * p.displayScale);
        image.canvas.Pen.Width := 1;
      End;
    CHALLENGE_LEFT_EIGHTH: Begin
        image.canvas.Line(w Div 8, 0, w Div 8, h);
      End;
    CHALLENGE_STRING: Begin
        // Wie auch immer man das Visualisiert ?
      End;
    CHALLENGE_CENTER_WEIGHTED: Begin
        r := (w) Div 3;
        image.canvas.Ellipse(-r + w Div 2, -r + h Div 2, r + w Div 2, r + h Div 2);
      End;
    CHALLENGE_CENTER_UNWEIGHTED: Begin
        r := (w) Div 3;
        image.canvas.Ellipse(-r + w Div 2, -r + h Div 2, r + w Div 2, r + h Div 2);
      End;
    CHALLENGE_CENTER_SPARSE: Begin
        // Wie auch immer man das Visualisiert ?
      End;
    CHALLENGE_CORNER: Begin
        r := (w) Div 8;
        image.canvas.Ellipse(-r, -r, r, r);
        image.canvas.Ellipse(-r + w, -r, r + w, r);
        image.canvas.Ellipse(-r + w, -r + h, r + w, r + h);
        image.canvas.Ellipse(-r, -r + h, r, r + h);
      End;
    CHALLENGE_CORNER_WEIGHTED: Begin
        r := (w) Div 4;
        image.canvas.Ellipse(-r, -r, r, r);
        image.canvas.Ellipse(-r + w, -r, r + w, r);
        image.canvas.Ellipse(-r + w, -r + h, r + w, r + h);
        image.canvas.Ellipse(-r, -r + h, r, r + h);
      End;
    CHALLENGE_RADIOACTIVE_WALLS: Begin
        // Die "save" Linie
        image.canvas.Line(w Div 2, 0, w Div 2, h);
        // Die Radioaktive Linie
        image.canvas.Pen.Color := clred;
        If (simStep < p.stepsPerGeneration / 2) Then
          radioactiveX := 1
        Else
          radioactiveX := w - 1;
        image.canvas.Pen.Width := 2;
        image.canvas.Line(radioactiveX, 0, radioactiveX, h);
        image.canvas.Pen.Width := 1;
      End;
    CHALLENGE_AGAINST_ANY_WALL: Begin
        image.Canvas.Rectangle(0, 0, w, h);
      End;
    CHALLENGE_TOUCH_ANY_WALL: Begin
        image.Canvas.Rectangle(0, 0, w, h);
      End;
    CHALLENGE_MIGRATE_DISTANCE: Begin
        // Wie auch immer man das Visualisiert ?
      End;
    CHALLENGE_EAST_WEST_EIGHTHS: Begin
        image.canvas.Line(w Div 8, 0, w Div 8, h);
        image.canvas.Line(w - w Div 8, 0, w - w Div 8, h);
      End;
    CHALLENGE_NEAR_BARRIER: Begin
        // TODO: Knifflig sollte aber möglich sein ..
      End;
    CHALLENGE_PAIRS: Begin
        // Wie auch immer man das Visualisiert ?
      End;
    CHALLENGE_LOCATION_SEQUENCE: Begin
        // Wie auch immer man das Visualisiert ?
      End;
    CHALLENGE_ALTRUISM_SACRIFICE: Begin
        // Wie auch immer man das Visualisiert ?
      End;
    CHALLENGE_ALTRUISM: Begin
        // Wie auch immer man das Visualisiert ?
      End;
  End;
End;

Procedure TImageWriter.SetCrashed(Value: Boolean);
Begin
  // Nichts im Synchronen Modus ist uns das Egal
End;

Procedure TImageWriter.AddChartRendererToQueue(Const SC: TSimpleChart);
Var
  png: TPortableNetworkGraphic;
Begin
  png := sc.SaveToPngImage(2000, 400);
  If Not ForceDirectories(p.imageDir) Then Begin
    writeln('Error: could not create: ' + p.imageDir);
  End
  Else Begin
    png.SaveToFile(IncludeTrailingPathDelimiter(p.imageDir) + 'log.png');
  End;
  png.free;
  sc.free;
End;

Function makeGeneticColor(Const Genome: Tgenome): uint8_t;
Begin
  result := ((length(genome) And 1)
    Or ((genome[0].sourceType) Shl 1)
    Or ((genome[high(genome)].sourceType) Shl 2)
    Or ((genome[0].sinkType) Shl 3)
    Or ((genome[high(genome)].sinkType) Shl 4)
    Or ((genome[0].sourceNum And 1) Shl 5)
    Or ((genome[0].sinkNum And 1) Shl 6)
    Or ((genome[high(genome)].sourceNum And 1) Shl 7));
End;

{ TImageWriterThread }

Procedure TImageWriterThread.WritelnEvent;
Var
  s: String;
Begin
  While fstringFivo.Count <> 0 Do Begin
    s := fstringFivo.Pop;
    If assigned(fWritelnCallback) Then Begin
      fWritelnCallback(self, s);
    End;
  End;
End;

Procedure TImageWriterThread.Setup;
Begin
  fcrashed := false;
  fscq := TSimpleChartQueue.create;
  fstringFivo := tStringQueue.create;
  fImageWriter := TImageWriter.Create();
  fImageWriter.fWritelnEvent := @self.Writeln;
  fJobQueue := TJobQueue.create;
End;

Procedure TImageWriterThread.TearDown;
Begin
  fstringFivo.free;
  fstringFivo := Nil;
  // Das darf im Teardown nicht freigegeben werden da es sonst im Herunterfahren nicht mehr ausgewertet werden kann !
  //fImageWriter.free;
  //fImageWriter := Nil;
  //fJobQueue.free;
  //fJobQueue := Nil;
End;

Procedure TImageWriterThread.Writeln(Value: String);
Begin
  fstringFivo.Push(value);
End;

Procedure TImageWriterThread.HandleJob(Const Job: TJob);
Begin
  Case Job.Kind Of
    jkFrame: fImageWriter.saveOneFrameImmed(Job.Data);
    jksaveGenerationVideo: fImageWriter.saveGenerationVideo(Job.data.generation);
  End;
End;

Procedure TImageWriterThread.HandleSCEvent(Const SC: TSimpleChart);
Begin
  fImageWriter.AddChartRendererToQueue(sc);
End;

Procedure TImageWriterThread.Execute;
Begin
  While Not Terminated Do Begin
    If fstringFivo.Count <> 0 Then Begin
      Synchronize(@WritelnEvent);
    End;
    If fJobQueue.Count = 0 Then Begin
      sleep(1);
    End
    Else Begin
      HandleJob(fJobQueue.Pop);
    End;
    If fscq.Count <> 0 Then Begin
      HandleSCEvent(fscq.Pop);
    End;
  End;
  Teardown;
End;

Constructor TImageWriterThread.Create(CreateSuspended: Boolean;
  WritelnCallback: TWritelnCallback; Const StackSize: SizeUInt);
Begin
  Inherited Create(CreateSuspended, StackSize);
  fWritelnCallback := WritelnCallback;
  FreeOnTerminate := false;
  Setup(); // Setup noch im Context des MainThread ausführen, sonst kann es "knallen"
  Start;
End;

Function TImageWriterThread.saveVideoFrameSync(simStep, generation,
  Challenge: unsigned): bool;
Var
  Indiv: Pindiv;
  index, i, data_indivLocs_cnt, data_indivColors_cnt: Integer;
  barrierLocs: TCoordArray;
  data: TImageFrameData;
  j: TJob;
Begin
  // We cache a local copy of data from params, grid, and peeps because
  // those objects will change by the main thread at the same time our
  // saveFrameThread() is using it to output a video frame.
  data.simStep := simStep;
  data.generation := generation;
  data.Challenge := Challenge;
  setlength(data.indivLocs, p.population + 1);
  data_indivLocs_cnt := 0;
  setlength(data.indivColors, p.population + 1);
  data_indivColors_cnt := 0;
  setlength(data.barrierLocs, 0);

  For index := 0 To p.population Do Begin // TODO: Sollte das nicht bei 1 los gehen ?
    indiv := peeps[index];
    If (indiv^.alive) Then Begin
      data.indivLocs[data_indivLocs_cnt] := indiv^.loc;
      inc(data_indivLocs_cnt);

      data.indivColors[data_indivColors_cnt] := makeGeneticColor(indiv^.genome);
      inc(data_indivColors_cnt);
    End;
  End;
  setlength(data.indivLocs, data_indivLocs_cnt);
  setlength(data.indivColors, data_indivColors_cnt);

  barrierLocs := grid.getBarrierLocations();
  setlength(data.barrierLocs, length(barrierLocs));
  For i := 0 To high(barrierLocs) Do Begin
    data.barrierLocs[i] := barrierLocs[i];
  End;

  j.Kind := jkFrame;
  j.Data := data;
  fJobQueue.Push(j);

  result := true;
End;

Procedure TImageWriterThread.saveGenerationVideo(generation: unsigned);
Var
  j: TJob;
Begin
  j.Kind := jksaveGenerationVideo;
  j.Data.generation := generation;
  fJobQueue.Push(j);
End;

Procedure TImageWriterThread.SetCrashed(Value: Boolean);
Begin
  fcrashed := Value;
End;

Procedure TImageWriterThread.AddChartRendererToQueue(Const SC: TSimpleChart);
Begin
  fscq.Push(sc);
End;

Procedure TImageWriterThread.Free;
Var
  key: Char;
Begin
  Terminate;
  While Not Finished Do Begin
    CheckSynchronize(1);
  End;
  (*
   * Sollten noch Bilder in der Writequeue sein (in der Regel die von der letzten Generation)
   * dann lassen wir dem User die Wahl diese auf zu heben oder "weg zu werfen".
   *)
  If assigned(fWritelnCallback) And (Not fcrashed) Then Begin
    fImageWriter.fWritelnEvent := Nil; // Der Rest läuft im Kontext des Main Threads -> also die Fifo wieder deaktivieren !
    While fJobQueue.Count <> 0 Do Begin
      fWritelnCallback(self, ' ' + inttostr(fJobQueue.Count) + ' jobs in write queue, press q to abort writing.');
      HandleJob(fJobQueue.Pop);
      If KeyPressed Then Begin
        key := ReadKey;
        If (key = 'q') Or (key = 'Q') Then Begin
          fWritelnCallback(self, 'Abort missing ' + inttostr(fJobQueue.Count) + ' jobs, going down.');
          fJobQueue.Clear;
        End;
      End;
    End;
  End;
  If Not fcrashed Then Begin
    While Not fscq.isempty Do Begin
      HandleSCEvent(fscq.Pop);
    End;
  End
  Else Begin
    While Not fscq.isempty Do Begin
      fscq.Pop.Free;
    End;
  End;
  fscq.free;
  fImageWriter.free;
  fImageWriter := Nil;
  fJobQueue.Clear;
  fJobQueue.Free;
  fJobQueue := Nil;
  Inherited free;
End;

{ TImageWriter }

Constructor TImageWriter.Create;
Begin
  fWritelnEvent := Nil;
  fAVI := tgwavi.Create();
  fimagelist := Nil;
  startNewGeneration();
End;

Destructor TImageWriter.Destroy;
Begin
  fAVI.Free;
  startNewGeneration(); // Das gibt dann alles frei ;)
End;

Procedure TImageWriter.startNewGeneration;
Var
  i: Integer;
Begin
  For i := 0 To high(fimagelist) Do Begin
    fimagelist[i].Free;
  End;
  setlength(fimagelist, 0);
End;

// Synchronous version, always returns true

Function TImageWriter.saveVideoFrameSync(simStep, generation,
  Challenge: unsigned): bool;
Var
  Indiv: Pindiv;
  index, i, data_indivLocs_cnt, data_indivColors_cnt: Integer;
  barrierLocs: TCoordArray;
Begin
  // We cache a local copy of data from params, grid, and peeps because
  // those objects will change by the main thread at the same time our
  // saveFrameThread() is using it to output a video frame.
  data.simStep := simStep;
  data.generation := generation;
  data.Challenge := Challenge;
  setlength(data.indivLocs, p.population + 1);
  data_indivLocs_cnt := 0;
  setlength(data.indivColors, p.population + 1);
  data_indivColors_cnt := 0;
  setlength(data.barrierLocs, 0);

  For index := 0 To p.population Do Begin
    indiv := peeps[index];
    If (indiv^.alive) Then Begin
      data.indivLocs[data_indivLocs_cnt] := indiv^.loc;
      inc(data_indivLocs_cnt);

      data.indivColors[data_indivColors_cnt] := makeGeneticColor(indiv^.genome);
      inc(data_indivColors_cnt);
    End;
  End;
  setlength(data.indivLocs, data_indivLocs_cnt);
  setlength(data.indivColors, data_indivColors_cnt);


  barrierLocs := grid.getBarrierLocations();
  setlength(data.barrierLocs, length(barrierLocs));
  For i := 0 To high(barrierLocs) Do Begin
    data.barrierLocs[i] := barrierLocs[i];
  End;

  saveOneFrameImmed(data);

  result := true;
End;

Procedure TImageWriter.saveGenerationVideo(generation: unsigned);
Var
  videoFilename: String;
  m: TMemoryStream;
  i: Integer;
Begin
  If assigned(fimageList) Then Begin
    videoFilename := IncludeTrailingPathDelimiter(p.imageDir) +
      'gen-' + format('%0.6d', [generation]) +
      '.avi';
    fAVI.Open(videoFilename,
      trunc(p.sizeX * p.displayScale * 1.0),
      trunc(p.sizeY * p.displayScale * 1.0),
      'MJPG',
      25 // Warum sind das nicht 30, so wie im Youtube Video gesagt ?
      , Nil
      );
    assert(length(fimagelist) = p.stepsPerGeneration, 'fimagelist has wrong length, is ' + inttostr(length(fimagelist)) + ' should be ' + inttostr(p.stepsPerGeneration));
    For i := 0 To high(fimagelist) Do Begin
      m := TMemoryStream.Create;
      fimagelist[i].SaveToStream(m);
      m.Position := 0;
      fAVI.Add_Frame(m);
      m.free;
    End;
    fAVI.Close();
    Writeln(extractfilename(videoFilename) + ' writen.');
  End;
  startNewGeneration();
End;

End.

