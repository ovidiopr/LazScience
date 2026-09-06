unit uUnitParser;

{$mode objfpc}{$H+}
{$codepage utf8}

interface

uses
  Classes, SysUtils, Math;

type
  // Seven SI base units
  TUnitDimension = array[0..6] of Integer;

  TPhysicalQuantity = record
    Multiplier: Double;
    Offset: Double;
    Dimensions: TUnitDimension;
  end;

  TUnitFamily = (ufAny, ufNone, ufLength, ufMass, ufTime, ufVoltage, ufCurrent,
                 ufResistance, ufFrequency, ufPressure, ufTemperature,
                 ufForce, ufEnergy, ufPower, ufVolume, ufVelocity, ufDensity,
                 ufVolumetricFlow, ufMassFlow, ufGasThroughput, ufAcceleration,
                 ufArea, ufCharge, ufCapacitance, ufInductance, ufMagneticFlux,
                 ufMagneticField, ufWavenumber, ufCustom);

  TSIPrefixKind = (pkQuecto, pkRonto, pkYocto, pkZepto, pkAtto, pkFemto, pkPico,
                   pkNano, pkMicro, pkMilli, pkCenti, pkDeci, pkNone, pkDeca,
                   pkHecto, pkKilo, pkMega, pkGiga, pkTera, pkPeta, pkExa,
                   pkZetta, pkYotta, pkRonna, pkQuetta);

  TSIPrefixRec = record
    Kind: TSIPrefixKind;
    Symbol: String;
    AltSymbol: String; // Secondary symbol (e.g. 'u' for 'µ')
    Exponent: Integer;
    Common: Boolean;
  end;

  TUnitAliasRec = record
    Symbol: String;
  end;

  TUnitFamilyInfo = record
    Family: TUnitFamily;
    BaseSymbol: String;
    Name: String;
    AliasCount: Integer;
    Aliases: array[0..7] of TUnitAliasRec;
  end;

const
  SIPrefixCount = 25;
  // SI Prefixes
  SIPrefixes: array[TSIPrefixKind] of TSIPrefixRec = (
    (Kind: pkQuecto; Symbol: 'q';  AltSymbol: '';  Exponent: -30; Common: False),
    (Kind: pkRonto;  Symbol: 'r';  AltSymbol: '';  Exponent: -27; Common: False),
    (Kind: pkYocto;  Symbol: 'y';  AltSymbol: '';  Exponent: -24; Common: False),
    (Kind: pkZepto;  Symbol: 'z';  AltSymbol: '';  Exponent: -21; Common: False),
    (Kind: pkAtto;   Symbol: 'a';  AltSymbol: '';  Exponent: -18; Common: False),
    (Kind: pkFemto;  Symbol: 'f';  AltSymbol: '';  Exponent: -15; Common: True),
    (Kind: pkPico;   Symbol: 'p';  AltSymbol: '';  Exponent: -12; Common: True),
    (Kind: pkNano;   Symbol: 'n';  AltSymbol: '';  Exponent: -9;  Common: True),
    (Kind: pkMicro;  Symbol: 'µ';  AltSymbol: 'u'; Exponent: -6;  Common: True),
    (Kind: pkMilli;  Symbol: 'm';  AltSymbol: '';  Exponent: -3;  Common: True),
    (Kind: pkCenti;  Symbol: 'c';  AltSymbol: '';  Exponent: -2;  Common: False),
    (Kind: pkDeci;   Symbol: 'd';  AltSymbol: '';  Exponent: -1;  Common: False),
    (Kind: pkNone;   Symbol: '';   AltSymbol: '';  Exponent: 0;   Common: True),
    (Kind: pkDeca;   Symbol: 'da'; AltSymbol: '';  Exponent: 1;   Common: False),
    (Kind: pkHecto;  Symbol: 'h';  AltSymbol: '';  Exponent: 2;   Common: False),
    (Kind: pkKilo;   Symbol: 'k';  AltSymbol: '';  Exponent: 3;   Common: True),
    (Kind: pkMega;   Symbol: 'M';  AltSymbol: '';  Exponent: 6;   Common: True),
    (Kind: pkGiga;   Symbol: 'G';  AltSymbol: '';  Exponent: 9;   Common: True),
    (Kind: pkTera;   Symbol: 'T';  AltSymbol: '';  Exponent: 12;  Common: True),
    (Kind: pkPeta;   Symbol: 'P';  AltSymbol: '';  Exponent: 15;  Common: True),
    (Kind: pkExa;    Symbol: 'E';  AltSymbol: '';  Exponent: 18;  Common: True),
    (Kind: pkZetta;  Symbol: 'Z';  AltSymbol: '';  Exponent: 21;  Common: True),
    (Kind: pkYotta;  Symbol: 'Y';  AltSymbol: '';  Exponent: 24;  Common: True),
    (Kind: pkRonna;  Symbol: 'R';  AltSymbol: '';  Exponent: 27;  Common: True),
    (Kind: pkQuetta; Symbol: 'Q';  AltSymbol: '';  Exponent: 30;  Common: True)
  );

  UnitFamilyCount = 26;
  UnitFamilyInfos: array[0..UnitFamilyCount - 1] of TUnitFamilyInfo = (
    (Family: ufLength; BaseSymbol: 'm'; Name: 'Length'; AliasCount: 6;
     Aliases: ((Symbol: 'in'), (Symbol: 'ft'), (Symbol: 'yd'), (Symbol: 'mi'),
               (Symbol: 'NM'), (Symbol: 'ly'), (Symbol: ''), (Symbol: ''))),

    (Family: ufMass; BaseSymbol: 'kg'; Name: 'Mass'; AliasCount: 6;
     Aliases: ((Symbol: 'g'), (Symbol: 'lb'), (Symbol: 'oz'), (Symbol: 't'),
               (Symbol: 'u'), (Symbol: 'Da'), (Symbol: ''), (Symbol: ''))),

    (Family: ufTime; BaseSymbol: 's'; Name: 'Time'; AliasCount: 3;
     Aliases: ((Symbol: 'min'), (Symbol: 'h'), (Symbol: 'd'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufVoltage; BaseSymbol: 'V'; Name: 'Voltage'; AliasCount: 4;
     Aliases: ((Symbol: 'W/A'), (Symbol: 'J/C'), (Symbol: 'kg*m^2/(s^3*A)'), (Symbol: 'Wb/s'),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufCurrent; BaseSymbol: 'A'; Name: 'Current'; AliasCount: 3;
     Aliases: ((Symbol: 'C/s'), (Symbol: 'V/Ohm'), (Symbol: 'W/V'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufResistance; BaseSymbol: 'Ohm'; Name: 'Resistance'; AliasCount: 3;
     Aliases: ((Symbol: 'V/A'), (Symbol: 'W/A^2'), (Symbol: 'V^2/W'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufFrequency; BaseSymbol: 'Hz'; Name: 'Frequency'; AliasCount: 2;
     Aliases: ((Symbol: '1/s'), (Symbol: 's^-1'), (Symbol: ''), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufPressure; BaseSymbol: 'Pa'; Name: 'Pressure'; AliasCount: 5;
     Aliases: ((Symbol: 'N/m^2'), (Symbol: 'bar'), (Symbol: 'atm'), (Symbol: 'psi'),
               (Symbol: 'Torr'), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufTemperature; BaseSymbol: 'K'; Name: 'Temperature'; AliasCount: 3;
     Aliases: ((Symbol: '°C'), (Symbol: '°F'), (Symbol: '°R'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufForce; BaseSymbol: 'N'; Name: 'Force'; AliasCount: 3;
     Aliases: ((Symbol: 'kg*m/s^2'), (Symbol: 'dyn'), (Symbol: 'lbf'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufEnergy; BaseSymbol: 'J'; Name: 'Energy'; AliasCount: 5;
     Aliases: ((Symbol: 'N*m'), (Symbol: 'W*s'), (Symbol: 'kg*m^2/s^2'), (Symbol: 'eV'),
               (Symbol: 'Wh'), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufPower; BaseSymbol: 'W'; Name: 'Power'; AliasCount: 4;
     Aliases: ((Symbol: 'J/s'), (Symbol: 'V*A'), (Symbol: 'kg*m^2/s^3'), (Symbol: 'hp'),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufVolume; BaseSymbol: 'm^3'; Name: 'Volume'; AliasCount: 6;
     Aliases: ((Symbol: 'L'), (Symbol: 'l'), (Symbol: 'm³'), (Symbol: 'cm^3'),
               (Symbol: 'in^3'), (Symbol: 'ft^3'), (Symbol: ''), (Symbol: ''))),

    (Family: ufVelocity; BaseSymbol: 'm/s'; Name: 'Velocity'; AliasCount: 4;
     Aliases: ((Symbol: 'km/h'), (Symbol: 'mph'), (Symbol: 'kn'), (Symbol: 'ft/s'),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufDensity; BaseSymbol: 'kg/m^3'; Name: 'Density'; AliasCount: 3;
     Aliases: ((Symbol: 'g/cm^3'), (Symbol: 'kg/L'), (Symbol: 'lb/ft^3'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufVolumetricFlow; BaseSymbol: 'm^3/s'; Name: 'Volumetric Flow Rate'; AliasCount: 4;
     Aliases: ((Symbol: 'L/s'), (Symbol: 'L/min'), (Symbol: 'm^3/h'), (Symbol: 'L/h'),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufMassFlow; BaseSymbol: 'kg/s'; Name: 'Mass Flow Rate'; AliasCount: 4;
     Aliases: ((Symbol: 'g/s'), (Symbol: 'kg/h'), (Symbol: 't/h'), (Symbol: 'lb/h'),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufGasThroughput; BaseSymbol: 'Pa*m^3/s'; Name: 'Gas Throughput'; AliasCount: 5;
     Aliases: ((Symbol: 'bar*L/s'), (Symbol: 'mbar*L/s'), (Symbol: 'Torr*L/s'), (Symbol: 'W'),
               (Symbol: 'atm*L/s'), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufAcceleration; BaseSymbol: 'm/s^2'; Name: 'Acceleration'; AliasCount: 2;
     Aliases: ((Symbol: 'gn'), (Symbol: 'Gal'), (Symbol: ''), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufArea; BaseSymbol: 'm^2'; Name: 'Area'; AliasCount: 5;
     Aliases: ((Symbol: 'cm^2'), (Symbol: 'ha'), (Symbol: 'acre'), (Symbol: 'in^2'),
               (Symbol: 'ft^2'), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufCharge; BaseSymbol: 'C'; Name: 'Charge'; AliasCount: 3;
     Aliases: ((Symbol: 'A*s'), (Symbol: 'Ah'), (Symbol: 'mAh'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufCapacitance; BaseSymbol: 'F'; Name: 'Capacitance'; AliasCount: 3;
     Aliases: ((Symbol: 'C/V'), (Symbol: 'A*s/V'), (Symbol: 's/Ohm'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufInductance; BaseSymbol: 'H'; Name: 'Inductance'; AliasCount: 3;
     Aliases: ((Symbol: 'Wb/A'), (Symbol: 'V*s/A'), (Symbol: 'Ohm*s'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufMagneticFlux; BaseSymbol: 'Wb'; Name: 'Magnetic Flux'; AliasCount: 2;
     Aliases: ((Symbol: 'V*s'), (Symbol: 'T*m^2'), (Symbol: ''), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufMagneticField; BaseSymbol: 'T'; Name: 'Magnetic Field'; AliasCount: 2;
     Aliases: ((Symbol: 'Wb/m^2'), (Symbol: 'G'), (Symbol: ''), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: ''))),

    (Family: ufWavenumber; BaseSymbol: 'm^-1'; Name: 'Wavenumber'; AliasCount: 3;
     Aliases: ((Symbol: '1/m'), (Symbol: 'cm^-1'), (Symbol: '1/cm'), (Symbol: ''),
               (Symbol: ''), (Symbol: ''), (Symbol: ''), (Symbol: '')))
  );

type
  // Fine-grained reason for a parse/resolve failure:
  //   upfNone           - no failure (call succeeded)
  //   upfInvalidNumber  - the numeric portion could not be parsed
  //   upfUnknownUnits   - the unit text isn't a recognized unit/expression
  //   upfFamilyMismatch - the units ARE recognized, but their physical
  //                       quantity family doesn't match what was required
  TUnitParseFailure = (upfNone, upfInvalidNumber, upfUnknownUnits, upfFamilyMismatch);

  TUnitParser = class
  private
    class function MakeQ(Mult, Off: Double; M, L, T, I, Theta, N, J: Integer): TPhysicalQuantity;
    class function GetUnitRegistry(const S: String; out Q: TPhysicalQuantity): Boolean;
    class function ResolveToken(const Token: String; out Q: TPhysicalQuantity): Boolean;
    class function TryStripPrefix(const Token: String; out Kind: TSIPrefixKind; out Remainder: String; out Q: TPhysicalQuantity): Boolean;
    class function ScanNumber(const S: String; var idx: Integer): Boolean;
    class function ParseTermSequence(const S: String; var Idx: Integer; Len: Integer; InsideGroup: Boolean; StartIsDiv: Boolean; var Q: TPhysicalQuantity): Boolean;
  public
    class function ParseExpression(const Expr: String; out Q: TPhysicalQuantity): Boolean; overload;
    class function ParseExpression(const Expr: String; out Q: TPhysicalQuantity; out ACanonicalExpr: String): Boolean; overload;
    class function NormalizeUnitsSpelling(const AUnits: String): String;
    class function AreEquivalent(const Q1, Q2: TPhysicalQuantity): Boolean;
    class function GetFamilyInfoIndex(AFamily: TUnitFamily): Integer;
    class function GetBaseSymbolFor(AFamily: TUnitFamily; const CustomUnits: String = ''): String;
    class function PrefixSymbolFor(AKind: TSIPrefixKind): String;
    class function PrefixKindForExponent(AExp: Integer): TSIPrefixKind;
    class function ChooseBestPrefixExponent(AAbsValue: Double): Integer;
    class function TryResolveFamilyForUnits(const AUnits: String; CurrentFamily: TUnitFamily; const CustomUnits: String; out AFamily: TUnitFamily; out AFactor, AOffset: Double; out ACanonicalUnits: String; out AFailure: TUnitParseFailure): Boolean;
    class function DecomposeUnit(const AUnits: String; CurrentFamily: TUnitFamily; const CustomUnits: String; out APrefix: TSIPrefixKind; out AUnprefixedSymbol: String; out AFactor, AOffset: Double; out AFamily: TUnitFamily; out AFailure: TUnitParseFailure): Boolean;
    class function TryParseText(const S: String; CurrentFamily: TUnitFamily; const CustomUnits: String; out ATypedNumber, ACanonical: Double; out AFamily: TUnitFamily; out ATypedPrefix: TSIPrefixKind; out AMatchedSymbol: String; out AFactor, AOffset: Double; out AFailure: TUnitParseFailure): Boolean;
  end;

implementation

var
  PointSettings: TFormatSettings;
  CachedFamilyBaseQ: array[0..UnitFamilyCount - 1] of TPhysicalQuantity;
  CachedFamilyBaseValid: Boolean = False;

  PrefixCharToKind: array[AnsiChar] of TSIPrefixKind;
  PrefixCharValid: array[AnsiChar] of Boolean;
  PrefixCharMapValid: Boolean = False;

function FloorDiv(a, b: Integer): Integer;
begin
  Result := a div b;
  if ((a mod b) <> 0) and ((a < 0) <> (b < 0)) then
    Dec(Result);
end;

procedure EnsureFamilyBaseCache;
var
  i: Integer;
begin
  if CachedFamilyBaseValid then Exit;
  for i := 0 to UnitFamilyCount - 1 do
    TUnitParser.ParseExpression(UnitFamilyInfos[i].BaseSymbol, CachedFamilyBaseQ[i]);
  CachedFamilyBaseValid := True;
end;

procedure EnsurePrefixCharMap;
var
  k: TSIPrefixKind;
  ch: AnsiChar;
begin
  if PrefixCharMapValid then Exit;
  for ch := Low(AnsiChar) to High(AnsiChar) do
    PrefixCharValid[ch] := False;
  for k := Low(TSIPrefixKind) to High(TSIPrefixKind) do
  begin
    if Length(SIPrefixes[k].Symbol) = 1 then
    begin
      PrefixCharToKind[SIPrefixes[k].Symbol[1]] := k;
      PrefixCharValid[SIPrefixes[k].Symbol[1]] := True;
    end;
    if Length(SIPrefixes[k].AltSymbol) = 1 then
    begin
      PrefixCharToKind[SIPrefixes[k].AltSymbol[1]] := k;
      PrefixCharValid[SIPrefixes[k].AltSymbol[1]] := True;
    end;
  end;
  PrefixCharMapValid := True;
end;

class function TUnitParser.MakeQ(Mult, Off: Double; M, L, T, I, Theta, N, J: Integer): TPhysicalQuantity;
begin
  Result.Multiplier := Mult;
  Result.Offset := Off;
  Result.Dimensions[0] := M;      // mass
  Result.Dimensions[1] := L;      // length
  Result.Dimensions[2] := T;      // time
  Result.Dimensions[3] := I;      // electric current
  Result.Dimensions[4] := Theta;  // thermodynamic temperature
  Result.Dimensions[5] := N;      // amount of substance
  Result.Dimensions[6] := J;      // luminous intensity
end;

class function TUnitParser.AreEquivalent(const Q1, Q2: TPhysicalQuantity): Boolean;
var
  i: Integer;
  scale: Double;
begin
  Result := False;
  for i := 0 to 6 do
    if Q1.Dimensions[i] <> Q2.Dimensions[i] then Exit;
  scale := Max(Abs(Q1.Multiplier), Abs(Q2.Multiplier));
  if Abs(Q1.Multiplier - Q2.Multiplier) > (1E-9*scale) then Exit;
  if Abs(Q1.Offset - Q2.Offset) > (1E-9*Max(1.0, Max(Abs(Q1.Offset), Abs(Q2.Offset)))) then Exit;
  Result := True;
end;

class function TUnitParser.GetFamilyInfoIndex(AFamily: TUnitFamily): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := 0 to UnitFamilyCount - 1 do
    if UnitFamilyInfos[i].Family = AFamily then
      Exit(i);
end;

class function TUnitParser.GetBaseSymbolFor(AFamily: TUnitFamily; const CustomUnits: String): String;
var
  idx: Integer;
begin
  Result := '';
  if AFamily = ufCustom then
  begin
    Result := CustomUnits;
    Exit;
  end;
  idx := GetFamilyInfoIndex(AFamily);
  if idx >= 0 then
    Result := UnitFamilyInfos[idx].BaseSymbol;
end;

class function TUnitParser.PrefixSymbolFor(AKind: TSIPrefixKind): String;
begin
  Result := SIPrefixes[AKind].Symbol;
end;

class function TUnitParser.PrefixKindForExponent(AExp: Integer): TSIPrefixKind;
var
  k: TSIPrefixKind;
begin
  Result := pkNone;
  for k := Low(TSIPrefixKind) to High(TSIPrefixKind) do
    if SIPrefixes[k].Exponent = AExp then
      Exit(k);
end;

class function TUnitParser.ChooseBestPrefixExponent(AAbsValue: Double): Integer;
var
  targetExp, bestExp, bestDiff, diff: Integer;
  k: TSIPrefixKind;
  found: Boolean;
begin
  if AAbsValue <= 0 then Exit(0);
  targetExp := FloorDiv(Floor(Log10(AAbsValue) + 1e-12), 3)*3;
  found := False;
  bestExp := 0;
  bestDiff := MaxInt;
  for k := Low(TSIPrefixKind) to High(TSIPrefixKind) do
    if SIPrefixes[k].Common then
    begin
      diff := Abs(SIPrefixes[k].Exponent - targetExp);
      if diff < bestDiff then
      begin
        bestDiff := diff;
        bestExp := SIPrefixes[k].Exponent;
        found := True;
      end;
    end;
  if found then Result := bestExp else Result := 0;
end;

class function TUnitParser.GetUnitRegistry(const S: String; out Q: TPhysicalQuantity): Boolean;
begin
  Result := True;
  case S of
    'kg':  Q := MakeQ(1.0,  0, 1, 0, 0, 0, 0, 0, 0);                   // kilogram (SI base)
    'g':   Q := MakeQ(1e-3, 0, 1, 0, 0, 0, 0, 0, 0);                   // gram
    'm':   Q := MakeQ(1.0,  0, 0, 1, 0, 0, 0, 0, 0);                   // meter
    's':   Q := MakeQ(1.0,  0, 0, 0, 1, 0, 0, 0, 0);                   // second
    'A':   Q := MakeQ(1.0,  0, 0, 0, 0, 1, 0, 0, 0);                   // ampere
    'K':   Q := MakeQ(1.0,  0, 0, 0, 0, 0, 1, 0, 0);                   // kelvin
    'mol': Q := MakeQ(1.0,  0, 0, 0, 0, 0, 0, 1, 0);                   // mole
    'cd':  Q := MakeQ(1.0,  0, 0, 0, 0, 0, 0, 0, 1);                   // candela
    'Hz':  Q := MakeQ(1.0, 0, 0,  0, -1,  0, 0, 0, 0);                 // hertz
    'rad': Q := MakeQ(1.0, 0, 0,  0,  0,  0, 0, 0, 0);                 // radians
    'sr':  Q := MakeQ(1.0, 0, 0,  0,  0,  0, 0, 0, 0);                 // steradian
    'N':   Q := MakeQ(1.0, 0, 1,  1, -2,  0, 0, 0, 0);                 // newton
    'Pa':  Q := MakeQ(1.0, 0, 1, -1, -2,  0, 0, 0, 0);                 // pascal
    'J':   Q := MakeQ(1.0, 0, 1,  2, -2,  0, 0, 0, 0);                 // joule
    'W':   Q := MakeQ(1.0, 0, 1,  2, -3,  0, 0, 0, 0);                 // watt
    'C':   Q := MakeQ(1.0, 0, 0,  0,  1,  1, 0, 0, 0);                 // coulomb
    'V':   Q := MakeQ(1.0, 0, 1,  2, -3, -1, 0, 0, 0);                 // volt
    'F':   Q := MakeQ(1.0, 0,-1, -2,  4,  2, 0, 0, 0);                 // farad
    'Ohm', 'Ω': Q := MakeQ(1.0, 0, 1,  2, -3, -2, 0, 0, 0);            // ohm
    'S':   Q := MakeQ(1.0, 0,-1, -2,  3,  2, 0, 0, 0);                 // siemens
    'Wb':  Q := MakeQ(1.0, 0, 1,  2, -2, -1, 0, 0, 0);                 // weber
    'T':   Q := MakeQ(1.0, 0, 1,  0, -2, -1, 0, 0, 0);                 // tesla
    'H':   Q := MakeQ(1.0, 0, 1,  2, -2, -2, 0, 0, 0);                 // henry
    'lm':  Q := MakeQ(1.0, 0, 0,  0,  0,  0, 0, 0, 1);                 // lumen
    'lx':  Q := MakeQ(1.0, 0, 0, -2,  0,  0, 0, 0, 1);                 // lux
    'Bq':  Q := MakeQ(1.0, 0, 0,  0, -1,  0, 0, 0, 0);                 // becquerel
    'Gy':  Q := MakeQ(1.0, 0, 0,  2, -2,  0, 0, 0, 0);                 // gray
    'Sv':  Q := MakeQ(1.0, 0, 0,  2, -2,  0, 0, 0, 0);                 // sievert
    'kat': Q := MakeQ(1.0, 0, 0,  0, -1,  0, 0, 1, 0);                 // katal
    'oz':  Q := MakeQ(0.028349523125, 0, 1, 0, 0, 0, 0, 0, 0);         // ounce
    'lb':  Q := MakeQ(0.45359237, 0, 1, 0, 0, 0, 0, 0, 0);             // pound
    'in':  Q := MakeQ(0.0254, 0, 0, 1, 0, 0, 0, 0, 0);                 // inch
    'ft':  Q := MakeQ(0.3048, 0, 0, 1, 0, 0, 0, 0, 0);                 // foot
    'yd':  Q := MakeQ(0.9144, 0, 0, 1, 0, 0, 0, 0, 0);                 // yard
    'mi':  Q := MakeQ(1609.344, 0, 0, 1, 0, 0, 0, 0, 0);               // mile
    'NM':  Q := MakeQ(1852, 0, 0, 1, 0, 0, 0, 0, 0);                   // nautical miles
    'ly':  Q := MakeQ(9460730472580800, 0, 0, 1, 0, 0, 0, 0, 0);       // light-year
    'min': Q := MakeQ(60.0, 0, 0, 0, 1, 0, 0, 0, 0);                   // minute
    'h':   Q := MakeQ(3600.0, 0, 0, 0, 1, 0, 0, 0, 0);                 // hour
    'd':   Q := MakeQ(86400.0, 0, 0, 0, 1, 0, 0, 0, 0);                // day
    'L', 'l': Q := MakeQ(1e-3, 0, 0, 3, 0, 0, 0, 0, 0);                // liter
    't':   Q := MakeQ(1000.0, 0, 1, 0, 0, 0, 0, 0, 0);                 // metric tonne
    'u', 'Da': Q := MakeQ(1.66053906660e-27, 0, 1, 0, 0, 0, 0, 0, 0);  // atomic mass (dalton)
    'eV':  Q := MakeQ(1.602176634e-19, 0, 1, 2, -2, 0, 0, 0, 0);       // electron volt
    'Wh':  Q := MakeQ(3600, 0, 1, 2, -2, 0, 0, 0, 0);                  // watt-hour
    'bar': Q := MakeQ(1e5, 0, 1, -1, -2, 0, 0, 0, 0);                  // bar
    'atm': Q := MakeQ(101325.0, 0, 1, -1, -2, 0, 0, 0, 0);             // standard atmosphere
    'psi': Q := MakeQ(6894.757293168361, 0, 1, -1, -2, 0, 0, 0, 0);    // pounds per square inch
    'Torr':Q := MakeQ(133.32236842105263, 0, 1, -1, -2, 0, 0, 0, 0);   // torr
    '°C':  Q := MakeQ(1.0, 273.15,  0, 0, 0, 0, 1, 0, 0);              // degree Celsius
    '°F':  Q := MakeQ(5/9, 255.37222222222222, 0, 0, 0, 0, 1, 0, 0);   // degree Fahrenheit
    '°R':  Q := MakeQ(1.8, 0, 0, 0, 0, 0, 1, 0, 0);                    // degree Rankine
    'dyn': Q := MakeQ(1e-5, 0, 1,  1, -2, 0, 0, 0, 0);                 // dyne
    'lbf': Q := MakeQ(4.44822, 0, 1,  1, -2, 0, 0, 0, 0);              // pound-force
    'hp':  Q := MakeQ(745.69987, 0, 1,  2, -3, 0, 0, 0, 0);            // horsepower
    'mph': Q := MakeQ(0.44704, 0, 0,  1, -1, 0, 0, 0, 0);              // miles per hour
    'kn':  Q := MakeQ(0.5144444444444445, 0, 0, 1, -1, 0, 0, 0, 0);    // knot
    'Gal': Q := MakeQ(0.01, 0, 0,  1, -2, 0, 0, 0, 0);                 // galileo
    'gn':  Q := MakeQ(9.80665, 0, 0,  1, -2, 0, 0, 0, 0);              // standard gravity
    'ha':  Q := MakeQ(10000.0, 0, 0,  2,  0, 0, 0, 0, 0);              // hectare
    'acre':Q := MakeQ(4046.85642, 0, 0,  2,  0, 0, 0, 0, 0);           // acre
    'Ah':  Q := MakeQ(3600.0, 0, 0,  0,  1, 1, 0, 0, 0);               // ampere-hour
    'mAh': Q := MakeQ(3.6, 0, 0,  0,  1, 1, 0, 0, 0);                  // milliampere-hour
    'G':   Q := MakeQ(1e-4, 0, 1,  0, -2, -1, 0, 0, 0);                // gauss
    else Result := False;
  end;
end;

// Attempts to split Token into a leading SI prefix plus a remainder that is
// itself a registered unit (e.g. 'km' -> pkKilo + 'm', 'uF' -> pkMicro + 'F')
class function TUnitParser.TryStripPrefix(const Token: String; out Kind: TSIPrefixKind; out Remainder: String; out Q: TPhysicalQuantity): Boolean;
begin
  EnsurePrefixCharMap;
  Result := False;

  if (Length(Token) > 2) and (Token[1] = 'd') and (Token[2] = 'a') then
  begin
    Remainder := Copy(Token, 3, MaxInt);
    if GetUnitRegistry(Remainder, Q) then
    begin
      Kind := pkDeca;
      Exit(True);
    end;
  end;

  if (Length(Token) > 1) and PrefixCharValid[Token[1]] then
  begin
    Remainder := Copy(Token, 2, MaxInt);
    if GetUnitRegistry(Remainder, Q) then
    begin
      Kind := PrefixCharToKind[Token[1]];
      Exit(True);
    end;
  end;
end;

class function TUnitParser.ResolveToken(const Token: String; out Q: TPhysicalQuantity): Boolean;
var
  Kind: TSIPrefixKind;
  Remainder: String;
begin
  if GetUnitRegistry(Token, Q) then Exit(True);
  if TryStripPrefix(Token, Kind, Remainder, Q) then
  begin
    Q.Multiplier := Q.Multiplier*Power(10, SIPrefixes[Kind].Exponent);
    Exit(True);
  end;
  Result := False;
end;

class function TUnitParser.ParseTermSequence(const S: String; var Idx: Integer; Len: Integer; InsideGroup: Boolean; StartIsDiv: Boolean; var Q: TPhysicalQuantity): Boolean;
var
  TokenStr, PowerStr: String;
  StartTok, Power, i, TokenCount: Integer;
  IsDiv: Boolean;
  TermQ: TPhysicalQuantity;
begin
  Result := False;
  IsDiv := StartIsDiv;
  TokenCount := 0;

  while Idx <= Len do
  begin
    while (Idx <= Len) and (S[Idx] = ' ') do Inc(Idx);
    if Idx > Len then Break;

    if S[Idx] = '(' then
    begin
      Inc(Idx);
      TermQ := MakeQ(1.0, 0.0, 0, 0, 0, 0, 0, 0, 0);
      if not ParseTermSequence(S, Idx, Len, True, False, TermQ) then Exit(False);
      if (Idx > Len) or (S[Idx] <> ')') then Exit(False);
      Inc(Idx);
    end
    else
    begin
      StartTok := Idx;
      while (Idx <= Len) and not (S[Idx] in ['*', '/', '^', ' ', '(', ')']) do Inc(Idx);
      TokenStr := Copy(S, StartTok, Idx - StartTok);
      if TokenStr = '' then Exit(False);
      if not ResolveToken(TokenStr, TermQ) then Exit(False);
    end;

    Power := 1;
    while (Idx <= Len) and (S[Idx] = ' ') do Inc(Idx);

    if (Idx <= Len) and (S[Idx] = '^') then
    begin
      Inc(Idx);
      while (Idx <= Len) and (S[Idx] = ' ') do Inc(Idx); // Skip spaces after ^
      StartTok := Idx;
      if (Idx <= Len) and (S[Idx] in ['+', '-']) then Inc(Idx);
      while (Idx <= Len) and (S[Idx] in ['0'..'9']) do Inc(Idx);
      PowerStr := Copy(S, StartTok, Idx - StartTok);
      if not TryStrToInt(PowerStr, Power) then Exit(False);
    end;

    if IsDiv then Power := -Power;

    Inc(TokenCount);
    Q.Multiplier := Q.Multiplier*Math.Power(TermQ.Multiplier, Power);

    if (not InsideGroup) and (TokenCount = 1) and (Power = 1) and (not IsDiv) and (Idx >= Len) then
      Q.Offset := Q.Offset + TermQ.Offset;

    for i := 0 to 6 do
      Q.Dimensions[i] := Q.Dimensions[i] + (TermQ.Dimensions[i]*Power);

    while (Idx <= Len) and (S[Idx] = ' ') do Inc(Idx);
    if Idx > Len then Break;

    if S[Idx] = ')' then
    begin
      if InsideGroup then Break
      else Exit(False);
    end;

    if S[Idx] = '*' then IsDiv := False
    else if S[Idx] = '/' then IsDiv := True
    else Exit(False);
    Inc(Idx);
  end;

  if TokenCount = 0 then Exit(False);
  Result := True;
end;

class function TUnitParser.ParseExpression(const Expr: String; out Q: TPhysicalQuantity): Boolean;
var
  discardCanonical: String;
begin
  Result := ParseExpression(Expr, Q, discardCanonical);
end;

class function TUnitParser.ParseExpression(const Expr: String; out Q: TPhysicalQuantity; out ACanonicalExpr: String): Boolean;
var
  S: String;
  Idx, Len: Integer;
  IsDiv: Boolean;
begin
  Result := False;
  Q := MakeQ(1.0, 0.0, 0, 0, 0, 0, 0, 0, 0);

  // Autocorrect alternate spellings
  S := StringReplace(Trim(Expr), '²', '^2', [rfReplaceAll]);
  S := StringReplace(S, '³', '^3', [rfReplaceAll]);
  S := StringReplace(S, '·', '*', [rfReplaceAll]);
  S := StringReplace(S, 'ºC', '°C', [rfReplaceAll]);
  S := StringReplace(S, 'ºF', '°F', [rfReplaceAll]);
  S := StringReplace(S, 'ºR', '°R', [rfReplaceAll]);
  S := StringReplace(S, 'oC', '°C', [rfReplaceAll]);
  S := StringReplace(S, 'oF', '°F', [rfReplaceAll]);
  S := StringReplace(S, 'oR', '°R', [rfReplaceAll]);

  ACanonicalExpr := S;

  if S = '' then Exit;
  Len := Length(S);
  Idx := 1;
  IsDiv := False;

  if Copy(S, 1, 2) = '1/' then
  begin
    IsDiv := True;
    Idx := 3;
  end;

  if not ParseTermSequence(S, Idx, Len, False, IsDiv, Q) then Exit;
  if Idx <= Len then Exit(False);

  Result := True;
end;

class function TUnitParser.NormalizeUnitsSpelling(const AUnits: String): String;
var
  Q: TPhysicalQuantity;
  canonical: String;
begin
  if ParseExpression(AUnits, Q, canonical) then
    Result := canonical
  else
    Result := AUnits;
end;

class function TUnitParser.TryResolveFamilyForUnits(const AUnits: String; CurrentFamily: TUnitFamily; const CustomUnits: String; out AFamily: TUnitFamily; out AFactor, AOffset: Double; out ACanonicalUnits: String; out AFailure: TUnitParseFailure): Boolean;
var
  Q, QBase: TPhysicalQuantity;
  i, j, idx: Integer;
  Match: Boolean;
begin
  Result := False;
  AFamily := ufAny;
  AFactor := 1.0;
  AOffset := 0.0;
  ACanonicalUnits := AUnits;
  AFailure := upfUnknownUnits;

  if not ParseExpression(AUnits, Q, ACanonicalUnits) then Exit; // AFailure stays upfUnknownUnits

  if CurrentFamily = ufCustom then
  begin
    if not ParseExpression(CustomUnits, QBase) then Exit; // CustomUnits itself doesn't parse

    Match := True;
    for j := 0 to 6 do
      if Q.Dimensions[j] <> QBase.Dimensions[j] then Match := False;

    if Match then
    begin
      AFamily := ufCustom;
      AFactor := Q.Multiplier;
      AOffset := Q.Offset;
      AFailure := upfNone;
      Result := True;
    end
    else
      AFailure := upfFamilyMismatch; // units parsed fine, wrong (custom) family
    Exit;
  end;

  EnsureFamilyBaseCache;

  if CurrentFamily <> ufAny then
  begin
    idx := GetFamilyInfoIndex(CurrentFamily);
    if idx >= 0 then
    begin
      QBase := CachedFamilyBaseQ[idx];
      Match := True;
      for j := 0 to 6 do
        if Q.Dimensions[j] <> QBase.Dimensions[j] then Match := False;

      if Match then
      begin
        AFamily := CurrentFamily;
        AFactor := Q.Multiplier;
        AOffset := Q.Offset;
        AFailure := upfNone;
        Result := True;
      end
      else
        AFailure := upfFamilyMismatch; // units parsed fine, wrong family
    end;
    Exit;
  end;

  for i := 0 to UnitFamilyCount - 1 do
  begin
    QBase := CachedFamilyBaseQ[i];
    Match := True;
    for j := 0 to 6 do
      if Q.Dimensions[j] <> QBase.Dimensions[j] then Match := False;

    if Match then
    begin
      AFamily := UnitFamilyInfos[i].Family;
      AFactor := Q.Multiplier;
      AOffset := Q.Offset;
      AFailure := upfNone;
      Result := True;
      Exit;
    end;
  end;

  AFactor := Q.Multiplier;
  AOffset := Q.Offset;
  AFailure := upfNone;
  Result := True;
end;

class function TUnitParser.ScanNumber(const S: String; var idx: Integer): Boolean;
var
  L: Integer;
  seenDigit, seenDot, seenExp: Boolean;
begin
  L := Length(S);
  seenDigit := False;
  seenDot := False;
  seenExp := False;
  if (idx <= L) and (S[idx] in ['+', '-']) then Inc(idx);
  while idx <= L do
  begin
    case S[idx] of
      '0'..'9': begin
          seenDigit := True;
          Inc(idx);
        end;
      '.', ',': begin
          if seenDot or seenExp then Break;
          seenDot := True;
          Inc(idx);
        end;
      'e', 'E': begin
          if seenExp or not seenDigit then Break;
          seenExp := True;
          Inc(idx);
          if (idx <= L) and (S[idx] in ['+', '-']) then Inc(idx);
        end;
      else Break;
    end;
  end;
  Result := seenDigit;
end;

class function TUnitParser.DecomposeUnit(const AUnits: String; CurrentFamily: TUnitFamily; const CustomUnits: String; out APrefix: TSIPrefixKind; out AUnprefixedSymbol: String; out AFactor, AOffset: Double; out AFamily: TUnitFamily; out AFailure: TUnitParseFailure): Boolean;
var
  Q: TPhysicalQuantity;
  Kind: TSIPrefixKind;
  remainder, canonicalUnits: String;
begin
  Result := False;
  APrefix := pkNone;
  AUnprefixedSymbol := AUnits;
  AFactor := 1.0;
  AOffset := 0.0;
  AFamily := ufAny;
  AFailure := upfUnknownUnits;

  if Trim(AUnits) = '' then
  begin
    AFamily := ufNone;
    Exit;
  end;

  // Direct registry lookup (no prefix), e.g. 'kg', 'bar', 'Pa'
  if GetUnitRegistry(AUnits, Q) then
  begin
    if not TryResolveFamilyForUnits(AUnits, CurrentFamily, CustomUnits, AFamily, AFactor, AOffset, canonicalUnits, AFailure) then
      Exit(False);
    APrefix := pkNone;
    AUnprefixedSymbol := canonicalUnits;
    Exit(True);
  end;

  // Prefix + registry lookup, e.g. 'km', 'uF', 'MPa'
  if TryStripPrefix(AUnits, Kind, remainder, Q) then
  begin
    if not TryResolveFamilyForUnits(remainder, CurrentFamily, CustomUnits, AFamily, AFactor, AOffset, canonicalUnits, AFailure) then
      Exit(False);
    APrefix := Kind;
    AUnprefixedSymbol := canonicalUnits;
    Exit(True);
  end;

  // Complex expressions, e.g. 'kg*m/s^2'
  if TryResolveFamilyForUnits(AUnits, CurrentFamily, CustomUnits, AFamily, AFactor, AOffset, canonicalUnits, AFailure) then
  begin
    APrefix := pkNone;
    AUnprefixedSymbol := canonicalUnits;
    Result := True;
  end;
end;

class function TUnitParser.TryParseText(const S: String; CurrentFamily: TUnitFamily; const CustomUnits: String; out ATypedNumber, ACanonical: Double; out AFamily: TUnitFamily; out ATypedPrefix: TSIPrefixKind; out AMatchedSymbol: String; out AFactor, AOffset: Double; out AFailure: TUnitParseFailure): Boolean;
var
  trimmed, numStr, unitStr: String;
  idx: Integer;
begin
  Result := False;
  ATypedNumber := 0; ACanonical := 0; AFamily := ufAny;
  ATypedPrefix := pkNone; AMatchedSymbol := ''; AFactor := 1.0; AOffset := 0.0;
  AFailure := upfInvalidNumber;

  trimmed := Trim(S);
  if trimmed = '' then Exit;

  idx := 1;
  if not ScanNumber(trimmed, idx) then Exit; // AFailure stays upfInvalidNumber
  numStr  := Copy(trimmed, 1, idx - 1);
  unitStr := Trim(Copy(trimmed, idx, MaxInt));

  numStr := StringReplace(numStr, ',', '.', [rfReplaceAll]);
  if not TryStrToFloat(numStr, ATypedNumber, PointSettings) then Exit; // upfInvalidNumber

  if unitStr = '' then
  begin
    // A bare number is interpreted in whatever unit CurrentFamily implies
    if (CurrentFamily = ufAny) then
      AFamily := ufNone
    else
      AFamily := CurrentFamily;
    AMatchedSymbol := '';
    ATypedPrefix := pkNone;
    ACanonical := ATypedNumber;
    AFailure := upfNone;
    Result := True;
    Exit;
  end;

  if not DecomposeUnit(unitStr, CurrentFamily, CustomUnits, ATypedPrefix, AMatchedSymbol, AFactor, AOffset, AFamily, AFailure) then
    Exit(False);

  ACanonical := (ATypedNumber*Power(10, SIPrefixes[ATypedPrefix].Exponent))*AFactor + AOffset;
  AFailure := upfNone;
  Result := True;
end;

initialization
  PointSettings := DefaultFormatSettings;
  PointSettings.DecimalSeparator := '.';
  PointSettings.ThousandSeparator := #0;

end.
