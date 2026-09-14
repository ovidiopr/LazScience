unit uMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls,
  TAGraph, TASeries, Math, uSciThermoCouple;

type
  { TForm1 }
  TForm1 = class(TForm)
    ChartTtoV: TChart;
    ChartVtoT: TChart;
    PageControl1: TPageControl;
    SciTC: TSciThermocouple;
    TabSheet1: TTabSheet;
    TabSheet2: TTabSheet;
    procedure FormCreate(Sender: TObject);
  private
    procedure PopulateDirectChart;
    procedure PopulateInverseChart;
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

const
  TCColors: array[TThermoCouple] of TColor = (clRed, clBlue, clGreen, clFuchsia,
                                              clTeal, clNavy, clMaroon, clOlive,
                                              clPurple);

{ TForm1 }

procedure TForm1.FormCreate(Sender: TObject);
begin
  SciTC.Units := tuCelsius;
  SciTC.ColdJunctionTemp := 0.0;

  PopulateDirectChart;
  PopulateInverseChart;
end;

procedure TForm1.PopulateDirectChart;
var
  TC: TThermoCouple;
  Series: TLineSeries;
  Temp, Volt: Double;
begin
  // Direct Polynomial Sweep: T -> V
  for TC := Low(TThermoCouple) to High(TThermoCouple) do
  begin
    SciTC.ThermoCoupleType := TC;

    Series := TLineSeries.Create(ChartTtoV);
    Series.Title := TCNames[Ord(TC) + 1];
    Series.SeriesColor := TCColors[TC];
    ChartTtoV.AddSeries(Series);

    Temp := -270.0;
    while Temp <= 2400.0 do
    begin
      // Evaluates the direct polynomial function for Temperature
      Volt := SciTC.TemperatureToVoltage(Temp);

      if not IsNaN(Volt) then
        Series.AddXY(Temp, Volt);

      Temp := Temp + 2.0;
    end;
  end;
end;

procedure TForm1.PopulateInverseChart;
var
  TC: TThermoCouple;
  Series: TLineSeries;
  Volt, Temp: Double;
begin
  // Inverse Polynomial Sweep: V -> T
  for TC := Low(TThermoCouple) to High(TThermoCouple) do
  begin
    SciTC.ThermoCoupleType := TC;

    Series := TLineSeries.Create(ChartVtoT);
    Series.Title := TCNames[Ord(TC) + 1];
    Series.SeriesColor := TCColors[TC];
    ChartVtoT.AddSeries(Series);

    // Sweep voltage range across all standard thermocouple ranges (-10 mV to +80 mV)
    Volt := -10.0;
    while Volt <= 80.0 do
    begin
      // Evaluates the inverse polynomial function for Voltage
      Temp := SciTC.VoltageToTemperature(Volt);

      if not IsNaN(Temp) then
        Series.AddXY(Volt, Temp);

      Volt := Volt + 0.1;
    end;
  end;
end;

end.
