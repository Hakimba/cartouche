# SPDX-License-Identifier: GPL-3.0-or-later
class_name Controls
extends RefCounted
## How the controller's buttons are drawn, as the user chose: Xbox's letters, Nintendo's or
## PlayStation's shapes. Only drawn: confirming and going back follow the buttons as the device
## sends them (its own settings may swap them), as in every app.

## Each style's name.
const NAMES: Dictionary[StringName, String] = {&"xbox": "Xbox", &"nintendo": "Nintendo", &"playstation": "PlayStation"}
const _SHAPES: Dictionary[StringName, String] = {&"a": "✕", &"b": "○", &"y": "△"}

## `xbox`, `nintendo` or `playstation`.
static var style := &"xbox"


## The mark of [param button] (`a`, `b` or `y`, as Android names it), as [member style]
## draws it.
static func mark(button: StringName) -> String:
	return _SHAPES[button] if style == &"playstation" else String(button).to_upper()


## The style's name: Xbox, Nintendo or PlayStation.
static func style_name() -> String:
	return NAMES[style]
