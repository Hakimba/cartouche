# SPDX-License-Identifier: GPL-3.0-or-later
class_name SatinPanel
extends Container
## A piece of the Studio look: its material ([StudioMaterial]: satin, frost, a key's dark disc, the "+"
## ball) drawn behind it with its gradient and shadows, its children laid over the whole of it. The
## frost's backdrop blur is not drawn: too costly on a handheld.

@export var look := StudioTokens.Look.SATIN:
	set(value):
		look = value
		_backing.look = value

## The colour its tinted shadows take.
var gel := StudioTokens.NEUTRAL:
	set(value):
		gel = value
		_backing.tint = value

var _backing := Backing.new(self, StudioTokens.Look.SATIN)


## A Studio material on a box of its own, behind the canvas item it is made for: so that item's own drawing
## (a mark, separators) stays above it. A look in the backdrop shown, drawn again when another shows; for a preview,
## in the colours of a palette of its own; or a material of any recipe ([method of]), which its owner paints again.
class Backing:
	extends RefCounted

	## Changing it, or the gel its shadows take, draws the new material on the same box.
	var look: StudioTokens.Look:
		set(value):
			look = value
			repaint()
	var tint := StudioTokens.NEUTRAL:
		set(value):
			tint = value
			repaint()
	## The material of any recipe drawn instead of [member look]'s; set again, or [method repaint], after its colours
	## change. None: the look's.
	var shown: StudioMaterial:
		set(value):
			shown = value
			repaint()

	var _item := RenderingServer.canvas_item_create()
	var _material := ShaderMaterial.new()
	## How far past the box its shadows reach.
	var _grow := 0.0
	var _box := Rect2()
	var _radius := -1.0
	## Whether the material's parameters wait for the next [method place]: nothing is drawn before it, so the
	## paints of the look, the gel and the theme made while the owner is built are written once.
	var _stale := false
	var _placed := false
	var _tuning := {}
	var _palette: Palette

	func _init(owner: CanvasItem, drawn: StudioTokens.Look, palette: Palette = null, made: StudioMaterial = null) -> void:
		_palette = palette
		shown = made
		if not made:
			if not palette and owner is Control:
				(owner as Control).theme_changed.connect(repaint)
			owner.set_meta(&"studio_backing", weakref(self))
		_material.shader = preload("res://studio/satin_panel.gdshader")
		RenderingServer.canvas_item_set_parent(_item, owner.get_canvas_item())
		RenderingServer.canvas_item_set_draw_behind_parent(_item, true)
		RenderingServer.canvas_item_set_material(_item, _material.get_rid())
		look = drawn

	## A backing of [param owner] drawing [param material] ([member shown]).
	static func of(owner: CanvasItem, material: StudioMaterial) -> Backing:
		return Backing.new(owner, StudioTokens.Look.SATIN, null, material)

	## Writes the material again where it stands; one not placed is written as it is placed.
	func repaint() -> void:
		_stale = true
		if _placed:
			place(_box, _radius)

	func _write() -> void:
		_stale = false
		var drawn := shown if shown else StudioMaterial.new(look, _palette)
		var parameters := Backing.recipe(drawn, tint)
		for parameter in parameters:
			_material.set_shader_parameter(parameter, parameters[parameter])
		if _tuning.has("colour"):
			_material.set_shader_parameter(&"colors", [StudioMaterial.rgba(ControlTokens._colour(_tuning["colour"]))])
			_material.set_shader_parameter(&"stop_count", 1)
		if _tuning.has("border_colour"):
			var border := ControlTokens._colour(_tuning["border_colour"])
			var colours: Array[Vector4] = []
			for shadow in drawn.shadows:
				var colour := shadow.shown(tint)
				colours.append(StudioMaterial.rgba(Color(border, colour.a) if shadow.inset else colour))
			_material.set_shader_parameter(&"shadow_colors", colours)
		_grow = drawn.reach()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			RenderingServer.free_rid(_item)

	## Draws the material on [param box] (in the owner's coordinates), its corners rounded by [param radius]
	## or by the material's own radius when negative.
	func place(box: Rect2, radius := -1.0) -> void:
		_placed = true
		if _stale:
			_write()
		_box = box
		_radius = radius
		var quad := box.grow(_grow)
		_material.set_shader_parameter(&"box_position", box.position - quad.position)
		_material.set_shader_parameter(&"box_size", box.size)
		radius = _tuning.get("corner_radius", radius)
		if radius >= 0.0:
			_material.set_shader_parameter(&"radius", radius)
		RenderingServer.canvas_item_clear(_item)
		RenderingServer.canvas_item_set_transform(_item, Transform2D(0.0, quad.position))
		RenderingServer.canvas_item_add_rect(_item, Rect2(Vector2.ZERO, quad.size), Color.WHITE)

	## Draws nothing until placed again.
	func clear() -> void:
		_placed = false
		RenderingServer.canvas_item_clear(_item)

	func tune(values: Dictionary) -> void:
		_tuning.merge(values, true)
		repaint()

	## The shader's parameters drawing [param drawn], its shadows tinted by [param gel].
	static func recipe(drawn: StudioMaterial, gel := StudioTokens.NEUTRAL) -> Dictionary[StringName, Variant]:
		var shapes: Array[Vector4] = []
		var shadow_colors: Array[Vector4] = []
		for shadow in drawn.shadows:
			shapes.append(Vector4(shadow.offset.x, shadow.offset.y, shadow.blur, shadow.spread))
			shadow_colors.append(StudioMaterial.rgba(shadow.shown(gel)))
		return {
			&"stop_count": drawn.stops.size(), &"stops": drawn.stops, &"colors": drawn.colors.map(StudioMaterial.rgba),
			&"centre": drawn.centre, &"radius": drawn.radius,
			&"inset_count": drawn.shadows.filter(func(shadow: StudioMaterial.Shadow) -> bool: return shadow.inset).size(),
			&"shadow_count": drawn.shadows.size(), &"shadow_shapes": shapes, &"shadow_colors": shadow_colors,
		}


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_SORT_CHILDREN:
			_lay_out()
		NOTIFICATION_RESIZED, NOTIFICATION_READY:
			_backing.place(Rect2(Vector2.ZERO, size))


## Lays the children in the panel, each over the whole of it.
func _lay_out() -> void:
	for child in _shown():
		fit_child_in_rect(child, Rect2(Vector2.ZERO, size))


func _get_minimum_size() -> Vector2:
	var largest := Vector2.ZERO
	for child in _shown():
		largest = largest.max(child.get_combined_minimum_size())
	return largest


## The children shown.
func _shown() -> Array[Control]:
	var shown: Array[Control] = []
	for child in get_children():
		if child is Control and (child as Control).visible:
			shown.append(child)
	return shown
