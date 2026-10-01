# SPDX-License-Identifier: GPL-3.0-or-later
class_name SettingsMenu
extends Control
## "Settings", over the screen it was opened from: the platforms set up, and the button style.
## B closes.

## [param choice] is `platforms`, `button_style`, or `close` (B).
signal chosen(choice: StringName)

@onready var _platforms: FieldButton = %Platforms
@onready var _button_style: FieldButton = %ButtonStyle


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		chosen.emit(&"close")


## Shows how many [param platforms] are set up and the button style, the focus on the line of
## [param focus] (a choice). With no platform, its line cannot be opened.
func open(platforms: int, focus: StringName) -> void:
	_platforms.show_value(str(platforms))
	_platforms.disabled = platforms == 0
	_platforms.focus_mode = FOCUS_NONE if _platforms.disabled else FOCUS_ALL
	_button_style.show_value(Controls.style_name())
	(_button_style if focus == &"button_style" or _platforms.disabled else _platforms).grab_focus()


func _on_platforms_pressed() -> void:
	chosen.emit(&"platforms")


func _on_button_style_pressed() -> void:
	chosen.emit(&"button_style")
