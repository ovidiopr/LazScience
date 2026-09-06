unit uMain;

{$mode objfpc}{$H+}

{ ==============================================================================
 Description:
   This unit implements a real-time photon property converter that synchronizes
   Wavelength, Frequency, Energy, and Wavenumber using TSciEdit controls. Modifying
   any single property automatically recalculates and updates all others.

 Physics Principles:
   Light properties are linked via the speed of light (c) and Planck's constant (h):

  *Wavelength (λ): Spatial period of the wave (m).
  *Frequency (ν): Cycles per second (Hz).
     Calculated as: ν = c/λ
  *Energy (E): Photon energy quantum (eV).
     Calculated as: E = h*c/λ
  *Wavenumber (h): Spatial frequency (m-1 or cm^-1).
     Calculated as: h = 1/λ

 Physical Constants:
  *$c = 299,792,458 m/s (Speed of light in vacuum)
  *$h = 4.135667696 x 10^-15 eV*s (Planck's constant in eV)

 Component Integration & Architecture:
  *Event-Driven Synchronization: All four TSciEdit controls share a single
     `OnUserEdit` event handler (`SciEditUserEdit`). This event fires only on
     explicit user input or trackbar adjustments, preventing infinite loops.

  *Base-Unit Normalization: The handler checks `Sender` to determine which field
     was edited, converts the input value to a baseline Wavelength (λ) in
     meters, and uses this baseline to calculate all target values.

  *Preferred Units (`seoPreferredUnits`): Each control has `seoPreferredUnits`
     enabled in the LFM, allowing values assigned in standard SI base units
     (e.g., `ValueAs['m']` or `ValueAs['Hz']`) to be displayed automatically
     in target units ('nm', 'THz', 'eV', 'cm^-1').
 ==============================================================================}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uSciEdit, uUnitParser;

type
  { TForm1 }
  TForm1 = class(TForm)
    lblWavelength: TLabel;
    edWavelength: TSciEdit;
    lblFrequency: TLabel;
    edFrequency: TSciEdit;
    lblEnergy: TLabel;
    edEnergy: TSciEdit;
    lblWavenumber: TLabel;
    edWavenumber: TSciEdit;

    procedure SciEditUserEdit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

const
  C_LIGHT = 299792458.0;        // Speed of light in m/s
  H_PLANCK = 4.135667696e-15;   // Planck's constant in eV*s

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  // Initialize with standard visible light wavelength (500 nm green light)
  edWavelength.ValueAs['nm'] := 500.0;
  SciEditUserEdit(edWavelength);
end;

procedure TForm1.SciEditUserEdit(Sender: TObject);
var
  Wavelength_m: Double;
begin
  // Calculate the normalized base wavelength in meters based on active control
  if Sender = edWavelength then
    Wavelength_m := edWavelength.ValueAs['m']
  else if Sender = edFrequency then
    Wavelength_m := C_LIGHT/edFrequency.ValueAs['Hz']
  else if Sender = edEnergy then
    Wavelength_m := (H_PLANCK*C_LIGHT)/edEnergy.ValueAs['eV']
  else if Sender = edWavenumber then
    Wavelength_m := 1.0/edWavenumber.ValueAs['m^-1'];

  // Prevent division by zero or negative physical values
  if Wavelength_m <= 0 then Exit;

  // Broadcast calculated baseline values to all non-editing controls
  if Sender <> edWavelength then
    edWavelength.ValueAs['m'] := Wavelength_m;

  if Sender <> edFrequency then
    edFrequency.ValueAs['Hz'] := C_LIGHT/Wavelength_m;

  if Sender <> edEnergy then
    edEnergy.ValueAs['eV'] := (H_PLANCK*C_LIGHT)/Wavelength_m;

  if Sender <> edWavenumber then
    edWavenumber.ValueAs['m^-1'] := 1.0/Wavelength_m;
end;

end.
