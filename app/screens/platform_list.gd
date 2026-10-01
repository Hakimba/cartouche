# SPDX-License-Identifier: GPL-3.0-or-later
class_name PlatformList
extends Control
## "Platforms": one line per platform set up, to open it and change or remove it. B goes back.

## The platform at [param index] in the list was opened; -1 for back.
signal chosen(index: int)

const _ROW := preload("res://screens/menu_row.tscn")

@onready var _rows: VBoxContainer = %Rows


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"screen_back"):
		get_viewport().set_input_as_handled()
		chosen.emit(-1)


## Lists [param platforms] (at least one) by name, the focus on the one at [param focus].
func open(platforms: Array[AndroidServices.Platform], focus: int) -> void:
	for row in _rows.get_children():
		# At once: the focus must not land on a line about to go.
		_rows.remove_child(row)
		row.queue_free()
	for i in platforms.size():
		var row: FieldButton = _ROW.instantiate()
		row.label = platforms[i].name
		# A name, never translated.
		row.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		row.pressed.connect(chosen.emit.bind(i))
		_rows.add_child(row)
	(_rows.get_child(clampi(focus, 0, platforms.size() - 1)) as Control).grab_focus()
