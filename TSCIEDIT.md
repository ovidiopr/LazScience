# TSciEdit

`TSciEdit` is a unit-aware numeric edit control for Lazarus/Free Pascal (LCL). It descends from `TCustomEdit` and lets the user type a number together with a physical unit — e.g. `12 km`, `3.3 kOhm`, `20 °C`, `14.7 psi` — and automatically parses, validates, converts, and re-formats it. It understands SI prefixes, compound unit expressions (`kg*m/s^2`), and 26 built-in physical-quantity families, and it can also be restricted to a custom, user-defined unit.

It ships together with a companion unit, `uUnitParser` (`TUnitParser`), which does all of the actual unit/expression parsing and dimensional analysis and can also be used on its own.

## Features

- **Free-form unit input** — type a number and a unit in one string (`"2.5 MPa"`, `"0.5 in"`, `"10 kg*m/s^2"`) and the control parses both parts.
- **Compound unit expressions** — units can be combined with `*`, `/`, `^` and parentheses (e.g. `kg*m^2/s^3`, `W/(m^2*K)`).
- **SI prefixes** — all standard prefixes from `q` (quecto, 1e-30) to `Q` (quetta, 1e30), including the `µ`/`u` alternate symbol and multi-letter `da` (deca).
- **Dimensional family checking** — restrict the control to a physical quantity (length, pressure, energy, etc.) so incompatible units are rejected with a clear error state.
- **Automatic unit/prefix selection** — optionally re-displays the value with the best-fitting SI prefix after every edit.
- **Canonical/preferred unit snapping** — optionally force values back to SI base units or to a unit of your choosing after every edit.
- **Custom units** — define your own base unit/expression for quantities the built-in families don't cover.
- **Scientific notation fallback** for very large/small magnitudes.
- **Visual error feedback** — the text turns a configurable color when the content can't be parsed, uses an unknown unit, or belongs to the wrong physical family.
- **TrackBar binding** — attach a `TTrackBar` to scrub the value multiplicatively (logarithmic slider) around a reference point.
- **Right-click unit menu** — offers the base unit and all its known aliases so the user can convert with a click.
- **Batch updates** (`BeginUpdate`/`EndUpdate`) to change several properties without re-parsing after each one.

## Supported unit families

`UnitFamily` restricts what the control will accept. Set it to `ufAny` (default) to accept any recognized unit, `ufNone` for plain dimensionless numbers, `ufCustom` to use your own unit (see below), or one of the physical families below. Each family has a **base (SI) symbol**, used internally and for `seoCanonicalUnits`/auto-prefixing, plus a set of recognized **alias** units that convert to/from it automatically.

| Family | Base symbol | Recognized aliases |
|---|---|---|
| Length | `m` | `in`, `ft`, `yd`, `mi`, `NM`, `ly` |
| Mass | `kg` | `g`, `lb`, `oz`, `t`, `u`, `Da` |
| Time | `s` | `min`, `h`, `d` |
| Voltage | `V` | `W/A`, `J/C`, `kg*m^2/(s^3*A)`, `Wb/s` |
| Current | `A` | `C/s`, `V/Ohm`, `W/V` |
| Resistance | `Ohm` | `V/A`, `W/A^2`, `V^2/W` |
| Frequency | `Hz` | `1/s`, `s^-1` |
| Pressure | `Pa` | `N/m^2`, `bar`, `atm`, `psi`, `Torr` |
| Temperature | `K` | `°C`, `°F`, `°R` |
| Force | `N` | `kg*m/s^2`, `dyn`, `lbf` |
| Energy | `J` | `N*m`, `W*s`, `kg*m^2/s^2`, `eV`, `Wh` |
| Power | `W` | `J/s`, `V*A`, `kg*m^2/s^3`, `hp` |
| Volume | `m^3` | `L`, `l`, `m³`, `cm^3`, `in^3`, `ft^3` |
| Velocity | `m/s` | `km/h`, `mph`, `kn`, `ft/s` |
| Density | `kg/m^3` | `g/cm^3`, `kg/L`, `lb/ft^3` |
| Volumetric Flow Rate | `m^3/s` | `L/s`, `L/min`, `m^3/h`, `L/h` |
| Mass Flow Rate | `kg/s` | `g/s`, `kg/h`, `t/h`, `lb/h` |
| Gas Throughput | `Pa*m^3/s` | `bar*L/s`, `mbar*L/s`, `Torr*L/s`, `W`, `atm*L/s` |
| Acceleration | `m/s^2` | `gn`, `Gal` |
| Area | `m^2` | `cm^2`, `ha`, `acre`, `in^2`, `ft^2` |
| Charge | `C` | `A*s`, `Ah`, `mAh` |
| Capacitance | `F` | `C/V`, `A*s/V`, `s/Ohm` |
| Inductance | `H` | `Wb/A`, `V*s/A`, `Ohm*s` |
| Magnetic Flux | `Wb` | `V*s`, `T*m^2` |
| Magnetic Field | `T` | `Wb/m^2`, `G` |
| Wavenumber | `m^-1` | `1/m`, `cm^-1`, `1/cm` |

Under the hood, every unit and alias is resolved down to the seven SI base dimensions (mass, length, time, current, temperature, amount of substance, luminous intensity), so any dimensionally-consistent combination of the base SI units listed in the registry — not just the aliases above — is also accepted (e.g. `kg*m/s^2` is understood as a Force even though `N` is the "official" alias).

Any of the base symbols or aliases above can be combined with an SI prefix (`km`, `MPa`, `µF`, `kOhm`, `mV`, ...) and the control will apply the prefix's power-of-ten automatically.

## Custom Units

Some quantities don't fit any of the 26 built-in families, or you may simply want the control's "base" unit to be something other than the SI unit. For that, set:

```pascal
SciEdit1.UnitFamily := ufCustom;
SciEdit1.CustomUnits := 'ft^3';   // any valid unit expression
```

`CustomUnits` is itself a unit expression (built from the same registry of atomic units, SI prefixes, and `*`, `/`, `^`, parentheses used everywhere else). It defines the **dimensional signature** that typed-in units must match, not a literal string match — so with `CustomUnits := 'ft^3'` the control will happily accept `2 m^3`, `500 L`, or `12 in^3` as well as `ft^3` itself, and will use `ft^3` as its own base/display unit and as the target for `seoCanonicalUnits`.

This is useful when:
- You want a family the component doesn't ship with (e.g. a torque unit `N*m` used consistently, distinguishing it from Energy which shares the same dimensions but different meaning).
- You want to change which unit is treated as "canonical" for a family without renaming the family's base symbol everywhere (e.g. use `psi` instead of `Pa` as your project's pressure base).

Notes:
- `CustomUnits` only has an effect while `UnitFamily = ufCustom`.
- The value is auto-corrected for common alternate spellings (`oC`/`ºC` → `°C`, `²`/`³` → `^2`/`^3`, `·` → `*`), the same normalization applied to typed input.
- If `CustomUnits` doesn't itself parse into a valid expression, any input will be rejected as `sesInvalidUnits`.

## Usage from the Designer

1. Drop a `TSciEdit` from the **Science** palette tab onto a form.
2. In the Object Inspector, set:
   - **UnitFamily** — restrict accepted input to a physical quantity, `ufCustom`, `ufNone`, or leave `ufAny`.
   - **CustomUnits** — only if `UnitFamily = ufCustom` (see above).
   - **PreferredUnits** — if set, typed values are always converted to/reported in this unit (e.g. force everything to display in `°F` even if the user types `°C`).
   - **Options** — combination of:
     - `seoAutoUnits` — pick the best SI prefix after each edit (on by default).
     - `seoScientificNotation` — fall back to scientific notation for extreme magnitudes (on by default).
     - `seoCanonicalUnits` — always convert to base SI units.
     - `seoPreferredUnits` — always convert to `PreferredUnits`.
   - **SignificantDigits** — how many significant digits to display (1–15, default 5).
   - **ErrorColor** — font color used while the content can't be parsed (default `clRed`).
   - **ContextUnits** — optionally restrict the right-click conversion menu to a specific subset of unit symbols; leave empty to show all known aliases for the detected family.
   - **TrackBar** — link a `TTrackBar` on the same form to scrub the value multiplicatively; **TrackBarFactor** sets how many times larger/smaller a full swing of the slider makes the value, **TrackBarRange** sets the slider's resolution, and **TrackBarSettleDelay** sets how long (ms) after the user releases the slider before the reference point resets.
3. Optionally set the initial **Text**, e.g. `12.5 kOhm` — it will be parsed as soon as the form loads.
4. Handle **OnValueChanged**, **OnParseError**, and/or **OnUserEdit** in the Object Inspector's Events tab if you need to react to edits (see below for their signatures).

Right-clicking the control at design time behaves the same as at runtime: it pops up a menu with the current unit and all of its known aliases so the value can be converted without typing.

## Usage from code

### Reading and writing values

```pascal
// Plain numeric access — reads/writes in whatever unit is currently
// displayed (or PreferredUnits, if set)
SciEdit1.Value := 100;
ShowMessage(FloatToStr(SciEdit1.Value));

// Explicit-unit access — converts on the fly, raises ESciEditError
// if AUnits isn't recognized or belongs to a different family
SciEdit1.ValueAs['km'] := 5;
ShowMessage(FloatToStr(SciEdit1.ValueAs['mi']));

// Always-SI access, regardless of the unit currently shown
ShowMessage(FloatToStr(SciEdit1.CanonicalValue));
```

### Restricting and inspecting units

```pascal
SciEdit1.UnitFamily := ufPressure;   // only pressure units are accepted
SciEdit1.PreferredUnits := 'bar';    // always show/convert to bar

if SciEdit1.HasValue then
  case SciEdit1.State of
    sesValid:           ; // ready to use
    sesInvalidNumber:   ; // numeric part couldn't be parsed
    sesInvalidUnits:    ; // unit part isn't recognized
    sesFamilyMismatch:  ; // valid unit, wrong physical quantity
  end;

ShowMessage(UnitFamilyName[SciEdit1.DetectedFamily]); // or inspect DetectedFamily directly
```

### Converting an existing value

```pascal
// Re-expresses the current value in a different (compatible) unit
SciEdit1.ConvertToUnits('psi');
```

### Handling events

```pascal
procedure TForm1.SciEdit1ValueChanged(Sender: TObject; NewValue: Double);
begin
  // Fires whenever the displayed value changes (typing, ValueAs, ConvertToUnits,
  // TrackBar movement, PreferredUnits/Options changes, etc.)
  Label1.Caption := FormatFloat('0.###', NewValue);
end;

procedure TForm1.SciEdit1ParseError(Sender: TObject; const RawText: String);
begin
  // Fires when text couldn't be parsed/converted
  StatusBar1.SimpleText := 'Could not understand: ' + RawText;
end;

procedure TForm1.SciEdit1UserEdit(Sender: TObject);
begin
  // Fires only when the USER actually changed the text and committed it
  // (Enter key or focus lost) — not for programmatic Text/Value assignments
  MarkDocumentDirty;
end;
```

### Batching multiple changes

```pascal
// Avoids re-parsing after every single property change
SciEdit1.BeginUpdate;
try
  SciEdit1.UnitFamily := ufCustom;
  SciEdit1.CustomUnits := 'ft^3';
  SciEdit1.Text := '12 ft^3';
finally
  SciEdit1.EndUpdate; // parses once, here
end;
```

### Linking a TrackBar in code

```pascal
SciEdit1.TrackBar := TrackBar1;
SciEdit1.TrackBarFactor := 10;   // full swing multiplies/divides the value by 10x
SciEdit1.TrackBarRange := 100;   // slider resolution
```

## Error states

| `State` | Meaning |
|---|---|
| `sesEmpty` | The edit is blank; `HasValue` is `False`. |
| `sesValid` | The text was parsed successfully. |
| `sesInvalidNumber` | The numeric portion of the text couldn't be parsed. |
| `sesInvalidUnits` | The unit portion isn't a recognized unit/expression. |
| `sesFamilyMismatch` | The units are valid, but belong to a different physical quantity than `UnitFamily` (or `CustomUnits`) requires. |

While in any of the three error states, the text is shown in `ErrorColor` and `OnParseError` fires.
