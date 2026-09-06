unit uSciReader;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, LResources;

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

    FDateSeparator: Char;
    FTimeSeparator: Char;

    FDateTimeLine: Integer;
    FDateTimeCol: Integer;
    FDateTimeLength: Integer;
    FDateTimeFormat: String;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
    function IsEqual(Other: TTXTOptions): Boolean;

    property XCol: Integer read FXCol write FXCol;
    property XLbl: String read FXLbl write FXLbl;
    property YCol: Integer read FYCol write FYCol;
    property YLbl: String read FYLbl write FYLbl;
    property DateSeparator: Char read FDateSeparator write FDateSeparator;
    property TimeSeparator: Char read FTimeSeparator write FTimeSeparator;
    property DateTimeLine: Integer read FDateTimeLine write FDateTimeLine;
    property DateTimeCol: Integer read FDateTimeCol write FDateTimeCol;
    property DateTimeLength: Integer read FDateTimeLength write FDateTimeLength;
    property DateTimeFormat: String read FDateTimeFormat write FDateTimeFormat;
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

    function GetCell(ACol, ARow: Integer): String;
    function GetValue(ACol, ARow: Integer): Double;
    function GetColCount(ARow: Integer): Integer;
    function GetHasErrors: Boolean;

    procedure SetOptions(Value: TTXTOptions);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadFromFile(const AFileName: String);
    procedure LoadFromString(const AString: String);
    procedure Clear;

    function FileDate: TDateTime;

    property Cells[ACol, ARow: Integer]: String read GetCell; default;
    property Value[ACol, ARow: Integer]: Double read GetValue;
    property ColCount[ARow: Integer]: Integer read GetColCount;
    property RowCount: Integer read FRowCount;
    property MaxColCount: Integer read FMaxColCount;

    property Errors: TStringList read FErrors;
    property HasErrors: Boolean read GetHasErrors;
  published
    property Options: TTXTOptions read FOptions write SetOptions;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Science', [TSciReader]);
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
  FDateSeparator := '/';
  FTimeSeparator := ':';
  FDateTimeLine := 0;
  FDateTimeCol := 0;
  FDateTimeLength := 0;
  FDateTimeFormat := 'dd/mm/yyyy, hh:nn:ss';
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
    FDateSeparator := Src.FDateSeparator;
    FTimeSeparator := Src.FTimeSeparator;
    FDateTimeLine := Src.FDateTimeLine;
    FDateTimeCol := Src.FDateTimeCol;
    FDateTimeLength := Src.FDateTimeLength;
    FDateTimeFormat := Src.FDateTimeFormat;
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
            (FDateSeparator = Other.FDateSeparator) and
            (FTimeSeparator = Other.FTimeSeparator) and
            (FDateTimeLine = Other.FDateTimeLine) and
            (FDateTimeCol = Other.FDateTimeCol) and
            (FDateTimeLength = Other.FDateTimeLength) and
            (FDateTimeFormat = Other.FDateTimeFormat);
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
end;

function TSciReader.FileDate: TDateTime;
var
  ValueStr: String;
  FS: TFormatSettings;
begin
  Result := 0;

  if (FOptions.DateTimeLength <= 0) or (Trim(FOptions.DateTimeFormat) = '') then Exit;
  if (FOptions.DateTimeLine < 0) or (FOptions.DateTimeLine >= FLines.Count) then Exit;

  ValueStr := Copy(FLines[FOptions.DateTimeLine], FOptions.DateTimeCol + 1, FOptions.DateTimeLength);
  if Trim(ValueStr) = '' then Exit;

  FS := DefaultFormatSettings;
  FS.DateSeparator := FOptions.DateSeparator;
  FS.TimeSeparator := FOptions.TimeSeparator;

  try
    Result := ScanDateTime(FOptions.DateTimeFormat, ValueStr, FS);
  except
    Result := 0;
  end;
end;

initialization
  {$I LazScience.lrs}
end.
