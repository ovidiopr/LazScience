unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons, TAGraph,
  TASeries, uSciReader, uSciReaderDlg;

type
  { TMainForm }
  TMainForm = class(TForm)
    btnLoadPlot: TBitBtn;
    Chart1: TChart;
    SciReader1: TSciReader;
    SciReaderDlg1: TSciReaderDlg;
    OpenDialog1: TOpenDialog;

    procedure btnLoadPlotClick(Sender: TObject);
  private
  public
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}

{ TMainForm }

procedure TMainForm.btnLoadPlotClick(Sender: TObject);
var
  LineSeries: TLineSeries;
  i: Integer;
  xVal, yVal: Double;
begin
  if not OpenDialog1.Execute then
    Exit;

  if not SciReaderDlg1.Execute(OpenDialog1.FileName) then
    Exit;

  // Configure the Chart
  Chart1.Series.Clear;
  LineSeries := TLineSeries.Create(Chart1);
  LineSeries.SeriesColor := clRed;
  Chart1.AddSeries(LineSeries);

  // Apply the user's custom axis labels
  Chart1.BottomAxis.Title.Caption := SciReader1.Options.XLbl;
  Chart1.BottomAxis.Title.Visible := True;
  Chart1.LeftAxis.Title.Caption := SciReader1.Options.YLbl;
  Chart1.LeftAxis.Title.Visible := True;

  // Loop through the rows and populate the series
  for i := 0 to SciReader1.RowCount - 1 do
  begin
    xVal := SciReader1.Value[SciReader1.Options.XCol, i];
    yVal := SciReader1.Value[SciReader1.Options.YCol, i];

    LineSeries.AddXY(xVal, yVal);
  end;
end;

end.
