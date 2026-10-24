# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioNameButton
extends Button
## A button whose theme variation is a tracked role ([constant TrackedText.ROLES]), its caption drawn through
## [StudioText] at the role's tracking, cut with an ellipsis when it outgrows the button; the button's own
## frame, focus and size are the theme's.

var _ink := Color.BLACK
var _outline_size := 0
var _outline := Color.WHITE


func _ready() -> void:
	_ink = get_theme_color(&"font_color")
	_outline_size = get_theme_constant(&"outline_size")
	_outline = get_theme_color(&"font_outline_color")
	# The engine's own glyphs stay unseen: the layout still measures with them.
	for state: StringName in [&"font_color", &"font_focus_color", &"font_hover_color", &"font_pressed_color", &"font_disabled_color",
			&"font_outline_color"]:
		add_theme_color_override(state, Color.TRANSPARENT)


func _draw() -> void:
	var line := TrackedText.line(theme_type_variation, atr(text), get_theme_font_size(&"font_size"))
	var frame := get_theme_stylebox(&"normal")
	line.fit(size.x - frame.get_minimum_size().x)
	var left := frame.get_margin(SIDE_LEFT)
	var x := left + (size.x - frame.get_minimum_size().x - line.width) / 2.0
	var y := (size.y - line.height) / 2.0
	line.draw(self, Vector2(x, y), _ink, _outline_size, _outline)
