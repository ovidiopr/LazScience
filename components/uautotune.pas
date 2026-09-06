unit uAutoTune;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Math, uPID;

type
  TAutotuneState = (
    atsIdle,      // Not started yet
    atsHeating,   // Driving toward SP with full power (initial heat-up)
    atsRunning,   // Collecting oscillation data
    atsComplete,  // Tuning succeeded; ResultConfig is valid
    atsFailed     // Tuning failed; FailureReason explains why
  );

  TTuningRules = (
    trTyreusLuyben,   // Conservative; recommended for thermal systems
    trZieglerNichols, // Classic; faster response but prone to overshoot
    trNoOvershoot     // Very conservative; use when overshoot is unacceptable
  );

  { Relay-feedback autotuner (Astrom-Hagglund method)

    Usage:
      1. Create an instance before starting the control loop
      2. While State is atsHeating or atsRunning, replace the PID output with
         the value returned by Update()
      3. When State = atsComplete, call PID.UpdateConfig(Tuner.ResultConfig)
         and resume normal PID control
      4. If State = atsFailed, inspect FailureReason and adjust plant
         parameters (typically qMax is too low or the system is too massive)

    The autotuner runs entirely within the existing control loop — there is
    no separate thread or blocking loop.

    Soft-relay operation:
      Instead of switching the output instantaneously between 0 and qMax
      (a hard relay), the autotuner ramps the output linearly over
      RampDuration seconds whenever the hysteresis threshold is crossed.
      This eliminates the abrupt voltage step that causes the thermoelectric
      artefact seen when the sensor is close to the heating element.
      Crossing and peak/valley detection are gated while a ramp is active,
      since the process variable is in a driven transition during that time.
      Set RampDuration to 0 to revert to hard-relay behaviour. }
  TRelayAutotuner = class
  private
    FSP: Double;
    FqMax: Double;
    FAlpha: Double;          // EMA filter weight on new sample (0..1)
    FHysteresis: Double;     // Relay dead-band
    FTimeoutLimit: Double;   // Seconds without a crossing before giving up
    FRampDuration: Double;   // Seconds over which the output transitions
    FRules: TTuningRules;

    FState: TAutotuneState;
    FOutput: Double;         // Current relay output (instantaneous, may be mid-ramp)
    FIntendedOutput: Double; // Logical relay target (0 or qMax); changes on threshold crossings
    FRampFrom: Double;       // Output value at the moment a ramp started
    FRampRemaining: Double;  // Seconds left in the current ramp (0 = no ramp active)

    FTFiltered: Double;
    FLastTFiltered: Double;
    FHasFirst: Boolean;      // True after the first measurement has been seen

    FElapsedTime: Double;    // Total simulation time since Reset
    FCrossCount: Integer;    // Upward SP crossings detected so far
    FStartTime: Double;      // Elapsed time at the first crossing
    FEndTime: Double;        // Elapsed time at the ninth crossing

    FPeakSum: Double;
    FValleySum: Double;
    FPeakCount: Integer;
    FValleyCount: Integer;
    FWasRising: Boolean;     // Slope direction in the previous step
    FHasDirection: Boolean;  // True after at least one step has been seen

    FTimeSinceLastCrossing: Double;

    FResultConfig: TPIDConfig;
    FFailureReason: string;

    function ComputeConfig(Ku, Pu: Double): TPIDConfig;

  public
    // SP              - Target setpoint the relay oscillates around
    // qMax            - Full relay output (e.g. heater wattage)
    // NoiseEstimate   - RMS noise on the measurement; used to set the relay
    //                   hysteresis.  Pass 0 and a safe minimum is used
    // Rules           - Tuning formula to apply once Ku/Pu are identified
    // TimeoutSeconds  - Simulation time allowed before the first oscillation
    //                   is declared impossible
    // RampDuration    - Seconds over which the output ramps between 0 and qMax
    //                   when a hysteresis threshold is crossed (soft-relay mode).
    //                   The ramp eliminates the abrupt voltage step that causes
    //                   a spurious temperature artefact when the sensor is
    //                   physically close to the heating element.
    //                   Rule of thumb: set it just above the artefact lifetime
    //                   you measured with the hard relay; the default of 35 s
    //                   covers artefacts up to ~25 s while being short enough
    //                   that thermal systems with a natural period of minutes
    //                   are unaffected.
    //                   Set to 0 to disable and restore original hard-relay
    //                   behaviour.
    constructor Create(SP, qMax, NoiseEstimate: Double;
                       Rules: TTuningRules = trTyreusLuyben;
                       TimeoutSeconds: Double = 300.0;
                       RampDuration: Double = 0.0);

    // Reset all state as if the object were freshly constructed
    procedure Reset;

    // Call once per control loop tick
    //   Measurement - current process variable reading
    //   Dt          - time elapsed since the last call (seconds)
    // Returns the relay output to apply to the plant
    // Check State after each call
    function Update(Measurement, Dt: Double): Double;

    property State: TAutotuneState read FState;
    // The output last returned by Update()
    property Output: Double read FOutput;
    // Valid only when State = atsComplete
    property ResultConfig: TPIDConfig read FResultConfig;
    // Non-empty when State = atsFailed
    property FailureReason: string read FFailureReason;
    // Seconds remaining in the current output ramp; 0 when idle (diagnostic use)
    property RampRemaining: Double read FRampRemaining;
  end;

implementation

constructor TRelayAutotuner.Create(SP, qMax, NoiseEstimate: Double;
                                    Rules: TTuningRules;
                                    TimeoutSeconds: Double;
                                    RampDuration: Double);
begin
  inherited Create;
  FSP := SP;
  FqMax := qMax;
  FAlpha := 0.3;
  FHysteresis := Max(0.05, NoiseEstimate*1.5);
  FTimeoutLimit := TimeoutSeconds;
  FRampDuration := Max(0.0, RampDuration);
  FRules := Rules;
  Reset;
end;

procedure TRelayAutotuner.Reset;
begin
  FState := atsHeating;
  FOutput := FqMax;   // Start with full power to drive toward SP
  FIntendedOutput := FqMax;
  FRampFrom := FqMax;
  FRampRemaining := 0;
  FHasFirst := False;
  FElapsedTime := 0;
  FCrossCount := 0;
  FStartTime := 0;
  FEndTime := 0;
  FPeakSum := 0;
  FValleySum := 0;
  FPeakCount := 0;
  FValleyCount := 0;
  FWasRising := False;
  FHasDirection := False;
  FTimeSinceLastCrossing := 0;
  FTFiltered := 0;
  FLastTFiltered := 0;
  FResultConfig := DefaultPIDConfig;
  FFailureReason := '';
end;

function TRelayAutotuner.ComputeConfig(Ku, Pu: Double): TPIDConfig;
begin
  Result := DefaultPIDConfig;

  case FRules of
    trTyreusLuyben:
    begin
      // Recommended for thermal systems: slow integral, small derivative
      Result.Kp := Ku/3.5;
      Result.Ki := Result.Kp/(Pu*2.2);
      Result.Kd := Result.Kp*(Pu/6.3);
    end;

    trZieglerNichols:
    begin
      // Classic rules: good step response but typically ~25% overshoot
      Result.Kp := 0.6*Ku;
      Result.Ki := Result.Kp/(0.5*Pu);
      Result.Kd := Result.Kp*(0.125*Pu);
    end;

    trNoOvershoot:
    begin
      // Very conservative variant: essentially, no overshoot
      Result.Kp := Ku/5.0;
      Result.Ki := Result.Kp/(Pu*3.0);
      Result.Kd := Result.Kp*(Pu/12.0);
    end;
  end;
end;

function TRelayAutotuner.Update(Measurement, Dt: Double): Double;
const
  NumCrossCount = 9;
var
  NewIntended: Double;
  Rising: Boolean;
  Amplitude, Ku, Pu: Double;
  Ramping: Boolean;
begin
  if FState in [atsComplete, atsFailed, atsIdle] then
    Exit(0);

  FElapsedTime := FElapsedTime + Dt;
  FTimeSinceLastCrossing := FTimeSinceLastCrossing + Dt;

  // EMA filter
  if not FHasFirst then
  begin
    FTFiltered := Measurement;
    FLastTFiltered := Measurement;
    FHasFirst := True;
  end
  else
    FLastTFiltered := FTFiltered;

  FTFiltered := (FAlpha*Measurement) + ((1.0 - FAlpha)*FTFiltered);

  // Soft relay
  // Determine the logical relay target from the hysteresis thresholds.
  // The intended output is level-sensitive (sticky inside the dead-band).
  NewIntended := FIntendedOutput;
  if FTFiltered < (FSP - FHysteresis) then
    NewIntended := FqMax
  else if FTFiltered > (FSP + FHysteresis) then
    NewIntended := 0;

  // On every change of logical target, start a fresh ramp from wherever
  // the output currently is.  If a ramp is already in progress and the
  // target reverses (unusual but possible with a very fast plant), the
  // new ramp simply continues from the current mid-ramp value.
  if NewIntended <> FIntendedOutput then
  begin
    FIntendedOutput := NewIntended;
    FRampFrom := FOutput;   // start from the current instantaneous value
    FRampRemaining := FRampDuration;
    // Discard slope direction; peak/valley tracking will restart cleanly once
    // the ramp ends and the process variable is settling under steady drive.
    FHasDirection := False;
  end;

  // Advance the ramp and update the physical output.
  if FRampRemaining >= 0 then
  begin
    FRampRemaining := Max(0.0, FRampRemaining - Dt);
    if FRampDuration > 0 then
      // Linear interpolation: full ramp_from at t=0, full intended at t=ramp_duration.
      FOutput := FIntendedOutput + (FRampFrom - FIntendedOutput)*(FRampRemaining/FRampDuration)
    else
      FOutput := FIntendedOutput;  // RampDuration = 0: hard relay (instant switch)
  end;
  // When FRampRemaining = 0, FOutput already equals FIntendedOutput from the
  // final interpolation step; no additional assignment is needed.

  Ramping := FRampRemaining > 0;

  // Crossing detection (upward crossings only), gated during ramp
  if (not Ramping) and (FLastTFiltered <= FSP) and (FTFiltered > FSP) then
  begin
    Inc(FCrossCount);
    FTimeSinceLastCrossing := 0;

    if FCrossCount = 1 then
    begin
      FStartTime := FElapsedTime;
      FState := atsRunning;
    end;

    if FCrossCount = NumCrossCount then
      FEndTime := FElapsedTime;
  end;

  // Peak/valley tracking, also gated during ramp
  if (not Ramping) and (FCrossCount >= 1) then
  begin
    Rising := (FTFiltered > FLastTFiltered);

    if FHasDirection and (Rising <> FWasRising) then
    begin
      if (not Rising) and (FLastTFiltered > FSP + FHysteresis) then
      begin
        // Rising --> Falling above the upper band: FLastTFiltered is the peak.
        FPeakSum += FLastTFiltered;
        Inc(FPeakCount);
      end
      else if Rising and (FLastTFiltered < FSP - FHysteresis) then
      begin
        // Falling --> Rising below the lower band: FLastTFiltered is the valley.
        FValleySum += FLastTFiltered;
        Inc(FValleyCount);
      end;
    end;

    FWasRising := Rising;
    FHasDirection := True;
  end;

  // Timeout/completion checks
  if (FCrossCount < 2) and (FTimeSinceLastCrossing > FTimeoutLimit) then
  begin
    FState := atsFailed;
    FFailureReason := 'Timeout: no oscillation detected within ' +
                      FloatToStrF(FTimeoutLimit, ffFixed, 0, 0) + 's. ' +
                      'Try increasing qMax or decreasing system mass.';
    Result := 0;
    Exit;
  end;

  if FCrossCount >= NumCrossCount then
  begin
    if (FPeakCount > 0) and (FValleyCount > 0) then
    begin
      Amplitude := ((FPeakSum/FPeakCount) - (FValleySum/FValleyCount))/2.0;
      Pu := (FEndTime - FStartTime)/(FCrossCount - 1);

      if Amplitude > 1e-9 then
      begin
        Ku := (2.0*FqMax)/(Pi*Amplitude);
        FResultConfig := ComputeConfig(Ku, Pu);
        FState := atsComplete;
      end
      else
      begin
        FState := atsFailed;
        FFailureReason := 'Oscillation amplitude is too small to measure reliably.';
      end;
    end
    else
    begin
      FState := atsFailed;
      FFailureReason := 'Insufficient peaks or valleys were captured.';
    end;
  end;

  Result := FOutput;
end;

end.
