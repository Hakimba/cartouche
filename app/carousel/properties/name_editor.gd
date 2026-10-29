# SPDX-License-Identifier: GPL-3.0-or-later
class_name NameEditor
extends Control
## A name typed on a [GamepadKeyboard] under the field showing it, at a caret that starts before its
## first letter and stays in view when the name is long; blank, the field shows faded the name it
## falls back to. Its owner maps X to [method erase], Y to [method space], L1 and R1 to
## [method move_caret] and Start to keeping it, so that no press counts while it is busy.

## OK pressed on the keyboard.
signal submitted

## The longest name kept, in characters, as `DisplayName` cuts it.
const _LONGEST := 80
const _BLANK_ALPHA := 0.45

var _typed := ""
## Where the next character goes, in characters from the start.
var _caret := 0
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
	_caret = 0
	_own = own
	_show()


func typed() -> String:
	return _typed


func focus_keys() -> void:
	_keyboard.first_letter().grab_focus()


## Erases the character before the caret.
func erase() -> void:
	if _caret > 0:
		_typed = _typed.erase(_caret - 1)
		_caret -= 1
		_show()


## Moves the caret [param by] characters, within the name.
func move_caret(by: int) -> void:
	_caret = clampi(_caret + by, 0, _typed.length())
	_show()


func space() -> void:
	_keyboard.space()


func _type(character: String) -> void:
	if _typed.length() < _LONGEST:
		_typed = _typed.insert(_caret, character)
		_caret += 1
		_show()


## The name typed with its caret, from the first character that keeps the caret in the field; a capital
## first and after a space, as names are written.
func _show() -> void:
	_keyboard.capital = _caret == 0 or _typed[_caret - 1] == " "
	_field.self_modulate.a = 1.0 if _typed else _BLANK_ALPHA
	if not _typed:
		_field.text = _own
		return
	var shown := _typed.insert(_caret, "|")
	var font := _field.get_theme_font(&"font")
	var font_size := _field.get_theme_font_size(&"font_size")
	var start := 0
	while start < _caret and font.get_string_size(shown.substr(start, _caret + 1 - start), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x > _field.size.x:
		start += 1
	_field.text = shown.substr(start)
