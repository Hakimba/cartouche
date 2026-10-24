# SPDX-License-Identifier: GPL-3.0-or-later
class_name FieldButton
extends Button
## A menu line: its name on the left and its value (a name, never translated) grey on the right, with a
## chevron; A acts on it. Its scene (`menu_row.tscn`) places them.

@export var label := ""
@export var scale_on_focus := true

var _focus_scale := FocusScale.new()

@onready var _value: Label = %Value


func _ready() -> void:
	(%Name as Label).text = label
	if scale_on_focus:
		_focus_scale.watch(self)


## The value shown under the field's name.
func show_value(shown: String) -> void:
	_value.text = shown


## The displayed value, without reaching into the row scene.
func shown_value() -> String:
	return _value.text
