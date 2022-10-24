Unit uImageWriter;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, ubasicTypes, ufifo;

{$I c_types.inc}
{$INTERFACES corba}

// Creates a graphic frame for each simStep, then
// assembles them into a video at the end of a generation.

Type

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

    Procedure startNewGeneration();
    Function saveVideoFrameSync(simStep, generation: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
    Procedure Free;

  End;


  { TImageWriter }

  TImageWriter = Class(IImageWriterInterface)
  private
    data: TImageFrameData;
  public
    Constructor Create();
    Procedure startNewGeneration();
    Function saveVideoFrameSync(simStep, generation: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
  End;

  tStringQueue = specialize TFifo < String > ;

  TFrameQueue = Specialize TFifo < TImageFrameData > ;

  { TImageWriterThread }

  TImageWriterThread = Class(TThread, IImageWriterInterface)
  private
    fImageWriter: TImageWriter;
    fWritelnCallback: TWritelnCallback;
    fstringFivo: tStringQueue;
    fFrameQueue: TFrameQueue;
    // Alles ab hier wird im Kontext des Mainthreads ausgeführt.
    Procedure WritelnEvent;

    // Alles ab hier wird im Kontext des Threads ausgeführt.
    Procedure Setup;
    Procedure TearDown;
    Procedure Writeln(Value: String);
  public
    Procedure Execute(); override;
    Constructor Create(CreateSuspended: Boolean; WritelnCallback: TWritelnCallback;
      Const StackSize: SizeUInt = DefaultStackSize);

    Procedure startNewGeneration();
    Function saveVideoFrameSync(simStep, generation: unsigned): bool;
    Procedure saveGenerationVideo(generation: unsigned);
    Procedure Free;
  End;

Implementation

Uses uparams, uindiv, uSimulator, ugenome, Graphics, crt;

// Pushes a new image frame onto .imageList.

Procedure saveOneFrameImmed(Const data: TImageFrameData);
Const
  maxColorVal = $B0;
  maxLumaVal = $B0;

  Function rgbToLuma(r, g, b: uint8_t): uint8;
  Begin
    result := (r + r + r + b + g + g + g + g) Div 8;
  End;


Var
  image: TBitmap;
  png: TPortableNetworkGraphic;
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
  imageFilename := IncludeTrailingPathDelimiter(p.imageDir) + format('frame-%0.6d-%0.6d.png', [data.generation, data.simStep]);

  // Draw barrier locations
  Color := $00888888;
  For i := 0 To high(data.barrierLocs) Do Begin
    image.Canvas.pen.Color := color;
    image.Canvas.Brush.Color := color;
    image.Canvas.Rectangle(
      data.barrierLocs[i].x * p.displayScale - (p.displayScale Div 2), ((p.sizeY - data.barrierLocs[i].y) - 1) * p.displayScale - (p.displayScale Div 2),
      (data.barrierLocs[i].x + 1) * p.displayScale, ((p.sizeY - (data.barrierLocs[i].y - 0))) * p.displayScale);
  End;

  // Draw agents
  For i := 0 To high(data.indivLocs) Do Begin
    c := data.indivColors[i];
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
    x := data.indivLocs[i].x * p.displayScale;
    y := ((p.sizeY - data.indivLocs[i].y) - 1) * p.displayScale;
    d := trunc(p.agentSize);
    image.Canvas.Ellipse(x - d, y - d, x + d, y + d);
  End;

  If ForceDirectories(ExtractFileDir(imageFilename)) Then Begin
    png := TPortableNetworkGraphic.Create;
    png.Assign(image);
    png.SaveToFile(imageFilename);
    png.free;
  End
  Else Begin
    writeln('Error, could not store: ' + imageFilename);
  End;
  image.free;
  //  imageList.push_back(image); //-- Wäre dazu da aus den einzelbildern einen .avi zu machen, mal sehen ob wir das mittels FPC hin kriegen ;)
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
  fstringFivo := tStringQueue.create;
  fImageWriter := TImageWriter.Create();
  fFrameQueue := TFrameQueue.create;

End;

Procedure TImageWriterThread.TearDown;
Begin
  fstringFivo.free;
  fstringFivo := Nil;
  fImageWriter.free;
  fImageWriter := Nil;
  // Das darf im Teardown nicht freigegeben werden da es sonst im Herunterfahren nicht mehr ausgewertet werden kann !
  //fFrameQueue.free;
  //fFrameQueue := Nil;
End;

Procedure TImageWriterThread.Writeln(Value: String);
Begin
  fstringFivo.Push(value);
End;

Procedure TImageWriterThread.Execute;
Begin
  Setup();
  While Not Terminated Do Begin
    If fstringFivo.Count <> 0 Then Begin
      Synchronize(@WritelnEvent);
    End;
    If fFrameQueue.Count = 0 Then Begin
      sleep(1);
    End
    Else Begin
      saveOneFrameImmed(fFrameQueue.Pop);
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
Begin
  // ??
End;

Function TImageWriterThread.saveVideoFrameSync(simStep, generation: unsigned
  ): bool;
Var
  Indiv: Pindiv;
  index, i: Integer;
  barrierLocs: TCoordArray;
  data: TImageFrameData;
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
  fFrameQueue.Push(data);
  result := true;
End;

Procedure TImageWriterThread.saveGenerationVideo(generation: unsigned);
Begin
  // TODO: was auch immer hier geschieht ..
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
  If assigned(fWritelnCallback) Then Begin
    While fFrameQueue.Count <> 0 Do Begin
      fWritelnCallback(self, ' ' + inttostr(fFrameQueue.Count) + ' images in write queue, press q to abort writing.');
      saveOneFrameImmed(fFrameQueue.Pop);
      If KeyPressed Then Begin
        key := ReadKey;
        If (key = 'q') Or (key = 'Q') Then Begin
          fWritelnCallback(self, 'Abort missing ' + inttostr(fFrameQueue.Count) + ' images, going down.');
          fFrameQueue.Clear;
        End;
      End;
    End;
  End;
  fFrameQueue.Clear;
  fFrameQueue.Free;
  fFrameQueue := Nil;
  Inherited free;
End;

{ TImageWriter }

Constructor TImageWriter.Create;
Begin
  startNewGeneration();
End;

Procedure TImageWriter.startNewGeneration;
Begin
  // ??
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
Begin
  // TODO: Hier die Imagelist welche via "imageList.push_back" erstellt wird als .avi speichern (siehe lazarusforum thread  https://lazarusforum.de/viewtopic.php?f=18&t=14483 )
  //    if (imageList.size() > 0) {
  //        std::stringstream videoFilename;
  //        videoFilename << p.imageDir.c_str() << "/gen-"
  //                      << std::setfill('0') << std::setw(6) << generation
  //                      << ".avi";
  //        cv::setNumThreads(2);
  //        imageList.save_video(videoFilename.str().c_str(),
  //                             25,
  //                             "H264");
  //        if (skippedFrames > 0) {
  //            std::cout << "Video skipped " << skippedFrames << " frames" << std::endl;
  //        }
  //    }
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

