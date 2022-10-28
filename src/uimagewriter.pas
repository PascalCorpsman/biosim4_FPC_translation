Unit uImageWriter;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Graphics, Classes, SysUtils, ubasicTypes, ufifo, ugwavi;

{$I c_types.inc}
{$INTERFACES corba}

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
    indivLocs: Array Of TCoord;
    indivColors: Array Of uint8_t;
    barrierLocs: Array Of TCoord;
    signalLayers: Array Of Array Of Array Of uint8; // [layer][x][y]
  End;

  { IImageWriterInterface }

  IImageWriterInterface = Interface
    Procedure SetCrashed(Value: Boolean); // Dem Imagewriter Mitteilen dass die Anwendung abgeraucht ist
    Procedure startNewGeneration();
    Function saveVideoFrameSync(simStep, generation: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
    Procedure Free;

  End;


  { TImageWriter }

  TImageWriter = Class(IImageWriterInterface)
  private
    fimagelist: Array Of TJPEGImage;
    data: TImageFrameData;
    fAVI: tgwavi;
    fWritelnEvent: TWritelnEvent;
    Procedure saveOneFrameImmed(Const adata: TImageFrameData);
    Procedure Writeln(Value: String);
  public
    Constructor Create(); virtual;
    Destructor Destroy(); override;
    Procedure startNewGeneration();
    Function saveVideoFrameSync(simStep, generation: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
    Procedure SetCrashed(Value: Boolean);
  End;

  tStringQueue = specialize TFifo < String > ;

  TJobKind = (jkFrame, jkStartNewGeneration, jksaveGenerationVideo);

  TJob = Record
    Kind: TJobKind;
    Data: TImageFrameData;
  End;

  TJobQueue = Specialize TFifo < TJob > ;

  { TImageWriterThread }

  TImageWriterThread = Class(TThread, IImageWriterInterface)
  private
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
  public
    Procedure Execute(); override;
    Constructor Create(CreateSuspended: Boolean; WritelnCallback: TWritelnCallback;
      Const StackSize: SizeUInt = DefaultStackSize);

    Procedure startNewGeneration();
    Function saveVideoFrameSync(simStep, generation: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
    Procedure SetCrashed(Value: Boolean);
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
  // Das * 1.0 ist weil unter Windows sonst nicht bestimmt werden kann welche trunc version verwendet werden soll..
  image.Width := trunc(p.sizeX * p.displayScale * 1.0);
  image.height := trunc(p.sizeY * p.displayScale * 1.0);
  image.canvas.brush.color := clwhite;
  image.canvas.rectangle(-1, -1, image.Width + 1, image.Height + 1);
  imageFilename := IncludeTrailingPathDelimiter(p.imageDir) + format('frame-%0.6d-%0.6d.png', [adata.generation, adata.simStep]);

  // Draw barrier locations
  Color := $00888888;
  For i := 0 To high(adata.barrierLocs) Do Begin
    image.Canvas.pen.Color := color;
    image.Canvas.Brush.Color := color;
    image.Canvas.Rectangle(
      adata.barrierLocs[i].x * p.displayScale - (p.displayScale Div 2), ((p.sizeY - adata.barrierLocs[i].y) - 1) * p.displayScale - (p.displayScale Div 2),
      (adata.barrierLocs[i].x + 1) * p.displayScale, ((p.sizeY - (adata.barrierLocs[i].y - 0))) * p.displayScale);
  End;

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
    image.Canvas.Ellipse(x - d, y - d, x + d, y + d);
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
  If p.saveVideo Then Begin
    jp := TJPEGImage.Create;
    jp.Assign(image);
    setlength(fimagelist, high(fimagelist) + 2);
    fimagelist[high(fimagelist)] := jp;
  End;
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

Procedure TImageWriter.SetCrashed(Value: Boolean);
Begin
  // Nichts im Synchronen Modus ist uns das Egal
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
    jkStartNewGeneration: fImageWriter.startNewGeneration();
  End;
End;

Procedure TImageWriterThread.Execute;
Begin
  Setup();
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
  End;
  Teardown;
End;

Constructor TImageWriterThread.Create(CreateSuspended: Boolean;
  WritelnCallback: TWritelnCallback; Const StackSize: SizeUInt);
Begin
  Inherited Create(CreateSuspended, StackSize);
  fWritelnCallback := WritelnCallback;
  FreeOnTerminate := false;
  Start;
End;

Procedure TImageWriterThread.startNewGeneration;
Var
  j: TJob;
Begin
  j.Kind := jkStartNewGeneration;
  fJobQueue.Push(j);
End;

Function TImageWriterThread.saveVideoFrameSync(simStep, generation: unsigned
  ): bool;
Var
  Indiv: Pindiv;
  index, i: Integer;
  barrierLocs: TCoordArray;
  data: TImageFrameData;
  j: TJob;
Begin
  // We cache a local copy of data from params, grid, and peeps because
  // those objects will change by the main thread at the same time our
  // saveFrameThread() is using it to output a video frame.
  data.simStep := simStep;
  data.generation := generation;
  setlength(data.indivLocs, 0);
  setlength(data.indivColors, 0);
  setlength(data.barrierLocs, 0);
  setlength(data.signalLayers, 0, 0, 0);
  //todo!!!
  For index := 0 To p.population Do Begin
    indiv := peeps[index];
    If (indiv^.alive) Then Begin
      setlength(data.indivLocs, high(data.indivLocs) + 2);
      data.indivLocs[high(data.indivLocs)] := indiv^.loc;
      setlength(data.indivColors, high(data.indivColors) + 2);
      data.indivColors[high(data.indivColors)] := makeGeneticColor(indiv^.genome);
    End;

    barrierLocs := grid.getBarrierLocations();
    setlength(data.barrierLocs, length(barrierLocs));
    For i := 0 To high(barrierLocs) Do Begin
      data.barrierLocs[i] := barrierLocs[i];
    End;
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

Procedure TImageWriterThread.Free;
Var
  key: Char;
Begin
  Terminate;
  While Not Finished Do Begin
    CheckSynchronize(1);
  End;
  (*
   * Sollten noch Bilder in der Writequeue sein (in der Regen die von der letzten Generation)
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

Function TImageWriter.saveVideoFrameSync(simStep, generation: unsigned): bool;
Var
  Indiv: Pindiv;
  index, i: Integer;
  barrierLocs: TCoordArray;
Begin
  // We cache a local copy of data from params, grid, and peeps because
  // those objects will change by the main thread at the same time our
  // saveFrameThread() is using it to output a video frame.
  data.simStep := simStep;
  data.generation := generation;
  setlength(data.indivLocs, 0);
  setlength(data.indivColors, 0);
  setlength(data.barrierLocs, 0);
  setlength(data.signalLayers, 0, 0, 0);
  //todo!!!
  For index := 0 To p.population Do Begin
    indiv := peeps[index];
    If (indiv^.alive) Then Begin
      //            data.indivLocs.push_back(indiv.loc);
      setlength(data.indivLocs, high(data.indivLocs) + 2);
      data.indivLocs[high(data.indivLocs)] := indiv^.loc;
      setlength(data.indivColors, high(data.indivColors) + 2);
      data.indivColors[high(data.indivColors)] := makeGeneticColor(indiv^.genome);
    End;

    barrierLocs := grid.getBarrierLocations();
    setlength(data.barrierLocs, length(barrierLocs));
    For i := 0 To high(barrierLocs) Do Begin
      data.barrierLocs[i] := barrierLocs[i];
    End;
  End;
  //
  saveOneFrameImmed(data);
  result := true;
End;

// ToDo: put save_video() in its own thread

Procedure TImageWriter.saveGenerationVideo(generation: unsigned);
Var
  videoFilename: String;
  m: TMemoryStream;
  i: Integer;
Begin
  // TODO: Hier die Imagelist welche via "imageList.push_back" erstellt wird als .avi speichern (siehe lazarusforum thread  https://lazarusforum.de/viewtopic.php?f=18&t=14483 )
  If assigned(fimageList) Then Begin
    videoFilename := p.imageDir + PathDelim +
      'gen-' + format('%0.6d', [generation]) +
      '.avi';
    fAVI.Open(videoFilename,
      trunc(p.sizeX * p.displayScale * 1.0),
      trunc(p.sizeY * p.displayScale * 1.0),
      'MJPG',
      25 // Warum sind das nicht 30 ?
      , Nil
      );
    //        cv::setNumThreads(2);
    //        imageList.save_video(videoFilename.str().c_str(),
    //                             25,
    //                             "H264");
    For i := 0 To high(fimagelist) Do Begin
      m := TMemoryStream.Create;
      fimagelist[i].SaveToStream(m);
      m.Position := 0;
      fAVI.Add_Frame(m);
      m.free;
    End;
    fAVI.Close();
    //        if (skippedFrames > 0) {
    //            std::cout << "Video skipped " << skippedFrames << " frames" << std::endl;
    //        }
    Writeln(extractfilename(videoFilename) + ' writen.');

  End;
  startNewGeneration();
End;

//void ImageWriter::abort()
//{
//    busy =true;
//    abortRequested = true;
//    {
//        std::lock_guard<std::mutex> lck(mutex_);
//        dataReady = true;
//    }
//    condVar.notify_one();
//}

// Runs in a thread; wakes up when there's a video frame to generate.
// When this wakes up, local copies of Params and Peeps will have been
// cached for us to use.
//void ImageWriter::saveFrameThread()
//{
//    busy = false; // we're ready for business
//    std::cout << "Imagewriter thread started." << std::endl;
//
//    while (true) {
//        // wait for job on queue
//        std::unique_lock<std::mutex> lck(mutex_);
//        condVar.wait(lck, [&]{ return dataReady && busy; });
//        // save frame
//        dataReady = false;
//        busy = false;
//
//        if (abortRequested) {
//            break;
//        }
//
//        // save image frame
//        saveOneFrameImmed(imageWriter.data);
//
//        //std::cout << "Image writer thread waiting..." << std::endl;
//        //std::this_thread::sleep_for(std::chrono::seconds(2));
//
//    }
//    std::cout << "Image writer thread exiting." << std::endl;
//}


// This is a synchronous gate for giving a job to saveFrameThread().
// Called from the same thread as the main simulator loop thread during
// single-thread mode.
// Returns true if the image writer accepts the job; returns false
// if the image writer is busy. Always called from a single thread
// and communicates with a single saveFrameThread(), so no need to make
// a critical section to safeguard the busy flag. When this function
// sets the busy flag, the caller will immediate see it, so the caller
// won't call again until busy is clear. When the thread clears the busy
// flag, it doesn't matter if it's not immediately visible to this
// function: there's no consequence other than a harmless frame-drop.
// The condition variable allows the saveFrameThread() to wait until
// there's a job to do.
//bool ImageWriter::saveVideoFrame(unsigned simStep, unsigned generation)
//{
//    if (!busy) {
//        busy = true;
//        // queue job for saveFrameThread()
//        // We cache a local copy of data from params, grid, and peeps because
//        // those objects will change by the main thread at the same time our
//        // saveFrameThread() is using it to output a video frame.
//        data.simStep = simStep;
//        data.generation = generation;
//        data.indivLocs.clear();
//        data.indivColors.clear();
//        data.barrierLocs.clear();
//        data.signalLayers.clear();
//        //todo!!!
//        for (uint16_t index = 1; index <= p.population; ++index) {
//            const Indiv &indiv = peeps[index];
//            if (indiv.alive) {
//                data.indivLocs.push_back(indiv.loc);
//                data.indivColors.push_back(makeGeneticColor(indiv.genome));
//            }
//        }
//
//        auto const &barrierLocs = grid.getBarrierLocations();
//        for (Coord loc : barrierLocs) {
//            data.barrierLocs.push_back(loc);
//        }
//
//        // tell thread there's a job to do
//        {
//            std::lock_guard<std::mutex> lck(mutex_);
//            dataReady = true;
//        }
//        condVar.notify_one();
//        return true;
//    } else {
//        // image saver thread is busy, drop a frame
//        ++droppedFrameCount;
//        return false;
//    }
//}

End.

