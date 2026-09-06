unit uMain;

{$mode objfpc}{$H+}

{==============================================================================
 Description:
   This unit serves as a diagnostic and demonstration interface for the
   TSciEdit component. It allows developers to observe how the component
   parses textual input into numerical values, physical units, SI prefixes,
   and canonical (base) values.

 Features Demonstrated:
   * State Inspection: The UI continuously updates to reveal the internal
     properties of the TSciEdit (Parsed Value, Detected Family, Detected
     Unit, SI Prefix, and Canonical Value) whenever the input changes.

   * Dynamic Constraints (UnitFamily): A ComboBox lets the user modify the
     permitted UnitFamily (e.g., restricting input strictly to Length or
     Mass) at runtime. Changing this forces the component to immediately
     re-evaluate its current text.

   * TrackBar Integration: The component is linked directly to a TTrackBar
     (via the object inspector/LFM). Moving the slider scales the underlying
     canonical value by a specific factor (TrackBarFactor) without requiring
     any manual event routing.

   * Canonical Units (seoCanonicalUnits): When enabled, this option forces
     non-base units to automatically convert to their SI base equivalent
     (e.g., typing "1 bar" converts to "100 kPa" or "100000 Pa").

   * Auto Units (seoAutoUnits): When enabled, the component automatically
     adjusts the SI prefix to keep the numerical portion at a readable
     magnitude (e.g., changing "0.005 m" to "5 mm").

   * Preferred Units (seoPreferredUnits): Allows the developer to designate
     a specific unit string. If the user types a compatible unit (e.g.,
     typing "1 ft" when the preferred unit is "in"), the component will
     automatically snap the value into the preferred unit ("12 in").

   * Strict Validation and Reversion: Leverages the OnParseError event to
     catch invalid inputs or unit family mismatches. If an error occurs,
     it alerts the user, logs the error, and reverts the input field back
     to its last known valid state (FLastValidText).

   * Action Logging & Manual Reformatting: A TMemo records real-time updates,
     and a dedicated button forces the component to re-apply optimal text
     formatting by calling EditingDone.
 ==============================================================================}
interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ComCtrls,
  ExtCtrls, TypInfo, uSciEdit, uUnitParser;

type
  { TForm1 }

  TForm1 = class(TForm)
    BtnReformat: TButton;
    BtnSetPref: TButton;
    ChkCanonical: TCheckBox;
    ChkAutoUnits: TCheckBox;
    ComboBoxFamily: TComboBox;
    EdPreferred: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    LblFamily: TLabel;
    LblValue: TLabel;
    LblUnit: TLabel;
    LblPrefix: TLabel;
    LblCanonical: TLabel;
    MemoLog: TMemo;
    TrackBar1: TTrackBar;
    SciEdit1: TSciEdit;

    procedure BtnReformatClick(Sender: TObject);
    procedure BtnSetPrefClick(Sender: TObject);
    procedure ChkAutoUnitsChange(Sender: TObject);
    procedure ChkCanonicalChange(Sender: TObject);
    procedure ComboBoxFamilyChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure SciEdit1ParseError(Sender: TObject; const RawText: String);
    procedure SciEdit1ValueChanged(Sender: TObject; NewValue: Double);
  private
    FLastValidText: String;
    FLastValidUnits: TUnitFamily;
    procedure LogMsg(const AMsg: String);
    procedure UpdateDetails;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  // Set an initial starting quantity
  SciEdit1.ValueAs['mm'] := 12.5;
  FLastValidText := SciEdit1.Text;
  FLastValidUnits := SciEdit1.DetectedFamily;
  UpdateDetails;
  LogMsg('Application started. Initial value set.');
end;

procedure TForm1.LogMsg(const AMsg: String);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + ' - ' + AMsg);
  // Auto-scroll to bottom
  MemoLog.SelStart := Length(MemoLog.Text);
end;

procedure TForm1.UpdateDetails;
begin
  LblValue.Caption := Format('Parsed Value: %g', [SciEdit1.Value]);
  LblFamily.Caption := 'Detected Family: ' + GetEnumName(TypeInfo(TUnitFamily), Ord(SciEdit1.DetectedFamily));
  LblUnit.Caption := Format('Detected Unit: %s', [SciEdit1.BaseUnits]);
  LblPrefix.Caption := 'Detected Prefix: ' + GetEnumName(TypeInfo(TSIPrefixKind), Ord(SciEdit1.Prefix));
  LblCanonical.Caption := Format('Canonical (Base) Value: %g', [SciEdit1.CanonicalValue]);
end;

procedure TForm1.ComboBoxFamilyChange(Sender: TObject);
var
  EnumIndex: Integer;
begin
  LogMsg('Changing UnitFamily constraint to: ' + ComboBoxFamily.Text);
  if ComboBoxFamily.ItemIndex > -1 then
  begin
    // Get the integer index of the enum from the string
    EnumIndex := GetEnumValue(TypeInfo(TUnitFamily), ComboBoxFamily.Text);

    // Cast the integer back to the enum type
    if EnumIndex <> -1 then
      SciEdit1.UnitFamily := TUnitFamily(EnumIndex);
  end;
  // Force the component to re-validate the current text against the new family
  SciEdit1.Text := SciEdit1.Text;
end;

procedure TForm1.ChkCanonicalChange(Sender: TObject);
begin
  if ChkCanonical.Checked then
    SciEdit1.Options := SciEdit1.Options + [seoCanonicalUnits]
  else
    SciEdit1.Options := SciEdit1.Options - [seoCanonicalUnits];
  LogMsg('seoCanonicalUnits toggled: ' + BoolToStr(ChkCanonical.Checked, True));
end;

procedure TForm1.ChkAutoUnitsChange(Sender: TObject);
begin
  if ChkAutoUnits.Checked then
    SciEdit1.Options := SciEdit1.Options + [seoAutoUnits]
  else
    SciEdit1.Options := SciEdit1.Options - [seoAutoUnits];
  LogMsg('seoAutoUnits toggled: ' + BoolToStr(ChkAutoUnits.Checked, True));
end;

procedure TForm1.BtnSetPrefClick(Sender: TObject);
begin
  SciEdit1.PreferredUnits := Trim(EdPreferred.Text);
  if SciEdit1.PreferredUnits <> '' then
    SciEdit1.Options := SciEdit1.Options + [seoPreferredUnits]
  else
    SciEdit1.Options := SciEdit1.Options - [seoPreferredUnits];
  LogMsg('Preferred unit set to: "' + SciEdit1.PreferredUnits + '"');
end;

procedure TForm1.SciEdit1ValueChanged(Sender: TObject; NewValue: Double);
begin
  // Save state for strict reversion
  FLastValidText := SciEdit1.Text;
  FLastValidUnits := SciEdit1.DetectedFamily;

  UpdateDetails;
  LogMsg(Format('Value Changed: %s (Canonical: %g)', [SciEdit1.Text, NewValue]));
end;

procedure TForm1.SciEdit1ParseError(Sender: TObject; const RawText: String);
begin
  LogMsg('ERROR: Invalid input or wrong unit family -> "' + RawText + '"');

  // Strict Validation: Revert the text to the last known good state
  SciEdit1.OnParseError := nil;
  try
    if (FLastValidUnits = SciEdit1.UnitFamily) or (SciEdit1.UnitFamily = ufAny) then
    begin
      ShowMessageFmt('"%s" is not a valid entry for the current Unit Family. Reverting.', [RawText]);
      SciEdit1.Text := FLastValidText;
    end
    else
      ShowMessageFmt('"%s" is not a valid entry for the current Unit Family.', [RawText]);
  finally
    SciEdit1.OnParseError := @SciEdit1ParseError;
  end;
end;

procedure TForm1.BtnReformatClick(Sender: TObject);
begin
  // Re-apply optimal formatting based on standard component behavior
  SciEdit1.EditingDone;
  LogMsg('Forced text formatting.');
end;

end.
