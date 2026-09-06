unit uMain;

{$mode objfpc}{$H+}

{ ==============================================================================
 Description:
   This unit demonstrates a Universal Unit Converter using the TSciEdit
   component. It translates physical quantities entered by the user into
   compatible target units within the same dimensional unit family.

 Features & Mechanics:
   * Dynamic Input Parsing: Uses `edInput` (TSciEdit) to parse arbitrary
     physical quantities (e.g., '100 km/h', '12 in', '500 Pa').

   * Automatic Family Detection: Reads `edInput.DetectedFamily` to identify
     the physical dimension (Length, Velocity, Pressure, etc.) and populates
     `cbTargetUnit` (TComboBox) with valid target units and SI aliases from
     `UnitFamilyInfos`.

   * In-Place Conversion: Copies the parsed quantity into `edOutput` (a read-only
     TSciEdit) and executes `ConvertToUnits(TargetUnitStr)` to perform the
     mathematical unit conversion.

   * Defensive Error Handling: Intercepts `ESciEditError` exceptions when
     incompatible units are requested, clearing the result field and displaying
     user-friendly feedback in `lblError`.

   * Reactive UI Updates: Automatically updates conversion results on value
     changes or dropdown selections.
 ==============================================================================}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uSciEdit, uUnitParser;

type
  { TForm1 }
  TForm1 = class(TForm)
    lblInput: TLabel;
    edInput: TSciEdit;
    lblTarget: TLabel;
    cbTargetUnit: TComboBox;
    lblOutput: TLabel;
    edOutput: TSciEdit;
    lblError: TLabel;

    procedure cbTargetUnitChange(Sender: TObject);
    procedure cbTargetUnitEditingDone(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure edInputValueChanged(Sender: TObject; NewValue: Double);
  private
    FLastFamily: TUnitFamily;
    procedure UpdateTargetUnitsList;
    procedure DoConversion;
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  // Set up the output control to be read-only
  edOutput.ReadOnly := True;
  edOutput.Color := clBtnFace;

  FLastFamily := ufAny;

  // Initialize with default conversion values
  edInput.Text := '100 km/h';
  cbTargetUnit.Text := 'mph';
  UpdateTargetUnitsList;
  DoConversion;
end;

procedure TForm1.cbTargetUnitChange(Sender: TObject);
begin
  // Ensure selecting a item from the drop-down immediately triggers conversion
  DoConversion;
end;

procedure TForm1.cbTargetUnitEditingDone(Sender: TObject);
begin
  DoConversion;
end;

procedure TForm1.edInputValueChanged(Sender: TObject; NewValue: Double);
begin
  UpdateTargetUnitsList;
  DoConversion;
end;

procedure TForm1.UpdateTargetUnitsList;
var
  idx, i: Integer;
begin
  if not edInput.HasValue then Exit;

  // Repopulate list only if physical dimension family changes
  if edInput.DetectedFamily = FLastFamily then Exit;

  FLastFamily := edInput.DetectedFamily;

  cbTargetUnit.Items.BeginUpdate;
  try
    cbTargetUnit.Items.Clear;

    // Get array index for the detected unit family
    idx := TUnitParser.GetFamilyInfoIndex(FLastFamily);

    if idx >= 0 then
    begin
      // Add base SI symbol (e.g., 'm' for Length, 'm/s' for Velocity)
      cbTargetUnit.Items.Add(UnitFamilyInfos[idx].BaseSymbol);

      // Add all recognized aliases for this family
      for i := 0 to UnitFamilyInfos[idx].AliasCount - 1 do
      begin
        if UnitFamilyInfos[idx].Aliases[i].Symbol <> '' then
          cbTargetUnit.Items.Add(UnitFamilyInfos[idx].Aliases[i].Symbol);
      end;
    end;
  finally
    cbTargetUnit.Items.EndUpdate;
  end;

  if cbTargetUnit.Items.Count > 0 then
    cbTargetUnit.ItemIndex := 0;
end;

procedure TForm1.DoConversion;
var
  TargetUnitStr: String;
begin
  lblError.Caption := '';
  TargetUnitStr := Trim(cbTargetUnit.Text);

  if (not edInput.HasValue) or (TargetUnitStr = '') then
  begin
    edOutput.Text := '';
    Exit;
  end;

  try
    // Copy the original parsed value and units to the output field
    edOutput.Text := edInput.Text;

    // Perform unit conversion
    edOutput.ConvertToUnits(TargetUnitStr);
  except
    on E: ESciEditError do
    begin
      edOutput.Text := '';
      lblError.Caption := E.Message;
    end;
  end;
end;

end.
