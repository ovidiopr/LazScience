unit uPID;

{$mode objfpc}{$H+}
{$interfaces corba}

interface

uses
  Classes, SysUtils, Math;

type
  TSafetyStatus = (ssNormal, ssOutputSaturated, ssIntegralWindup,
                   ssDerivativeNoisy, ssTimeStepExcessive, ssMultipleFaults);

  TAntiWindupMode = (awClamping, awBackCalculation, awConditional);
  TDerivativeMode = (dmNone, dmLowPass, dmSimpleMovingAverage);

  { Controller configuration }
  TPIDConfig = record
    Kp, Ki, Kd: Double;

    OutputMax, OutputMin: Double;
    OutputRateLimit: Double;     // Slew rate limit (units per second)
    OutputFilterAlpha: Double;   // Smoothing: 0.0 = raw (no filter), 1.0 = maximum smoothing

    PLimit, ILimit, DLimit: Double;

    AntiWindupMode: TAntiWindupMode;
    AntiWindupGain: Double;

    DerivativeMode: TDerivativeMode;
    DerivativeFilterCoeff: Double; // 0..1, higher = smoother

    MaxDt, MinDt: Double;

    SetpointRamping: Boolean;
    SetpointRampRate: Double;
    MaxSetpointLead: Double;   // Max gap allowed between FInternalSetpoint and Measurement (0 = disabled)

    Deadband: Double;

    Kf_Loss: Double;
    AmbientGuess: Double;

    HotStartWindow: Double;
  end;

  { One update result }
  TPIDOutput = record
    Output: Double;
    P, I, D, FF: Double;
    Error: Double;
    EffectiveSetpoint: Double;
    SafetyStatus: TSafetyStatus;
    Dt: Double;
  end;

  { PID controller }
  TChivaPID = class
  private
    FConfig: TPIDConfig;

    FSetpoint: Double;
    FInternalSetpoint: Double;

    FIntegral: Double;

    FPrevMeasurement: Double;
    FPrevError: Double;
    FPrevOutput: Double;         // Stores the final filtered/limited output
    FPrevFilteredPID: Double;    // Stores the post-filter, pre-clamp PID sum (used by the EMA)

    FHasPrevMeasurement: Boolean;
    FHasPrevError: Boolean;

    FFilteredDerivative: Double;
    FDerivBuffer: array[0..4] of Double;
    FDtBuffer: array[0..4] of Double;

    FUpdateCount: UInt64;
    FMaxError: Double;
    FHotStartTimer: Double;  // Seconds elapsed since Reset; gates the hot-start snap

    function Clamp(Value, Limit: Double): Double;
    function ClampOutput(Value: Double): Double;
    function ClampDt(Dt: Double): Double;

    procedure UpdateSetpointRamp(Measurement, Dt: Double);

    function CalculateDerivative(Measurement, Dt: Double): Double;
    function UpdateIntegral(Error, Dt, TentativeOutput, FinalOutput: Double; OutputIsUnsaturated: Boolean): Double;
    function ApplyRateLimit(Output, Dt: Double): Double;
    function DetermineSafetyStatus(Output, Error, Dt: Double): TSafetyStatus;

    function UpdateCore(Error, Measurement, Dt: Double): TPIDOutput;
  public
    constructor Create(const AConfig: TPIDConfig);

    procedure Reset; overload;
    procedure Reset(AMeasurement: Double); overload;
    procedure Reset(AMeasurement, AInitialOutput: Double); overload;
    procedure SetSetpoint(Value: Double);
    procedure UpdateConfig(const AConfig: TPIDConfig);

    function Update(Measurement, Dt: Double): TPIDOutput;
    function UpdateFromError(Error, Dt: Double): TPIDOutput;

    property Config: TPIDConfig read FConfig;
    property InternalSetpoint: Double read FInternalSetpoint;
    property UpdateCount: UInt64 read FUpdateCount;
    property MaxError: Double read FMaxError;
  end;

function DefaultPIDConfig: TPIDConfig;

const
  PIDNumber = 1;
  PIDNames: Array [1..PIDNumber] of String = ('Heater');

implementation

function DefaultPIDConfig: TPIDConfig;
begin
  with Result do
  begin
    Kp := 1.0;
    Ki := 0.0;
    Kd := 0.0;

    OutputMin := 0.0;
    OutputMax := 1.0;
    OutputRateLimit := 0.0;
    OutputFilterAlpha := 0.0; // Default to no filtering (0.0 = raw)

    PLimit := Infinity;
    ILimit := 5.0;
    DLimit := 0.5;

    AntiWindupMode := awBackCalculation;
    AntiWindupGain := 1.0;

    DerivativeMode := dmLowPass;
    DerivativeFilterCoeff := 0.8;

    MinDt := 1e-4;
    MaxDt := 1.0;

    SetpointRamping := False;
    SetpointRampRate := 1.0;
    MaxSetpointLead := 5.0;   // Allow up to 5 units of lead before pausing the ramp

    Deadband := 0.0;

    Kf_Loss := 0.0;
    AmbientGuess := 298.15;  // 25 ºC

    HotStartWindow := 30.0;  // Snap active for the first 30 s after Reset
  end;
end;

constructor TChivaPID.Create(const AConfig: TPIDConfig);
begin
  inherited Create;
  FConfig := AConfig;
  Reset;
end;

procedure TChivaPID.Reset;
var
  i: Integer;
begin
  FIntegral := 0;
  FFilteredDerivative := 0;
  FPrevOutput := 0;
  FPrevFilteredPID := 0;

  FHasPrevMeasurement := False;
  FHasPrevError := False;

  FInternalSetpoint := FSetpoint;

  for i := 0 to 4 do
  begin
    FDerivBuffer[i] := 0;
    FDtBuffer[i] := FConfig.MinDt;
  end;

  FUpdateCount := 0;
  FMaxError := 0;
  FHotStartTimer := 0;
end;

procedure TChivaPID.Reset(AMeasurement: Double);
begin
  Reset;
  FInternalSetpoint := AMeasurement;
  FUpdateCount := 1;
end;

procedure TChivaPID.Reset(AMeasurement, AInitialOutput: Double);
begin
  Reset(AMeasurement);

  // Bumpless transfer: seed the integral so the first automatic output equals AInitialOutput
  FIntegral := Clamp(AInitialOutput - FConfig.Kf_Loss*(FInternalSetpoint - FConfig.AmbientGuess), FConfig.ILimit);
  // Seed the rate-limiter baseline so it does not fight the initial value
  FPrevOutput := AInitialOutput;
end;

procedure TChivaPID.SetSetpoint(Value: Double);
begin
  FSetpoint := Value;
  if not FConfig.SetpointRamping then
    FInternalSetpoint := Value;
end;

procedure TChivaPID.UpdateConfig(const AConfig: TPIDConfig);
begin
  // FIntegral stores the ready-to-use output contribution
  // Scaling it when Ki changes would cause an immediate output bump
  // If Ki is being disabled entirely, zero the integral to stop windup
  if AConfig.Ki <= 1e-9 then
    FIntegral := 0;
  FConfig := AConfig;
end;

function TChivaPID.Clamp(Value, Limit: Double): Double;
var L: Double;
begin
  L := Abs(Limit);
  if Value > L then Exit(L);
  if Value < -L then Exit(-L);
  Result := Value;
end;

function TChivaPID.ClampOutput(Value: Double): Double;
begin
  if Value > FConfig.OutputMax then Exit(FConfig.OutputMax);
  if Value < FConfig.OutputMin then Exit(FConfig.OutputMin);
  Result := Value;
end;

function TChivaPID.ClampDt(Dt: Double): Double;
begin
  if Dt < FConfig.MinDt then Exit(FConfig.MinDt);
  if Dt > FConfig.MaxDt then Exit(FConfig.MaxDt);
  Result := Dt;
end;

procedure TChivaPID.UpdateSetpointRamp(Measurement, Dt: Double);
var
  Diff, MaxStep: Double;
begin
  // Advance FInternalSetpoint toward FSetpoint at the nominal ramp rate
  Diff := FSetpoint - FInternalSetpoint;
  MaxStep := FConfig.SetpointRampRate*Dt;

  if Abs(Diff) <= MaxStep then
    FInternalSetpoint := FSetpoint
  else
    FInternalSetpoint := FInternalSetpoint + Sign(Diff)*MaxStep;
end;

function TChivaPID.CalculateDerivative(Measurement, Dt: Double): Double;
var
  RawD, Alpha, TotalTime: Double;
  i: Integer;
begin
  if not FHasPrevMeasurement then
  begin
    for i := 0 to 4 do
    begin
      FDerivBuffer[i] := Measurement;
      FDtBuffer[i] := Dt;
    end;
    FFilteredDerivative := 0;
    Exit(0);
  end;

  // Shift buffer and record current sample + its Dt
  for i := 4 downto 1 do
  begin
    FDerivBuffer[i] := FDerivBuffer[i - 1];
    FDtBuffer[i] := FDtBuffer[i - 1];
  end;
  FDerivBuffer[0] := Measurement;
  FDtBuffer[0] := Dt;

  case FConfig.DerivativeMode of
    dmNone:
      FFilteredDerivative := 0;

    dmLowPass:
      begin
        TotalTime := FDtBuffer[0] + FDtBuffer[1] + FDtBuffer[2] + FDtBuffer[3];
        if TotalTime < 1e-9 then TotalTime := 1e-9;
        Alpha := FConfig.DerivativeFilterCoeff;
        RawD := -(FDerivBuffer[0] - FDerivBuffer[4])/TotalTime;
        FFilteredDerivative := (Alpha*FFilteredDerivative) + ((1.0 - Alpha)*RawD);
      end;

    dmSimpleMovingAverage:
      begin
        RawD := 0;
        for i := 0 to 3 do
        begin
          if FDtBuffer[i] > 1e-9 then
            RawD += (FDerivBuffer[i] - FDerivBuffer[i+1])/FDtBuffer[i];
        end;
        FFilteredDerivative := -(RawD/4.0);
      end;
  end;

  Result := Clamp(FFilteredDerivative*FConfig.Kd, FConfig.DLimit);
end;

function TChivaPID.UpdateIntegral(Error, Dt, TentativeOutput, FinalOutput: Double; OutputIsUnsaturated: Boolean): Double;
var
  AvgError, Correction: Double;
begin
  if Abs(Error) < FConfig.Deadband then
    AvgError := 0
  else if FHasPrevError then
    AvgError := 0.5*(Error + FPrevError)
  else
    AvgError := Error;

  case FConfig.AntiWindupMode of
    awClamping:
      FIntegral := Clamp(FIntegral + AvgError*FConfig.Ki*Dt, FConfig.ILimit);

    awBackCalculation:
      begin
        // Compare what the PID wanted (Tentative) vs what actually happened (Final)
        // This includes Clamping, RateLimiting, and Filter Lag
        Correction := (FinalOutput - TentativeOutput)*FConfig.AntiWindupGain*Dt;
        FIntegral := Clamp(FIntegral + AvgError*FConfig.Ki*Dt + Correction, FConfig.ILimit);
      end;

    awConditional:
      // Only freeze integration when the output is actually saturated.
      if OutputIsUnsaturated then
        FIntegral := Clamp(FIntegral + AvgError*FConfig.Ki*Dt, FConfig.ILimit);
  end;

  Result := FIntegral;
end;

function TChivaPID.ApplyRateLimit(Output, Dt: Double): Double;
var
  MaxDelta, Delta: Double;
begin
  if FConfig.OutputRateLimit <= 0 then Exit(Output);

  MaxDelta := FConfig.OutputRateLimit*Dt;
  Delta := Output - FPrevOutput;

  if Delta > MaxDelta then
    Result := FPrevOutput + MaxDelta
  else if Delta < -MaxDelta then
    Result := FPrevOutput - MaxDelta
  else
    Result := Output;
end;

function TChivaPID.DetermineSafetyStatus(Output, Error, Dt: Double): TSafetyStatus;
var
  FaultCount: Integer;
  Saturated, Windup, Excessive: Boolean;
begin
  Saturated := (Output >= FConfig.OutputMax) or (Output <= FConfig.OutputMin);

  // Detect integral windup and excessive time step
  Windup := Abs(FIntegral) >= FConfig.ILimit;
  Excessive := Dt >= FConfig.MaxDt;

  FaultCount := Ord(Saturated) + Ord(Windup) + Ord(Excessive);

  if FaultCount > 1 then
    Result := ssMultipleFaults
  else if Saturated then
    Result := ssOutputSaturated
  else if Windup then
    Result := ssIntegralWindup
  else if Excessive then
    Result := ssTimeStepExcessive
  else
    Result := ssNormal;
end;

function TChivaPID.UpdateCore(Error, Measurement, Dt: Double): TPIDOutput;
var
  P, I, D, FF, RawPID, FilteredPID, ClampedPID: Double;
  OutputIsUnsaturated: Boolean;
begin
  if Abs(Error) > FMaxError then
    FMaxError := Abs(Error);

  // Calculate Standard Components
  P := Clamp(Error*FConfig.Kp, FConfig.PLimit);
  D := CalculateDerivative(Measurement, Dt);
  FF := FConfig.Kf_Loss*(FInternalSetpoint - FConfig.AmbientGuess);

  // Snapshot the integral contribution for this cycle before updating it
  I := FIntegral;

  // Initial Tentative Sum
  RawPID := P + I + D + FF;

  // On the very first cycle, seed the EMA filter with RawPID so there is no
  // drag toward 0 when an immediate non-zero output is needed
  if not FHasPrevMeasurement then
    FPrevFilteredPID := RawPID;

  // Apply low-pass filter (EMA: FPrevFilteredPID carries the previous filtered value)
  FilteredPID := ((1.0 - FConfig.OutputFilterAlpha)*RawPID) + (FConfig.OutputFilterAlpha*FPrevFilteredPID);
  FPrevFilteredPID := FilteredPID;

  // Clamp before rate limiting; record whether output is within bounds
  ClampedPID := ClampOutput(FilteredPID);
  OutputIsUnsaturated := (ClampedPID = FilteredPID);

  // Apply rate limiting
  Result.Output := ApplyRateLimit(ClampedPID, Dt);

  // Update integral (with back-calculation awareness of the filter/clamp/rate)
  UpdateIntegral(Error, Dt, RawPID, Result.Output, OutputIsUnsaturated);

  Result.P := P;
  Result.I := I;
  Result.D := D;
  Result.FF := FF;
  Result.Error := Error;
  Result.EffectiveSetpoint := FInternalSetpoint;
  Result.Dt := Dt;
  Result.SafetyStatus := DetermineSafetyStatus(Result.Output, Error, Dt);

  FPrevMeasurement := Measurement;
  FPrevError := Error;
  FPrevOutput := Result.Output;
  FHasPrevMeasurement := True;
  FHasPrevError := True;
end;

function TChivaPID.Update(Measurement, Dt: Double): TPIDOutput;
var
  ActualDt: Double;
begin
  Inc(FUpdateCount);
  ActualDt := ClampDt(Dt);

  if FConfig.SetpointRamping then
  begin
    if (FUpdateCount = 1) then
      FInternalSetpoint := Measurement
    else
    begin
      // Hot-start correction: if the measurement and FInternalSetpoint are on
      // opposite sides of the target setpoint, the ramp is chasing the process
      // variable from the wrong direction, typically because the system was hot
      FHotStartTimer := FHotStartTimer + ActualDt;
      if (FConfig.HotStartWindow > 0) and
         (FHotStartTimer <= FConfig.HotStartWindow) and
         ((Measurement - FSetpoint)*(FInternalSetpoint - FSetpoint) < 0) then
        FInternalSetpoint := Measurement;
    end;

    UpdateSetpointRamp(Measurement, ActualDt);
  end;

  Result := UpdateCore(FInternalSetpoint - Measurement, Measurement, ActualDt);
end;

// NOTE: SetpointRamping is intentionally not applied here. This method
// accepts a pre-computed error from an external source, so there is no
// measurement available to drive UpdateSetpointRamp or the MaxSetpointLead
// pacing clamp. If SetpointRamping = True, the caller is responsible for
// ensuring the supplied error is already relative to a ramped setpoint
function TChivaPID.UpdateFromError(Error, Dt: Double): TPIDOutput;
var
  ActualDt, FakeMeas: Double;
begin
  Inc(FUpdateCount);
  ActualDt := ClampDt(Dt);

  if FHasPrevError and FHasPrevMeasurement then
    FakeMeas := FPrevMeasurement - (Error - FPrevError)
  else
    FakeMeas := 0;

  Result := UpdateCore(Error, FakeMeas, ActualDt);
end;

end.
