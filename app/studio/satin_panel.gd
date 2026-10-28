# SPDX-License-Identifier: GPL-3.0-or-later
class_name SatinPanel
extends Container
## A piece of the Studio design: its material ([StudioMaterial]: satin, frost, a key's dark disc, the "+"
## ball) drawn behind it with the design's gradient and shadows, its children laid over the whole of it. The
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
## (a mark, separators) stays above it, as a CSS background lies under the element's content.
class Backing:
	extends RefCounted

	## Changing it, or the gel its shadows take, draws the new material on the same box.
	var look: StudioTokens.Look:
		set(value):
			look = value
			_paint()
	var tint := StudioTokens.NEUTRAL:
		set(value):
			tint = value
			_paint()

	var _item := RenderingServer.canvas_item_create()
	var _material := ShaderMaterial.new()
	## How far past the box its shadows reach.
	var _grow := 0.0
	var _box := Rect2()
	var _radius := -1.0
	var _tuning := {}

	func _init(owner: CanvasItem, shown: StudioTokens.Look) -> void:
		owner.set_meta(&"studio_backing", weakref(self))
		_material.shader = preload("res://studio/satin_panel.gdshader")
		RenderingServer.canvas_item_set_parent(_item, owner.get_canvas_item())
		RenderingServer.canvas_item_set_draw_behind_parent(_item, true)
		RenderingServer.canvas_item_set_material(_item, _material.get_rid())
		look = shown

	func _paint() -> void:
		var shown := StudioMaterial.new(look)
		var parameters := Backing.recipe(shown, tint)
		for parameter in parameters:
			_material.set_shader_parameter(parameter, parameters[parameter])
		if _tuning.has("colour"):
			var fill := ControlTokens._colour(_tuning["colour"])
			_material.set_shader_parameter(&"colors", [Vector4(fill.r, fill.g, fill.b, fill.a)])
			_material.set_shader_parameter(&"stop_count", 1)
		if _tuning.has("border_colour"):
			var border := ControlTokens._colour(_tuning["border_colour"])
			var colours: Array[Vector4] = []
			for shadow in shown.shadows:
				var colour := shadow.shown(tint)
				colours.append(Vector4(border.r, border.g, border.b, colour.a) if shadow.inset else Vector4(colour.r, colour.g, colour.b, colour.a))
			_material.set_shader_parameter(&"shadow_colors", colours)
		_grow = shown.reach()
		place(_box, _radius)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			RenderingServer.free_rid(_item)

	## Draws the material on [param box] (in the owner's coordinates), its corners rounded by [param radius]
	## or by the look's own radius when negative.
	func place(box: Rect2, radius := -1.0) -> void:
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

	func tune(values: Dictionary) -> void:
		_tuning.merge(values, true)
		_paint()

	## The shader's parameters drawing [param shown], its shadows tinted by [param gel].
	static func recipe(shown: StudioMaterial, gel := StudioTokens.NEUTRAL) -> Dictionary[StringName, Variant]:
		var as_vector := func(color: Color) -> Vector4: return Vector4(color.r, color.g, color.b, color.a)
		var shapes: Array[Vector4] = []
		var shadow_colors: Array[Vector4] = []
		for shadow in shown.shadows:
			shapes.append(Vector4(shadow.offset.x, shadow.offset.y, shadow.blur, shadow.spread))
			shadow_colors.append(as_vector.call(shadow.shown(gel)))
		return {
			&"stop_count": shown.stops.size(), &"stops": shown.stops, &"colors": shown.colors.map(as_vector),
			&"centre": shown.centre, &"radius": shown.radius,
			&"inset_count": shown.shadows.filter(func(shadow: StudioMaterial.Shadow) -> bool: return shadow.inset).size(),
			&"shadow_count": shown.shadows.size(), &"shadow_shapes": shapes, &"shadow_colors": shadow_colors,
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
