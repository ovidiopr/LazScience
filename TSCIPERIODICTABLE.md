# TSciPeriodicTable and TSciPeriodicTableDlg

`TSciPeriodicTable` is a visual control that draws the periodic table of the elements, lets the user select an element with the mouse or the keyboard, and shows its details. `TSciPeriodicTableDlg` is a non-visual companion that wraps the same table in a modal, resizable dialog with **Accept** and **Cancel** buttons, in the style of `TOpenDialog`: call `Execute`, then read the chosen element.

Units: `uSciPeriodicTable.pas` / `uSciPeriodicTableDlg.pas` (the dialog form itself lives in `uPeriodicTableDlg.pas`, `uPeriodicTableDlg.lfm`)

---

## Overview

The table holds the 118 elements, laid out on an 18-column by 10-row grid: the seven periods, a spacer row, and the lanthanide and actinide rows underneath. The element data (atomic number, symbol, name, atomic weight, density, melting and boiling points, specific heat, phase) is compiled into the package, so no data file has to be shipped or loaded at run time.

The table always fills the client area of the control: the cells and the fonts scale automatically when the control (or the form hosting it) is resized. Cells are not forced to be square.

The element objects (`TSciElement`) are loaded once and shared by every table and dialog in the program. An element obtained from one component can therefore be assigned to another (for example `Table1.Selected := Dlg1.Element`).

---

## TSciElement

A read-only description of one element. Instances are owned by the package and stay valid for the whole program run; never free them.

| Property | Type | Description |
|---|---|---|
| `Number` | `Integer` | Atomic number (1–118). |
| `Symbol` | `String` | Chemical symbol, e.g. `'Fe'`. |
| `Name` | `String` | Element name, e.g. `'Iron'`. |
| `Phase` | `String` | `'Solid'`, `'Liquid'`, `'Gas'` or `'Artificial'`. |
| `Weight` | `Double` | Atomic weight, in u. |
| `Density` | `Double` | Density in g/cm³. `-1` if unknown. |
| `MeltingPoint` | `Double` | Melting point in K. `-1` if unknown. |
| `BoilingPoint` | `Double` | Boiling point in K. `-1` if unknown. |
| `SpecificHeat` | `Double` | Specific heat in J/(g·K). `-1` if unknown. |

> The names of the most recently named superheavy elements (113, 115, 117 and 118) are the provisional systematic names stored in the bundled data file.

---

## TSciPeriodicTable

### Published properties

#### `SelectedNumber: Integer`
Default: `1`

Atomic number of the selected element. The selected cell is drawn with the system highlight colors. Assigning a number outside `1..118` is ignored.

#### `ShowDetails: Boolean`
Default: `True`

When `True`, the empty block at the top of the table (groups 3–12, periods 1–3) shows the details of the selected element: large symbol, name, atomic number, atomic weight, phase and density (`n/a` if unknown). Set to `False` to leave that area blank.

#### `ColorLanthanides: TColor`
Default: `clSkyBlue`

Background of the lanthanide cells (atomic numbers 57–71).

#### `ColorActinides: TColor`
Default: a light violet (`$00D3A8FF`)

Background of the actinide cells (atomic numbers 89–103).

#### `ColorOthers: TColor`
Default: `clMoneyGreen`

Background of all the other element cells.

#### `Color: TColor`
Default: `clWindow`

Background of the empty areas of the table.

#### `Font: TFont`

The font **name** and **color** are used for all the text. The font **size** is ignored: text is scaled automatically to the size of the cells.

#### Inherited properties

`Align`, `Anchors`, `BorderSpacing`, `Constraints`, `Enabled`, `ParentColor`, `ParentFont`, `PopupMenu`, `ShowHint`, `TabOrder`, `TabStop` (default `True`) and `Visible`. The default size of a newly dropped control is 576 × 400.

---

### Events

#### `OnSelectionChange: TNotifyEvent`

Fires whenever the selected element changes, whether the change came from the mouse, the keyboard or code (`SelectedNumber` / `Selected`). It does not fire when the new value equals the current one.

#### `OnElementDblClick: TSciElementEvent`

Fires when the user double-clicks an element. A double-click on an empty cell does nothing. Signature:

```pascal
procedure MyHandler(Sender: TObject; Element: TSciElement);
```

`OnClick`, `OnEnter`, `OnExit` and `OnResize` are also published.

---

### Public properties and methods

#### `property Selected: TSciElement`

The selected element. Assigning an element selects it (and repaints the table). Assigning `nil` is ignored.

#### `property Elements[ANumber: Integer]: TSciElement`

Element by atomic number (`1..ElementCount`). Raises an exception for an invalid number.

#### `property ElementCount: Integer`

Number of elements (118).

#### `function FindElement(const ASymbol: String): TSciElement`

Case-insensitive search by symbol (`'fe'` finds iron). Returns `nil` if there is no such element.

#### `function ElementAt(ACol, ARow: Integer): TSciElement`

Returns the element drawn in the given grid cell (0-based column and row), or `nil` for an empty or out-of-range cell. Columns are groups 1–18 (0–17); rows 0–6 are periods 1–7, row 7 is the spacer, and rows 8 and 9 are the lanthanides and actinides.

#### `function ElementAtPos(X, Y: Integer): TSciElement`

Returns the element drawn at the given client-area position, or `nil`. Useful for hints and popup menus.

#### `procedure Assign(Source: TPersistent)`

When `Source` is another `TSciPeriodicTable`, copies its appearance (`Color`, `Font`, `ShowDetails` and the three color properties) and its selection. `Color` and `Font` are copied only if the source does not inherit them from its parent. Events are not copied and `OnSelectionChange` is not fired.

---

### Mouse and keyboard

| Action | Effect |
|---|---|
| Left click on an element | Selects it and gives the control focus. |
| Double click on an element | Selects it and fires `OnElementDblClick`. |
| Arrow keys | Move the selection to the next element in that direction, skipping empty cells (for example Right from beryllium jumps to boron). The selection stays put at the edges of the table. |

---

## TSciPeriodicTableDlg

A non-visual component. `Execute` shows a modal dialog containing a `TSciPeriodicTable` and the **Accept** and **Cancel** buttons. The dialog is a resizable tool window (`bsSizeToolWin`), and the table fills it, so the user can enlarge it to read the details more comfortably. Its minimum size keeps the table legible.

* **Accept** or **Enter** accepts the selected element.
* A **double click** on an element also accepts it.
* **Cancel**, **Esc** or closing the window cancels.

### Published properties

#### `Table: TSciPeriodicTable`

Configuration of the table shown in the dialog. In the Object Inspector it expands into the properties of a regular `TSciPeriodicTable`: set the colors, `Font`, `ShowDetails` and the initial `SelectedNumber` here. Only the appearance and the selection are used when the dialog opens (see `Assign` above); the `Left`, `Top`, `Width`, `Height` and `Align` properties shown for it have no effect, and neither do its events.

#### `Title: String`
Default: empty

Caption of the dialog. If empty, the default caption (`Periodic Table of the Elements`) is used.

### Public properties and methods

#### `function Execute: Boolean`

Shows the dialog modally. Returns `True` if the user accepted an element; in that case `SelectedNumber` and `Element` hold the choice. Returns `False` if the dialog was cancelled, and the previous selection is left unchanged.

#### `property SelectedNumber: Integer`

Atomic number of the selected element. It is the initial selection when the dialog opens and is updated by `Execute` when the user accepts. It is the same value as `Table.SelectedNumber`.

#### `property Element: TSciElement`

The selected element. Like all `TSciElement` objects, it is shared data that stays valid for the whole program run, so it can be used after the dialog has closed.

---

## Design-time usage

**Table on a form**

1. Drop a `TSciPeriodicTable` on the form (palette tab **Science**) and set `Align := alClient`, or position it freely.
2. Adjust `ColorLanthanides`, `ColorActinides`, `ColorOthers` and `ShowDetails` as needed.
3. Write `OnSelectionChange` and/or `OnElementDblClick` handlers.

**Selection dialog**

1. Drop a `TSciPeriodicTableDlg` on the form.
2. Expand `Table` in the Object Inspector to configure the colors, font and initial selection of the dialog's table, and set `Title` if you want a custom caption.
3. Call `Execute` from your code.

---

## Runtime usage examples

### Table that reacts to the selection

```pascal
uses uSciPeriodicTable;

procedure TForm1.SciPeriodicTable1SelectionChange(Sender: TObject);
var
  E: TSciElement;
begin
  E := SciPeriodicTable1.Selected;
  lblInfo.Caption := Format('%s (%s): %.3f u', [E.Name, E.Symbol, E.Weight]);
end;

procedure TForm1.SciPeriodicTable1ElementDblClick(Sender: TObject; Element: TSciElement);
begin
  ShowMessage(Element.Name);
end;
```

### Choosing an element with the dialog

```pascal
uses uSciPeriodicTable, uSciPeriodicTableDlg;

procedure TForm1.ButtonPickClick(Sender: TObject);
begin
  SciPeriodicTableDlg1.SelectedNumber := 26;        // start on iron
  if SciPeriodicTableDlg1.Execute then
    ShowMessage(Format('%s (Z = %d)',
      [SciPeriodicTableDlg1.Element.Name,
       SciPeriodicTableDlg1.SelectedNumber]));
end;
```

### Showing the dialog's choice on a table in the form

```pascal
if SciPeriodicTableDlg1.Execute then
  SciPeriodicTable1.Selected := SciPeriodicTableDlg1.Element;
// or, equivalently:
//   SciPeriodicTable1.SelectedNumber := SciPeriodicTableDlg1.SelectedNumber;
```

### Looking up elements without a visible table

```pascal
var
  T: TSciPeriodicTable;
  E: TSciElement;
begin
  T := TSciPeriodicTable.Create(nil);
  try
    E := T.FindElement('Cu');
    if E <> nil then
      WriteLn(E.Name, ' melts at ', E.MeltingPoint:0:1, ' K');
  finally
    T.Free;
  end;
end;
```
