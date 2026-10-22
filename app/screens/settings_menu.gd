# SPDX-License-Identifier: GPL-3.0-or-later
class_name SettingsMenu
extends Control
## "Settings", over the screen it was opened from: the platforms set up, the button style, the
## graphics (the edges' smoothing) and the region whose images labels prefer, chosen in a list. B
## closes.

## [param choice] is `platforms`, `button_style`, `graphics`, `region`, or `close` (B).
signal chosen(choice: StringName)

@onready var _platforms: FieldButton = %Platforms
@onready var _button_style: FieldButton = %ButtonStyle
@onready var _graphics: FieldButton = %Graphics
@onready var _region: FieldButton = %Region
@onready var _choice: ChoiceList = %Choice


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and not _choice.visible and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		chosen.emit(&"close")


## Shows how many [param platforms] are set up, the button style, the edges' smoothing and the
## preferred [param region] (empty for none), the focus on the line of [param focus] (a choice). With
## no platform, its line cannot be opened.
func open(platforms: int, focus: StringName, region: String) -> void:
	_platforms.show_value(str(platforms))
	_platforms.disabled = platforms == 0
	_platforms.focus_mode = FOCUS_NONE if _platforms.disabled else FOCUS_ALL
	_button_style.show_value(Controls.style_name())
	_graphics.show_value(tr(EdgeSmoothingScreen.NAMES[EdgeSmoothingScreen.of(get_viewport())]))
	_region.show_value(_region_name(region))
	if focus == &"graphics":
		_graphics.grab_focus()
	elif focus == &"region":
		_region.grab_focus()
	else:
		(_button_style if focus == &"button_style" or _platforms.disabled else _platforms).grab_focus()


## The region chosen among none and [param regions], as the plugin names them, the focus first on
## [param current]; [param current] when given up.
func choose_region(current: String, regions: PackedStringArray) -> String:
	var choices := PackedStringArray([""]) + regions
	var names := PackedStringArray()
	for region in choices:
		names.append(_region_name(region))
	var index := await _choice.choose(tr("Preferred region of images"), names, choices.find(current))
	_region.grab_focus()
	return current if index < 0 else choices[index]


func _region_name(region: String) -> String:
	return tr(region) if region else tr("None")


func _on_platforms_pressed() -> void:
	chosen.emit(&"platforms")


func _on_button_style_pressed() -> void:
	chosen.emit(&"button_style")


func _on_graphics_pressed() -> void:
	chosen.emit(&"graphics")


func _on_region_pressed() -> void:
	chosen.emit(&"region")
