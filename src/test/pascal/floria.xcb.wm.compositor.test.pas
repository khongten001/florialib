{ Unit Floria.XCB.WM.Compositor.Test — Unit test suite for TXCBCompositor }

unit Floria.XCB.WM.Compositor.Test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  Floria.XCB,
  Floria.XCB.WM,
  Floria.XCB.Damage,
  Floria.XCB.WM.Compositor,
  Floria.Image.Core,
  Floria.Canvas.Agg;

type
  TXCBCompositorTest = class(TTestCase)
  published
    procedure TestCompositorLifecycleOffline();
    procedure TestCompositedWindowShadowConfig();
    procedure TestSceneCompositionOffline();
    procedure TestDamageNotifyRouting();
    procedure TestLiveCompositorIfAvailable();
  end;

implementation

procedure TXCBCompositorTest.TestCompositorLifecycleOffline();
var
  comp: TXCBCompositor;
  w: TXCBCompositedWindow;
  rect: TXCBRect;
begin
  comp := TXCBCompositor.Create(nil, 0, 800, 600);
  try
    AssertFalse('Compositor active offline', comp.IsActive);
    AssertEquals('Screen width', 800, comp.ScreenWidth);
    AssertEquals('Screen height', 600, comp.ScreenHeight);
    AssertNotNull('Scene image created', comp.SceneImage);
    AssertNotNull('Scene canvas created', comp.SceneCanvas);
    AssertEquals('Zero windows initially', 0, comp.Windows.Count);

    rect := TXCBRect.Create(50, 50, 400, 300);
    w := comp.RegisterWindow(1001, rect);
    AssertNotNull('Window registered', w);
    AssertEquals('Window ID matches', 1001, w.Window);
    AssertEquals('One window in list', 1, comp.Windows.Count);
    AssertSame('FindWindow finds registered window', w, comp.FindWindow(1001));

    // Test geometry update
    w.UpdateGeometry(60, 70, 420, 320);
    AssertEquals('Updated X', 60, w.Geometry.X);
    AssertEquals('Updated Y', 70, w.Geometry.Y);
    AssertEquals('Updated Width', 420, w.Geometry.Width);
    AssertEquals('Updated Height', 320, w.Geometry.Height);

    // Test properties
    comp.SetWindowOpacity(1001, 0.85);
    AssertTrue('Window opacity updated', Abs(w.Opacity - 0.85) < 0.001);

    comp.SetWindowBackdropBlur(1001, True, 20);
    AssertTrue('Window backdrop blur enabled', w.HasBackdropBlur);
    AssertEquals('Window blur radius', 20, w.BlurRadius);

    comp.SetWindowShadow(1001, True, 18, 6, 0.5);
    AssertTrue('Window shadow enabled', w.ShadowConfig.Enabled);
    AssertEquals('Shadow radius', 18, w.ShadowConfig.Radius);
    AssertEquals('Shadow offset Y', 6, w.ShadowConfig.OffsetY);

    comp.UnregisterWindow(1001);
    AssertEquals('Window unregistered', 0, comp.Windows.Count);
    AssertNull('FindWindow returns nil', comp.FindWindow(1001));
  finally
    comp.Free();
  end;
end;

procedure TXCBCompositorTest.TestCompositedWindowShadowConfig();
var
  cfg: TXCBWindowShadowConfig;
begin
  cfg := TXCBWindowShadowConfig.Create(True, 16, 5, 0.45);
  AssertTrue('Shadow enabled', cfg.Enabled);
  AssertEquals('Shadow radius', 16, cfg.Radius);
  AssertEquals('Shadow offset Y', 5, cfg.OffsetY);
  AssertTrue('Shadow opacity', Abs(cfg.Opacity - 0.45) < 0.001);
end;

procedure TXCBCompositorTest.TestSceneCompositionOffline();
var
  comp: TXCBCompositor;
  w1, w2: TXCBCompositedWindow;
  rect1, rect2: TXCBRect;
  clientImg1, clientImg2: TFloriaImage;
  canvas: TFloriaCanvasAgg;
  pixel: TBgraPixel;
  isCompositedNonBlank: Boolean;
  x, y: Integer;
begin
  comp := TXCBCompositor.Create(nil, 0, 640, 480);
  try
    comp.SetBackgroundColor(30, 30, 46, 255); // Catppuccin Base

    // Create 1st simulated client (Frosted Glass Panel)
    rect1 := TXCBRect.Create(50, 50, 200, 150);
    w1 := comp.RegisterWindow(2001, rect1);
    w1.HasBackdropBlur := True;
    w1.BlurRadius := 10;
    w1.Opacity := 0.9;
    clientImg1 := TFloriaImage.Create(200, 150);
    clientImg1.Clear(60, 60, 80, 220); // Semi-transparent bluish panel
    w1.Image := clientImg1;
    w1.IsDirty := False;

    // Create 2nd simulated client (Foreground dialog with Drop Shadow)
    rect2 := TXCBRect.Create(180, 120, 250, 180);
    w2 := comp.RegisterWindow(2002, rect2);
    w2.ShadowConfig := TXCBWindowShadowConfig.Create(True, 12, 4, 0.4);
    clientImg2 := TFloriaImage.Create(250, 180);
    clientImg2.Clear(240, 240, 250, 255); // Bright card
    w2.Image := clientImg2;
    w2.IsDirty := False;

    // Execute full composite pass
    comp.CompositeScene();

    AssertNotNull('Scene image available', comp.SceneImage);
    AssertEquals('Scene image width', 640, comp.SceneImage.Width);
    AssertEquals('Scene image height', 480, comp.SceneImage.Height);

    // Assert that the composition changed pixels in the window region
    pixel := comp.SceneImage.Pixels[200, 150];
    // Pixel inside w2 (bright card) should be close to 240
    AssertTrue('Foreground window pixel rendered', pixel.R > 200);

    // Pixel in background corner should match background color (30, 30, 46)
    pixel := comp.SceneImage.Pixels[10, 10];
    AssertEquals('Background R', 30, pixel.R);
    AssertEquals('Background G', 30, pixel.G);
    AssertEquals('Background B', 46, pixel.B);
  finally
    comp.Free();
  end;
end;

procedure TXCBCompositorTest.TestDamageNotifyRouting();
var
  comp: TXCBCompositor;
  w: TXCBCompositedWindow;
  rect: TXCBRect;
  dmgEvent: xcb_damage_notify_event_t;
begin
  comp := TXCBCompositor.Create(nil, 0, 800, 600);
  try
    rect := TXCBRect.Create(100, 100, 300, 200);
    w := comp.RegisterWindow(5001, rect);
    w.IsDirty := False;

    FillChar(dmgEvent, SizeOf(dmgEvent), 0);
    dmgEvent.drawable := 5001;
    dmgEvent.area.x := 10;
    dmgEvent.area.y := 10;
    dmgEvent.area.width := 50;
    dmgEvent.area.height := 50;

    AssertTrue('HandleDamageNotify returns True for registered window', comp.HandleDamageNotify(@dmgEvent));
    AssertTrue('Window marked dirty on damage', w.IsDirty);

    // Test unhandled drawable
    dmgEvent.drawable := 9999;
    AssertFalse('HandleDamageNotify returns False for unknown window', comp.HandleDamageNotify(@dmgEvent));
  finally
    comp.Free();
  end;
end;

procedure TXCBCompositorTest.TestLiveCompositorIfAvailable();
var
  conn: Pxcb_connection_t;
  screenNum: Integer;
  screen: Pxcb_screen_t;
  comp: TXCBCompositor;
begin
  screenNum := 0;
  conn := xcb_connect(nil, @screenNum);
  if conn = nil then Exit;
  try
    if xcb_connection_has_error(conn) = 0 then
    begin
      screen := xcb_setup_roots_iterator(xcb_get_setup(conn)).data;
      if screen <> nil then
      begin
        comp := TXCBCompositor.Create(conn, screen^.root, screen^.width_in_pixels, screen^.height_in_pixels);
        try
          AssertTrue('Composite extension detected on live server', comp.HasComposite);
          AssertTrue('Damage extension detected on live server', comp.HasDamage);
        finally
          comp.Free();
        end;
      end;
    end;
  finally
    xcb_disconnect(conn);
  end;
end;

initialization
  RegisterTest(TXCBCompositorTest);

end.
