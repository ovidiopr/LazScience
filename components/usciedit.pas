unit uSciEdit;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ComCtrls, ExtCtrls, Graphics, LCLType,
  Math, LResources, Menus, uUnitParser;

type
  ESciEditError = class(Exception);

  TSciEditOption = (
    seoAutoUnits,          // auto-pick the best SI prefix after each edit
    seoScientificNotation, // fall back to scientific notation for extreme magnitudes
    seoCanonicalUnits,     // convert non-canonical units (e.g. bar, °C) to base units (e.g. Pa, K)
    seoPreferredUnits      // always convert user-typed input to PreferredUnits (if set)
  );
  TSciEditOptions = set of TSciEditOption;

  // sesInvalidNumber  - the numeric portion of the text couldn't be parsed
  // sesInvalidUnits   - the unit portion isn't a recognized unit/expression
  // sesFamilyMismatch - the units are valid, but belong to a different
  //                     physical quantity family than UnitFamily requires
  TSciEditState = (sesEmpty, sesValid, sesInvalidNumber, sesInvalidUnits, sesFamilyMismatch);

  TSciEditEvent = procedure(Sender: TObject; NewValue: Double) of object;
  TSciEditParseErrorEvent = procedure(Sender: TObject; const RawText: String) of object;

const
  DefaultSciEditOptions = [seoAutoUnits, seoScientificNotation];

type
  TSciEdit = class(TCustomEdit)
  private
    FPreferredUnits: String;
    FValue: Double;
    FBaseUnits: String;
    FPrefix: TSIPrefixKind;
    FUnitFactor: Double;
    FUnitOffset: Double;
    FHasValue: Boolean;
    FUnitFamily: TUnitFamily;
    FCustomUnits: String;
    FSignificantDigits: Integer;
    FOptions: TSciEditOptions;
    FDetectedFamily: TUnitFamily;
    FState: TSciEditState;
    FOnValueChanged: TSciEditEvent;
    FOnParseError: TSciEditParseErrorEvent;
    FOnUserEdit: TNotifyEvent;
    FUpdating: Boolean;
    FLastCommittedText: String;

    FBatchDepth: Integer;
    FBatchPendingReparse: Boolean;

    FErrorColor: TColor;
    FUserFontColor: TColor;
    FApplyingStateColor: Boolean;
    FPrevFontOnChange: TNotifyEvent;

    FTrackBar: TTrackBar;
    FTrackBarFactor: Double;
    FTrackBarRange: Integer;
    FTrackBarReference: Double;
    FTrackBarSettleDelay: Integer;
    FTrackBarSettleTimer: TTimer;
    FTrackBarOldOnChange: TNotifyEvent;
    FTrackBarOldOnEnter: TNotifyEvent;
    FTrackBarOldOnMouseUp: TMouseEvent;
    FTrackBarOldOnKeyUp: TKeyEvent;

    FUnitPopupMenu: TPopupMenu;
    FContextUnits: TStringList;

    procedure SetPreferredUnits(const AUnits: String);
    function GetValueAs(const AUnits: String): Double;
    procedure SetValueAs(const AUnits: String; AValue: Double);
    function GetValue: Double;
    procedure SetValue(AValue: Double);

    procedure SetUnitFamily(AFamily: TUnitFamily);
    procedure SetSignificantDigits(ADigits: Integer);
    procedure SetCustomUnits(const S: String);
    procedure SetOptions(AValue: TSciEditOptions);
    procedure SetErrorColor(AValue: TColor);
    procedure FontChangedHandler(Sender: TObject);
    procedure ApplyErrorColor;
    procedure RestoreNormalColor;
    procedure SetState(AState: TSciEditState);
    procedure SetTrackBar(ATrackBar: TTrackBar);
    procedure SetTrackBarFactor(AFactor: Double);
    procedure SetTrackBarRange(ARange: Integer);
    procedure SetTrackBarSettleDelay(AValue: Integer);
    procedure ApplyTrackBarBounds;
    function  GetCanonicalValue: Double;
    procedure ApplyCanonicalValue(ACanonical: Double);
    procedure ResetTrackBarReference;
    procedure TrackBarChangeHandler(Sender: TObject);
    procedure TrackBarEnterHandler(Sender: TObject);
    procedure TrackBarMouseUpHandler(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
    procedure TrackBarKeyUpHandler(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure TrackBarSettleTimerHandler(Sender: TObject);
    function GetUnitDescription: String;
    procedure UpdateText;

    function DecomposeMyUnit(const AUnits: String; out APrefix: TSIPrefixKind;
      out AUnprefixed: String; out AFactor, AOffset: Double; out AFamily: TUnitFamily;
      out AFailure: TUnitParseFailure): Boolean;
    function CanonicalFromValue(AValue: Double; APrefix: TSIPrefixKind; AFactor, AOffset: Double): Double;
    function ValueFromCanonical(ACanonical: Double; APrefix: TSIPrefixKind; AFactor, AOffset: Double): Double;

    procedure UnitMenuItemClick(Sender: TObject);
    procedure PopulateUnitContextMenu;
    procedure SetContextUnits(AValue: TStringList);

    procedure DoParseInput;
    function IsBatchUpdating: Boolean;
  protected
    procedure DoContextPopup(MousePos: TPoint; var Handled: Boolean); override;
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure EditingDone; override;

    procedure BeginUpdate;
    procedure EndUpdate;

    property ValueAs[const AUnits: String]: Double read GetValueAs write SetValueAs;
    property HasValue: Boolean read FHasValue;
    property State: TSciEditState read FState;
    property DetectedFamily: TUnitFamily read FDetectedFamily;
    property CanonicalValue: Double read GetCanonicalValue;
    procedure ConvertToUnits(const TargetUnits: String);
  published
    property Text;
    property Value: Double read GetValue write SetValue stored False;
    property BaseUnits: String read FBaseUnits;
    property Prefix: TSIPrefixKind read FPrefix;
    property PreferredUnits: String read FPreferredUnits write SetPreferredUnits;
    property UnitFamily: TUnitFamily read FUnitFamily write SetUnitFamily default ufAny;
    property CustomUnits: String read FCustomUnits write SetCustomUnits;
    property SignificantDigits: Integer read FSignificantDigits write SetSignificantDigits default 5;
    property Options: TSciEditOptions read FOptions write SetOptions default DefaultSciEditOptions;
    property ErrorColor: TColor read FErrorColor write SetErrorColor default clRed;

    property TrackBar: TTrackBar read FTrackBar write SetTrackBar;
    property TrackBarFactor: Double read FTrackBarFactor write SetTrackBarFactor;
    property TrackBarRange: Integer read FTrackBarRange write SetTrackBarRange default 100;
    property TrackBarSettleDelay: Integer read FTrackBarSettleDelay write SetTrackBarSettleDelay default 150;

    property ContextUnits: TStringList read FContextUnits write SetContextUnits;

    property OnValueChanged: TSciEditEvent read FOnValueChanged write FOnValueChanged;
    property OnParseError: TSciEditParseErrorEvent read FOnParseError write FOnParseError;
    property OnUserEdit: TNotifyEvent read FOnUserEdit write FOnUserEdit;

    property Align;
    property Anchors;
    property AutoSize;
    property BorderSpacing;
    property BorderStyle;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property MaxLength;
    property ParentColor;
    property ParentFont;
    property ParentShowHint;
    property PopupMenu;
    property ReadOnly;
    property ShowHint;
    property TabOrder;
    property TabStop;
    property Visible;
    property OnClick;
    property OnDblClick;
    property OnEnter;
    property OnExit;
    property OnKeyPress;
    property OnKeyUp;
  end;

procedure Register;

implementation

var
  PointSettings: TFormatSettings;

function FormatSignificant(x: Double; SigDigits: Integer): String;
var
  mag, decimals: Integer;
  rounded: Double;
  fmt: String;
begin
  if SigDigits < 1 then SigDigits := 1;
  if x = 0 then
  begin
    if SigDigits <= 1 then Exit('0');
    Exit('0.' + StringOfChar('0', SigDigits - 1));
  end;
  mag := Floor(Log10(Abs(x)) + 1e-12);
  decimals := (SigDigits - 1) - mag;
  if decimals < 0 then decimals := 0;
  rounded := RoundTo(x, -decimals);
  if rounded <> 0 then
  begin
    mag := Floor(Log10(Abs(rounded)) + 1e-12);
    decimals := (SigDigits - 1) - mag;
    if decimals < 0 then decimals := 0;
  end;
  if decimals = 0 then
    fmt := '0'
  else
    fmt := '0.' + StringOfChar('0', decimals);
  Result := FormatFloat(fmt, rounded, PointSettings);
end;

function FormatNumberAuto(x: Double; SigDigits: Integer; AllowScientific: Boolean): String;
const
  SciHighThreshold = 1e6;
  SciLowThreshold  = 1e-4;
var
  useScientific: Boolean;
  mag: Integer;
  mantissa: Double;
  mantStr: String;
begin
  useScientific := AllowScientific and (x <> 0) and
    ((Abs(x) >= SciHighThreshold) or (Abs(x) < SciLowThreshold));

  if not useScientific then
    Exit(FormatSignificant(x, SigDigits));

  mag := Floor(Log10(Abs(x)) + 1e-12);
  mantissa := x/Power(10, mag);
  mantStr := FormatSignificant(mantissa, SigDigits);
  if Abs(StrToFloatDef(mantStr, mantissa, PointSettings)) >= 10 then
  begin
    Inc(mag);
    mantissa := x/Power(10, mag);
    mantStr := FormatSignificant(mantissa, SigDigits);
  end;
  Result := mantStr + 'e' + IntToStr(mag);
end;

{ TSciEdit }

constructor TSciEdit.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FUnitFamily := ufAny;
  FCustomUnits := '';
  FSignificantDigits := 5;
  FOptions := DefaultSciEditOptions;
  FValue := 0;
  FBaseUnits := '';
  FPrefix := pkNone;
  FUnitFactor := 1.0;
  FUnitOffset := 0.0;
  FHasValue := False;
  FState := sesEmpty;
  FDetectedFamily := ufAny;
  FUpdating := False;
  FLastCommittedText := '';
  FBatchDepth := 0;
  FBatchPendingReparse := False;
  FTrackBar := nil;
  FTrackBarFactor := 2.0;
  FTrackBarRange := 100;
  FTrackBarReference := 0;
  FTrackBarSettleDelay := 150;
  FTrackBarSettleTimer := nil;
  FContextUnits := TStringList.Create;

  FErrorColor := clRed;
  FApplyingStateColor := False;
  FUserFontColor := Font.Color;
  FPrevFontOnChange := Font.OnChange;
  Font.OnChange := @FontChangedHandler;
end;

destructor TSciEdit.Destroy;
begin
  if Assigned(Font) then
    Font.OnChange := FPrevFontOnChange;
  SetTrackBar(nil);
  FContextUnits.Free;
  inherited Destroy;
end;

// Tracks the color the user (or the ancestor/theme) sets on Font.Color while
// we are NOT displaying an error, so a later error/restore cycle can put the
// exact same color back instead of clobbering it with a hardcoded default
procedure TSciEdit.FontChangedHandler(Sender: TObject);
begin
  if Assigned(FPrevFontOnChange) then FPrevFontOnChange(Sender);
  if (not FApplyingStateColor) and not (FState in [sesInvalidNumber, sesInvalidUnits, sesFamilyMismatch]) then
    FUserFontColor := Font.Color;
end;

procedure TSciEdit.ApplyErrorColor;
begin
  FApplyingStateColor := True;
  try
    Font.Color := FErrorColor;
  finally
    FApplyingStateColor := False;
  end;
end;

procedure TSciEdit.RestoreNormalColor;
begin
  FApplyingStateColor := True;
  try
    Font.Color := FUserFontColor;
  finally
    FApplyingStateColor := False;
  end;
end;

procedure TSciEdit.SetState(AState: TSciEditState);
begin
  FState := AState;
  if AState in [sesInvalidNumber, sesInvalidUnits, sesFamilyMismatch] then
    ApplyErrorColor
  else
    RestoreNormalColor;
end;

function TSciEdit.IsBatchUpdating: Boolean;
begin
  Result := FBatchDepth > 0;
end;

procedure TSciEdit.BeginUpdate;
begin
  Inc(FBatchDepth);
end;

procedure TSciEdit.EndUpdate;
begin
  if FBatchDepth <= 0 then Exit; // guard against unbalanced Begin/EndUpdate calls

  Dec(FBatchDepth);
  if (FBatchDepth = 0) and FBatchPendingReparse then
  begin
    FBatchPendingReparse := False;
    if Trim(Text) <> '' then
      DoParseInput;
  end;
end;

procedure TSciEdit.SetErrorColor(AValue: TColor);
begin
  if FErrorColor = AValue then Exit;
  FErrorColor := AValue;
  if FState in [sesInvalidNumber, sesInvalidUnits, sesFamilyMismatch] then
    ApplyErrorColor;
end;

procedure TSciEdit.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FTrackBar) then
    FTrackBar := nil;
end;

procedure TSciEdit.RealSetText(const AValue: TCaption);
begin
  inherited RealSetText(AValue);
  if (not FUpdating) and not (csLoading in ComponentState) then
  begin
    if IsBatchUpdating then
      FBatchPendingReparse := True
    else
      DoParseInput;
  end;
  // Keep the "last known" baseline in sync with every Text assignment
  FLastCommittedText := Text;
end;

procedure TSciEdit.Loaded;
begin
  inherited Loaded;
  if (Text <> '') and not FUpdating then
    DoParseInput;
end;

procedure TSciEdit.SetContextUnits(AValue: TStringList);
begin
  FContextUnits.Assign(AValue);
end;

function TSciEdit.DecomposeMyUnit(const AUnits: String; out APrefix: TSIPrefixKind;
  out AUnprefixed: String; out AFactor, AOffset: Double; out AFamily: TUnitFamily;
  out AFailure: TUnitParseFailure): Boolean;
begin
  Result := TUnitParser.DecomposeUnit(AUnits, FUnitFamily, FCustomUnits,
    APrefix, AUnprefixed, AFactor, AOffset, AFamily, AFailure);
end;

function TSciEdit.CanonicalFromValue(AValue: Double; APrefix: TSIPrefixKind; AFactor, AOffset: Double): Double;
begin
  Result := (AValue*Power(10, SIPrefixes[APrefix].Exponent))*AFactor + AOffset;
end;

function TSciEdit.ValueFromCanonical(ACanonical: Double; APrefix: TSIPrefixKind; AFactor, AOffset: Double): Double;
begin
  if AFactor <> 0 then
    Result := (ACanonical - AOffset)/(AFactor*Power(10, SIPrefixes[APrefix].Exponent))
  else
    Result := 0;
end;

function TSciEdit.GetCanonicalValue: Double;
begin
  if FHasValue then
    Result := CanonicalFromValue(FValue, FPrefix, FUnitFactor, FUnitOffset)
  else
    Result := 0;
end;

procedure TSciEdit.ConvertToUnits(const TargetUnits: String);
var
  TargetFam, prefFam: TUnitFamily;
  Factor, Offset, ACanonical, prefFactor, prefOffset: Double;
  targetPrefix, prefPrefix: TSIPrefixKind;
  unprefixedUnits, prefUnprefixed: String;
  failure: TUnitParseFailure;
begin
  if not FHasValue then Exit;

  if not DecomposeMyUnit(TargetUnits, targetPrefix, unprefixedUnits, Factor, Offset, TargetFam, failure) then
    raise ESciEditError.CreateFmt('"%s" is not a recognized unit.', [TargetUnits]);

  if TargetFam <> FDetectedFamily then
    raise ESciEditError.CreateFmt('Unit "%s" is incompatible with the current value''s family.', [TargetUnits]);

  SetState(sesValid);

  if (FBaseUnits = unprefixedUnits) and (FPrefix = targetPrefix) then Exit;

  ACanonical := GetCanonicalValue;

  if unprefixedUnits <> TUnitParser.GetBaseSymbolFor(TargetFam, FCustomUnits) then
    FOptions := FOptions - [seoCanonicalUnits];

  if (seoPreferredUnits in FOptions) and (Trim(FPreferredUnits) <> '') and
     DecomposeMyUnit(Trim(FPreferredUnits), prefPrefix, prefUnprefixed, prefFactor, prefOffset, prefFam, failure) and
     ((prefUnprefixed <> unprefixedUnits) or (prefPrefix <> targetPrefix)) then
    FOptions := FOptions - [seoPreferredUnits];

  FBaseUnits := unprefixedUnits;
  FUnitFactor := Factor;
  FUnitOffset := Offset;
  FPrefix := targetPrefix;
  FDetectedFamily := TargetFam;

  FValue := ValueFromCanonical(ACanonical, FPrefix, Factor, Offset);

  UpdateText;
  if Assigned(FOnValueChanged) then FOnValueChanged(Self, FValue);
end;

function TSciEdit.GetUnitDescription: String;
var
  idx, j: Integer;
  aliasList: String;
begin
  Result := '';
  if not FHasValue or (FDetectedFamily in [ufAny, ufCustom]) then Exit;

  idx := TUnitParser.GetFamilyInfoIndex(FDetectedFamily);
  if idx < 0 then Exit;

  Result := UnitFamilyInfos[idx].Name + ' [' + UnitFamilyInfos[idx].BaseSymbol + ']';
  aliasList := '';
  for j := 0 to UnitFamilyInfos[idx].AliasCount - 1 do
  begin
    if UnitFamilyInfos[idx].Aliases[j].Symbol <> '' then
    begin
      if aliasList <> '' then aliasList := aliasList + ', ';
      aliasList := aliasList + UnitFamilyInfos[idx].Aliases[j].Symbol;
    end;
  end;

  if aliasList <> '' then
    Result := Result + ' (Equivalents: ' + aliasList + ')';
end;

procedure TSciEdit.UpdateText;
var
  numStr, prefSym: String;
begin
  if FUpdating then Exit;
  if not FHasValue then Exit;

  numStr := FormatNumberAuto(FValue, FSignificantDigits, seoScientificNotation in FOptions);
  prefSym := TUnitParser.PrefixSymbolFor(FPrefix);

  FUpdating := True;
  try
    // Only append the space and unit if a unit or prefix actually exists
    if (prefSym <> '') or (FBaseUnits <> '') then
    begin
      Text := numStr + ' ' + prefSym + FBaseUnits;
      Hint := GetUnitDescription;
    end
    else
    begin
      Text := numStr;
      Hint := '';
    end;
  finally
    FUpdating := False;
  end;
end;

procedure TSciEdit.ApplyCanonicalValue(ACanonical: Double);
var
  bestExp: Integer;
  valBaseUnit: Double;
  prefPrefix: TSIPrefixKind;
  prefUnprefixed: String;
  prefFactor, prefOffset: Double;
  prefFam: TUnitFamily;
  prefFailure: TUnitParseFailure;
  custPrefix: TSIPrefixKind;
  custUnprefixed: String;
  custFactor, custOffset: Double;
  custFam: TUnitFamily;
  custFailure: TUnitParseFailure;
begin
  if not FHasValue then Exit;

  // On user request, if PreferredUnits is set and dimensionally compatible
  // with the value we're holding, use it
  if (seoPreferredUnits in FOptions) and (Trim(FPreferredUnits) <> '') and
     DecomposeMyUnit(Trim(FPreferredUnits), prefPrefix, prefUnprefixed, prefFactor, prefOffset, prefFam, prefFailure) and
     (prefFam = FDetectedFamily) then
  begin
    FBaseUnits := prefUnprefixed;
    FUnitFactor := prefFactor;
    FUnitOffset := prefOffset;
    FPrefix := prefPrefix;
    FValue := ValueFromCanonical(ACanonical, FPrefix, FUnitFactor, FUnitOffset);
    SetState(sesValid);
    UpdateText;
    if Assigned(FOnValueChanged) then FOnValueChanged(Self, FValue);
    Exit;
  end;

  if seoCanonicalUnits in FOptions then
  begin
    FBaseUnits := TUnitParser.GetBaseSymbolFor(FDetectedFamily, FCustomUnits);

    // Detect factor/offset for custom units
    if FDetectedFamily = ufCustom then
    begin
      if DecomposeMyUnit(FBaseUnits, custPrefix, custUnprefixed, custFactor, custOffset, custFam, custFailure) then
      begin
        FUnitFactor := custFactor;
        FUnitOffset := custOffset;
      end
      else
      begin
        FUnitFactor := 1.0;
        FUnitOffset := 0.0;
      end;
    end
    else
    begin
      FUnitFactor := 1.0;
      FUnitOffset := 0.0;
    end;
    valBaseUnit := ACanonical;
  end
  else
    valBaseUnit := ValueFromCanonical(ACanonical, pkNone, FUnitFactor, FUnitOffset);

  // Prevent auto-prefixes on dimensionless values (pure numbers)
  if (FDetectedFamily = ufNone) or (FBaseUnits = '') then
    bestExp := 0
  else if seoAutoUnits in FOptions then
    bestExp := TUnitParser.ChooseBestPrefixExponent(Abs(valBaseUnit))
  else
    bestExp := SIPrefixes[FPrefix].Exponent;

  FValue := valBaseUnit/Power(10, bestExp);
  FPrefix := TUnitParser.PrefixKindForExponent(bestExp);
  SetState(sesValid);
  UpdateText;
  if Assigned(FOnValueChanged) then FOnValueChanged(Self, FValue);
end;

procedure TSciEdit.ApplyTrackBarBounds;
begin
  if not Assigned(FTrackBar) then Exit;
  FUpdating := True;
  try
    FTrackBar.Min := -FTrackBarRange;
    FTrackBar.Max := FTrackBarRange;
  finally
    FUpdating := False;
  end;
  ResetTrackBarReference;
end;

procedure TSciEdit.ResetTrackBarReference;
begin
  if not Assigned(FTrackBar) then Exit;
  if Assigned(FTrackBarSettleTimer) then
    FTrackBarSettleTimer.Enabled := False;
  FTrackBarReference := GetCanonicalValue;
  FUpdating := True;
  try
    if FTrackBar.Position = 0 then
    begin
      // Reset the position
      FTrackBar.Position := 1;
      FTrackBar.Position := 0;
    end
    else
      FTrackBar.Position := 0;
  finally
    FUpdating := False;
  end;
end;

procedure TSciEdit.TrackBarChangeHandler(Sender: TObject);
var
  factor, newCanonical: Double;
begin
  if not (FUpdating or (not Assigned(FTrackBar)) or (not FHasValue)) then
  begin
    factor := Power(FTrackBarFactor, FTrackBar.Position/FTrackBarRange);
    newCanonical := FTrackBarReference*factor;
    ApplyCanonicalValue(newCanonical);
  end;
  if Assigned(FTrackBarOldOnChange) then FTrackBarOldOnChange(Sender);
end;

procedure TSciEdit.TrackBarSettleTimerHandler(Sender: TObject);
begin
  FTrackBarSettleTimer.Enabled := False;
  ResetTrackBarReference;
end;

procedure TSciEdit.TrackBarEnterHandler(Sender: TObject);
begin
  ResetTrackBarReference;
  if Assigned(FTrackBarOldOnEnter) then FTrackBarOldOnEnter(Sender);
end;

procedure TSciEdit.TrackBarMouseUpHandler(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  // Arm the timer to wait for any animations to finish
  if Assigned(FTrackBarSettleTimer) and (FTrackBarSettleDelay > 0) then
  begin
    FTrackBarSettleTimer.Enabled := False;
    FTrackBarSettleTimer.Enabled := True;
  end
  else
    ResetTrackBarReference;

  if Assigned(FTrackBarOldOnMouseUp) then
    FTrackBarOldOnMouseUp(Sender, Button, Shift, X, Y);
end;

procedure TSciEdit.TrackBarKeyUpHandler(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Arm the timer to wait for any animations to finish
  if Assigned(FTrackBarSettleTimer) and (FTrackBarSettleDelay > 0) then
  begin
    FTrackBarSettleTimer.Enabled := False;
    FTrackBarSettleTimer.Enabled := True;
  end
  else
    ResetTrackBarReference;

  if Assigned(FTrackBarOldOnKeyUp) then
    FTrackBarOldOnKeyUp(Sender, Key, Shift);
end;

procedure TSciEdit.SetPreferredUnits(const AUnits: String);
var
  normalized: String;
begin
  // Same autocorrection as CustomUnits, e.g. 'oC' -> '°C'.
  normalized := TUnitParser.NormalizeUnitsSpelling(AUnits);

  if FPreferredUnits = normalized then Exit;
  FPreferredUnits := normalized;

  if FHasValue and (Trim(normalized) <> '') then
    ConvertToUnits(normalized);
end;

function TSciEdit.GetValue: Double;
begin
  if not FHasValue then Exit(0.0);

  if Trim(FPreferredUnits) <> '' then
    Result := GetValueAs(FPreferredUnits)
  else
    Result := FValue;
end;

procedure TSciEdit.SetValue(AValue: Double);
var
  targetUnits: String;
begin
  // Never load a saved value, it comes from Text
  if csLoading in ComponentState then Exit;

  if Trim(FPreferredUnits) <> '' then
    SetValueAs(FPreferredUnits, AValue)
  else
  begin
    if FBaseUnits <> '' then
      targetUnits := TUnitParser.PrefixSymbolFor(FPrefix) + FBaseUnits
    else
      targetUnits := TUnitParser.GetBaseSymbolFor(FUnitFamily, FCustomUnits);

    if targetUnits <> '' then
      SetValueAs(targetUnits, AValue)
    else
    begin
      FValue := AValue;
      FHasValue := True;
      SetState(sesValid);
      UpdateText;
      if Assigned(FOnValueChanged) then FOnValueChanged(Self, FValue);

      ResetTrackBarReference;
    end;
  end;
end;

function TSciEdit.GetValueAs(const AUnits: String): Double;
var
  fam: TUnitFamily;
  factor, offset: Double;
  unitPrefix: TSIPrefixKind;
  unprefixed: String;
  failure: TUnitParseFailure;
begin
  if not FHasValue then Exit(0);

  if Trim(AUnits) = '' then
    Exit(GetCanonicalValue);

  if not DecomposeMyUnit(AUnits, unitPrefix, unprefixed, factor, offset, fam, failure) then
  begin
    if Assigned(FOnParseError) then FOnParseError(Self, AUnits);
    raise ESciEditError.CreateFmt('"%s" is not a recognized unit.', [AUnits]);
  end;

  // Compare against FDetectedFamily, not just FUnitFamily
  if fam <> FDetectedFamily then
  begin
    if Assigned(FOnParseError) then FOnParseError(Self, AUnits);
    raise ESciEditError.CreateFmt('Unit "%s" is incompatible with the current value''s family.', [AUnits]);
  end;

  Result := ValueFromCanonical(GetCanonicalValue, unitPrefix, factor, offset);
end;

procedure TSciEdit.SetValueAs(const AUnits: String; AValue: Double);
var
  fam: TUnitFamily;
  factor, offset, newCanonical: Double;
  unitPrefix: TSIPrefixKind;
  unprefixed: String;
  failure: TUnitParseFailure;
begin
  if not DecomposeMyUnit(AUnits, unitPrefix, unprefixed, factor, offset, fam, failure) then
  begin
    if Assigned(FOnParseError) then FOnParseError(Self, AUnits);
    raise ESciEditError.CreateFmt('"%s" is not a recognized unit.', [AUnits]);
  end;

  if (FUnitFamily <> ufAny) and (fam <> FUnitFamily) then
  begin
    if Assigned(FOnParseError) then FOnParseError(Self, AUnits);
    raise ESciEditError.CreateFmt('Unit "%s" is incompatible with the selected family.', [AUnits]);
  end;

  FBaseUnits := unprefixed;
  FPrefix := unitPrefix;
  FUnitFactor := factor;
  FUnitOffset := offset;
  FDetectedFamily := fam;

  newCanonical := CanonicalFromValue(AValue, unitPrefix, factor, offset);

  FValue := AValue;
  FHasValue := True;
  SetState(sesValid);

  if (seoAutoUnits in FOptions) or (seoPreferredUnits in FOptions) or (seoCanonicalUnits in FOptions) then
    ApplyCanonicalValue(newCanonical)
  else
  begin
    UpdateText;
    if Assigned(FOnValueChanged) then FOnValueChanged(Self, FValue);
  end;

  ResetTrackBarReference;
end;

procedure TSciEdit.SetUnitFamily(AFamily: TUnitFamily);
begin
  if FUnitFamily = AFamily then Exit;
  FUnitFamily := AFamily;

  if Trim(Text) <> '' then
  begin
    if IsBatchUpdating then
      FBatchPendingReparse := True
    else
      DoParseInput;
  end;
end;

procedure TSciEdit.SetOptions(AValue: TSciEditOptions);
begin
  if FOptions = AValue then Exit;
  FOptions := AValue;
  if FHasValue then
    ApplyCanonicalValue(GetCanonicalValue);
end;

procedure TSciEdit.SetTrackBar(ATrackBar: TTrackBar);
begin
  if FTrackBar = ATrackBar then Exit;

  if Assigned(FTrackBar) then
  begin
    FTrackBar.OnChange := FTrackBarOldOnChange;
    FTrackBar.OnEnter := FTrackBarOldOnEnter;
    FTrackBar.OnMouseUp := FTrackBarOldOnMouseUp;
    FTrackBar.OnKeyUp := FTrackBarOldOnKeyUp;
    FTrackBar.RemoveFreeNotification(Self);
  end;
  FreeAndNil(FTrackBarSettleTimer);

  FTrackBar := ATrackBar;
  FTrackBarOldOnChange := nil;
  FTrackBarOldOnEnter := nil;
  FTrackBarOldOnMouseUp := nil;
  FTrackBarOldOnKeyUp := nil;

  if Assigned(FTrackBar) then
  begin
    FTrackBar.FreeNotification(Self);
    FTrackBarOldOnChange := FTrackBar.OnChange;
    FTrackBarOldOnEnter := FTrackBar.OnEnter;
    FTrackBarOldOnMouseUp := FTrackBar.OnMouseUp;
    FTrackBarOldOnKeyUp := FTrackBar.OnKeyUp;
    FTrackBar.OnChange := @TrackBarChangeHandler;
    FTrackBar.OnEnter := @TrackBarEnterHandler;
    FTrackBar.OnMouseUp := @TrackBarMouseUpHandler;
    FTrackBar.OnKeyUp := @TrackBarKeyUpHandler;

    FTrackBarSettleTimer := TTimer.Create(Self);
    FTrackBarSettleTimer.Enabled := False;
    FTrackBarSettleTimer.Interval := FTrackBarSettleDelay;
    FTrackBarSettleTimer.OnTimer := @TrackBarSettleTimerHandler;

    ApplyTrackBarBounds;
  end;
end;

procedure TSciEdit.SetTrackBarFactor(AFactor: Double);
begin
  if AFactor <= 1 then AFactor := 2;
  FTrackBarFactor := AFactor;
end;

procedure TSciEdit.SetTrackBarRange(ARange: Integer);
begin
  if ARange < 1 then ARange := 1;
  if FTrackBarRange = ARange then Exit;
  FTrackBarRange := ARange;
  ApplyTrackBarBounds;
end;

procedure TSciEdit.SetTrackBarSettleDelay(AValue: Integer);
begin
  if AValue < 1 then AValue := 1;
  if FTrackBarSettleDelay = AValue then Exit;
  FTrackBarSettleDelay := AValue;
  if Assigned(FTrackBarSettleTimer) then
    FTrackBarSettleTimer.Interval := FTrackBarSettleDelay;
end;

procedure TSciEdit.SetSignificantDigits(ADigits: Integer);
begin
  if ADigits < 1 then ADigits := 1;
  if ADigits > 15 then ADigits := 15;
  if FSignificantDigits = ADigits then Exit;
  FSignificantDigits := ADigits;
  UpdateText;
end;

procedure TSciEdit.SetCustomUnits(const S: String);
var
  normalized: String;
begin
  // Autocorrect alternate spellings (e.g. 'oC', 'ºC') to their canonical form ('°C')
  normalized := TUnitParser.NormalizeUnitsSpelling(S);

  if FCustomUnits = normalized then Exit;
  FCustomUnits := normalized;

  if (FUnitFamily = ufCustom) and (Trim(Text) <> '') then
  begin
    if IsBatchUpdating then
      FBatchPendingReparse := True
    else
      DoParseInput;
  end;
end;

procedure TSciEdit.PopulateUnitContextMenu;
var
  idx, j: Integer;

  procedure AddItem(const ASymbol: String);
  var
    Item: TMenuItem;
  begin
    if ASymbol = '' then Exit;

    if (FContextUnits.Count > 0) and (FContextUnits.IndexOf(ASymbol) < 0) then Exit;

    Item := TMenuItem.Create(FUnitPopupMenu);
    Item.Caption := ASymbol;
    Item.Checked := (ASymbol = FBaseUnits);
    Item.OnClick := @UnitMenuItemClick;
    FUnitPopupMenu.Items.Add(Item);
  end;

begin
  if not Assigned(FUnitPopupMenu) then
    FUnitPopupMenu := TPopupMenu.Create(Self);

  FUnitPopupMenu.Items.Clear;
  if not FHasValue or (FDetectedFamily in [ufAny, ufCustom]) then Exit;

  idx := TUnitParser.GetFamilyInfoIndex(FDetectedFamily);
  if idx < 0 then Exit;

  AddItem(UnitFamilyInfos[idx].BaseSymbol);

  for j := 0 to UnitFamilyInfos[idx].AliasCount - 1 do
    AddItem(UnitFamilyInfos[idx].Aliases[j].Symbol);
end;

procedure TSciEdit.DoContextPopup(MousePos: TPoint; var Handled: Boolean);
begin
  inherited DoContextPopup(MousePos, Handled);
  if Handled then Exit;

  if FHasValue and not (FDetectedFamily in [ufAny, ufCustom]) and
     not (seoCanonicalUnits in FOptions) then
  begin
    PopulateUnitContextMenu;
    if FUnitPopupMenu.Items.Count > 0 then
    begin
      FUnitPopupMenu.PopUp(ClientToScreen(MousePos).X, ClientToScreen(MousePos).Y);
      Handled := True;
    end;
  end;
end;

procedure TSciEdit.UnitMenuItemClick(Sender: TObject);
begin
  if not (Sender is TMenuItem) then Exit;

  ConvertToUnits(StripHotkey(TMenuItem(Sender).Caption));
end;

procedure TSciEdit.DoParseInput;
var
  typedNumber, canonical, factor, offset: Double;
  fam: TUnitFamily;
  typedPrefix: TSIPrefixKind;
  matchedSymbol, effectiveUnit: String;
  failure: TUnitParseFailure;
  fallbackPrefix: TSIPrefixKind;
  fallbackUnprefixed: String;
  fallbackFactor, fallbackOffset: Double;
  fallbackFam: TUnitFamily;
begin
  if Trim(Text) = '' then
  begin
    FHasValue := False;
    SetState(sesEmpty);
    Exit;
  end;

  if TUnitParser.TryParseText(Text, FUnitFamily, FCustomUnits, typedNumber, canonical, fam, typedPrefix, matchedSymbol, factor, offset, failure) then
  begin
    // Fallback logic for pure numeric inputs
    if matchedSymbol = '' then
    begin
      if Trim(FPreferredUnits) <> '' then
        effectiveUnit := Trim(FPreferredUnits)
      else if (FUnitFamily <> ufAny) and (FUnitFamily <> ufNone) then
        effectiveUnit := TUnitParser.GetBaseSymbolFor(FUnitFamily, FCustomUnits)
      else
        effectiveUnit := '';

      if effectiveUnit <> '' then
      begin
        // Resolve effectiveUnit, to report why it failed
        if not DecomposeMyUnit(effectiveUnit, fallbackPrefix, fallbackUnprefixed, fallbackFactor, fallbackOffset, fallbackFam, failure) then
        begin
          SetState(sesInvalidUnits);
          if Assigned(FOnParseError) then FOnParseError(Self, Text);
        end
        else
          SetValueAs(effectiveUnit, typedNumber);
        Exit;
      end;
    end;

    // TryParseText already enforces family compatibility internally, so a
    // successful result here is guaranteed to match FUnitFamily already
    FDetectedFamily := fam;
    FHasValue := True;
    FPrefix := typedPrefix;
    FBaseUnits := matchedSymbol;
    FUnitFactor := factor;
    FUnitOffset := offset;

    // ApplyCanonicalValue decides the final displayed unit/prefix:
    //   1. seoCanonicalUnits (snap to base SI units)
    //   2. seoPreferredUnits (snap to PreferredUnits)
    //   3. seoAutoUnits (pick the best SI prefix)
    // With none of those set, keep exactly what the user typed
    if (seoCanonicalUnits in FOptions) or (seoPreferredUnits in FOptions) or (seoAutoUnits in FOptions) then
      ApplyCanonicalValue(canonical)
    else
    begin
      FValue := typedNumber;
      SetState(sesValid);
      UpdateText;
      if Assigned(FOnValueChanged) then FOnValueChanged(Self, FValue);
    end;

    ResetTrackBarReference;
  end
  else
  begin
    case failure of
      upfFamilyMismatch: SetState(sesFamilyMismatch);
      upfUnknownUnits:   SetState(sesInvalidUnits);
    else
      SetState(sesInvalidNumber);
    end;
    if Assigned(FOnParseError) then FOnParseError(Self, Text);
  end;
end;

procedure TSciEdit.EditingDone;
var
  userChangedText: Boolean;
begin
  if not FUpdating then
  begin
    // Compare it to the last text we know about to tell whether the user
    // really changed anything since then
    userChangedText := Text <> FLastCommittedText;
    DoParseInput;
    FLastCommittedText := Text;
    if userChangedText and Assigned(FOnUserEdit) then
      FOnUserEdit(Self);
  end;
  inherited EditingDone;
end;

procedure TSciEdit.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Key = VK_RETURN then
  begin
    EditingDone;
    Key := 0;
  end;
end;

procedure Register;
begin
  RegisterComponents('Science', [TSciEdit]);
end;

initialization
  PointSettings := DefaultFormatSettings;
  PointSettings.DecimalSeparator := '.';
  PointSettings.ThousandSeparator := #0;

  {$I LazScience.lrs}
end.
