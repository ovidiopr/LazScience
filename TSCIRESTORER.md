# TSciRestorer

`TSciRestorer` is a non-visual component that saves and restores the size, position, window state, and panel layout of Lazarus forms across application sessions, using an INI file as persistent storage. Drop one instance on a form and, with zero additional code, the form will reopen exactly where the user left it. For non-owner forms, call `SaveForm` and `RestoreForm` directly.

Unit: `uSciRestorer.pas`

---

## How it works

`TSciRestorer` intercepts the owner form's `OnShow` and `OnClose` events (while preserving any handlers you already have). On `OnShow` it calls `RestoreForm` once; on `OnClose` it calls `SaveForm` — but only if the close action is not `caNone` (i.e. only when the form is actually going away). If the form is hidden with `caHide` and later shown again, the restore fires again on the next `OnShow`.

Geometry is stored in an INI file whose location, section name, and file name are all configurable. DPI values are saved alongside geometry so that sizes and positions are correctly scaled when the application is next run on a display with a different pixel density.

---

## Published properties

### INI file location

#### `IniLocation: TIniLocation`
Default: `ilAppDir`

Controls where the INI file is stored. Three modes are available:

| Value | Where the file goes |
|---|---|
| `ilAppDir` | Same directory as the application executable |
| `ilUserDir` | The OS per-user configuration directory (see below) |
| `ilCustomDir` | An arbitrary path supplied via `IniFileName` |

**`ilUserDir` paths by OS** (resolved using Lazarus's `GetAppConfigDir` / `GetUserDir`):

| OS | Default path |
|---|---|
| Windows | `%APPDATA%\<AppName>\<AppName>.ini` |
| Linux | `~/.config/<AppName>/<AppName>.ini` |
| macOS | `~/Library/Application Support/<AppName>/<AppName>.ini` |

When `UserSubDir` is set, the subdirectory name you provide is used instead of the Lazarus-generated application name.

The directory is created automatically if it does not exist.

#### `IniFileName: String`
Default: `''` (uses the application executable name with a `.ini` extension)

Behaviour depends on `IniLocation`:

- `ilAppDir` / `ilUserDir` — treated as a bare file name only (any path component is stripped). The directory is still determined by `IniLocation`.
- `ilCustomDir` — treated as the complete file path, including directory.

#### `UserSubDir: String`
Default: `''`

Only used when `IniLocation = ilUserDir`. Specifies the subdirectory created inside the OS user-configuration folder. If empty, Lazarus's default application-name subfolder is used.

Example: setting `UserSubDir := 'MyApp'` on Linux produces `~/.config/MyApp/<IniFileName>`.

#### `IniSection: String`
Default: `''` (resolves to `'SciRestorer'`)

The INI section name under which all keys for this component instance are stored. Set this explicitly when you have more than one `TSciRestorer` sharing the same INI file (e.g. one per form in an MDI application).

---

### Save/restore behaviour

#### `DefaultWhatSave: STWhatSave`
Default: `[svSize, svLocation, svState, svPanels]`

Controls which aspects of the form are saved and restored when `SaveForm` / `RestoreForm` are called with `What = [svDefault]`. The set can contain any combination of:

| Element | What is saved/restored |
|---|---|
| `svSize` | `Width` and `Height` of the form |
| `svLocation` | `Left` and `Top` of the form |
| `svState` | `WindowState` (`wsNormal`, `wsMaximized`, optionally `wsMinimized`) |
| `svPanels` | Width/height of docked `TPanel` controls (see below) |
| `svDefault` | Expands to `DefaultWhatSave` — used as the sentinel value in `What` parameters |

#### `AutoSaveRestoreOwner: Boolean`
Default: `True`

When `True`, the component automatically hooks the owner form's `OnShow` and `OnClose` to call `RestoreForm` and `SaveForm`. Set to `False` if you want to manage the timing yourself and call `SaveForm` / `RestoreForm` manually.

#### `SaveMinimized: Boolean`
Default: `False`

Controls what happens when the application is closed while the window is minimized.

- `False` (default): minimized state is not persisted; the form reopens as `wsNormal`.
- `True`: `wsMinimized` is saved and restored, so the form reopens minimized.

The default `False` is almost always the correct choice — reopening an application to a minimized window is confusing.

---

## Methods

### `procedure SaveForm(TheForm: TForm; const Key: String = ''; What: STWhatSave = [svDefault])`

Saves the state of `TheForm` to the INI file. `Key` is an optional identifier for the form's INI keys; if omitted, the form's `Name` property is used (falling back to its class name if `Name` is empty).

`What` selects which aspects to save:
- Pass `[svDefault]` (the default) to use `DefaultWhatSave`.
- Pass an explicit set such as `[svSize, svLocation]` to save only those aspects, regardless of `DefaultWhatSave`.

```pascal
// Save only the window state of a secondary form
SciRestorer1.SaveForm(Form2, 'OptionsForm', [svState]);
```

### `procedure RestoreForm(TheForm: TForm; const Key: String = ''; What: STWhatSave = [svDefault])`

Restores the state of `TheForm` from the INI file. If no previously saved data exists for the given key, the form's current property values are used as defaults (so the first run is always safe).

After applying saved geometry, `RestoreForm` automatically checks that the form is visible on at least one connected monitor and nudges it back onto the nearest work area if necessary. This handles the common case of a monitor being disconnected between sessions.

Window state is applied last, after geometry, so that maximise/restore works correctly.

---

## Panel save/restore

When `svPanels` is in the active set, `TSciRestorer` saves and restores the `Width` of panels aligned `alLeft` or `alRight`, and the `Height` of panels aligned `alTop` or `alBottom`. This preserves the position of splitter-divided layouts.

The component traverses the full control hierarchy recursively, so panels nested inside tab pages, group boxes, or other panels are all handled.

Two panels are excluded:
- **Unnamed panels** (`Name = ''`) — no stable INI key can be formed.
- **Opted-out panels** — any panel with `Tag = -1` is skipped entirely.

Panels with `alNone` or `alClient` alignment are skipped because their size is not independently resizable by a `TSplitter`.

Saved panel sizes are DPI-scaled when the display resolution differs between sessions, the same as form geometry.

---

## DPI scaling

Every time geometry is saved, the current `PixelsPerInch` of the form is written to the INI file alongside the size and position values. On restore, if the saved DPI differs from the current display DPI, all geometry values are scaled proportionally before being applied. This applies to both form dimensions and panel sizes.

Scaling is applied only to values that were actually read from the INI file. If you restore only `svLocation` (not `svSize`), for example, only the position is scaled — the size remains at whatever the form's current dimensions are.

---

## Design-time usage (zero-code auto-save)

1. Drop a `TSciRestorer` on the form whose state you want to persist.
2. Leave `AutoSaveRestoreOwner` as `True`.
3. Choose `IniLocation` — `ilAppDir` is fine for single-user desktop apps; use `ilUserDir` for apps installed in a shared system directory.
4. Optionally set `UserSubDir` (e.g. the application name) when using `ilUserDir`.
5. Run the application. The form's position, size, state, and panel layout will be saved on close and restored on the next launch.

No event handlers or code are required.

---

## Runtime usage (multiple forms)

A single `TSciRestorer` instance can save and restore as many forms as you need. Use the `Key` parameter to give each form a distinct INI entry:

```pascal
// In FormCreate or a menu-open handler:
SciRestorer1.RestoreForm(SettingsForm, 'Settings');

// In the settings form's OnClose (or wherever you choose to save):
SciRestorer1.SaveForm(SettingsForm, 'Settings');
```

---

## Sharing an INI file between components

Multiple `TSciRestorer` instances (e.g. one per form in a large application) can write to the same INI file safely, provided each instance uses a distinct `IniSection`:

```pascal
// On Form1:
SciRestorer1.IniSection := 'MainWindow';

// On Form2:
SciRestorer2.IniSection := 'SettingsWindow';
```

Or use the `Key` parameter on a shared instance to disambiguate entries within the same section.

---

## Visibility clamping

After restoring position and size, `TSciRestorer` checks that at least 50 pixels of the form remain within the work area of the nearest monitor. If the form would be completely (or nearly completely) off-screen — for example because a monitor has been removed since the last session — it is nudged back to a fully visible position. The form is never resized larger than the work area.

---

## Notes on `caHide` forms

If a form is closed with `CloseAction = caHide` (hidden rather than destroyed), `TSciRestorer` saves the form state and resets its internal "already restored" flag. The next time the form is shown, `RestoreForm` fires again. This means hide/show cycles behave consistently with open/close cycles.
