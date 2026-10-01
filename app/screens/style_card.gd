# SPDX-License-Identifier: GPL-3.0-or-later
class_name StyleCard
extends Control
## One button style to choose: a white card with the four face buttons drawn as that style marks
## them, and the style's name. Focusable; the focus is a ring.

## Confirmed while focused: this style is chosen.
signal chosen(style: StringName)

## The face buttons of each style: top, left, right, bottom.
const _FACES: Dictionary[StringName, Array] = {
	&"xbox": ["Y", "X", "B", "A"],
	&"nintendo": ["X", "Y", "A", "B"],
	&"playstation": ["△", "□", "○", "✕"],
}
const _BUTTON_RADIUS := 31.0
const _SPREAD := 65.0
const _TITLE_SIZE := 28

@export var style := &"xbox"

var _focus_scale := FocusScale.new()


func _ready() -> void:
	focus_mode = FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_focus_scale.watch(self)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		accept_event()
		chosen.emit(style)


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox(&"normal", &"Field"), card)
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Field"), card)
	var centre := Vector2(size.x / 2.0, size.y * 0.44)
	var offsets: Array[Vector2] = [Vector2(0, -_SPREAD), Vector2(-_SPREAD, 0), Vector2(_SPREAD, 0), Vector2(0, _SPREAD)]
	var faces: Array[String] = []
	faces.assign(_FACES[style])
	for i in 4:
		var at := centre + offsets[i]
		ButtonMark.draw(self, faces[i], at, _BUTTON_RADIUS, 28.0)
	var font := get_theme_font(&"font", &"FieldValue")
	var title := Controls.NAMES[style]
	var width := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, _TITLE_SIZE).x
	draw_string(font, Vector2((size.x - width) / 2.0, size.y - 40.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_TITLE_SIZE, ButtonMark.INK)
