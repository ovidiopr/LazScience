unit uSciReader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, Math, LResources, uFormula;

type
  TTXTOptions = class(TPersistent)
  private
    FDelimiter: Char;
    FComment: Char;
    FQuotation: Char;
    FHeaderLines: Integer;
    FDecimal: Char;
    FThousand: Char;

    FXCol: Integer;
    FXLbl: String;
    FYCol: Integer;
    FYLbl: String;
    FXFormula: String;
    FYFormula: String;

    FDateSeparator: Char;
    FTimeSeparator: Char;

    FDateTimeLine: Integer;
    FDateTimeCol: Integer;
    FDateTimeLength: Integer;
    FDateTimeFormat: String;
    FFileDateFallback: Boolean;
    FHeaderVars: TStringList;
    FSkipInvalidRows: Boolean;

    procedure SetHeaderVars(Value: TStrings);
    function GetHeaderVars: TStrings;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;
    function IsEqual(Other: TTXTOptions): Boolean;

    property XCol: Integer read FXCol write FXCol;
    property XLbl: String read FXLbl write FXLbl;
    property YCol: Integer read FYCol write FYCol;
    property YLbl: String read FYLbl write FYLbl;
    property XFormula: String read FXFormula write FXFormula;
    property YFormula: String read FYFormula write FYFormula;
    property DateSeparator: Char read FDateSeparator write FDateSeparator;
    property TimeSeparator: Char read FTimeSeparator write FTimeSeparator;
    property DateTimeLine: Integer read FDateTimeLine write FDateTimeLine;
    property DateTimeCol: Integer read FDateTimeCol write FDateTimeCol;
    property DateTimeLength: Integer read FDateTimeLength write FDateTimeLength;
    property DateTimeFormat: String read FDateTimeFormat write FDateTimeFormat;
    // Use the file modification time when no date is set or found in the file
    property FileDateFallback: Boolean read FFileDateFallback write FFileDateFallback;
    // Name=Text pairs: the number after Text in the file is the variable Name
    property HeaderVars: TStrings read GetHeaderVars write SetHeaderVars;
    // Drop rows whose X or Y is not a number (text, blank or invalid result)
    property SkipInvalidRows: Boolean read FSkipInvalidRows write FSkipInvalidRows;
  published
    property Delimiter: Char read FDelimiter write FDelimiter default ' ';
    property Comment: Char read FComment write FComment default '#';
    property Quotation: Char read FQuotation write FQuotation default #0;
    property HeaderLines: Integer read FHeaderLines write FHeaderLines default 0;
    property Decimal: Char read FDecimal write FDecimal default '.';
    property Thousand: Char read FThousand write FThousand default #0;
  end;

  TSciReader = class(TComponent)
  private
    FData: array of array of String;
    FRowCount: Integer;
    FMaxColCount: Integer;
    FOptions: TTXTOptions;
    FLines: TStringList;
    FErrors: TStringList;
    FSourceFileName: String;
    FHeaderNames: TStringArray;
    FHeaderValues: TDoubleArray;

    FXFormulaObj: TFormula;
    FYFormulaObj: TFormula;
    FXErrorShown: Boolean;
    FYErrorShown: Boolean;

    function GetCell(ACol, ARow: Integer): String;
    function GetValue(ACol, ARow: Integer): Double;
    function GetColCount(ARow: Integer): Integer;
    function GetHasErrors: Boolean;
    function GetX(ARow: Integer): Double;
    function GetY(ARow: Integer): Double;

    function BuildColumnNames(ColCount: Integer; const ExtraNames: array of String): TStringArray;
    function EnsureXFormula: TFormula;
    function EnsureYFormula: TFormula;
    function YExtraNames: TStringArray;
    function FindHeaderNumber(const Key: String; out V: Double): Boolean;
    procedure ComputeHeaderValues;
    function CellIsNumber(ACol, ARow: Integer): Boolean;
    procedure RemoveInvalidRows;
    function GetHeaderCount: Integer;
    function GetHeaderName(Index: Integer): String;
    function GetHeaderValue(Index: Integer): Double;

    procedure SetOptions(Value: TTXTOptions);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: String);
    procedure LoadFromString(const AString: String);
    procedure Clear;

    function FileDate: TDateTime;
    // True if X and Y of the row come from numbers and are finite
    function RowIsValid(ARow: Integer): Boolean;
    // Header value by name, or ADefault when it is not defined
    function HeaderValueByName(const AName: String; ADefault: Double = 0.0): Double;

    property Cells[ACol, ARow: Integer]: String read GetCell; default;
    property Value[ACol, ARow: Integer]: Double read GetValue;
    property ColCount[ARow: Integer]: Integer read GetColCount;
    property RowCount: Integer read FRowCount;
    property MaxColCount: Integer read FMaxColCount;

    property X[ARow: Integer]: Double read GetX;
    property Y[ARow: Integer]: Double read GetY;

    property Errors: TStringList read FErrors;
    property HasErrors: Boolean read GetHasErrors;
    // File the text came from; used by FileDate when FileDateFallback is set
    property SourceFileName: String read FSourceFileName write FSourceFileName;
    // Header values found in the last loaded text (see TTXTOptions.HeaderVars)
    property HeaderCount: Integer read GetHeaderCount;
    property HeaderNames[Index: Integer]: String read GetHeaderName;
    property HeaderValues[Index: Integer]: Double read GetHeaderValue;
  published
    property Options: TTXTOptions read FOptions write SetOptions;
  end;

function ColumnLetter(ColIndex: Integer): String;
// Header value names must not clash with column names or formula variables
function IsValidHeaderName(const AName: String): Boolean;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Science', [TSciReader]);
end;

function ColumnLetter(ColIndex: Integer): String;
const
  Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWZ'; // 24 letters - X and Y are skipped
var
  N: Integer;
begin
  if (ColIndex >= 0) and (ColIndex < Length(Alphabet)) then
    Result := Alphabet[ColIndex + 1]
  else if ColIndex >= 0 then
  begin
    N := ColIndex - Length(Alphabet);
    Result := Alphabet[(N div Length(Alphabet)) + 1] + Alphabet[(N mod Length(Alphabet)) + 1];
  end
  else
    Result := '';
end;

function IsValidHeaderName(const AName: String): Boolean;
const
  Reserved: array [0..4] of String = ('X', 'Y', 'I', 'N', 'PI');
var
  i: Integer;
  U: String;
  AllLetters: Boolean;
begin
  Result := False;
  U := UpperCase(Trim(AName));
  if (U = '') or not (U[1] in ['A'..'Z', '_']) then Exit;
  for i := 2 to Length(U) do
    if not (U[i] in ['A'..'Z', '0'..'9', '_']) then Exit;
  for i := Low(Reserved) to High(Reserved) do
    if U = Reserved[i] then Exit;

  // One or two letters could be a column name (A, B, ..., AA, AB, ...)
  AllLetters := True;
  for i := 1 to Length(U) do
    if not (U[i] in ['A'..'Z']) then AllLetters := False;
  if AllLetters and (Length(U) <= 2) then Exit;

  Result := True;
end;

{ TTXTOptions }

constructor TTXTOptions.Create;
begin
  inherited Create;
  FDelimiter := ' ';
  FComment := '#';
  FQuotation := #0;
  FHeaderLines := 0;
  FDecimal := '.';
  FThousand := #0;
  FXCol := 0;
  FXLbl := 'X';
  FYCol := 1;
  FYLbl := 'Y';
  FXFormula := '';
  FYFormula := '';
  FDateSeparator := '/';
  FTimeSeparator := ':';
  FDateTimeLine := 0;
  FDateTimeCol := 0;
  FDateTimeLength := 0;
  FDateTimeFormat := 'dd/mm/yyyy, hh:nn:ss';
  FFileDateFallback := True;
  FHeaderVars := TStringList.Create;
  FSkipInvalidRows := False;
end;

destructor TTXTOptions.Destroy;
begin
  FreeAndNil(FHeaderVars);
  inherited Destroy;
end;

procedure TTXTOptions.SetHeaderVars(Value: TStrings);
begin
  FHeaderVars.Assign(Value);
end;

function TTXTOptions.GetHeaderVars: TStrings;
begin
  Result := FHeaderVars;
end;

procedure TTXTOptions.Assign(Source: TPersistent);
var
  Src: TTXTOptions;
begin
  if Source is TTXTOptions then
  begin
    Src := TTXTOptions(Source);
    FDelimiter := Src.FDelimiter;
    FComment := Src.FComment;
    FQuotation := Src.FQuotation;
    FHeaderLines := Src.FHeaderLines;
    FDecimal := Src.FDecimal;
    FThousand := Src.FThousand;
    FXCol := Src.FXCol;
    FXLbl := Src.FXLbl;
    FYCol := Src.FYCol;
    FYLbl := Src.FYLbl;
    FXFormula := Src.FXFormula;
    FYFormula := Src.FYFormula;
    FDateSeparator := Src.FDateSeparator;
    FTimeSeparator := Src.FTimeSeparator;
    FDateTimeLine := Src.FDateTimeLine;
    FDateTimeCol := Src.FDateTimeCol;
    FDateTimeLength := Src.FDateTimeLength;
    FDateTimeFormat := Src.FDateTimeFormat;
    FFileDateFallback := Src.FFileDateFallback;
    FHeaderVars.Assign(Src.FHeaderVars);
    FSkipInvalidRows := Src.FSkipInvalidRows;
  end
  else
    inherited Assign(Source);
end;

function TTXTOptions.IsEqual(Other: TTXTOptions): Boolean;
begin
  Result := Assigned(Other) and
            (FDelimiter = Other.FDelimiter) and
            (FComment = Other.FComment) and
            (FQuotation = Other.FQuotation) and
            (FHeaderLines = Other.FHeaderLines) and
            (FDecimal = Other.FDecimal) and
            (FThousand = Other.FThousand) and
            (FXCol = Other.FXCol) and
            (FXLbl = Other.FXLbl) and
            (FYCol = Other.FYCol) and
            (FYLbl = Other.FYLbl) and
            (FXFormula = Other.FXFormula) and
            (FYFormula = Other.FYFormula) and
            (FDateSeparator = Other.FDateSeparator) and
            (FTimeSeparator = Other.FTimeSeparator) and
            (FDateTimeLine = Other.FDateTimeLine) and
            (FDateTimeCol = Other.FDateTimeCol) and
            (FDateTimeLength = Other.FDateTimeLength) and
            (FDateTimeFormat = Other.FDateTimeFormat) and
            (FFileDateFallback = Other.FFileDateFallback) and
            (FHeaderVars.Text = Other.FHeaderVars.Text) and
            (FSkipInvalidRows = Other.FSkipInvalidRows);
end;

{ TSciReader }

constructor TSciReader.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FOptions := TTXTOptions.Create;
  FErrors := TStringList.Create;
  FLines := TStringList.Create;
  Clear;
end;

destructor TSciReader.Destroy;
begin
  FreeAndNil(FXFormulaObj);
  FreeAndNil(FYFormulaObj);
  FreeAndNil(FErrors);
  FreeAndNil(FLines);
  FreeAndNil(FOptions);
  inherited Destroy;
end;

procedure TSciReader.SetOptions(Value: TTXTOptions);
begin
  if Assigned(Value) then
    FOptions.Assign(Value);
end;

procedure TSciReader.Clear;
begin
  SetLength(FData, 0);
  FRowCount := 0;
  FMaxColCount := 0;
  FLines.Clear;
  FErrors.Clear;
  FSourceFileName := '';
  SetLength(FHeaderNames, 0);
  SetLength(FHeaderValues, 0);
  // Recompile formulas on every load
  FreeAndNil(FXFormulaObj);
  FreeAndNil(FYFormulaObj);
  FXErrorShown := False;
  FYErrorShown := False;
end;

function TSciReader.GetHasErrors: Boolean;
begin
  Result := FErrors.Count > 0;
end;

function TSciReader.GetCell(ACol, ARow: Integer): String;
begin
  if (ARow >= 0) and (ARow < FRowCount) and (ACol >= 0) and (ACol < Length(FData[ARow])) then
    Result := FData[ARow][ACol]
  else
    Result := '';
end;

function TSciReader.GetValue(ACol, ARow: Integer): Double;
var
  CellStr: String;
  FS: TFormatSettings;
begin
  CellStr := Trim(GetCell(ACol, ARow));

  if CellStr = '' then
    Exit(0.0);

  // Initialize custom format settings to override the system defaults
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := FOptions.Decimal;
  FS.ThousandSeparator := FOptions.Thousand;

  Result := StrToFloatDef(CellStr, 0.0, FS);
end;

function TSciReader.GetColCount(ARow: Integer): Integer;
begin
  if (ARow >= 0) and (ARow < FRowCount) then
    Result := Length(FData[ARow])
  else
    Result := 0;
end;

function TSciReader.BuildColumnNames(ColCount: Integer; const ExtraNames: array of String): TStringArray;
var
  i: Integer;
begin
  SetLength(Result, ColCount + Length(ExtraNames));
  for i := 0 to ColCount - 1 do
    Result[i] := ColumnLetter(i);
  for i := 0 to High(ExtraNames) do
    Result[ColCount + i] := ExtraNames[i];
end;

function TSciReader.EnsureXFormula: TFormula;
begin
  if not Assigned(FXFormulaObj) then
    FXFormulaObj := TFormula.Create(FOptions.XFormula, BuildColumnNames(FMaxColCount, FHeaderNames), FOptions.Decimal, FOptions.Thousand);
  Result := FXFormulaObj;
end;

function TSciReader.EnsureYFormula: TFormula;
begin
  if not Assigned(FYFormulaObj) then
    FYFormulaObj := TFormula.Create(FOptions.YFormula, BuildColumnNames(FMaxColCount, YExtraNames), FOptions.Decimal, FOptions.Thousand);
  Result := FYFormulaObj;
end;

// Extra Y formula variables: X, then the header values
function TSciReader.YExtraNames: TStringArray;
var
  i: Integer;
begin
  SetLength(Result, Length(FHeaderNames) + 1);
  Result[0] := 'X';
  for i := 0 to High(FHeaderNames) do
    Result[i + 1] := FHeaderNames[i];
end;

function TSciReader.GetX(ARow: Integer): Double;
var
  F: TFormula;
  Names: TStringArray;
  Values: TDoubleArray;
  i, ColN, H: Integer;
begin
  if Trim(FOptions.XFormula) = '' then
  begin
    Result := GetValue(FOptions.XCol, ARow); // legacy column-index behavior
    Exit;
  end;

  F := EnsureXFormula;
  if not F.Valid then
  begin
    // Report once per load, not once per row
    if not FXErrorShown then
      FErrors.Add('X Formula error: ' + F.ErrorMessage);
    FXErrorShown := True;
    Result := 0.0;
    Exit;
  end;

  // Columns, then header values
  ColN := GetColCount(ARow);
  H := Length(FHeaderNames);
  SetLength(Names, ColN + H);
  SetLength(Values, ColN + H);
  for i := 0 to ColN - 1 do
  begin
    Names[i] := ColumnLetter(i);
    Values[i] := GetValue(i, ARow);
  end;
  for i := 0 to H - 1 do
  begin
    Names[ColN + i] := FHeaderNames[i];
    Values[ColN + i] := FHeaderValues[i];
  end;

  Result := F.Evaluate(Names, Values);
end;

function TSciReader.GetY(ARow: Integer): Double;
var
  F: TFormula;
  Names: TStringArray;
  Values: TDoubleArray;
  i, ColN, H: Integer;
begin
  if Trim(FOptions.YFormula) = '' then
  begin
    Result := GetValue(FOptions.YCol, ARow); // legacy column-index behavior
    Exit;
  end;

  F := EnsureYFormula;
  if not F.Valid then
  begin
    // Report once per load, not once per row
    if not FYErrorShown then
      FErrors.Add('Y Formula error: ' + F.ErrorMessage);
    FYErrorShown := True;
    Result := 0.0;
    Exit;
  end;

  // Columns, X (always available to the Y formula), then header values
  ColN := GetColCount(ARow);
  H := Length(FHeaderNames);
  SetLength(Names, ColN + 1 + H);
  SetLength(Values, ColN + 1 + H);
  for i := 0 to ColN - 1 do
  begin
    Names[i] := ColumnLetter(i);
    Values[i] := GetValue(i, ARow);
  end;
  Names[ColN] := 'X';
  Values[ColN] := GetX(ARow);
  for i := 0 to H - 1 do
  begin
    Names[ColN + 1 + i] := FHeaderNames[i];
    Values[ColN + 1 + i] := FHeaderValues[i];
  end;

  Result := F.Evaluate(Names, Values);
end;

procedure TSciReader.LoadFromFile(const AFileName: String);
var
  sl: TStringStream;
begin
  if not FileExists(AFileName) then
  begin
    Clear;
    FErrors.Add(Format('File not found: %s', [AFileName]));
    Exit;
  end;

  sl := TStringStream.Create('');
  try
    try
      sl.LoadFromFile(AFileName);
      LoadFromString(sl.DataString);
      FSourceFileName := AFileName;
    except
      on E: Exception do
      begin
        Clear;
        FErrors.Add(Format('Could not read "%s": %s', [AFileName, E.Message]));
      end;
    end;
  finally
    sl.Free;
  end;
end;

procedure TSciReader.LoadFromString(const AString: String);
var
  CellList: TStringList;
  LineIdx, ColIdx, SkipCount: Integer;
  Line, TrimmedLine: String;
begin
  Clear;
  FLines.Text := AString; // splits on CRLF/LF/CR uniformly
  if AString = '' then Exit;

  CellList := TStringList.Create;
  try
    CellList.StrictDelimiter := True;

    SetLength(FData, FLines.Count); // upper bound; trimmed to FRowCount below
    FRowCount := 0;
    SkipCount := FOptions.HeaderLines;

    for LineIdx := 0 to FLines.Count - 1 do
    begin
      Line := FLines[LineIdx];

      if SkipCount > 0 then
      begin
        Dec(SkipCount);
        Continue;
      end;

      TrimmedLine := TrimLeft(Line);
      if (FOptions.Comment <> #0) and (TrimmedLine <> '') and (TrimmedLine[1] = FOptions.Comment) then
        Continue; // comment lines are not shown as data rows

      try
        CellList.Delimiter := FOptions.Delimiter;
        CellList.QuoteChar := FOptions.Quotation; // #0 effectively disables quoting

        CellList.DelimitedText := Line;

        if CellList.Count = 0 then
        begin
          SetLength(FData[FRowCount], 1);
          FData[FRowCount][0] := '';
        end
        else
        begin
          SetLength(FData[FRowCount], CellList.Count);
          for ColIdx := 0 to CellList.Count - 1 do
            FData[FRowCount][ColIdx] := CellList[ColIdx];
        end;

        if CellList.Count > FMaxColCount then FMaxColCount := CellList.Count;
      except
        on E: Exception do
        begin
          // Whatever went wrong, keep the whole raw line as a single cell
          SetLength(FData[FRowCount], 1);
          FData[FRowCount][0] := Line;
          if FMaxColCount < 1 then FMaxColCount := 1;
          FErrors.Add(Format('Row %d could not be parsed (%s) - shown as raw text.', [FRowCount, E.Message]));
        end;
      end;

      Inc(FRowCount);
    end;

    SetLength(FData, FRowCount);
  finally
    CellList.Free;
  end;

  ComputeHeaderValues;

  if FOptions.SkipInvalidRows then
    RemoveInvalidRows;
end;

function TSciReader.CellIsNumber(ACol, ARow: Integer): Boolean;
var
  S: String;
  V: Double;
  FS: TFormatSettings;
begin
  S := Trim(GetCell(ACol, ARow));
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := FOptions.Decimal;
  FS.ThousandSeparator := FOptions.Thousand;
  Result := (S <> '') and TryStrToFloat(S, V, FS);
end;

function TSciReader.RowIsValid(ARow: Integer): Boolean;
var
  V: Double;

  // Columns used by the formula must be numbers; a broken formula reports its error instead
  function FormulaColumnsOK(AF: TFormula): Boolean;
  var
    j: Integer;
  begin
    Result := True;
    if not AF.Valid then Exit;
    for j := 0 to FMaxColCount - 1 do
      if AF.UsesVariable(ColumnLetter(j)) and not CellIsNumber(j, ARow) then
        Exit(False);
  end;

begin
  Result := False;
  if (ARow < 0) or (ARow >= FRowCount) then Exit;

  if Trim(FOptions.XFormula) = '' then
  begin
    if not CellIsNumber(FOptions.XCol, ARow) then Exit;
  end
  else if not FormulaColumnsOK(EnsureXFormula) then Exit;

  if Trim(FOptions.YFormula) = '' then
  begin
    if not CellIsNumber(FOptions.YCol, ARow) then Exit;
  end
  else if not FormulaColumnsOK(EnsureYFormula) then Exit;

  V := GetX(ARow);
  if IsNan(V) or IsInfinite(V) then Exit;
  V := GetY(ARow);
  if IsNan(V) or IsInfinite(V) then Exit;

  Result := True;
end;

// Compact FData in place, keeping only the valid rows
procedure TSciReader.RemoveInvalidRows;
var
  i, n: Integer;
begin
  n := 0;
  for i := 0 to FRowCount - 1 do
    if RowIsValid(i) then
    begin
      if n <> i then
        FData[n] := FData[i];
      Inc(n);
    end;
  FRowCount := n;
  SetLength(FData, n);
end;

// First number after Key on the first line that contains Key (case-insensitive)
function TSciReader.FindHeaderNumber(const Key: String; out V: Double): Boolean;
var
  i, p, s: Integer;
  Line, UKey, NumStr: String;
  FS: TFormatSettings;
begin
  Result := False;
  V := 0.0;
  UKey := UpperCase(Trim(Key));
  if UKey = '' then Exit;

  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  FS.ThousandSeparator := #0;

  for i := 0 to FLines.Count - 1 do
  begin
    Line := FLines[i];
    p := Pos(UKey, UpperCase(Line));
    if p = 0 then Continue;

    // Skip to the first character that can start a number
    p := p + Length(UKey);
    while (p <= Length(Line)) and not (Line[p] in ['0'..'9', '+', '-', '.', FOptions.Decimal]) do
      Inc(p);

    s := p;
    if (p <= Length(Line)) and (Line[p] in ['+', '-']) then Inc(p);
    while (p <= Length(Line)) and (Line[p] in ['0'..'9', '.', FOptions.Decimal]) do Inc(p);
    if (p <= Length(Line)) and (Line[p] in ['e', 'E']) then
    begin
      Inc(p);
      if (p <= Length(Line)) and (Line[p] in ['+', '-']) then Inc(p);
      while (p <= Length(Line)) and (Line[p] in ['0'..'9']) do Inc(p);
    end;

    NumStr := Copy(Line, s, p - s);
    if FOptions.Decimal <> '.' then
      NumStr := StringReplace(NumStr, FOptions.Decimal, '.', [rfReplaceAll]);
    Result := TryStrToFloat(NumStr, V, FS);
    if not Result then V := 0.0;
    Exit;
  end;
end;

procedure TSciReader.ComputeHeaderValues;
var
  i, n: Integer;
  AName, AKey: String;
  V: Double;
begin
  SetLength(FHeaderNames, 0);
  SetLength(FHeaderValues, 0);

  for i := 0 to FOptions.HeaderVars.Count - 1 do
  begin
    AName := Trim(FOptions.HeaderVars.Names[i]);
    AKey := FOptions.HeaderVars.ValueFromIndex[i];
    if AName = '' then Continue;

    if not IsValidHeaderName(AName) then
    begin
      FErrors.Add(Format('Header value "%s": invalid name (use 3+ characters or a digit, e.g. T1)', [AName]));
      Continue;
    end;

    // Missing values read as 0 so the formulas still compile
    if not FindHeaderNumber(AKey, V) then
      FErrors.Add(Format('Header value "%s": no number found after "%s"', [AName, AKey]));

    n := Length(FHeaderNames);
    SetLength(FHeaderNames, n + 1);
    SetLength(FHeaderValues, n + 1);
    FHeaderNames[n] := AName;
    FHeaderValues[n] := V;
  end;
end;

function TSciReader.GetHeaderCount: Integer;
begin
  Result := Length(FHeaderNames);
end;

function TSciReader.GetHeaderName(Index: Integer): String;
begin
  if (Index >= 0) and (Index < Length(FHeaderNames)) then
    Result := FHeaderNames[Index]
  else
    Result := '';
end;

function TSciReader.GetHeaderValue(Index: Integer): Double;
begin
  if (Index >= 0) and (Index < Length(FHeaderValues)) then
    Result := FHeaderValues[Index]
  else
    Result := 0.0;
end;

function TSciReader.HeaderValueByName(const AName: String; ADefault: Double = 0.0): Double;
var
  i: Integer;
begin
  Result := ADefault;
  for i := 0 to High(FHeaderNames) do
    if SameText(FHeaderNames[i], AName) then
      Exit(FHeaderValues[i]);
end;

function TSciReader.FileDate: TDateTime;
var
  ValueStr: String;
  FS: TFormatSettings;
  Age: TDateTime;
begin
  Result := 0;

  // Date/time written inside the file, when configured
  if (FOptions.DateTimeLength > 0) and (Trim(FOptions.DateTimeFormat) <> '') and
     (FOptions.DateTimeLine >= 0) and (FOptions.DateTimeLine < FLines.Count) then
  begin
    ValueStr := Copy(FLines[FOptions.DateTimeLine], FOptions.DateTimeCol + 1, FOptions.DateTimeLength);
    if Trim(ValueStr) <> '' then
    begin
      FS := DefaultFormatSettings;
      FS.DateSeparator := FOptions.DateSeparator;
      FS.TimeSeparator := FOptions.TimeSeparator;

      try
        Result := ScanDateTime(FOptions.DateTimeFormat, ValueStr, FS);
      except
        Result := 0;
      end;
    end;
  end;

  // Otherwise the modification time of the file (same call on every platform)
  if (Result = 0) and FOptions.FileDateFallback and (FSourceFileName <> '') then
    if FileAge(FSourceFileName, Age) then
      Result := Age;
end;

initialization
  {$I LazScience.lrs}
end.
