unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls,
  uSciPeriodicTable, uSciPeriodicTableDlg;

type

  { TForm1 }

  TForm1 = class(TForm)
    btnSelect: TButton;
    SciPeriodicTable1: TSciPeriodicTable;
    SciPeriodicTableDlg1: TSciPeriodicTableDlg;
    procedure btnSelectClick(Sender: TObject);
    procedure SciPeriodicTable1ElementDblClick(Sender: TObject;
      Element: TSciElement);
  private

  public

  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

procedure TForm1.btnSelectClick(Sender: TObject);
begin
  if SciPeriodicTableDlg1.Execute then
  begin
    ShowMessage('Element selected: ' + SciPeriodicTableDlg1.Element.Name);
    SciPeriodicTable1.Selected := SciPeriodicTableDlg1.Element;
  end;
end;

procedure TForm1.SciPeriodicTable1ElementDblClick(Sender: TObject; Element: TSciElement);
begin
  ShowMessage('Element selected: ' + Element.Name);
end;

end.

