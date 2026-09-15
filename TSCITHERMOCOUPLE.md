# TSciThermocouple

`TSciThermocouple` is a non-visual component that converts between thermocouple voltage and temperature, and in the reverse direction, for nine standard thermocouple types. Conversion uses the official NIST ITS-90 polynomial coefficients and includes cold-junction compensation.

Unit: `uSciThermoCouple.pas`

---

## Thermocouple types

| Enum value | Name | Temperature range | Typical use |
|---|---|---|---|
| `tcTypeB` | Type B | 0 – 1820 °C | Very high-temperature furnaces |
| `tcTypeC` | Type C | 0 – 2315 °C | Vacuum/inert atmosphere furnaces |
| `tcTypeE` | Type E | −270 – 1000 °C | Cryogenic and sub-zero measurements |
| `tcTypeJ` | Type J | −210 – 1200 °C | General industrial, older equipment |
| `tcTypeK` | Type K | −270 – 1372 °C | General purpose (the most common type) |
| `tcTypeN` | Type N | −270 – 1300 °C | High-stability alternative to Type K |
| `tcTypeR` | Type R | −50 – 1768 °C | Platinum-group, laboratory standard |
| `tcTypeS` | Type S | −50 – 1768 °C | Platinum-group, calibration reference |
| `tcTypeT` | Type T | −270 – 400 °C | Cryogenics, food processing |

---

## Temperature units

The `Units` property controls the scale used for all temperature inputs and outputs:

| Enum value | Scale |
|---|---|
| `tuKelvin` | Kelvin |
| `tuCelsius` | Celsius (default) |
| `tuFahrenheit` | Fahrenheit |
| `tuRankine` | Rankine |

---

## Published properties

### `ThermoCoupleType: TThermoCouple`
Default: `tcTypeK`

Selects the active thermocouple type. This determines which set of NIST polynomial coefficients is used for all conversions.

### `Units: TTempUnits`
Default: `tuCelsius`

The temperature scale for all inputs and outputs of `VoltageToTemperature` and `TemperatureToVoltage`. The cold-junction temperature (`ColdJunctionTemp`) is interpreted in the same units.

### `ColdJunctionTemp: Double`
Default: `0.0`

The cold-junction (reference junction) temperature, expressed in the active `Units`. This is added as a voltage offset before the inverse polynomial is evaluated, implementing the standard isothermal-block cold-junction compensation method.

Set this to the measured temperature at the point where the thermocouple wire meets the copper traces of your ADC board (typically read from an on-board NTC or IC temperature sensor).

---

## Methods

### `function VoltageToTemperature(const Voltage: Double): Double`

Converts a thermocouple EMF (in **volts**) to temperature. Uses `ColdJunctionTemp` for cold-junction compensation.

Returns `NaN` if the voltage is outside the valid range for the active thermocouple type.

### `function VoltageToTemperature(const Voltage: Double; const CustomTcj: Double): Double`

Overloaded variant that accepts an explicit cold-junction temperature instead of the stored `ColdJunctionTemp`. Useful when the cold-junction temperature is measured dynamically on each conversion cycle and you do not want to update the property.

The `CustomTcj` value is interpreted in the active `Units`.

Returns `NaN` if the voltage is outside the valid range.

### `function TemperatureToVoltage(const Temperature: Double): Double`

Converts a temperature (in the active `Units`) to the corresponding thermocouple EMF in **volts**.

Returns `NaN` if the temperature is outside the valid range for the active thermocouple type.

---

## Unit-level helper functions (public)

The following functions are declared in the interface section of `uSciThermoCouple` and can be called directly without a component instance:

```pascal
function VoltageToTemperature(
  const Voltage: Double;
  TC_Type: TThermoCouple;
  Units: TTempUnits;
  const Tcj: Double): Double;

function TemperatureToVoltage(
  const Temperature: Double;
  TC_Type: TThermoCouple;
  Units: TTempUnits): Double;
```

These are the same conversions the component delegates to internally, but let you pass the type and units explicitly — convenient in loops where you process multiple thermocouple channels at once without creating separate component instances.

---

## Type and range validation

All conversions return `NaN` for out-of-range inputs. Checking for `NaN` in your readout loop is strongly recommended:

```pascal
uses Math; // for IsNaN

T := TC.VoltageToTemperature(Vmeasured);
if IsNaN(T) then
  ShowMessage('Voltage out of range for selected thermocouple type')
else
  Label1.Caption := Format('%.1f °C', [T]);
```

Note that Type B has a particularly restricted low-end response — its output voltage near 0 °C is very close to zero, which makes it unsuitable for temperatures below about 250 °C in practice (the polynomial inversion error in the 0–250 °C range is ±3 °C).

---

## Design-time usage

1. Drop a `TSciThermocouple` on the form.
2. Set `ThermoCoupleType` to match the sensor wired to your ADC.
3. Set `Units` to match your application's temperature display units.
4. Optionally set `ColdJunctionTemp` to a fixed ambient temperature (e.g. 25 °C) for bench testing; replace with a live sensor reading at runtime.

---

## Runtime usage example

```pascal
uses uSciThermoCouple, Math;

// Assuming SciThermocouple1 is already configured at design time
// (Type K, Celsius, ColdJunctionTemp updated each cycle from an NTC sensor)

procedure TForm1.TimerTick(Sender: TObject);
var
  Vmeasured, Tcj, T: Double;
begin
  // Read raw voltage from your ADC (in volts)
  Vmeasured := ReadADCVolts(Channel0);

  // Read cold-junction from on-board sensor (in °C)
  Tcj := ReadNTCSensor;

  // Convert, passing Tcj as an overload argument for a dynamic value
  T := SciThermocouple1.VoltageToTemperature(Vmeasured, Tcj);

  if IsNaN(T) then
    lblTemp.Caption := 'ERR'
  else
    lblTemp.Caption := Format('%.2f °C', [T]);
end;
```

---

## Notes on accuracy

Polynomial coefficients are taken from the NIST Monograph 175 (ITS-90) tables. The forward direction (temperature → voltage) uses the full published polynomials. The inverse direction (voltage → temperature) uses the NIST inverse polynomial approximations, which introduce a small additional error (typically < 0.05 °C for Types E, J, K, N, T; < 0.02 °C for Types R and S; ±3 °C for Type B below 250 °C).

Type C coefficients are fitted locally (not NIST-official) and carry an error of up to 1 % at the extremes of the range.
