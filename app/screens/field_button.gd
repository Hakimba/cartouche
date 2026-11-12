# SPDX-License-Identifier: GPL-3.0-or-later
class_name FieldButton
extends Button
## A menu line holding its name and its value (a name, never translated); A acts on it. The settings card paints both
## and this button only carries the focus.

@export var label := ""

var _value := ""


## The value shown under the field's name.
func show_value(shown: String) -> void:
	_value = shown


## The displayed value.
func shown_value() -> String:
	return _value
