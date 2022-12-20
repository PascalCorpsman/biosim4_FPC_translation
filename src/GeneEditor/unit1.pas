Unit Unit1;

{$MODE objfpc}{$H+}

Interface

Uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Menus, ugraphs, uparams;

Type

  { TForm1 }

  TForm1 = Class(TForm)
    MainMenu1: TMainMenu;
    MenuItem1: TMenuItem;
    MenuItem10: TMenuItem;
    MenuItem11: TMenuItem;
    MenuItem12: TMenuItem;
    MenuItem13: TMenuItem;
    MenuItem14: TMenuItem;
    MenuItem15: TMenuItem;
    MenuItem2: TMenuItem;
    MenuItem3: TMenuItem;
    MenuItem4: TMenuItem;
    MenuItem5: TMenuItem;
    MenuItem6: TMenuItem;
    MenuItem7: TMenuItem;
    MenuItem8: TMenuItem;
    MenuItem9: TMenuItem;
    OpenDialog1: TOpenDialog;
    OpenDialog2: TOpenDialog;
    PopupMenu1: TPopupMenu;
    SaveDialog1: TSaveDialog;
    Separator1: TMenuItem;
    Procedure FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
    Procedure FormCreate(Sender: TObject);
    Procedure FormShow(Sender: TObject);
    Procedure MenuItem10Click(Sender: TObject);
    Procedure MenuItem11Click(Sender: TObject);
    Procedure MenuItem12Click(Sender: TObject);
    Procedure MenuItem13Click(Sender: TObject);
    Procedure MenuItem14Click(Sender: TObject);
    Procedure MenuItem15Click(Sender: TObject);
    Procedure MenuItem2Click(Sender: TObject);
    Procedure MenuItem3Click(Sender: TObject);
    Procedure MenuItem4Click(Sender: TObject);
    Procedure MenuItem5Click(Sender: TObject);
    Procedure MenuItem6Click(Sender: TObject);
    Procedure MenuItem7Click(Sender: TObject);
    Procedure MenuItem8Click(Sender: TObject);
  private
    fdx, fdy: integer;

    Function VisGeneString(Value: String): Boolean;

    Procedure GraphBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    Procedure GraphBoxMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    Procedure GraphBoxMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);

    Procedure CreateSensorActionsNet();
    Procedure OnNodePrepareCanvas(Sender: TGraph; Const aCanvas: TCanvas; Const NodeIndex: Integer);
  public
    DownSelectedIndex: Integer;
    GraphBox: TGraphBox;
    pm: TParamManager;
    Function LoadGenome(Filename: String; index: integer): Boolean; // Index = -1 Load Random

  End;

Var
  Form1ShowOnce: Boolean = true;
  Form1: TForm1;

Implementation

{$R *.lfm}

Uses ugenome, usensoractions, Math;

Function Clamp(Value, Lower, Upper: Integer): Integer;
Begin
  If value < lower Then Begin
    result := lower;
  End
  Else Begin
    If value > Upper Then Begin
      result := Upper;
    End
    Else Begin
      result := value;
    End;
  End;
End;

{ TForm1 }

Procedure TForm1.FormCreate(Sender: TObject);
Begin
  caption := 'Biosim genome Editor ver. 0.01';
  Randomize;
  pm := TParamManager.Create();
  GraphBox := TGraphBox.Create(self);
  GraphBox.Name := 'GraphBox1';
  GraphBox.Parent := self;
  GraphBox.Top := 8;
  GraphBox.Left := 8;
  GraphBox.Width := self.ClientWidth - 16;
  GraphBox.Height := self.ClientHeight - 16;
  GraphBox.Anchors := [akTop, akLeft, akRight, akBottom];
  GraphBox.OnMouseDown := @GraphBoxMouseDown;
  GraphBox.OnMouseMove := @GraphBoxMouseMove;
  GraphBox.OnMouseUp := @GraphBoxMouseUp;
  GraphBox.Graph.OnPrepareNodeCanvas := @OnNodePrepareCanvas;
  GraphBox.PopupMenu := PopupMenu1;
  p.maxNumberNeurons := 4;
  CreateSensorActionsNet();
End;

Procedure TForm1.FormShow(Sender: TObject);
Begin
  If Form1ShowOnce Then Begin
    Form1ShowOnce := false;
    MenuItem5Click(Nil);
  End;
End;

Procedure TForm1.MenuItem10Click(Sender: TObject);
Begin
  // Add Edges
  MenuItem10.Checked := Not MenuItem10.Checked;
  If MenuItem10.Checked Then Begin
    MenuItem11.Checked := false;
    MenuItem14.Checked := false;
  End;
End;

Procedure TForm1.MenuItem11Click(Sender: TObject);
Begin
  // Del Edges
  MenuItem11.Checked := Not MenuItem11.Checked;
  If MenuItem11.Checked Then Begin
    MenuItem10.Checked := false;
    MenuItem14.Checked := false;
  End;
End;

Procedure TForm1.MenuItem12Click(Sender: TObject);
Var
  s: String;
  nc, t: Integer;
Begin
  // Empty Brain
  s := InputBox('Question', 'How many inner should it be ?', inttostr(p.maxNumberNeurons));
  If trim(s) = '' Then exit;
  NC := strtointdef(s, p.maxNumberNeurons);
  t := p.maxNumberNeurons;
  p.maxNumberNeurons := nc;
  CreateSensorActionsNet();
  p.maxNumberNeurons := t;
  MenuItem5Click(Nil);
End;

Procedure TForm1.MenuItem13Click(Sender: TObject);
Var
  c, i: Integer;
  n: TNode;
Begin
  // Add Inner Node
  c := 0;
  For i := 0 To GraphBox.Graph.NodeCount - 1 Do Begin
    If GraphBox.Graph.Node[i].Name[1] = 'N' Then inc(c);
  End;
  i := GraphBox.Graph.AddNode('N' + inttostr(c), 'N' + inttostr(c), Nil, false, 0);
  n := GraphBox.Graph.Node[i];
  n.position := point(
    round((GraphBox.ClientWidth - 20) * system.Random(1000) / 1000 + 10),
    round((GraphBox.ClientHeight - 20) * system.Random(1000) / 1000 + 10));
  GraphBox.Graph.Node[i] := n;
  GraphBox.Invalidate;
End;

Procedure TForm1.MenuItem14Click(Sender: TObject);
Begin
  // Del Node
  MenuItem14.Checked := Not MenuItem14.Checked;
  If MenuItem14.Checked Then Begin
    MenuItem10.Checked := false;
    MenuItem11.Checked := false;
  End;
End;

Procedure TForm1.MenuItem15Click(Sender: TObject);
Var
  s, t: String;
  g: TGene;
  i: Integer;
Begin
  // Show Genome String
  With GraphBox.Graph Do Begin
    s := inttostr(EdgeCount) + ' ';
    For i := 0 To EdgeCount - 1 Do Begin
      t := Node[Edge[i].StartIndex].Name;
      If t[1] = 'N' Then Begin
        g.sourceType := NEURON;
      End
      Else Begin
        g.sourceType := SENSOR;
      End;
      g.sourceNum := strtoint(copy(t, 2, length(t)));
      t := Node[Edge[i].EndIndex].Name;
      If t[1] = 'N' Then Begin
        g.sinkType := NEURON;
      End
      Else Begin
        g.sinkType := SENSOR;
      End;
      g.sinkNum := strtoint(copy(t, 2, length(t)));
      g.weight := clamp(round(strtofloat(Edge[i].EdgeCaption) * 8192), low(int16_t), high(int16_t));
      s := s + format('%0.8X ', [GetCompressedGene(g)]);
    End;
    s := trim(s);
  End;
  showmessage('The genome of this brain is:' + LineEnding + s);
End;

Procedure TForm1.FormCloseQuery(Sender: TObject; Var CanClose: Boolean);
Begin
  pm.free;
  pm := Nil;
End;

Procedure TForm1.GraphBoxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
Begin
  DownSelectedIndex := -1;
  If MenuItem10.Checked Or MenuItem11.Checked Then Begin
    DownSelectedIndex := GraphBox.SelectedNode;
  End;
  If GraphBox.SelectedNode <> -1 Then Begin
    fdx := x - GraphBox.graph.Node[GraphBox.SelectedNode].Position.X;
    fdy := y - GraphBox.graph.Node[GraphBox.SelectedNode].Position.y;
    If MenuItem14.Checked Then Begin
      GraphBox.Graph.DelNode(GraphBox.SelectedNode);
      GraphBox.Invalidate;
    End;
  End;
End;

Procedure TForm1.GraphBoxMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
Var
  s: String;
  f: Single;
Begin
  If DownSelectedIndex <> -1 Then Begin
    If MenuItem10.Checked Then Begin
      // Add Edge
      If GraphBox.SelectedNode <> -1 Then Begin
        s := InputBox('Question', 'Enter edge weight', format('%0.5f', [0.0]));
        f := strtofloatdef(s, 0.0);
        GraphBox.Graph.AddEdge(DownSelectedIndex, GraphBox.SelectedNode, ClBlack, Nil, true, format('%0.5f', [f]));
        GraphBox.Invalidate;
      End;
    End;
    If MenuItem11.Checked Then Begin
      // Del Edge
      If GraphBox.SelectedNode <> -1 Then Begin
        GraphBox.Graph.DelEdge(DownSelectedIndex, GraphBox.SelectedNode);
        GraphBox.Invalidate;
      End;
    End;
  End;
End;

Procedure TForm1.GraphBoxMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
Var
  p: TPoint;
  n: TNode;
Begin
  If (ssleft In shift) And (GraphBox.SelectedNode <> -1) And (Not MenuItem10.Checked) And (Not MenuItem11.Checked) Then Begin
    p.x := x + fdx;
    p.Y := y + fdy;
    n := GraphBox.graph.Node[GraphBox.SelectedNode];
    n.Position := p;
    GraphBox.graph.Node[GraphBox.SelectedNode] := n;
    GraphBox.Invalidate;
  End;
  If (ssleft In shift) And (MenuItem10.Checked Or MenuItem11.Checked) Then Begin
    If DownSelectedIndex <> -1 Then Begin
      GraphBox.Canvas.Pen.Color := clRed;
      GraphBox.Canvas.moveto(GraphBox.graph.Node[DownSelectedIndex].Position);
      GraphBox.Canvas.LineTo(x, y);
      GraphBox.Invalidate;
    End;
  End;
End;

Procedure TForm1.CreateSensorActionsNet;
Var
  i: integer;
Begin
  GraphBox.Graph.Clear;
  For i := 0 To integer(NUM_SENSES) - 1 Do Begin
    GraphBox.graph.AddNode('S' + inttostr(i), sensorName(TSensor(i)), Nil);
  End;
  For i := 0 To p.maxNumberNeurons - 1 Do Begin
    GraphBox.graph.AddNode('N' + IntToStr(i), 'N' + IntToStr(i), Nil, false, 1);
  End;
  For i := 0 To integer(NUM_ACTIONS) - 1 Do Begin
    GraphBox.graph.AddNode('A' + inttostr(i), actionName(TAction(i)), Nil, false, 2);
  End;
  GraphBox.Invalidate;
End;

Procedure TForm1.OnNodePrepareCanvas(Sender: TGraph; Const aCanvas: TCanvas;
  Const NodeIndex: Integer);
Begin
  If GraphBox.Graph.Node[NodeIndex].Selected Then exit;
  Case GraphBox.Graph.Node[NodeIndex].Name[1] Of
    'S': aCanvas.Pen.Color := clBlue;
    'N': aCanvas.Pen.Color := clGray;
    'A': aCanvas.Pen.Color := clFuchsia;
  End;
End;

Procedure TForm1.MenuItem2Click(Sender: TObject);
Begin
  If OpenDialog1.Execute Then Begin
    LoadGenome(OpenDialog1.FileName, -1);
  End;
  //  LoadGenome('..' + PathDelim + 'Challange_1_Right_Half.sim', 0);
End;

Procedure TForm1.MenuItem3Click(Sender: TObject);
Var
  i, j: Integer;
  n: TNode;
  del, finished: Boolean;
Begin
  // Remove Unused
  // Alles was nicht am Ende in einen Aktor wandert wird raus geworfen
  With GraphBox.Graph Do Begin // Das Teufelszeug ;)
    // Versuch das Gleiche nach zu bilden wie in Biosim
    // Alle Neuronen die nur sich selbst oder niemanden Füttern fliegen raus
    Repeat
      finished := true;
      For i := NodeCount - 1 Downto 0 Do Begin
        n := Node[i];
        n.Visited := false;
        Node[i] := n;
        If (n.Name[1] = 'N') Then Begin
          del := (n.Edges = Nil);
          If Not del Then Begin
            del := true;
            For j := 0 To high(n.Edges) Do Begin
              If (n.Edges[j].StartIndex <> n.Edges[j].EndIndex) Or
                (n.Edges[j].StartIndex <> i) Then Begin
                del := false;
                break;
              End;
            End;
          End;
          If del Then Begin
            DelNode(i);
            finished := false; // Mindestens 1 Node wurde gelöscht, also noch ne Runde..
          End;
        End;
      End;
    Until finished;

    // Alles von dem keine Kante Raus oder Rein geht, weg ... -> Weil für die Simulation irrelevant
    For i := 0 To EdgeCount - 1 Do Begin

      n := node[Edge[i].StartIndex];
      n.Visited := true;
      node[Edge[i].StartIndex] := n;

      n := node[Edge[i].EndIndex];
      n.Visited := true;
      node[Edge[i].EndIndex] := n;

    End;
    For i := NodeCount - 1 Downto 0 Do Begin
      If Not node[i].Visited Then Begin
        DelNode(i);
      End;
    End;
  End;
  GraphBox.Invalidate;
End;

Procedure TForm1.MenuItem4Click(Sender: TObject);
Begin
  Close;
End;

Procedure TForm1.MenuItem5Click(Sender: TObject);
Var
  Sis, Ais, Nis: Array Of Integer;
  ang, i, dh, mx: Integer;
  l, angle, s, c: Single;
  n: TNode;
Begin
  // Oder Nice
  // Die Idee ist
  // Alle Sensoren Oben in einem Halbbogen
  // Alle Neuronen in der Mitte
  // Alle Aktoren unten in einem Halbbogen
  sis := Nil;
  Ais := Nil;
  Nis := Nil;
  For i := 0 To GraphBox.Graph.NodeCount - 1 Do Begin
    Case GraphBox.Graph.Node[i].Name[1] Of
      'S': Begin
          setlength(sis, high(sis) + 2);
          sis[high(sis)] := i;
        End;
      'N': Begin
          setlength(Nis, high(nis) + 2);
          nis[high(Nis)] := i;
        End;
      'A': Begin
          setlength(Ais, high(Ais) + 2);
          Ais[high(Ais)] := i;
        End;
    End;
  End;
  dh := GraphBox.ClientHeight Div 2;
  mx := GraphBox.ClientWidth Div 2;
  For i := 0 To high(sis) Do Begin
    ang := 180 - 180 Div length(sis);
    angle := (ang * (i + 1) / length(sis));
    SinCos(DegToRad(angle), s, c);
    n := GraphBox.Graph.Node[sis[i]];
    n.Position := point(round(mx + 0.9 * c * mx), round(dh - 0.9 * dh * s));
    GraphBox.Graph.Node[sis[i]] := n;
  End;
  // Die Neuronen in die Mitte
  If high(nis) >= 20 Then Begin
    // Bei mehr als 20 Inneren Neuronen plazieren wir sie irgendwo im "inneren"
    For i := 0 To high(Nis) Do Begin
      ang := system.random(360);
      SinCos(DegToRad(ang), s, c);
      n := GraphBox.Graph.Node[Nis[i]];
      l := (system.random(60) + 20) / 100;
      n.Position := point(
        round(mx + c * mx * l),
        round(dh + s * dh * l)
        );
      GraphBox.Graph.Node[Nis[i]] := n;
    End;
  End
  Else Begin
    For i := 0 To high(Nis) Do Begin
      n := GraphBox.Graph.Node[Nis[i]];
      n.Position := point(round(GraphBox.ClientWidth * (i + 1.5) / (length(nis) + 2)), round(dh));
      GraphBox.Graph.Node[Nis[i]] := n;
    End;
  End;
  For i := 0 To high(Ais) Do Begin
    ang := 180 - 180 Div length(ais);
    angle := (ang * (i + 1) / length(ais));
    SinCos(DegToRad(angle), s, c);
    n := GraphBox.Graph.Node[Ais[i]];
    n.Position := point(round(mx + 0.9 * c * mx), round(dh + 0.9 * dh * s));
    GraphBox.Graph.Node[Ais[i]] := n;
  End;
  GraphBox.Invalidate;
End;

Procedure TForm1.MenuItem6Click(Sender: TObject);
Var
  f: TFileStream;
Begin
  If SaveDialog1.Execute Then Begin
    f := TFileStream.Create(SaveDialog1.FileName, fmCreate Or fmOpenWrite);
    GraphBox.Graph.SaveToStream(f);
    f.free;
  End;
End;

Procedure TForm1.MenuItem7Click(Sender: TObject);
Var
  f: TFileStream;
Begin
  If OpenDialog2.Execute Then Begin
    f := TFileStream.Create(OpenDialog2.FileName, fmOpenRead);
    GraphBox.Graph.LoadFromStream(f);
    f.free;
    GraphBox.Invalidate;
    MenuItem10.Checked := false;
    MenuItem11.Checked := false;
    MenuItem14.Checked := false;
  End;
End;

Procedure TForm1.MenuItem8Click(Sender: TObject);
Var
  i: Integer;
Begin
  // Fill Up With Missings
  For i := 0 To integer(NUM_SENSES) - 1 Do Begin
    If GraphBox.graph.FindNode('S' + inttostr(i)) = -1 Then Begin
      GraphBox.graph.AddNode('S' + inttostr(i), sensorName(TSensor(i)), Nil);
    End;
  End;
  For i := 0 To integer(NUM_ACTIONS) - 1 Do Begin
    If GraphBox.graph.FindNode('A' + inttostr(i)) = -1 Then Begin
      GraphBox.graph.AddNode('A' + inttostr(i), actionName(TAction(i)), Nil, false, 2);
    End;
  End;
  GraphBox.Invalidate;
End;

Function TForm1.VisGeneString(Value: String): Boolean;
Var
  son, sin: String; // SourceName
  sa: TStringArray;
  g: TGene;
  i, soi, sii: Integer;
  ui32: UInt32;
  dummy: integer;
Begin
  result := false;
  sa := trim(Value).Split(' ');
  If Not assigned(sa) Then exit;
  If strtointdef(sa[0], -1) <> high(sa) Then exit;
  CreateSensorActionsNet;
  For i := 1 To high(sa) Do Begin
    Val('$' + sa[i], ui32, dummy);
    g := GetGeneFromUInt(ui32);
    // 1. Anlegen der Knoten, sollte es diese noch nicht geben
    If g.sourceType = SENSOR Then Begin
      son := 'S' + inttostr(g.sourceNum Mod integer(NUM_SENSES));
    End
    Else Begin
      son := 'N' + inttostr(g.sourceNum Mod p.maxNumberNeurons);
    End;
    soi := GraphBox.graph.FindNode(son);
    If soi = -1 Then Begin
      Raise exception.create('Error, sensor ' + sensorName(TSensor(g.sourceNum Mod integer(NUM_SENSES))) + 'not found.');
    End;
    If g.sinkType = ugenome.ACTION Then Begin
      sin := 'A' + inttostr(g.sinkNum Mod integer(NUM_ACTIONS));
    End
    Else Begin
      sin := 'N' + inttostr(g.sinkNum Mod p.maxNumberNeurons);
    End;
    sii := GraphBox.graph.FindNode(sin);
    If sii = -1 Then Begin
      Raise exception.create('Error, action ' + actionName(TAction(g.sinkNum Mod integer(NUM_ACTIONS))) + 'not found.');
    End;
    // 2. Eintragen der Kantengewichte
    GraphBox.graph.AddEdge(soi, sii, clblack, Nil, true, format('%0.5f', [g.weightAsFloat()]));
  End;
  GraphBox.Invalidate;
End;

Function TForm1.LoadGenome(Filename: String; index: integer): Boolean;
Var
  sl: TStringList;
  sli: integer;
  genome, fn: String;
Begin
  result := false;
  If lowercase(ExtractFileExt(Filename)) <> '.sim' Then exit;
  If Not FileExists(Filename) Then exit;
  sl := TStringList.Create;
  sl.LoadFromFile(Filename);
  If sl.count < 4 Then Begin
    sl.free;
    exit;
  End;
  // Laden der Parameterfile
  fn := IncludeTrailingPathDelimiter(ExtractFileDir(Filename));
  fn := fn + sl[0];
  fn := StringReplace(fn, '/', PathDelim, [rfReplaceAll]);
  fn := StringReplace(fn, '\', PathDelim, [rfReplaceAll]);
  If Not FileExists(fn) Then Begin
    showmessage('Error, could not load Challange config file: ' + fn);
    sl.free;
    exit;
  End;
  pm.registerConfigFile(fn);
  pm.updateFromConfigFile(0);

  If index = -1 Then Begin
    // Ein Zufälliges Genome laden
    sli := system.random(sl.Count - 3) + 3;
  End
  Else Begin
    sli := index + 3;
  End;
  If sli >= sl.Count Then Begin
    sl.free;
    exit;
  End;
  genome := sl[sli];
  //GraphBox.Clear;
  VisGeneString(genome);

  sl.free;
  result := true;
End;

End.

