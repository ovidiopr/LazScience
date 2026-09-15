//========================================================================//
//                                                                        //
//  uSciDM3Connector.pas                                                  //
//                                                                        //
//  GUI-only companion to TSciDM3; this unit provides the visual          //
//  presentation (a live tag TTreeView and a rendered image control) as   //
//  a separate non-visual component, TSciDM3Connector, that you drop      //
//  alongside a TSciDM3 and link to it plus the UI controls.              //
//                                                                        //
//  Neither link is required: use TreeView only, ImageControl only, or    //
//  both.                                                                 //
//                                                                        //
//  ImageControl accepts any TGraphicControl descendant (TImage,          //
//  TPaintBox, …). TImage is handled by assigning to Picture.Bitmap;      //
//  all other TGraphicControl descendants receive the bitmap via           //
//  OnPaint + Canvas.Draw.                                                 //
//                                                                        //
//  2026-09-14 First version (Ovidio)                                     //
//                                                                        //
//========================================================================//

unit uSciDM3Connector;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ComCtrls, ExtCtrls, Graphics, IntfGraphics,
  uSciDM3;

type
  TDM3ColorScheme = (csGrayscale, csInverted);

  { TSciDM3Connector }

  TSciDM3Connector = class(TComponent)
  private
    FDM3: TSciDM3;
    FTreeView: TTreeView;
    FImageControl: TGraphicControl;
    FCachedBitmap: TBitmap;
    FAutoRefresh: Boolean;
    FColorScheme: TDM3ColorScheme;
    FSliceIndex: Integer;

    procedure SetDM3(Value: TSciDM3);
    procedure SetTreeView(Value: TTreeView);
    procedure SetImageControl(Value: TGraphicControl);
    procedure SetColorScheme(Value: TDM3ColorScheme);
    procedure SetSliceIndex(Value: Integer);

    procedure DM3DataChanged(Sender: TObject);

    procedure RenderToControl;
    procedure SetOnPaint(AControl: TGraphicControl; AHandler: TNotifyEvent);
    procedure OnImageControlPaint(Sender: TObject);

    procedure RefreshTree;
    procedure RefreshImage;

  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    // Rebuilds TreeView and/or ImageControl
    procedure Refresh;

  published
    property DM3: TSciDM3 read FDM3 write SetDM3;
    property TreeView: TTreeView read FTreeView write SetTreeView;
    property ImageControl: TGraphicControl read FImageControl write SetImageControl;
    property AutoRefresh: Boolean read FAutoRefresh write FAutoRefresh default True;
    property ColorScheme: TDM3ColorScheme read FColorScheme write SetColorScheme default csGrayscale;
    property SliceIndex: Integer read FSliceIndex write SetSliceIndex default 0;
  end;

procedure Register;

implementation

procedure Register;
begin
  RegisterComponents('Science', [TSciDM3Connector]);
end;

{ TSciDM3Connector }

constructor TSciDM3Connector.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FAutoRefresh := True;
  FColorScheme := csGrayscale;
  FSliceIndex := 0;
  FCachedBitmap := nil;
end;

destructor TSciDM3Connector.Destroy;
begin
  // Unhook from DM3
  if assigned(FDM3) then
  begin
    FDM3.UnregisterDataChangeListener(@DM3DataChanged);
    FDM3.RemoveFreeNotification(Self);
  end;
  if assigned(FTreeView) then
    FTreeView.RemoveFreeNotification(Self);
  if assigned(FImageControl) then
  begin
    SetOnPaint(FImageControl, nil);
    FImageControl.RemoveFreeNotification(Self);
  end;
  FCachedBitmap.Free;
  inherited Destroy;
end;

procedure TSciDM3Connector.Notification(AComponent: TComponent; Operation: TOperation);
begin
  inherited Notification(AComponent, Operation);
  if Operation = opRemove then
  begin
    if AComponent = FDM3 then
      FDM3 := nil
    else if AComponent = FTreeView then
      FTreeView := nil
    else if AComponent = FImageControl then
    begin
      // The control is gone; release the cached bitmap and nil the reference
      FreeAndNil(FCachedBitmap);
      FImageControl := nil;
    end;
  end;
end;

procedure TSciDM3Connector.SetDM3(Value: TSciDM3);
begin
  if FDM3 = Value then Exit;

  if assigned(FDM3) then
  begin
    FDM3.UnregisterDataChangeListener(@DM3DataChanged);
    FDM3.RemoveFreeNotification(Self);
  end;

  FDM3 := Value;

  if assigned(FDM3) then
  begin
    FDM3.FreeNotification(Self);
    FDM3.RegisterDataChangeListener(@DM3DataChanged);
  end;

  if FAutoRefresh then
    Refresh;
end;

procedure TSciDM3Connector.SetTreeView(Value: TTreeView);
begin
  if FTreeView = Value then Exit;

  if assigned(FTreeView) then
    FTreeView.RemoveFreeNotification(Self);

  FTreeView := Value;

  if assigned(FTreeView) then
    FTreeView.FreeNotification(Self);

  if FAutoRefresh then
    RefreshTree;
end;

procedure TSciDM3Connector.SetImageControl(Value: TGraphicControl);
begin
  if FImageControl = Value then Exit;

  // Unhook the old control
  if assigned(FImageControl) then
  begin
    SetOnPaint(FImageControl, nil);
    FImageControl.RemoveFreeNotification(Self);
  end;

  // Discard any bitmap that was sized for the old control
  FreeAndNil(FCachedBitmap);

  FImageControl := Value;

  if assigned(FImageControl) then
  begin
    FImageControl.FreeNotification(Self);
    // Hook OnPaint so the cached bitmap is redrawn on every paint
    SetOnPaint(FImageControl, @OnImageControlPaint);
  end;

  if FAutoRefresh then
    RefreshImage;
end;

procedure TSciDM3Connector.SetColorScheme(Value: TDM3ColorScheme);
begin
  if FColorScheme = Value then Exit;
  FColorScheme := Value;
  if FAutoRefresh then
    RefreshImage;
end;

procedure TSciDM3Connector.SetSliceIndex(Value: Integer);
begin
  if FSliceIndex = Value then Exit;
  FSliceIndex := Value;
  if FAutoRefresh then
    RefreshImage;
end;

procedure TSciDM3Connector.DM3DataChanged(Sender: TObject);
begin
  if FAutoRefresh then
    Refresh;
end;

procedure TSciDM3Connector.RenderToControl;
begin
  if not assigned(FCachedBitmap) or not assigned(FImageControl) then
    Exit;

  if FImageControl is TImage then
    TImage(FImageControl).Picture.Bitmap.Assign(FCachedBitmap)
  else
    FImageControl.Canvas.Draw(0, 0, FCachedBitmap);
end;

procedure TSciDM3Connector.SetOnPaint(AControl: TGraphicControl; AHandler: TNotifyEvent);
begin
  if AControl is TImage then
    TImage(AControl).OnPaint := AHandler
  else if AControl is TPaintBox then
    TPaintBox(AControl).OnPaint := AHandler;
end;

procedure TSciDM3Connector.OnImageControlPaint(Sender: TObject);
begin
  RenderToControl;
end;

procedure TSciDM3Connector.Refresh;
begin
  RefreshTree;
  RefreshImage;
end;

procedure TSciDM3Connector.RefreshTree;
var
  NodeMap: TStringList;
  i, DotPos: Integer;
  Key, Value, PathSoFar, Part, Remainder: String;
  ParentNode, Node: TTreeNode;
  Idx: Integer;
begin
  if not assigned(FTreeView) then Exit;

  FTreeView.Items.BeginUpdate;
  try
    FTreeView.Items.Clear;

    if not (assigned(FDM3) and FDM3.IsOpen and FDM3.IsParsed) then
      Exit;

    NodeMap := TStringList.Create;
    try
      NodeMap.Sorted := True;
      NodeMap.Duplicates := dupError;

      for i := 0 to FDM3.Tags.Count - 1 do
      begin
        Key := FDM3.Tags.Names[i];
        Value := FDM3.Tags.ValueFromIndex[i];

        ParentNode := nil;
        PathSoFar := '';
        Remainder := Key;

        while Remainder <> '' do
        begin
          DotPos := Pos('.', Remainder);
          if DotPos = 0 then
          begin
            Part := Remainder;
            Remainder := '';
          end
          else
          begin
            Part := Copy(Remainder, 1, DotPos - 1);
            Remainder := Copy(Remainder, DotPos + 1, Length(Remainder));
          end;

          if PathSoFar = '' then
            PathSoFar := Part
          else
            PathSoFar := PathSoFar + '.' + Part;

          if NodeMap.Find(PathSoFar, Idx) then
            Node := TTreeNode(NodeMap.Objects[Idx])
          else
          begin
            Node := FTreeView.Items.AddChild(ParentNode, Part);
            NodeMap.AddObject(PathSoFar, Node);
          end;

          ParentNode := Node;
        end;

        // Leaf value, one level below the fully resolved tag path
        FTreeView.Items.AddChild(ParentNode, Value);
      end;
    finally
      NodeMap.Free;
    end;
  finally
    FTreeView.Items.EndUpdate;
  end;
end;

procedure TSciDM3Connector.RefreshImage;
var
  i, j, w, h: Integer;
  c: Byte;
  ll, hl: Double;
  TempIntfImage: TLazIntfImage;

  procedure ClearControl;
  begin
    if FImageControl is TImage then
      TImage(FImageControl).Picture.Graphic := nil
    else
      FImageControl.Invalidate;
  end;

begin
  if not assigned(FImageControl) then Exit;

  if not (assigned(FDM3) and FDM3.IsOpen and FDM3.IsParsed) then
  begin
    // No data, discard the cache and clear the control
    FreeAndNil(FCachedBitmap);
    ClearControl;
    Exit;
  end;

  w := FDM3.ImageWidth;
  h := FDM3.ImageHeight;
  ll := FDM3.LowLimit;
  hl := FDM3.HighLimit;

  if (FSliceIndex < 0) or (FSliceIndex >= FDM3.ImageDepth) then
  begin
    FreeAndNil(FCachedBitmap);
    ClearControl;
    Exit;
  end;

  // (Re)allocate the cached bitmap only when the dimensions actually change
  if not assigned(FCachedBitmap) or (FCachedBitmap.Width <> w) or (FCachedBitmap.Height <> h) then
  begin
    FreeAndNil(FCachedBitmap);
    FCachedBitmap := TBitmap.Create;
    FCachedBitmap.Width := w;
    FCachedBitmap.Height := h;
  end;

  // Run the pixel loop into the cached bitmap via a TLazIntfImage round-trip
  TempIntfImage := FCachedBitmap.CreateIntfImage;
  try
    for i := 0 to w - 1 do
      for j := 0 to h - 1 do
      begin
        c := NormalizePixelValue(FDM3.PixelValue(i, j, FSliceIndex), ll, hl);
        case FColorScheme of
          csInverted: c := 255 - c;
          // csGrayscale: use c as-is
        end;
        TempIntfImage.Colors[i, j] := TColorToFPColor(RGBToColor(c, c, c));
      end;
    FCachedBitmap.LoadFromIntfImage(TempIntfImage);
  finally
    TempIntfImage.Free;
  end;

  RenderToControl;
end;

end.
