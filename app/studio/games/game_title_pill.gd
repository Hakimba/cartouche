# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameTitlePill
extends Control
## The games title keeps fractional tracking, one-line ellipsis and the ribbon's highlighted matches.

const MAX_WIDTH := 1152.0
const RADIUS := 38.4
const KEY := 38.4
const GAP := 11.52
const LEFT := 8.96
const RIGHT := 25.6
const VERTICAL := 7.68

var _panel := SatinPanel.Backing.new(self, StudioTokens.Look.SATIN)
var _key := SatinPanel.Backing.new(self, StudioTokens.Look.KEY)
var _line := StudioText.new("", StudioTokens.Face.JAKARTA_800, 29.44, -0.01)
var _marks: Array[Vector2] = []
var _bold: Array[StudioText] = []
var _text_x := 0.0:
	set(value):
		_text_x = value
		queue_redraw()
var _text_alpha := 1.0:
	set(value):
		_text_alpha = value
		queue_redraw()
var _text_move: Tween
var _move: Tween
var _wanted_top := -1.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_to_group(ButtonGlyph.GROUP)
	get_parent_control().resized.connect(_centre)


func _draw() -> void:
	_panel.place(Rect2(Vector2.ZERO, size), RADIUS)
	ButtonGlyph.draw_key(self, _key, Rect2(Vector2(LEFT, (size.y - KEY) / 2.0), Vector2.ONE * KEY), &"a")
	var at := Vector2(LEFT + KEY + GAP + _text_x, VERTICAL)
	var ink := Color(StudioTokens.INK, _text_alpha)
	_line.draw(self, at, ink)
	for i in _marks.size():
		var mark := _marks[i]
		var end := minf(mark.y, _line.width)
		if end > mark.x:
			var y := roundf(at.y + _line.baseline) + 5.0
			draw_line(Vector2(at.x + mark.x, y), Vector2(at.x + end, y), ink, 3.0, true)
			if mark.y <= _line.width:
				_bold[i].draw(self, at + Vector2(mark.x + 0.8, 0.0), ink)


func show_title(text: String, marks: Array[Vector2i], direction := 0) -> void:
	_line = StudioText.new(text, StudioTokens.Face.JAKARTA_800, 29.44, -0.01)
	_line.fit(MAX_WIDTH - LEFT - KEY - GAP - RIGHT)
	size = Vector2(LEFT + KEY + GAP + _line.width + RIGHT, maxf(KEY, _line.height) + 2.0 * VERTICAL)
	_marks.clear()
	_bold.clear()
	for mark in marks:
		var prefix := StudioText.new(text.left(mark.x), StudioTokens.Face.JAKARTA_800, 29.44, -0.01)
		var end := StudioText.new(text.left(mark.x + mark.y), StudioTokens.Face.JAKARTA_800, 29.44, -0.01)
		_marks.append(Vector2(prefix.width, end.width))
		_bold.append(StudioText.new(text.substr(mark.x, mark.y), StudioTokens.Face.JAKARTA_800, 29.44, -0.01))
	_centre()
	if _text_move:
		_text_move.kill()
	_text_x = direction * 10.24
	_text_alpha = 0.0 if direction != 0 else 1.0
	_text_move = create_tween().set_parallel()
	_text_move.tween_property(self, ^"_text_x", 0.0, 0.2).set_custom_interpolator(Motion.curve(Motion.Easing.EASE_OUT))
	_text_move.tween_property(self, ^"_text_alpha", 1.0, 0.2).set_custom_interpolator(Motion.curve(Motion.Easing.EASE_OUT))
	queue_redraw()


func move_top(top: float) -> void:
	if top == _wanted_top:
		return
	if _move:
		_move.kill()
	if _wanted_top < 0.0:
		position.y = top
	else:
		_move = create_tween()
		_move.tween_property(self, ^"position:y", top, 0.3).set_custom_interpolator(Motion.curve(Motion.Easing.GLIDE))
	_wanted_top = top


func _centre() -> void:
	position.x = (get_parent_control().size.x - size.x) / 2.0
