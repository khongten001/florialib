{ Unit Floria.XCB.Damage — Pascal binding for X11 Damage Extension ('xcb-damage') }

unit Floria.XCB.Damage;

{$mode objfpc}{$H+}

interface

uses
  Floria.XCB,
  Floria.XCB.XFixes;

const
  XCB_DAMAGE_MAJOR_VERSION = 1;
  XCB_DAMAGE_MINOR_VERSION = 1;

  // Damage event code
  XCB_DAMAGE_NOTIFY = 0;

  // Report Levels
  XCB_DAMAGE_REPORT_LEVEL_RAW_RECTANGLES   = 0;
  XCB_DAMAGE_REPORT_LEVEL_DELTA_RECTANGLES = 1;
  XCB_DAMAGE_REPORT_LEVEL_BOUNDING_BOX     = 2;
  XCB_DAMAGE_REPORT_LEVEL_NON_EMPTY        = 3;

type
  xcb_damage_damage_t = Cardinal;
  Pxcb_damage_damage_t = ^xcb_damage_damage_t;

  xcb_damage_report_level_t = Byte;

  Pxcb_damage_query_version_cookie_t = ^xcb_damage_query_version_cookie_t;
  xcb_damage_query_version_cookie_t = record
    sequence: Cardinal;
  end;

  Pxcb_damage_query_version_reply_t = ^xcb_damage_query_version_reply_t;
  xcb_damage_query_version_reply_t = record
    response_type: Byte;
    pad0         : Byte;
    sequence     : Word;
    length       : Cardinal;
    major_version: Cardinal;
    minor_version: Cardinal;
    pad1         : array[0..15] of Byte;
  end;

  Pxcb_damage_notify_event_t = ^xcb_damage_notify_event_t;
  xcb_damage_notify_event_t = record
    response_type: Byte;
    level        : Byte;
    sequence     : Word;
    drawable     : xcb_drawable_t;
    damage       : xcb_damage_damage_t;
    timestamp    : xcb_timestamp_t;
    area         : xcb_rectangle_t;
    geometry     : xcb_rectangle_t;
  end;

var
  xcb_damage_id: xcb_extension_t; cvar; external;

function xcb_damage_query_version(c: Pxcb_connection_t; client_major_version, client_minor_version: Cardinal): xcb_damage_query_version_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_query_version';
function xcb_damage_query_version_unchecked(c: Pxcb_connection_t; client_major_version, client_minor_version: Cardinal): xcb_damage_query_version_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_query_version_unchecked';
function xcb_damage_query_version_reply(c: Pxcb_connection_t; cookie: xcb_damage_query_version_cookie_t; e: PPxcb_generic_error_t): Pxcb_damage_query_version_reply_t; cdecl; external 'xcb-damage' name 'xcb_damage_query_version_reply';

function xcb_damage_create(c: Pxcb_connection_t; damage: xcb_damage_damage_t; drawable: xcb_drawable_t; level: Byte): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_create';
function xcb_damage_create_checked(c: Pxcb_connection_t; damage: xcb_damage_damage_t; drawable: xcb_drawable_t; level: Byte): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_create_checked';

function xcb_damage_destroy(c: Pxcb_connection_t; damage: xcb_damage_damage_t): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_destroy';
function xcb_damage_destroy_checked(c: Pxcb_connection_t; damage: xcb_damage_damage_t): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_destroy_checked';

function xcb_damage_subtract(c: Pxcb_connection_t; damage: xcb_damage_damage_t; repair: xcb_xfixes_region_t; parts: xcb_xfixes_region_t): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_subtract';
function xcb_damage_subtract_checked(c: Pxcb_connection_t; damage: xcb_damage_damage_t; repair: xcb_xfixes_region_t; parts: xcb_xfixes_region_t): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_subtract_checked';

function xcb_damage_add(c: Pxcb_connection_t; drawable: xcb_drawable_t; region: xcb_xfixes_region_t): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_add';
function xcb_damage_add_checked(c: Pxcb_connection_t; drawable: xcb_drawable_t; region: xcb_xfixes_region_t): xcb_void_cookie_t; cdecl; external 'xcb-damage' name 'xcb_damage_add_checked';

implementation

end.
