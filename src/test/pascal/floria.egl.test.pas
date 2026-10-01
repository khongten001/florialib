unit Floria.EGL.Test;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  Floria.EGL;

type
  TFloriaEGLTest = class(TTestCase)
  published
    procedure TestEGLAvailability();
    procedure TestEGLConstantsAndTypes();
    procedure TestFloriaEGLErrorString();
    procedure TestEGLDisplayInitialization();
    procedure TestEGLChooseConfig();
    procedure TestEGLPbufferSurface();
    procedure TestEGLContextLifecycle();
    procedure TestEGLGetProcAddress();
  end;

implementation

procedure TFloriaEGLTest.TestEGLAvailability();
var
  egl: TEGLEngine;
begin
  egl := FloriaEGL();
  // Standard modern Linux systems with Mesa / GPU have libEGL.so.1
  AssertTrue('EGL library should be detected and available', egl.Available);
  AssertTrue('Library path should be set', Length(egl.LibraryPath) > 0);
  AssertTrue('FloriaEGLIsAvailable wrapper works', FloriaEGLIsAvailable());
end;

procedure TFloriaEGLTest.TestEGLConstantsAndTypes();
begin
  AssertEquals('EGL_FALSE', 0, EGL_FALSE);
  AssertEquals('EGL_TRUE', 1, EGL_TRUE);
  AssertNull('EGL_NO_CONTEXT is nil', EGL_NO_CONTEXT);
  AssertNull('EGL_NO_DISPLAY is nil', EGL_NO_DISPLAY);
  AssertNull('EGL_NO_SURFACE is nil', EGL_NO_SURFACE);
  AssertEquals('EGL_SUCCESS value', $3000, EGL_SUCCESS);
  AssertEquals('EGL_NONE value', $3038, EGL_NONE);
  AssertEquals('EGL_OPENGL_ES2_BIT value', $0004, EGL_OPENGL_ES2_BIT);
  AssertEquals('EGL_WINDOW_BIT value', $0004, EGL_WINDOW_BIT);
  AssertEquals('EGL_PBUFFER_BIT value', $0001, EGL_PBUFFER_BIT);
end;

procedure TFloriaEGLTest.TestFloriaEGLErrorString();
begin
  AssertEquals('Success string', 'EGL_SUCCESS', FloriaEGLErrorString(EGL_SUCCESS));
  AssertEquals('Not initialized string', 'EGL_NOT_INITIALIZED', FloriaEGLErrorString(EGL_NOT_INITIALIZED));
  AssertEquals('Bad config string', 'EGL_BAD_CONFIG', FloriaEGLErrorString(EGL_BAD_CONFIG));
  AssertEquals('Bad alloc string', 'EGL_BAD_ALLOC', FloriaEGLErrorString(EGL_BAD_ALLOC));
  AssertEquals('Bad context string', 'EGL_BAD_CONTEXT', FloriaEGLErrorString(EGL_BAD_CONTEXT));
  AssertEquals('Bad display string', 'EGL_BAD_DISPLAY', FloriaEGLErrorString(EGL_BAD_DISPLAY));
  AssertEquals('Bad surface string', 'EGL_BAD_SURFACE', FloriaEGLErrorString(EGL_BAD_SURFACE));
  AssertTrue('Unknown error formatting', Pos('EGL_UNKNOWN_ERROR', FloriaEGLErrorString($9999)) = 1);
end;

procedure TFloriaEGLTest.TestEGLDisplayInitialization();
var
  egl: TEGLEngine;
  InitOk: Boolean;
begin
  egl := FloriaEGL();
  if not egl.Available then
    Exit;

  InitOk := egl.InitializeDefaultDisplay();
  AssertTrue('InitializeDefaultDisplay succeeds on active display session', InitOk);
  AssertTrue('DefaultDisplay is non-null', egl.DefaultDisplay <> EGL_NO_DISPLAY);
  AssertTrue('EGL Version Major >= 1', egl.VersionMajor >= 1);
  AssertTrue('Version string not empty', Length(egl.Version) > 0);
  AssertTrue('Client APIs string not empty', Length(egl.ClientAPIs) > 0);
end;

procedure TFloriaEGLTest.TestEGLChooseConfig();
var
  egl: TEGLEngine;
  Attribs: array[0..12] of EGLint;
  Cfg: EGLConfig;
  NumConfigs: EGLint;
  RedSize: EGLint;
  Ok: EGLBoolean;
begin
  egl := FloriaEGL();
  if not egl.Available or not egl.InitializeDefaultDisplay() then
    Exit;

  Attribs[0] := EGL_SURFACE_TYPE;
  Attribs[1] := EGL_PBUFFER_BIT;
  Attribs[2] := EGL_RED_SIZE;
  Attribs[3] := 8;
  Attribs[4] := EGL_GREEN_SIZE;
  Attribs[5] := 8;
  Attribs[6] := EGL_BLUE_SIZE;
  Attribs[7] := 8;
  Attribs[8] := EGL_ALPHA_SIZE;
  Attribs[9] := 8;
  Attribs[10] := EGL_RENDERABLE_TYPE;
  Attribs[11] := EGL_OPENGL_ES2_BIT;
  Attribs[12] := EGL_NONE;

  Cfg := nil;
  NumConfigs := 0;
  Ok := eglChooseConfig(egl.DefaultDisplay, @Attribs[0], @Cfg, 1, @NumConfigs);
  AssertEquals('eglChooseConfig succeeds', EGL_TRUE, Ok);
  AssertTrue('At least one matching EGL config found', NumConfigs > 0);
  AssertNotNull('EGLConfig is non-null', Cfg);

  RedSize := 0;
  Ok := eglGetConfigAttrib(egl.DefaultDisplay, Cfg, EGL_RED_SIZE, @RedSize);
  AssertEquals('eglGetConfigAttrib succeeds', EGL_TRUE, Ok);
  AssertTrue('Red size is at least 8 bits', RedSize >= 8);
end;

procedure TFloriaEGLTest.TestEGLPbufferSurface();
var
  egl: TEGLEngine;
  CfgAttribs: array[0..12] of EGLint;
  SurfAttribs: array[0..4] of EGLint;
  Cfg: EGLConfig;
  NumConfigs: EGLint;
  Surf: EGLSurface;
  Val: EGLint;
begin
  egl := FloriaEGL();
  if not egl.Available or not egl.InitializeDefaultDisplay() then
    Exit;

  CfgAttribs[0] := EGL_SURFACE_TYPE;
  CfgAttribs[1] := EGL_PBUFFER_BIT;
  CfgAttribs[2] := EGL_RED_SIZE;
  CfgAttribs[3] := 8;
  CfgAttribs[4] := EGL_GREEN_SIZE;
  CfgAttribs[5] := 8;
  CfgAttribs[6] := EGL_BLUE_SIZE;
  CfgAttribs[7] := 8;
  CfgAttribs[8] := EGL_ALPHA_SIZE;
  CfgAttribs[9] := 8;
  CfgAttribs[10] := EGL_RENDERABLE_TYPE;
  CfgAttribs[11] := EGL_OPENGL_ES2_BIT;
  CfgAttribs[12] := EGL_NONE;

  Cfg := nil;
  NumConfigs := 0;
  if eglChooseConfig(egl.DefaultDisplay, @CfgAttribs[0], @Cfg, 1, @NumConfigs) <> EGL_TRUE then
    Exit;

  SurfAttribs[0] := EGL_WIDTH;
  SurfAttribs[1] := 32;
  SurfAttribs[2] := EGL_HEIGHT;
  SurfAttribs[3] := 24;
  SurfAttribs[4] := EGL_NONE;

  Surf := eglCreatePbufferSurface(egl.DefaultDisplay, Cfg, @SurfAttribs[0]);
  AssertNotNull('Pbuffer surface created', Surf);
  try
    Val := 0;
    eglQuerySurface(egl.DefaultDisplay, Surf, EGL_WIDTH, @Val);
    AssertEquals('Pbuffer width query', 32, Val);

    Val := 0;
    eglQuerySurface(egl.DefaultDisplay, Surf, EGL_HEIGHT, @Val);
    AssertEquals('Pbuffer height query', 24, Val);
  finally
    eglDestroySurface(egl.DefaultDisplay, Surf);
  end;
end;

procedure TFloriaEGLTest.TestEGLContextLifecycle();
var
  egl: TEGLEngine;
  CfgAttribs: array[0..12] of EGLint;
  CtxAttribs: array[0..2] of EGLint;
  SurfAttribs: array[0..4] of EGLint;
  Cfg: EGLConfig;
  NumConfigs: EGLint;
  Ctx: EGLContext;
  Surf: EGLSurface;
  ClientVer: EGLint;
begin
  egl := FloriaEGL();
  if not egl.Available or not egl.InitializeDefaultDisplay() then
    Exit;

  // Bind OpenGL ES API
  eglBindAPI(EGL_OPENGL_ES_API);

  CfgAttribs[0] := EGL_SURFACE_TYPE;
  CfgAttribs[1] := EGL_PBUFFER_BIT;
  CfgAttribs[2] := EGL_RED_SIZE;
  CfgAttribs[3] := 8;
  CfgAttribs[4] := EGL_GREEN_SIZE;
  CfgAttribs[5] := 8;
  CfgAttribs[6] := EGL_BLUE_SIZE;
  CfgAttribs[7] := 8;
  CfgAttribs[8] := EGL_ALPHA_SIZE;
  CfgAttribs[9] := 8;
  CfgAttribs[10] := EGL_RENDERABLE_TYPE;
  CfgAttribs[11] := EGL_OPENGL_ES2_BIT;
  CfgAttribs[12] := EGL_NONE;

  Cfg := nil;
  NumConfigs := 0;
  if eglChooseConfig(egl.DefaultDisplay, @CfgAttribs[0], @Cfg, 1, @NumConfigs) <> EGL_TRUE then
    Exit;

  CtxAttribs[0] := EGL_CONTEXT_CLIENT_VERSION;
  CtxAttribs[1] := 2;
  CtxAttribs[2] := EGL_NONE;

  Ctx := eglCreateContext(egl.DefaultDisplay, Cfg, EGL_NO_CONTEXT, @CtxAttribs[0]);
  AssertNotNull('EGLContext created successfully', Ctx);

  SurfAttribs[0] := EGL_WIDTH;
  SurfAttribs[1] := 16;
  SurfAttribs[2] := EGL_HEIGHT;
  SurfAttribs[3] := 16;
  SurfAttribs[4] := EGL_NONE;

  Surf := eglCreatePbufferSurface(egl.DefaultDisplay, Cfg, @SurfAttribs[0]);
  AssertNotNull('Pbuffer surface for context make-current', Surf);

  try
    // Test MakeCurrent
    AssertEquals('eglMakeCurrent succeeds', EGL_TRUE,
      eglMakeCurrent(egl.DefaultDisplay, Surf, Surf, Ctx));

    AssertTrue('eglGetCurrentContext matches', Ctx = eglGetCurrentContext());
    AssertTrue('eglGetCurrentDisplay matches', egl.DefaultDisplay = eglGetCurrentDisplay());

    ClientVer := 0;
    eglQueryContext(egl.DefaultDisplay, Ctx, EGL_CONTEXT_CLIENT_VERSION, @ClientVer);
    AssertEquals('Queried context client version is 2', 2, ClientVer);

    // Release current
    eglMakeCurrent(egl.DefaultDisplay, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
    AssertTrue('Context released', eglGetCurrentContext() = nil);
  finally
    eglDestroySurface(egl.DefaultDisplay, Surf);
    eglDestroyContext(egl.DefaultDisplay, Ctx);
  end;
end;

procedure TFloriaEGLTest.TestEGLGetProcAddress();
var
  egl: TEGLEngine;
  P: Pointer;
begin
  egl := FloriaEGL();
  if not egl.Available then
    Exit;

  // Test eglGetProcAddress
  P := eglGetProcAddress('glGetString');
  // glGetString may be resolved via eglGetProcAddress or dlsym
  if P = nil then
    P := egl.GetProc('glGetString');
  AssertNotNull('GetProc glGetString resolved', P);
end;

initialization
  RegisterTest(TFloriaEGLTest);

end.
