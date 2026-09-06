unit uHeaterModel;

{$mode ObjFPC}{$H+}

interface

uses Classes, SysUtils, Math;

type
  THeaterModel = class
  private
    FCp: Double;              // Specific Heat (kJ/kg/K)
    FMass: Double;            // Mass (kg)
    FConvectionRate: Double;  // kW/K (Linear loss)
    FRadiativeRate: Double;   // kW/K^4 (Non-linear loss, usually very small)
    FTemperature: Double;     // Internal Element Temperature (K)
    FTAmbient: Double;        // Ambient Temperature (K)

    // Delay Simulation (Dead Time)
    FDelayBuffer: array of Double;
    FDelayIndex: Integer;

    const STEFAN_BOLTZMANN = 5.67e-11; // Example scaled constant
  public
    procedure Initialize(const initialT, Cp, mass, convectionRate, TAmbient: Double; DelaySeconds: Double = 2.0; dt: Double = 0.1);

    function CalcTemperature(const duty, deltaTime: Double): Double;

    property ElementTemperature: Double read FTemperature; // Core temp
    property Ambient: Double read FTAmbient write FTAmbient;
  end;

implementation

procedure THeaterModel.Initialize(const initialT, Cp, mass, convectionRate,
  TAmbient: Double; DelaySeconds: Double = 2.0; dt: Double = 0.1);
var
  BufferSize, i: Integer;
begin
  FTemperature := initialT;
  FCp := Cp;
  FMass := mass;
  FConvectionRate := convectionRate;
  FRadiativeRate := 0.00000001; // Small default for realistic high-temp loss
  FTAmbient := TAmbient;

  // Initialize Dead Time Buffer
  BufferSize := Max(1, Round(DelaySeconds/dt));
  SetLength(FDelayBuffer, BufferSize);
  for i := 0 to High(FDelayBuffer) do
    FDelayBuffer[i] := initialT;
  FDelayIndex := 0;
end;

function THeaterModel.CalcTemperature(const duty, deltaTime: Double): Double;
var
  dQ_conv, dQ_rad, Net_dQ: Double;
begin
  // Convective Loss (Linear)
  dQ_conv := (FTAmbient - FTemperature)*FConvectionRate;

  // Radiative Loss (Non-linear: T^4)
  // High temp surfaces lose heat much faster
  dQ_rad := STEFAN_BOLTZMANN*FRadiativeRate*(Power(FTAmbient, 4) - Power(FTemperature, 4));

  // Thermal Mass calculation
  Net_dQ := duty + dQ_conv + dQ_rad;
  FTemperature := FTemperature + (Net_dQ*deltaTime)/(FMass*FCp);

  // Simulate Sensor Delay (Transport Delay)
  // The sensor doesn't see the element temp immediately
  Result := FDelayBuffer[FDelayIndex]; // Return the "old" temperature
  FDelayBuffer[FDelayIndex] := FTemperature; // Store the "new" temperature

  Inc(FDelayIndex);
  if FDelayIndex > High(FDelayBuffer) then FDelayIndex := 0;
end;

end.
