unit uTXTdialog;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, Grids, Buttons, Spin, IniFiles, Menus, uSciReader, Math,
  DividerBevel;

type
  TSciReaderDlgOption = (srdDateTimeReading, srdAutoSaveConfig, srdShowFormulas);
  TSciReaderDlgOptions = set of TSciReaderDlgOption;

  { TCharListOptions }
  TCharListOptions = class(TPersistent)
  private
    FDelimiterChars: TStringList;
    FCommentChars: TStringList;
    FQuotationChars: TStringList;
    FDecimalChars: TStringList;
    FThousandChars: TStringList;
    FDateSeparatorChars: TStringList;
    FTimeSeparatorChars: TStringList;
    FOnChange: TNotifyEvent;

    procedure ListChanged(Sender: TObject);

    function GetDelimiterChars: TStrings;
    function GetCommentChars: TStrings;
    function GetQuotationChars: TStrings;
    function GetDecimalChars: TStrings;
    function GetThousandChars: TStrings;
    function GetDateSeparatorChars: TStrings;
    function GetTimeSeparatorChars: TStrings;
    procedure SetDelimiterChars(Value: TStrings);
    procedure SetCommentChars(Value: TStrings);
    procedure SetQuotationChars(Value: TStrings);
    procedure SetDecimalChars(Value: TStrings);
    procedure SetThousandChars(Value: TStrings);
    procedure SetDateSeparatorChars(Value: TStrings);
    procedure SetTimeSeparatorChars(Value: TStrings);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Assign(Source: TPersistent); override;

    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property DelimiterChars: TStrings read GetDelimiterChars write SetDelimiterChars;
    property CommentChars: TStrings read GetCommentChars write SetCommentChars;
    property QuotationChars: TStrings read GetQuotationChars write SetQuotationChars;
    property DecimalChars: TStrings read GetDecimalChars write SetDecimalChars;
    property ThousandChars: TStrings read GetThousandChars write SetThousandChars;
    property DateSeparatorChars: TStrings read GetDateSeparatorChars write SetDateSeparatorChars;
    property TimeSeparatorChars: TStrings read GetTimeSeparatorChars write SetTimeSeparatorChars;
  end;

  { TFTXTDialog }
  TFTXTDialog = class(TForm)
    btnResetDateTime: TBitBtn;
    btnAccept: TBitBtn;
    btnCancel: TBitBtn;
    btnLoad: TBitBtn;
    btnMenu: TBitBtn;
    btnRefresh: TBitBtn;
    cbbDate: TComboBox;
    cbbThousand: TComboBox;
    cbbDelimiter: TComboBox;
    cbbComment: TComboBox;
    cbbDecimal: TComboBox;
    cbbTime: TComboBox;
    cbbXCol: TComboBox;
    cbbYCol: TComboBox;
    cbbQuotation: TComboBox;
    DateLbl: TLabel;
    DateTimeFmtLbl: TLabel;
    lblError: TLabel;
    lblFormulaError: TLabel;
    miSetAsDateTime: TMenuItem;
    pnDatTimOptions: TPanel;
    pnFormulaOptions: TPanel;
    dvFormula: TDividerBevel;
    TimeLbl: TLabel;
    txtDateTimeFmt: TEdit;
    txtXFormula: TEdit;
    txtYFormula: TEdit;
    txtXLbl: TEdit;
    ThousandLbl: TLabel;
    DelimiterLbl: TLabel;
    CommentLbl: TLabel;
    DecimalLbl: TLabel;
    txtYLbl: TEdit;
    XColLbl: TLabel;
    XLblLbl: TLabel;
    YLblLbl: TLabel;
    YColLbl: TLabel;
    XFormulaLbl: TLabel;
    YFormulaLbl: TLabel;
    pnFmtOptions: TPanel;
    txtHeader: TSpinEdit;
    lblData: TLabel;
    lblSource: TLabel;
    mmSource: TMemo;
    LeftPanel: TPanel;
    pnButtons: TPanel;
    RightPanel: TPanel;
    sgView: TStringGrid;
    Splitter: TSplitter;
    QuotationLbl: TLabel;
    pnTXTOptions: TPanel;
    HeaderLbl: TLabel;
    pmSelectChar: TPopupMenu;
    miSetAsDelimiter: TMenuItem;
    miSetAsComment: TMenuItem;
    miSetAsQuotation: TMenuItem;
    miSetAsDecimal: TMenuItem;
    miSetAsThousand: TMenuItem;
    miSetAsDateSeparator: TMenuItem;
    miSetAsTimeSeparator: TMenuItem;
    procedure btnLoadClick(Sender: TObject);
    procedure btnMenuClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
    procedure btnResetDateTimeClick(Sender: TObject);
    procedure cbbCommentChange(Sender: TObject);
    procedure cbbDecimalChange(Sender: TObject);
    procedure cbbDelimiterChange(Sender: TObject);
    procedure cbbQuotationChange(Sender: TObject);
    procedure cbbThousandChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure miSetAsDateTimeClick(Sender: TObject);
    procedure mmSourceKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure mmSourceMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure txtHeaderChange(Sender: TObject);
    procedure txtXFormulaEditingDone(Sender: TObject);
    procedure txtYFormulaEditingDone(Sender: TObject);
    procedure miSetAsDelimiterClick(Sender: TObject);
    procedure miSetAsCommentClick(Sender: TObject);
    procedure miSetAsQuotationClick(Sender: TObject);
    procedure miSetAsDecimalClick(Sender: TObject);
    procedure miSetAsThousandClick(Sender: TObject);
    procedure miSetAsDateSeparatorClick(Sender: TObject);
    procedure miSetAsTimeSeparatorClick(Sender: TObject);
  private
    { private declarations }
    FPreviewReader: TSciReader;
    FOpenDialog: TOpenDialog;
    FOptionsView: TTXTOptions;
    FFileName: TFileName;
    FConfigFile: TFileName;
    FDialogOptions: TSciReaderDlgOptions;
    FUpdating: Boolean;

    FDateTimeLine: Integer;
    FDateTimeCol: Integer;
    FDateTimeLength: Integer;

    FCharOptions: TCharListOptions;

    function GetFileName: TFileName;
    function GetConfigFileName(DirectoryName: TFileName): TFileName;
    function GetOptions: TTXTOptions;
    function GetDelimiter: Char;
    function GetComment: Char;
    function GetQuotation: Char;
    function GetHeaderLines: Integer;
    function GetDecimal: Char;
    function GetThousand: Char;
    function GetXCol: Integer;
    function GetXLbl: String;
    function GetYCol: Integer;
    function GetYLbl: String;
    function GetXFormula: String;
    function GetYFormula: String;
    function GetDateSeparator: Char;
    function GetTimeSeparator: Char;
    function GetDateTimeFormat: String;

    function GetCharOptions: TCharListOptions;
    procedure SetCharOptions(Value: TCharListOptions);
    procedure CharListChanged(Sender: TObject);
    procedure SetOpenDialog(Value: TOpenDialog);

    procedure SetFileName(Value: TFileName);
    procedure SetDialogOptions(Value: TSciReaderDlgOptions);
    procedure SetOptions(Value: TTXTOptions);
    procedure SetDelimiter(Value: Char);
    procedure SetComment(Value: Char);
    procedure SetQuotation(Value: Char);
    procedure SetHeaderLines(Value: Integer);
    procedure SetDecimal(Value: Char);
    procedure SetThousand(Value: Char);
    procedure SetXCol(Value: Integer);
    procedure SetXLbl(Value: String);
    procedure SetYCol(Value: Integer);
    procedure SetYLbl(Value: String);
    procedure SetXFormula(Value: String);
    procedure SetYFormula(Value: String);
    procedure SetDateSeparator(Value: Char);
    procedure SetTimeSeparator(Value: Char);
    procedure SetDateTimeFormat(Value: String);

    procedure UpdateView;
    procedure RefreshView;

    procedure SelectComboValue(ACombo: TComboBox; const AValue: String);
    procedure SetSelectionAsChar(ACombo: TComboBox);
    procedure PopulateCharCombo(ACombo: TComboBox; ASpecs: TStrings);
    function GetComboChar(ACombo: TComboBox): Char;
    procedure SetComboChar(ACombo: TComboBox; Value: Char);

    procedure PosToLineCol(APos: Integer; out ALine, ACol: Integer);
    procedure UpdateFormulaError;
  public
    { public declarations }

    constructor Create(TheOwner: TComponent); override;

    function Execute: Boolean;

    procedure SaveDirPreferences(DirectoryName: TFileName);
    procedure RestoreDirPreferences(DirectoryName: TFileName);

    property FileName: TFileName read GetFileName write SetFileName;
    property ConfigFile: TFileName read FConfigFile write FConfigFile;
    property DialogOptions: TSciReaderDlgOptions read FDialogOptions write SetDialogOptions
                              default [srdDateTimeReading, srdAutoSaveConfig, srdShowFormulas];

    property OpenDialog: TOpenDialog read FOpenDialog write SetOpenDialog;

    property Options: TTXTOptions read GetOptions write SetOptions;
    property Delimiter: Char read GetDelimiter write SetDelimiter;
    property Comment: Char read GetComment write SetComment;
    property Quotation: Char read GetQuotation write SetQuotation;
    property HeaderLines: Integer read GetHeaderLines write SetHeaderLines;
    property Decimal: Char read GetDecimal write SetDecimal;
    property Thousand: Char read GetThousand write SetThousand;
    property XCol: Integer read GetXCol write SetXCol;
    property XLbl: String read GetXLbl write SetXLbl;
    property YCol: Integer read GetYCol write SetYCol;
    property YLbl: String read GetYLbl write SetYLbl;
    property XFormula: String read GetXFormula write SetXFormula;
    property YFormula: String read GetYFormula write SetYFormula;
    property DateSeparator: Char read GetDateSeparator write SetDateSeparator;
    property TimeSeparator: Char read GetTimeSeparator write SetTimeSeparator;

    property DateTimeLine: Integer read FDateTimeLine write FDateTimeLine;
    property DateTimeCol: Integer read FDateTimeCol write FDateTimeCol;
    property DateTimeLength: Integer read FDateTimeLength write FDateTimeLength;
    property DateTimeFormat: String read GetDateTimeFormat write SetDateTimeFormat;
  published
    property CharOptions: TCharListOptions read GetCharOptions write SetCharOptions;
  end;

implementation

{$R *.lfm}

// Generic "named character" helpers.

function CharToDisplayName(C: Char): String;
begin
  case C of
    #0:  Result := 'NONE';
    #9:  Result := 'TAB';
    #10: Result := 'LF';
    #13: Result := 'CR';
    #27: Result := 'ESC';
    #32: Result := 'SPACE';
  else
    if (Ord(C) < 32) or (Ord(C) = 127) then
      Result := '#' + IntToStr(Ord(C))
    else
      Result := C;
  end;
end;

function DisplayNameToChar(const S: String): Char;
var
  Code: Integer;
  Upper: String;
begin
  Upper := UpperCase(Trim(S));
  if Upper = 'NONE'  then Exit(#0);
  if Upper = 'TAB'   then Exit(#9);
  if Upper = 'LF'    then Exit(#10);
  if Upper = 'CR'    then Exit(#13);
  if Upper = 'ESC'   then Exit(#27);
  if Upper = 'SPACE' then Exit(#32);

  // Ordinal escape, e.g. '#9', '#13'
  if (Length(S) >= 2) and (S[1] = '#') and
     TryStrToInt(Copy(S, 2, MaxInt), Code) and (Code >= 0) and (Code <= 255) then
    Exit(Chr(Code));

  if Length(S) >= 1 then
    Result := S[1]
  else
    Result := #0;
end;

{ TCharListOptions }

constructor TCharListOptions.Create;
begin
  inherited Create;
  FDelimiterChars := TStringList.Create;
  FDelimiterChars.OnChange := @ListChanged;
  FDelimiterChars.Text := 'SPACE' + LineEnding + 'TAB' + LineEnding + ';' + LineEnding + ',';

  FCommentChars := TStringList.Create;
  FCommentChars.OnChange := @ListChanged;
  FCommentChars.Text := '#' + LineEnding + '>' + LineEnding + '/' + LineEnding + '''';

  FQuotationChars := TStringList.Create;
  FQuotationChars.OnChange := @ListChanged;
  FQuotationChars.Text := 'NONE' + LineEnding + '"' + LineEnding + '''';

  FDecimalChars := TStringList.Create;
  FDecimalChars.OnChange := @ListChanged;
  FDecimalChars.Text := '.' + LineEnding + ',' + LineEnding + ';';

  FThousandChars := TStringList.Create;
  FThousandChars.OnChange := @ListChanged;
  FThousandChars.Text := 'NONE' + LineEnding + 'SPACE' + LineEnding + ',' + LineEnding + '.' + LineEnding + ';';

  FDateSeparatorChars := TStringList.Create;
  FDateSeparatorChars.OnChange := @ListChanged;
  FDateSeparatorChars.Text := 'SPACE' + LineEnding + '/' + LineEnding + '-';

  FTimeSeparatorChars := TStringList.Create;
  FTimeSeparatorChars.OnChange := @ListChanged;
  FTimeSeparatorChars.Text := 'SPACE' + LineEnding + ':' + LineEnding + '.' + LineEnding + ';';
end;

destructor TCharListOptions.Destroy;
begin
  FreeAndNil(FDelimiterChars);
  FreeAndNil(FCommentChars);
  FreeAndNil(FQuotationChars);
  FreeAndNil(FDecimalChars);
  FreeAndNil(FThousandChars);
  FreeAndNil(FDateSeparatorChars);
  FreeAndNil(FTimeSeparatorChars);
  inherited Destroy;
end;

procedure TCharListOptions.ListChanged(Sender: TObject);
begin
  if Assigned(FOnChange) then
    FOnChange(Sender); // Sender is whichever specific TStringList changed
end;

procedure TCharListOptions.Assign(Source: TPersistent);
var
  Src: TCharListOptions;
begin
  if Source is TCharListOptions then
  begin
    Src := TCharListOptions(Source);

    FDelimiterChars.Assign(Src.FDelimiterChars);
    FCommentChars.Assign(Src.FCommentChars);
    FQuotationChars.Assign(Src.FQuotationChars);
    FDecimalChars.Assign(Src.FDecimalChars);
    FThousandChars.Assign(Src.FThousandChars);
    FDateSeparatorChars.Assign(Src.FDateSeparatorChars);
    FTimeSeparatorChars.Assign(Src.FTimeSeparatorChars);
  end
  else
    inherited Assign(Source);
end;

procedure TCharListOptions.SetDelimiterChars(Value: TStrings);
begin
  FDelimiterChars.Assign(Value);
end;

function TCharListOptions.GetDelimiterChars: TStrings;
begin
  Result := FDelimiterChars;
end;

function TCharListOptions.GetCommentChars: TStrings;
begin
  Result := FCommentChars;
end;

procedure TCharListOptions.SetCommentChars(Value: TStrings);
begin
  FCommentChars.Assign(Value);
end;

function TCharListOptions.GetQuotationChars: TStrings;
begin
  Result := FQuotationChars;
end;

procedure TCharListOptions.SetQuotationChars(Value: TStrings);
begin
  FQuotationChars.Assign(Value);
end;

function TCharListOptions.GetDecimalChars: TStrings;
begin
  Result := FDecimalChars;
end;

procedure TCharListOptions.SetDecimalChars(Value: TStrings);
begin
  FDecimalChars.Assign(Value);
end;

function TCharListOptions.GetThousandChars: TStrings;
begin
  Result := FThousandChars;
end;

procedure TCharListOptions.SetThousandChars(Value: TStrings);
begin
  FThousandChars.Assign(Value);
end;

function TCharListOptions.GetDateSeparatorChars: TStrings;
begin
  Result := FDateSeparatorChars;
end;

procedure TCharListOptions.SetDateSeparatorChars(Value: TStrings);
begin
  FDateSeparatorChars.Assign(Value);
end;

function TCharListOptions.GetTimeSeparatorChars: TStrings;
begin
  Result := FTimeSeparatorChars;
end;

procedure TCharListOptions.SetTimeSeparatorChars(Value: TStrings);
begin
  FTimeSeparatorChars.Assign(Value);
end;

function TFTXTDialog.GetFileName: TFileName;
begin
  Result := FFileName;
end;

function TFTXTDialog.GetConfigFileName(DirectoryName: TFileName): TFileName;
begin
  if FConfigFile <> '' then
    Result := DirectoryName + DirectorySeparator + FConfigFile
  else
    Result := DirectoryName + DirectorySeparator + ChangeFileExt(ExtractFileName(Application.ExeName), '.cfg');
end;

procedure TFTXTDialog.SetDialogOptions(Value: TSciReaderDlgOptions);
begin
  FDialogOptions := Value;
  pnDatTimOptions.Visible := (srdDateTimeReading in Value);
  miSetAsDateTime.Visible := (srdDateTimeReading in Value);
  pnFormulaOptions.Visible := (srdShowFormulas in Value);
end;

function TFTXTDialog.GetOptions: TTXTOptions;
begin
  FOptionsView.Delimiter := Delimiter;
  FOptionsView.Comment := Comment;
  FOptionsView.Quotation := Quotation;
  FOptionsView.HeaderLines := HeaderLines;
  FOptionsView.Decimal := Decimal;
  FOptionsView.Thousand := Thousand;
  FOptionsView.XCol := XCol;
  FOptionsView.XLbl := XLbl;
  FOptionsView.YCol := YCol;
  FOptionsView.YLbl := YLbl;
  FOptionsView.XFormula := XFormula;
  FOptionsView.YFormula := YFormula;
  FOptionsView.DateSeparator := DateSeparator;
  FOptionsView.TimeSeparator := TimeSeparator;
  FOptionsView.DateTimeLine := DateTimeLine;
  FOptionsView.DateTimeCol := DateTimeCol;
  FOptionsView.DateTimeLength := DateTimeLength;
  FOptionsView.DateTimeFormat := DateTimeFormat;
  Result := FOptionsView;
end;

function TFTXTDialog.GetComboChar(ACombo: TComboBox): Char;
begin
  Result := DisplayNameToChar(ACombo.Text);
end;

procedure TFTXTDialog.SetComboChar(ACombo: TComboBox; Value: Char);
begin
  SelectComboValue(ACombo, CharToDisplayName(Value));
end;

function TFTXTDialog.GetDelimiter: Char;
begin
  Result := GetComboChar(cbbDelimiter);
end;

procedure TFTXTDialog.SetDelimiter(Value: Char);
begin
  SetComboChar(cbbDelimiter, Value);
end;

function TFTXTDialog.GetComment: Char;
begin
  Result := GetComboChar(cbbComment);
end;

procedure TFTXTDialog.SetComment(Value: Char);
begin
  SetComboChar(cbbComment, Value);
end;

function TFTXTDialog.GetQuotation: Char;
begin
  Result := GetComboChar(cbbQuotation);
end;

procedure TFTXTDialog.SetQuotation(Value: Char);
begin
  SetComboChar(cbbQuotation, Value);
end;

function TFTXTDialog.GetHeaderLines: Integer;
begin
  Result := txtHeader.Value;
end;

function TFTXTDialog.GetDecimal: Char;
begin
  Result := GetComboChar(cbbDecimal);
end;

procedure TFTXTDialog.SetDecimal(Value: Char);
begin
  SetComboChar(cbbDecimal, Value);
end;

function TFTXTDialog.GetThousand: Char;
begin
  Result := GetComboChar(cbbThousand);
end;

procedure TFTXTDialog.SetThousand(Value: Char);
begin
  SetComboChar(cbbThousand, Value);
end;

function TFTXTDialog.GetXCol: Integer;
begin
  Result := cbbXCol.ItemIndex;
end;

function TFTXTDialog.GetXLbl: String;
begin
  Result := txtXLbl.Text;
end;

function TFTXTDialog.GetYCol: Integer;
begin
  Result := cbbYCol.ItemIndex;
end;

function TFTXTDialog.GetYLbl: String;
begin
  Result := txtYLbl.Text;
end;

function TFTXTDialog.GetXFormula: String;
begin
  Result := Trim(txtXFormula.Text);
end;

function TFTXTDialog.GetYFormula: String;
begin
  Result := Trim(txtYFormula.Text);
end;

function TFTXTDialog.GetDateSeparator: Char;
begin
  Result := GetComboChar(cbbDate);
end;

procedure TFTXTDialog.SetDateSeparator(Value: Char);
begin
  SetComboChar(cbbDate, Value);
end;

function TFTXTDialog.GetTimeSeparator: Char;
begin
  Result := GetComboChar(cbbTime);
end;

procedure TFTXTDialog.SetTimeSeparator(Value: Char);
begin
  SetComboChar(cbbTime, Value);
end;

function TFTXTDialog.GetDateTimeFormat: String;
begin
  Result := txtDateTimeFmt.Text;
end;

procedure TFTXTDialog.SetDateTimeFormat(Value: String);
begin
  if (Value <> txtDateTimeFmt.Text) then
    txtDateTimeFmt.Text := Value;
end;

// Assigning a new TCharListOptions repopulates every combobox automatically
// via each nested TStringList's OnChange

function TFTXTDialog.GetCharOptions: TCharListOptions;
begin
  Result := FCharOptions;
end;

procedure TFTXTDialog.SetCharOptions(Value: TCharListOptions);
begin
  FCharOptions.Assign(Value);
end;

procedure TFTXTDialog.CharListChanged(Sender: TObject);
begin
  if Sender = FCharOptions.DelimiterChars then
  begin
    if Assigned(cbbDelimiter) then
      PopulateCharCombo(cbbDelimiter, FCharOptions.DelimiterChars);
  end
  else if Sender = FCharOptions.CommentChars then
  begin
    if Assigned(cbbComment) then
      PopulateCharCombo(cbbComment, FCharOptions.CommentChars);
  end
  else if Sender = FCharOptions.QuotationChars then
  begin
    if Assigned(cbbQuotation) then
      PopulateCharCombo(cbbQuotation, FCharOptions.QuotationChars);
  end
  else if Sender = FCharOptions.DecimalChars then
  begin
    if Assigned(cbbDecimal) then
      PopulateCharCombo(cbbDecimal, FCharOptions.DecimalChars);
  end
  else if Sender = FCharOptions.ThousandChars then
  begin
    if Assigned(cbbThousand) then
      PopulateCharCombo(cbbThousand, FCharOptions.ThousandChars);
  end
  else if Sender = FCharOptions.DateSeparatorChars then
  begin
    if Assigned(cbbDate) then
      PopulateCharCombo(cbbDate, FCharOptions.DateSeparatorChars);
  end
  else if Sender = FCharOptions.TimeSeparatorChars then
  begin
    if Assigned(cbbTime) then
      PopulateCharCombo(cbbTime, FCharOptions.TimeSeparatorChars);
  end;
end;

procedure TFTXTDialog.SetOpenDialog(Value: TOpenDialog);
begin
  FOpenDialog := Value;
  if Assigned(btnLoad) then
    btnLoad.Enabled := Assigned(FOpenDialog);
end;

procedure TFTXTDialog.PopulateCharCombo(ACombo: TComboBox; ASpecs: TStrings);
var
  i: Integer;
  OldText, CharName: String;
begin
  OldText := ACombo.Text;

  ACombo.Items.BeginUpdate;
  try
    ACombo.Items.Clear;
    for i := 0 to ASpecs.Count - 1 do
    begin
      CharName := CharToDisplayName(DisplayNameToChar(ASpecs[i]));
      if ACombo.Items.IndexOf(CharName) = -1 then
        ACombo.Items.Add(CharName);
    end;
  finally
    ACombo.Items.EndUpdate;
  end;

  if OldText <> '' then
    SelectComboValue(ACombo, OldText) // keeps the current selection, re-adding it if it was a custom value
  else if ACombo.Items.Count > 0 then
    ACombo.ItemIndex := 0;
end;

procedure TFTXTDialog.PosToLineCol(APos: Integer; out ALine, ACol: Integer);
var
  i, LineStart, LineLen: Integer;
begin
  LineStart := 0;
  for i := 0 to mmSource.Lines.Count - 1 do
  begin
    LineLen := Length(mmSource.Lines[i]);
    if APos <= LineStart + LineLen then
    begin
      ALine := i;
      ACol := APos - LineStart;
      Exit;
    end;

    LineStart := LineStart + LineLen + Length(LineEnding);
  end;

  if mmSource.Lines.Count > 0 then
  begin
    ALine := mmSource.Lines.Count - 1;
    ACol := Length(mmSource.Lines[ALine]);
  end
  else
  begin
    ALine := 0;
    ACol := 0;
  end;
end;

procedure TFTXTDialog.SetFileName(Value: TFileName);
begin
  if (Value <> FFileName) then
  begin
    FFileName := Value;

    if FileExists(Value) then
    begin
      Caption := 'File options - ' + ExtractFileName(Value);

      mmSource.Lines.LoadFromFile(Value);

      RestoreDirPreferences(ExtractFileDir(Value));
    end
    else
    begin
      Caption := 'File options';
      mmSource.Lines.Clear;
    end;

    RefreshView;
  end;
end;

procedure TFTXTDialog.SetOptions(Value: TTXTOptions);
begin
  if not Assigned(Value) then Exit;

  FUpdating := True;
  try
    Delimiter := Value.Delimiter;
    Comment := Value.Comment;
    Quotation := Value.Quotation;
    HeaderLines := Value.HeaderLines;
    Decimal := Value.Decimal;
    Thousand := Value.Thousand;
    XCol := Value.XCol;
    XLbl := Value.XLbl;
    YCol := Value.YCol;
    YLbl := Value.YLbl;
    XFormula := Value.XFormula;
    YFormula := Value.YFormula;
    DateSeparator := Value.DateSeparator;
    TimeSeparator := Value.TimeSeparator;
    DateTimeLine := Value.DateTimeLine;
    DateTimeCol := Value.DateTimeCol;
    DateTimeLength := Value.DateTimeLength;
    DateTimeFormat := Value.DateTimeFormat;
  finally
    FUpdating := False;
  end;

  RefreshView;
end;

procedure TFTXTDialog.SelectComboValue(ACombo: TComboBox; const AValue: String);
var
  Idx: Integer;
begin
  Idx := ACombo.Items.IndexOf(AValue);
  if Idx = -1 then
    Idx := ACombo.Items.Add(AValue);
  ACombo.ItemIndex := Idx;
end;

procedure TFTXTDialog.SetSelectionAsChar(ACombo: TComboBox);
var
  Ch: String;
begin
  Ch := mmSource.SelText;
  if Length(Ch) <> 1 then
  begin
    ShowMessage('Select exactly one character in the source text first.');
    Exit;
  end;

  SelectComboValue(ACombo, CharToDisplayName(Ch[1]));

  RefreshView;
end;

procedure TFTXTDialog.miSetAsDelimiterClick(Sender: TObject);
begin
  SetSelectionAsChar(cbbDelimiter);
end;

procedure TFTXTDialog.miSetAsCommentClick(Sender: TObject);
begin
  SetSelectionAsChar(cbbComment);
end;

procedure TFTXTDialog.miSetAsQuotationClick(Sender: TObject);
begin
  SetSelectionAsChar(cbbQuotation);
end;

procedure TFTXTDialog.miSetAsDecimalClick(Sender: TObject);
begin
  SetSelectionAsChar(cbbDecimal);
end;

procedure TFTXTDialog.miSetAsThousandClick(Sender: TObject);
begin
  SetSelectionAsChar(cbbThousand);
end;

procedure TFTXTDialog.miSetAsDateSeparatorClick(Sender: TObject);
begin
  SetSelectionAsChar(cbbDate);
end;

procedure TFTXTDialog.miSetAsTimeSeparatorClick(Sender: TObject);
begin
  SetSelectionAsChar(cbbTime);
end;

procedure TFTXTDialog.SetHeaderLines(Value: Integer);
begin
  if (Value <> txtHeader.Value) then
    txtHeader.Value := Value;
end;

procedure TFTXTDialog.SetXCol(Value: Integer);
var
  i: Integer;
begin
  if (Value <> cbbXCol.ItemIndex) then
  begin
    // Convert logic to standard 1-based lists to match RefreshView
    for i := cbbXCol.Items.Count + 1 to Value + 1 do
      cbbXCol.Items.Add(IntToStr(i));

    cbbXCol.ItemIndex := Value;
  end;
end;

procedure TFTXTDialog.SetXLbl(Value: String);
begin
  if (Value <> txtXLbl.Text) then
    txtXLbl.Text := Value;
end;

procedure TFTXTDialog.SetYCol(Value: Integer);
var
  i: Integer;
begin
  if (Value <> cbbYCol.ItemIndex) then
  begin
    // Convert logic to standard 1-based lists to match RefreshView
    for i := cbbYCol.Items.Count + 1 to Value + 1 do
      cbbYCol.Items.Add(IntToStr(i));

    cbbYCol.ItemIndex := Value;
  end;
end;

procedure TFTXTDialog.SetYLbl(Value: String);
begin
  if (Value <> txtYLbl.Text) then
    txtYLbl.Text := Value;
end;

procedure TFTXTDialog.SetXFormula(Value: String);
begin
  if (Value <> txtXFormula.Text) then
    txtXFormula.Text := Value;
end;

procedure TFTXTDialog.SetYFormula(Value: String);
begin
  if (Value <> txtYFormula.Text) then
    txtYFormula.Text := Value;
end;

procedure TFTXTDialog.btnLoadClick(Sender: TObject);
begin
  if not Assigned(FOpenDialog) then
  begin
    ShowMessage('No file dialog has been assigned (OpenDialog property).');
    Exit;
  end;

  FOpenDialog.FileName := FileName;

  if FOpenDialog.Execute then
    FileName := FOpenDialog.FileName;
end;

procedure TFTXTDialog.btnMenuClick(Sender: TObject);
var
  BtnPt: TPoint;
begin
  BtnPt := btnMenu.ClientToScreen(Point(0, btnMenu.Height));
  pmSelectChar.PopUp(BtnPt.X, BtnPt.Y);
end;

procedure TFTXTDialog.btnRefreshClick(Sender: TObject);
begin
  RefreshView;
end;

procedure TFTXTDialog.btnResetDateTimeClick(Sender: TObject);
begin
  DateSeparator := '/';
  TimeSeparator := ':';
  DateTimeLine := 0;
  DateTimeCol := 0;
  DateTimeLength := 0;
  DateTimeFormat := 'dd/mm/yyyy, hh:nn:ss';

  RefreshView;
end;

procedure TFTXTDialog.cbbCommentChange(Sender: TObject);
begin
  FPreviewReader.Options.Comment := Comment;

  RefreshView;
end;

procedure TFTXTDialog.cbbDecimalChange(Sender: TObject);
begin
  FPreviewReader.Options.Decimal := Decimal;
  RefreshView;
end;

procedure TFTXTDialog.cbbDelimiterChange(Sender: TObject);
begin
  FPreviewReader.Options.Delimiter := Delimiter;

  RefreshView;
end;

procedure TFTXTDialog.cbbQuotationChange(Sender: TObject);
begin
  FPreviewReader.Options.Quotation := Quotation;

  RefreshView;
end;

procedure TFTXTDialog.cbbThousandChange(Sender: TObject);
begin
  FPreviewReader.Options.Thousand := Thousand;
  RefreshView;
end;

constructor TFTXTDialog.Create(TheOwner: TComponent);
begin
  FCharOptions := TCharListOptions.Create;

  FCharOptions.OnChange := @CharListChanged;

  inherited Create(TheOwner);
end;

procedure TFTXTDialog.FormCreate(Sender: TObject);
begin
  FPreviewReader := TSciReader.Create(Self);
  FOptionsView := TTXTOptions.Create;

  // Fixed header row showing each column's formula-usable letter (A, B,
  // C, ...) - set here as well as in the .lfm so it stays correct even if
  // the designer ever touches this property.
  sgView.FixedRows := 1;

  FConfigFile := '';
  DialogOptions := [srdDateTimeReading, srdAutoSaveConfig, srdShowFormulas];

  btnLoad.Enabled := Assigned(FOpenDialog);

  // Make sure every combobox reflects whatever ended up in its list
  PopulateCharCombo(cbbDelimiter, FCharOptions.DelimiterChars);
  PopulateCharCombo(cbbComment, FCharOptions.CommentChars);
  PopulateCharCombo(cbbQuotation, FCharOptions.QuotationChars);
  PopulateCharCombo(cbbDecimal, FCharOptions.DecimalChars);
  PopulateCharCombo(cbbThousand, FCharOptions.ThousandChars);
  PopulateCharCombo(cbbDate, FCharOptions.DateSeparatorChars);
  PopulateCharCombo(cbbTime, FCharOptions.TimeSeparatorChars);

  FUpdating := True;
  Delimiter := ' ';
  Comment := '#';
  Quotation := #0;
  HeaderLines := 0;
  Decimal := '.';
  Thousand := #0;
  XCol := 0;
  XLbl := 'X';
  YCol := 1;
  YLbl := 'Y';
  XFormula := '';
  YFormula := '';
  DateSeparator := '/';
  TimeSeparator := ':';
  DateTimeLine := 0;
  DateTimeCol := 0;
  DateTimeLength := 0;
  DateTimeFormat := 'dd/mm/yyyy, hh:nn:ss';
  FUpdating := False;
  RefreshView;
end;

procedure TFTXTDialog.FormDestroy(Sender: TObject);
begin
  FreeAndNil(FPreviewReader);
  FreeAndNil(FOptionsView);
  FreeAndNil(FCharOptions);
end;

procedure TFTXTDialog.miSetAsDateTimeClick(Sender: TObject);
var
  ALine, ACol: Integer;
begin
  PosToLineCol(mmSource.SelStart, ALine, ACol);
  DateTimeLine := ALine;
  DateTimeCol := ACol;
  DateTimeLength := mmSource.SelLength;

  RefreshView;
end;

procedure TFTXTDialog.mmSourceKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  btnMenu.Enabled := (mmSource.SelLength > 0);
end;

procedure TFTXTDialog.mmSourceMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  btnMenu.Enabled := (mmSource.SelLength > 0);
end;

procedure TFTXTDialog.txtHeaderChange(Sender: TObject);
begin
  FPreviewReader.Options.HeaderLines := HeaderLines;

  RefreshView;
end;

procedure TFTXTDialog.txtXFormulaEditingDone(Sender: TObject);
begin
  RefreshView;
end;

procedure TFTXTDialog.txtYFormulaEditingDone(Sender: TObject);
begin
  RefreshView;
end;

procedure TFTXTDialog.UpdateView;
var
  i, j: Integer;
begin
  sgView.BeginUpdate;
  try
    sgView.RowCount := FPreviewReader.RowCount + 1; // +1 for the fixed header row
    sgView.ColCount := Max(1, FPreviewReader.MaxColCount);

    // Fixed header row: the column letter each formula can reference (see
    // TTXTOptions.XFormula for the A, B, C... naming convention)
    for j := 0 to sgView.ColCount - 1 do
      sgView.Cells[j, 0] := ColumnLetter(j);

    for i := 0 to FPreviewReader.RowCount - 1 do
      for j := 0 to sgView.ColCount - 1 do
        sgView.Cells[j, i + 1] := FPreviewReader.Cells[j, i];
  finally
    sgView.EndUpdate;
  end;
end;

procedure TFTXTDialog.RefreshView;
var
  i, xi, yi: Integer;
begin
  if not FUpdating then
  begin
    xi := cbbXCol.ItemIndex;
    yi := cbbYCol.ItemIndex;

    // Sync current UI parameters to the preview reader
    FPreviewReader.Options.Delimiter := Delimiter;
    FPreviewReader.Options.Comment := Comment;
    FPreviewReader.Options.Quotation := Quotation;
    FPreviewReader.Options.HeaderLines := HeaderLines;
    FPreviewReader.Options.Decimal := Decimal;
    FPreviewReader.Options.Thousand := Thousand;

    FPreviewReader.Options.XCol := XCol;
    FPreviewReader.Options.XLbl := XLbl;
    FPreviewReader.Options.YCol := YCol;
    FPreviewReader.Options.YLbl := YLbl;
    FPreviewReader.Options.XFormula := XFormula;
    FPreviewReader.Options.YFormula := YFormula;

    FPreviewReader.Options.DateSeparator := DateSeparator;
    FPreviewReader.Options.TimeSeparator := TimeSeparator;
    FPreviewReader.Options.DateTimeLine := DateTimeLine;
    FPreviewReader.Options.DateTimeCol := DateTimeCol;
    FPreviewReader.Options.DateTimeLength := DateTimeLength;
    FPreviewReader.Options.DateTimeFormat := DateTimeFormat;

    // Load string data directly into the preview
    FPreviewReader.LoadFromString(mmSource.Text);

    cbbXCol.Items.Clear;
    cbbYCol.Items.Clear;

    for i := 1 to max(FPreviewReader.MaxColCount, max(xi + 1, yi + 1)) do
    begin
      cbbXCol.Items.Add(IntToStr(i));
      cbbYCol.Items.Add(IntToStr(i));
    end;

    cbbXCol.ItemIndex := xi;
    cbbYCol.ItemIndex := yi;

    if (srdDateTimeReading in FDialogOptions) then
    begin
      try
        lblData.Caption:= 'Data - date = ' + DateTimeToStr(FPreviewReader.FileDate);
      except
        lblData.Caption:= 'Data';
      end;
    end
    else
      lblData.Caption := 'Data';

    if FPreviewReader.HasErrors then
      lblError.Caption := Format('Error: %s', [FPreviewReader.Errors[0]])
    else
      lblError.Caption := '';

    UpdateFormulaError;

    UpdateView;
  end;
end;

// Evaluates the formulas against the first preview row
procedure TFTXTDialog.UpdateFormulaError;
var
  XVal, YVal: Double;
begin
  if (XFormula = '') and (YFormula = '') then
  begin
    lblFormulaError.Caption := '';
    Exit;
  end;

  if FPreviewReader.RowCount = 0 then
  begin
    lblFormulaError.Caption := '';
    Exit;
  end;

  XVal := FPreviewReader.X[0];
  YVal := FPreviewReader.Y[0];

  if FPreviewReader.HasErrors then
  begin
    lblFormulaError.Font.Color := clRed;
    lblFormulaError.Caption := FPreviewReader.Errors[FPreviewReader.Errors.Count - 1];
  end
  else
  begin
    lblFormulaError.Font.Color := clGreen;
    lblFormulaError.Caption := Format('Row 1: X=%.6g  Y=%.6g', [XVal, YVal]);
  end;
end;

function TFTXTDialog.Execute: Boolean;
var
  ConfigDir: TFileName;
begin
  ConfigDir := ExtractFileDir(FileName);

  FPreviewReader.Options.Delimiter := Delimiter;
  FPreviewReader.Options.Comment := Comment;
  FPreviewReader.Options.Quotation := Quotation;
  FPreviewReader.Options.HeaderLines := HeaderLines;
  FPreviewReader.Options.Decimal := Decimal;
  FPreviewReader.Options.Thousand := Thousand;

  RefreshView;

  Result := (ShowModal = mrOK);

  if Result and (srdAutoSaveConfig in FDialogOptions) then
    SaveDirPreferences(ConfigDir);
end;

procedure TFTXTDialog.SaveDirPreferences(DirectoryName: TFileName);
var
  Ini: TIniFile;
  FName : TFileName;
begin
  if Assigned(FOpenDialog) then
    FOpenDialog.InitialDir := DirectoryName;

  FName := GetConfigFileName(DirectoryName);
  try
    Ini := TIniFile.Create(FName);
    try
      //Save TXT options
      Ini.WriteInteger('TXTOptions', 'Delimiter', Ord(Options.Delimiter));
      Ini.WriteInteger('TXTOptions', 'Comment', Ord(Options.Comment));
      Ini.WriteInteger('TXTOptions', 'Quotation', Ord(Options.Quotation));
      Ini.WriteInteger('TXTOptions', 'HeaderLines', Options.HeaderLines);
      Ini.WriteInteger('TXTOptions', 'Decimal', Ord(Options.Decimal));
      Ini.WriteInteger('TXTOptions', 'Thousand', Ord(Options.Thousand));
      Ini.WriteInteger('TXTOptions', 'XCol', Options.XCol);
      Ini.WriteString('TXTOptions', 'XLbl', Options.XLbl);
      Ini.WriteInteger('TXTOptions', 'YCol', Options.YCol);
      Ini.WriteString('TXTOptions', 'YLbl', Options.YLbl);
      Ini.WriteString('TXTOptions', 'XFormula', Options.XFormula);
      Ini.WriteString('TXTOptions', 'YFormula', Options.YFormula);
      Ini.WriteInteger('TXTOptions', 'DateSeparator', Ord(Options.DateSeparator));
      Ini.WriteInteger('TXTOptions', 'TimeSeparator', Ord(Options.TimeSeparator));
      // Line/Col rather than an absolute offset: portable across OSes and
      // across files with different line-ending conventions.
      Ini.WriteInteger('TXTOptions', 'DateTimeLine', Options.DateTimeLine);
      Ini.WriteInteger('TXTOptions', 'DateTimeCol', Options.DateTimeCol);
      Ini.WriteInteger('TXTOptions', 'DateTimeLength', Options.DateTimeLength);
      Ini.WriteString('TXTOptions', 'DateTimeFormat', Options.DateTimeFormat);
    finally
      Ini.Free;
    end;
  except
    // Failsafe catch for Read-Only directories
  end;
end;

procedure TFTXTDialog.RestoreDirPreferences(DirectoryName: TFileName);
var
  Ini: TIniFile;
  FName : TFileName;
begin
  if Assigned(FOpenDialog) then
    FOpenDialog.InitialDir := DirectoryName;

  FName := GetConfigFileName(DirectoryName);
  if FileExists(FName) then
  begin
    try
      Ini := TIniFile.Create(FName);
      FUpdating := True;
      try
        //Restore TXT options
        Delimiter := Chr(Ini.ReadInteger('TXTOptions', 'Delimiter', Ord(' ')));
        Comment := Chr(Ini.ReadInteger('TXTOptions', 'Comment', Ord('#')));
        Quotation := Chr(Ini.ReadInteger('TXTOptions', 'Quotation', Ord(#0)));
        HeaderLines := Ini.ReadInteger('TXTOptions', 'HeaderLines', 0);
        Decimal := Chr(Ini.ReadInteger('TXTOptions', 'Decimal', Ord('.')));
        Thousand := Chr(Ini.ReadInteger('TXTOptions', 'Thousand', Ord(#0)));
        XCol := Ini.ReadInteger('TXTOptions', 'XCol', 0);
        XLbl := Ini.ReadString('TXTOptions', 'XLbl', 'X');
        YCol := Ini.ReadInteger('TXTOptions', 'YCol', 1);
        YLbl := Ini.ReadString('TXTOptions', 'YLbl', 'Y');
        XFormula := Ini.ReadString('TXTOptions', 'XFormula', '');
        YFormula := Ini.ReadString('TXTOptions', 'YFormula', '');
        DateSeparator := Chr(Ini.ReadInteger('TXTOptions', 'DateSeparator', Ord('/')));
        TimeSeparator := Chr(Ini.ReadInteger('TXTOptions', 'TimeSeparator', Ord(':')));
        DateTimeLine := Ini.ReadInteger('TXTOptions', 'DateTimeLine', 0);
        DateTimeCol := Ini.ReadInteger('TXTOptions', 'DateTimeCol', 0);
        DateTimeLength := Ini.ReadInteger('TXTOptions', 'DateTimeLength', 0);
        DateTimeFormat := Ini.ReadString('TXTOptions', 'DateTimeFormat', 'dd/mm/yyyy, hh:nn:ss');
      finally
        FUpdating := False;
        Ini.Free;
      end;
      RefreshView;
    except
      // Ignore reading exceptions gracefully
    end;
  end;
end;

end.
