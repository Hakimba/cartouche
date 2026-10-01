# SPDX-License-Identifier: GPL-3.0-or-later
class_name NoConsole
extends Control
## Nothing set up yet: one thing to do, add a console. Y opens the settings, as on the consoles
## screen.

## [param choice] is `add` or `settings`.
signal chosen(choice: StringName)

@onready var _add: Button = %Add


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"open_settings"):
		get_viewport().set_input_as_handled()
		chosen.emit(&"settings")


func focus() -> void:
	_add.grab_focus()


func _on_add_pressed() -> void:
	chosen.emit(&"add")
