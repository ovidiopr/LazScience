# TSciReader & TSciReaderDlg

Two complementary Lazarus/Free Pascal (LCL) components for loading delimited text data files (instrument logs, CSV/TSV exports, lab data dumps, etc.) into a Pascal application:

- **`TSciReader`** (`uSciReader.pas`) — a non-visual data component that parses a delimited text file into rows/columns of cells and numeric values, and can apply user-defined formulas to compute the X and Y values exposed to consumers.
- **`TSciReaderDlg`** (`uSciReaderDlg.pas`) — an interactive **file-format dialog**: it lets the user pick a file and configure how it is parsed — delimiter, comment character, header lines, decimal style, and more, including the X/Y formulas — while watching a live preview, then loads the result straight into a `TSciReader` you have linked to it.

You can use `TSciReader` entirely on its own if you already know a file's format and just want to parse it. `TSciReaderDlg` is for the common case where the file format needs to be discovered or confirmed interactively by the end user, without you writing that UI yourself.

---

## How `TSciReader` works

`TSciReader.LoadFromFile` / `LoadFromString` splits the input into lines, then splits each line into cells according to `Options` (a `TTXTOptions`), and stores the result as a simple 2-D array of strings. Lines are handled as follows, in order:

1. The first `HeaderLines` lines are skipped entirely (not stored as data, not counted as rows).
2. Any remaining line whose first non-whitespace character equals `Comment` is skipped (set `Comment := #0` to disable comment stripping).
3. Every other line is split into cells on `Delimiter`, honouring `Quotation` as a quote character if set (`#0` disables quoting).
4. If a line fails to split for any reason, the whole raw line is kept as a single cell and a message is added to `Errors` — a malformed row never aborts the whole load.

The parsed result is exposed as:

| Member | Description |
|---|---|
| `Cells[ACol, ARow]` *(default property)* | The raw string in a given cell; out-of-range access returns `''` instead of raising. |
| `Value[ACol, ARow]` | The cell parsed as a `Double`, using `Options.Decimal` / `Options.Thousand` as the separators; unparsable or empty cells return `0.0`. |
| `X[ARow]` | The computed X value for the row — see **Formulas** below. |
| `Y[ARow]` | The computed Y value for the row — see **Formulas** below. |
| `ColCount[ARow]` | Number of cells in a specific row (rows can have different lengths). |
| `RowCount` | Total number of data rows (after removing header/comment lines). |
| `MaxColCount` | The widest row seen, handy for sizing a grid. |
| `Errors` / `HasErrors` | Any row-level parse problems encountered while loading, including formula errors. |
| `FileDate` | See below. |

Because `Cells` is the default indexed property, `Reader[col, row]` and `Reader.Cells[col, row]` are equivalent.

---

## Column naming convention

Each data column is assigned a single letter used as its variable name in formulas. The letters run `A B C D E F G H I J K L M N O P Q R S T U V W Z` (24 letters; **X and Y are deliberately skipped** so they can be used as reserved names in the Y formula without ambiguity). Columns past the first 24 get two-letter names by the same scheme (`AA`, `AB`, …).

The dialog's grid header row shows the letter for each column so the user always knows which name to put in a formula.

---

## Formulas

`TSciReader` exposes two computed properties, `X[ARow]` and `Y[ARow]`, driven by the `XFormula` and `YFormula` strings in `TTXTOptions`. These let you express any algebraic transformation of the raw column data without writing any Pascal code.

### When no formula is set

If `XFormula` is empty, `X[ARow]` returns `Value[Options.XCol, ARow]` — the raw numeric value of the column at index `XCol`. Likewise for `YFormula` / `YCol`. This is the same behaviour as before formulas were added, so existing code is unaffected.

### When a formula is set

`XFormula` is compiled once (on first access after a load) into an expression tree by the `TFormula` engine (`uFormula.pas`). It is then evaluated once per row, with the column letters `A`, `B`, `C`, … bound to the raw numeric values of the corresponding columns in that row.

`YFormula` is compiled with the same column letters **plus** the special name `X`, which is bound to the already-computed value of `X[ARow]`. This lets you write a Y expression that builds on the X transformation — for example, converting a raw time column first (in XFormula) and then dividing the signal column by the converted time (in YFormula).

If the formula fails to compile (syntax error, unknown variable), `Valid` is `False`, a message is added to `Errors`, and the property returns `0.0` for every row.

### Formula syntax

| Element | Examples |
|---|---|
| **Numbers** | `1`, `2.5`, `1e-3`, `1.2E5` |
| **Column variables** | `A`, `B`, `C`, … (case-insensitive) |
| **Special variable (Y formula only)** | `X` — the result of the X formula for the same row |
| **Constant** | `pi` |
| **Arithmetic** | `+`, `-`, `*`, `/`, `^` (power, right-associative) |
| **Unary minus** | `-A`, `-sin(B)` |
| **Parentheses** | `(A + B) * C` |
| **Functions** | `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `exp`, `ln`, `log10`, `sqrt`, `abs`, `sign`, `sqr`, `round`, `trunc`, `frac` |

All functions take exactly one argument: `sqrt(A)`, `abs(B - C)`, `sin(pi * A)`.

Operator precedence (highest to lowest): function call / parentheses → `^` → unary minus → `*` `/` → `+` `-`. So `-2^2` evaluates to `-(2^2) = -4`, and `2^3^2` evaluates to `2^(3^2) = 512`, matching common calculator conventions.

Division by zero and invalid domain errors (e.g. `sqrt` of a negative number, `ln` of zero) return `NaN` rather than raising an exception.

A column variable that is out of range for a particular row (e.g. column `C` on a row that only has two cells) quietly evaluates to `0.0`.

### Formula examples

```
# X formula: convert column A (milliseconds) to seconds
A / 1000

# Y formula: subtract a baseline held in column C from the signal in column B
B - C

# Y formula: normalise to X (already computed as seconds)
B / X

# Y formula: calibrated thermocouple reading (linear correction)
A * 1.025 - 0.3

# X formula: convert a degree column to radians
A * pi / 180

# Y formula: use a more complex expression
sqrt(B^2 + C^2)
```

---

## `TTXTOptions` reference

`TSciReader.Options` (and the value the dialog edits) is a `TTXTOptions`:

| Property | Default | Description |
|---|---|---|
| `Delimiter` | `' '` (space) | Character that separates cells within a line. |
| `Comment` | `'#'` | Lines starting with this character (after leading whitespace) are skipped. Set to `#0` to disable. |
| `Quotation` | `#0` | Quote character for cells containing the delimiter itself. `#0` disables quoting. |
| `HeaderLines` | `0` | Number of lines to skip unconditionally at the top of the file. |
| `Decimal` | `'.'` | Decimal separator used when parsing `Value[...]` and column values in formula evaluation. |
| `Thousand` | `#0` | Thousands separator to strip when parsing `Value[...]` and column values in formula evaluation. `#0` disables it. |
| `XCol` | `0` | Column index for `X[ARow]` when `XFormula` is empty. |
| `YCol` | `1` | Column index for `Y[ARow]` when `YFormula` is empty. |
| `XLbl` | `'X'` | Suggested axis label for the X series — carried as metadata for consumers (e.g. a charting component). |
| `YLbl` | `'Y'` | Suggested axis label for the Y series. |
| `XFormula` | `''` | Formula expression for computing `X[ARow]`. Empty means fall back to `Value[XCol, ARow]`. |
| `YFormula` | `''` | Formula expression for computing `Y[ARow]`. Empty means fall back to `Value[YCol, ARow]`. Column `X` is also available in this formula. |
| `DateSeparator` / `TimeSeparator` | `'/'` / `':'` | Separators used when parsing the `FileDate` timestamp. |
| `DateTimeLine` / `DateTimeCol` / `DateTimeLength` | `0` / `0` / `0` | Position (0-based line/column) and length of the embedded timestamp substring used by `FileDate`. Length `0` disables `FileDate`. |
| `DateTimeFormat` | `'dd/mm/yyyy, hh:nn:ss'` | `ScanDateTime` format string used to parse the timestamp substring. |

`TTXTOptions` is a plain `TPersistent` — copy it with `Assign`, compare two instances with `IsEqual`.

---

## `FileDate`

Many instrument log files embed a timestamp for the whole file/run in a fixed position on a specific line (e.g. column 10 of line 0, 19 characters, `dd/mm/yyyy, hh:nn:ss`), separate from the per-row X/Y data. If `Options.DateTimeLength > 0`, `FileDate` extracts the substring at `DateTimeLine` / `DateTimeCol` (0-based) of that length from the *raw* line text (not from the parsed cells) and parses it with `Options.DateTimeFormat`, `DateSeparator`, and `TimeSeparator`. It returns `0` if the fields are not configured or the substring cannot be parsed.

---

## The `TSciReaderDlg` dialog

`TSciReaderDlg` is the interactive file-format dialog. Calling `Execute` shows the dialog modally; if the user accepts it, `TSciReaderDlg` applies the chosen format to the linked `TSciReader` and loads the chosen file into it — so from the calling code's point of view, one call does everything: pick a file, confirm/adjust its format, and load it.

### What the dialog shows

- A **raw text preview** (Memo) of the loaded file, and a **grid preview** (StringGrid) showing how it currently parses into rows/columns. The grid header row shows the column letter (`A`, `B`, `C`, …) for each column so the user knows which names to use in formulas. The grid updates live as any option changes.
- Dropdowns for **Delimiter**, **Comment**, **Quotation**, **Decimal**, **Thousand**, **Date separator**, and **Time separator**, each populated from a customisable candidate list (see `CharOptions` below).
- A **Header lines** spin edit, and **X/Y column** dropdowns with matching **X/Y label** text fields.
- **X formula** and **Y formula** text fields. These are visible by default and can be hidden by removing `srdShowFormulas` from `DialogOptions`. After each keystroke (on focus-leave), the formula is compiled and evaluated against the first data row; the result is shown in a status label beneath the fields — green for a valid formula with the computed `X`/`Y` values, red with the error message if the formula is invalid.
- **Date/Time** fields (separators + a `ScanDateTime` format string) plus a **"Reset Date/Time"** button that restores the defaults. This panel is visible by default and can be hidden by removing `srdDateTimeReading` from `DialogOptions`.
- **Right-click / "…" menu on the source text preview:** select a single character in the raw text and use the popup menu (or the toolbar's menu button) to instantly set it as the Delimiter, Comment, Quotation, Decimal, Thousand, Date separator, or Time separator — the fastest way to configure a new file format. Selecting a range of text and choosing **"Date/Time"** from the same menu records that selection's line/column/length as the `DateTimeLine` / `DateTimeCol` / `DateTimeLength` fields, so the parsed file timestamp is shown live in the data-panel label.
- A **Load** button (enabled only when an `OpenDialog` has been assigned) to browse for a different file, and a **Refresh** button to re-run parsing with the current settings.
- **Accept/Cancel** buttons; `Execute` returns whether the user accepted.

### Per-directory format memory

If `srdAutoSaveConfig` is in `DialogOptions` (the default), accepting the dialog writes the current `TTXTOptions` — including formulas — to an `.ini`-style config file in the same directory as the loaded file (named after `ConfigFile`, or after the application's executable name with a `.cfg` extension if `ConfigFile` is blank). The next time a file from that same directory is opened through the dialog, those settings are read back automatically, so users configure a given instrument/export format once per folder and the dialog remembers it.

### Published properties of `TSciReaderDlg`

#### `Reader: TSciReader`

The `TSciReader` instance that the dialog reads its initial options from, and writes the chosen options and loaded data back to on acceptance.

#### `FileName: String`

The file to load when `Execute` is called. Updated to the last file the user accepted in the dialog.

#### `OpenDialog: TOpenDialog`

A standard `TOpenDialog` that powers the dialog's "Load" button. Without it the button is disabled, but you can still open a specific file by passing its path to `Execute`.

#### `ConfigFile: TFileName`

Custom name for the per-directory settings file. Defaults to `<AppName>.cfg` in the same directory as the loaded file when blank.

#### `DialogOptions: TSciReaderDlgOptions`

Default: `[srdDateTimeReading, srdAutoSaveConfig, srdShowFormulas]`

A set controlling which sections of the dialog are active:

| Element | Effect when included |
|---|---|
| `srdDateTimeReading` | Shows the Date/Time panel and parses `FileDate` live |
| `srdAutoSaveConfig` | Writes and reads the per-directory `.cfg` file |
| `srdShowFormulas` | Shows the X/Y formula fields and live formula feedback |

Remove any element to hide the corresponding section of the dialog UI. The underlying data (formulas, date/time settings) is still honoured by `TSciReader` even when hidden from the dialog.

#### `CharOptions: TCharListOptions`

Controls the candidate lists shown in each dropdown. See **Customising the dropdown choices** below.

#### `Options: TTXTOptions`

Shorthand accessor: reads and writes `Reader.Options` directly. Raises an exception if `Reader` is not assigned.

### `LoadDirConfig(const ADirectory: TFileName): Boolean`

Reads the saved per-directory configuration for the given directory into `Reader.Options`, without opening the dialog. Useful for restoring a previously saved format programmatically at application startup.

```pascal
SciReaderDlg1.LoadDirConfig(ExtractFileDir(MyFilePath));
SciReader1.LoadFromFile(MyFilePath);
```

### Customising the dropdown choices (`CharOptions`)

Each dropdown's list of selectable named characters is configurable via the dialog's `CharOptions` property (a `TCharListOptions`):

| List property | Default entries |
|---|---|
| `DelimiterChars` | `SPACE`, `TAB`, `;`, `,` |
| `CommentChars` | `#`, `>`, `/`, `'` |
| `QuotationChars` | `NONE`, `"`, `'` |
| `DecimalChars` | `.`, `,`, `;` |
| `ThousandChars` | `NONE`, `SPACE`, `,`, `.`, `;` |
| `DateSeparatorChars` | `SPACE`, `/`, `-` |
| `TimeSeparatorChars` | `SPACE`, `:`, `.`, `;` |

Each list accepts either a named token (`SPACE`, `TAB`, `LF`, `CR`, `ESC`, `NONE`), a literal single character, or an ordinal escape (`#9`, `#13`, …). Edit these lists at design time or in code to restrict the dropdowns to formats relevant to your instruments, or to add an unusual delimiter. Whatever the user actually picks (via a dropdown or the right-click menu) is added to the list automatically if it is not already there, so the list grows organically with use.

---

## Using `TSciReader` alone (no dialog)

If you already know the file format and any transformations needed, skip the dialog entirely:

```pascal
uses uSciReader;

Reader := TSciReader.Create(Self);
Reader.Options.Delimiter := ',';
Reader.Options.Comment := '#';
Reader.Options.HeaderLines := 1;
Reader.Options.Decimal := '.';

// Optional: transform the raw columns with formulas
// Column A = time in ms, column B = raw sensor counts
Reader.Options.XFormula := 'A / 1000';        // convert ms → s
Reader.Options.YFormula := '(B - 50) * 0.02'; // offset and scale

Reader.LoadFromFile('C:\data\run042.csv');

if Reader.HasErrors then
  ShowMessage(Reader.Errors.Text)
else
  for i := 0 to Reader.RowCount - 1 do
    ChartSeries1.AddXY(Reader.X[i], Reader.Y[i]);
```

If no formulas are needed, use `Reader.Value[XCol, i]` / `Reader.Value[YCol, i]` directly, or set `XCol` / `YCol` and use `Reader.X[i]` / `Reader.Y[i]` without formulas.

`LoadFromString` works identically but takes the file content directly (e.g. text already fetched over a network or held in a memo) instead of a path.

---

## Using `TSciReader` + `TSciReaderDlg` together — from the Designer

1. Drop a **`TSciReader`** onto the form or data module.
2. Drop a **`TSciReaderDlg`** next to it.
3. Drop a standard **`TOpenDialog`** (needed only if you want the dialog's "Load" button to let the user browse for a different file).
4. In the Object Inspector, on `TSciReaderDlg`, set:
   - **Reader** → the `TSciReader` instance from step 1.
   - **OpenDialog** → the `TOpenDialog` from step 3 (leave unassigned to disable the "Load" button).
   - **FileName** → an initial file to open, if any.
   - **ConfigFile** — optional custom name for the per-directory settings file.
   - **DialogOptions** — choose which panels to show; default `[srdDateTimeReading, srdAutoSaveConfig, srdShowFormulas]` shows everything.
   - **CharOptions** — customise the dropdown candidate lists if needed.
5. Wire a button or menu item to call `SciReaderDlg1.Execute`.

---

## Using `TSciReader` + `TSciReaderDlg` together — from code

```pascal
uses uSciReader, uSciReaderDlg;

SciReaderDlg1.Reader := SciReader1;            // if not already wired at design time
SciReaderDlg1.OpenDialog := OpenDialog1;
SciReaderDlg1.FileName := 'C:\data\run042.csv'; // optional starting point

if SciReaderDlg1.Execute then
begin
  // SciReader1.Options (including any formulas) and SciReader1's data
  // have already been updated; SciReaderDlg1.FileName reflects the
  // file the user ended up loading.
  if SciReader1.HasErrors then
    ShowMessage(SciReader1.Errors.Text);

  for i := 0 to SciReader1.RowCount - 1 do
    ChartSeries1.AddXY(SciReader1.X[i], SciReader1.Y[i]);
end;
```

The overload `Execute(const AFileName: String)` lets you specify the file to open in the same call:

```pascal
if SciReaderDlg1.Execute('C:\data\run043.csv') then
  ...
```

Both `Reader` and `OpenDialog` must be assigned before calling `Execute`, or `TSciReaderDlg` raises an exception. This is a deliberate fail-fast check: a dialog with nowhere to put its result, or no way to browse for a file, is a configuration mistake rather than a runtime condition to handle gracefully.

You can also read and write the file format and formulas directly through the dialog component without opening the dialog window:

```pascal
SciReaderDlg1.Options.Delimiter := ';';
SciReaderDlg1.Options.XFormula := 'A * pi / 180';
SciReaderDlg1.Options.YFormula := 'sin(X)';
```

---

## Error handling for formulas

Formula errors are reported through the same `Errors` / `HasErrors` mechanism as parse errors. Each call to `X[ARow]` or `Y[ARow]` that encounters an invalid formula appends a message such as `'X Formula error: Unknown variable "Z"'` to `Errors`. Check `HasErrors` after iterating all rows, or check it once after `LoadFromFile` if you call `X`/`Y` immediately during the load.

```pascal
Reader.LoadFromFile(FileName);
// Trigger formula evaluation across all rows
for i := 0 to Reader.RowCount - 1 do
  ChartSeries1.AddXY(Reader.X[i], Reader.Y[i]);

if Reader.HasErrors then
  MemoErrors.Lines.Assign(Reader.Errors);
```
