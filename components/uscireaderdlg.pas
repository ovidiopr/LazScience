unit uSciReaderDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Dialogs, LResources, uTXTDialog, uSciReader;

type
  TSciReaderDlg = class(TComponent)
  private
    FReader: TSciReader;
    FFileName: String;
    FConfigFile: TFileName;
    FDialogOptions: TSciReaderDlgOptions;
    FOpenDialog: TOpenDialog;

    FCharOptions: TCharListOptions;

    function GetOptions: TTXTOptions;
    procedure SetOptions(const Value: TTXTOptions);
    procedure SetCharOptions(const Value: TCharListOptions);
    procedure SetDialogOptions(AValue: TSciReaderDlgOptions);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    function Execute: Boolean; overload;
    function Execute(const AFileName: String = ''): Boolean; overload;

    function LoadDirConfig(const ADirectory: TFileName): Boolean;

    property Options: TTXTOptions read GetOptions write SetOptions;
  published
    property Reader: TSciReader read FReader write FReader;
    property FileName: String read FFileName write FFileName;

    property ConfigFile: TFileName read FConfigFile write FConfigFile;

    property DialogOptions: TSciReaderDlgOptions read FDialogOptions write SetDialogOptions
                              default [srdDateTimeReading, srdAutoSaveConfig, srdShowFormulas];

    property OpenDialog: TOpenDialog read FOpenDialog write FOpenDialog;

    property CharOptions: TCharListOptions read FCharOptions write SetCharOptions;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Science', [TSciReaderDlg]);
end;

constructor TSciReaderDlg.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  FDialogOptions := [srdDateTimeReading, srdAutoSaveConfig, srdShowFormulas];

  FCharOptions := TCharListOptions.Create;
end;

destructor TSciReaderDlg.Destroy;
begin
  FreeAndNil(FCharOptions);
  inherited Destroy;
end;

function TSciReaderDlg.GetOptions: TTXTOptions;
begin
  if not Assigned(FReader) then
    raise Exception.Create('Reader property must be assigned before reading Options.');
  Result := FReader.Options;
end;

procedure TSciReaderDlg.SetOptions(const Value: TTXTOptions);
begin
  if not Assigned(FReader) then
    raise Exception.Create('Reader property must be assigned before writing Options.');
  FReader.Options := Value;
end;

procedure TSciReaderDlg.SetCharOptions(const Value: TCharListOptions);
begin
  FCharOptions.Assign(Value);
end;

procedure TSciReaderDlg.SetDialogOptions(AValue: TSciReaderDlgOptions);
begin
  if FDialogOptions = AValue then Exit;

  FDialogOptions := AValue;
end;

function TSciReaderDlg.Execute: Boolean;
begin
  Result := Execute(FFileName);
end;

function TSciReaderDlg.Execute(const AFileName: String): Boolean;
var
  DlgForm: TFTXTDialog;
begin
  Result := False;
  if not Assigned(FReader) then
    raise Exception.Create('Reader property must be assigned before executing dialog.');
  if not Assigned(FOpenDialog) then
    raise Exception.Create('Open Dialog property must be assigned before executing dialog.');

  if AFileName <> '' then
    FFileName := AFileName;

  DlgForm := TFTXTDialog.Create(nil);
  try
    DlgForm.ConfigFile := FConfigFile;
    DlgForm.DialogOptions := FDialogOptions;
    DlgForm.OpenDialog := FOpenDialog;
    DlgForm.CharOptions := FCharOptions;
    DlgForm.Options := FReader.Options;
    DlgForm.FileName := FFileName;

    if DlgForm.Execute then
    begin
      FReader.Options := DlgForm.Options;
      FFileName := DlgForm.FileName;

      if FFileName <> '' then
        FReader.LoadFromFile(FFileName);

      Result := True;
    end;
  finally
    DlgForm.Free;
  end;
end;

function TSciReaderDlg.LoadDirConfig(const ADirectory: TFileName): Boolean;
var
  DlgForm: TFTXTDialog;
begin
  Result := False;
  if not Assigned(FReader) then
    raise Exception.Create('Reader property must be assigned before loading configuration.');

  DlgForm := TFTXTDialog.Create(nil);
  try
    DlgForm.ConfigFile := FConfigFile;
    DlgForm.Options := FReader.Options;
    DlgForm.RestoreDirPreferences(ADirectory);
    FReader.Options := DlgForm.Options;
    Result := True;
  finally
    DlgForm.Free;
  end;
end;

initialization
  {$I LazScience.lrs}
end.
