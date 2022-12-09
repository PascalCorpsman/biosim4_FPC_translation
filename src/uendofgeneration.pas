Unit uEndOfGeneration;

{$MODE ObjFPC}{$H+}

Interface

Uses
  Classes, SysUtils, Graphics;

{$I c_types.inc}

Procedure endOfGeneration(generation: unsigned);

Implementation

Uses uparams, uSimulator, uImageWriter, usimplechart;

// At the end of each generation, we save a video file (if p.saveVideo is true) and
// print some genomic statistics to stdout (if p.updateGraphLog is true).

Procedure endOfGeneration(generation: unsigned);
Var
  sc: TSimpleChart;
  sl: TStringList;
  Diversity, Survivors: TSeries;
  sa: TStringArray;
  x, i: Integer;
Begin
  If ((p.saveVideo And (
    ((generation Mod p.videoStride) = 0)
    Or (generation <= p.videoSaveFirstFrames)
    Or ((generation >= p.parameterChangeGenerationNumber) And (generation <= p.parameterChangeGenerationNumber + p.videoSaveFirstFrames))
    Or (generation = p.maxGenerations - 1) // Shure save the last simulated generation ;)
    ))) Or AdditionalVideoFrame Then Begin
    imageWriter.saveGenerationVideo(generation);
  End;
  If (p.updateGraphLog And ((generation = 1) Or ((generation Mod p.updateGraphLogStride) = 0)) Or AdditionalVideoFrame) Then Begin
    sc := TSimpleChart.Create();
    sc.XAXis.UseMinVal := true;
    sc.XAXis.MinVal := 0;
    sc.XAXis.MarkFormat := '%0.f';
    sl := TStringList.Create;
    sl.LoadFromFile(IncludeTrailingPathDelimiter(p.logDir) + 'epoch-log.txt'); // Der Existiert immer, da wir den vorher ja erstellt haben ;)
    Survivors := TSeries.Create();
    Diversity := TSeries.Create();
    sc.AddSeries(Survivors);
    sc.AddSeries(Diversity);
    Survivors.SeriesColor := clGreen;
    Survivors.SeriesCaption := 'Survivors';
    Survivors.SeriesWidth := 2;
    Survivors.YAxis.UseMinVal := true;
    Survivors.YAxis.MinVal := 0;
    Survivors.YAxis.UseMaxVal := true;
    Survivors.YAxis.MaxVal := p.population;
    Survivors.YAxis.MarkFormat := '%.0f';
    Diversity.SeriesColor := clPurple;
    Diversity.SeriesCaption := 'Diversity';
    Diversity.SeriesWidth := 2;
    Diversity.YAxis.UseMinVal := true;
    Diversity.YAxis.MinVal := 0;
    Diversity.YAxis.UseMaxVal := true;
    Diversity.YAxis.MaxVal := 1.0;
    Diversity.YAxis.MarkFormat := '%0.2f';
    Diversity.YAxis.Pos := apRight;
    FormatSettings.DecimalSeparator := '.';
    For i := 1 To sl.Count - 1 Do Begin
      sa := sl[i].Split(';');
      x := strtointdef(sa[0], -1);
      Survivors.AddDataPoint(x, strtointdef(sa[1], 0));
      Diversity.AddDataPoint(x, strtofloatdef(sa[2], 0));
    End;
    (*
     * Im Multithread Modus Knallt es, wenn ein TBitmap aus dem Hauptthread heraus erzeugt wird und ebenfalls gleichzeitig im Thread
     * also muss das erzeugen des Bildes ebenfalls durch den ImageWriter Thread geschleust werden ...
     *)
    ImageWriter.AddChartRendererToQueue(sc);
    sl.free;

  End;
End;

End.

