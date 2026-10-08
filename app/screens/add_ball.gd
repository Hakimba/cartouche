# SPDX-License-Identifier: GPL-3.0-or-later
class_name AddBall
extends Control
## The "+" ball above the consoles: one more can be added. Opened (while up is held), it becomes a
## button, "Add a platform": the two strokes of its "+" spread apart and stretch into the button's
## outline (the horizontal one into its top and bottom edges, the vertical one into its round ends),
## the white widening with them, then the text comes in. Closed, the other way round.

const _BALL := 64.0
const _BUTTON := Vector2(330.0, 46.0)
## Half the length of each stroke of the "+".
const _ARM := 14.0
const _STROKE := 3.5
const _MORPH_S := 0.34
const _TEXT_SIZE := 20
## How far into the morph the text starts to show.
const _TEXT_FROM := 0.85

## Whether it is the button, or on its way to it.
var is_open := false

## From the ball (0) to the button (1).
var _opened := 0.0:
	set(value):
		_opened = value
		queue_redraw()
var _tween: Tween
var _box := StyleBoxFlat.new()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_box.bg_color = Color(1, 1, 1, 0.94)
	_box.shadow_color = Color(0, 0, 0, 0.14)
	_box.shadow_size = 6
	_box.shadow_offset = Vector2(0, 2)
	_box.anti_aliasing = true


## Turns the ball into the button.
func open() -> void:
	_morph(true)


## Turns the button back into the ball, at once when not [param animated].
func close(animated := true) -> void:
	_morph(false)
	if not animated:
		if _tween:
			_tween.kill()
		_opened = 0.0


func _morph(to_open: bool) -> void:
	if to_open == is_open:
		return
	is_open = to_open
	Diagnostics.trace("carousel", "add ball %s" % ("opened" if to_open else "closed"))
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"_opened", 1.0 if to_open else 0.0, _MORPH_S).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK if to_open else Tween.TRANS_CUBIC)


func _draw() -> void:
	var p := _opened
	# Past 1, on the rebound, the button grows a little wider and flatter; the strokes stop at 1.
	var t := minf(p, 1.0)
	var centre := size / 2.0
	var button := Vector2(_BALL, _BALL).lerp(_BUTTON, p)
	var radius := button.y / 2.0
	var straight := (button.x - button.y) / 2.0
	# The white: the ball growing flatter, then pushed wider by the strokes' ends as they spread.
	var white := Vector2(maxf(lerpf(_BALL, button.y, t), button.x * t), button.y)
	_box.set_corner_radius_all(roundi(radius))
	draw_style_box(_box, Rect2(centre - white / 2.0, white))
	var ink := ButtonMark.INK
	for side: float in [-1.0, 1.0]:
		# The horizontal stroke parts into the top and bottom edges, as long as the straight sides.
		var half := lerpf(_ARM, straight, t)
		var y := side * radius * t
		draw_line(centre + Vector2(-half, y), centre + Vector2(half, y), ink, _STROKE, true)
		# The vertical stroke parts into the two ends, bending from a line into a half circle.
		var middle := centre + Vector2(side * (straight + radius) * t, 0.0)
		var sweep := PI * t
		if sweep < 0.02:
			draw_line(middle - Vector2(0, _ARM), middle + Vector2(0, _ARM), ink, _STROKE, true)
			continue
		var bend := lerpf(2.0 * _ARM, PI * radius, t) / sweep
		var facing := 0.0 if side > 0.0 else PI
		draw_arc(middle - Vector2(side * bend, 0.0), bend, facing - sweep / 2.0, facing + sweep / 2.0, 24, ink,
			_STROKE, true)
	if p > _TEXT_FROM:
		var font := get_theme_font(&"font", &"FieldValue")
		var text := tr("Add a platform")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _TEXT_SIZE).x
		var baseline := centre.y + (font.get_ascent(_TEXT_SIZE) - font.get_descent(_TEXT_SIZE)) / 2.0
		var shown := Color(ink, clampf((p - _TEXT_FROM) / (1.0 - _TEXT_FROM), 0.0, 1.0))
		draw_string(font, Vector2(centre.x - width / 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _TEXT_SIZE, shown)
