unit uPeriodicTableDlg;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ButtonPanel, uSciPeriodicTable;

type

  { TfrmPeriodicTableDlg }

  TfrmPeriodicTableDlg = class(TForm)
    ButtonPanel: TButtonPanel;
    SciPeriodicTable: TSciPeriodicTable;
    procedure SciPeriodicTableElementDblClick(Sender: TObject; Element: TSciElement);
  private
    function GetSelectedNumber: Integer;
    procedure SetSelectedNumber(AValue: Integer);
  public
    property SelectedNumber: Integer read GetSelectedNumber write SetSelectedNumber;
  end;

implementation

{$R *.lfm}

{ TfrmPeriodicTableDlg }

function TfrmPeriodicTableDlg.GetSelectedNumber: Integer;
begin
  Result := SciPeriodicTable.SelectedNumber;
end;

procedure TfrmPeriodicTableDlg.SetSelectedNumber(AValue: Integer);
begin
  SciPeriodicTable.SelectedNumber := AValue;
end;

// Double click on an element is the same as pressing Accept
procedure TfrmPeriodicTableDlg.SciPeriodicTableElementDblClick(Sender: TObject; Element: TSciElement);
begin
  ModalResult := mrOK;
end;

end.
