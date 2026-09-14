unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, uSciDM3, uSciDM3Connector;

type
  TFormMain = class(TForm)
    ButtonOpen: TButton;
    Image1: TImage;
    OpenDialog1: TOpenDialog;
    PanelTop: TPanel;
    SciDM3: TSciDM3;
    SciDM3Connector: TSciDM3Connector;
    Splitter1: TSplitter;
    TreeView1: TTreeView;
    procedure ButtonOpenClick(Sender: TObject);
  private
  public
  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}

procedure TFormMain.ButtonOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    SciDM3.FileName := OpenDialog1.FileName;
    SciDM3.ParseDM3;
  end;
end;

end.
