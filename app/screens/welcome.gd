# SPDX-License-Identifier: GPL-3.0-or-later
class_name Welcome
extends Control
## The title screen of the first launch: "Cartouche" in the middle, a worm of colour going round its
## outline. It waits for a button, any one; after a moment, a line says so.

## Seconds before the line asking for a button fades in, and the time it takes.
const _HINT_AFTER_S := 1.5
const _HINT_FADE_S := 0.6

var _pressed := false

@onready var _logo: Label = %Logo
@onready var _worm: LogoWorm = %Worm
@onready var _hint: Label = %Hint


func _ready() -> void:
	_worm.follow(_logo)
	_hint.modulate.a = 0.0
	create_tween().tween_property(_hint, ^"modulate:a", 1.0, _HINT_FADE_S).set_delay(_HINT_AFTER_S)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_pressed() and not event.is_echo() and (event is InputEventJoypadButton or event is InputEventKey):
		get_viewport().set_input_as_handled()
		_pressed = true
		Sounds.play(SoundEffects.Cue.SELECT)
		Diagnostics.trace("screens", "welcome passed")


## Returns once a button is pressed, or at once if one was pressed already.
func passed() -> void:
	while not _pressed:
		await get_tree().process_frame
