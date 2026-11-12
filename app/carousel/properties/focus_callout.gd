# SPDX-License-Identifier: GPL-3.0-or-later
class_name FocusCallout
extends Control
## The focus caption beside its anchor, on a frost pill and a lead starting at a dot.

const _WIDTH := 2.56
const _FADE_S := 0.15

var timeline := false:
	set(value):
		timeline = value
		if value and _fade:
			_fade.kill()
		if value and _motion:
			_motion.kill()

var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _fade: Tween
var _line: StudioText
var _backing: SatinPanel.Backing
var _text := ""
var _caption_box := Rect2()
var _target_box := Rect2()
var _target_from := Vector2.ZERO
var _target_to := Vector2.ZERO
var _motion: Tween
var _fade_alpha := 0.0

func _ready() -> void:
	modulate.a = 0.0
	_backing = SatinPanel.Backing.new(self, StudioTokens.Look.FROST)


func _draw() -> void:
	draw_line(_from, _to, Backdrop.palette.ink, _WIDTH, true)
	draw_circle(_from, 10.24, Backdrop.palette.callout_ring, true, -1.0, true)
	draw_circle(_from, 7.04, Backdrop.palette.ink, true, -1.0, true)
	if _line:
		_line.draw(self, _caption_box.position + Vector2(15.36, 5.76), Backdrop.palette.ink)


func point(caption: String, at: Vector2, target: Vector2) -> void:
	var changed := _text != caption
	if changed:
		_text = caption
	_fade_to(1.0)
	var had_caption := _line != null
	if changed or not _line:
		_line = StudioText.new(caption, StudioTokens.Face.JAKARTA_700, 23.04)
	var box := Rect2(at - Vector2(0.0, (_line.height + 11.52) / 2.0), Vector2(_line.width + 30.72, _line.height + 11.52))
	var start := target
	if start == _target_from and at == _target_to and box == _target_box and not changed:
		return
	_target_from = start
	_target_to = at
	_target_box = box
	if changed and had_caption and not timeline:
		_motion = Motion.restart(self, _motion)
		_motion.tween_method(_move_geometry.bind(_from, start, _to, at, _caption_box, box), 0.0, 1.0, 0.32)
	else:
		if _motion:
			_motion.kill()
		_set_geometry(start, at, box)


func _move_geometry(part: float, from: Vector2, to: Vector2, old_end: Vector2, new_end: Vector2,
		old_box: Rect2, new_box: Rect2) -> void:
	part = Motion.eased(Motion.Easing.EASE, part)
	var start := from.lerp(to, part)
	var old_lead := old_end - from
	var new_lead := new_end - to
	var lead := Vector2.from_angle(lerp_angle(old_lead.angle(), new_lead.angle(), part)) \
		* lerpf(old_lead.length(), new_lead.length(), part)
	_set_geometry(start, start + lead, Rect2(old_box.position.lerp(new_box.position, part), new_box.size))


func _set_geometry(start: Vector2, end: Vector2, box: Rect2) -> void:
	_from = start
	_to = end
	_caption_box = box
	_backing.place(box)
	queue_redraw()


func clear() -> void:
	_fade_to(0.0)
	_fade_alpha = 0.0


func _fade_to(alpha: float) -> void:
	if timeline or (_fade_alpha == alpha and ((_fade and _fade.is_running()) or is_equal_approx(modulate.a, alpha))):
		return
	_fade_alpha = alpha
	_fade = Motion.restart(self, _fade)
	_fade.tween_property(self, ^"modulate:a", alpha, _FADE_S)
