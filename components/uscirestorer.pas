unit uSciRestorer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ExtCtrls, Types, Math, IniFiles,
  LCLIntf, LCLType, FileUtil, LazFileUtils;

type
  EWinRestorer = class(Exception);

  TWhatSave = (svDefault, svSize, svLocation, svState, svPanels);
  STWhatSave = set of TWhatSave;

  { TIniLocation: where the INI file is stored }
  TIniLocation = (ilAppDir,      // Same directory as the executable
                  ilUserDir,     // OS user-config dir
                  ilCustomDir);  // Arbitrary path supplied via IniFileName


  { TSciRestorer }

  TSciRestorer = class(TComponent)
  private
    FIniFileName: String;
    FUserSubDir: String;
    FIniLocation: TIniLocation;
    FIniSection: String;
    FDefaultWhatSave: STWhatSave;
    FAutoSaveRestoreOwner: Boolean;
    FSaveMinimized: Boolean;
    FOldOwnerShow: TNotifyEvent;
    FOldOwnerClose: TCloseEvent;
    FHooked: Boolean;
    FRestoredOwner: Boolean;

    { Helpers }
    function  GetEffectiveIniFileName: String;
    function  GetEffectiveIniSection: String;
    function  GetFormKey(Form: TForm; const Key: String): String;
    function  ScaleValue(Value, FromDPI, ToDPI: Integer): Integer;

    { Visibility }
    procedure EnsureFormVisible(F: TForm);

    { Panel save/restore, recursive to handle nested panels }
    procedure SavePanelsRecursive(Container: TWinControl; Ini: TCustomIniFile;
      const Section, FormKey: String);
    procedure RestorePanelsRecursive(Container: TWinControl; Ini: TCustomIniFile;
      const Section, FormKey: String; SavedDPI, CurDPI: Integer);

    { Auto-hook for the owner form }
    procedure HookOwner;
    procedure UnhookOwner;
    procedure OwnerFormShow(Sender: TObject);
    procedure OwnerFormClose(Sender: TObject; var CloseAction: TCloseAction);
  protected
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor  Destroy; override;

    procedure SaveForm(TheForm: TForm; const Key: String = '';
      What: STWhatSave = [svDefault]);
    procedure RestoreForm(TheForm: TForm; const Key: String = '';
      What: STWhatSave = [svDefault]);
  published
    property IniFileName: String read FIniFileName write FIniFileName;
    property UserSubDir: String read FUserSubDir write FUserSubDir;
    property IniLocation: TIniLocation read FIniLocation write FIniLocation default ilAppDir;
    property IniSection: String read FIniSection write FIniSection;

    property DefaultWhatSave: STWhatSave read FDefaultWhatSave write FDefaultWhatSave default [svSize, svLocation, svState, svPanels];
    property AutoSaveRestoreOwner: Boolean read FAutoSaveRestoreOwner write FAutoSaveRestoreOwner default True;
    property SaveMinimized: Boolean read FSaveMinimized write FSaveMinimized default False;
  end;

procedure Register;

implementation

const
  DefaultIniSection = 'SciRestorer';

{ TSciRestorer }

constructor TSciRestorer.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIniFileName := '';
  FUserSubDir := '';
  FIniLocation := ilAppDir;
  FIniSection := '';
  FDefaultWhatSave := [svSize, svLocation, svState, svPanels];
  FAutoSaveRestoreOwner := True;
  FSaveMinimized := False;
  FHooked := False;
  FRestoredOwner := False;
end;

destructor TSciRestorer.Destroy;
begin
  UnhookOwner;
  inherited Destroy;
end;

function TSciRestorer.GetEffectiveIniFileName: String;
var
  BareName, Dir: String;
begin
  // Determine the bare file name (no path)
  if FIniFileName <> '' then
  begin
    case FIniLocation of
      ilCustomDir:
        begin
          // IniFileName is the complete path, return as-is
          Result := FIniFileName;
          Exit;
        end;
      ilAppDir, ilUserDir:
        // Use as bare filename override
        BareName := ExtractFileName(FIniFileName);
    end;
  end
  else
    BareName := ChangeFileExt(ExtractFileName(Application.ExeName), '.ini');

  // Resolve the directory
  case FIniLocation of
    ilAppDir:
      Dir := ExtractFilePath(Application.ExeName);

    ilUserDir:
    begin
      if FUserSubDir <> '' then
        Dir := AppendPathDelim(AppendPathDelim(GetUserDir) + '.config' + PathDelim + FUserSubDir)
      else
        Dir := AppendPathDelim(GetAppConfigDir(False));

      // Create the directory if it does not yet exist
      if not DirectoryExists(Dir) then
        ForceDirectories(Dir);
    end;

    ilCustomDir:
      // Should have been handled above; guard for completeness
      Dir := ExtractFilePath(Application.ExeName);
  end;

  Result := Dir + BareName;
end;

function TSciRestorer.GetEffectiveIniSection: String;
begin
  if FIniSection <> '' then
    Result := FIniSection
  else
    Result := DefaultIniSection;
end;

function TSciRestorer.GetFormKey(Form: TForm; const Key: String): String;
begin
  if Key <> '' then
    Result := Key
  else if Assigned(Form) and (Form.Name <> '') then
    Result := Form.Name
  else if Assigned(Form) then
    Result := Form.ClassName
  else
    Result := 'UnknownForm';
end;

function TSciRestorer.ScaleValue(Value, FromDPI, ToDPI: Integer): Integer;
begin
  if (FromDPI <= 0) or (ToDPI <= 0) or (FromDPI = ToDPI) then
    Exit(Value);
  Result := Round(Value*(ToDPI/FromDPI));
end;

procedure TSciRestorer.EnsureFormVisible(F: TForm);
var
  R, WA: TRect;
  M: TMonitor;
  L, T, W, H: Integer;
begin
  L := F.Left;
  T := F.Top;
  W := F.Width;
  H := F.Height;

  R := Rect(L, T, L + W, T + H);
  M := Screen.MonitorFromRect(R, mdNearest);
  if M = nil then
    M := Screen.PrimaryMonitor;
  WA := M.WorkareaRect;

  // Clamp size to work-area
  if W > (WA.Right - WA.Left) then W := WA.Right - WA.Left;
  if H > (WA.Bottom - WA.Top) then H := WA.Bottom - WA.Top;

  // Clamp position so that at least 50px of the form remains visible
  // Too far left
  if (L + W) < (WA.Left + 50) then
    L := WA.Left;

  // Too far up
  if (T + H) < (WA.Top + 50) then
    T := WA.Top;

  // Too far right
  if L > (WA.Right - 50) then
    L := WA.Right - 50;

  // Too far down
  if T > (WA.Bottom - 50) then
    T := WA.Bottom - 50;

  F.SetBounds(L, T, W, H);
end;

procedure TSciRestorer.SavePanelsRecursive(Container: TWinControl;
  Ini: TCustomIniFile; const Section, FormKey: String);
var
  i: Integer;
  P: TPanel;
  Key: String;
begin
  for i := 0 to Container.ControlCount - 1 do
  begin
    // Recurse into any TWinControl child
    if Container.Controls[i] is TWinControl then
      SavePanelsRecursive(TWinControl(Container.Controls[i]), Ini, Section, FormKey);

    if not (Container.Controls[i] is TPanel) then Continue;
    P := TPanel(Container.Controls[i]);

    // Skip unnamed panels or opted-out panels
    if (P.Name = '') or (P.Tag = -1) then Continue;

    Key := FormKey + '_Panel_' + P.Name;

    if P.Align in [alLeft, alRight] then
      Ini.WriteInteger(Section, Key + '_Width', P.Width)
    else if P.Align in [alTop, alBottom] then
      Ini.WriteInteger(Section, Key + '_Height', P.Height);
  end;
end;

procedure TSciRestorer.RestorePanelsRecursive(Container: TWinControl;
  Ini: TCustomIniFile; const Section, FormKey: String;
  SavedDPI, CurDPI: Integer);
var
  i: Integer;
  P: TPanel;
  Key: String;
  SavedSize: Integer;
begin
  for i := 0 to Container.ControlCount - 1 do
  begin
    // Recurse into any TWinControl child
    if Container.Controls[i] is TWinControl then
      RestorePanelsRecursive(TWinControl(Container.Controls[i]), Ini,
        Section, FormKey, SavedDPI, CurDPI);

    if not (Container.Controls[i] is TPanel) then Continue;
    P := TPanel(Container.Controls[i]);

    if (P.Name = '') or (P.Tag = -1) then Continue;

    Key := FormKey + '_Panel_' + P.Name;

    if P.Align in [alLeft, alRight] then
    begin
      SavedSize := Ini.ReadInteger(Section, Key + '_Width', P.Width);
      SavedSize := ScaleValue(SavedSize, SavedDPI, CurDPI);
      // Sanity: never set a panel narrower than 10px
      P.Width := Max(SavedSize, 10);
    end
    else if P.Align in [alTop, alBottom] then
    begin
      SavedSize := Ini.ReadInteger(Section, Key + '_Height', P.Height);
      SavedSize := ScaleValue(SavedSize, SavedDPI, CurDPI);
      P.Height := Max(SavedSize, 10);
    end;
  end;
end;

procedure TSciRestorer.SaveForm(TheForm: TForm; const Key: String;
  What: STWhatSave);
var
  Ini: TIniFile;
  Section,
  FormKey: String;
  UseSet: STWhatSave;
  SaveWS: Integer;
begin
  if not Assigned(TheForm) then Exit;

  if svDefault in What then
    UseSet := FDefaultWhatSave
  else
    UseSet := What;

  Ini := TIniFile.Create(GetEffectiveIniFileName);
  try
    Section := GetEffectiveIniSection;
    FormKey := GetFormKey(TheForm, Key);

    // Only persist DPI when we are saving geometry
    if [svSize, svLocation]*UseSet <> [] then
      Ini.WriteInteger(Section, FormKey + '_DPI', TheForm.PixelsPerInch);

    if svSize in UseSet then
    begin
      Ini.WriteInteger(Section, FormKey + '_Width',  TheForm.Width);
      Ini.WriteInteger(Section, FormKey + '_Height', TheForm.Height);
    end;

    if svLocation in UseSet then
    begin
      Ini.WriteInteger(Section, FormKey + '_Left', TheForm.Left);
      Ini.WriteInteger(Section, FormKey + '_Top',  TheForm.Top);
    end;

    if svState in UseSet then
    begin
      case TheForm.WindowState of
        wsMinimized:
          // Respect SaveMinimized property; fall back to normal if not set
          if FSaveMinimized then
            SaveWS := 1
          else
            SaveWS := 2;
        wsNormal: SaveWS := 2;
        wsMaximized: SaveWS := 3;
      else
        SaveWS := 2;
      end;
      Ini.WriteInteger(Section, FormKey + '_WindowState', SaveWS);
    end;

    if svPanels in UseSet then
      SavePanelsRecursive(TheForm, Ini, Section, FormKey);

  finally
    Ini.Free;
  end;
end;

procedure TSciRestorer.RestoreForm(TheForm: TForm; const Key: String;
  What: STWhatSave);
var
  Ini: TIniFile;
  Section,
  FormKey: String;
  UseSet: STWhatSave;
  SavedDPI,
  CurDPI: Integer;
  l, t, w, h: Integer;
  stateCode: Integer;
  RestoreGeom: Boolean;
begin
  if not Assigned(TheForm) then Exit;

  if svDefault in What then
    UseSet := FDefaultWhatSave
  else
    UseSet := What;

  Ini := TIniFile.Create(GetEffectiveIniFileName);
  try
    Section := GetEffectiveIniSection;
    FormKey := GetFormKey(TheForm, Key);

    // Geometry
    RestoreGeom := [svSize, svLocation]*UseSet <> [];

    if RestoreGeom then
    begin
      CurDPI := TheForm.PixelsPerInch;
      SavedDPI := Ini.ReadInteger(Section, FormKey + '_DPI', CurDPI);

      l := TheForm.Left;
      t := TheForm.Top;
      w := TheForm.Width;
      h := TheForm.Height;

      if svSize in UseSet then
      begin
        w := Ini.ReadInteger(Section, FormKey + '_Width',  w);
        h := Ini.ReadInteger(Section, FormKey + '_Height', h);
        // Sanity guards
        if w < 50 then w := TheForm.Width;
        if h < 50 then h := TheForm.Height;
      end;

      if svLocation in UseSet then
      begin
        l := Ini.ReadInteger(Section, FormKey + '_Left', l);
        t := Ini.ReadInteger(Section, FormKey + '_Top',  t);
      end;

      // Scale only the values that were actually read from the INI
      if SavedDPI <> CurDPI then
      begin
        if svSize in UseSet then
        begin
          w := ScaleValue(w, SavedDPI, CurDPI);
          h := ScaleValue(h, SavedDPI, CurDPI);
        end;
        if svLocation in UseSet then
        begin
          l := ScaleValue(l, SavedDPI, CurDPI);
          t := ScaleValue(t, SavedDPI, CurDPI);
        end;
      end;

      TheForm.SetBounds(l, t, w, h);

      EnsureFormVisible(TheForm);
    end;

    // Panels
    if svPanels in UseSet then
    begin
      CurDPI := TheForm.PixelsPerInch;
      SavedDPI := Ini.ReadInteger(Section, FormKey + '_DPI', CurDPI);
      RestorePanelsRecursive(TheForm, Ini, Section, FormKey, SavedDPI, CurDPI);
    end;

    // Window state, applied last so maximise/minimise works correctly
    if svState in UseSet then
    begin
      stateCode := Ini.ReadInteger(Section, FormKey + '_WindowState', 2);
      case stateCode of
        1: if FSaveMinimized then
             TheForm.WindowState := wsMinimized
           else
             TheForm.WindowState := wsNormal;
        2: TheForm.WindowState := wsNormal;
        3: TheForm.WindowState := wsMaximized;
      else
        TheForm.WindowState := wsNormal;
      end;
    end;

  finally
    Ini.Free;
  end;
end;

procedure TSciRestorer.HookOwner;
var
  OwnerForm: TForm;
begin
  if (csDesigning in ComponentState) or FHooked then Exit;
  if not (Assigned(Owner) and (Owner is TForm)) then Exit;

  OwnerForm := TForm(Owner);
  FOldOwnerShow := OwnerForm.OnShow;
  FOldOwnerClose := OwnerForm.OnClose;
  OwnerForm.OnShow := @OwnerFormShow;
  OwnerForm.OnClose := @OwnerFormClose;
  FHooked := True;
end;

procedure TSciRestorer.UnhookOwner;
var
  OwnerForm: TForm;
begin
  if not FHooked then Exit;
  if Assigned(Owner) and (Owner is TForm) then
  begin
    OwnerForm := TForm(Owner);
    if not (csDestroying in OwnerForm.ComponentState) then
    begin
      OwnerForm.OnShow := FOldOwnerShow;
      OwnerForm.OnClose := FOldOwnerClose;
    end;
  end;
  FHooked := False;
end;

procedure TSciRestorer.Loaded;
begin
  inherited Loaded;
  if FAutoSaveRestoreOwner then
    HookOwner;
end;

procedure TSciRestorer.OwnerFormShow(Sender: TObject);
begin
  // Restore only on first show
  if FAutoSaveRestoreOwner and (Sender is TForm) and not FRestoredOwner then
  begin
    RestoreForm(TForm(Sender));
    FRestoredOwner := True;
  end;

  if Assigned(FOldOwnerShow) then
    FOldOwnerShow(Sender);
end;

procedure TSciRestorer.OwnerFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  // Let the user's handler run first so it can set CloseAction
  if Assigned(FOldOwnerClose) then
    FOldOwnerClose(Sender, CloseAction);

  if FAutoSaveRestoreOwner and (Sender is TForm) and (CloseAction <> caNone) then
  begin
    SaveForm(TForm(Sender));
    // Allow re-restore if the form is shown again
    if CloseAction = caHide then
      FRestoredOwner := False;
  end;
end;

procedure Register;
begin
  RegisterComponents('Science', [TSciRestorer]);
end;

end.
