# SPDX-License-Identifier: GPL-3.0-or-later
class_name ChoiceCard
extends Control
## One choice of a [ChoiceScreen]: a white card showing it ([method _draw_sample]). Focusable; the focus is a ring.

## Confirmed while focused: this choice is chosen.
signal chosen(value: StringName)

@export var value := &""

var _focus_scale := FocusScale.new()


func _ready() -> void:
	focus_mode = FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_focus_scale.watch(self)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		accept_event()
		chosen.emit(value)


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox(&"normal", &"Field"), card)
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Field"), card)
	_draw_sample()


## Draws the choice over the card.
func _draw_sample() -> void:
	pass
