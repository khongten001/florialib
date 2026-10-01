{ Unit Floria.XCB.Composite — Pascal binding for X11 Composite Extension ('xcb-composite') }

unit Floria.XCB.Composite;

{$mode objfpc}{$H+}

interface

uses
  Floria.XCB,
  Floria.XCB.XFixes;

const
  XCB_COMPOSITE_MAJOR_VERSION = 0;
  XCB_COMPOSITE_MINOR_VERSION = 4;

  // Redirection update modes
  XCB_COMPOSITE_REDIRECT_AUTOMATIC = 0;
  XCB_COMPOSITE_REDIRECT_MANUAL    = 1;

type
  Pxcb_composite_query_version_cookie_t = ^xcb_composite_query_version_cookie_t;
  xcb_composite_query_version_cookie_t = record
    sequence: Cardinal;
  end;

  Pxcb_composite_query_version_reply_t = ^xcb_composite_query_version_reply_t;
  xcb_composite_query_version_reply_t = record
    response_type: Byte;
    pad0         : Byte;
    sequence     : Word;
    length       : Cardinal;
    major_version: Cardinal;
    minor_version: Cardinal;
    pad1         : array[0..15] of Byte;
  end;

  Pxcb_composite_get_overlay_window_cookie_t = ^xcb_composite_get_overlay_window_cookie_t;
  xcb_composite_get_overlay_window_cookie_t = record
    sequence: Cardinal;
  end;

  Pxcb_composite_get_overlay_window_reply_t = ^xcb_composite_get_overlay_window_reply_t;
  xcb_composite_get_overlay_window_reply_t = record
    response_type: Byte;
    pad0         : Byte;
    sequence     : Word;
    length       : Cardinal;
    overlay_win  : xcb_window_t;
    pad1         : array[0..19] of Byte;
  end;

var
  xcb_composite_id: xcb_extension_t; cvar; external;

function xcb_composite_query_version(c: Pxcb_connection_t; client_major_version, client_minor_version: Cardinal): xcb_composite_query_version_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_query_version';
function xcb_composite_query_version_unchecked(c: Pxcb_connection_t; client_major_version, client_minor_version: Cardinal): xcb_composite_query_version_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_query_version_unchecked';
function xcb_composite_query_version_reply(c: Pxcb_connection_t; cookie: xcb_composite_query_version_cookie_t; e: PPxcb_generic_error_t): Pxcb_composite_query_version_reply_t; cdecl; external 'xcb-composite' name 'xcb_composite_query_version_reply';

function xcb_composite_redirect_window(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_redirect_window';
function xcb_composite_redirect_window_checked(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_redirect_window_checked';

function xcb_composite_redirect_subwindows(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_redirect_subwindows';
function xcb_composite_redirect_subwindows_checked(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_redirect_subwindows_checked';

function xcb_composite_unredirect_window(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_unredirect_window';
function xcb_composite_unredirect_window_checked(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_unredirect_window_checked';

function xcb_composite_unredirect_subwindows(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_unredirect_subwindows';
function xcb_composite_unredirect_subwindows_checked(c: Pxcb_connection_t; window: xcb_window_t; update: Byte): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_unredirect_subwindows_checked';

function xcb_composite_create_region_from_border_clip(c: Pxcb_connection_t; region: xcb_xfixes_region_t; window: xcb_window_t): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_create_region_from_border_clip';
function xcb_composite_create_region_from_border_clip_checked(c: Pxcb_connection_t; region: xcb_xfixes_region_t; window: xcb_window_t): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_create_region_from_border_clip_checked';

function xcb_composite_name_window_pixmap(c: Pxcb_connection_t; window: xcb_window_t; pixmap: xcb_pixmap_t): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_name_window_pixmap';
function xcb_composite_name_window_pixmap_checked(c: Pxcb_connection_t; window: xcb_window_t; pixmap: xcb_pixmap_t): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_name_window_pixmap_checked';

function xcb_composite_get_overlay_window(c: Pxcb_connection_t; window: xcb_window_t): xcb_composite_get_overlay_window_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_get_overlay_window';
function xcb_composite_get_overlay_window_unchecked(c: Pxcb_connection_t; window: xcb_window_t): xcb_composite_get_overlay_window_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_get_overlay_window_unchecked';
function xcb_composite_get_overlay_window_reply(c: Pxcb_connection_t; cookie: xcb_composite_get_overlay_window_cookie_t; e: PPxcb_generic_error_t): Pxcb_composite_get_overlay_window_reply_t; cdecl; external 'xcb-composite' name 'xcb_composite_get_overlay_window_reply';

function xcb_composite_release_overlay_window(c: Pxcb_connection_t; window: xcb_window_t): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_release_overlay_window';
function xcb_composite_release_overlay_window_checked(c: Pxcb_connection_t; window: xcb_window_t): xcb_void_cookie_t; cdecl; external 'xcb-composite' name 'xcb_composite_release_overlay_window_checked';

implementation

end.
