# SPDX-License-Identifier: GPL-3.0-or-later
class_name NameEditor
extends Control
## A name typed on a [GamepadKeyboard] under the field showing it, its end in view when it is
## long; blank, the field shows faded the name it falls back to. Its owner maps X to [method erase],
## Y to [method space] and Start to keeping it, so that no press counts while it is busy.

## OK pressed on the keyboard.
signal submitted

## The longest name kept, in characters, as `DisplayName` cuts it.
const _LONGEST := 80
const _BLANK_ALPHA := 0.45

var _typed := ""
## What a blank name falls back to.
var _own := ""

@onready var _field: Label = %FieldText
@onready var _keyboard: GamepadKeyboard = %Keyboard


func _ready() -> void:
	_keyboard.typed.connect(_type)
	_keyboard.erased.connect(erase)
	_keyboard.submitted.connect(submitted.emit)


## Starts from [param current], a blank name falling back to [param own].
func open(current: String, own: String) -> void:
	_keyboard.build()
	_typed = current
	_own = own
	_show()


func typed() -> String:
	return _typed


func focus_keys() -> void:
	_keyboard.first_letter().grab_focus()


func erase() -> void:
	_typed = _typed.left(-1)
	_show()


func space() -> void:
	_keyboard.space()


func _type(character: String) -> void:
	if _typed.length() < _LONGEST:
		_typed += character
		_show()


## The name typed with a caret after it; a capital first and after a space, as names are written.
func _show() -> void:
	_keyboard.capital = _typed.is_empty() or _typed.ends_with(" ")
	_field.text = _typed + "|" if _typed else _own
	_field.self_modulate.a = 1.0 if _typed else _BLANK_ALPHA
	var font_size := _field.get_theme_font_size(&"font_size")
	var wide := _field.get_theme_font(&"font").get_string_size(_field.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	_field.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if wide > _field.size.x else HORIZONTAL_ALIGNMENT_LEFT
