# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioTokens
extends RefCounted
## Every value of the Studio design the app draws with, in px at the 1280×960 frame. Generated from the
## design's tokens: never edited by hand (a test fails on a hand edit).

const SHA256 := "0927926ffa11ba14e138cc2c03b94ebe593d5cd541e2eaf7ed61471562222ea6"

const INK := Color("#24201b")
const MUTE := Color("#857a6d")
const SATIN := Color("#fcfaf6")
const LINE := Color(0.27451, 0.203922, 0.133333, 0.13)
const NEUTRAL := Color("#a07850")
## Each console's gel, by its folder under res://carousel/consoles.
const GEL: Dictionary[StringName, Color] = {&"ps2_slim": Color("#2f6fc6"), &"psx": Color("#e09a12"), &"nes": Color("#d62b2b"), &"snes": Color("#6f5bc4"), &"n64": Color("#1e9e4a"), &"gc": Color("#7a5bd0"), &"wii": Color("#22a8e0"), &"xbox": Color("#4fa82a"), &"xbox360": Color("#93b92e"), &"gb": Color("#3a3fa0"), &"gbc": Color("#e2408a"), &"gba": Color("#3d4fc4")}
const LIVE: Array[StringName] = [&"GEL_FADE_S", &"ARRIVE_S", &"FLY_S", &"BOUNCE_S", &"PAUSE_S", &"TR_GAMES_FADE_S", &"TR_GAMES_RAIL_S", &"TR_GAMES_DROP_PX", &"TR_GAMES_LOGO_S", &"TR_GAMES_LOGO_S_CURVE", &"TR_GAMES_RAIL_BACK_S", &"TR_GAMES_HINTS_S", &"TR_RING_OPEN_S", &"TR_RING_OPEN_S_CURVE", &"TR_RING_SINK_S", &"TR_RING_RISE_S", &"TR_RING_RISE_S_CURVE", &"TR_RING_RISE_AT_S", &"TR_RING_MARKS_S", &"TR_RING_MARKS_AT_S", &"TR_RING_MIDDLE_AT_S", &"TR_RING_MIDDLE_S", &"TR_RING_MIDDLE_S_CURVE", &"TR_RING_CLOSE_S", &"TR_RING_CLOSE_S_CURVE", &"TR_FORM_OPEN_S", &"TR_FORM_OPEN_S_CURVE", &"TR_FORM_AT_S", &"TR_FORM_FADE_S", &"TR_FORM_OUT_S", &"TR_FORM_SLIDE_PX", &"TR_FORM_LIFT_PX", &"TR_FORM_BACK_S", &"TR_FORM_BACK_S_CURVE", &"TR_FORM_LEAVE_S", &"TR_CHOOSER_OPEN_S", &"TR_CHOOSER_AT_S", &"TR_CHOOSER_OUT_S", &"TR_CHOOSER_LINES_AT_S", &"TR_CHOOSER_LAYER_S", &"TR_CHOOSER_MODEL_S", &"TR_CHOOSER_CARD_S", &"TR_CHOOSER_CARD_S_CURVE", &"TR_CHOOSER_SHIFT_PX", &"TR_CHOOSER_TITLE_PX", &"TR_CHOOSER_IN_S", &"TR_FORM_CHOOSER_TITLE_PX", &"TR_PLACE_BACK_S", &"TR_PLACE_ARC_PX", &"TR_PLACE_OTHERS_S", &"TR_PLACE_MARKS_S", &"TR_PLACE_AT_S", &"TR_SETTINGS_OPEN_S", &"TR_SETTINGS_OPEN_S_CURVE", &"TR_SETTINGS_LEAVE_S", &"TR_SETTINGS_LEAVE_S_CURVE", &"TR_SETTINGS_RECEDE", &"TR_SETTINGS_DROP_PX", &"TR_SETTINGS_SINK_S", &"TR_SETTINGS_SINK_S_CURVE", &"TR_SETTINGS_VEIL_AT_S", &"TR_SETTINGS_VEIL_S", &"TR_SETTINGS_CARD_AT_S", &"TR_SETTINGS_RISE_PX", &"TR_SETTINGS_HINTS_S", &"TR_SETTINGS_CLOSE_S", &"TR_SETTINGS_CARD_OUT_S", &"TR_SETTINGS_CARD_OUT_S_CURVE", &"TR_SETTINGS_BACK_AT_S", &"TR_SETTINGS_CARD_S", &"TR_SETTINGS_CARD_S_CURVE", &"TR_PROPERTIES_OPEN_S", &"TR_PROPERTIES_TRAVEL_S", &"TR_PROPERTIES_TRAVEL_S_CURVE", &"TR_PROPERTIES_FADE_S", &"TR_PROPERTIES_POOL_S", &"TR_PROPERTIES_POOL_S_CURVE", &"TR_PROPERTIES_ZONE_AT_S", &"TR_PROPERTIES_NAME_AT_S", &"TR_PROPERTIES_RISE_PX", &"TR_PROPERTIES_CALLOUT_AT_S", &"TR_PROPERTIES_BACK_S", &"TR_BALL_MORPH_S", &"TR_REVERSE", &"TR_SETTLE_S"]

const CONTROL_EDITS: Dictionary = {}
const CONTROL_STYLES: Dictionary = {}

## The chrome every screen shares.
const CLOCK := Rect2(29.0, 29.0, 94.0, 35.0)
const BATTERY := Rect2(1123.0, 29.0, 125.0, 35.0)
const PLUS := Rect2(608.0, 29.0, 64.0, 64.0)
## The hint row's left, top and height; its width is its content's.
const HINTS := Rect2(40.0, 878.0, 520.0, 44.0)
const HINTS_PADDING_LEFT := 6.4
const HINTS_PADDING_RIGHT := 17.92
const HINTS_GAP := 20.48
const HINT_GAP := 7.68
const HINT_SEPARATOR := Vector2(1.0, 23.04)
const PILL_GAP := 6.4
const BOLT_HEIGHT := 21.76
const BOLT_VIEW := Vector2(12.0, 18.0)
const BOLT_SHAPE: Array[Vector2] = [Vector2(7.0, 0.0), Vector2(0.0, 10.5), Vector2(5.0, 10.5), Vector2(4.0, 18.0), Vector2(12.0, 7.0), Vector2(7.0, 7.0), Vector2(8.0, 0.0)]
const BOLT := Color("#e8962a")
const KEY_SIZE := 32.0
## A key named by more than a letter (the pad's arrows, a word): a capsule.
const PAD_KEY_WIDTH := 58.88
const PAD_KEY_RADIUS := 16.0
const PLUS_BAR := Vector2(28.16, 5.38)
const PLUS_BAR_RADIUS := 2.56

## The design's faces, family and weight; and its text roles, each one a face, a size in px, a tracking in em
## and whether its figures are tabular.
enum Face { JAKARTA_500, JAKARTA_700, JAKARTA_800, PLEX_500, PLEX_600 }
enum Role { HINT, PILL, KEY }
const ROLE_FACE: Array[Face] = [Face.JAKARTA_700, Face.JAKARTA_700, Face.JAKARTA_800]
const ROLE_PX: Array[float] = [23.04, 23.68, 17.28]
const ROLE_TRACKING: Array[float] = [0.0, 0.0, 0.0]
const ROLE_TNUM: Array[bool] = [false, true, false]

## The materials: a fill (stops, colours, and the centre of a radial fill in parts of the box, or (-1, -1)
## for a fill from top to bottom), a corner radius, and shadows as [Vector4(x, y, blur, spread), colour,
## inset, tinted by the gel], the insets first, each group in CSS order (the first one drawn on top).
const SATIN_STOPS: Array[float] = [0.0, 1.0]
const SATIN_COLORS: Array[Color] = [Color(1, 0.992157, 0.976471, 1), Color(0.956863, 0.937255, 0.905882, 1)]
const SATIN_CENTRE := Vector2(-1, -1)
const SATIN_RADIUS := 14.08
const SATIN_SHADOWS := [[Vector4(0.0, 1.28, 0.0, 0.0), Color(1, 1, 1, 1), true, false], [Vector4(0.0, 1.54, 2.56, 0.0), Color(0.27451, 0.203922, 0.133333, 0.14), false, false], [Vector4(0.0, 10.24, 20.48, -6.4), Color(0.27451, 0.203922, 0.133333, 0.28), false, false]]
const FROST_STOPS: Array[float] = [0.0, 1.0]
const FROST_COLORS: Array[Color] = [Color(1, 0.988235, 0.968627, 0.62), Color(1, 0.988235, 0.968627, 0.62)]
const FROST_CENTRE := Vector2(-1, -1)
const FROST_RADIUS := 12.8
const FROST_SHADOWS := [[Vector4(0.0, 1.28, 0.0, 0.0), Color(1, 1, 1, 0.9), true, false], [Vector4(0.0, 1.28, 2.56, 0.0), Color(0.27451, 0.203922, 0.133333, 0.12), false, false], [Vector4(0.0, 6.4, 15.36, -5.12), Color(0.27451, 0.203922, 0.133333, 0.22), false, false]]
const KEY_STOPS: Array[float] = [0.0, 0.7]
const KEY_COLORS: Array[Color] = [Color(0.352941, 0.32549, 0.294118, 1), Color(0.141176, 0.12549, 0.105882, 1)]
const KEY_CENTRE := Vector2(0.38, 0.3)
const KEY_RADIUS := 16.0
const KEY_SHADOWS := [[Vector4(0.0, 1.54, 2.56, 0.0), Color(0.117647, 0.0784314, 0.0392157, 0.35), false, false]]
const PLUS_STOPS: Array[float] = [0.0, 0.55, 1.0]
const PLUS_COLORS: Array[Color] = [Color(1, 1, 1, 1), Color(0.956863, 0.937255, 0.905882, 1), Color(0.866667, 0.831373, 0.780392, 1)]
const PLUS_CENTRE := Vector2(0.36, 0.3)
const PLUS_RADIUS := 32.0
const PLUS_SHADOWS := [[Vector4(0.0, -2.56, 5.12, 0.0), Color(0.27451, 0.203922, 0.133333, 0.12), true, false], [Vector4(0.0, 2.56, 3.84, 0.0), Color(0.27451, 0.203922, 0.133333, 0.18), false, false], [Vector4(0.0, 12.8, 23.04, -7.68), Color(0.27451, 0.203922, 0.133333, 0.35), false, false]]
const PLINTH_STOPS: Array[float] = [0.0, 0.235955, 0.235955, 1.0]
const PLINTH_COLORS: Array[Color] = [Color(0.992157, 0.984314, 0.968627, 1), Color(0.964706, 0.94902, 0.921569, 1), Color(0.921569, 0.894118, 0.85098, 1), Color(0.894118, 0.866667, 0.819608, 1)]
const PLINTH_CENTRE := Vector2(-1, -1)
const PLINTH_RADIUS := 17.92
const PLINTH_SHADOWS := [[Vector4(0.0, 1.54, 0.0, 0.0), Color("#fff"), true, false], [Vector4(0.0, -3.84, 0.0, 0.0), Color(1, 1, 1, 1.0), true, true, 0.7], [Vector4(0.0, 25.6, 38.4, -17.92), Color(0.27451, 0.203922, 0.133333, 0.4), false, false]]
const FOCUS_RADIUS := 17.92
## The focused card: the satin fill with its ring and glow in the gel's colour and its own drop shadow.
const FOCUS_SHADOWS := [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#fff"), true, false], [Vector4(0.0, 0.0, 0.0, 4.86), Color(1, 1, 1, 1.0), false, true], [Vector4(0.0, 0.0, 20.48, 2.56), Color(1, 1, 1, 0.35), false, true], [Vector4(0.0, 15.36, 25.6, -7.68), Color(0.27451, 0.203922, 0.133333, 0.35), false, false]]
## Every material the app draws, by its look: [stops, colours, centre, radius, shadows]; the focused card is
## the satin with the focus ring's radius and shadows.
enum Look { SATIN, FROST, KEY, PLUS, FOCUS, PLINTH }
const LOOKS := [[SATIN_STOPS, SATIN_COLORS, SATIN_CENTRE, SATIN_RADIUS, SATIN_SHADOWS], [FROST_STOPS, FROST_COLORS, FROST_CENTRE, FROST_RADIUS, FROST_SHADOWS], [KEY_STOPS, KEY_COLORS, KEY_CENTRE, KEY_RADIUS, KEY_SHADOWS], [PLUS_STOPS, PLUS_COLORS, PLUS_CENTRE, PLUS_RADIUS, PLUS_SHADOWS], [SATIN_STOPS, SATIN_COLORS, SATIN_CENTRE, FOCUS_RADIUS, FOCUS_SHADOWS], [PLINTH_STOPS, PLINTH_COLORS, PLINTH_CENTRE, PLINTH_RADIUS, PLINTH_SHADOWS]]

## The cyclorama's glows over its baked wall and floor, bottom first: [centre, radii, colour at the centre,
## last stop as a part of the radii, whether the gel tints it].
const BACKDROP_GLOWS := [[Vector2(640.0, 716.8), Vector2(435.2, 89.6), Color(1, 1, 1, 0.16), 0.7, true], [Vector2(921.6, 192.0), Vector2(512.0, 384.0), Color(1, 1, 1, 0.42), 0.7, true], [Vector2(640.0, 288.0), Vector2(742.4, 409.6), Color(1, 0.976471, 0.933333, 0.85), 0.72, false], [Vector2(640.0, 678.4), Vector2(563.2, 115.2), Color(1, 0.988235, 0.964706, 0.9), 0.7, false]]

## The Type chooser's plinth: its box on the screen; inside it, its top's soft shadow (box and colour at the
## centre, fading to nothing at its edge) and the plate holding the logo; and the turntable's view over it.
const PLINTH := Rect2(57.6, 570.88, 422.4, 227.84)
const PLINTH_TOP_SHADOW := Rect2(38.4, 7.68, 345.6, 38.4)
const PLINTH_TOP_SHADE := Color(0.235294, 0.172549, 0.109804, 0.28)
const PLINTH_PLATE := Rect2(30.72, 69.12, 360.96, 115.2)
const TURNTABLE := Rect2(38.4, 166.4, 460.8, 499.2)
## The games' softness by their distance from the centre: a neighbour's blur (px) and saturation, and the
## warm shadow (down px, CSS blur px, alpha) of the chosen game and of a neighbour.
const SOFT_BLUR := 1.1
const SOFT_SATURATION := 0.92
const CHOSEN_SHADOW := Vector3(12.0, 22.0, 0.2)
const SIDE_SHADOW := Vector3(8.0, 14.0, 0.28)

## The rail and games row's spring: stiffness and damping, unit mass.
const SPRING_STIFFNESS := 280.0
const SPRING_DAMPING := 25.0

## The backdrops the app can draw, and each one's values ([Palette] reads them): its colours, its materials
## (as [constant LOOKS]), the project theme's items it changes, the viewport's clear colour, the consoles' room
## light, whether the logos take their dark-background pictures, its wall (`studio`: the baked studio, its glows
## and the rail's pool of light; `mapped`: the studio's lightness mapped from its low to its high colour; `black`),
## its pixel veil's colours (one to three) and their spread (`pixels`: one colour per pixel, at random; `waves`:
## mixed in big slow waves), and the properties' operating light.
enum Scheme { LIGHT, DARK, LIGHT_GREY, ANTHRACITE }
const SCHEMES: Array[Dictionary] = [
	{&"ink": INK, &"mute": MUTE, &"line": LINE, &"neutral": NEUTRAL, &"plinth_top_shade": PLINTH_TOP_SHADE, &"arrow_stroke": Color("#fffdf9"), &"arrow_shine": Color(1, 1, 1, 0.22), &"arrow_drop": Color(0.23529411764705882, 0.1568627450980392, 0.0784313725490196, 0.35), &"sticker_shadow": Color(0.23529411764705882, 0.1568627450980392, 0.0784313725490196, 0.38), &"callout_ring": Color("#ffffff"), &"ribbon_key_ink": Color("#ffffff"), &"key_mark": Color("#24201b"), &"form_off": Color(1.0, 0.988235, 0.968627, 0.5), &"toggle_off_track": Color("#e3dbcf"), &"warm_shadow": Color(0.27450980392156865, 0.20392156862745098, 0.13333333333333333, 1.0), &"knob_top": Color("#ffffff"), &"toggle_knob_edge": Color("#f1ebe2"), &"switch_knob_middle": Color("#f4efe7"), &"switch_knob_edge": Color("#e2d9cc"), &"switch_track_off": Color("#ddd4c7"), &"switch_shadow_knob": Color(0.27451, 0.203922, 0.133333, 0.3), &"switch_shadow_track": Color(0.27451, 0.203922, 0.133333, 0.25), &"smoothing_ground": Color(0.933, 0.949, 0.965, 1.0), &"smoothing_disc": Color(0.059, 0.059, 0.078, 1.0), &"scrim": Color(0.235294, 0.172549, 0.117647, 0.16), &"caret": Color("#24201b"), &"toggle_warm": Color(0.27451, 0.203922, 0.133333, 1.0), &"looks": LOOKS, &"theme": {}, &"clear": Color("#4d4d4d"), &"room_light": 0.55, &"dark_logos": false, &"wall": &"studio", &"wall_low": Color("#000"), &"wall_high": Color("#000"), &"veil_base": Color(0.91, 0.89, 0.85, 1.0), &"veil_colours": [Color("#24201b")], &"veil_spread": &"pixels", &"operating_dark": Color(0.071, 0.078, 0.102, 1.0), &"operating_warm_alpha": 0.38, &"operating_pool": Color(0.1803921568627451, 0.12941176470588237, 0.08627450980392157, 0.5356000000000001), &"operating_pool_gel_share": 0.26138909634055263},
	{&"ink": Color("#ede7de"), &"mute": Color("#8f877c"), &"line": Color("#fff0e01a"), &"neutral": Color("#9a9288"), &"plinth_top_shade": Color("#00000080"), &"arrow_stroke": Color("#151311"), &"arrow_shine": Color("#ffffff0f"), &"arrow_drop": Color("#000000c4"), &"sticker_shadow": Color("#000000d5"), &"callout_ring": Color("#000000"), &"ribbon_key_ink": Color("#141210"), &"key_mark": Color("#2a2723"), &"form_off": Color("#2a272399"), &"toggle_off_track": Color("#3a3631"), &"warm_shadow": Color("#000000"), &"knob_top": Color("#f0ebe3"), &"toggle_knob_edge": Color("#c9c2b7"), &"switch_knob_middle": Color("#d9d3ca"), &"switch_knob_edge": Color("#bdb6ab"), &"switch_track_off": Color("#3a3631"), &"switch_shadow_knob": Color("#000000a8"), &"switch_shadow_track": Color("#0000008c"), &"smoothing_ground": Color("#0c0b0a"), &"smoothing_disc": Color("#dcd8d0"), &"scrim": Color("#0000008c"), &"caret": Color("#ede7de"), &"toggle_warm": Color("#000000"), &"looks": [[SATIN_STOPS, [Color("#1c1a17"), Color("#151311")], SATIN_CENTRE, SATIN_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 1.54, 2.56, 0.0), Color("#00000080"), false, false], [Vector4(0.0, 10.24, 20.48, -6.4), Color("#00000099"), false, false]]], [FROST_STOPS, [Color("#1e1c19c7"), Color("#1e1c19c7")], FROST_CENTRE, FROST_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 6.4, 15.36, -5.12), Color("#00000080"), false, false]]], [KEY_STOPS, [Color("#4a453f"), Color("#2a2723")], KEY_CENTRE, KEY_RADIUS, [[Vector4(0.0, 1.54, 2.56, 0.0), Color("#00000080"), false, false]]], [PLUS_STOPS, [Color("#3a3631"), Color("#262320"), Color("#1c1a17")], PLUS_CENTRE, PLUS_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 12.8, 23.04, -7.68), Color("#00000099"), false, false]]], [SATIN_STOPS, [Color("#1c1a17"), Color("#151311")], SATIN_CENTRE, FOCUS_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 0.0, 0.0, 4.86), Color("#ffffff"), false, true], [Vector4(0.0, 0.0, 20.48, 2.56), Color("#ffffff59"), false, true], [Vector4(0.0, 15.36, 25.6, -7.68), Color("#00000099"), false, false]]], [PLINTH_STOPS, [Color("#2a2724"), Color("#221f1c"), Color("#1c1a17"), Color("#151311")], PLINTH_CENTRE, PLINTH_RADIUS, [[Vector4(0.0, 1.54, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, -3.84, 0.0, 0.0), Color("#ffffff80"), true, true, 0.7], [Vector4(0.0, 25.6, 38.4, -17.92), Color("#000000b3"), false, false]]]], &"theme": {"Button/colors/font_color": Color("#ede7de"), "Button/colors/font_disabled_color": Color("#ede7de73"), "Button/colors/font_focus_color": Color("#ede7de"), "Button/colors/font_hover_color": Color("#ede7de"), "Button/colors/font_pressed_color": Color("#ede7de"), "Button/colors/font_hover_pressed_color": Color("#ede7de"), "Button/styles/pressed/bg_color": Color("#2a2723"), "Button/styles/pressed/border_color": Color("#ede7de24"), "Button/styles/pressed/shadow_color": Color("#ede7de99"), "Field/styles/pressed/bg_color": Color("#2a2723"), "Field/styles/pressed/shadow_color": Color("#ede7de99"), "Pill/styles/panel/bg_color": Color("#2a2723eb"), "Pill/styles/panel/shadow_color": Color("#00000043"), "ArtBar/styles/background/bg_color": Color("#ede7de24"), "ArtBar/styles/background/shadow_color": Color("#ede7de99"), "ArtBar/styles/fill/bg_color": Color("#ede7de"), "ArtBar/styles/fill/shadow_color": Color("#ede7de99"), "ArtBarStalled/styles/background/bg_color": Color("#ede7de24"), "ArtBarStalled/styles/background/shadow_color": Color("#ede7de99"), "ArtBarStalled/styles/fill/bg_color": Color("#8f877c"), "ArtBarStalled/styles/fill/shadow_color": Color("#ede7de99"), "NameButton/colors/font_outline_color": Color("#00000000"), "RibbonKeyOn/styles/panel/bg_color": Color("#ede7de"), "RibbonKeyOn/styles/panel/shadow_color": Color("#ede7de99"), "SearchCount/colors/font_color": Color("#8f877c"), "ScreenText/colors/font_color": Color("#ede7de"), "ConsoleModel/colors/font_color": Color("#8f877c"), "Status/colors/font_color": Color("#ede7de"), "RowValue/colors/font_color": Color("#8f877c"), "Label/colors/font_color": Color("#ede7de"), "Label/colors/font_outline_color": Color("#00000000"), "RibbonTextOn/colors/font_color": Color("#141210")}, &"clear": Color("#000000"), &"room_light": 0.4, &"dark_logos": true, &"wall": &"black", &"wall_low": Color("#000"), &"wall_high": Color("#000"), &"veil_base": Color("#000000"), &"veil_colours": [Color("#ffffff")], &"veil_spread": &"pixels", &"operating_dark": Color("#000000"), &"operating_warm_alpha": 0.0, &"operating_pool": Color("#00000099"), &"operating_pool_gel_share": 0.0},
	{&"ink": Color("#1e2024"), &"mute": Color("#797b7e"), &"line": Color("#34363a21"), &"neutral": Color("#7c7d81"), &"plinth_top_shade": Color("#2c2e3147"), &"arrow_stroke": Color("#fbfdff"), &"arrow_shine": Color("#fdfeff38"), &"arrow_drop": Color("#292a2e59"), &"sticker_shadow": Color("#292a2e61"), &"callout_ring": Color("#fdfeff"), &"ribbon_key_ink": Color("#fdfeff"), &"key_mark": Color("#1e1f23"), &"form_off": Color("#fafcff80"), &"toggle_off_track": Color("#dadbdf"), &"warm_shadow": Color("#34363a"), &"knob_top": Color("#fdfeff"), &"toggle_knob_edge": Color("#eaebef"), &"switch_knob_middle": Color("#edeff3"), &"switch_knob_edge": Color("#d8d9dd"), &"switch_track_off": Color("#d3d4d8"), &"switch_shadow_knob": Color("#34363a4d"), &"switch_shadow_track": Color("#34363a40"), &"smoothing_ground": Color("#eff1f4"), &"smoothing_disc": Color("#0d0f12"), &"scrim": Color("#2c2e3129"), &"caret": Color("#1e2024"), &"toggle_warm": Color("#34363a"), &"looks": [[SATIN_STOPS, [Color("#fbfdff"), Color("#edeff3")], SATIN_CENTRE, SATIN_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#fdfeff"), true, false], [Vector4(0.0, 1.54, 2.56, 0.0), Color("#34363a24"), false, false], [Vector4(0.0, 10.24, 20.48, -6.4), Color("#34363a47"), false, false]]], [FROST_STOPS, [Color("#fafcff9e"), Color("#fafcff9e")], FROST_CENTRE, FROST_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#fdfeffe6"), true, false], [Vector4(0.0, 1.28, 2.56, 0.0), Color("#34363a1f"), false, false], [Vector4(0.0, 6.4, 15.36, -5.12), Color("#34363a38"), false, false]]], [KEY_STOPS, [Color("#525357"), Color("#1e2024")], KEY_CENTRE, KEY_RADIUS, [[Vector4(0.0, 1.54, 2.56, 0.0), Color("#13151859"), false, false]]], [PLUS_STOPS, [Color("#fdfeff"), Color("#edeff3"), Color("#d3d4d8")], PLUS_CENTRE, PLUS_RADIUS, [[Vector4(0.0, -2.56, 5.12, 0.0), Color("#34363a1f"), true, false], [Vector4(0.0, 2.56, 3.84, 0.0), Color("#34363a2e"), false, false], [Vector4(0.0, 12.8, 23.04, -7.68), Color("#34363a59"), false, false]]], [SATIN_STOPS, [Color("#fbfdff"), Color("#edeff3")], SATIN_CENTRE, FOCUS_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#fdfeff"), true, false], [Vector4(0.0, 0.0, 0.0, 4.86), Color("#fdfeff"), false, true], [Vector4(0.0, 0.0, 20.48, 2.56), Color("#fdfeff59"), false, true], [Vector4(0.0, 15.36, 25.6, -7.68), Color("#34363a59"), false, false]]], [PLINTH_STOPS, [Color("#f9fbfe"), Color("#f0f2f5"), Color("#e3e4e8"), Color("#dcdde1")], PLINTH_CENTRE, PLINTH_RADIUS, [[Vector4(0.0, 1.54, 0.0, 0.0), Color("#fdfeff"), true, false], [Vector4(0.0, -3.84, 0.0, 0.0), Color("#fdfeff"), true, true, 0.7], [Vector4(0.0, 25.6, 38.4, -17.92), Color("#34363a66"), false, false]]]], &"theme": {"Button/colors/font_color": Color("#1e2024"), "Button/colors/font_disabled_color": Color("#1e202473"), "Button/colors/font_focus_color": Color("#1e2024"), "Button/colors/font_hover_color": Color("#1e2024"), "Button/colors/font_pressed_color": Color("#1e2024"), "Button/colors/font_hover_pressed_color": Color("#1e2024"), "Button/styles/pressed/bg_color": Color("#edeff3"), "Button/styles/pressed/border_color": Color("#1e202424"), "Button/styles/pressed/shadow_color": Color("#00000399"), "Field/styles/pressed/bg_color": Color("#edeff3"), "Field/styles/pressed/border_color": Color("#cacbcf"), "Field/styles/pressed/shadow_color": Color("#00000399"), "Pill/styles/panel/bg_color": Color("#f8fafdeb"), "Pill/styles/panel/border_color": Color("#cacbcf"), "Pill/styles/panel/shadow_color": Color("#34363a1f"), "ArtBar/styles/background/bg_color": Color("#1e202424"), "ArtBar/styles/background/border_color": Color("#cacbcf"), "ArtBar/styles/background/shadow_color": Color("#00000399"), "ArtBar/styles/fill/bg_color": Color("#1e2024"), "ArtBar/styles/fill/border_color": Color("#cacbcf"), "ArtBar/styles/fill/shadow_color": Color("#00000399"), "ArtBarStalled/styles/background/bg_color": Color("#1e202424"), "ArtBarStalled/styles/background/border_color": Color("#cacbcf"), "ArtBarStalled/styles/background/shadow_color": Color("#00000399"), "ArtBarStalled/styles/fill/bg_color": Color("#797b7e"), "ArtBarStalled/styles/fill/border_color": Color("#cacbcf"), "ArtBarStalled/styles/fill/shadow_color": Color("#00000399"), "NameButton/colors/font_outline_color": Color("#fdfeff"), "RibbonKeyOn/styles/panel/bg_color": Color("#1e2024"), "RibbonKeyOn/styles/panel/border_color": Color("#cacbcf"), "RibbonKeyOn/styles/panel/shadow_color": Color("#00000399"), "SearchCount/colors/font_color": Color("#797b7e"), "ScreenText/colors/font_color": Color("#1e2024"), "ConsoleModel/colors/font_color": Color("#797b7e"), "Status/colors/font_color": Color("#1e2024"), "RowValue/colors/font_color": Color("#797b7e"), "Label/colors/font_color": Color("#1e2024"), "Label/colors/font_outline_color": Color("#fdfeff"), "RibbonTextOn/colors/font_color": Color("#fdfeff")}, &"clear": Color("#4d4d4d"), &"room_light": 0.55, &"dark_logos": false, &"wall": &"mapped", &"wall_low": Color("#c2c4c8"), &"wall_high": Color("#d9dadd"), &"veil_base": Color(0.814902, 0.820392, 0.833725, 1), &"veil_colours": [Color("#1e9e4a"), Color("#93b92e")], &"veil_spread": &"waves", &"operating_dark": Color(0.071, 0.078, 0.102, 0.0), &"operating_warm_alpha": 0.0, &"operating_pool": Color(0.1803921568627451, 0.12941176470588237, 0.08627450980392157, 0.0), &"operating_pool_gel_share": 0.0},
	{&"ink": Color("#ede7de"), &"mute": Color("#8f877c"), &"line": Color("#fff0e01a"), &"neutral": Color("#9a9288"), &"plinth_top_shade": Color("#00000080"), &"arrow_stroke": Color("#151311"), &"arrow_shine": Color("#ffffff0f"), &"arrow_drop": Color("#000000c4"), &"sticker_shadow": Color("#000000d5"), &"callout_ring": Color("#000000"), &"ribbon_key_ink": Color("#141210"), &"key_mark": Color("#2a2723"), &"form_off": Color("#2a272399"), &"toggle_off_track": Color("#3a3631"), &"warm_shadow": Color("#000000"), &"knob_top": Color("#f0ebe3"), &"toggle_knob_edge": Color("#c9c2b7"), &"switch_knob_middle": Color("#d9d3ca"), &"switch_knob_edge": Color("#bdb6ab"), &"switch_track_off": Color("#3a3631"), &"switch_shadow_knob": Color("#000000a8"), &"switch_shadow_track": Color("#0000008c"), &"smoothing_ground": Color("#0c0b0a"), &"smoothing_disc": Color("#dcd8d0"), &"scrim": Color("#0000008c"), &"caret": Color("#ede7de"), &"toggle_warm": Color("#000000"), &"looks": [[SATIN_STOPS, [Color("#1c1a17"), Color("#151311")], SATIN_CENTRE, SATIN_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 1.54, 2.56, 0.0), Color("#00000080"), false, false], [Vector4(0.0, 10.24, 20.48, -6.4), Color("#00000099"), false, false]]], [FROST_STOPS, [Color("#1e1c19c7"), Color("#1e1c19c7")], FROST_CENTRE, FROST_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 6.4, 15.36, -5.12), Color("#00000080"), false, false]]], [KEY_STOPS, [Color("#4a453f"), Color("#2a2723")], KEY_CENTRE, KEY_RADIUS, [[Vector4(0.0, 1.54, 2.56, 0.0), Color("#00000080"), false, false]]], [PLUS_STOPS, [Color("#3a3631"), Color("#262320"), Color("#1c1a17")], PLUS_CENTRE, PLUS_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 12.8, 23.04, -7.68), Color("#00000099"), false, false]]], [SATIN_STOPS, [Color("#1c1a17"), Color("#151311")], SATIN_CENTRE, FOCUS_RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, 0.0, 0.0, 4.86), Color("#ffffff"), false, true], [Vector4(0.0, 0.0, 20.48, 2.56), Color("#ffffff59"), false, true], [Vector4(0.0, 15.36, 25.6, -7.68), Color("#00000099"), false, false]]], [PLINTH_STOPS, [Color("#2a2724"), Color("#221f1c"), Color("#1c1a17"), Color("#151311")], PLINTH_CENTRE, PLINTH_RADIUS, [[Vector4(0.0, 1.54, 0.0, 0.0), Color("#ffffff12"), true, false], [Vector4(0.0, -3.84, 0.0, 0.0), Color("#ffffff80"), true, true, 0.7], [Vector4(0.0, 25.6, 38.4, -17.92), Color("#000000b3"), false, false]]]], &"theme": {"Button/colors/font_color": Color("#ede7de"), "Button/colors/font_disabled_color": Color("#ede7de73"), "Button/colors/font_focus_color": Color("#ede7de"), "Button/colors/font_hover_color": Color("#ede7de"), "Button/colors/font_pressed_color": Color("#ede7de"), "Button/colors/font_hover_pressed_color": Color("#ede7de"), "Button/styles/pressed/bg_color": Color("#2a2723"), "Button/styles/pressed/border_color": Color("#ede7de24"), "Button/styles/pressed/shadow_color": Color("#ede7de99"), "Field/styles/pressed/bg_color": Color("#2a2723"), "Field/styles/pressed/shadow_color": Color("#ede7de99"), "Pill/styles/panel/bg_color": Color("#2a2723eb"), "Pill/styles/panel/shadow_color": Color("#00000043"), "ArtBar/styles/background/bg_color": Color("#ede7de24"), "ArtBar/styles/background/shadow_color": Color("#ede7de99"), "ArtBar/styles/fill/bg_color": Color("#ede7de"), "ArtBar/styles/fill/shadow_color": Color("#ede7de99"), "ArtBarStalled/styles/background/bg_color": Color("#ede7de24"), "ArtBarStalled/styles/background/shadow_color": Color("#ede7de99"), "ArtBarStalled/styles/fill/bg_color": Color("#8f877c"), "ArtBarStalled/styles/fill/shadow_color": Color("#ede7de99"), "NameButton/colors/font_outline_color": Color("#00000000"), "RibbonKeyOn/styles/panel/bg_color": Color("#ede7de"), "RibbonKeyOn/styles/panel/shadow_color": Color("#ede7de99"), "SearchCount/colors/font_color": Color("#8f877c"), "ScreenText/colors/font_color": Color("#ede7de"), "ConsoleModel/colors/font_color": Color("#8f877c"), "Status/colors/font_color": Color("#ede7de"), "RowValue/colors/font_color": Color("#8f877c"), "Label/colors/font_color": Color("#ede7de"), "Label/colors/font_outline_color": Color("#00000000"), "RibbonTextOn/colors/font_color": Color("#141210")}, &"clear": Color("#000000"), &"room_light": 0.4, &"dark_logos": true, &"wall": &"mapped", &"wall_low": Color("#1e1f22"), &"wall_high": Color("#2b2c2f"), &"veil_base": Color(0.148235, 0.152157, 0.163922, 1), &"veil_colours": [Color("#9a9288")], &"veil_spread": &"pixels", &"operating_dark": Color("#00000000"), &"operating_warm_alpha": 0.0, &"operating_pool": Color("#00000000"), &"operating_pool_gel_share": 0.0},
]
## The pixel veil, tuned over one backdrop: its light, the gel whitened by a share, added at most this much; over a
## light wall, its ink lies this many times its step below the wall.
const VEIL_WHITENED := 0.3
const VEIL_ADDED := 0.2275
const VEIL_INK_DEPTH := 3.0
const VEIL_TUNED_OVER := Scheme.ANTHRACITE
## How much faster than the app's clock the veil's time runs.
const VEIL_TIME_SCALE := 1.35

## The timings the dev bridge may retune while the app runs ([constant LIVE]); the app reads them as
## constants. The gel's change is eased by the CSS curve `ease`.
static var GEL_FADE_S := 0.38
static var ARRIVE_S := 0.42
static var FLY_S := 0.46
static var BOUNCE_S := 0.2
static var PAUSE_S := 0.12
static var TR_GAMES_FADE_S := 0.2
static var TR_GAMES_RAIL_S := 0.3
static var TR_GAMES_DROP_PX := 51.2
static var TR_GAMES_LOGO_S := 0.0
static var TR_GAMES_LOGO_S_CURVE := 4
static var TR_GAMES_RAIL_BACK_S := 0.31
static var TR_GAMES_HINTS_S := 0.2
static var TR_RING_OPEN_S := 0.4
static var TR_RING_OPEN_S_CURVE := 4
static var TR_RING_SINK_S := 0.24
static var TR_RING_RISE_S := 0.36
static var TR_RING_RISE_S_CURVE := 6
static var TR_RING_RISE_AT_S := 0.04
static var TR_RING_MARKS_S := 0.2
static var TR_RING_MARKS_AT_S := 0.2
static var TR_RING_MIDDLE_AT_S := 0.16
static var TR_RING_MIDDLE_S := 0.24
static var TR_RING_MIDDLE_S_CURVE := 3
static var TR_RING_CLOSE_S := 0.62
static var TR_RING_CLOSE_S_CURVE := 4
static var TR_FORM_OPEN_S := 0.38
static var TR_FORM_OPEN_S_CURVE := 4
static var TR_FORM_AT_S := 0.06
static var TR_FORM_FADE_S := 0.3
static var TR_FORM_OUT_S := 0.2
static var TR_FORM_SLIDE_PX := 64.0
static var TR_FORM_LIFT_PX := 51.2
static var TR_FORM_BACK_S := 0.38
static var TR_FORM_BACK_S_CURVE := 4
static var TR_FORM_LEAVE_S := 0.26
static var TR_CHOOSER_OPEN_S := 0.38
static var TR_CHOOSER_AT_S := 0.06
static var TR_CHOOSER_OUT_S := 0.15
static var TR_CHOOSER_LINES_AT_S := 0.15
static var TR_CHOOSER_LAYER_S := 0.2
static var TR_CHOOSER_MODEL_S := 0.08
static var TR_CHOOSER_CARD_S := 0.32
static var TR_CHOOSER_CARD_S_CURVE := 4
static var TR_CHOOSER_SHIFT_PX := 38.4
static var TR_CHOOSER_TITLE_PX := 10.24
static var TR_CHOOSER_IN_S := 0.23
static var TR_FORM_CHOOSER_TITLE_PX := 10.24
static var TR_PLACE_BACK_S := 0.4
static var TR_PLACE_ARC_PX := 38.4
static var TR_PLACE_OTHERS_S := 0.2
static var TR_PLACE_MARKS_S := 0.16
static var TR_PLACE_AT_S := 0.08
static var TR_SETTINGS_OPEN_S := 0.36
static var TR_SETTINGS_OPEN_S_CURVE := 6
static var TR_SETTINGS_LEAVE_S := 0.18
static var TR_SETTINGS_LEAVE_S_CURVE := 2
static var TR_SETTINGS_RECEDE := 0.96
static var TR_SETTINGS_DROP_PX := 51.2
static var TR_SETTINGS_SINK_S := 0.24
static var TR_SETTINGS_SINK_S_CURVE := 12
static var TR_SETTINGS_VEIL_AT_S := 0.08
static var TR_SETTINGS_VEIL_S := 0.2
static var TR_SETTINGS_CARD_AT_S := 0.12
static var TR_SETTINGS_RISE_PX := 38.4
static var TR_SETTINGS_HINTS_S := 0.15
static var TR_SETTINGS_CLOSE_S := 0.36
static var TR_SETTINGS_CARD_OUT_S := 0.18
static var TR_SETTINGS_CARD_OUT_S_CURVE := 2
static var TR_SETTINGS_BACK_AT_S := 0.14
static var TR_SETTINGS_CARD_S := 0.24
static var TR_SETTINGS_CARD_S_CURVE := 6
static var TR_PROPERTIES_OPEN_S := 0.4
static var TR_PROPERTIES_TRAVEL_S := 0.36
static var TR_PROPERTIES_TRAVEL_S_CURVE := 4
static var TR_PROPERTIES_FADE_S := 0.15
static var TR_PROPERTIES_POOL_S := 0.36
static var TR_PROPERTIES_POOL_S_CURVE := 3
static var TR_PROPERTIES_ZONE_AT_S := 0.24
static var TR_PROPERTIES_NAME_AT_S := 0.2
static var TR_PROPERTIES_RISE_PX := 20.48
static var TR_PROPERTIES_CALLOUT_AT_S := 0.28
static var TR_PROPERTIES_BACK_S := 0.38
static var TR_BALL_MORPH_S := 0.34
static var TR_REVERSE := 0
static var TR_SETTLE_S := 0.0


## The window's pixels to the design's: the 1280 px frame stretched to the window's width.
static func window_scale(window: Window) -> float:
	return window.size.x / 1280.0
