unit uMain;

{ ==============================================================================
  SciPID Component Demonstration
  ==============================================================================

  This unit demonstrates the capabilities of the TSciPID component and its
  underlying TChivaPID and TRelayAutotuner implementations. It features a fully
  self-contained thermal simulation to test the controller without physical hardware.

  Key Features Demonstrated:

  1. Component-Based Control:
     Shows how to configure TSciPID using the Object Inspector/Config records
     and how to cleanly execute a control loop by passing a process variable
     and time delta (Dt) to the Update() method.

  2. Thermal Physics Simulation (THeaterModel):
     Simulates a realistic heater using thermal mass (Cp, mass), applied
     power (qMax), and ambient heat loss (convection).

  3. Noise and Filtering:
     Injects artificial noise into the simulated sensor readings and uses an
     Exponential Moving Average (EMA) filter to shield the PID's derivative
     term from noise spikes.

  4. Built-in Relay Autotuning:
     Demonstrates the Astroem-Hagglund relay feedback autotuner. When activated,
     the TSciPID component transparently intercepts the Update() cycle, forces
     the simulated temperature to oscillate around the setpoint, calculates
     the ultimate gain (Ku) and period (Pu), and automatically updates the
     PID parameters (Kp, Ki, Kd) upon success.

  5. Event-Driven Feedback:
     Uses the OnAutotuneComplete event to safely catch the end of the tuning
     cycle (success or failure) and update the UI accordingly.

  Usage:
  - Adjust the heater properties (Mass, Cp, Convection) to change the "plant".
  - Click "Simulate" to run a standard PID control loop using the current Kp/Ki/Kd.
  - Click "Autotune" to run the relay feedback process and find optimal parameters.

  ============================================================================== }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ExtCtrls, ComCtrls, TAGraph, TASeries, TACustomSeries, TATransformations,
  uPID, uSciPID, uAutoTune, uSciEdit, uUnitParser, uHeaterModel;

type
  { TForm1 }
  TForm1 = class(TForm)
    btnAutotune: TButton;
    lblRampingRate: TLabel;
    seRampingRate: TSciEdit;
    seConvection: TSciEdit;
    seCp: TSciEdit;
    seDerivativeFilterWeight: TSciEdit;
    lblKd: TLabel;
    lblDerivativeFilterWeight: TLabel;
    gbPIDSettings: TGroupBox;
    gbHeater: TGroupBox;
    gbSimulation: TGroupBox;
    lblKi: TLabel;
    seKd: TSciEdit;
    seKi: TSciEdit;
    seKp: TSciEdit;
    lblTnoise: TLabel;
    lblQMax: TLabel;
    lblSP: TLabel;
    lblTamb: TLabel;
    lblConvection: TLabel;
    lblMass: TLabel;
    lblCp: TLabel;
    lblOutputSmooth: TLabel;
    seMass: TSciEdit;
    seOutputSmooth: TSciEdit;
    rgPIDType: TRadioGroup;
    rgPIDCalc: TRadioGroup;
    lblKp: TLabel;
    seQMax: TSciEdit;
    SciPID1: TSciPID;
    btnSimulate: TButton;
    seSP: TSciEdit;
    seTamb: TSciEdit;
    seTnoise: TSciEdit;
    TunePIDButton: TButton;
    Chart1: TChart;
    Chart1LineSeries1: TLineSeries; // Raw Temperature
    Chart1LineSeries2: TLineSeries; // Output %
    Chart1LineSeries3: TLineSeries; // Setpoint
    Chart1LineSeries4: TLineSeries; // Filtered Temperature
    LeftAxisTransformations: TChartAxisTransformations;
    LeftAxisTransformationsAutoScaleAxisTransform1: TAutoScaleAxisTransform;
    LeftAxisTransformationsAutoScaleAxisTransform2: TAutoScaleAxisTransform;
    pnlInput: TPanel;
    RightAxisTransformations: TChartAxisTransformations;
    RightAxisTransformationsAutoScaleAxisTransform1: TAutoScaleAxisTransform;
    RightAxisTransformationsAutoScaleAxisTransform2: TAutoScaleAxisTransform;
    procedure rgPIDTypeSelectionChanged(Sender: TObject);
    procedure btnSimulateClick(Sender: TObject);
    procedure OnPIDAutotuneComplete(Sender: TObject; Success: Boolean; const AResultConfig: TPIDConfig; const AFailureReason: string);
    procedure TunePIDButtonClick(Sender: TObject);
  private
    Tnoise: double;
    FTuningFinished: Boolean;
    procedure initializeModels(var heater: THeaterModel);
    procedure UpdateUIFromConfig;
    procedure RunSimulation(DoTune: Boolean);
  public
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

procedure TForm1.initializeModels(var heater: THeaterModel);
var
  Tamb, convection, mass, Cp: Double;
begin
  Tamb := seTamb.ValueAs['°C'];
  convection := seConvection.ValueAs['kW/°C'];
  mass := seMass.ValueAs['kg'];
  Cp := seCp.ValueAs['kJ/kg/°C'];

  heater.initialize(Tamb, Cp, mass, convection, Tamb);

  // Apply parameters
  with SciPID1.Config do
  begin
    Kp := seKp.ValueAs['1/°C'];
    case rgPIDType.ItemIndex of
      0: begin // Standard (Kp, Ki, Kd)
        Ki := seKi.ValueAs['1/s/°C'];
        Kd := seKd.ValueAs['s/°C'];
      end;
      1: begin // Parallel (Kp, Ti, Td)
        Ki := seKi.ValueAs['s'];
        if abs(Ki) < 1e-6 then
          Ki := 0
        else
          Ki := Kp/Ki;
        Kd := Kp*seKd.ValueAs['s'];
      end;
    end;

    OutputMax := 1.0; // Our control output is a fraction (0% to 100%)
    OutputMin := 0.0;

    SetpointRamping := seRampingRate.Value > 0;
    SetpointRampRate := seRampingRate.ValueAs['°C/s'];
    AmbientGuess := Tamb;
    DerivativeMode := dmLowPass;

    Tnoise := seTnoise.ValueAs['°C'];

    if Tnoise > 0.01 then
    begin
      Deadband := Tnoise*2.2;
      DerivativeFilterCoeff := seDerivativeFilterWeight.Value;
    end
    else
    begin
      Deadband := 0.0;
      DerivativeFilterCoeff := 0.0;
    end;

    OutputFilterAlpha := seOutputSmooth.Value;

    if OutputFilterAlpha > 0.5 then
      OutputRateLimit := 0.05
    else
      OutputRateLimit := 0.005;

    AntiWindupMode := awBackCalculation;
    AntiWindupGain := 2.0;
  end;

  SciPID1.Setpoint := seSP.ValueAs['°C'];
  SciPID1.Reset;
end;

procedure TForm1.UpdateUIFromConfig;
var
  p, i, d: Double;
begin
  p := SciPID1.Config.Kp;
  i := SciPID1.Config.Ki;
  d := SciPID1.Config.Kd;

  seKp.Value := p;

  if rgPIDType.ItemIndex = 1 then // Parallel (Kp, Ti, Td)
  begin
    if abs(i) < 1e-6 then
      seKi.Value := 0
    else
      seKi.Value := p/i;

    if abs(p) < 1e-6 then
      seKd.Value := 0
    else
      seKd.Value := d/p;
  end
  else // Standard (Kp, Ki, Kd)
  begin
    seKi.Value := i;
    seKd.Value := d;
  end;
end;

procedure TForm1.RunSimulation(DoTune: Boolean);
var
  heater: THeaterModel;
  OP, qMax, tRaw, tFiltered, time, Dt: Double;
  step, MaxSteps: Integer;
  OutRec: TPIDOutput;
  FilterAlpha: Double;
begin
  try
    qMax := seQMax.ValueAs['kW'];
    Tnoise := seTnoise.ValueAs['°C'];
  except
    ShowMessage('Invalid input formats.');
    Exit;
  end;

  Chart1LineSeries1.Clear;
  Chart1LineSeries2.Clear;
  Chart1LineSeries3.Clear;
  Chart1LineSeries4.Clear;

  heater := THeaterModel.Create;
  try
    initializeModels(heater);

    if DoTune then
    begin
      with SciPID1.Autotune do
      begin
        QMax := 1.0;
        NoiseEstimate := Tnoise;
        RampDuration := 0.0;
        TimeoutSeconds := 1000.0;
        AutoApply := True;
      end;

      // Reset the flag
      FTuningFinished := False;

      SciPID1.StartAutotune;
      MaxSteps := 40000;
    end
    else
      MaxSteps := 36000;

    OP := 0.0;
    tFiltered := seTamb.ValueAs['°C'];
    FilterAlpha := 0.8;
    Dt := 0.1;

    for step := 0 to MaxSteps do
    begin
      time := step*Dt;
      tRaw := heater.calcTemperature(OP*qMax, Dt) + Tnoise*(1 - 2*Random);
      tFiltered := (FilterAlpha*tRaw) + ((1.0 - FilterAlpha)*tFiltered);

      OutRec := SciPID1.Update(tFiltered, Dt);
      OP := OutRec.Output;

      if (step mod 10 = 0) then
      begin
        Chart1LineSeries1.AddXY(time/60, tRaw);
        Chart1LineSeries2.AddXY(time/60, OP*100.0);
        Chart1LineSeries3.AddXY(time/60, OutRec.EffectiveSetpoint);
        Chart1LineSeries4.AddXY(time/60, tFiltered);

        if (step mod 100 = 0) then
          Application.ProcessMessages;
      end;

      // Break safely if the event handler flipped our flag
      if DoTune and FTuningFinished then Break;
    end;

    // Check if we hit MaxSteps without the event ever firing
    if DoTune then
    begin
      if not FTuningFinished then
      begin
        SciPID1.CancelAutotune;
        ShowMessage('Tuning failed: Did not finish within the simulation time limit.');
      end;
    end;

  finally
    heater.Free;
  end;
end;

procedure TForm1.btnSimulateClick(Sender: TObject);
begin
  RunSimulation(False);
end;

procedure TForm1.OnPIDAutotuneComplete(Sender: TObject; Success: Boolean; const AResultConfig: TPIDConfig; const AFailureReason: string);
begin
  FTuningFinished := True;

  if Success then
  begin
    UpdateUIFromConfig;
    ShowMessage('Tuning Complete! PID parameters have been updated.');
  end
  else
  begin
    ShowMessage('Tuning failed: ' + AFailureReason);
  end;
end;

procedure TForm1.TunePIDButtonClick(Sender: TObject);
begin
  RunSimulation(True);
end;

procedure TForm1.rgPIDTypeSelectionChanged(Sender: TObject);
var
  p, i, d: Double;
begin
  try
    p := seKp.Value;
    i := seKi.Value;
    d := seKd.Value;

    case rgPIDType.ItemIndex of
      0: begin // Standard (Kp, Ki, Kd)
        lblKi.Caption := 'Ki:';
        lblKd.Caption := 'Kd:';

        if abs(i) < 1e-6 then i := 1e-6;

        seKi.UnitFamily := ufCustom;
        seKi.CustomUnits := '1/s/°C';
        seKi.ValueAs['1/s/°C'] := p/i;
        seKi.PreferredUnits := '1/s/°C';

        seKd.UnitFamily := ufCustom;
        seKd.CustomUnits := 's/°C';
        seKd.ValueAs['s/°C'] := p*d;
        seKd.PreferredUnits := 's/°C';
      end;
      1: begin // Parallel (Kp, Ti, Td)
        lblKi.Caption := 'Ti:';
        lblKd.Caption := 'Td:';

        if abs(p) < 1e-6 then p := 1e-6;
        if abs(i) < 1e-6 then i := 1e-6;

        seKi.UnitFamily := ufTime;
        seKi.CustomUnits := '';
        seKi.ValueAs['s'] := p/i;
        seKi.PreferredUnits := 's';

        seKd.UnitFamily := ufTime;
        seKd.CustomUnits := '';
        seKd.ValueAs['s'] := d/p;
        seKd.PreferredUnits := 's';
      end;
    end;
  except
    // Silent fail on invalid strings during switch
  end;
end;

end.
