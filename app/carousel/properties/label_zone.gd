# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelZone
extends Control
## A focusable outline around the projected label face.

enum Shape { DISC, RECTANGLE }

const OUTSET := 10.0
const CORNER := 20.48
const _GLOW_REACH := 32.0
const _SHADER := """
shader_type canvas_item;
uniform vec2 box_size;
uniform float radius;
uniform vec4 gel : source_color;
varying vec2 point;
void vertex() { point = VERTEX - vec2(32.0); }
float erf_value(float x) {
	float a = abs(x);
	float t = 1.0 + (0.278393 + (0.230389 + 0.078108 * a * a) * a) * a;
	return sign(x) * (1.0 - 1.0 / (t * t * t * t));
}
void fragment() {
	vec2 q = abs(point - box_size * 0.5) - box_size * 0.5 + radius;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
	float aa = max(fwidth(d), 0.001);
	float rim = (1.0 - smoothstep(-aa, aa, d)) * smoothstep(-5.12 - aa, -5.12 + aa, d);
	float outside = 0.45 * (0.5 - 0.5 * erf_value(d / (8.96 * sqrt(2.0))));
	float inside = 0.25 * (0.5 + 0.5 * erf_value((d + 5.12) / (5.12 * sqrt(2.0))));
	float glow = d > 0.0 ? outside : inside;
	COLOR = vec4(gel.rgb, rim + glow * (1.0 - rim)) * COLOR;
}
"""

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
	var shader := Shader.new()
	shader.code = _SHADER
	_material.shader = shader
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
	_material.set_shader_parameter(&"gel", gel)
	if same_target and _morph:
		return
	_target_box = box
	shape = kind
	if _morph:
		_morph.kill()
		_morph = null
	if morph:
		_morph = create_tween()
		_morph.tween_method(_morph_box.bind(get_rect(), box, corner_radius, radius), 0.0, 1.0, 0.32)
		_morph.finished.connect(func() -> void: _morph = null)
	else:
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
