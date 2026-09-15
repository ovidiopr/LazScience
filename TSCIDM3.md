# TSciDM3 and TSciDM3Connector

`TSciDM3` parses GATAN DigitalMicrograph 3 (`.dm3`) files — the native format of the Gatan DigitalMicrograph electron-microscopy software — and exposes the image data, metadata tags, calibration, and thumbnail for use in Lazarus applications. `TSciDM3Connector` is a companion non-visual component that wires a `TSciDM3` to a standard `TTreeView` (for the tag hierarchy) and/or a `TImage` (for the rendered image) with no boilerplate code.

Units: `uSciDM3.pas` / `uSciDM3Connector.pas`

---

## Overview

A DM3 file is a tree-structured binary container. It holds one or more images (the first is usually a thumbnail; the selected image is the actual data), a rich metadata tag tree (acquisition parameters, microscope settings, calibration), and calibration information that relates pixel coordinates to physical dimensions.

`TSciDM3` loads the file, walks the tag tree, decodes the binary image payload into a 3-D variant array (width × height × depth), and exposes ready-to-use bitmaps, pixel values, calibration records, and the full tag list as a `TStringList` of `key=value` pairs.

`TSciDM3Connector` listens for the `DataChanged` event that `TSciDM3` fires after a successful parse, and automatically rebuilds the linked `TTreeView` and/or re-renders the linked `TImage`.

---

## TSciDM3

### Published properties

#### `FileName: String`

The full path to the `.dm3` file to load. Assigning a new value at runtime closes any previously open file and opens the new one. If `AutoParse` is `True`, parsing begins immediately; otherwise call `ParseDM3` explicitly.

#### `ChosenImage: Integer`
Default: `1`

DM3 files contain a list of images. Image 0 is almost always the embedded thumbnail; image 1 (the default) is the primary data image. Increase this index for files that contain multiple data images (e.g. spectrum-image cubes stored as separate slices).

Changing `ChosenImage` after a file is parsed does not re-parse the file; it re-selects which image's calibration and pixel data are exposed by the properties and methods.

#### `AutoParse: Boolean`
Default: `False`

When `True`, assigning `FileName` automatically calls `ParseDM3`. When `False`, you control the timing — useful when you need to configure other properties (such as `ChosenImage` or `OutputCharset`) before parsing begins.

#### `OutputCharset: String`
Default: `'UTF-8'`

The character encoding used when reading Unicode strings from the DM3 tag tree. Change this only if your DM3 files were saved with a non-UTF-8 encoding.

#### `DebugLevel: Integer`
Default: `0`

Controls the verbosity of diagnostic messages sent to `OnPrintMessage`:

| Value | Output |
|---|---|
| `0` | Silent |
| `1`–`3` | Key milestones (file open, parse complete, image dimensions) |
| `4`–`5` | Per-section progress |
| `6`–`10` | Full tag-by-tag trace |

#### `OnPrintMessage: TPrintMessageEvent`

Callback for all diagnostic and error output. Signature:

```pascal
procedure MyHandler(Sender: TObject; Msg: String; MsgType: TSciMsgType);
```

`TSciMsgType` values: `smInfo`, `smWarning`, `smError`.

Wire this to a memo or log window during development; leave it unassigned in production for silent operation.

---

### Read-only public properties

These are available after a successful `ParseDM3` call (`IsParsed = True`).

#### `IsOpen: Boolean`

`True` after a file has been opened successfully (the binary stream is available). Does not imply that parsing has completed.

#### `IsParsed: Boolean`

`True` after `ParseDM3` has completed without error. All image and metadata properties are valid only when this is `True`.

#### `DataType: TDataType`

The pixel data type stored in the DM3 file (e.g. `SIGNED_INT16_DATA`, `REAL4_DATA`, `UNSIGNED_INT8_DATA`, `COMPLEX8_DATA`, etc.). Useful for deciding how to interpret or display pixel values.

#### `Tags: TStringList`

The complete metadata tag tree flattened into `key=value` pairs. Keys use dot notation reflecting the DM3 tag path, e.g.:

```
root.ImageList.1.ImageData.Calibrations.Dimension.0.Scale=0.0425
root.ImageList.1.ImageData.Calibrations.Dimension.0.Units=nm
```

The list is sorted. Use `Tags.Values['some.path']` to retrieve a specific value.

#### `Info: TStringList`

A curated subset of `Tags` containing the most commonly useful acquisition parameters (microscope voltage, magnification, acquisition date, etc.). Suitable for displaying in a summary panel.

#### `Image[Index: Integer]: TBitmap`

Returns a normalised 8-bit grayscale `TBitmap` for the image at the given list index. The caller owns the returned bitmap and must free it.

#### `ImageData: TImageData`

The raw decoded pixel data as a `TImageData = array of array of array of Variant` (indexed `[x, y, z]`). For most 2-D images, `z = 0`. For complex data, `FDataReal` holds the real part; the imaginary part is accessible via `PixelValue` with appropriate handling.

#### `ImageWidth`, `ImageHeight`, `ImageDepth: Integer`

Pixel dimensions of the selected image. `ImageDepth` is 1 for a standard 2-D image and greater than 1 for a 3-D dataset (spectrum-image cube).

#### `Thumbnail: TBitmap`

The embedded thumbnail bitmap (image index 0). The caller owns the returned object and must free it.

#### `ThumbnailData: TByteDynArray`

The raw BGRA bytes of the embedded thumbnail (4 bytes per pixel, matching `pf32bit`). Use this when you need to pass thumbnail data to a non-LCL consumer (e.g. a REST API or a hardware display buffer).

#### `ImageType: Integer`

The integer data-type code stored in the DM3 tag tree for the selected image. Maps to the `DataTypes` constant array (e.g. `1 = SIGNED_INT16_DATA`).

#### `LowLimit`, `HighLimit: Double`

Display window limits for the selected image, as stored by DigitalMicrograph. If the DM3 file does not contain display limits, these are computed as the actual minimum and maximum of `ImageData`.

#### `Cuts: TPoint`

Convenience wrapper: `TPoint(Round(LowLimit), Round(HighLimit))`.

#### `Axis[Index: Integer]: TTriple`

Calibration record for the axis at position `Index` (0 = X, 1 = Y, 2 = Z for a 3-D dataset). `TTriple` holds:

```pascal
TTriple = record
  Origin:    Double;  // calibrated coordinate of pixel 0
  PixelSize: Double;  // physical size of one pixel
  Units:     String;  // unit string (e.g. 'nm', 'eV')
end;
```

#### `PxSize: TTriple`

Shorthand for `Axis[0]` — the X-axis calibration, which in a 2-D image gives the physical pixel size.

#### `SptUnits: String`

The brightness (intensity) units of the selected image, as stored in the calibration tags (e.g. `'Counts'`, `'e-'`).

---

### Methods

#### `procedure ParseDM3`

Opens and fully parses the file set in `FileName`. After a successful call, `IsParsed` is `True` and all read-only properties are valid. Fires `DataChanged` to notify any registered listeners (including a linked `TSciDM3Connector`).

Raises an exception if the file cannot be opened or is not a valid DM3 file.

#### `constructor CreateFile(AOwner: TComponent; const AFileName: String; ADebugLevel: Integer = 0)`

Alternative constructor for programmatic use: creates the component, sets `FileName` and `DebugLevel`, and immediately calls `ParseDM3`. Useful when you instantiate `TSciDM3` in code rather than dropping it on a form.

```pascal
DM3 := TSciDM3.CreateFile(Self, '/data/image.dm3');
try
  ShowMessage(Format('%d × %d px, pixel size = %.4f %s',
    [DM3.ImageWidth, DM3.ImageHeight,
     DM3.PxSize.PixelSize, DM3.PxSize.Units]));
finally
  DM3.Free;
end;
```

#### `function PixelValue(X, Y, Z: Integer): Double`

Returns the real-part value of the pixel at `(X, Y, Z)` as a `Double`, regardless of the underlying storage type. For complex data this is the real component; use `ImageData` directly for the imaginary component.

#### `function PNGThumbnail: TPortableNetworkGraphic`

Returns the embedded thumbnail as a `TPortableNetworkGraphic`. The caller owns the returned object and must free it. Returns `nil` if no thumbnail is present or if parsing has not completed.

#### `procedure DumpTags(const DumpDir: String)`

Writes the full tag list to a text file named `<OriginalFilename>.tags.txt` in `DumpDir`. Useful for exploring an unfamiliar DM3 file's metadata structure.

#### `procedure RegisterDataChangeListener(AListener: TNotifyEvent)`
#### `procedure UnregisterDataChangeListener(AListener: TNotifyEvent)`

Manually register or unregister a `TNotifyEvent` callback that fires whenever `ParseDM3` completes. `TSciDM3Connector` uses this mechanism internally; these methods are also available for your own subscribers.

---

## TSciDM3Connector

`TSciDM3Connector` is a non-visual bridge component. Drop it alongside a `TSciDM3` and point it at a `TTreeView` and/or a `TImage`; it handles all update logic automatically.

### Published properties

#### `DM3: TSciDM3`

The `TSciDM3` instance to observe. When set, the connector registers a `DataChanged` listener on the parser so that the tree view and image are refreshed automatically after every parse.

Setting `DM3` to `nil` (or freeing the referenced component) cleanly unregisters the listener.

#### `TreeView: TTreeView`

The tree view control to populate with the tag hierarchy. Each DM3 tag path is broken on `.` delimiters to create nested tree nodes; leaf nodes display the tag value. Set to `nil` to disable tree population.

#### `ImageControl: TImage`

The `TImage` control to render the data image into. The connector reads `LowLimit`/`HighLimit` from the linked `TSciDM3` to normalise pixel values to the 0–255 range. Set to `nil` to disable image rendering.

#### `AutoRefresh: Boolean`
Default: `True`

When `True`, the connector rebuilds the tree and/or re-renders the image immediately whenever:
- `DM3` is assigned or changed,
- `TreeView` or `ImageControl` is assigned or changed,
- `ColorScheme` or `SliceIndex` is changed,
- the linked `TSciDM3` fires its `DataChanged` event.

Set to `False` to suppress automatic updates and call `Refresh` manually instead.

#### `ColorScheme: TDM3ColorScheme`
Default: `csGrayscale`

Controls how pixel values are mapped to display colours:

| Value | Effect |
|---|---|
| `csGrayscale` | Dark pixels for low values, bright for high |
| `csInverted` | Bright pixels for low values, dark for high |

#### `SliceIndex: Integer`
Default: `0`

For 3-D datasets (`ImageDepth > 1`), selects which Z-slice is rendered in `ImageControl`. Changing this property triggers an image refresh when `AutoRefresh` is `True`.

---

### Methods

#### `procedure Refresh`

Forces an immediate rebuild of both the tree view and the image. Call this after setting `AutoRefresh := False` and making a batch of property changes.

---

## Design-time usage

1. Drop a `TSciDM3` on the form. Set `FileName` (or leave blank and assign at runtime). Set `AutoParse` to `True` if you want parsing to begin as soon as a file name is assigned.
2. Drop a `TSciDM3Connector` on the form. Set its `DM3` property to the `TSciDM3` instance.
3. Drop a `TTreeView` on the form and set `TSciDM3Connector.TreeView` to it.
4. Drop a `TImage` on the form (set `Stretch := True` for best results) and set `TSciDM3Connector.ImageControl` to it.
5. At runtime, assign `TSciDM3.FileName` and call `ParseDM3` (or rely on `AutoParse`). The connector automatically populates the tree view and renders the image.

---

## Runtime usage example

```pascal
uses uSciDM3, uSciDM3Connector;

// Design-time: SciDM3_1 and SciDM3Connector1 are already linked.

procedure TForm1.ButtonOpenClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    SciDM3_1.FileName := OpenDialog1.FileName;
    SciDM3_1.ParseDM3;

    // After ParseDM3 the connector has already refreshed the tree
    // and image automatically (AutoRefresh = True).

    lblSize.Caption := Format('%d × %d px', [SciDM3_1.ImageWidth, SciDM3_1.ImageHeight]);
    lblScale.Caption := Format('%.4f %s/px', [SciDM3_1.PxSize.PixelSize, SciDM3_1.PxSize.Units]);
  end;
end;

procedure TForm1.OnPrintMessage(Sender: TObject; Msg: String; MsgType: TSciMsgType);
begin
  case MsgType of
    smError:   Memo1.Lines.Add('[ERROR] ' + Msg);
    smWarning: Memo1.Lines.Add('[WARN]  ' + Msg);
    smInfo:    Memo1.Lines.Add('[INFO]  ' + Msg);
  end;
end;
```

---

## Supported image data types

`TSciDM3` can decode and render the following pixel storage types into `ImageData` and `PixelValue`:

`SIGNED_INT8`, `UNSIGNED_INT8`, `SIGNED_INT16`, `UNSIGNED_INT16`, `SIGNED_INT32`, `UNSIGNED_INT32`, `SIGNED_INT64`, `UNSIGNED_INT64`, `REAL4` (single), `REAL8` (double), `COMPLEX8` (real part only for rendering), `COMPLEX16` (real part only for rendering).

RGB and RGBA types are not decoded into `ImageData`; the thumbnail (always RGB) is handled separately via `GetThumbnail`.

---

## Acknowledgements

The DM3 file format parsing is based on the DM3_Reader plug-in for ImageJ by Greg Jefferis and the Python adaptation by Pierre-Ivan Raynal. The original format specification is published at [er-c.org/cbb/info/dmformat](http://www.er-c.org/cbb/info/dmformat/).
