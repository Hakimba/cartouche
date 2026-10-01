# SPDX-License-Identifier: GPL-3.0-or-later
class_name FieldButton
extends Button
## A form field or a menu line: its name, and its value (a name, never translated), with a chevron
## on the right; A acts on it. Its scene places them: the name small and grey above the value
## (`field_button.tscn`), or the name on the left and the value grey on the right (`menu_row.tscn`).

@export var label := ""

var _focus_scale := FocusScale.new()

@onready var _value: Label = %Value


func _ready() -> void:
	(%Name as Label).text = label
	_focus_scale.watch(self)


## The value shown under the field's name.
func show_value(shown: String) -> void:
	_value.text = shown
