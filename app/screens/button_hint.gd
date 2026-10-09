# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonHint
extends PanelContainer
## A controller button and what it does, small: "Y Settings".

## The button, as [method Controls.mark] names it.
@export var button := &"a"
@export var text := "":
	set(shown):
		text = shown
		if _label:
			_label.text = shown

var _label: Label


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var items := HBoxContainer.new()
	items.add_theme_constant_override(&"separation", 10)
	items.mouse_filter = MOUSE_FILTER_IGNORE
	var glyph := ButtonGlyph.new()
	glyph.button = button
	glyph.size_flags_vertical = SIZE_SHRINK_CENTER
	_label = Label.new()
	_label.theme_type_variation = &"HintText"
	_label.text = text
	items.add_child(glyph)
	items.add_child(_label)
	add_child(items)
