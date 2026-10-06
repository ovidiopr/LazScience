unit uSciPeriodicTable;

{$mode objfpc}{$H+}

{ TSciPeriodicTable - visual periodic table of the elements.

  The element data (sciperiodictable_elements.csv) is compiled into the unit
  through the Lazarus resource file sciperiodictable_elements.lrs (regenerate
  it with  makelrs.py when the CSV changes).
  The element objects are shared by all instances (loaded once), so a
  TSciElement obtained from one table can be assigned to another one.
  The table always fills the client area of the control: cells and fonts are
  scaled when the control (or the form hosting it) is resized. }

interface

uses
  Classes, SysUtils, Types, Math, Contnrs, Graphics, Controls, LCLType, LResources;

const
  SciPTColCount = 18; // groups
  SciPTRowCount = 10; // 7 periods + spacer row + lanthanides + actinides

  DefaultColorLanthanides = clSkyBlue;
  DefaultColorActinides   = TColor($00D3A8FF);
  DefaultColorOthers      = clMoneyGreen;

type
  { TSciElement }

  TSciElement = class
  private
    FNumber: Integer;
    FSymbol: string;
    FName: string;
    FPhase: string;
    FWeight: Double;
    FDensity: Double;
    FMeltingPoint: Double;
    FBoilingPoint: Double;
    FSpecificHeat: Double;
    FCol: Integer; // 0-based position inside the table grid
    FRow: Integer;
  public
    property Number: Integer read FNumber;
    property Symbol: string read FSymbol;
    property Name: string read FName;
    property Phase: string read FPhase;
    property Weight: Double read FWeight;               // u
    // The following values are -1 when unknown
    property Density: Double read FDensity;             // g/cm3
    property MeltingPoint: Double read FMeltingPoint;   // K
    property BoilingPoint: Double read FBoilingPoint;   // K
    property SpecificHeat: Double read FSpecificHeat;   // J/(g*K)
  end;

  TSciElementEvent = procedure(Sender: TObject; Element: TSciElement) of object;

  { TSciPeriodicTable }

  TSciPeriodicTable = class(TCustomControl)
  private
    FSelected: TSciElement;
    FShowDetails: Boolean;
    FColorLanthanides: TColor;
    FColorActinides: TColor;
    FColorOthers: TColor;
    FOnSelectionChange: TNotifyEvent;
    FOnElementDblClick: TSciElementEvent;
    function GetElement(ANumber: Integer): TSciElement;
    function GetElementCount: Integer;
    function GetSelectedNumber: Integer;
    procedure SetColorActinides(AValue: TColor);
    procedure SetColorLanthanides(AValue: TColor);
    procedure SetColorOthers(AValue: TColor);
    procedure SetSelected(AValue: TSciElement);
    procedure SetSelectedNumber(AValue: Integer);
    procedure SetShowDetails(AValue: Boolean);
    procedure MoveSelection(DCol, DRow: Integer);
    function BackColor: TColor;
    function ElementColor(E: TSciElement): TColor;
    function CellLeft(ACol: Integer): Integer;
    function CellTop(ARow: Integer): Integer;
    function CellRect(ACol, ARow: Integer): TRect;
    procedure DrawElement(E: TSciElement; const ARect: TRect);
    procedure DrawDetails;
  protected
    class function GetControlClassDefaultSize: TSize; override;
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure DblClick; override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure DoSelectionChange; virtual;
  public
    constructor Create(AOwner: TComponent); override;
    { Copies the appearance (colors, font, ShowDetails) and the selection }
    procedure Assign(Source: TPersistent); override;
    { Element by atomic number (1..ElementCount) }
    property Elements[ANumber: Integer]: TSciElement read GetElement;
    property ElementCount: Integer read GetElementCount;
    { Case-insensitive search by symbol, e.g. 'Fe'. Returns nil if not found. }
    function FindElement(const ASymbol: string): TSciElement;
    { Element drawn at a (0-based) table cell, or nil for an empty cell }
    function ElementAt(ACol, ARow: Integer): TSciElement;
    { Element drawn at a client-area position, or nil }
    function ElementAtPos(X, Y: Integer): TSciElement;
    property Selected: TSciElement read FSelected write SetSelected;
  published
    property SelectedNumber: Integer read GetSelectedNumber write SetSelectedNumber default 1;
    property ShowDetails: Boolean read FShowDetails write SetShowDetails default True;
    property ColorLanthanides: TColor read FColorLanthanides write SetColorLanthanides default DefaultColorLanthanides;
    property ColorActinides: TColor read FColorActinides write SetColorActinides default DefaultColorActinides;
    property ColorOthers: TColor read FColorOthers write SetColorOthers default DefaultColorOthers;
    property OnSelectionChange: TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
    property OnElementDblClick: TSciElementEvent read FOnElementDblClick write FOnElementDblClick;
    // Inherited
    property Align;
    property Anchors;
    property BorderSpacing;
    property Color default clWindow;
    property Constraints;
    property Enabled;
    property Font;
    property ParentColor;
    property ParentFont;
    property PopupMenu;
    property ShowHint;
    property TabOrder;
    property TabStop default True;
    property Visible;
    property OnClick;
    property OnEnter;
    property OnExit;
    property OnResize;
  end;

implementation

const
  ElementsResourceName = 'SCIPERIODICTABLE_ELEMENTS';

{ Shared element data: parsed once from the resource, used by all tables }

var
  GElements: TObjectList = nil;
  GGrid: array[0..SciPTColCount - 1, 0..SciPTRowCount - 1] of TSciElement;

procedure LoadElements;
var
  Lines, Fields: TStringList;
  Res: TLResource;
  FS: TFormatSettings;
  I: Integer;
  E: TSciElement;

  // Empty field -> -1 (unknown). The CSV always uses '.' as decimal separator.
  function FloatField(AIndex: Integer): Double;
  begin
    if Trim(Fields[AIndex]) = '' then
      Result := -1
    else
      Result := StrToFloat(Trim(Fields[AIndex]), FS);
  end;

begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

  Lines := TStringList.Create;
  Fields := TStringList.Create;
  try
    Fields.Delimiter := ',';
    Fields.StrictDelimiter := True;

    Res := LazarusResources.Find(ElementsResourceName);
    if Res = nil then
      raise Exception.Create('TSciPeriodicTable: element data resource not found');
    Lines.Text := Res.Value;

    // Columns: Z,Symbol,Element,Group,Period,AtomicMass,Density,Melt,Boil,Heat,Phase
    for I := 1 to Lines.Count - 1 do // line 0 is the header
    begin
      if Trim(Lines[I]) = '' then
        Continue;
      Fields.DelimitedText := Lines[I];
      if Fields.Count < 11 then
        raise Exception.CreateFmt('TSciPeriodicTable: invalid element data (line %d)', [I + 1]);

      E := TSciElement.Create;
      GElements.Add(E);
      E.FNumber := StrToInt(Fields[0]);
      E.FSymbol := Fields[1];
      E.FName := Fields[2];
      E.FCol := StrToInt(Fields[3]) - 1;
      E.FRow := StrToInt(Fields[4]) - 1;
      E.FWeight := FloatField(5);
      E.FDensity := FloatField(6);
      E.FMeltingPoint := FloatField(7);
      E.FBoilingPoint := FloatField(8);
      E.FSpecificHeat := FloatField(9);
      E.FPhase := Fields[10];

      if (E.FNumber <> GElements.Count) or
         (E.FCol < 0) or (E.FCol >= SciPTColCount) or
         (E.FRow < 0) or (E.FRow >= SciPTRowCount) or
         (GGrid[E.FCol, E.FRow] <> nil) then
        raise Exception.CreateFmt('TSciPeriodicTable: invalid element data (line %d)', [I + 1]);
      GGrid[E.FCol, E.FRow] := E;
    end;
  finally
    Fields.Free;
    Lines.Free;
  end;
end;

procedure EnsureElements;
begin
  if GElements <> nil then
    Exit;
  GElements := TObjectList.Create(True);
  try
    FillChar(GGrid, SizeOf(GGrid), 0);
    LoadElements;
  except
    FreeAndNil(GElements); // so the next table retries instead of using half the data
    raise;
  end;
end;

{ TSciPeriodicTable }

constructor TSciPeriodicTable.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  with GetControlClassDefaultSize do
    SetInitialBounds(0, 0, CX, CY);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  TabStop := True;
  Color := clWindow;
  FShowDetails := True;
  FColorLanthanides := DefaultColorLanthanides;
  FColorActinides := DefaultColorActinides;
  FColorOthers := DefaultColorOthers;
  EnsureElements;
  FSelected := Elements[1];
end;

procedure TSciPeriodicTable.Assign(Source: TPersistent);
var
  Src: TSciPeriodicTable;
begin
  if Source is TSciPeriodicTable then
  begin
    Src := TSciPeriodicTable(Source);
    if not Src.ParentColor then
      Color := Src.Color;
    if not Src.ParentFont then
      Font.Assign(Src.Font);
    FShowDetails := Src.FShowDetails;
    FColorLanthanides := Src.FColorLanthanides;
    FColorActinides := Src.FColorActinides;
    FColorOthers := Src.FColorOthers;
    FSelected := Src.FSelected;
    Invalidate;
  end
  else
    inherited Assign(Source);
end;

class function TSciPeriodicTable.GetControlClassDefaultSize: TSize;
begin
  Result.CX := 576;
  Result.CY := 400;
end;

{ Properties }

function TSciPeriodicTable.GetElement(ANumber: Integer): TSciElement;
begin
  if (ANumber < 1) or (ANumber > GElements.Count) then
    raise Exception.CreateFmt('TSciPeriodicTable: invalid atomic number %d', [ANumber]);
  Result := TSciElement(GElements[ANumber - 1]);
end;

function TSciPeriodicTable.GetElementCount: Integer;
begin
  Result := GElements.Count;
end;

function TSciPeriodicTable.GetSelectedNumber: Integer;
begin
  if FSelected = nil then
    Result := 0
  else
    Result := FSelected.Number;
end;

procedure TSciPeriodicTable.SetSelectedNumber(AValue: Integer);
begin
  if (AValue >= 1) and (AValue <= GElements.Count) then
    SetSelected(Elements[AValue]);
end;

procedure TSciPeriodicTable.SetSelected(AValue: TSciElement);
begin
  if (AValue = nil) or (AValue = FSelected) or (GElements.IndexOf(AValue) < 0) then
    Exit;
  FSelected := AValue;
  Invalidate;
  DoSelectionChange;
end;

procedure TSciPeriodicTable.SetShowDetails(AValue: Boolean);
begin
  if FShowDetails = AValue then Exit;
  FShowDetails := AValue;
  Invalidate;
end;

procedure TSciPeriodicTable.SetColorLanthanides(AValue: TColor);
begin
  if FColorLanthanides = AValue then Exit;
  FColorLanthanides := AValue;
  Invalidate;
end;

procedure TSciPeriodicTable.SetColorActinides(AValue: TColor);
begin
  if FColorActinides = AValue then Exit;
  FColorActinides := AValue;
  Invalidate;
end;

procedure TSciPeriodicTable.SetColorOthers(AValue: TColor);
begin
  if FColorOthers = AValue then Exit;
  FColorOthers := AValue;
  Invalidate;
end;

{ Lookup }

function TSciPeriodicTable.FindElement(const ASymbol: string): TSciElement;
var
  I: Integer;
begin
  for I := 0 to GElements.Count - 1 do
  begin
    Result := TSciElement(GElements[I]);
    if SameText(Result.Symbol, ASymbol) then
      Exit;
  end;
  Result := nil;
end;

function TSciPeriodicTable.ElementAt(ACol, ARow: Integer): TSciElement;
begin
  if (ACol < 0) or (ACol >= SciPTColCount) or (ARow < 0) or (ARow >= SciPTRowCount) then
    Result := nil
  else
    Result := GGrid[ACol, ARow];
end;

function TSciPeriodicTable.ElementAtPos(X, Y: Integer): TSciElement;
begin
  Result := nil;
  if (ClientWidth <= 0) or (ClientHeight <= 0) or
     (X < 0) or (Y < 0) or (X >= ClientWidth) or (Y >= ClientHeight) then
    Exit;
  // Exact inverse of CellLeft/CellTop
  Result := GGrid[X * SciPTColCount div ClientWidth, Y * SciPTRowCount div ClientHeight];
end;

{ Geometry: the cell boundaries are computed from the client size so the
  18 x 10 cells always fill the control without gaps. }

function TSciPeriodicTable.CellLeft(ACol: Integer): Integer;
begin
  Result := (ACol * ClientWidth + SciPTColCount - 1) div SciPTColCount;
end;

function TSciPeriodicTable.CellTop(ARow: Integer): Integer;
begin
  Result := (ARow * ClientHeight + SciPTRowCount - 1) div SciPTRowCount;
end;

function TSciPeriodicTable.CellRect(ACol, ARow: Integer): TRect;
begin
  Result := Rect(CellLeft(ACol), CellTop(ARow), CellLeft(ACol + 1), CellTop(ARow + 1));
end;

{ Painting }

function TSciPeriodicTable.BackColor: TColor;
begin
  if Color = clDefault then
    Result := clWindow
  else
    Result := Color;
end;

function TSciPeriodicTable.ElementColor(E: TSciElement): TColor;
begin
  case E.Number of
    57..71:   Result := FColorLanthanides;
    89..103:  Result := FColorActinides;
  else
    Result := FColorOthers;
  end;
end;

procedure TSciPeriodicTable.Paint;
var
  C, R: Integer;
  E: TSciElement;
begin
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := BackColor;
  Canvas.FillRect(0, 0, ClientWidth, ClientHeight);

  for C := 0 to SciPTColCount - 1 do
    for R := 0 to SciPTRowCount - 1 do
    begin
      E := GGrid[C, R];
      if E <> nil then
        DrawElement(E, CellRect(C, R));
    end;

  if FShowDetails and (FSelected <> nil) then
    DrawDetails;
end;

procedure TSciPeriodicTable.DrawElement(E: TSciElement; const ARect: TRect);
var
  CW, CH, SymH, TextX, TextY: Integer;
begin
  CW := ARect.Right - ARect.Left;
  CH := ARect.Bottom - ARect.Top;

  Canvas.Font.Assign(Font);
  Canvas.Brush.Style := bsSolid;
  if E = FSelected then
  begin
    Canvas.Brush.Color := clHighlight;
    Canvas.Font.Color := clHighlightText;
  end
  else
    Canvas.Brush.Color := ElementColor(E);
  Canvas.FillRect(ARect);
  Canvas.Brush.Style := bsClear;

  // Atomic number, top-left
  Canvas.Font.Style := [];
  Canvas.Font.Height := -Max(6, Round(CH * 0.22));
  Canvas.TextOut(ARect.Left + 2, ARect.Top + 2, IntToStr(E.Number));

  // Symbol, bold, shrunk if it does not fit the cell width (e.g. 'Uuo')
  Canvas.Font.Style := [fsBold];
  SymH := Max(6, Round(CH * 0.4));
  repeat
    Canvas.Font.Height := -SymH;
    if (Canvas.TextWidth(E.Symbol) <= CW - 2) or (SymH <= 6) then
      Break;
    Dec(SymH);
  until False;

  TextX := ARect.Left + (CW - Canvas.TextWidth(E.Symbol)) div 2;
  TextY := ARect.Top + 2 * (CH - Canvas.TextHeight(E.Symbol)) div 3;
  Canvas.TextOut(TextX, TextY, E.Symbol);
end;

{ The details are drawn in the empty block of the table (groups 3-12,
  periods 1-3), as the old form's panel did. }
procedure TSciPeriodicTable.DrawDetails;
var
  R: TRect;
  FH, X, Y, LineH, SymW, SymH, NameH: Integer;

  procedure TextLine(const S: string);
  begin
    Canvas.TextOut(X, Y, S);
    Inc(Y, LineH);
  end;

var
  DensityText: string;
begin
  R := Rect(CellLeft(2), CellTop(0), CellLeft(12), CellTop(3));
  FH := Max(8, Min(Round((CellTop(1) - CellTop(0)) * 0.28),
                   Round((CellLeft(1) - CellLeft(0)) * 0.5)));
  X := R.Left + FH div 2;
  Y := R.Top + FH div 2;

  Canvas.Font.Assign(Font);
  Canvas.Brush.Style := bsClear;

  Canvas.Font.Style := [fsBold];
  Canvas.Font.Height := -FH * 2;
  SymW := Canvas.TextWidth(FSelected.Symbol);
  SymH := Canvas.TextHeight(FSelected.Symbol);
  Canvas.TextOut(X, Y, FSelected.Symbol);

  Canvas.Font.Style := [];
  Canvas.Font.Height := -Round(FH * 1.3);
  NameH := Canvas.TextHeight(FSelected.Name);
  Canvas.TextOut(X + SymW + FH, Y + (SymH - NameH) div 2, FSelected.Name);

  Canvas.Font.Height := -FH;
  LineH := Canvas.TextHeight('Ag') + FH div 4;
  Inc(Y, SymH + FH div 3);

  if FSelected.Density < 0 then
    DensityText := 'n/a'
  else
    DensityText := FloatToStr(FSelected.Density) + ' g/cm3';

  TextLine('Atomic Number: ' + IntToStr(FSelected.Number));
  TextLine('Atomic Weight: ' + FloatToStr(FSelected.Weight));
  TextLine('Phase: ' + FSelected.Phase);
  TextLine('Density: ' + DensityText);
end;

procedure TSciPeriodicTable.Resize;
begin
  inherited Resize;
  Invalidate;
end;

{ Interaction }

procedure TSciPeriodicTable.MouseDown(Button: TMouseButton; Shift: TShiftState;
  X, Y: Integer);
var
  E: TSciElement;
begin
  inherited MouseDown(Button, Shift, X, Y);
  if CanFocus then
    SetFocus;
  if Button = mbLeft then
  begin
    E := ElementAtPos(X, Y);
    if E <> nil then
      SetSelected(E);
  end;
end;

procedure TSciPeriodicTable.DblClick;
var
  P: TPoint;
  E: TSciElement;
begin
  inherited DblClick;
  P := ScreenToClient(Mouse.CursorPos);
  E := ElementAtPos(P.X, P.Y);
  if (E <> nil) and Assigned(FOnElementDblClick) then
    FOnElementDblClick(Self, E);
end;

procedure TSciPeriodicTable.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  case Key of
    VK_LEFT:  MoveSelection(-1, 0);
    VK_RIGHT: MoveSelection(1, 0);
    VK_UP:    MoveSelection(0, -1);
    VK_DOWN:  MoveSelection(0, 1);
  else
    Exit;
  end;
  Key := 0;
end;

{ Moves to the next element in the given direction, skipping empty cells }
procedure TSciPeriodicTable.MoveSelection(DCol, DRow: Integer);
var
  C, R: Integer;
  E: TSciElement;
begin
  if FSelected = nil then
    Exit;
  C := FSelected.FCol;
  R := FSelected.FRow;
  repeat
    Inc(C, DCol);
    Inc(R, DRow);
    E := ElementAt(C, R);
    if (C < 0) or (C >= SciPTColCount) or (R < 0) or (R >= SciPTRowCount) then
      Exit;
  until E <> nil;
  SetSelected(E);
end;

procedure TSciPeriodicTable.DoSelectionChange;
begin
  if Assigned(FOnSelectionChange) then
    FOnSelectionChange(Self);
end;

initialization
  {$I sciperiodictable_elements.lrs}

finalization
  FreeAndNil(GElements);

end.
