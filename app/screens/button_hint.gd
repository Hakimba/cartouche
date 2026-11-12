# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonHint
extends Control
## A controller button and what it does, small: "Y Settings", the key then its label, in a [HintRow]. A finger lifted
## on a hint shown whole presses its button, as the pad would: every guard of the pad holds for it.

## The pad's button each mark stands for; the others (directions, the stick) are no single press.
const _PRESSES: Dictionary[StringName, JoyButton] = {
	&"a": JOY_BUTTON_A, &"b": JOY_BUTTON_B, &"x": JOY_BUTTON_X, &"y": JOY_BUTTON_Y, &"start": JOY_BUTTON_START,
	&"l1": JOY_BUTTON_LEFT_SHOULDER, &"r1": JOY_BUTTON_RIGHT_SHOULDER,
}

## The button, as [method Controls.mark] names it.
@export var button := &"a"
@export var text := "":
	set(shown):
		if shown == text:
			return
		text = shown
		_label = StudioText.of(StudioTokens.Role.HINT, tr(shown))
		update_minimum_size()
		queue_redraw()

var _key := SatinPanel.Backing.new(self, StudioTokens.Look.KEY)
var _label := StudioText.of(StudioTokens.Role.HINT, "")
## The finger put down on the hint, -1 for none.
var _finger := -1


func _ready() -> void:
	# A hint faded passes its finger on to what lies under it.
	mouse_filter = MOUSE_FILTER_PASS if button in _PRESSES else MOUSE_FILTER_IGNORE
	add_to_group(ButtonGlyph.GROUP)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_label = StudioText.of(StudioTokens.Role.HINT, tr(text))
			update_minimum_size()
			queue_redraw()
		NOTIFICATION_RESIZED:
			queue_redraw()


func _get_minimum_size() -> Vector2:
	var key := ButtonGlyph.key_size(button)
	return Vector2(key.x + StudioTokens.HINT_GAP + _label.width, maxf(key.y, _label.height))


func _draw() -> void:
	var key := ButtonGlyph.key_size(button)
	ButtonGlyph.draw_key(self, _key, Rect2(Vector2(0.0, (size.y - key.y) / 2.0), key), button)
	_label.draw(self, Vector2(key.x + StudioTokens.HINT_GAP, (size.y - _label.height) / 2.0), Backdrop.palette.ink)


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not _shown_whole():
		return
	accept_event()
	if touch.pressed:
		_finger = touch.index
		return
	var lifted := touch.index == _finger and not touch.canceled and Rect2(Vector2.ZERO, size).has_point(touch.position)
	_finger = -1
	if lifted:
		_press()


## Pressed, then let go a frame later, as a real press is.
func _press() -> void:
	for down: bool in [true, false]:
		var press := InputEventJoypadButton.new()
		press.button_index = _PRESSES[button]
		press.pressed = down
		Input.parse_input_event(press)
		if down:
			await get_tree().process_frame


## Whether the hint shows whole: none of it or of what holds it faded.
func _shown_whole() -> bool:
	var alpha := self_modulate.a
	var item: CanvasItem = self
	while item != null:
		alpha *= item.modulate.a
		item = item.get_parent() as CanvasItem
	return alpha > 0.99
