# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioTokens
extends RefCounted
## Every value of the Studio design the app draws with, in px at the 1280×960 frame. Generated from the
## design's tokens: never edited by hand (a test fails on a hand edit).
## The whole of the design's set is kept, used or not yet: the screens built after the foundation read it.

const SHA256 := "454e81371df8458caa62f6355577360865f588842d008b9ee32b1762e9aefe7c"

const INK := Color("#24201b")
const MUTE := Color("#857a6d")
const SATIN := Color("#fcfaf6")
const LINE := Color(0.27451, 0.203922, 0.133333, 0.13)
const NEUTRAL := Color("#a07850")
## Each console's gel, by its folder under res://carousel/consoles.
const GEL: Dictionary[StringName, Color] = {&"ps2_slim": Color("#2f6fc6"), &"psx": Color("#e09a12"), &"nes": Color("#d62b2b"), &"snes": Color("#6f5bc4"), &"n64": Color("#1e9e4a"), &"gc": Color("#7a5bd0"), &"wii": Color("#22a8e0"), &"xbox": Color("#4fa82a"), &"xbox360": Color("#93b92e"), &"gb": Color("#3a3fa0"), &"gbc": Color("#e2408a"), &"gba": Color("#3d4fc4")}
const MAKER: Dictionary[String, Color] = {"Atari": Color("#c8541e"), "Microsoft": Color("#2d9c3c"), "Nintendo": Color("#e4000f"), "Sega": Color("#1f64c8"), "Sony": Color("#2a3a6e")}
## The gel's change, eased by the CSS curve `ease`.
const GEL_FADE_S := 0.38

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
## The focus ring around a focused row or field, in the gel's colour.
const FOCUS_RING := 4.86
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
## The turntable's turn (radians a second), the swing it enters with (radians) and the time it settles in.
const TURN := 0.6981317007977318
const SWING := 1.2217304763960306
const SETTLE_S := 0.6
## The games' softness by their distance from the centre: a neighbour's blur (px) and saturation, and the
## warm shadow (down px, CSS blur px, alpha) of the chosen game and of a neighbour.
const SOFT_BLUR := 1.1
const SOFT_SATURATION := 0.92
const CHOSEN_SHADOW := Vector3(12.0, 22.0, 0.2)
const SIDE_SHADOW := Vector3(8.0, 14.0, 0.28)

## The rail and games row's spring: stiffness and damping, unit mass.
const SPRING_STIFFNESS := 280.0
const SPRING_DAMPING := 25.0


## The window's pixels to the design's: the 1280 px frame stretched to the window's width.
static func window_scale(window: Window) -> float:
	return window.size.x / 1280.0
