# TSciPID

`TSciPID` is a Lazarus/Free Pascal (LCL) component that implements a full-featured PID controller with an Object-Inspector-friendly interface, thread-safe access, and a built-in relay-feedback autotuner. Drop it on a form or data module, tune it from the Object Inspector or from code, and drive it once per control-loop tick with a measurement and a time step.

It's built for real control loops — DAQ threads, hardware timers, embedded-style polling — not just simulations: every entry point is safe to call from a worker thread while the main thread reads status or edits tuning, and UI-facing events can be automatically marshalled onto the main thread.

## How the PID works

Each call to `Update(Measurement, Dt)` runs one control cycle:

1. **Setpoint handling.** If `SetpointRamping` is enabled, the internal setpoint is moved a bounded step toward the real `Setpoint` instead of jumping instantly (see [Setpoint ramping](#setpoint-ramping) below). The error used everywhere else is `InternalSetpoint - Measurement`.
2. **Proportional term:** `P = Error * Kp`, clamped to `± PLimit`.
3. **Derivative term:** computed from the measurement (not the error, which avoids "derivative kick" on setpoint changes), optionally smoothed by a low-pass filter or a short moving average, then multiplied by `Kd` and clamped to `± DLimit`. See [Derivative filtering](#derivative-filtering).
4. **Feed-forward term:** `FF = Kf_Loss * (InternalSetpoint - AmbientGuess)` — an optional linear estimate of steady-state loss (e.g. heat loss to ambient), added directly to the output so the integral term doesn't have to build up that offset from scratch. Leave `Kf_Loss = 0` to disable it.
5. **Integral term:** the previous cycle's accumulated integral (`I`) is added into the sum; the integral itself is then updated *after* the output is computed, using one of three anti-windup strategies (see [Anti-windup](#anti-windup-modes)) and an error deadband (see below).
6. **Sum, filter, clamp, rate-limit:** `RawPID = P + I + D + FF` is smoothed by an exponential-moving-average output filter (`OutputFilterAlpha`), clamped to `[OutputMin, OutputMax]`, and finally passed through a slew-rate limiter (`OutputRateLimit`) so the output can't change faster than a given amount per second.
7. **Safety status** is computed from the final output and internal state (see [Safety status](#safety-status)) and returned alongside the numeric result.

Every `Update`/`UpdateFromError` call returns a `TPIDOutput` record with the full breakdown — `Output`, `P`, `I`, `D`, `FF`, `Error`, `EffectiveSetpoint`, `Dt`, and `SafetyStatus` — so a UI or logger can show exactly what each term is contributing, not just the final number.

### Deadband

If `Abs(Error) < Deadband`, the integral is fed 0 for that cycle instead of the real error — this prevents slow integral creep from sensor/process noise sitting right at the setpoint. It only affects the integral; `P` and `D` still see the real error.

### Anti-windup modes

Integral windup is what happens when the output is saturated (or otherwise prevented from reaching what the raw PID sum demands) but the integral keeps accumulating anyway, causing a large overshoot once the constraint is lifted. `AntiWindupMode` selects the strategy:

- **`awClamping`** — the integral is simply clamped to `± ILimit` every cycle. Simple, but keeps integrating right up against the limit while saturated.
- **`awBackCalculation`** *(default)* — compares what the PID actually wanted to output (`RawPID`, before filtering/clamping/rate-limiting) against what it was actually allowed to output, and feeds the difference back into the integral, scaled by `AntiWindupGain`. This accounts for saturation, the output filter, and the rate limiter all at once, so it's the most robust general-purpose choice.
- **`awConditional`** — integration is simply frozen whenever the final output is at `OutputMin`/`OutputMax`, and proceeds normally otherwise.

### Derivative filtering

Raw derivatives amplify measurement noise, so `DerivativeMode` selects how the slope of the measurement is estimated:

- **`dmNone`** — derivative term is always 0.
- **`dmLowPass`** *(default)* — an exponential moving average of the raw slope, smoothed by `DerivativeFilterCoeff` (0 = no smoothing, closer to 1 = heavier smoothing/more lag). Computed over a short internal buffer of the last 5 samples for extra noise immunity.
- **`dmSimpleMovingAverage`** — averages the slope over the same 5-sample buffer without the EMA history term.

### Setpoint ramping

When `SetpointRamping = True`, the setpoint the controller actually chases (`InternalSetpoint`) moves toward `Setpoint` at a maximum rate of `SetpointRampRate` (setpoint units per second) instead of stepping instantly — useful for processes (ovens, motors) that shouldn't be commanded to jump instantly. A **hot-start correction** guards against starting a ramp from the wrong side: for the first `HotStartWindow` seconds after a `Reset`, if the measurement and the internal setpoint are on opposite sides of the real setpoint (e.g. the plant was already hot when the ramp started), the internal setpoint snaps to the measurement so the ramp doesn't fight the process in the wrong direction. `MaxSetpointLead` is reserved for pacing the ramp relative to the actual measurement.

### Safety status

`TPIDOutput.SafetyStatus` reports what's currently limiting the controller, computed fresh every cycle:

| Status | Meaning |
|---|---|
| `ssNormal` | Nothing unusual. |
| `ssOutputSaturated` | Output is pinned at `OutputMin` or `OutputMax`. |
| `ssIntegralWindup` | The integral term is at its `ILimit`. |
| `ssTimeStepExcessive` | `Dt` (after clamping) is at `MaxDt` — the loop is running slower than expected. |
| `ssMultipleFaults` | More than one of the above is true simultaneously. |

### Bumpless start/reset

`Reset` clears all internal history (integral, derivative buffers, previous error/measurement). The overload `Reset(AMeasurement, AInitialOutput)` additionally back-solves the integral term so the very next `Update` call produces `AInitialOutput` without a bump — useful when handing control from manual/open-loop operation to the PID, or when the autotuner hands control back after `AutoApply`.

## Configuration parameters (`Config`)

| Property | Description |
|---|---|
| `Kp`, `Ki`, `Kd` | Proportional, integral, and derivative gains. |
| `OutputMax`, `OutputMin` | Hard clamp applied to the final output. |
| `OutputRateLimit` | Maximum rate of change of the output, in output-units per second. `0` disables rate limiting. |
| `OutputFilterAlpha` | EMA smoothing applied to the P+I+D+FF sum before clamping. `0.0` = no filtering (raw), closer to `1.0` = heavier smoothing. |
| `PLimit`, `ILimit`, `DLimit` | Independent clamps on the P, I, and D contributions (not the final output). |
| `AntiWindupMode` | `awClamping`, `awBackCalculation` (default), or `awConditional` — see above. |
| `AntiWindupGain` | Correction gain used only by `awBackCalculation`. |
| `DerivativeMode` | `dmNone`, `dmLowPass` (default), or `dmSimpleMovingAverage` — see above. |
| `DerivativeFilterCoeff` | 0–1 smoothing factor for `dmLowPass` (higher = smoother, more lag). |
| `MinDt`, `MaxDt` | The `Dt` passed to `Update`/`UpdateFromError` is clamped to this range before use, guarding against a stalled loop (too-large `Dt`) or a divide-by-near-zero (too-small `Dt`). |
| `SetpointRamping` | Enable gradual setpoint movement — see [Setpoint ramping](#setpoint-ramping). |
| `SetpointRampRate` | Maximum setpoint change per second while ramping. |
| `MaxSetpointLead` | Maximum allowed gap between the internal (ramped) setpoint and the measurement (`0` disables). |
| `Deadband` | Error magnitude below which the integral treats the error as zero. |
| `Kf_Loss` | Feed-forward gain against `(InternalSetpoint - AmbientGuess)`; models a linear loss term (e.g. heat loss) so the integral doesn't have to discover it. `0` disables feed-forward. |
| `AmbientGuess` | Reference "ambient" value used by the feed-forward term (e.g. room temperature in Kelvin). |
| `HotStartWindow` | Seconds after `Reset` during which the hot-start correction (see [Setpoint ramping](#setpoint-ramping)) is active. |

The defaults (used when a `TSciPID` is first created) are `Kp=1, Ki=0, Kd=0`, output clamped to `[0, 1]`, `awBackCalculation` anti-windup, `dmLowPass` derivative filtering, `AmbientGuess = 298.15` (25 °C), and `HotStartWindow = 30` s.

## Autotuning

`TSciPID` includes a relay-feedback autotuner (Åström–Hägglund method) that measures the plant's ultimate gain and period by deliberately oscillating it, then computes PID gains from a chosen tuning rule — no manual trial-and-error tuning required.

### How it works

1. **Heating phase.** The autotuner drives the plant at full output (`QMax`) until the measurement first crosses the setpoint.
2. **Relay phase.** From then on, the output is switched between `0` and `QMax` every time the (noise-filtered) measurement crosses a hysteresis band around the setpoint (`SP ± Hysteresis`), producing a sustained oscillation. Peaks and valleys of that oscillation are recorded, along with the time between crossings.
3. After 9 setpoint crossings, the autotuner computes:
   - **Ultimate gain `Ku`** from the oscillation amplitude and `QMax`.
   - **Ultimate period `Pu`** from the average time between crossings.
   - Final `Kp`/`Ki`/`Kd` from `Ku`/`Pu` using the selected `Rules`.
4. On success, `ResultConfig` holds the computed tuning, ready to apply. On failure, `AutotuneFailureReason` explains why (usually "increase `QMax`" or "the system is too massive/slow").

The autotuner runs entirely inside your existing control loop (no separate thread or blocking wait) — while it's active, every `TSciPID.Update(Measurement, Dt)` call drives the relay instead of the PID and returns its output the same way, so nothing else in your loop needs to change.

### Soft-relay mode

Switching the output instantaneously between `0` and `QMax` (a "hard relay") can cause artefacts on real hardware — e.g. a thermoelectric glitch on a temperature sensor mounted close to a heating element, right at the moment of the step. Setting `RampDuration > 0` makes the autotuner ramp the output linearly over that many seconds instead of stepping it, eliminating the abrupt transition. Crossing and peak/valley detection are automatically paused while a ramp is in progress, since the process variable is in a driven transition during that time and isn't representative of the natural oscillation. Set `RampDuration = 0` (the default) to restore hard-relay behaviour.

### Tuning rules (`TTuningRules`)

| Rule | Character |
|---|---|
| `trTyreusLuyben` *(default)* | Conservative; recommended for thermal systems. Slow integral action, small derivative. |
| `trZieglerNichols` | Classic rules; faster response but typically ~25% overshoot. |
| `trNoOvershoot` | Very conservative; use when overshoot is unacceptable. |

### Autotune parameters (`Autotune`)

| Property | Description |
|---|---|
| `QMax` | Full relay output applied during tuning (e.g. heater wattage, valve %). Must be set to a value appropriate for your plant before starting. |
| `NoiseEstimate` | RMS noise on the measurement; used to size the relay hysteresis (`max(0.05, NoiseEstimate * 1.5)`). Leave at `0` to use a safe minimum. |
| `Rules` | Which tuning formula to apply once `Ku`/`Pu` are found — see above. |
| `TimeoutSeconds` | How long to wait for the first oscillation before declaring failure. Default 300 s. |
| `RampDuration` | Soft-relay ramp time in seconds; `0` = hard relay (default). |
| `AutoApply` | If `True` (default), a successful tune is written into `Config` automatically and the PID is bumplessly reset, so normal control resumes with the new tuning on the very next `Update` call. If `False`, you must apply `ResultConfig`/the autotune-complete event's config yourself. |

### Running an autotune

```pascal
PID.Autotune.QMax := 100.0;          // full heater power, plant units
PID.Autotune.Rules := trTyreusLuyben;
PID.OnAutotuneComplete := @HandleTuned;
PID.StartAutotune;                   // uses the current Setpoint as target
// ... keep calling PID.Update(Measurement, Dt) exactly as before ...

procedure TForm1.HandleTuned(Sender: TObject; Success: Boolean;
  const AResultConfig: TPIDConfig; const AFailureReason: string);
begin
  if Success then
    ShowMessage('Tuned. Kp=' + FloatToStr(AResultConfig.Kp))
  else
    ShowMessage('Autotune failed: ' + AFailureReason);
end;
```

You can also call the overload `StartAutotune(ASetpoint, AqMax, ANoiseEstimate, ARules, ATimeoutSeconds, ARampDuration)` to start a one-off autotune without touching the `Autotune` sub-object. `CancelAutotune` stops an active autotune early (fires `OnAutotuneComplete` with `Success = False`). While autotuning, `UpdateFromError` raises an exception — the relay method needs the real measurement, not a pre-computed error. Progress can be polled at any time via `Autotuning`, `AutotuneState`, `AutotuneFailureReason`, and `AutotuneRampRemaining`, or observed passively through `OnAutotuneComplete`.

## Usage from the Designer

1. Drop a `TSciPID` from the **Science** palette tab onto a form or data module.
2. Expand **Config** in the Object Inspector and set at least `Kp`/`Ki`/`Kd` and `OutputMin`/`OutputMax` for your plant; adjust the other sub-properties described in the table above as needed.
3. Set **Setpoint** to your initial target value.
4. If you want to autotune instead of hand-tuning, expand **Autotune** and set `QMax` (and optionally `Rules`, `NoiseEstimate`, `TimeoutSeconds`, `RampDuration`, `AutoApply`).
5. Leave **SynchronizeEvents** at its default (`True`) unless you plan to call `Update` only from the main thread and want to avoid the `TThread.Queue` overhead.
6. Add handlers for **OnUpdate** and, if you'll use autotuning, **OnAutotuneComplete** from the Events tab.
7. In your control loop (a `TTimer`, a worker thread, a hardware ISR wrapper, etc.), call `PID.Update(Measurement, Dt)` once per tick and apply the returned `Output` to your actuator. All tuning, autotuning, and setpoint changes can be adjusted live from the Object Inspector or from code without recreating the component.

## Usage from code

### Basic setup and control loop

```pascal
PID := TSciPID.Create(Self);
PID.Config.Kp := 2.0;
PID.Config.Ki := 0.1;
PID.Config.Kd := 0.05;
PID.Config.OutputMin := 0;
PID.Config.OutputMax := 100;
PID.OnUpdate := @HandlePIDUpdate;    // called with every TPIDOutput
PID.Setpoint := 60.0;

// ... once per control-loop tick, from the main thread or a worker/DAQ thread:
Output := PID.Update(Measurement, Dt);
ApplyToActuator(Output.Output);
```

```pascal
procedure TForm1.HandlePIDUpdate(Sender: TObject; const AOutput: TPIDOutput);
begin
  // Runs on the main thread by default (SynchronizeEvents = True), so it's
  // safe to touch the UI here even if Update() was called from a DAQ thread
  ChartSeries1.AddXY(Now, AOutput.Output);
  case AOutput.SafetyStatus of
    ssNormal: StatusLabel.Caption := 'OK';
    ssOutputSaturated: StatusLabel.Caption := 'Output saturated';
    ssIntegralWindup: StatusLabel.Caption := 'Integral at limit';
    ssTimeStepExcessive: StatusLabel.Caption := 'Loop running slow';
    ssMultipleFaults: StatusLabel.Caption := 'Multiple faults';
  end;
end;
```

### Driving from a DAQ/worker thread

`TSciPID`'s `Update`, `UpdateFromError`, `Reset*`, `SetSetpoint`/`Setpoint`, and config changes are all internally locked, so a worker thread can safely call `Update` while the main thread reads status or edits tuning:

```pascal
// Inside a TThread.Execute override, polling hardware every 50 ms:
while not Terminated do
begin
  Measurement := ReadSensor;
  Output := PID.Update(Measurement, 0.050);
  WriteActuator(Output.Output);
  Sleep(50);
end;
```

With `SynchronizeEvents = True` (the default), `OnUpdate` is queued and fired on the main thread via `TThread.Queue` — delivery is lossless and in order, and the worker thread never blocks waiting for the UI. Set `SynchronizeEvents := False` if you're doing your own marshalling, or if `Update` is only ever called from the main thread and you want the event fired synchronously.

### Using a pre-computed error

If you already have an error signal from elsewhere (rather than a raw measurement), use `UpdateFromError` instead of `Update`:

```pascal
Output := PID.UpdateFromError(Error, Dt);
```

Note: this cannot be used while an autotune is active (the relay method needs the real measurement), and if `Config.SetpointRamping` is enabled, the caller is responsible for ensuring the supplied error is already relative to the ramped setpoint, since `UpdateFromError` has no measurement to drive the ramp itself.

### Bumpless reset

```pascal
PID.Reset;                                    // clear all history
PID.Reset(CurrentMeasurement);                 // also re-seed the internal setpoint
PID.Reset(CurrentMeasurement, CurrentOutput);  // + seed the integral so the next
                                                // Update() doesn't bump the output
```

### Autotuning from code

See [Running an autotune](#running-an-autotune) above. In short:

```pascal
PID.Autotune.QMax := 100.0;
PID.OnAutotuneComplete := @HandleTuned;
PID.StartAutotune;
// keep calling PID.Update(Measurement, Dt) as usual; it now drives the relay
```

### Other read-only properties

| Property | Description |
|---|---|
| `InternalSetpoint` | The (possibly ramped) setpoint actually being used internally. |
| `UpdateCount` | Number of `Update`/`UpdateFromError` calls since the last `Reset`. |
| `MaxError` | Largest absolute error seen since the last `Reset`. |
| `Autotuning` | `True` while `AutotuneState` is `atsHeating` or `atsRunning`. |
| `AutotuneState` | `atsIdle`, `atsHeating`, `atsRunning`, `atsComplete`, or `atsFailed`. |
| `AutotuneFailureReason` | Populated when `AutotuneState = atsFailed`. |
| `AutotuneRampRemaining` | Seconds left in the current soft-relay ramp (diagnostic use). |
