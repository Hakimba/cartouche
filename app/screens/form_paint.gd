# SPDX-License-Identifier: GPL-3.0-or-later
class_name FormPaint
extends RefCounted
## What the add-console form draws its own way: the materials of its step chips, switches and pill buttons, the
## focus card that moves between them, and the plain look of the controls that only hold focus and a press.

## One container width unit of the design, in px at the 1280 px frame.
const CQW := 12.8
## A browser's "normal" line of the two families, and the ascent in it, in em: text set with a CSS `font`
## shorthand keeps it, the rest of the design's text lines are 1.5 em tall.
const PLEX_LINE := 1.3
const PLEX_ASCENT := 1.025
const JAKARTA_LINE := 1.26
const JAKARTA_ASCENT := 1.038
## The lines kept, so a text shaped once is not shaped again each time it is drawn.
const _LINES_KEPT := 96

static var _lines: Dictionary[String, StudioText] = {}


## A Studio material of any recipe on a box of its own, drawn behind the canvas item it is made for (what
## [SatinPanel.Backing] does for the design's own looks).
class Layer:
	extends RefCounted

	## The material; set again (or [method repaint]) after its colours change.
	var shown: StudioMaterial:
		set(value):
			shown = value
			repaint()
	## The colour its tinted shadows take.
	var tint := StudioTokens.NEUTRAL:
		set(value):
			tint = value
			repaint()

	var _item := RenderingServer.canvas_item_create()
	var _shader := ShaderMaterial.new()
	var _grow := 0.0
	var _box := Rect2()
	var _radius := -1.0

	func _init(owner: CanvasItem, material: StudioMaterial) -> void:
		_shader.shader = preload("res://studio/satin_panel.gdshader")
		RenderingServer.canvas_item_set_parent(_item, owner.get_canvas_item())
		RenderingServer.canvas_item_set_draw_behind_parent(_item, true)
		RenderingServer.canvas_item_set_material(_item, _shader.get_rid())
		shown = material

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			RenderingServer.free_rid(_item)

	func repaint() -> void:
		var parameters := SatinPanel.Backing.recipe(shown, tint)
		for parameter in parameters:
			_shader.set_shader_parameter(parameter, parameters[parameter])
		_grow = shown.reach()
		place(_box, _radius)

	func clear() -> void:
		RenderingServer.canvas_item_clear(_item)

	## Draws the material on [param box] (the owner's coordinates), its corners rounded by [param radius], or by
	## the material's own when negative.
	func place(box: Rect2, radius := -1.0) -> void:
		_box = box
		_radius = radius
		var quad := box.grow(_grow)
		_shader.set_shader_parameter(&"box_position", box.position - quad.position)
		_shader.set_shader_parameter(&"box_size", box.size)
		_shader.set_shader_parameter(&"radius", shown.radius if radius < 0.0 else radius)
		RenderingServer.canvas_item_clear(_item)
		RenderingServer.canvas_item_set_transform(_item, Transform2D(0.0, quad.position))
		RenderingServer.canvas_item_add_rect(_item, Rect2(Vector2.ZERO, quad.size), Color.WHITE)


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

	var _layer: Layer

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer = Layer.new(self, FormPaint.card_material(true))

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			_layer.place(Rect2(Vector2.ZERO, size), radius)


## The card's material: the design's focused card as its picture shows it (the satin card and its drop shadow,
## with no gel ring or glow), or the ring and glow alone with no fill and no inset highlight.
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
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for colour: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_disabled_color"]:
		button.add_theme_color_override(colour, Color.TRANSPARENT)
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	if button.focus_neighbor_left.is_empty():
		button.focus_neighbor_left = NodePath(".")
	if button.focus_neighbor_right.is_empty():
		button.focus_neighbor_right = NodePath(".")
