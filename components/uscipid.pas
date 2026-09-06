unit uSciPID;

{
  Lazarus component wrapper around TChivaPID (uPID.pas).

  Goals:
    - Drop a PID controller on a form/datamodule and edit its tuning in the
      Object Inspector (Config sub-properties).
    - Safe to drive from a worker thread (e.g. a DAQ polling thread) while the
      main thread reads Setpoint / changes tuning / handles OnUpdate.

  Thread-safety model:
    - TChivaPID itself is NOT thread-safe. Every entry point into it
      (Update, UpdateFromError, SetSetpoint, UpdateConfig, Reset*) is wrapped
      here in a single TCriticalSection, so it is safe to call Update from a
      DAQ thread while the main thread calls Setpoint := ... or edits Config.
    - OnUpdate is potentially dangerous to fire directly on a worker thread
      (handlers usually touch UI). Options:
        SynchronizeEvents = True  (default): each TPIDOutput is queued and
          the event is fired on the main thread via TThread.Queue. Delivery
          is lossless and in order; the calling thread never blocks waiting
          for the UI.
        SynchronizeEvents = False: OnUpdate fires synchronously, on whatever
          thread called Update/UpdateFromError. Use this if you are doing
          your own marshalling, or if the component is only ever driven from
          the main thread.

  Usage:
    PID := TSciPID.Create(Self);
    PID.Config.Kp := 2.0;
    PID.Config.Ki := 0.1;
    PID.OnUpdate := @HandlePIDUpdate;   // called with every TPIDOutput
    PID.Setpoint := 60.0;
    ...
    // from the main thread, or from a DAQ thread:
    Output := PID.Update(Measurement, Dt);

  Autotuning (transparent to the driving loop):
    - Autotuning is layered on top of the same Update(Measurement, Dt) call
      used for normal control. Set PID.Autotune.QMax (and, optionally,
      NoiseEstimate/Rules/TimeoutSeconds/RampDuration - see uAutoTune for
      what each does), then call PID.StartAutotune. From that point every
      Update() call drives the relay autotuner instead of the PID and
      returns its output the same way; nothing else in the control loop
      needs to change.
    - By default (Autotune.AutoApply = True) a successful tune is written
      into Config automatically and the PID is bumplessly reset, so control
      resumes with the new tuning on the very next Update() call.
    - PID.OnAutotuneComplete(Sender, Success, ResultConfig, FailureReason)
      fires once, on success, failure, or CancelAutotune (subject to
      SynchronizeEvents, exactly like OnUpdate), so the UI can be notified
      without polling.
    - PID.Autotuning / PID.AutotuneState / PID.AutotuneFailureReason /
      PID.AutotuneRampRemaining are available for progress display.

    Example:
      PID.Autotune.QMax := 100.0;      // full heater power, plant units
      PID.OnAutotuneComplete := @HandleTuned;
      PID.StartAutotune;
      // ... keep calling PID.Update(Measurement, Dt) as usual ...

      procedure TForm1.HandleTuned(Sender: TObject; Success: Boolean;
        const AResultConfig: TPIDConfig; const AFailureReason: string);
      begin
        if Success then
          ShowMessage('Tuned. Kp=' + FloatToStr(AResultConfig.Kp))
        else
          ShowMessage('Autotune failed: ' + AFailureReason);
      end;
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs, LResources, uPID, uAutoTune;

type
  TPIDUpdateEvent = procedure(Sender: TObject; const AOutput: TPIDOutput) of object;
  TAutotuneCompleteEvent = procedure(Sender: TObject; Success: Boolean; const AResultConfig: TPIDConfig; const AFailureReason: string) of object;

  TPIDConfigItems = class(TPersistent)
  private
    FOnChange: TNotifyEvent;

    FKp, FKi, FKd: Double;
    FOutputMax, FOutputMin: Double;
    FOutputRateLimit: Double;
    FOutputFilterAlpha: Double;
    FPLimit, FILimit, FDLimit: Double;
    FAntiWindupMode: TAntiWindupMode;
    FAntiWindupGain: Double;
    FDerivativeMode: TDerivativeMode;
    FDerivativeFilterCoeff: Double;
    FMaxDt, FMinDt: Double;
    FSetpointRamping: Boolean;
    FSetpointRampRate: Double;
    FMaxSetpointLead: Double;
    FDeadband: Double;
    FKf_Loss: Double;
    FAmbientGuess: Double;
    FHotStartWindow: Double;

    procedure Changed;

    procedure SetKp(AValue: Double);
    procedure SetKi(AValue: Double);
    procedure SetKd(AValue: Double);
    procedure SetOutputMax(AValue: Double);
    procedure SetOutputMin(AValue: Double);
    procedure SetOutputRateLimit(AValue: Double);
    procedure SetOutputFilterAlpha(AValue: Double);
    procedure SetPLimit(AValue: Double);
    procedure SetILimit(AValue: Double);
    procedure SetDLimit(AValue: Double);
    procedure SetAntiWindupMode(AValue: TAntiWindupMode);
    procedure SetAntiWindupGain(AValue: Double);
    procedure SetDerivativeMode(AValue: TDerivativeMode);
    procedure SetDerivativeFilterCoeff(AValue: Double);
    procedure SetMaxDt(AValue: Double);
    procedure SetMinDt(AValue: Double);
    procedure SetSetpointRamping(AValue: Boolean);
    procedure SetSetpointRampRate(AValue: Double);
    procedure SetMaxSetpointLead(AValue: Double);
    procedure SetDeadband(AValue: Double);
    procedure SetKf_Loss(AValue: Double);
    procedure SetAmbientGuess(AValue: Double);
    procedure SetHotStartWindow(AValue: Double);
  public
    procedure Assign(Source: TPersistent); override;
    function AsRecord: TPIDConfig;
    procedure LoadFromRecord(const ACfg: TPIDConfig);

    property OnChange: TNotifyEvent read FOnChange write FOnChange;
  published
    property Kp: Double read FKp write SetKp;
    property Ki: Double read FKi write SetKi;
    property Kd: Double read FKd write SetKd;

    property OutputMax: Double read FOutputMax write SetOutputMax;
    property OutputMin: Double read FOutputMin write SetOutputMin;
    property OutputRateLimit: Double read FOutputRateLimit write SetOutputRateLimit;
    property OutputFilterAlpha: Double read FOutputFilterAlpha write SetOutputFilterAlpha;

    property PLimit: Double read FPLimit write SetPLimit;
    property ILimit: Double read FILimit write SetILimit;
    property DLimit: Double read FDLimit write SetDLimit;

    property AntiWindupMode: TAntiWindupMode read FAntiWindupMode write SetAntiWindupMode default awBackCalculation;
    property AntiWindupGain: Double read FAntiWindupGain write SetAntiWindupGain;

    property DerivativeMode: TDerivativeMode read FDerivativeMode write SetDerivativeMode default dmLowPass;
    property DerivativeFilterCoeff: Double read FDerivativeFilterCoeff write SetDerivativeFilterCoeff;

    property MaxDt: Double read FMaxDt write SetMaxDt;
    property MinDt: Double read FMinDt write SetMinDt;

    property SetpointRamping: Boolean read FSetpointRamping write SetSetpointRamping default False;
    property SetpointRampRate: Double read FSetpointRampRate write SetSetpointRampRate;
    property MaxSetpointLead: Double read FMaxSetpointLead write SetMaxSetpointLead;

    property Deadband: Double read FDeadband write SetDeadband;

    property Kf_Loss: Double read FKf_Loss write SetKf_Loss;
    property AmbientGuess: Double read FAmbientGuess write SetAmbientGuess;

    property HotStartWindow: Double read FHotStartWindow write SetHotStartWindow;
  end;

  TAutotuneParams = class(TPersistent)
  private
    FQMax: Double;
    FNoiseEstimate: Double;
    FRules: TTuningRules;
    FTimeoutSeconds: Double;
    FRampDuration: Double;
    FAutoApply: Boolean;
  public
    constructor Create;
    procedure Assign(Source: TPersistent); override;
  published
    property QMax: Double read FQMax write FQMax;
    property NoiseEstimate: Double read FNoiseEstimate write FNoiseEstimate;
    property Rules: TTuningRules read FRules write FRules default trTyreusLuyben;
    property TimeoutSeconds: Double read FTimeoutSeconds write FTimeoutSeconds;
    property RampDuration: Double read FRampDuration write FRampDuration;
    property AutoApply: Boolean read FAutoApply write FAutoApply default True;
  end;

  TPIDOutputArray = array of TPIDOutput;

  { TSciPID }
  TSciPID = class(TComponent)
  private
    FPID: TChivaPID;
    FConfigItems: TPIDConfigItems;
    FLock: TCriticalSection;

    FSetpointMirror: Double;
    FSynchronizeEvents: Boolean;
    FOnUpdate: TPIDUpdateEvent;

    FPendingOutputs: TPIDOutputArray;
    FPendingCount: Integer;
    FEventQueued: Boolean;

    // Autotuner integration
    FAutotuner: TRelayAutotuner;
    FAutotuneParams: TAutotuneParams;
    FAutotuneSP: Double;           // SP the active autotune is targeting
    FOnAutotuneComplete: TAutotuneCompleteEvent;

    FPendingAutotuneEvent: Boolean;
    FPendingAutotuneSuccess: Boolean;
    FPendingAutotuneConfig: TPIDConfig;
    FPendingAutotuneReason: string;

    procedure ConfigChanged(Sender: TObject);
    procedure SetConfig(AValue: TPIDConfigItems);
    procedure SetAutotuneParams(AValue: TAutotuneParams);

    function GetSetpoint: Double;
    procedure SetSetpoint(AValue: Double);
    function GetInternalSetpoint: Double;
    function GetUpdateCount: UInt64;
    function GetMaxError: Double;

    function GetAutotuneState: TAutotuneState;
    function GetAutotuning: Boolean;
    function GetAutotuneFailureReason: string;
    function GetAutotuneRampRemaining: Double;

    procedure QueueOutput(const AOutput: TPIDOutput);
    procedure ProcessQueuedOutputs;

    function BuildAutotuneOutput(RelayOutput, Measurement, Dt: Double): TPIDOutput;
    procedure AbortActiveAutotune(const AReason: string);
    procedure QueueAutotuneComplete(Success: Boolean; const ACfg: TPIDConfig; const AReason: string);
    procedure ProcessAutotuneComplete;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Reset; overload;
    procedure Reset(AMeasurement: Double); overload;
    procedure Reset(AMeasurement, AInitialOutput: Double); overload;

    // Thread-safe: may be called from the main thread or from a worker (e.g. DAQ) thread
    function Update(Measurement, Dt: Double): TPIDOutput;
    function UpdateFromError(Error, Dt: Double): TPIDOutput;

    // Starts a relay autotune using the settings in the Autotune sub-object
    // and the component's current Setpoint as the target
    procedure StartAutotune; overload;
    procedure StartAutotune(ASetpoint, AqMax: Double; ANoiseEstimate: Double = 0;
                            ARules: TTuningRules = trTyreusLuyben;
                            ATimeoutSeconds: Double = 300.0;
                            ARampDuration: Double = 0.0); overload;
    // Stops an active autotune early
    procedure CancelAutotune;

    property InternalSetpoint: Double read GetInternalSetpoint;
    property UpdateCount: UInt64 read GetUpdateCount;
    property MaxError: Double read GetMaxError;

    property Autotuning: Boolean read GetAutotuning;
    property AutotuneState: TAutotuneState read GetAutotuneState;
    property AutotuneFailureReason: string read GetAutotuneFailureReason;
    property AutotuneRampRemaining: Double read GetAutotuneRampRemaining;
  published
    property Config: TPIDConfigItems read FConfigItems write SetConfig;
    property Autotune: TAutotuneParams read FAutotuneParams write SetAutotuneParams;
    property Setpoint: Double read GetSetpoint write SetSetpoint;
    property SynchronizeEvents: Boolean read FSynchronizeEvents write FSynchronizeEvents default True;
    property OnUpdate: TPIDUpdateEvent read FOnUpdate write FOnUpdate;
    property OnAutotuneComplete: TAutotuneCompleteEvent read FOnAutotuneComplete write FOnAutotuneComplete;
  end;

procedure Register;

implementation

{ TPIDConfigItems }

procedure TPIDConfigItems.Changed;
begin
  if Assigned(FOnChange) then FOnChange(Self);
end;

procedure TPIDConfigItems.SetKp(AValue: Double);
begin
  if FKp = AValue then Exit;
  FKp := AValue; Changed;
end;

procedure TPIDConfigItems.SetKi(AValue: Double);
begin
  if FKi = AValue then Exit;
  FKi := AValue; Changed;
end;

procedure TPIDConfigItems.SetKd(AValue: Double);
begin
  if FKd = AValue then Exit;
  FKd := AValue; Changed;
end;

procedure TPIDConfigItems.SetOutputMax(AValue: Double);
begin
  if FOutputMax = AValue then Exit;
  FOutputMax := AValue; Changed;
end;

procedure TPIDConfigItems.SetOutputMin(AValue: Double);
begin
  if FOutputMin = AValue then Exit;
  FOutputMin := AValue; Changed;
end;

procedure TPIDConfigItems.SetOutputRateLimit(AValue: Double);
begin
  if FOutputRateLimit = AValue then Exit;
  FOutputRateLimit := AValue; Changed;
end;

procedure TPIDConfigItems.SetOutputFilterAlpha(AValue: Double);
begin
  if FOutputFilterAlpha = AValue then Exit;
  FOutputFilterAlpha := AValue; Changed;
end;

procedure TPIDConfigItems.SetPLimit(AValue: Double);
begin
  if FPLimit = AValue then Exit;
  FPLimit := AValue; Changed;
end;

procedure TPIDConfigItems.SetILimit(AValue: Double);
begin
  if FILimit = AValue then Exit;
  FILimit := AValue; Changed;
end;

procedure TPIDConfigItems.SetDLimit(AValue: Double);
begin
  if FDLimit = AValue then Exit;
  FDLimit := AValue; Changed;
end;

procedure TPIDConfigItems.SetAntiWindupMode(AValue: TAntiWindupMode);
begin
  if FAntiWindupMode = AValue then Exit;
  FAntiWindupMode := AValue; Changed;
end;

procedure TPIDConfigItems.SetAntiWindupGain(AValue: Double);
begin
  if FAntiWindupGain = AValue then Exit;
  FAntiWindupGain := AValue; Changed;
end;

procedure TPIDConfigItems.SetDerivativeMode(AValue: TDerivativeMode);
begin
  if FDerivativeMode = AValue then Exit;
  FDerivativeMode := AValue; Changed;
end;

procedure TPIDConfigItems.SetDerivativeFilterCoeff(AValue: Double);
begin
  if FDerivativeFilterCoeff = AValue then Exit;
  FDerivativeFilterCoeff := AValue; Changed;
end;

procedure TPIDConfigItems.SetMaxDt(AValue: Double);
begin
  if FMaxDt = AValue then Exit;
  FMaxDt := AValue; Changed;
end;

procedure TPIDConfigItems.SetMinDt(AValue: Double);
begin
  if FMinDt = AValue then Exit;
  FMinDt := AValue; Changed;
end;

procedure TPIDConfigItems.SetSetpointRamping(AValue: Boolean);
begin
  if FSetpointRamping = AValue then Exit;
  FSetpointRamping := AValue; Changed;
end;

procedure TPIDConfigItems.SetSetpointRampRate(AValue: Double);
begin
  if FSetpointRampRate = AValue then Exit;
  FSetpointRampRate := AValue; Changed;
end;

procedure TPIDConfigItems.SetMaxSetpointLead(AValue: Double);
begin
  if FMaxSetpointLead = AValue then Exit;
  FMaxSetpointLead := AValue; Changed;
end;

procedure TPIDConfigItems.SetDeadband(AValue: Double);
begin
  if FDeadband = AValue then Exit;
  FDeadband := AValue; Changed;
end;

procedure TPIDConfigItems.SetKf_Loss(AValue: Double);
begin
  if FKf_Loss = AValue then Exit;
  FKf_Loss := AValue; Changed;
end;

procedure TPIDConfigItems.SetAmbientGuess(AValue: Double);
begin
  if FAmbientGuess = AValue then Exit;
  FAmbientGuess := AValue; Changed;
end;

procedure TPIDConfigItems.SetHotStartWindow(AValue: Double);
begin
  if FHotStartWindow = AValue then Exit;
  FHotStartWindow := AValue; Changed;
end;

procedure TPIDConfigItems.Assign(Source: TPersistent);
begin
  if Source is TPIDConfigItems then
    LoadFromRecord(TPIDConfigItems(Source).AsRecord)
  else
    inherited Assign(Source);
end;

function TPIDConfigItems.AsRecord: TPIDConfig;
begin
  Result.Kp := FKp;
  Result.Ki := FKi;
  Result.Kd := FKd;
  Result.OutputMax := FOutputMax;
  Result.OutputMin := FOutputMin;
  Result.OutputRateLimit := FOutputRateLimit;
  Result.OutputFilterAlpha := FOutputFilterAlpha;
  Result.PLimit := FPLimit;
  Result.ILimit := FILimit;
  Result.DLimit := FDLimit;
  Result.AntiWindupMode := FAntiWindupMode;
  Result.AntiWindupGain := FAntiWindupGain;
  Result.DerivativeMode := FDerivativeMode;
  Result.DerivativeFilterCoeff := FDerivativeFilterCoeff;
  Result.MaxDt := FMaxDt;
  Result.MinDt := FMinDt;
  Result.SetpointRamping := FSetpointRamping;
  Result.SetpointRampRate := FSetpointRampRate;
  Result.MaxSetpointLead := FMaxSetpointLead;
  Result.Deadband := FDeadband;
  Result.Kf_Loss := FKf_Loss;
  Result.AmbientGuess := FAmbientGuess;
  Result.HotStartWindow := FHotStartWindow;
end;

procedure TPIDConfigItems.LoadFromRecord(const ACfg: TPIDConfig);
begin
  FKp := ACfg.Kp;
  FKi := ACfg.Ki;
  FKd := ACfg.Kd;
  FOutputMax := ACfg.OutputMax;
  FOutputMin := ACfg.OutputMin;
  FOutputRateLimit := ACfg.OutputRateLimit;
  FOutputFilterAlpha := ACfg.OutputFilterAlpha;
  FPLimit := ACfg.PLimit;
  FILimit := ACfg.ILimit;
  FDLimit := ACfg.DLimit;
  FAntiWindupMode := ACfg.AntiWindupMode;
  FAntiWindupGain := ACfg.AntiWindupGain;
  FDerivativeMode := ACfg.DerivativeMode;
  FDerivativeFilterCoeff := ACfg.DerivativeFilterCoeff;
  FMaxDt := ACfg.MaxDt;
  FMinDt := ACfg.MinDt;
  FSetpointRamping := ACfg.SetpointRamping;
  FSetpointRampRate := ACfg.SetpointRampRate;
  FMaxSetpointLead := ACfg.MaxSetpointLead;
  FDeadband := ACfg.Deadband;
  FKf_Loss := ACfg.Kf_Loss;
  FAmbientGuess := ACfg.AmbientGuess;
  FHotStartWindow := ACfg.HotStartWindow;
  Changed;
end;

{ TAutotuneParams }

constructor TAutotuneParams.Create;
begin
  inherited Create;
  FQMax := 1.0;
  FNoiseEstimate := 0.0;
  FRules := trTyreusLuyben;
  FTimeoutSeconds := 300.0;
  FRampDuration := 0.0;
  FAutoApply := True;
end;

procedure TAutotuneParams.Assign(Source: TPersistent);
begin
  if Source is TAutotuneParams then
  begin
    FQMax := TAutotuneParams(Source).QMax;
    FNoiseEstimate := TAutotuneParams(Source).NoiseEstimate;
    FRules := TAutotuneParams(Source).Rules;
    FTimeoutSeconds := TAutotuneParams(Source).TimeoutSeconds;
    FRampDuration := TAutotuneParams(Source).RampDuration;
    FAutoApply := TAutotuneParams(Source).AutoApply;
  end
  else
    inherited Assign(Source);
end;

{ TSciPID }

constructor TSciPID.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FLock := TCriticalSection.Create;
  FSynchronizeEvents := True;

  FConfigItems := TPIDConfigItems.Create;
  FConfigItems.LoadFromRecord(DefaultPIDConfig);
  FConfigItems.OnChange := @ConfigChanged;

  FPID := TChivaPID.Create(FConfigItems.AsRecord);

  FAutotuneParams := TAutotuneParams.Create;
end;

destructor TSciPID.Destroy;
begin
  FConfigItems.OnChange := nil;
  FreeAndNil(FAutotuner);
  FreeAndNil(FAutotuneParams);
  FreeAndNil(FPID);
  FreeAndNil(FConfigItems);
  FreeAndNil(FLock);
  inherited Destroy;
end;

procedure TSciPID.SetAutotuneParams(AValue: TAutotuneParams);
begin
  FAutotuneParams.Assign(AValue);
end;

procedure TSciPID.ConfigChanged(Sender: TObject);
var
  Cfg: TPIDConfig;
begin
  Cfg := FConfigItems.AsRecord;
  FLock.Enter;
  try
    if Assigned(FPID) then
      FPID.UpdateConfig(Cfg);
  finally
    FLock.Leave;
  end;
end;

procedure TSciPID.SetConfig(AValue: TPIDConfigItems);
begin
  FConfigItems.Assign(AValue);
end;

function TSciPID.GetSetpoint: Double;
begin
  FLock.Enter;
  try
    Result := FSetpointMirror;
  finally
    FLock.Leave;
  end;
end;

procedure TSciPID.SetSetpoint(AValue: Double);
begin
  FLock.Enter;
  try
    FSetpointMirror := AValue;
    FPID.SetSetpoint(AValue);
  finally
    FLock.Leave;
  end;
end;

function TSciPID.GetInternalSetpoint: Double;
begin
  FLock.Enter;
  try
    Result := FPID.InternalSetpoint;
  finally
    FLock.Leave;
  end;
end;

function TSciPID.GetUpdateCount: UInt64;
begin
  FLock.Enter;
  try
    Result := FPID.UpdateCount;
  finally
    FLock.Leave;
  end;
end;

function TSciPID.GetMaxError: Double;
begin
  FLock.Enter;
  try
    Result := FPID.MaxError;
  finally
    FLock.Leave;
  end;
end;

function TSciPID.GetAutotuneState: TAutotuneState;
begin
  FLock.Enter;
  try
    if Assigned(FAutotuner) then
      Result := FAutotuner.State
    else
      Result := atsIdle;
  finally
    FLock.Leave;
  end;
end;

function TSciPID.GetAutotuning: Boolean;
begin
  Result := GetAutotuneState in [atsHeating, atsRunning];
end;

function TSciPID.GetAutotuneFailureReason: string;
begin
  FLock.Enter;
  try
    if Assigned(FAutotuner) then
      Result := FAutotuner.FailureReason
    else
      Result := '';
  finally
    FLock.Leave;
  end;
end;

function TSciPID.GetAutotuneRampRemaining: Double;
begin
  FLock.Enter;
  try
    if Assigned(FAutotuner) then
      Result := FAutotuner.RampRemaining
    else
      Result := 0;
  finally
    FLock.Leave;
  end;
end;

procedure TSciPID.QueueOutput(const AOutput: TPIDOutput);
var
  NeedQueue: Boolean;
begin
  if not Assigned(FOnUpdate) then Exit;

  if (not FSynchronizeEvents) or (TThread.CurrentThread.ThreadID = MainThreadID) then
  begin
    FOnUpdate(Self, AOutput);
    Exit;
  end;

  FLock.Enter;
  try
    if FPendingCount >= Length(FPendingOutputs) then
      SetLength(FPendingOutputs, Length(FPendingOutputs) * 2 + 4);
    FPendingOutputs[FPendingCount] := AOutput;
    Inc(FPendingCount);
    NeedQueue := not FEventQueued;
    FEventQueued := True;
  finally
    FLock.Leave;
  end;

  if NeedQueue then
    TThread.Queue(nil, @ProcessQueuedOutputs);
end;

procedure TSciPID.ProcessQueuedOutputs;
var
  Batch: TPIDOutputArray;
  BatchCount, i: Integer;
begin
  FLock.Enter;
  try
    Batch := FPendingOutputs;
    BatchCount := FPendingCount;
    FPendingOutputs := nil;
    FPendingCount := 0;
    FEventQueued := False;
  finally
    FLock.Leave;
  end;

  if Assigned(FOnUpdate) then
    for i := 0 to BatchCount - 1 do
      FOnUpdate(Self, Batch[i]);
end;

function TSciPID.BuildAutotuneOutput(RelayOutput, Measurement, Dt: Double): TPIDOutput;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Output := RelayOutput;
  Result.Error := FAutotuneSP - Measurement;
  Result.EffectiveSetpoint := FAutotuneSP;
  Result.Dt := Dt;
  Result.SafetyStatus := ssNormal;
end;

procedure TSciPID.AbortActiveAutotune(const AReason: string);
begin
  if not Assigned(FAutotuner) then Exit;
  FreeAndNil(FAutotuner);
  QueueAutotuneComplete(False, DefaultPIDConfig, AReason);
end;

procedure TSciPID.QueueAutotuneComplete(Success: Boolean; const ACfg: TPIDConfig;
  const AReason: string);
begin
  if not Assigned(FOnAutotuneComplete) then Exit;

  if (not FSynchronizeEvents) or (TThread.CurrentThread.ThreadID = MainThreadID) then
  begin
    FOnAutotuneComplete(Self, Success, ACfg, AReason);
    Exit;
  end;

  FLock.Enter;
  try
    FPendingAutotuneSuccess := Success;
    FPendingAutotuneConfig := ACfg;
    FPendingAutotuneReason := AReason;
    FPendingAutotuneEvent := True;
  finally
    FLock.Leave;
  end;

  TThread.Queue(nil, @ProcessAutotuneComplete);
end;

procedure TSciPID.ProcessAutotuneComplete;
var
  Has, Success: Boolean;
  Cfg: TPIDConfig;
  Reason: string;
begin
  FLock.Enter;
  try
    Has := FPendingAutotuneEvent;
    Success := FPendingAutotuneSuccess;
    Cfg := FPendingAutotuneConfig;
    Reason := FPendingAutotuneReason;
    FPendingAutotuneEvent := False;
  finally
    FLock.Leave;
  end;

  if Has and Assigned(FOnAutotuneComplete) then
    FOnAutotuneComplete(Self, Success, Cfg, Reason);
end;

procedure TSciPID.Reset;
begin
  FLock.Enter;
  try
    FPID.Reset;
  finally
    FLock.Leave;
  end;
end;

procedure TSciPID.Reset(AMeasurement: Double);
begin
  FLock.Enter;
  try
    FPID.Reset(AMeasurement);
  finally
    FLock.Leave;
  end;
end;

procedure TSciPID.Reset(AMeasurement, AInitialOutput: Double);
begin
  FLock.Enter;
  try
    FPID.Reset(AMeasurement, AInitialOutput);
  finally
    FLock.Leave;
  end;
end;

procedure TSciPID.StartAutotune;
begin
  StartAutotune(GetSetpoint, FAutotuneParams.QMax, FAutotuneParams.NoiseEstimate,
    FAutotuneParams.Rules, FAutotuneParams.TimeoutSeconds, FAutotuneParams.RampDuration);
end;

procedure TSciPID.StartAutotune(ASetpoint, AqMax: Double; ANoiseEstimate: Double;
  ARules: TTuningRules; ATimeoutSeconds: Double; ARampDuration: Double);
begin
  FLock.Enter;
  try
    // Starting a new autotune while one is already running discards the old one
    AbortActiveAutotune('Superseded by a new StartAutotune call.');
    FAutotuneSP := ASetpoint;
    FAutotuner := TRelayAutotuner.Create(ASetpoint, AqMax, ANoiseEstimate, ARules,
      ATimeoutSeconds, ARampDuration);
  finally
    FLock.Leave;
  end;
end;

procedure TSciPID.CancelAutotune;
begin
  FLock.Enter;
  try
    AbortActiveAutotune('Cancelled by user request.');
  finally
    FLock.Leave;
  end;
end;

function TSciPID.Update(Measurement, Dt: Double): TPIDOutput;
var
  RelayOutput: Double;
  AutotuneJustFinished, AutotuneSucceeded: Boolean;
  FinishedConfig: TPIDConfig;
  FinishedReason: string;
begin
  AutotuneJustFinished := False;
  AutotuneSucceeded := False;
  FinishedConfig := DefaultPIDConfig;
  FinishedReason := '';

  FLock.Enter;
  try
    if Assigned(FAutotuner) then
    begin
      // Autotuning is active, replace the PID entirely for this tick
      RelayOutput := FAutotuner.Update(Measurement, Dt);
      Result := BuildAutotuneOutput(RelayOutput, Measurement, Dt);

      if FAutotuner.State in [atsComplete, atsFailed] then
      begin
        AutotuneJustFinished := True;
        AutotuneSucceeded := (FAutotuner.State = atsComplete);

        if AutotuneSucceeded then
        begin
          FinishedConfig := FAutotuner.ResultConfig;
          if FAutotuneParams.AutoApply then
          begin
            // Update config
            FConfigItems.LoadFromRecord(FinishedConfig);
            // Bumpless restart
            FPID.Reset(Measurement);
            FPID.SetSetpoint(FSetpointMirror);
          end;
        end
        else
          FinishedReason := FAutotuner.FailureReason;

        FreeAndNil(FAutotuner);
      end;
    end
    else
      Result := FPID.Update(Measurement, Dt);
  finally
    FLock.Leave;
  end;

  QueueOutput(Result);
  if AutotuneJustFinished then
    QueueAutotuneComplete(AutotuneSucceeded, FinishedConfig, FinishedReason);
end;

function TSciPID.UpdateFromError(Error, Dt: Double): TPIDOutput;
begin
  FLock.Enter;
  try
    if Assigned(FAutotuner) then
      raise Exception.Create('TSciPID.UpdateFromError: cannot be used while ' +
        'autotuning is active. Relay autotuning needs the actual measurement ' +
        '- call Update(Measurement, Dt) instead, or CancelAutotune first.');
    Result := FPID.UpdateFromError(Error, Dt);
  finally
    FLock.Leave;
  end;
  QueueOutput(Result);
end;

procedure Register;
begin
  RegisterComponents('Science', [TSciPID]);
end;

initialization
  {$I LazScience.lrs}
end.
