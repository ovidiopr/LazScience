# TSciReader & TSciReaderDlg

Two complementary Lazarus/Free Pascal (LCL) components for loading delimited text data files (instrument logs, CSV/TSV exports, lab data dumps, etc.) into a Pascal application:

- **`TSciReader`** (`uSciReader.pas`) — a non-visual data component that parses a delimited text file into rows/columns of cells and numeric values. It has no UI of its own; you either configure it entirely from code, or let the dialog below configure it interactively.
- **`TSciReaderDlg`** (`uSciReaderDlg.pas`) — an interactive **file-format dialog**: it lets the user pick a file and configure how it's parsed — delimiter, comment character, header lines, decimal style, and more — while watching a live preview, then loads the result straight into a `TSciReader` you've linked to it.

You can use `TSciReader` entirely on its own if you already know a file's format and just want to parse it. `TSciReaderDlg` is for the common case where the file format needs to be discovered or confirmed interactively by the end user (arbitrary delimiter, comment character, header lines, decimal style, etc.), without you writing that UI yourself.

## How `TSciReader` works

`TSciReader.LoadFromFile`/`LoadFromString` splits the input into lines, then splits each line into cells according to `Options` (a `TTXTOptions`), and stores the result as a simple 2D array of strings. Lines are handled as follows, in order:

1. The first `HeaderLines` lines are skipped entirely (not stored as data, not counted as rows).
2. Any remaining line whose first non-whitespace character equals `Comment` is skipped (set `Comment := #0` to disable comment stripping).
3. Every other line is split into cells on `Delimiter`, honoring `Quotation` as a quote character if set (`#0` disables quoting).
4. If a line fails to split for any reason, the whole raw line is kept as a single cell and a message is added to `Errors` — a malformed row never aborts the whole load.

The parsed result is exposed as:

| Member | Description |
|---|---|
| `Cells[ACol, ARow]` *(default property)* | The raw string in a given cell; out-of-range access returns `''` instead of raising. |
| `Value[ACol, ARow]` | The cell parsed as a `Double`, using `Options.Decimal`/`Options.Thousand` as the separators; unparsable or empty cells return `0.0`. |
| `ColCount[ARow]` | Number of cells in a specific row (rows can have different lengths). |
| `RowCount` | Total number of data rows (after removing header/comment lines). |
| `MaxColCount` | The widest row seen, handy for sizing a grid. |
| `Errors` / `HasErrors` | Any row-level parse problems encountered while loading. |
| `FileDate` | See below. |

Because `Cells` is the default indexed property, `Reader[col, row]` and `Reader.Cells[col, row]` are equivalent.

### `FileDate`

Many instrument log files embed a timestamp for the whole file/run in a fixed position on a specific line (e.g. column 10 of line 0, 19 characters, `dd/mm/yyyy, hh:nn:ss`), separate from the per-row X/Y data. If `Options.DateTimeLength > 0`, `FileDate` extracts the substring at `DateTimeLine`/`DateTimeCol` (0-based) of that length from the *raw* line text (not from the parsed cells) and parses it with `Options.DateTimeFormat`, `DateSeparator`, and `TimeSeparator`. It returns `0` if the fields aren't configured or the substring can't be parsed.

## `TTXTOptions` reference

`TSciReader.Options` (and the value the dialog edits) is a `TTXTOptions`:

| Property | Default | Description |
|---|---|---|
| `Delimiter` | `' '` (space) | Character that separates cells within a line. |
| `Comment` | `'#'` | Lines starting with this character (after leading whitespace) are skipped. Set to `#0` to disable. |
| `Quotation` | `#0` | Quote character for cells containing the delimiter itself. `#0` disables quoting. |
| `HeaderLines` | `0` | Number of lines to skip unconditionally at the top of the file. |
| `Decimal` | `'.'` | Decimal separator used when parsing `Value[...]`. |
| `Thousand` | `#0` | Thousands separator to strip when parsing `Value[...]`. `#0` disables it. |
| `XCol` / `YCol` | `0` / `1` | Suggested column indices for X/Y data — not enforced by `TSciReader` itself, but carried along as metadata for consumers (e.g. a charting component) that want a default column pairing. |
| `XLbl` / `YLbl` | `'X'` / `'Y'` | Suggested axis/column labels, same purpose as above. |
| `DateSeparator` / `TimeSeparator` | `'/'` / `':'` | Separators used when parsing the `FileDate` timestamp. |
| `DateTimeLine` / `DateTimeCol` / `DateTimeLength` | `0` / `0` / `0` | Position (0-based line/column) and length of the embedded timestamp substring used by `FileDate`. Length `0` disables `FileDate`. |
| `DateTimeFormat` | `'dd/mm/yyyy, hh:nn:ss'` | `ScanDateTime` format string used to parse that substring. |

`TTXTOptions` is a plain `TPersistent` — copy it with `Assign`, compare two instances with `IsEqual`.

## The `TSciReaderDlg` dialog

`TSciReaderDlg` is the interactive file-format dialog. Calling `Execute` shows the dialog modally; if the user accepts it, `TSciReaderDlg` applies the chosen format to the linked `TSciReader` and loads the chosen file into it — so from the calling code's point of view, one call does everything: pick a file, confirm/adjust its format, and load it.

### What the dialog shows

- A **raw text preview** (`Memo`) of the loaded file, and a **grid preview** (`StringGrid`) showing how it currently parses into rows/columns — the grid updates live as any option changes.
- Dropdowns for **Delimiter**, **Comment**, **Quotation**, **Decimal**, **Thousand**, **Date separator**, and **Time separator**, each populated from a customizable candidate list (see `CharOptions` below). Special values like `SPACE`, `TAB`, `NONE`, `CR`, `LF`, `ESC` are shown by name; anything else shows as the literal character or an ordinal escape (`#9`) for unprintable ones.
- A **Header lines** spin edit, and **X/Y column** dropdowns with matching **X/Y label** text fields.
- **Date/Time** fields (separators + a `ScanDateTime` format string) plus a **"Reset Date/Time"** button that restores the defaults.
- **Right-click / "..." menu on the source text preview:** select a single character in the raw text and use the popup menu (or the toolbar's menu button) to instantly set it as the Delimiter, Comment, Quotation, Decimal separator, Thousand separator, Date separator, or Time separator — the fastest way to configure a new file format. Selecting a range of text and choosing **"Date/Time"** from the same menu instead records that selection's line/column/length as the `DateTimeLine`/`DateTimeCol`/`DateTimeLength` fields, so the dialog can show the parsed file timestamp live.
- A **Load** button (enabled only when an `OpenDialog` has been assigned) to browse for a different file, and a **Refresh** button to re-run parsing with the current settings.
- **Accept/Cancel** buttons; `Execute` returns whether the user accepted.

### Per-directory format memory

If `AutoSaveConfig = True` (default), accepting the dialog writes the current `TTXTOptions` to an `.ini`-style config file in the same directory as the loaded file (named after `ConfigFile`, or after the application's executable name with a `.cfg` extension if `ConfigFile` is blank). The next time a file from that same directory is opened through the dialog, those settings are read back automatically — so, in practice, users configure a given instrument/export format once per folder and the dialog remembers it from then on.

### Customizing the dropdown choices (`CharOptions`)

Each dropdown's list of selectable "named characters" is configurable via the dialog's `CharOptions` property (a `TCharListOptions`):

| List property | Default entries |
|---|---|
| `DelimiterChars` | `SPACE`, `TAB`, `;`, `,` |
| `CommentChars` | `#`, `>`, `/`, `'` |
| `QuotationChars` | `NONE`, `"`, `'` |
| `DecimalChars` | `.`, `,`, `;` |
| `ThousandChars` | `NONE`, `SPACE`, `,`, `.`, `;` |
| `DateSeparatorChars` | `SPACE`, `/`, `-` |
| `TimeSeparatorChars` | `SPACE`, `:`, `.`, `;` |

Each list accepts either a named token (`SPACE`, `TAB`, `LF`, `CR`, `ESC`, `NONE`), a literal single character, or an ordinal escape (`#9`, `#13`, ...). Edit these lists at design time or in code to restrict the dropdowns to formats relevant to your instruments, or to add an unusual delimiter your files use — whatever the user actually picks (via a dropdown or the right-click menu) is added to the list automatically if it isn't there already, so the list also grows organically with use.

## Using `TSciReader` alone (no dialog)

If you already know the file format, skip the dialog entirely:

```pascal
Reader := TSciReader.Create(Self);
Reader.Options.Delimiter := ',';
Reader.Options.Comment := '#';
Reader.Options.HeaderLines := 1;
Reader.Options.Decimal := '.';

Reader.LoadFromFile('C:\data\run042.csv');

if Reader.HasErrors then
  ShowMessage(Reader.Errors.Text)
else
begin
  for i := 0 to Reader.RowCount - 1 do
    ChartSeries1.AddXY(Reader.Value[0, i], Reader.Value[1, i]);
end;
```

`LoadFromString` works identically but takes the file content directly (e.g. text already fetched over a network, or held in a memo) instead of a path.

## Using `TSciReader` + `TSciReaderDlg` together — from the Designer

1. Drop a **`TSciReader`** onto the form/data module.
2. Drop a **`TSciReaderDlg`** next to it.
3. Drop a standard **`TOpenDialog`** (needed only if you want the dialog's "Load" button to let the user browse for a different file).
4. In the Object Inspector, on `TSciReaderDlg`, set:
   - **Reader** → the `TSciReader` instance from step 1 — this is where the dialog will deposit the loaded data.
   - **OpenDialog** → the `TOpenDialog` from step 3 (leave unassigned to disable the "Load" button and only ever open the file passed to `Execute`).
   - **FileName** → an initial file to open, if any.
   - **ConfigFile** — optional custom name for the per-directory settings file (defaults to the executable's name with a `.cfg` extension).
   - **DateTimeReading** — whether the dialog shows/parses the embedded file timestamp (default `True`).
   - **AutoSaveConfig** — whether accepted settings are remembered per-directory (default `True`).
   - **CharOptions** — customize the dropdown candidate lists if needed (see above).
5. Wire a button/menu item to call `SciReaderDlg1.Execute` (see below) — there's nothing further to configure visually, since the dialog window itself is created on demand when `Execute` is called.

## Using `TSciReader` + `TSciReaderDlg` together — from code

```pascal
SciReaderDlg1.Reader := SciReader1;         // if not already wired at design time
SciReaderDlg1.OpenDialog := OpenDialog1;
SciReaderDlg1.FileName := 'C:\data\run042.csv'; // optional starting point

if SciReaderDlg1.Execute then
begin
  // SciReader1.Options and SciReader1's data have already been updated;
  // SciReaderDlg1.FileName now reflects whatever file the user ended up loading.
  if SciReader1.HasErrors then
    ShowMessage(SciReader1.Errors.Text);

  for i := 0 to SciReader1.RowCount - 1 do
    ChartSeries1.AddXY(
      SciReader1.Value[SciReader1.Options.XCol, i],
      SciReader1.Value[SciReader1.Options.YCol, i]);
end;
```

Calling `Execute` with no arguments (as above) reuses `FileName`/`Reader.Options` from whatever was last set; the overload `Execute(const AFileName: String)` lets you specify the file to open in the same call:

```pascal
if SciReaderDlg1.Execute('C:\data\run043.csv') then
  ...
```

Both `Reader` and `OpenDialog` **must** be assigned before calling `Execute`, or `TSciReaderDlg` raises an exception — this is a deliberate fail-fast check, since a dialog with nowhere to put its result, or no way to browse for a file, is a configuration mistake rather than a runtime condition to handle gracefully.

You can also read/write the file format directly through the dialog component without opening the dialog window at all:

```pascal
SciReaderDlg1.Options.Delimiter := ';';   // shorthand for SciReaderDlg1.Reader.Options.Delimiter
```
