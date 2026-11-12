# SPDX-License-Identifier: GPL-3.0-or-later
class_name NoConsole
extends Page
## Nothing set up yet: one thing to do, add a console. Y opens the settings, as on the consoles
## screen. It answers `add` or `settings`.

@onready var _add: Button = %Add


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		Sounds.play(SoundEffects.Cue.SETTINGS)
		done.emit(&"settings")


func _open(_request: Variant) -> void:
	_add.grab_focus()


func _on_add_pressed() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	done.emit(&"add")
