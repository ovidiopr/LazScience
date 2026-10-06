unit uSciPeriodicTableDlg;

{$mode objfpc}{$H+}

{ TSciPeriodicTableDlg - non-visual component that lets the user pick an
  element from a (resizable) periodic table dialog, in the style of
  TOpenDialog:

    SciPeriodicTableDlg1.SelectedNumber := 26;     // initial selection
    if SciPeriodicTableDlg1.Execute then
      ShowMessage(SciPeriodicTableDlg1.Element.Name);

  The look of the dialog's table (colors, font, ShowDetails, initial
  selection) is configured through the Table property, which exposes a
  TSciPeriodicTable in the Object Inspector. Only its appearance and
  selection are used: its position, size and events are ignored. }

interface

uses
  Classes, SysUtils, Controls, uSciPeriodicTable;

type

  { TSciPeriodicTableDlg }

  TSciPeriodicTableDlg = class(TComponent)
  private
    FTitle: string;
    FTable: TSciPeriodicTable; // template for the table shown in the dialog
    function GetElement: TSciElement;
    function GetSelectedNumber: Integer;
    procedure SetSelectedNumber(AValue: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    { Shows the dialog modally. Returns True if the user accepted an element,
      which is then available in SelectedNumber / Element. }
    function Execute: Boolean;
    { The selected element (shared data, valid for the whole program run) }
    property Element: TSciElement read GetElement;
    { Atomic number of the selected element; also the initial selection }
    property SelectedNumber: Integer read GetSelectedNumber write SetSelectedNumber;
  published
    { Dialog caption; empty keeps the default one }
    property Title: string read FTitle write FTitle;
    { Configuration of the table shown in the dialog }
    property Table: TSciPeriodicTable read FTable;
  end;

implementation

uses
  uPeriodicTableDlg;

{ TSciPeriodicTableDlg }

constructor TSciPeriodicTableDlg.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FTable := TSciPeriodicTable.Create(Self); // freed together with the component
  FTable.Name := 'Table';
  FTable.SetSubComponent(True);
end;

function TSciPeriodicTableDlg.GetElement: TSciElement;
begin
  Result := FTable.Selected;
end;

function TSciPeriodicTableDlg.GetSelectedNumber: Integer;
begin
  Result := FTable.SelectedNumber;
end;

procedure TSciPeriodicTableDlg.SetSelectedNumber(AValue: Integer);
begin
  FTable.SelectedNumber := AValue;
end;

function TSciPeriodicTableDlg.Execute: Boolean;
var
  Form: TfrmPeriodicTableDlg;
begin
  Form := TfrmPeriodicTableDlg.Create(nil);
  try
    if FTitle <> '' then
      Form.Caption := FTitle;
    Form.SciPeriodicTable.Assign(FTable);
    Result := Form.ShowModal = mrOK;
    if Result then
      FTable.SelectedNumber := Form.SelectedNumber;
  finally
    Form.Free;
  end;
end;

end.
