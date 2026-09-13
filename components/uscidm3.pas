//==========================================================================//
//  Pascal module for parsing GATAN DM3 (DigitalMicrograph) files           //
//                                                                          //
//  based on the DM3_Reader plug-in (v 1.3.4) for ImageJ                    //
//  by Greg Jefferis <jefferis@stanford.edu>                                //
//  http://rsb.info.nih.gov/ij/plugins/DM3_Reader.html                      //
//                                                                          //
//  Python adaptation: Pierre-Ivan Raynal <raynal@univ-tours.fr>            //
//  http://microscopies.med.univ-tours.fr/                                  //
//                                                                          //
//  Several improvements and Pascal port:                                   //
//  Ovidio Peña-Rodríguez <ovidio@bytesfall.com>                            //
//  http://ovidio.me/                                                       //
//                                                                          //
//  Format: http://www.er-c.org/cbb/info/dmformat/                          //
//          https://imagej.nih.gov/ij/plugins/DM3Format.gj.html             //
//                                                                          //
//  2024-10-05 Ported to Pascal                                             //
//  2018-02-26 Made the library compatible with Python 3 (Ovidio)           //
//  2018-02-19 Added support for various data types (Ovidio)                //
//  2018-02-17 Removed PIL requirement (Ovidio)                             //
//==========================================================================//
unit uSciDM3;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, Graphics, Dialogs, Types,
  IntfGraphics, Variants, Math;

const
  // Constants for encoded data types
  SHORT_DATA = 2;
  LONG_DATA = 3;
  USHORT_DATA = 4;
  ULONG_DATA = 5;
  FLOAT_DATA = 6;
  DOUBLE_DATA = 7;
  BOOLEAN_DATA = 8;
  CHAR_DATA = 9;
  OCTET_DATA = 10;
  STRUCT_DATA = 15;
  STRING_DATA = 18;
  ARRAY_DATA = 20;

  // List of image DataTypes
  DataTypes: Array[0..37] of String = ('NULL_DATA',
                                       'SIGNED_INT16_DATA',
                                       'REAL4_DATA',
                                       'COMPLEX8_DATA',
                                       'OBSOLETE_DATA',
                                       'PACKED_DATA',
                                       'UNSIGNED_INT8_DATA',
                                       'SIGNED_INT32_DATA',
                                       'RGB_DATA',
                                       'SIGNED_INT8_DATA',
                                       'UNSIGNED_INT16_DATA',
                                       'UNSIGNED_INT32_DATA',
                                       'REAL8_DATA',
                                       'COMPLEX16_DATA',
                                       'BINARY_DATA',
                                       'RGB_UINT8_0_DATA',
                                       'RGB_UINT8_1_DATA',
                                       'RGB_UINT16_DATA',
                                       'RGB_FLOAT32_DATA',
                                       'RGB_FLOAT64_DATA',
                                       'RGBA_UINT8_0_DATA',
                                       'RGBA_UINT8_1_DATA',
                                       'RGBA_UINT8_2_DATA',
                                       'RGBA_UINT8_3_DATA',
                                       'RGBA_UINT16_DATA',
                                       'RGBA_FLOAT32_DATA',
                                       'RGBA_FLOAT64_DATA',
                                       'POINT2_SINT16_0_DATA',
                                       'POINT2_SINT16_1_DATA',
                                       'POINT2_SINT32_0_DATA',
                                       'POINT2_FLOAT32_0_DATA',
                                       'RECT_SINT16_1_DATA',
                                       'RECT_SINT32_1_DATA',
                                       'RECT_FLOAT32_1_DATA',
                                       'RECT_FLOAT32_0_DATA',
                                       'SIGNED_INT64_DATA',
                                       'UNSIGNED_INT64_DATA',
                                       'LAST_DATA');

  // Other constants
  IMGLIST = 'root.ImageList.';
  OBJLIST = 'root.DocumentObjectList.';
  MAXDEPTH = 64;

  DEFAULTCHARSET = 'UTF-8';

  VERSION = '1.1';

  // END constants

type
  TIntegerArray = Array of Integer;

  TImageData = Array of Array of Array of Variant;

  TReadFunc = function(F: TFileStream): Variant;

  TDataType = (NULL_DATA, SIGNED_INT16_DATA, REAL4_DATA, COMPLEX8_DATA,
               OBSOLETE_DATA, PACKED_DATA, UNSIGNED_INT8_DATA,
               SIGNED_INT32_DATA, RGB_DATA, SIGNED_INT8_DATA,
               UNSIGNED_INT16_DATA, UNSIGNED_INT32_DATA, REAL8_DATA,
               COMPLEX16_DATA, BINARY_DATA, RGB_UINT8_0_DATA,
               RGB_UINT8_1_DATA, RGB_UINT16_DATA, RGB_FLOAT32_DATA,
               RGB_FLOAT64_DATA, RGBA_UINT8_0_DATA, RGBA_UINT8_1_DATA,
               RGBA_UINT8_2_DATA, RGBA_UINT8_3_DATA, RGBA_UINT16_DATA,
               RGBA_FLOAT32_DATA, RGBA_FLOAT64_DATA, POINT2_SINT16_0_DATA,
               POINT2_SINT16_1_DATA, POINT2_SINT32_0_DATA,
               POINT2_FLOAT32_0_DATA, RECT_SINT16_1_DATA, RECT_SINT32_1_DATA,
               RECT_FLOAT32_1_DATA, RECT_FLOAT32_0_DATA,
               SIGNED_INT64_DATA, UNSIGNED_INT64_DATA, LAST_DATA);

  TDataTypesDec = record
    Key: Integer;
    Value: String;
  end;

  TTriple = record
    Origin: Double;
    PixelSize: Double;
    Units: String;
  end;

  TPrintMessageEvent = procedure(Sender: TObject; Msg: String; MsgType: TMsgDlgType) of Object;

  TSciDM3 = class(TComponent)
  private
    FDebugLevel: Integer;   // 0=none, 1-3=basic, 4-5=simple, 6-10 verbose
    FOutputCharset: String;
    FFileName: String;
    FIsOpen: Boolean;
    FIsParsed: Boolean;
    FAutoParse: Boolean;
    FDataType: TDataType;
    FChosenImage: Integer;
    FTagsTreeView: TTreeView;
    FCurGroupLevel: Integer;
    FCurGroupAtLevelX: Array[0..MAXDEPTH - 1] of Integer;
    FCurGroupNameAtLevelX: Array[0..MAXDEPTH - 1] of String;
    FCurTagAtLevelX: Array[0..MAXDEPTH - 1] of Integer;
    FCurTagName: String;
    FFile: TFileStream;
    FStoredTags: TStringList;
    FTagDict: TStringList;

    FDataReal: TImageData;
    FDataImag: TImageData;

    FOnPrintMessage: TPrintMessageEvent;

    function MakeGroupString: String;
    function MakeGroupNameString: String;
    function ReadTagGroup(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
    function ReadTagEntry(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
    function ReadTagType(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
    function EncodedTypeSize(EncType: Integer): Integer;
    function ReadAnyData(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
    function ReadNativeData(EncodedType, ETSize: Integer): Variant;
    function ReadStringData(StringSize: Integer; TheTree: TTreeView; ParentNode: TTreeNode): String;
    function ReadArrayTypes: TIntegerArray;
    function ReadArrayData(ArrayTypes: TIntegerArray; TheTree: TTreeView; ParentNode: TTreeNode): Integer;
    function ReadStructTypes: TIntegerArray;
    function ReadStructData(StructTypes: TIntegerArray; TheTree: TTreeView; ParentNode: TTreeNode): Integer;
    function StoreTag(TagName: String; TagValue: Variant): String;

    procedure ReadImageData;

    function GetOutputCharset: String;
    procedure SetOutputCharset(const Value: String);

    function GetImage(Index: Integer): TBitmap;
    function GetImageWidth: Integer;
    function GetImageHeight: Integer;
    function GetImageDepth: Integer;
    function GetFileName: String;
    function GetTags: TStringList;
    function GetInfo: TStringList;
    function GetThumbnail: TBitmap;
    function GetThumbnailData: TByteDynArray;

    function GetImageType: Integer;
    function GetLowLimit: Double;
    function GetHighLimit: Double;
    function GetCuts: TPoint;
    function AxisUnits(Index: Integer = 0): TTriple;
    function GetPxSize: TTriple;
    function GetSptUnits: String;

    procedure SetFileName(Value: String);
    procedure SetChosenImage(Value: Integer);
    procedure SetTagsTreeView(Value: TTreeView);

  public
    constructor Create(AOwner: TComponent); override;
    constructor CreateFile(AOwner: TComponent; const AFileName: String; ADebugLevel: Integer = 0);
    destructor Destroy; override;

    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

    procedure ParseDM3(TheTree: TTreeView = Nil);

    function PNGThumbnail: TPortableNetworkGraphic;

    procedure DumpTags(const DumpDir: String);

    // Read-only results of parsing the file, and the actions that produce them.
    property IsOpen: Boolean read FIsOpen;
    property IsParsed: Boolean read FIsParsed;
    property DataType: TDataType read FDataType;
    property Tags: TStringList read GetTags;
    property Info: TStringList read GetInfo;
    property Image[Index: Integer]: TBitmap read GetImage;
    property ImageData: TImageData read FDataReal;
    property ImageWidth: Integer read GetImageWidth;
    property ImageHeight: Integer read GetImageHeight;
    property ImageDepth: Integer read GetImageDepth;
    property Thumbnail: TBitmap read GetThumbnail;
    property ThumbnailData: TByteDynArray read GetThumbnailData;
    property ImageType: Integer read GetImageType;
    property LowLimit: Double read GetLowLimit;
    property HighLimit: Double read GetHighLimit;
    property Cuts: TPoint read GetCuts;
    property Axis[Index: Integer]: TTriple read AxisUnits;
    property PxSize: TTriple read GetPxSize;
    property SptUnits: String read GetSptUnits;

  published
    // Design-time configurable properties.
    property FileName: String read GetFileName write SetFilename;
    property DebugLevel: Integer read FDebugLevel write FDebugLevel default 0;
    property OutputCharset: String read GetOutputCharset write SetOutputCharset;
    // Which image to expose (for multi-image DM3/DM4 files); changing it
    // while a file is already parsed re-reads ImageData for the new index.
    property ChosenImage: Integer read FChosenImage write SetChosenImage default 1;
    // When True, setting FileName at runtime automatically calls ParseDM3.
    property AutoParse: Boolean read FAutoParse write FAutoParse default False;
    // Optional: a TTreeView to populate live with the tag structure while
    // parsing, used whenever ParseDM3 is called without an explicit one.
    property TagsTreeView: TTreeView read FTagsTreeView write SetTagsTreeView;
    property OnPrintMessage: TPrintMessageEvent read FOnPrintMessage write FOnPrintMessage;
  end;

procedure Register;

// Binary data reading functions
// Read 4 bytes as *big endian* LongInt from file F
function ReadLongInt(F: TFileStream): LongInt;
// Read 2 bytes as *big endian* SmallInt from file F
function ReadSmallInt(F: TFileStream): SmallInt;
// Read 1 byte as Byte from file F
function ReadByte(F: TFileStream): Byte;
// Read 1 byte as ShortInt from file F
function ReadShortInt(F: TFileStream): ShortInt;
// Read 1 byte as Boolean from file F
function ReadBool(F: TFileStream): Boolean;
// Read 1 byte as Char from file F
function ReadChar(F: TFileStream): AnsiChar;
// Read Len bytes as a String from file F
function ReadString(F: TFileStream; Len: Integer = 1): String;
// Read Len bytes as a UTF-16LE string from file F, re-encoded into Charset
function ReadUnicodeString(F: TFileStream; Len: Integer = 1; const Charset: String = DEFAULTCHARSET): String;
// Read 2 bytes as *little endian* SmallInt from file F
function ReadLESmallInt(F: TFileStream): SmallInt;
// Read 4 bytes as *little endian* LongInt from file F
function ReadLELongInt(F: TFileStream): LongInt;
// Read 2 bytes as *little endian* Word from file F
function ReadLEWord(F: TFileStream): Word;
// Read 4 bytes as *little endian* Cardinal from file F
function ReadLECardinal(F: TFileStream): LongWord;
// Read 4 bytes as *little endian* Single from file F
function ReadLEFloat(F: TFileStream): Single;
// Read 8 bytes as *little endian* Double from file F
function ReadLEDouble(F: TFileStream): Double;

implementation

// Binary data reading functions

// Read 4 bytes as *big endian* LongInt from file F
function ReadLongInt(F: TFileStream): LongInt;
var
  Buffer: Array[0..3] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Result := (Buffer[0] shl 24) or (Buffer[1] shl 16) or
            (Buffer[2] shl 8) or Buffer[3];
end;

// Read 2 bytes as *big endian* SmallInt from file F
function ReadSmallInt(F: TFileStream): SmallInt;
var
  Buffer: Array[0..1] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Result := (Buffer[0] shl 8) or Buffer[1];
end;

// Read 1 byte as Byte from file F
function ReadByte(F: TFileStream): Byte;
begin
  F.ReadBuffer(Result, SizeOf(Result));
end;

// Read 1 byte as ShortInt from file F
function ReadShortInt(F: TFileStream): ShortInt;
begin
  F.ReadBuffer(Result, SizeOf(Result));
end;

// Read 1 byte as Boolean from file F
function ReadBool(F: TFileStream): Boolean;
begin
  Result := ReadShortInt(F) <> 0;
end;

// Read 1 byte as Char from file F
function ReadChar(F: TFileStream): AnsiChar;
var
  Buffer: Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Result := AnsiChar(Buffer);
end;

// Read Len bytes as a String from file F
function ReadString(F: TFileStream; Len: Integer = 1): String;
var
  Buffer: Array of Byte;
begin
  SetLength(Buffer, Len);
  F.ReadBuffer(Buffer[0], Len);
  SetString(Result, PAnsiChar(@Buffer[0]), Len);
end;

// Read Len bytes as a UTF-16LE string from file F, re-encoded into Charset
function ReadUnicodeString(F: TFileStream; Len: Integer = 1; const Charset: String = DEFAULTCHARSET): String;
var
  Buffer: Array of Byte;
  CodeUnitCount, i: Integer;
  CodePoint, HighSurrogate: Cardinal;

  // Appends the UTF-8 encoding of a single Unicode code point to Result.
  procedure AppendUTF8(CP: Cardinal);
  begin
    if CP <= $7F then
      Result := Result + Chr(CP)
    else if CP <= $7FF then
      Result := Result + Chr($C0 or (CP shr 6)) +
                          Chr($80 or (CP and $3F))
    else if CP <= $FFFF then
      Result := Result + Chr($E0 or (CP shr 12)) +
                          Chr($80 or ((CP shr 6) and $3F)) +
                          Chr($80 or (CP and $3F))
    else
      Result := Result + Chr($F0 or (CP shr 18)) +
                          Chr($80 or ((CP shr 12) and $3F)) +
                          Chr($80 or ((CP shr 6) and $3F)) +
                          Chr($80 or (CP and $3F));
  end;

begin
  Result := '';
  if Len <= 0 then
    Exit;

  SetLength(Buffer, Len);
  F.ReadBuffer(Buffer[0], Len);

  // Len is a byte count; UTF-16 code units are 2 bytes each
  // For an odd Len, simply drop the trailing byte
  CodeUnitCount := Len div 2;

  if not SameText(Charset, 'UTF-8') then
  begin
    // Only UTF-8 is fully implemented
    SetLength(Result, CodeUnitCount);
    for i := 0 to CodeUnitCount - 1 do
      Result[i + 1] := Chr(Buffer[2*i]);
    Exit;
  end;

  i := 0;
  while i < CodeUnitCount do
  begin
    CodePoint := Buffer[2*i] or (Buffer[2*i + 1] shl 8);

    // Combine a UTF-16 surrogate pair into a single code point.
    if (CodePoint >= $D800) and (CodePoint <= $DBFF) and (i + 1 < CodeUnitCount) then
    begin
      HighSurrogate := CodePoint;
      Inc(i);
      CodePoint := Buffer[2*i] or (Buffer[2*i + 1] shl 8);
      CodePoint := $10000 + ((HighSurrogate - $D800) shl 10) + (CodePoint - $DC00);
    end;

    AppendUTF8(CodePoint);
    Inc(i);
  end;
end;

// Read 2 bytes as *little endian* SmallInt from file F
function ReadLESmallInt(F: TFileStream): SmallInt;
var
  Buffer: Array[0..1] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Result := (Buffer[1] shl 8) or Buffer[0];
end;

// Read 4 bytes as *little endian* LongInt from file F
function ReadLELongInt(F: TFileStream): LongInt;
var
  Buffer: Array[0..3] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Result := (Buffer[3] shl 24) or (Buffer[2] shl 16) or
            (Buffer[1] shl 8) or Buffer[0];
end;

// Read 2 bytes as *little endian* Word from file F
function ReadLEWord(F: TFileStream): Word;
var
  Buffer: Array[0..1] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Result := (Buffer[1] shl 8) or Buffer[0];
end;

// Read 4 bytes as *little endian* LongWord from file F
function ReadLECardinal(F: TFileStream): LongWord;
var
  Buffer: Array[0..3] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Result := (Buffer[3] shl 24) or (Buffer[2] shl 16) or
            (Buffer[1] shl 8) or Buffer[0];
end;

// Read 4 bytes as *little endian* Single from file F
function ReadLEFloat(F: TFileStream): Single;
var
  Buffer: Array[0..3] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Move(Buffer[0], Result, SizeOf(Result));
end;

// Read 8 bytes as *little endian* Double from file F
function ReadLEDouble(F: TFileStream): Double;
var
  Buffer: Array[0..7] of Byte;
begin
  F.ReadBuffer(Buffer, SizeOf(Buffer));
  Move(Buffer[0], Result, SizeOf(Result));
end;

// End of binary data reading functions


// TSciDM3 class: parses DM3 file.
constructor TSciDM3.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  // Initialize variables
  FDebugLevel := 0;
  FOutputCharset := DEFAULTCHARSET;
  FFileName := '';
  FChosenImage := 1;
  FAutoParse := False;
  FDataType := NULL_DATA;
  FIsOpen := False;
  FIsParsed := False;

  // Create Tags repositories
  FStoredTags := TStringList.Create;
  FTagDict := TStringList.Create;
  FTagDict.Sorted := True;
end;

// Convenience constructor for creating and opening a file in one call from
// code (e.g. AOwner = Nil for a standalone parser, no need to drop it on a form).
constructor TSciDM3.CreateFile(AOwner: TComponent; const AFileName: String; ADebugLevel: Integer = 0);
begin
  Create(AOwner);
  FDebugLevel := ADebugLevel;
  FileName := AFileName; // goes through the SetFileName property setter
end;

destructor TSciDM3.Destroy;
begin
  SetLength(FDataReal, 0, 0, 0);
  SetLength(FDataImag, 0, 0, 0);

  FFile.Free;
  FStoredTags.Free;
  FTagDict.Free;

  inherited Destroy;
end;

procedure TSciDM3.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and (AComponent = FTagsTreeView) then
    FTagsTreeView := Nil;
end;

function TSciDM3.MakeGroupString: String;
var
  i: Integer;
begin
  Result := IntToStr(FCurGroupAtLevelX[0]);
  for i := 1 to FCurGroupLevel do
    Result := Format('%s.%d', [Result, FCurGroupAtLevelX[i]]);
end;

function TSciDM3.MakeGroupNameString: String;
var
  i: Integer;
begin
  Result := Format('%s', [FCurGroupNameAtLevelX[0]]);
  for i := 1 to FCurGroupLevel do
    Result := Format('%s.%s', [Result, FCurGroupNameAtLevelX[i]]);
end;

function TSciDM3.ReadTagGroup(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
var
  IsGroupSorted, IsGroupOpen: Boolean;
  NumTags, i: Integer;
begin
  // Go down a level
  Inc(FCurGroupLevel);
  if FCurGroupLevel >= MAXDEPTH then
    raise Exception.CreateFmt('%x: Tag group nesting exceeds MAXDEPTH (%d)',
                              [FFile.Position, MAXDEPTH]);
  // Increment group counter
  Inc(FCurGroupAtLevelX[FCurGroupLevel]);
  // Set number of current tag to -1
  FCurTagAtLevelX[FCurGroupLevel] := -1;

  if (DebugLevel > 5) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('rTG: Current Group Level: %d', [FCurGroupLevel]), mtInformation);

  // Is the group sorted?
  IsGroupSorted := ReadBool(FFile);
  // Is the group open?
  IsGroupOpen := ReadBool(FFile);
  // Number of Tags
  NumTags := ReadLongInt(FFile);

  if (DebugLevel > 5) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('rTG: Iterating over the %d tag entries in this group', [NumTags]), mtInformation);

  // Read Tags
  for i := 0 to NumTags - 1 do
    ReadTagEntry(TheTree, ParentNode);
  // Go back up one level as reading group is finished
  Dec(FCurGroupLevel);
  Result := 1;
end;

function TSciDM3.ReadTagEntry(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
var
  IsData: Boolean;
  LenTagLabel: Integer;
  TagLabel: String;
  ChildNode: TTreeNode;
begin
  // Is data or a new group?
  IsData := (ReadShortInt(FFile) = 21);
  Inc(FCurTagAtLevelX[FCurGroupLevel]);
  // Get tag label if exists
  LenTagLabel := ReadSmallInt(FFile);
  if LenTagLabel <> 0 then
    TagLabel := ReadString(FFile, LenTagLabel)
  else
    TagLabel := String(IntToStr(FCurTagAtLevelX[FCurGroupLevel]));

  if assigned(OnPrintMessage) then
    if (DebugLevel > 5) then
      OnPrintMessage(Self, Format('%i | %s:\nTag label = %s', [FCurGroupLevel, MakeGroupString, TagLabel]), mtInformation)
    else if (DebugLevel > 0) then
      OnPrintMessage(Self, Format('%i: Tag label = %s', [FCurGroupLevel, TagLabel]), mtInformation);

  if IsData then
  begin
    // Give it a name
    FCurTagName := Format('%s.%s', [MakeGroupNameString, TagLabel]);
    //Add it to the TTreeView
    if assigned(TheTree) and assigned(ParentNode) then
      ChildNode := TheTree.Items.AddChild(ParentNode, TagLabel);
    // Read it
    ReadTagType(TheTree, ChildNode);
  end
  else
  begin
    // It is a tag group
    if FCurGroupLevel + 1 >= MAXDEPTH then
      raise Exception.CreateFmt('%x: Tag group nesting exceeds MAXDEPTH (%d)',
                                [FFile.Position, MAXDEPTH]);
    FCurGroupNameAtLevelX[FCurGroupLevel + 1] := TagLabel;
    if assigned(TheTree) and assigned(ParentNode) then
      ChildNode := TheTree.Items.AddChild(ParentNode, TagLabel);
    ReadTagGroup(TheTree, ChildNode); // Increments FCurGroupLevel
  end;
  Result := 1;
end;

function TSciDM3.ReadTagType(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
var
  Delim: String;
  NumInTag: LongInt;
begin
  Delim := ReadString(FFile, 4);
  if Delim <> '%%%%' then
    raise Exception.Create(Format('%x: Tag Type delimiter not %%%%', [FFile.Position]));
  NumInTag := ReadLongInt(FFile);
  ReadAnyData(TheTree, ParentNode);
  Result := 1;
end;

function TSciDM3.EncodedTypeSize(EncType: Integer): Integer;
begin
  case EncType of
    0: Result := 0;
    BOOLEAN_DATA, CHAR_DATA, OCTET_DATA: Result := 1;
    SHORT_DATA, USHORT_DATA: Result := 2;
    LONG_DATA, ULONG_DATA, FLOAT_DATA: Result := 4;
    DOUBLE_DATA: Result := 8;
  else
    Result := -1; // Unrecognized types
  end;
end;

function TSciDM3.ReadAnyData(TheTree: TTreeView; ParentNode: TTreeNode): Integer;
var
  EncodedType,
  StringSize: Integer;
  ArrayTypes,
  StructTypes: TIntegerArray;
  ETSize: Integer;
  S: String;
begin
  // Higher level function dispatching to handling data types to other functions
  // Get Type category (short, long, array...)
  EncodedType := ReadLongInt(FFile);
  // Calc size of EncodedType
  ETSize := EncodedTypeSize(EncodedType);

  if (DebugLevel > 5) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('rAnD, %x:\tTag Type = %d\tTag Size = %d',
                                [FFile.Position, EncodedType, ETSize]), mtInformation);

  if ETSize > 0 then
  begin
    S := StoreTag(FCurTagName, ReadNativeData(EncodedType, ETSize));
    // Add the Tag value to the TTreeView
    if assigned(TheTree) and assigned(ParentNode) then
      TheTree.Items.AddChild(ParentNode, S);
  end
  else
    case EncodedType of
      STRING_DATA: begin
        StringSize := ReadLongInt(FFile);
        ReadStringData(StringSize, TheTree, ParentNode);
      end;
      STRUCT_DATA: begin
        // Does not store tags yet
        StructTypes := ReadStructTypes;
        ReadStructData(StructTypes, TheTree, ParentNode)
      end;
      ARRAY_DATA: begin
        // Does not store tags yet
        // Indicates size of skipped data blocks
        ArrayTypes := ReadArrayTypes;
        ReadArrayData(ArrayTypes, TheTree, ParentNode);
      end;
      else
        raise Exception.Create(Format('rAnD, %x: Can''t understand encoded type', [FFile.Position]));
    end;

  Result := 1;
end;

function TSciDM3.ReadNativeData(EncodedType: Integer; ETSize: Integer): Variant;
begin
  // Reads ordinary data types
  case EncodedType of
    SHORT_DATA: Result := ReadLESmallInt(FFile);
    LONG_DATA: Result := ReadLELongInt(FFile);
    USHORT_DATA: Result := ReadLEWord(FFile);
    ULONG_DATA: Result := ReadLECardinal(FFile);
    FLOAT_DATA: Result := ReadLEFloat(FFile);
    DOUBLE_DATA: Result := ReadLEDouble(FFile);
    BOOLEAN_DATA: Result := ReadBool(FFile);
    CHAR_DATA: Result := ReadChar(FFile);
    OCTET_DATA: Result := ReadChar(FFile); // Difference with char???
   else
      raise Exception.CreateFmt('rND, %x: Unknown data type %d',
                                [FFile.Position, EncodedType]);
  end;

  if assigned(OnPrintMessage) then
    if DebugLevel > 3 then
      OnPrintMessage(Self, Format('rND, %x: %s', [FFile.Position, VarToStr(Result)]), mtInformation)
    else if DebugLevel > 0 then
      OnPrintMessage(Self, VarToStr(Result), mtInformation);
end;

function TSciDM3.ReadStringData(StringSize: Integer; TheTree: TTreeView; ParentNode: TTreeNode): String;
begin
  if StringSize <= 0 then
    Result := ''
  else
  begin
    if (DebugLevel > 3) and assigned(OnPrintMessage) then
      OnPrintMessage(Self, Format('rSD @ %s/%x:', [IntToStr(FFile.Position), FFile.Position]), mtInformation);

    Result := ReadUnicodeString(FFile, StringSize, FOutputCharset);
    //Result := ReadString(FFile, StringSize);

    if (DebugLevel > 3) and assigned(OnPrintMessage) then
      OnPrintMessage(Self, Result + '   <' + Result + '>', mtInformation);
  end;

  if (DebugLevel > 0) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, 'StringVal: ' + Result, mtInformation);

  StoreTag(FCurTagName, Result);
  // Finally, add the value to the TTreeView
  if assigned(TheTree) and assigned(ParentNode) then
    TheTree.Items.AddChild(ParentNode, Result);
end;

function TSciDM3.ReadArrayTypes: TIntegerArray;
var
  ArrayType: Integer;
begin
  // Determines the data types in an array data type
  ArrayType := ReadLongInt(FFile);
  SetLength(Result, 0);

  case ArrayType of
    STRUCT_DATA: Result := ReadStructTypes;
    ARRAY_DATA: Result := ReadArrayTypes;
    else
    begin
      SetLength(Result, 1);
      Result[0] := ArrayType;
    end;
  end;
end;

function TSciDM3.ReadArrayData(ArrayTypes: TIntegerArray; TheTree: TTreeView; ParentNode: TTreeNode): Integer;
var
  ArraySize, ItemSize, EncodedType, ETSize, BufSize, i: Integer;
  S1, S2: String;
  ChildNode: TTreeNode;
begin
  // Reads array data
  ArraySize := ReadLongInt(FFile);

  if (DebugLevel > 3) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('rArD, %x: Reading array of size = %d', [FFile.Position, ArraySize]), mtInformation);

  ItemSize := 0;
  EncodedType := 0;

  for i := 0 to High(ArrayTypes) do
  begin
    EncodedType := ArrayTypes[i];
    ETSize := EncodedTypeSize(EncodedType);
    Inc(ItemSize, ETSize);
    if (DebugLevel > 5) and assigned(OnPrintMessage) then
      OnPrintMessage(Self, Format('rArD: Tag Type = %d\tTag Size = %d', [EncodedType, ETSize]), mtInformation);
  end;

  if (DebugLevel > 5) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('rArD: Array Item Size = %d', [ItemSize]), mtInformation);

  BufSize := ArraySize*ItemSize;

  if (not FCurTagName.EndsWith('ImageData.Data')) and (Length(ArrayTypes) = 1) and
     (EncodedType = USHORT_DATA) and (ArraySize < 256) then
  begin
    // Treat as String
    ReadStringData(BufSize, TheTree, ParentNode);
  end
  else
  begin
    // Treat as binary data
    // Store data size and offset as tags
    S1 := StoreTag(FCurTagName + '.Size', BufSize);
    S2 := StoreTag(FCurTagName + '.Offset', FFile.Position);
    // Skip data w/o reading
    FFile.Seek(BufSize, soFromCurrent);
    // Add info to TTreeView
    if assigned(TheTree) and assigned(ParentNode) then
    begin
      ChildNode := TheTree.Items.AddChild(ParentNode, 'Size');
      TheTree.Items.AddChild(ChildNode, S1);
      ChildNode := TheTree.Items.AddChild(ParentNode, 'Offset');
      TheTree.Items.AddChild(ChildNode, S2);
    end;
  end;

  Result := 1;
end;

function TSciDM3.ReadStructTypes: TIntegerArray;
var
  StructNameLength, NumFields, NameLength, FieldType, i: Integer;
begin
  // Analyzes data types in a struct

  if (DebugLevel > 3) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('Reading Struct Types at Pos = %x', [FFile.Position]), mtInformation);

  StructNameLength := ReadLongInt(FFile);
  NumFields := ReadLongInt(FFile);

  if (DebugLevel > 5) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('NumFields = %d', [NumFields]), mtInformation);

  if NumFields > 100 then
    raise Exception.CreateFmt('%x: Too many fields', [FFile.Position]);

  SetLength(Result, NumFields);
  for i := 0 to NumFields - 1 do
  begin
    NameLength := ReadLongInt(FFile);
    if (DebugLevel > 9) and assigned(OnPrintMessage) then
      OnPrintMessage(Self, Format('%dth NameLength = %d', [i, NameLength]), mtInformation);
    // Struct fields are normally unnamed (NameLength = 0) in DM3 files, but
    // skip over any name bytes if present so the stream stays in sync
    // instead of silently misreading everything that follows.
    if NameLength > 0 then
    begin
      if assigned(OnPrintMessage) then
        OnPrintMessage(Self, Format('%x: Unexpected named struct field (length %d), skipping name.',
                                    [FFile.Position, NameLength]), mtWarning);
      FFile.Seek(NameLength, soFromCurrent);
    end;
    FieldType := ReadLongInt(FFile);
    Result[i] := FieldType;
  end;
end;

function TSciDM3.ReadStructData(StructTypes: TIntegerArray; TheTree: TTreeView; ParentNode: TTreeNode): Integer;
var
  i, EncodedType, ETSize: Integer;
  S: String;
begin
  // Reads struct data based on type info in StructType
  for i := 0 to High(StructTypes) do
  begin
    EncodedType := StructTypes[i];
    ETSize := EncodedTypeSize(EncodedType);

    if (DebugLevel > 5) and assigned(OnPrintMessage) then
      OnPrintMessage(Self, Format('Tag Type = %d\tTag Size = %d', [EncodedType, ETSize]), mtInformation);

    // Get data
    //ReadNativeData(EncodedType, ETSize);
    S := StoreTag(FCurTagName, ReadNativeData(EncodedType, ETSize));
    // Add the Tag value to the TTreeView
    if assigned(TheTree) and assigned(ParentNode) then
      TheTree.Items.AddChild(ParentNode, S);
  end;

  Result := 1;
end;

function TSciDM3.StoreTag(TagName: String; TagValue: Variant): String;
begin
  // Convert tag value to String if it is not already
  case VarType(TagValue) of
    varInteger: Result := IntToStr(TagValue);
    varDouble: Result := FloatToStr(TagValue);
    varBoolean: Result := BoolToStr(TagValue, True);
    else
      Result := VarToStr(TagValue);
  end;

  // Store Tags as StringList
  if (DebugLevel > 5) and assigned(OnPrintMessage) then
    OnPrintMessage(Self, Format('%s = %s', [TagName,  Result]), mtInformation);

  FStoredTags.Add(Format('%s = %s', [TagName, Result]));
  FTagDict.AddPair(TagName, Result);
end;

function TSciDM3.GetOutputCharset: String;
begin
  Result := FOutputCharset;
end;

procedure TSciDM3.SetOutputCharset(const Value: String);
begin
  FOutputCharset := Value;
end;

procedure TSciDM3.SetFileName(Value: String);
begin
  if (Value <> FFileName) then
  begin
    FFileName := Value;
    FIsParsed := False;

    // Don't touch the filesystem while the component is being placed/edited
    // on a form in the IDE - only open the file at run time.
    if (csDesigning in ComponentState) then
      Exit;

    if assigned(FFile) then
      FreeAndNil(FFile);

    // Open file for reading
    if FileExists(FFileName) then
    begin
      FFile := TFileStream.Create(FFileName, fmOpenRead or fmShareDenyWrite);
      FIsOpen := True;
    end
    else
      FIsOpen := False;

    if FAutoParse and FIsOpen then
      ParseDM3(FTagsTreeView);
  end;
end;

procedure TSciDM3.SetChosenImage(Value: Integer);
begin
  if (Value <> FChosenImage) then
  begin
    FChosenImage := Value;
    // Re-read pixel data for the newly selected image, if we already have a
    // parsed tag tree to read it from.
    if IsOpen and IsParsed then
      ReadImageData;
  end;
end;

procedure TSciDM3.SetTagsTreeView(Value: TTreeView);
begin
  if (FTagsTreeView <> Value) then
  begin
    if assigned(FTagsTreeView) then
      FTagsTreeView.RemoveFreeNotification(Self);
    FTagsTreeView := Value;
    if assigned(FTagsTreeView) then
      FTagsTreeView.FreeNotification(Self);
  end;
end;

function TSciDM3.GetImage(Index: Integer): TBitmap;
var
  i, j, w, h: Integer;
  c: Byte;
  data, ll, hl: Double;
  TempIntfImage: TLazIntfImage;
begin
  Result := Nil;
  if IsOpen and IsParsed then
  begin
    if (Index < 0) or (Index >= ImageDepth) then
      raise Exception.CreateFmt('Image index %d out of range (0..%d)', [Index, ImageDepth - 1]);

    w := ImageWidth;
    h := ImageHeight;
    ll := LowLimit;
    hl := HighLimit;

    Result := TBitmap.Create;
    Result.Width := w;
    Result.Height := h;

    TempIntfImage := Result.CreateIntfImage;

    for i := 0 to w - 1 do
    begin
      for j := 0 to h - 1 do
      begin
        if DataType in [COMPLEX8_DATA, PACKED_DATA, COMPLEX16_DATA] then
          // The tiny epsilon avoids Ln(0) = -Infinity for an exactly-zero complex value.
          data := Ln(Sqrt(Power(ImageData[i, j, Index], 2) +
                          Power(FDataImag[i, j, Index], 2)) + 1e-30)
        else
          data := ImageData[i, j, Index];

        if (data <= ll) then
          c := 0
        else if (data >= hl) then
          c := 255
        else
          c := Round(255*(data - ll)/(hl - ll));

        TempIntfImage.Colors[i, j] := TColorToFPColor(RGBToColor(c, c, c));
        //Result.BeginUpdate(True);
        //Result.Canvas.Pixels[i, j] := RGBToColor(c, c, c);
        //Result.EndUpdate(False);
      end;
    end;

    Result.LoadFromIntfImage(TempIntfImage);
  end;
end;

function TSciDM3.GetImageWidth: Integer;
begin
  Result := Length(FDataReal);
end;

function TSciDM3.GetImageHeight: Integer;
begin
  Result := 0;
  if (Length(FDataReal) > 0) then
    Result := Length(FDataReal[0]);
end;

function TSciDM3.GetImageDepth: Integer;
begin
  Result := 0;
  if (Length(FDataReal) > 0) and (Length(FDataReal[0]) > 0) then
    Result := Length(FDataReal[0, 0]);
end;

function TSciDM3.GetFileName: String;
begin
  Result := FFileName;
end;

function TSciDM3.GetTags: TStringList;
begin
  Result := FTagDict;
end;

procedure TSciDM3.ParseDM3(TheTree: TTreeView = Nil);
var
  FileVersion, FileSize: Integer;
  LittleEndian: Boolean;
  t1, t2: TDateTime;
  StartNode : TTreeNode;
begin
  // Fall back to the design-time linked TagsTreeView, if any, when the
  // caller didn't pass one explicitly.
  if not assigned(TheTree) then
    TheTree := FTagsTreeView;

  if IsOpen then
  begin
    FStoredTags.Clear;
    FTagDict.Clear;

    // Track currently read group
    FCurGroupLevel := -1;
    FillChar(FCurGroupAtLevelX, SizeOf(FCurGroupAtLevelX), 0);
    FillChar(FCurGroupNameAtLevelX, SizeOf(FCurGroupNameAtLevelX), 0);

    // Track current tag
    FillChar(FCurTagAtLevelX, SizeOf(FCurTagAtLevelX), 0);
    FCurTagName := '';

    if (DebugLevel > 0) then t1 := Now;

    // Read header (first 3 4-byte int)
    // Get version
    FileVersion := ReadLongInt(FFile);
    // Get indicated file size
    FileSize := ReadLongInt(FFile);
    // Get byte-ordering
    LittleEndian := (ReadLongInt(FFile) = 1);

    // Check file header, raise Exception if not DM3
    if (FileVersion <> 3) or not LittleEndian then
      raise Exception.Create(Format('"%s" does not appear to be a DM3 file.', [ExtractFileName(FFileName)]))
    else if (DebugLevel > 0) and assigned(OnPrintMessage) then
      OnPrintMessage(Self, Format('"%s" appears to be a DM3 file', [FFileName]), mtInformation);

    if (DebugLevel > 5) and assigned(OnPrintMessage) then
    begin
      OnPrintMessage(Self, 'Header info.:', mtInformation);
      OnPrintMessage(Self, Format('  -File version: %d', [FileVersion]), mtInformation);
      OnPrintMessage(Self, Format('  -Little Endian: %s', [BoolToStr(LittleEndian, True)]), mtInformation);
      OnPrintMessage(Self, Format('  -File size: %d bytes', [FileSize]), mtInformation);
    end;

    // Set name of root group (contains all data)...
    FCurGroupNameAtLevelX[0] := 'root';
    //Populate the TTreeView
    if assigned(TheTree) then
      StartNode := TheTree.Items.AddFirst(Nil, ExtractFileName(FFileName));
    // Read it
    ReadTagGroup(TheTree, StartNode);

    if (DebugLevel > 0) and assigned(OnPrintMessage) then
      OnPrintMessage(Self, Format('-- %d Tags read --', [FStoredTags.Count]), mtInformation);

    // Finally, read image data
    ReadImageData;

    if (DebugLevel > 0) and assigned(OnPrintMessage) then
    begin
      t2 := Now;
      OnPrintMessage(Self, Format('| parse DM3 file: %.3g s', [t2 - t1]), mtInformation);
    end;

    FIsParsed := True;
  end;
end;

procedure TSciDM3.DumpTags(const DumpDir: String);
var
  DumpFile: String;
  F: TextFile;
  ATag: String;
begin
  if IsOpen and IsParsed then
  begin
    DumpFile := IncludeTrailingPathDelimiter(DumpDir) + ExtractFileName(FFileName) + '.tagdump.txt';
    try
      AssignFile(F, DumpFile);
      Rewrite(F);
      try
        for ATag in FStoredTags do
          WriteLn(F, ATag);
      finally
        CloseFile(F);
      end;
    except
      on E: Exception do
        if assigned(OnPrintMessage) then
          OnPrintMessage(Self, Format('Cannot generate dump file. Error: "%s"', [E.Message]), mtWarning);
    end;
  end;
end;

// Extracts useful experiment info from DM3 file.
function TSciDM3.GetInfo: TStringList;
  procedure AddItem(TagKey, TagName: String);
  begin
    if tags.IndexOfName(TagName) > -1 then
      Result.AddPair(TagKey, Tags.Values[TagName]);
  end;

var
  TagRoot,
  BarTag,
  MicTag: String;
begin
  if IsOpen and IsParsed then
  begin
    // Define useful information
    TagRoot := 'root.ImageList.1';
    BarTag := Format('%s.ImageTags.DataBar', [TagRoot]);
    MicTag := Format('%s.ImageTags.Microscope Info', [TagRoot]);

    // Get experiment information
    Result := TStringList.Create;
    Result.Clear;

    AddItem('descrip', Format('%s.Description', [TagRoot]));
    AddItem('acq_date', Format('%s.Acquisition Date', [BarTag]));
    AddItem('acq_time', Format('%s.Acquisition Time', [BarTag]));
    AddItem('name', Format('%s.Name', [MicTag]));
    AddItem('micro', Format('%s.Microscope', [MicTag]));
    AddItem('hv', Format('%s.Voltage', [MicTag]));
    AddItem('mag', Format('%s.Indicated Magnification', [MicTag]));
    AddItem('mode', Format('%s.Operation Mode', [MicTag]));
    AddItem('operator', Format('%s.Operator', [MicTag]));
    AddItem('specimen', Format('%s.Specimen', [MicTag]));
  end;
end;

procedure TSciDM3.ReadImageData;
var
  i, j, k: Integer;
  ImWidth, ImHeight, ImDepth: Integer;
  DataOffset, DataSize, PixelDepth: Integer;
  TagRoot: String;
  TmpImage: TImageData;
begin
  if IsOpen then
  begin
    TagRoot := Format('root.ImageList.%d.ImageData', [ChosenImage]);

    DataOffset := StrToInt(Tags.Values[TagRoot + '.Data.Offset']);
    DataSize := StrToInt(Tags.Values[TagRoot + '.Data.Size']);
    FDataType := TDataType(StrToInt(Tags.Values[TagRoot + '.DataType']));
    PixelDepth := StrToInt(Tags.Values[TagRoot + '.PixelDepth']);
    ImWidth := StrToInt(Tags.Values[TagRoot + '.Dimensions.0']);

    if Tags.IndexOfName(TagRoot + '.Dimensions.1') > -1 then
      ImHeight := StrToInt(Tags.Values[TagRoot + '.Dimensions.1'])
    else
      ImHeight := 1;

    if Tags.IndexOfName(TagRoot + '.Dimensions.2') > -1 then
      ImDepth := StrToInt(Tags.Values[TagRoot + '.Dimensions.2'])
    else
      ImDepth := 1;

    if DataSize <> PixelDepth*ImWidth*ImHeight*ImDepth then
      raise Exception.Create('Actual data size does not match the expected size.');

    SetLength(FDataReal, ImWidth, ImHeight, ImDepth);

    if (DebugLevel > 0) and assigned(OnPrintMessage) then
    begin
      OnPrintMessage(Self, Format('Image data in "%s" starts at %X', [ExtractFileName(FFileName), DataOffset]), mtInformation);
      OnPrintMessage(Self, Format('Image size: %d px, %d px', [ImageWidth, ImageHeight]), mtInformation);

      OnPrintMessage(Self, Format('Image data type: %d read as %s.', [DataType, DataTypes[Integer(DataType)]]), mtInformation);
    end;

    FFile.Position := DataOffset;

    // Check if image DataType is implemented, then read it
    case DataType of
      // 16-bit LE signed integer (SmallInt, LE)
      SIGNED_INT16_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadLESmallInt(FFile);
      end;

      // 32-bit LE floating point (Single, LE)
      REAL4_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadLEFloat(FFile);
      end;

      // 64-bit LE complex floating point (Two Singles, LE)
      COMPLEX8_DATA: begin
        SetLength(FDataImag, ImWidth, ImHeight, ImDepth);

        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
            begin
              FDataReal[i, j, k] := ReadLEFloat(FFile);
              FDataImag[i, j, k] := ReadLEFloat(FFile);
            end;
      end;

      // 32-bit LE packed complex (FFT)
      PACKED_DATA: begin
        try
          SetLength(FDataImag, ImWidth, ImHeight, ImDepth);
          SetLength(TmpImage, ImWidth, ImHeight, ImDepth);

          for i := 0 to ImWidth - 1 do
            for j := 0 to ImHeight - 1 do
              for k := 0 to ImDepth - 1 do
              begin
                TmpImage[i, j, k] := ReadLEFloat(FFile);
                FDataReal[i, j, k] := 1.0;
              end;

          for i := 0 to ImWidth - 1 do
            for j := (1 + ImHeight div 2) to ImHeight - 1 do
              for k := 0 to ImDepth - 1 do
              begin
                FDataReal[i, j, k] := TmpImage[i, 2*(j - ImHeight div 2), k];
                FDataImag[i, j, k] := TmpImage[i, 2*(j - ImHeight div 2) + 1, k];
              end;

          for i := 0 to ImWidth - 1 do
            for j := 1 to (ImHeight div 2) - 1 do
              for k := 0 to ImDepth - 1 do
              begin
                FDataReal[i, j, k] := FDataReal[ImWidth - 1 - i, ImHeight - j, k];
                FDataImag[i, j, k] := -FDataImag[ImWidth - 1 - i, ImHeight - j, k]
              end;

          for i := (1 + ImWidth div 2) to ImWidth - 1 do
            for k := 0 to ImDepth - 1 do
            begin
              FDataReal[i, 0, k] := TmpImage[i - ImWidth div 2, 0, k];
              FDataImag[i, 0, k] := TmpImage[i - ImWidth div 2, 1, k];
            end;

          for i := 1 to (ImWidth div 2) - 1 do
            for k := 0 to ImDepth - 1 do
            begin
              FDataReal[i, 0, k] := FDataReal[ImWidth - i, 0, k];
              FDataImag[i, 0, k] := -FDataImag[ImWidth - i, 0, k];
            end;

          for i := (1 + ImWidth div 2) to ImWidth - 1 do
            for k := 0 to ImDepth - 1 do
            begin
              FDataReal[i, ImHeight div 2, k] := TmpImage[i, 0, k];
              FDataImag[i, ImHeight div 2, k] := TmpImage[i, 1, k];
            end;

          for i := 1 to (ImWidth div 2) - 1 do
            for k := 0 to ImDepth - 1 do
            begin
              FDataReal[i, ImHeight div 2, k] := FDataReal[ImWidth - i, ImHeight div 2, k];
              FDataImag[i, ImHeight div 2, k] := -FDataImag[ImWidth - i, ImHeight div 2, k];
            end;

          for k := 0 to ImDepth - 1 do
          begin
            FDataReal[0, 0, k] := TmpImage[0, 1, k];
            FDataImag[0, 0, k] := 0.0;

            FDataReal[ImWidth div 2, 0, k] := TmpImage[0, 0, k];
            FDataImag[ImWidth div 2, 0, k] := 0.0;

            FDataReal[0, ImHeight div 2, k] := TmpImage[ImWidth div 2, 1, k];
            FDataImag[0, ImHeight div 2, k] := 0.0;

            FDataReal[ImWidth div 2, ImHeight div 2, k] := TmpImage[ImWidth div 2, 0, k];
            FDataImag[ImWidth div 2, ImHeight div 2, k] := 0.0;
          end;
        finally
          SetLength(TmpImage, 0, 0, 0);
        end;
      end;

      // 8-bit unsigned integer (Byte)
      UNSIGNED_INT8_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadByte(FFile);
      end;

      // 32-bit LE signed integer (LongInt, LE)
      SIGNED_INT32_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadLELongInt(FFile);
      end;

      // 8-bit signed integer (ShorInt)
      SIGNED_INT8_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadShortInt(FFile);
      end;

      // 16-bit LE unsigned integer (Word, LE)
      UNSIGNED_INT16_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadLEWord(FFile);
      end;

      // 32-bit LE unsigned integer (Cardinal, LE)
      UNSIGNED_INT32_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadLECardinal(FFile);
      end;

      // 64-bit LE floating point (Double, LE)
      REAL8_DATA: begin
        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
              FDataReal[i, j, k] := ReadLEDouble(FFile);
      end;

      // 128-bit LE complex floating point (Two Doubles, LE)
      COMPLEX16_DATA: begin
        SetLength(FDataImag, ImWidth, ImHeight, ImDepth);

        for i := 0 to ImWidth - 1 do
          for j := 0 to ImHeight - 1 do
            for k := 0 to ImDepth - 1 do
            begin
              FDataReal[i, j, k] := ReadLEDouble(FFile);
              FDataImag[i, j, k] := ReadLEDouble(FFile);
            end;
      end;
      else
        raise Exception.CreateFmt('Cannot extract image data from "%s": unimplemented DataType (%s).',
                                  [ExtractFileName(FFileName), DataTypes[Integer(DataType)]]);
    end;
  end;
end;

function TSciDM3.GetThumbnail: TBitmap;
var
  TagRoot: String;
  TnSize, TnOffset, TnWidth, TnHeight: Integer;
  RawData: TBytes;
begin
  Result := Nil;
  if IsOpen and IsParsed then
  begin
    TagRoot := 'root.ImageList.0.ImageData';
    TnSize := StrToInt(FTagDict.Values[TagRoot + '.Data.Size']);
    TnOffset := StrToInt(FTagDict.Values[TagRoot + '.Data.Offset']);
    TnWidth := StrToInt(FTagDict.Values[TagRoot + '.Dimensions.0']);
    TnHeight := StrToInt(FTagDict.Values[TagRoot + '.Dimensions.1']);

    if (DebugLevel > 0) and assigned(OnPrintMessage) then
    begin
      OnPrintMessage(Self, Format('Thumbnail data in "%s" starts at %X', [ExtractFileName(FFileName), TnOffset]), mtInformation);
      OnPrintMessage(Self, Format('Thumbnail size: %d px, %d px', [TnWidth, TnHeight]), mtInformation);
    end;

    if (TnWidth*TnHeight*4) <> TnSize then
      raise Exception.Create('Cannot extract thumbnail from ' + ExtractFileName(FFileName))
    else
    begin
      FFile.Position := TnOffset;
      SetLength(RawData, TnSize);
      FFile.ReadBuffer(RawData[0], TnSize);

      Result := TBitmap.Create;
      try
        Result.Width := TnWidth;
        Result.Height := TnHeight;
        Result.PixelFormat := pf16bit;
        //Move(RawData[0], Result.ScanLine[0]^, TnSize);
        Move(RawData[0], Result.RawImage.Data[0], TnSize);
      except
        Result.Free;
        raise;
      end;
    end;
  end;
end;

function TSciDM3.GetThumbnailData: TByteDynArray;
var
  BmpThumbnail: TBitmap;
begin
  SetLength(Result, 0);
  if IsOpen and IsParsed then
  begin
    BmpThumbnail := GetThumbnail;
    try
      SetLength(Result, BmpThumbnail.Width*BmpThumbnail.Height*2);
      //Move(BmpThumbnail.ScanLine[0]^, Result[0], Length(Result));
      Move(BmpThumbnail.RawImage.Data[0], Result[0], Length(Result));
    finally
      BmpThumbnail.Free;
    end;
  end;
end;

function TSciDM3.PNGThumbnail: TPortableNetworkGraphic;
var
  BmpThumbnail: TBitmap;
begin
  Result := Nil;
  if IsOpen and IsParsed then
  begin
    try
      BmpThumbnail := GetThumbnail;
      try
        Result := TPortableNetworkGraphic.Create;
        Result.Assign(BmpThumbnail);
      finally
        BmpThumbnail.Free;
      end;
    except
      on E: Exception do
        if assigned(OnPrintMessage) then
          OnPrintMessage(Self, Format('Could not save thumbnail. Error: "%s".', [E.Message]), mtWarning);
    end;
  end;
end;

function TSciDM3.GetImageType: Integer;
var
  TagName: String;
begin
  Result := -1;
  if IsOpen and IsParsed then
  begin
    TagName := Format('root.ImageList.%d.ImageData.DataType', [ChosenImage]);
    if Tags.IndexOfName(TagName) > -1 then
      Result := StrToInt(Tags.Values[TagName]);
  end;
end;

function TSciDM3.GetLowLimit: Double;
const
  TagName = 'root.DocumentObjectList.0.ImageDisplayInfo.LowLimit';
var
  i, j, k: Integer;
begin
  Result := 0;
  if IsOpen and IsParsed then
  begin
    if Tags.IndexOfName(TagName) > -1 then
      Result := StrToFloat(Tags.Values[TagName])
    else if (Length(FDataReal) > 0) and (Length(FDataReal[0]) > 0) and
            (Length(FDataReal[0, 0]) > 0) then
    begin
      Result := FDataReal[0, 0, 0];
      for i := Low(FDataReal) to High(FDataReal) do
        for j := Low(FDataReal[i]) to High(FDataReal[i]) do
          for k := Low(FDataReal[i, j]) to High(FDataReal[i, j]) do
            if (FDataReal[i, j, k] < Result) then
              Result := FDataReal[i, j, k];
    end;
  end;
end;

function TSciDM3.GetHighLimit: Double;
const
  TagName = 'root.DocumentObjectList.0.ImageDisplayInfo.HighLimit';
var
  i, j, k: Integer;
begin
  Result := 0;
  if IsOpen and IsParsed then
  begin
    if Tags.IndexOfName(TagName) > -1 then
      Result := StrToFloat(Tags.Values[TagName])
    else if (Length(FDataReal) > 0) and (Length(FDataReal[0]) > 0) and
            (Length(FDataReal[0, 0]) > 0) then
    begin
      Result := FDataReal[0, 0, 0];
      for i := Low(FDataReal) to High(FDataReal) do
        for j := Low(FDataReal[i]) to High(FDataReal[i]) do
          for k := Low(FDataReal[i, j]) to High(FDataReal[i, j]) do
            if (FDataReal[i, j, k] > Result) then
              Result := FDataReal[i, j, k];
    end;
  end;
end;

function TSciDM3.GetCuts: TPoint;
begin
  Result := TPoint.Create(0, 0);
  if IsOpen and IsParsed then
    Result := TPoint.Create(Round(LowLimit), Round(HighLimit));
end;

function TSciDM3.AxisUnits(Index: Integer = 0): TTriple;
var
  TagRoot: String;
begin
  Result.Origin := 0;
  Result.PixelSize := 0;
  Result.Units := '';

  if IsOpen and IsParsed then
  begin
    TagRoot := Format('root.ImageList.%d.ImageData.Calibrations.Dimension.%d', [ChosenImage, Index]);

    with Result do
    begin
      if Tags.IndexOfName(TagRoot + '.Origin') > -1 then
        Origin := StrToFloat(Tags.Values[TagRoot + '.Origin']);
      if Tags.IndexOfName(TagRoot + '.Scale') > -1 then
        PixelSize := StrToFloat(Tags.Values[TagRoot + '.Scale']);
      if Tags.IndexOfName(TagRoot + '.Units') > -1 then
        Units := Tags.Values[TagRoot + '.Units'];
    end;

    if (DebugLevel > 0) and assigned(OnPrintMessage) then
        OnPrintMessage(Self, Format('Pixel size = %f %s', [Result.PixelSize, Result.Units]), mtInformation);
  end;
end;

function TSciDM3.GetPxSize: TTriple;
begin
  Result.Origin := 0;
  Result.PixelSize := 0;
  Result.Units := '';
  if IsOpen and IsParsed then
    Result := AxisUnits(0);
end;

function TSciDM3.GetSptUnits: String;
var
  TagName: String;
begin
  Result := '';
  if IsOpen and IsParsed then
  begin
    TagName := Format('root.ImageList.%d.ImageData.Calibrations.Brightness.Units', [ChosenImage]);
    if Tags.IndexOfName(TagName) > -1 then
      Result := Tags.Values[TagName];
  end;
end;

procedure Register;
begin
  RegisterComponents('Science', [TSciDM3]);
end;

end.

