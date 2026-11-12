# SPDX-License-Identifier: GPL-3.0-or-later
class_name FormPaint
extends RefCounted
## What the add-console form draws its own way: the materials of its step chips, switches and pill buttons, the
## focus card that moves between them, its rows' separators and chevrons, and the plain look of the controls that
## only hold focus and a press.

## One hundredth of the 1280 px frame's width, in px.
const CQW := 12.8
## The default line height of each of the two font families, and the ascent in it, in em: the text lines that
## keep it; the other text lines are 1.5 em tall.
const PLEX_LINE := 1.3
const PLEX_ASCENT := 1.025
const JAKARTA_LINE := 1.26
const JAKARTA_ASCENT := 1.038
## A screen's title and its step count above it ("02 / 03"), in px; the count sits this far up and left of its box.
const TITLE_PX := 4.6 * CQW
const _COUNT_PX := 1.7 * CQW
const _COUNT_SHIFT := Vector2(-1.0, -1.0)
## A row's text and marks end this far from its right edge, in px.
const PAD_RIGHT := 1.8 * CQW
## A row's separator: from its step chip's left to this far from its right edge, this far under it, in px.
const _SEPARATOR_LEFT := 2.2 * CQW
const _SEPARATOR_RIGHT := 1.4 * CQW
const _SEPARATOR_GAP := 0.3 * CQW
## How long a text takes to light up or go back to muted.
const LIT_S := 0.3
## The lines kept, so a text shaped once is not shaped again each time it is drawn.
const _LINES_KEPT := 96

static var _lines: Dictionary[String, StudioText] = {}
## The box of every plain control: none.
static var _no_box := StyleBoxEmpty.new()


## The card that rests on the focused field, and the bare ring round a pill button: the satin card with the gel's
## ring and glow, or the ring and glow alone. It moves between boxes; its radius follows its box.
class Card:
	extends Control

	var bare := false:
		set(value):
			bare = value
			_layer.shown = FormPaint.card_material(not value)
	var rim := StudioTokens.NEUTRAL:
		set(value):
			rim = value
			_layer.tint = value
	## The corners' radius, px.
	var radius := StudioTokens.FOCUS_RADIUS:
		set(value):
			radius = value
			_layer.place(Rect2(Vector2.ZERO, size), radius)

	var _layer: SatinPanel.Backing

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer = SatinPanel.Backing.of(self, FormPaint.card_material(true))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layer.place(Rect2(Vector2.ZERO, size), radius)
		elif what == NOTIFICATION_THEME_CHANGED:
			_layer.shown = FormPaint.card_material(not bare)


## How far a text of [param canvas] is lit, 0 (muted) to 1 (white): eased over [constant LIT_S] when it changes.
class Lit:
	extends RefCounted

	var at := 0.0
	var _canvas: CanvasItem
	var _lighting: Tween

	func _init(canvas: CanvasItem) -> void:
		_canvas = canvas

	func light(to: float) -> void:
		var from := at
		_lighting = Motion.restart(_canvas, _lighting)
		_lighting.tween_method(func(t: float) -> void:
			at = lerpf(from, to, Motion.eased(Motion.Easing.EASE, t))
			_canvas.queue_redraw(), 0.0, 1.0, LIT_S)

	## The muted ink as lit now.
	func ink() -> Color:
		return Backdrop.palette.mute.lerp(Color.WHITE, at)


## The card's material: the focused card (the satin card and its shadow, with no gel ring or glow), or the ring
## and glow alone with no fill and no inset highlight.
static func card_material(filled: bool) -> StudioMaterial:
	var shown := StudioMaterial.new(StudioTokens.Look.FOCUS)
	if not filled:
		shown.colors.assign([Color.TRANSPARENT, Color.TRANSPARENT])
	var kept: Array[StudioMaterial.Shadow] = []
	kept.assign(shown.shadows.filter(func(shadow: StudioMaterial.Shadow) -> bool: return shadow.tinted != filled))
	shown.shadows = kept
	return shown


## The line [param shown] in [param face] at [param px] tracked by [param tracking_em], whole: shaped the first
## time only. Cut it with [method StudioText.fit] before drawing it in a room.
static func line(shown: String, face: StudioTokens.Face, px: float, tracking_em := 0.0) -> StudioText:
	var key := "%d|%f|%f|%s" % [face, px, tracking_em, shown]
	if key not in _lines:
		if _lines.size() >= _LINES_KEPT:
			_lines.clear()
		_lines[key] = StudioText.new(shown, face, px, tracking_em)
	var text := _lines[key]
	text.fit(INF)
	return text


## A step count on [param canvas]: [param number] in the gel [param rim], then [param rest] muted.
static func draw_count(canvas: CanvasItem, number: String, rest: String, rim: Color) -> void:
	var shown := line(number, StudioTokens.Face.PLEX_600, _COUNT_PX, 0.08)
	shown.draw(canvas, _COUNT_SHIFT, Backdrop.palette.gel(rim))
	line(rest, StudioTokens.Face.PLEX_600, _COUNT_PX, 0.08).draw(canvas, _COUNT_SHIFT + Vector2(shown.width, 0.0), Backdrop.palette.mute)


## The 1 px line under a row of [param canvas], in its own coordinates.
static func separator(canvas: Control) -> void:
	canvas.draw_rect(Rect2(_SEPARATOR_LEFT, canvas.size.y + _SEPARATOR_GAP - 1.0,
		canvas.size.x - _SEPARATOR_LEFT - _SEPARATOR_RIGHT, 1.0), Backdrop.palette.line)


## A chevron on [param canvas] pointing to [param tip]: its arms go [param back] from the tip and [param side] each
## way across, [param stroke] wide in [param ink]; their ends rounded when [param rounded].
static func chevron(canvas: CanvasItem, tip: Vector2, back: Vector2, side: Vector2, ink: Color, stroke: float,
		rounded := true) -> void:
	var points := PackedVector2Array([tip + back - side, tip, tip + back + side])
	canvas.draw_polyline(points, ink, stroke, true)
	if rounded:
		for point in points:
			canvas.draw_circle(point, stroke / 2.0, ink)


## A material of [param colors] over [param stops] and [param shadows] (each as [StudioTokens] lists them), on a
## box rounded by [param radius]; a radial fill when [param centre] is not (-1, -1).
static func material(colors: Array[Color], radius: float, shadows: Array, centre := Vector2(-1.0, -1.0),
		stops: Array[float] = [0.0, 1.0]) -> StudioMaterial:
	var made := StudioMaterial.new(StudioTokens.Look.SATIN)
	made.stops = stops
	made.colors = colors
	made.centre = centre
	made.radius = radius
	made.shadows.clear()
	for entry: Array in shadows:
		made.shadows.append(StudioMaterial.Shadow.new(entry))
	return made


## [param button] as a control that only holds the focus and takes a press: no box of its own, its text drawn by
## the form (the button's own stays for the tests and the screen readers), and no way off sideways unless its scene opens one.
static func plain(button: Button) -> void:
	button.flat = true
	for state: StringName in [&"focus", &"normal", &"hover", &"pressed", &"disabled", &"hover_pressed"]:
		button.add_theme_stylebox_override(state, _no_box)
	for colour: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_disabled_color"]:
		button.add_theme_color_override(colour, Color.TRANSPARENT)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if button.focus_neighbor_left.is_empty():
		button.focus_neighbor_left = NodePath(".")
	if button.focus_neighbor_right.is_empty():
		button.focus_neighbor_right = NodePath(".")
