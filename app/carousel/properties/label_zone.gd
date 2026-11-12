# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelZone
extends Control
## A focusable outline around the projected label face.

enum Shape { DISC, RECTANGLE }

const OUTSET := 10.0
const CORNER := 20.48
const _GLOW_REACH := 32.0

var shape := Shape.DISC
var gel := StudioTokens.NEUTRAL
var corner_radius := 0.0
var _outline := ColorRect.new()
var _material := ShaderMaterial.new()
var _focus: Tween
var _morph: Tween
var _target_box := Rect2()


func _ready() -> void:
	focus_mode = FOCUS_ALL
	_material.shader = preload("res://carousel/properties/label_zone.gdshader")
	_outline.material = _material
	_outline.mouse_filter = MOUSE_FILTER_IGNORE
	_outline.modulate.a = 0.0
	add_child(_outline)
	focus_entered.connect(_focus_changed)
	focus_exited.connect(_focus_changed)


static func around(label: Rect2, kind: Shape) -> Rect2:
	var box := label.grow(OUTSET)
	if kind == Shape.DISC:
		var diameter := maxf(box.size.x, box.size.y)
		box = Rect2(box.get_center() - Vector2.ONE * diameter / 2.0, Vector2.ONE * diameter)
	return box


func place(label: Rect2, kind: Shape, tint: Color) -> void:
	var box := around(label, kind)
	if _target_box == box and shape == kind and gel == tint:
		return
	var radius := CORNER if kind == Shape.RECTANGLE else box.size.x / 2.0
	var morph := _target_box.has_area() and shape != kind
	var same_target := _target_box == box and shape == kind
	gel = tint
	_material.set_shader_parameter(&"gel", Backdrop.palette.gel(gel))
	if same_target and _morph and _morph.is_running():
		return
	_target_box = box
	shape = kind
	if morph:
		_morph = Motion.restart(self, _morph)
		_morph.tween_method(_morph_box.bind(get_rect(), box, corner_radius, radius), 0.0, 1.0, 0.32)
	else:
		if _morph:
			_morph.kill()
		_paint(box, radius)


func _morph_box(part: float, from: Rect2, to: Rect2, old_radius: float, new_radius: float) -> void:
	part = Motion.eased(Motion.Easing.EASE, part)
	_paint(Rect2(from.position.lerp(to.position, part), from.size.lerp(to.size, part)), lerpf(old_radius, new_radius, part))


func _paint(box: Rect2, radius: float) -> void:
	position = box.position
	size = box.size
	corner_radius = radius
	_outline.position = -Vector2.ONE * _GLOW_REACH
	_outline.size = size + Vector2.ONE * 2.0 * _GLOW_REACH
	_material.set_shader_parameter(&"box_size", size)
	_material.set_shader_parameter(&"radius", radius)


func _focus_changed() -> void:
	_focus = Motion.restart(self, _focus)
	_focus.tween_property(_outline, ^"modulate:a", 1.0 if has_focus() else 0.0, 0.2)
