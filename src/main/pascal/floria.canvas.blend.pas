unit Floria.Canvas.Blend;

// Floria.Canvas.Blend
// ===================
// Full W3C/CSS Compositing and Blending Level 1 implementation.
// Provides all 29 standard blend modes:
//   - 12 Porter-Duff compositing operators
//   - 13 separable blend modes (Multiply, Screen, etc.)
//   - 4 non-separable HSL blend modes (Hue, Saturation, Color, Luminosity)
//
// Each blend mode operates on premultiplied 8-bit BGRA pixels and supports
// partial coverage (anti-aliased edges). The implementation follows the
// exact mathematical formulations from the W3C specification:
// https://www.w3.org/TR/compositing-1/
//
// Usage:
//   FloriaBlendPixel(@DstPixel, SrcPixel, BlendMode, Cover);
//   FloriaBlendScanline(DstRow, SrcRow, Width, BlendMode, Cover);

{$mode objfpc}{$H+}

interface

uses
  agg_basics,
  agg_pixfmt,
  agg_color;

type
  // Complete enumeration of all 29 standard blend modes (Skia & W3C Level 1).
  // Modes 0-13: Porter-Duff compositing operators & arithmetic blend modes.
  // Modes 14-24: Separable blend modes (Multiply, Screen, etc.).
  // Modes 25-28: Non-separable HSL blend modes (Hue, Saturation, Color, Luminosity).
  TFloriaBlendMode = (
    // Porter-Duff compositing operators
    fbmClear,        // 0  - Clear destination
    fbmSrc,          // 1  - Replace with source
    fbmDst,          // 2  - Keep destination (no-op)
    fbmSrcOver,      // 3  - Source over destination (default alpha compositing)
    fbmDstOver,      // 4  - Destination over source
    fbmSrcIn,        // 5  - Source within destination
    fbmDstIn,        // 6  - Destination within source
    fbmSrcOut,       // 7  - Source outside destination
    fbmDstOut,       // 8  - Destination outside source
    fbmSrcATop,      // 9  - Source atop destination
    fbmDstATop,      // 10 - Destination atop source
    fbmXor,          // 11 - Exclusive or
    fbmPlus,         // 12 - Additive blending (S + D)
    fbmModulate,     // 13 - Component-wise multiply (S * D)

    // Separable blend modes (per-channel, independent R/G/B processing)
    fbmMultiply,     // 14 - Darkens: Cs * Cd
    fbmScreen,       // 15 - Lightens: Cs + Cd - Cs * Cd
    fbmOverlay,      // 16 - Combines Multiply and Screen
    fbmDarken,       // 17 - Min(Cs, Cd)
    fbmLighten,      // 18 - Max(Cs, Cd)
    fbmColorDodge,   // 19 - Brightens destination to reflect source
    fbmColorBurn,    // 20 - Darkens destination to reflect source
    fbmHardLight,    // 21 - Combines Multiply and Screen (source determines)
    fbmSoftLight,    // 22 - Gentle version of HardLight
    fbmDifference,   // 23 - |Cs - Cd|
    fbmExclusion,    // 24 - Lower contrast Difference

    // Non-separable blend modes (HSL-based, process R/G/B together)
    fbmHue,          // 25 - Hue from source, saturation+luminosity from dest
    fbmSaturation,   // 26 - Saturation from source, hue+luminosity from dest
    fbmColor,        // 27 - Hue+saturation from source, luminosity from dest
    fbmLuminosity    // 28 - Luminosity from source, hue+saturation from dest
  );

  // 32-bit BGRA pixel for blend operations (matches TBgraPixel layout)
  TBlendPixel = packed record
    B : Byte;
    G : Byte;
    R : Byte;
    A : Byte;
  end;
  PBlendPixel = ^TBlendPixel;

// Core blend operations
// ABlendMode: the blend mode to apply
// ACover: anti-aliased edge coverage (0..255), 255 = fully covered
procedure FloriaBlendPixel(ADst: PBlendPixel; const ASrc: TBlendPixel; ABlendMode: TFloriaBlendMode; ACover: Byte = 255);

// Blend an entire scanline (Width pixels) from Src onto Dst
procedure FloriaBlendScanline(ADst, ASrc: PBlendPixel; AWidth: Integer; ABlendMode: TFloriaBlendMode; ACover: Byte = 255);

// Utility: blend a single source color onto a scanline with uniform alpha
procedure FloriaBlendFill(ADst: PBlendPixel; AWidth: Integer; const ASrc: TBlendPixel; ABlendMode: TFloriaBlendMode; ACover: Byte = 255);

// Convert blend mode to human-readable name
function FloriaBlendModeName(AMode: TFloriaBlendMode): string;

// Adaptor callback for AggPas pixfmt_custom_blend_rgba
procedure FloriaAggBlendAdaptor(this: pixel_formats_ptr; op: unsigned; p: int8u_ptr; cr, cg, cb, ca, cover: unsigned);

implementation

uses
  Math;

const
  BASE_SHIFT = 8;
  BASE_MASK  = 255;

// ---------------------------------------------------------------------------
// Internal helper: clamp integer to [0..255]
// ---------------------------------------------------------------------------
function Clamp255(V: Integer): Byte; inline;
begin
  if V < 0 then
    Result := 0
  else if V > 255 then
    Result := 255
  else
    Result := Byte(V);
end;

// ---------------------------------------------------------------------------
// Internal helper: fixed-point multiply (a * b / 255)
// Uses (a * b + 128 + ((a * b + 128) shr 8)) shr 8 for exact rounding
// ---------------------------------------------------------------------------
function Mul255(A, B: Integer): Integer; inline;
var
  T: Integer;
begin
  T := A * B + 128;
  Result := (T + (T shr 8)) shr 8;
end;

// ---------------------------------------------------------------------------
// Internal helper: fixed-point divide (a * 255 / b), clamped
// ---------------------------------------------------------------------------
function Div255(A, B: Integer): Integer; inline;
begin
  if B = 0 then
    Result := 0
  else
  begin
    Result := (A * 255) div B;
    if Result > 255 then
      Result := 255;
  end;
end;

// ---------------------------------------------------------------------------
// Non-separable blend mode helpers (W3C spec Section 13.3)
// All operate on unpremultiplied [0..255] channel values
// ---------------------------------------------------------------------------

function Lum(R, G, B: Integer): Integer; inline;
begin
  // ITU-R BT.601 luma: 0.299*R + 0.587*G + 0.114*B
  // Fixed-point: (77*R + 150*G + 29*B) / 256
  Result := (77 * R + 150 * G + 29 * B + 128) shr 8;
end;

procedure ClipColor(var R, G, B: Integer);
var
  L, N, X, D: Integer;
begin
  L := Lum(R, G, B);
  N := R;
  if G < N then N := G;
  if B < N then N := B;
  X := R;
  if G > X then X := G;
  if B > X then X := B;

  if N < 0 then
  begin
    if L <> N then
      D := L - N
    else
      D := 1;
    R := L + ((R - L) * L + (D shr 1)) div D;
    G := L + ((G - L) * L + (D shr 1)) div D;
    B := L + ((B - L) * L + (D shr 1)) div D;
  end;

  if X > 255 then
  begin
    D := X - L;
    if D = 0 then D := 1;
    R := L + ((R - L) * (255 - L) + (D shr 1)) div D;
    G := L + ((G - L) * (255 - L) + (D shr 1)) div D;
    B := L + ((B - L) * (255 - L) + (D shr 1)) div D;
  end;
end;

procedure SetLum(var R, G, B: Integer; L: Integer);
var
  D: Integer;
begin
  D := L - Lum(R, G, B);
  R := R + D;
  G := G + D;
  B := B + D;
  ClipColor(R, G, B);
end;

function Sat(R, G, B: Integer): Integer; inline;
var
  N, X: Integer;
begin
  N := R;
  if G < N then N := G;
  if B < N then N := B;
  X := R;
  if G > X then X := G;
  if B > X then X := B;
  Result := X - N;
end;

// SetSat: Set the saturation of (R,G,B) to S
// The W3C spec defines this in terms of min/mid/max channel sorting
procedure SetSat(var R, G, B: Integer; S: Integer);
var
  MinVal, MidVal, MaxVal: PInteger;
  Tmp: PInteger;
begin
  // Sort channels by value: MinVal <= MidVal <= MaxVal
  MinVal := @R; MidVal := @G; MaxVal := @B;

  if MinVal^ > MidVal^ then begin Tmp := MinVal; MinVal := MidVal; MidVal := Tmp; end;
  if MinVal^ > MaxVal^ then begin Tmp := MinVal; MinVal := MaxVal; MaxVal := Tmp; end;
  if MidVal^ > MaxVal^ then begin Tmp := MidVal; MidVal := MaxVal; MaxVal := Tmp; end;

  if MaxVal^ > MinVal^ then
  begin
    MidVal^ := ((MidVal^ - MinVal^) * S + ((MaxVal^ - MinVal^) shr 1)) div (MaxVal^ - MinVal^);
    MaxVal^ := S;
  end
  else
  begin
    MidVal^ := 0;
    MaxVal^ := 0;
  end;
  MinVal^ := 0;
end;

// ---------------------------------------------------------------------------
// Separable blend mode channel functions (W3C spec Section 13.2)
// Input/output: unpremultiplied channel values [0..255]
// Cs = source channel, Cd = destination channel
// ---------------------------------------------------------------------------

function BlendMultiply(Cs, Cd: Integer): Integer; inline;
begin
  Result := Mul255(Cs, Cd);
end;

function BlendScreen(Cs, Cd: Integer): Integer; inline;
begin
  Result := Cs + Cd - Mul255(Cs, Cd);
end;

function BlendOverlay(Cs, Cd: Integer): Integer; inline;
begin
  // Overlay = HardLight with swapped arguments
  if Cd <= 127 then
    Result := Mul255(2 * Cd, Cs)
  else
    Result := BlendScreen(Cs, 2 * Cd - 255);
end;

function BlendDarken(Cs, Cd: Integer): Integer; inline;
begin
  if Cs < Cd then
    Result := Cs
  else
    Result := Cd;
end;

function BlendLighten(Cs, Cd: Integer): Integer; inline;
begin
  if Cs > Cd then
    Result := Cs
  else
    Result := Cd;
end;

function BlendColorDodge(Cs, Cd: Integer): Integer; inline;
begin
  if Cd = 0 then
    Result := 0
  else if Cs = 255 then
    Result := 255
  else
  begin
    Result := Div255(Cd, 255 - Cs);
    if Result > 255 then
      Result := 255;
  end;
end;

function BlendColorBurn(Cs, Cd: Integer): Integer; inline;
begin
  if Cd = 255 then
    Result := 255
  else if Cs = 0 then
    Result := 0
  else
  begin
    Result := 255 - Div255(255 - Cd, Cs);
    if Result < 0 then
      Result := 0;
  end;
end;

function BlendHardLight(Cs, Cd: Integer): Integer; inline;
begin
  if Cs <= 127 then
    Result := Mul255(2 * Cs, Cd)
  else
    Result := BlendScreen(Cd, 2 * Cs - 255);
end;

function BlendSoftLight(Cs, Cd: Integer): Integer; inline;
var
  T: Integer;
begin
  // W3C spec formula
  if Cs <= 127 then
  begin
    // Cd - (1 - 2*Cs) * Cd * (1 - Cd)
    // In fixed-point: Cd - Mul255((255 - 2*Cs), Mul255(Cd, 255 - Cd))
    Result := Cd - Mul255(255 - 2 * Cs, Mul255(Cd, 255 - Cd));
  end
  else
  begin
    // D(Cd) function from W3C spec
    if Cd <= 63 then  // Cd <= 0.25
      T := ((16 * Cd - 12 * 255) * Cd + 4 * 255 * 255) * Cd div (255 * 255)
    else
      T := Round(Sqrt(Cd / 255.0) * 255.0);
    Result := Cd + Mul255(2 * Cs - 255, T - Cd);
  end;
end;

function BlendDifference(Cs, Cd: Integer): Integer; inline;
begin
  Result := Abs(Cs - Cd);
end;

function BlendExclusion(Cs, Cd: Integer): Integer; inline;
begin
  Result := Cs + Cd - 2 * Mul255(Cs, Cd);
end;

// ---------------------------------------------------------------------------
// Core blending: applies blend mode B to premultiplied BGRA pixels
// Implements the full compositing formula from the W3C spec:
//   Co = αs x Fa x Cs + αd x Fb x Cd + αs x αd x B(Cs, Cd)
// where Fa and Fb depend on the compositing operator.
// For SrcOver (the compositor used with all separable/non-separable modes):
//   Fa = 1, Fb = 1 - αs
//   Co = αs x Cs + αd x (1 - αs) x Cd + αs x αd x (B(Cs,Cd) - Cs)
//      = αs x (Cs + αd x (B(Cs,Cd) - Cs)) + αd x (1 - αs) x Cd
// But for clean separation, we implement it as the spec:
//   Cr = (1 - αd) x Cs + (1 - αs) x Cd + B(Cs, Cd)
//   (for unpremultiplied, then re-premultiply)
// ---------------------------------------------------------------------------

procedure DoBlendPixel(ADst: PBlendPixel; const ASrc: TBlendPixel; ABlendMode: TFloriaBlendMode; ACover: Byte);
var
  SR, SG, SB, SA: Integer;
  DR, DG, DB, DA: Integer;
  // Unpremultiplied source and dest channels
  SRu, SGu, SBu: Integer;
  DRu, DGu, DBu: Integer;
  // Blended result channels (unpremultiplied)
  BRu, BGu, BBu: Integer;
  // Output
  OutA, OutR, OutG, OutB: Integer;
  S1A, D1A: Integer; // 255 - alpha
  InvSA, InvDA: Integer;
begin
  // Apply coverage to source
  if ACover = 0 then Exit;

  SR := ASrc.R; SG := ASrc.G; SB := ASrc.B; SA := ASrc.A;

  if ACover < 255 then
  begin
    SR := Mul255(SR, ACover);
    SG := Mul255(SG, ACover);
    SB := Mul255(SB, ACover);
    SA := Mul255(SA, ACover);
  end;

  if SA = 0 then Exit;

  DR := ADst^.R; DG := ADst^.G; DB := ADst^.B; DA := ADst^.A;

  // --- Porter-Duff compositing operators (operate on premultiplied) ---
  case ABlendMode of
    fbmClear:
      begin
        ADst^.R := 0; ADst^.G := 0; ADst^.B := 0; ADst^.A := 0;
        Exit;
      end;

    fbmSrc:
      begin
        ADst^.R := Clamp255(SR); ADst^.G := Clamp255(SG);
        ADst^.B := Clamp255(SB); ADst^.A := Clamp255(SA);
        Exit;
      end;

    fbmDst:
      Exit; // No-op

    fbmSrcOver:
      begin
        S1A := 255 - SA;
        ADst^.R := Clamp255(SR + Mul255(DR, S1A));
        ADst^.G := Clamp255(SG + Mul255(DG, S1A));
        ADst^.B := Clamp255(SB + Mul255(DB, S1A));
        ADst^.A := Clamp255(SA + Mul255(DA, S1A));
        Exit;
      end;

    fbmDstOver:
      begin
        D1A := 255 - DA;
        ADst^.R := Clamp255(DR + Mul255(SR, D1A));
        ADst^.G := Clamp255(DG + Mul255(SG, D1A));
        ADst^.B := Clamp255(DB + Mul255(SB, D1A));
        ADst^.A := Clamp255(DA + Mul255(SA, D1A));
        Exit;
      end;

    fbmSrcIn:
      begin
        ADst^.R := Clamp255(Mul255(SR, DA));
        ADst^.G := Clamp255(Mul255(SG, DA));
        ADst^.B := Clamp255(Mul255(SB, DA));
        ADst^.A := Clamp255(Mul255(SA, DA));
        Exit;
      end;

    fbmDstIn:
      begin
        ADst^.R := Clamp255(Mul255(DR, SA));
        ADst^.G := Clamp255(Mul255(DG, SA));
        ADst^.B := Clamp255(Mul255(DB, SA));
        ADst^.A := Clamp255(Mul255(DA, SA));
        Exit;
      end;

    fbmSrcOut:
      begin
        D1A := 255 - DA;
        ADst^.R := Clamp255(Mul255(SR, D1A));
        ADst^.G := Clamp255(Mul255(SG, D1A));
        ADst^.B := Clamp255(Mul255(SB, D1A));
        ADst^.A := Clamp255(Mul255(SA, D1A));
        Exit;
      end;

    fbmDstOut:
      begin
        S1A := 255 - SA;
        ADst^.R := Clamp255(Mul255(DR, S1A));
        ADst^.G := Clamp255(Mul255(DG, S1A));
        ADst^.B := Clamp255(Mul255(DB, S1A));
        ADst^.A := Clamp255(Mul255(DA, S1A));
        Exit;
      end;

    fbmSrcATop:
      begin
        S1A := 255 - SA;
        ADst^.R := Clamp255(Mul255(SR, DA) + Mul255(DR, S1A));
        ADst^.G := Clamp255(Mul255(SG, DA) + Mul255(DG, S1A));
        ADst^.B := Clamp255(Mul255(SB, DA) + Mul255(DB, S1A));
        ADst^.A := DA;
        Exit;
      end;

    fbmDstATop:
      begin
        D1A := 255 - DA;
        ADst^.R := Clamp255(Mul255(DR, SA) + Mul255(SR, D1A));
        ADst^.G := Clamp255(Mul255(DG, SA) + Mul255(SG, D1A));
        ADst^.B := Clamp255(Mul255(DB, SA) + Mul255(SB, D1A));
        ADst^.A := SA;
        Exit;
      end;

    fbmXor:
      begin
        S1A := 255 - SA;
        D1A := 255 - DA;
        ADst^.R := Clamp255(Mul255(SR, D1A) + Mul255(DR, S1A));
        ADst^.G := Clamp255(Mul255(SG, D1A) + Mul255(DG, S1A));
        ADst^.B := Clamp255(Mul255(SB, D1A) + Mul255(DB, S1A));
        ADst^.A := Clamp255(Mul255(SA, D1A) + Mul255(DA, S1A));
        Exit;
      end;

    fbmPlus:
      begin
        ADst^.R := Clamp255(SR + DR);
        ADst^.G := Clamp255(SG + DG);
        ADst^.B := Clamp255(SB + DB);
        ADst^.A := Clamp255(SA + DA);
        Exit;
      end;

    fbmModulate:
      begin
        ADst^.R := Clamp255(Mul255(SR, DR));
        ADst^.G := Clamp255(Mul255(SG, DG));
        ADst^.B := Clamp255(Mul255(SB, DB));
        ADst^.A := Clamp255(Mul255(SA, DA));
        Exit;
      end;
  end;

  // --- Separable and Non-separable blend modes ---
  // These use SrcOver compositing with the blend function applied to
  // unpremultiplied color channels.

  // Compute output alpha: αo = αs + αd - αs * αd
  OutA := SA + DA - Mul255(SA, DA);
  if OutA = 0 then
  begin
    ADst^.R := 0; ADst^.G := 0; ADst^.B := 0; ADst^.A := 0;
    Exit;
  end;

  // Unpremultiply source and destination channels
  if SA > 0 then
  begin
    SRu := (SR * 255 + (SA shr 1)) div SA;
    SGu := (SG * 255 + (SA shr 1)) div SA;
    SBu := (SB * 255 + (SA shr 1)) div SA;
    if SRu > 255 then SRu := 255;
    if SGu > 255 then SGu := 255;
    if SBu > 255 then SBu := 255;
  end
  else
  begin
    SRu := 0; SGu := 0; SBu := 0;
  end;

  if DA > 0 then
  begin
    DRu := (DR * 255 + (DA shr 1)) div DA;
    DGu := (DG * 255 + (DA shr 1)) div DA;
    DBu := (DB * 255 + (DA shr 1)) div DA;
    if DRu > 255 then DRu := 255;
    if DGu > 255 then DGu := 255;
    if DBu > 255 then DBu := 255;
  end
  else
  begin
    DRu := 0; DGu := 0; DBu := 0;
  end;

  // Apply separable blend function to each channel
  case ABlendMode of
    fbmMultiply:
      begin
        BRu := BlendMultiply(SRu, DRu);
        BGu := BlendMultiply(SGu, DGu);
        BBu := BlendMultiply(SBu, DBu);
      end;

    fbmScreen:
      begin
        BRu := BlendScreen(SRu, DRu);
        BGu := BlendScreen(SGu, DGu);
        BBu := BlendScreen(SBu, DBu);
      end;

    fbmOverlay:
      begin
        BRu := BlendOverlay(SRu, DRu);
        BGu := BlendOverlay(SGu, DGu);
        BBu := BlendOverlay(SBu, DBu);
      end;

    fbmDarken:
      begin
        BRu := BlendDarken(SRu, DRu);
        BGu := BlendDarken(SGu, DGu);
        BBu := BlendDarken(SBu, DBu);
      end;

    fbmLighten:
      begin
        BRu := BlendLighten(SRu, DRu);
        BGu := BlendLighten(SGu, DGu);
        BBu := BlendLighten(SBu, DBu);
      end;

    fbmColorDodge:
      begin
        BRu := BlendColorDodge(SRu, DRu);
        BGu := BlendColorDodge(SGu, DGu);
        BBu := BlendColorDodge(SBu, DBu);
      end;

    fbmColorBurn:
      begin
        BRu := BlendColorBurn(SRu, DRu);
        BGu := BlendColorBurn(SGu, DGu);
        BBu := BlendColorBurn(SBu, DBu);
      end;

    fbmHardLight:
      begin
        BRu := BlendHardLight(SRu, DRu);
        BGu := BlendHardLight(SGu, DGu);
        BBu := BlendHardLight(SBu, DBu);
      end;

    fbmSoftLight:
      begin
        BRu := BlendSoftLight(SRu, DRu);
        BGu := BlendSoftLight(SGu, DGu);
        BBu := BlendSoftLight(SBu, DBu);
      end;

    fbmDifference:
      begin
        BRu := BlendDifference(SRu, DRu);
        BGu := BlendDifference(SGu, DGu);
        BBu := BlendDifference(SBu, DBu);
      end;

    fbmExclusion:
      begin
        BRu := BlendExclusion(SRu, DRu);
        BGu := BlendExclusion(SGu, DGu);
        BBu := BlendExclusion(SBu, DBu);
      end;

    // Non-separable blend modes: process all 3 channels together
    fbmHue:
      begin
        BRu := SRu; BGu := SGu; BBu := SBu;
        SetSat(BRu, BGu, BBu, Sat(DRu, DGu, DBu));
        SetLum(BRu, BGu, BBu, Lum(DRu, DGu, DBu));
      end;

    fbmSaturation:
      begin
        BRu := DRu; BGu := DGu; BBu := DBu;
        SetSat(BRu, BGu, BBu, Sat(SRu, SGu, SBu));
        SetLum(BRu, BGu, BBu, Lum(DRu, DGu, DBu));
      end;

    fbmColor:
      begin
        BRu := SRu; BGu := SGu; BBu := SBu;
        SetLum(BRu, BGu, BBu, Lum(DRu, DGu, DBu));
      end;

    fbmLuminosity:
      begin
        BRu := DRu; BGu := DGu; BBu := DBu;
        SetLum(BRu, BGu, BBu, Lum(SRu, SGu, SBu));
      end;

  else
    // Fallback: SrcOver
    BRu := SRu;
    BGu := SGu;
    BBu := SBu;
  end;

  // Composite: Co = (αs × (1 - αd) × Cs + αd × (1 - αs) × Cd + αs × αd × B(Cs,Cd)) / αo
  // Clamp each channel result
  InvSA := 255 - SA;
  InvDA := 255 - DA;

  OutR := (Mul255(SA, Mul255(InvDA, SRu)) + Mul255(DA, Mul255(InvSA, DRu)) + Mul255(Mul255(SA, DA), BRu));
  OutG := (Mul255(SA, Mul255(InvDA, SGu)) + Mul255(DA, Mul255(InvSA, DGu)) + Mul255(Mul255(SA, DA), BGu));
  OutB := (Mul255(SA, Mul255(InvDA, SBu)) + Mul255(DA, Mul255(InvSA, DBu)) + Mul255(Mul255(SA, DA), BBu));

  // Divide by output alpha to get unpremultiplied, then re-premultiply
  // Actually we already have premultiplied form: just store with proper alpha
  ADst^.R := Clamp255(OutR);
  ADst^.G := Clamp255(OutG);
  ADst^.B := Clamp255(OutB);
  ADst^.A := Clamp255(OutA);
end;

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

procedure FloriaBlendPixel(ADst: PBlendPixel; const ASrc: TBlendPixel; ABlendMode: TFloriaBlendMode; ACover: Byte = 255);
begin
  DoBlendPixel(ADst, ASrc, ABlendMode, ACover);
end;

procedure FloriaBlendScanline(ADst, ASrc: PBlendPixel; AWidth: Integer; ABlendMode: TFloriaBlendMode; ACover: Byte = 255);
var
  I: Integer;
begin
  for I := 0 to AWidth - 1 do
  begin
    DoBlendPixel(ADst, ASrc^, ABlendMode, ACover);
    Inc(ADst);
    Inc(ASrc);
  end;
end;

procedure FloriaBlendFill(ADst: PBlendPixel; AWidth: Integer; const ASrc: TBlendPixel; ABlendMode: TFloriaBlendMode; ACover: Byte = 255);
var
  I: Integer;
begin
  for I := 0 to AWidth - 1 do
  begin
    DoBlendPixel(ADst, ASrc, ABlendMode, ACover);
    Inc(ADst);
  end;
end;

function FloriaBlendModeName(AMode: TFloriaBlendMode): string;
const
  Names: array[TFloriaBlendMode] of string = (
    'Clear', 'Src', 'Dst', 'SrcOver', 'DstOver',
    'SrcIn', 'DstIn', 'SrcOut', 'DstOut',
    'SrcATop', 'DstATop', 'Xor', 'Plus', 'Modulate',
    'Multiply', 'Screen', 'Overlay', 'Darken', 'Lighten',
    'ColorDodge', 'ColorBurn', 'HardLight', 'SoftLight',
    'Difference', 'Exclusion',
    'Hue', 'Saturation', 'Color', 'Luminosity'
  );
begin
  Result := Names[AMode];
end;

procedure FloriaAggBlendAdaptor(this: pixel_formats_ptr; op: unsigned; p: int8u_ptr; cr, cg, cb, ca, cover: unsigned);
var
  Src: TBlendPixel;
  Mode: TFloriaBlendMode;
begin
  if (cover = 0) or (ca = 0) then Exit;
  if op > Ord(High(TFloriaBlendMode)) then Exit;
  Mode := TFloriaBlendMode(op);
  // Source color passed by AggPas is straight RGB (cr, cg, cb) in range 0..255 and alpha (ca) in range 0..255
  // Premultiply source:
  Src.R := (cr * ca + 255) shr 8;
  Src.G := (cg * ca + 255) shr 8;
  Src.B := (cb * ca + 255) shr 8;
  Src.A := Byte(ca);
  DoBlendPixel(PBlendPixel(p), Src, Mode, Byte(cover));
end;

end.
