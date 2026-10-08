# SPDX-License-Identifier: GPL-3.0-or-later
class_name GamepadKeyboard
extends VBoxContainer
## A keyboard played with the stick or the d-pad, A typing the key with the focus: digits, letters
## in the French order, accents and a few signs, then Shift, Space, Erase and OK. A capital comes
## first and after each space, as names are written; Shift turns the next letter the other way. Its
## keys are made when it is first needed ([method build]): some 15 ms on a handheld, not to be paid
## at every start.

## [param character] typed: a letter, a digit, a sign or a space.
signal typed(character: String)
signal erased
signal submitted

const _ROWS: Array[String] = ["1234567890", "azertyuiop", "qsdfghjklm", "wxcvbn'-.:", "éèàçù&!?/,"]

## Whether the next letter is a capital.
var capital := true:
	set(value):
		capital = value
		_show_case()

var _letters: Array[Button] = []


## Makes the keys, once.
func build() -> void:
	if not _letters.is_empty():
		return
	add_theme_constant_override(&"separation", 10)
	for row in _ROWS:
		var keys := _row()
		for character in row:
			var key := _key(character, _type.bind(character))
			if character.to_upper() != character:
				_letters.append(key)
			keys.add_child(key)
	var last := _row()
	last.add_child(_key(tr("Shift"), func() -> void: capital = not capital, 1.5))
	last.add_child(_key(tr("Space"), _type.bind(" "), 3.0))
	last.add_child(_key(tr("Erase"), erased.emit, 1.5))
	last.add_child(_key(tr("OK"), submitted.emit, 1.5))
	_show_case()


## Types a space, as the Space key does.
func space() -> void:
	_type(" ")


## The key the focus starts on: the first letter.
func first_letter() -> Button:
	return _letters[0]


## Types [param character] as the keyboard's case has it.
func _type(character: String) -> void:
	typed.emit(character.to_upper() if capital else character)
	capital = character == " "


func _show_case() -> void:
	for key in _letters:
		key.text = key.text.to_upper() if capital else key.text.to_lower()


func _row() -> HBoxContainer:
	var keys := HBoxContainer.new()
	keys.size_flags_vertical = SIZE_EXPAND_FILL
	keys.add_theme_constant_override(&"separation", 10)
	add_child(keys)
	return keys


func _key(caption: String, press: Callable, stretch := 1.0) -> Button:
	var key := Button.new()
	key.theme_type_variation = &"Key"
	key.text = caption
	key.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	key.size_flags_horizontal = SIZE_EXPAND_FILL
	key.size_flags_stretch_ratio = stretch
	key.size_flags_vertical = SIZE_EXPAND_FILL
	key.pressed.connect(press)
	return key
