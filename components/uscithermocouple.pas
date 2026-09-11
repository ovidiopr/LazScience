unit uSciThermoCouple;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Math;

type
  TTempUnits = (tuKelvin, tuCelsius, tuFahrenheit, tuRankine);

  TThermoCouple = (tcTypeB, tcTypeC, tcTypeE, tcTypeJ, tcTypeK,
                   tcTypeN, tcTypeR, tcTypeS, tcTypeT);

const
  ScaleShift = 273.15; // 0 degC in Kelvin
  TCNumber = 9;
  TCNames: array [1..TCNumber] of string = ('Type B', 'Type C', 'Type E',
                                            'Type J', 'Type K', 'Type N',
                                            'Type R', 'Type S', 'Type T');

type
  { TSciThermocouple }

  TSciThermocouple = class(TComponent)
  private
    FThermoCoupleType: TThermoCouple;
    FUnits: TTempUnits;
    FColdJunctionTemp: Double;
  public
    constructor Create(AOwner: TComponent); override;

    function VoltageToTemperature(const Voltage: Double): Double; overload;
    function VoltageToTemperature(const Voltage: Double; const CustomTcj: Double): Double; overload;
    function TemperatureToVoltage(const Temperature: Double): Double;

  published
    property ThermoCoupleType: TThermoCouple read FThermoCoupleType write FThermoCoupleType default tcTypeK;
    property Units: TTempUnits read FUnits write FUnits default tuCelsius;
    property ColdJunctionTemp: Double read FColdJunctionTemp write FColdJunctionTemp;
  end;

procedure Register;

implementation

// Generic helper

function PolyEval(const Coeffs: array of Double; const x: Double): Double;
var
  i: Integer;
begin
  if Length(Coeffs) = 0 then
    Exit(0.0);
  Result := Coeffs[High(Coeffs)];
  for i := High(Coeffs) - 1 downto Low(Coeffs) do
    Result := Result*x + Coeffs[i];
end;

// Functions to translate to/from Celsius from/to the other three scales

function ToCelsius(const Value: Double; Units: TTempUnits): Double;
begin
  case Units of
    tuKelvin: Result := Value - ScaleShift;
    tuCelsius: Result := Value;
    tuFahrenheit: Result := (Value - 32.0)/1.8;
    tuRankine: Result := Value/1.8 - ScaleShift;
    else Result := NaN;
  end;
end;

function FromCelsius(const Value: Double; Units: TTempUnits): Double;
begin
  case Units of
    tuKelvin: Result := Value + ScaleShift;
    tuCelsius: Result := Value;
    tuFahrenheit: Result := Value*1.8 + 32.0;
    tuRankine: Result := (Value + ScaleShift)*1.8;
    else Result := NaN;
  end;
end;

// Each pair below converts one thermocouple type between Celsius and volts

function CelsiusToVoltageTypeB(const Temperature: Double): Double;
const
  // For temperatures between 0 and 630.615 degC
  CoeffsA: array[0..6] of Double = (0.0000000000E+00,
                                   -2.4650818346E-04,
                                    5.9040421171E-06,
                                   -1.3257931636E-09,
                                    1.5668291901E-12,
                                   -1.6944529240E-15,
                                    6.2290347094E-19);
  // For temperatures between 630.615 and 1820 degC
  CoeffsB: array[0..8] of Double = (-3.8938168621E+00,
                                     2.8571747470E-02,
                                    -8.4885104785E-05,
                                     1.5785280164E-07,
                                    -1.6835344864E-10,
                                     1.1109794013E-13,
                                    -4.4515431033E-17,
                                     9.8975640821E-21,
                                    -9.3791330289E-25);
begin
  if (Temperature < 0.0) or (Temperature > 1820.0) then
    Result := NaN
  else if (Temperature < 630.615) then
    Result := PolyEval(CoeffsA, Temperature)
  else
    Result := PolyEval(CoeffsB, Temperature);
end;

function VoltageToCelsiusTypeB(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between 0 and 250 degC, error = 3
  CoeffsA: array[0..8] of Double = (3.1789090E+01,
                                    3.4448163E+03,
                                   -5.3374301E+04,
                                    5.2049290E+05,
                                   -2.8550200E+06,
                                    9.0559800E+06,
                                   -1.6488200E+07,
                                    1.5984200E+07,
                                   -6.3901800E+06);
  // For temperatures between 250 and 700 degC, error = 0.03
  CoeffsB: array[0..8] of Double = (9.8423321E+01,
                                    6.9971500E+02,
                                   -8.4765304E+02,
                                    1.0052644E+03,
                                   -8.3345952E+02,
                                    4.5508542E+02,
                                   -1.5523037E+02,
                                    2.9886750E+01,
                                   -2.4742860E+00);
  // For temperatures between 700 and 1820 degC, error = 0.02
  CoeffsC: array[0..8] of Double = (2.1315071E+02,
                                    2.8510504E+02,
                                   -5.2742887E+01,
                                    9.9160804E+00,
                                   -1.2965303E+00,
                                    1.1195870E-01,
                                   -6.0625199E-03,
                                    1.8661696E-04,
                                   -2.4878585E-06);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeB(Tcj);
  if (VoltCorrect < 0.0) or (VoltCorrect > 13.820) then
    Result := NaN
  else if (VoltCorrect < 0.291) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else if (VoltCorrect < 2.431) then
    Result := PolyEval(CoeffsB, VoltCorrect)
  else
    Result := PolyEval(CoeffsC, VoltCorrect);
end;

function CelsiusToVoltageTypeC(const Temperature: Double): Double;
const
  // For temperatures between 0 and 2315 degC, error = 1%  (local fit)
  Coeffs: array[0..6] of Double = (0.00000E00,
                                   1.33300E-02,
                                   1.25261E-05,
                                  -1.08382E-08,
                                   3.70800E-12,
                                  -4.64562E-16,
                                  -1.35135E-20);
begin
  if (Temperature < 0.0) or (Temperature > 2315.0) then
    Result := NaN
  else
    Result := PolyEval(Coeffs, Temperature);
end;

function VoltageToCelsiusTypeC(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between 0 and 631 degC, error = 0.04
  CoeffsA: array[0..6] of Double = (0.0000000E+00,
                                    7.4411468E+01,
                                   -4.5680255E+00,
                                    6.0972079E-01,
                                   -5.5888380E-02,
                                    2.9645590E-03,
                                   -6.5745000E-05);
  // For temperatures between 631 and 2315 degC, error = 0.3
  CoeffsB: array[0..6] of Double = (4.1102500E+02,
                                   -6.1463789E+01,
                                    1.4651879E+01,
                                   -9.9683382E-01,
                                    3.7141869E-02,
                                   -7.0836000E-04,
                                    5.5012700E-06);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeC(Tcj);
  if (VoltCorrect < 0.0) or (VoltCorrect > 37.107) then
    Result := NaN
  else if (VoltCorrect < 11.3) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else
    Result := PolyEval(CoeffsB, VoltCorrect);
end;

function CelsiusToVoltageTypeE(const Temperature: Double): Double;
const
  // For temperatures between -270 and 0 degC
  CoeffsA: array[0..13] of Double = (0.000000000000E+00,
                                     0.586655087080E-01,
                                     0.454109771240E-04,
                                    -0.779980486860E-06,
                                    -0.258001608430E-07,
                                    -0.594525830570E-09,
                                    -0.932140586670E-11,
                                    -0.102876055340E-12,
                                    -0.803701236210E-15,
                                    -0.439794973910E-17,
                                    -0.164147763550E-19,
                                    -0.396736195160E-22,
                                    -0.558273287210E-25,
                                    -0.346578420130E-28);
  // For temperatures between 0 and 1000 degC
  CoeffsB: array[0..10] of Double = (0.000000000000E+00,
                                     0.586655087100E-01,
                                     0.450322755820E-04,
                                     0.289084072120E-07,
                                    -0.330568966520E-09,
                                     0.650244032700E-12,
                                    -0.191974955040E-15,
                                    -0.125366004970E-17,
                                     0.214892175690E-20,
                                    -0.143880417820E-23,
                                     0.359608994810E-27);
begin
  if (Temperature < -270.0) or (Temperature > 1000.0) then
    Result := NaN
  else if (Temperature < 0.0) then
    Result := PolyEval(CoeffsA, Temperature)
  else
    Result := PolyEval(CoeffsB, Temperature);
end;

function VoltageToCelsiusTypeE(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between -200 and 0 degC, error = 0.03
  CoeffsA: array[0..8] of Double = (0.0000000E+00,
                                    1.6977288E+01,
                                   -4.3514970E-01,
                                   -1.5859697E-01,
                                   -9.2502871E-02,
                                   -2.6084314E-02,
                                   -4.1360199E-03,
                                   -3.4034030E-04,
                                   -1.1564890E-05);
  // For temperatures between 0 and 1000 degC, error = 0.02
  CoeffsB: array[0..9] of Double = (0.0000000E+00,
                                    1.7057035E+01,
                                   -2.3301759E-01,
                                    6.5435585E-03,
                                   -7.3562749E-05,
                                   -1.7896001E-06,
                                    8.4036165E-08,
                                   -1.3735879E-09,
                                    1.0629823E-11,
                                   -3.2447087E-14);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeE(Tcj);
  if (VoltCorrect < -8.825) or (VoltCorrect > 76.373) then
    Result := NaN
  else if (VoltCorrect < 11.3) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else
    Result := PolyEval(CoeffsB, VoltCorrect);
end;

function CelsiusToVoltageTypeJ(const Temperature: Double): Double;
const
  // For temperatures between -210 and 1200 degC
  CoeffsA: array[0..8] of Double = (0.000000000000E+00,
                                    0.503811878150E-01,
                                    0.304758369300E-04,
                                   -0.856810657200E-07,
                                    0.132281952950E-09,
                                   -0.170529583370E-12,
                                    0.209480906970E-15,
                                   -0.125383953360E-18,
                                    0.156317256970E-22);
begin
  if (Temperature < -210.0) or (Temperature > 1200.0) then
    Result := NaN
  else
    Result := PolyEval(CoeffsA, Temperature);
end;

function VoltageToCelsiusTypeJ(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between -210 and 0 degC
  CoeffsA: array[0..8] of Double = (0.0000000E+00,
                                    1.9528268E+01,
                                   -1.2286185E+00,
                                   -1.0752178E+00,
                                   -5.9086933E-01,
                                   -1.7256713E-01,
                                   -2.8131513E-02,
                                   -2.3963370E-03,
                                   -8.3823321E-05);
  // For temperatures between 0 and 500 degC, error = 0.05
  CoeffsB: array[0..7] of Double = (0.000000E+00,
                                    1.978425E+01,
                                   -2.001204E-01,
                                    1.036969E-02,
                                   -2.549687E-04,
                                    3.585153E-06,
                                   -5.344285E-08,
                                    5.099890E-10);
  // For temperatures between 500 and 1372 degC, error = 0.06
  CoeffsC: array[0..6] of Double = (-1.3180580E+02,
                                     4.8302220E+01,
                                    -1.6460310E+00,
                                     5.4647310E-02,
                                    -9.6507150E-04,
                                     8.8021930E-06,
                                    -3.1108100E-08);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeJ(Tcj);
  if (VoltCorrect < -8.095) or (VoltCorrect > 69.553) then
    Result := NaN
  else if (VoltCorrect < 0.0) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else if (VoltCorrect < 42.919) then
    Result := PolyEval(CoeffsB, VoltCorrect)
  else
    Result := PolyEval(CoeffsC, VoltCorrect);
end;

function CelsiusToVoltageTypeK(const Temperature: Double): Double;
const
  // For temperatures between -270 and 0 degC
  CoeffsA: array[0..10] of Double = (0.0000000000E+00,
                                     3.9450128025E-02,
                                     2.3622373598E-05,
                                    -3.2858906784E-07,
                                    -4.9904828777E-09,
                                    -6.7509059173E-11,
                                    -5.7410327428E-13,
                                    -3.1088872894E-15,
                                    -1.0451609365E-17,
                                    -1.9889266878E-20,
                                    -1.6322697486E-23);
  // For temperatures between 0 and 1372 degC
  CoeffsB: array[0..9] of Double = (-1.7600413686E-02,
                                     3.8921204975E-02,
                                     1.8558770032E-05,
                                    -9.9457592874E-08,
                                     3.1840945719E-10,
                                    -5.6072844889E-13,
                                     5.6075059059E-16,
                                    -3.2020720003E-19,
                                     9.7151147152E-23,
                                    -1.2104721275E-26);
begin
  if (Temperature < -270.0) or (Temperature > 1372.0) then
    Result := NaN
  else if (Temperature < 0.0) then
    Result := PolyEval(CoeffsA, Temperature)
  else
    Result := PolyEval(CoeffsB, Temperature) + 0.1185976*exp(-1.183432E-4*sqr(Temperature - 126.9686));
end;

function VoltageToCelsiusTypeK(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between -200 and 0 degC, error = 0.04
  CoeffsA: array[0..8] of Double = (0.0000000E+00,
                                    2.5173462E+01,
                                   -1.1662878E+00,
                                   -1.0833638E+00,
                                   -8.9773540E-01,
                                   -3.7342377E-01,
                                   -8.6632643E-02,
                                   -1.0450598E-02,
                                   -5.1920577E-04);
  // For temperatures between 0 and 500 degC, error = 0.05
  CoeffsB: array[0..9] of Double = (0.0000000E+00,
                                    2.5083550E+01,
                                    7.8601060E-02,
                                   -2.5031310E-01,
                                    8.3152700E-02,
                                   -1.2280340E-02,
                                    9.8040360E-04,
                                   -4.4130300E-05,
                                    1.0577340E-06,
                                   -1.0527550E-08);
  // For temperatures between 500 and 1372 degC, error = 0.06
  CoeffsC: array[0..6] of Double = (-1.3180580E+02,
                                     4.8302220E+01,
                                    -1.6460310E+00,
                                     5.4647310E-02,
                                    -9.6507150E-04,
                                     8.8021930E-06,
                                    -3.1108100E-08);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeK(Tcj);
  if (VoltCorrect < -5.891) or (VoltCorrect > 54.886) then
    Result := NaN
  else if (VoltCorrect < 0.0) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else if (VoltCorrect < 20.644) then
    Result := PolyEval(CoeffsB, VoltCorrect)
  else
    Result := PolyEval(CoeffsC, VoltCorrect);
end;

function CelsiusToVoltageTypeN(const Temperature: Double): Double;
const
  // For temperatures between -270 and 1300 degC
  CoeffsA: array[0..10] of Double = (0.000000000000E+00,
                                     0.259293946010E-01,
                                     0.157101418800E-04,
                                     0.438256272370E-07,
                                    -0.252611697940E-09,
                                     0.643118193390E-12,
                                    -0.100634715190E-14,
                                     0.997453389920E-18,
                                    -0.608632456070E-21,
                                     0.208492293390E-24,
                                    -0.306821961510E-28);
begin
  if (Temperature < -270.0) or (Temperature > 1300.0) then
    Result := NaN
  else
    Result := PolyEval(CoeffsA, Temperature);
end;

function VoltageToCelsiusTypeN(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between -270 and 0 degC
  CoeffsA: array[0..9] of Double = (0.0000000E+00,
                                    3.8436847E+01,
                                    1.1010485E+00,
                                    5.2229312E+00,
                                    7.2060525E+00,
                                    5.8488586E+00,
                                    2.7754916E+00,
                                    7.7075166E-01,
                                    1.1582665E-01,
                                    7.3138868E-03);
  // For temperatures between 0 and 600 degC
  CoeffsB: array[0..7] of Double = (0.00000E+00,
                                    3.86896E+01,
                                   -1.08267E+00,
                                    4.70205E-02,
                                   -2.12169E-06,
                                   -1.17272E-04,
                                    5.39280E-06,
                                   -7.98156E-08);
  // For temperatures between 600 and 1300 degC
  CoeffsC: array[0..5] of Double = (1.972485E+01,
                                    3.300943E+01,
                                   -3.915159E-01,
                                    9.855391E-03,
                                   -1.274371E-04,
                                    7.767022E-07);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeN(Tcj);
  if (VoltCorrect < -4.345) or (VoltCorrect > 47.513) then
    Result := NaN
  else if (VoltCorrect < 0.0) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else if (VoltCorrect < 20.613) then
    Result := PolyEval(CoeffsB, VoltCorrect)
  else
    Result := PolyEval(CoeffsC, VoltCorrect);
end;

function CelsiusToVoltageTypeR(const Temperature: Double): Double;
const
  // For temperatures between -50 and 1768 degC
  CoeffsA: array[0..9] of Double = (0.000000000000E+00,
                                    0.528961729765E-02,
                                    0.139166589782E-04,
                                   -0.238855693017E-07,
                                    0.356916001063E-10,
                                   -0.462347666298E-13,
                                    0.500777441034E-16,
                                   -0.373105886191E-19,
                                    0.157716482367E-22,
                                   -0.281038625251E-26);
begin
  if (Temperature < -50.0) or (Temperature > 1768.0) then
    Result := NaN
  else
    Result := PolyEval(CoeffsA, Temperature);
end;

function VoltageToCelsiusTypeR(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between -50 and 250 degC
  CoeffsA: array[0..10] of Double = (0.0000000E+00,
                                     1.8891380E+02,
                                    -9.3835290E+01,
                                     1.3068619E+02,
                                    -2.2703580E+02,
                                     3.5145659E+02,
                                    -3.8953900E+02,
                                     2.8239471E+02,
                                    -1.2607281E+02,
                                     3.1353611E+01,
                                    -3.3187769E+00);
  // For temperatures between 250 and 1200 degC
  CoeffsB: array[0..9] of Double = (1.334584505E+01,
                                    1.472644573E+02,
                                   -1.844024844E+01,
                                    4.031129726E+00,
                                   -6.249428360E-01,
                                    6.468412046E-02,
                                   -4.458750426E-03,
                                    1.994710149E-04,
                                   -5.313401790E-06,
                                    6.481976217E-08);
  // For temperatures between 1200 and 1675 degC
  CoeffsC: array[0..5] of Double = (-8.199599416E+01,
                                     1.553962042E+02,
                                    -8.342197663E+00,
                                     4.279433549E-01,
                                    -1.191577910E-02,
                                     1.492290091E-04);
  // For temperatures between 1675 and 1768 degC
  CoeffsD: array[0..4] of Double = (3.406177836E+04,
                                   -7.023729171E+03,
                                    5.582903813E+02,
                                   -1.952394635E+01,
                                    2.560740231E-01);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeR(Tcj);
  if (VoltCorrect < -0.226) or (VoltCorrect > 21.103) then
    Result := NaN
  else if (VoltCorrect < 1.923) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else if (VoltCorrect < 13.228) then
    Result := PolyEval(CoeffsB, VoltCorrect)
  else if (VoltCorrect < 19.739) then
    Result := PolyEval(CoeffsC, VoltCorrect)
  else
    Result := PolyEval(CoeffsD, VoltCorrect);
end;

function CelsiusToVoltageTypeS(const Temperature: Double): Double;
const
  // For temperatures between -50 and 1768 degC
  CoeffsA: array[0..8] of Double = (0.000000000000E+00,
                                    0.540313308631E-02,
                                    0.125934289740E-04,
                                   -0.232477968689E-07,
                                    0.322028823036E-10,
                                   -0.331465196389E-13,
                                    0.255744251786E-16,
                                   -0.125068871393E-19,
                                    0.271443176145E-23);
begin
  if (Temperature < -50.0) or (Temperature > 1768.0) then
    Result := NaN
  else
    Result := PolyEval(CoeffsA, Temperature);
end;

function VoltageToCelsiusTypeS(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between -50 and 250 degC
  CoeffsA: array[0..9] of Double = (0.00000000E+00,
                                    1.84949460E+02,
                                   -8.00504062E+01,
                                    1.02237430E+02,
                                   -1.52248592E+02,
                                    1.88821343E+02,
                                   -1.59085941E+02,
                                    8.23027880E+01,
                                   -2.34181944E+01,
                                    2.79786260E+00);
  // For temperatures between 250 and 1200 degC
  CoeffsB: array[0..9] of Double = (1.291507177E+01,
                                    1.466298863E+02,
                                   -1.534713402E+01,
                                    3.145945973E+00,
                                   -4.163257839E-01,
                                    3.187963771E-02,
                                   -1.291637500E-03,
                                    2.183475087E-05,
                                   -1.447379511E-07,
                                    8.211272125E-09);
  // For temperatures between 1200 and 1664 degC
  CoeffsC: array[0..5] of Double = (-8.087801117E+01,
                                     1.621573104E+02,
                                    -8.536869453E+00,
                                     4.719686976E-01,
                                    -1.441693666E-02,
                                     2.081618890E-04);
  // For temperatures between 1664 and 1768 degC
  CoeffsD: array[0..4] of Double = (5.333875126E+04,
                                   -1.235892298E+04,
                                    1.092657613E+03,
                                   -4.265693686E+01,
                                    6.247205420E-01);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeS(Tcj);
  if (VoltCorrect < -0.236) or (VoltCorrect > 18.693) then
    Result := NaN
  else if (VoltCorrect < 1.874) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else if (VoltCorrect < 11.950) then
    Result := PolyEval(CoeffsB, VoltCorrect)
  else if (VoltCorrect < 17.536) then
    Result := PolyEval(CoeffsC, VoltCorrect)
  else
    Result := PolyEval(CoeffsD, VoltCorrect);
end;

function CelsiusToVoltageTypeT(const Temperature: Double): Double;
const
  // For temperatures between -270 and 400 degC
  CoeffsA: array[0..8] of Double = (0.000000000000E+00,
                                    0.387481063640E-01,
                                    0.332922278800E-04,
                                    0.206182434040E-06,
                                   -0.218822568460E-08,
                                    0.109968809280E-10,
                                   -0.308157587720E-13,
                                    0.454791352900E-16,
                                   -0.275129016730E-19);
begin
  if (Temperature < -270.0) or (Temperature > 400.0) then
    Result := NaN
  else
    Result := PolyEval(CoeffsA, Temperature);
end;

function VoltageToCelsiusTypeT(const Voltage: Double; const Tcj: Double = 0.0): Double;
var
  VoltCorrect: Double;
const
  // For temperatures between -270 and 0 degC
  CoeffsA: array[0..7] of Double = (0.0000000E+00,
                                    2.5949192E+01,
                                   -2.1316967E-01,
                                    7.9018692E-01,
                                    4.2527777E-01,
                                    1.3304473E-01,
                                    2.0241446E-02,
                                    1.2668171E-03);
  // For temperatures between 0 and 400 degC
  CoeffsB: array[0..6] of Double = (0.000000E+00,
                                    2.592800E+01,
                                   -7.602961E-01,
                                    4.637791E-02,
                                   -2.165394E-03,
                                    6.048144E-05,
                                   -7.293422E-07);
begin
  VoltCorrect := Voltage + CelsiusToVoltageTypeT(Tcj);
  if (VoltCorrect < -6.258) or (VoltCorrect > 20.872) then
    Result := NaN
  else if (VoltCorrect < 0.0) then
    Result := PolyEval(CoeffsA, VoltCorrect)
  else
    Result := PolyEval(CoeffsB, VoltCorrect);
end;

// Public conversion
function CelsiusToVoltage(const Temperature: Double; TC_Type: TThermoCouple): Double;
begin
  case TC_Type of
    tcTypeB: Result := CelsiusToVoltageTypeB(Temperature);
    tcTypeC: Result := CelsiusToVoltageTypeC(Temperature);
    tcTypeE: Result := CelsiusToVoltageTypeE(Temperature);
    tcTypeJ: Result := CelsiusToVoltageTypeJ(Temperature);
    tcTypeK: Result := CelsiusToVoltageTypeK(Temperature);
    tcTypeN: Result := CelsiusToVoltageTypeN(Temperature);
    tcTypeR: Result := CelsiusToVoltageTypeR(Temperature);
    tcTypeS: Result := CelsiusToVoltageTypeS(Temperature);
    tcTypeT: Result := CelsiusToVoltageTypeT(Temperature);
    else Result := NaN;
  end;
end;

function VoltageToCelsius(const Voltage: Double; TC_Type: TThermoCouple; const Tcj: Double = 0.0): Double;
begin
  case TC_Type of
    tcTypeB: Result := VoltageToCelsiusTypeB(Voltage, Tcj);
    tcTypeC: Result := VoltageToCelsiusTypeC(Voltage, Tcj);
    tcTypeE: Result := VoltageToCelsiusTypeE(Voltage, Tcj);
    tcTypeJ: Result := VoltageToCelsiusTypeJ(Voltage, Tcj);
    tcTypeK: Result := VoltageToCelsiusTypeK(Voltage, Tcj);
    tcTypeN: Result := VoltageToCelsiusTypeN(Voltage, Tcj);
    tcTypeR: Result := VoltageToCelsiusTypeR(Voltage, Tcj);
    tcTypeS: Result := VoltageToCelsiusTypeS(Voltage, Tcj);
    tcTypeT: Result := VoltageToCelsiusTypeT(Voltage, Tcj);
    else Result := NaN;
  end;
end;

function TemperatureToVoltage(const Temperature: Double; TC_Type: TThermoCouple; Units: TTempUnits): Double;
begin
  Result := CelsiusToVoltage(ToCelsius(Temperature, Units), TC_Type);
end;

function VoltageToTemperature(const Voltage: Double; TC_Type: TThermoCouple; Units: TTempUnits; const Tcj: Double): Double;
begin
  // Tcj must be given in the same Units as the call (e.g. pass 273.15 for a
  // 0 degC cold junction when Units = tuKelvin)
  Result := FromCelsius(VoltageToCelsius(Voltage, TC_Type, ToCelsius(Tcj, Units)), Units);
end;

// TSciThermocouple implementation

constructor TSciThermocouple.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FThermoCoupleType := tcTypeK;
  FUnits := tuCelsius;
  FColdJunctionTemp := 0.0;
end;

function TSciThermocouple.VoltageToTemperature(const Voltage: Double): Double;
begin
  Result := uSciThermoCouple.VoltageToTemperature(Voltage, FThermoCoupleType, FUnits, FColdJunctionTemp);
end;

function TSciThermocouple.VoltageToTemperature(const Voltage: Double; const CustomTcj: Double): Double;
begin
  Result := uSciThermoCouple.VoltageToTemperature(Voltage, FThermoCoupleType, FUnits, CustomTcj);
end;

function TSciThermocouple.TemperatureToVoltage(const Temperature: Double): Double;
begin
  Result := uSciThermoCouple.TemperatureToVoltage(Temperature, FThermoCoupleType, FUnits);
end;

// IDE registration
procedure Register;
begin
  RegisterComponents('Science', [TSciThermocouple]);
end;

end.
