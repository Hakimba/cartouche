# SPDX-License-Identifier: GPL-3.0-or-later
class_name GlyphButton
extends Button
## A button of the screens, as wide as its text: grows a little while focused, and may show the
## mark of the button that confirms on its left ([member shows_glyph]), its text moved over.

## Room the mark takes on the left: its margin, its width and the gap to the text.
const _GLYPH_ROOM := 22.0 + 30.0 + 12.0

@export var shows_glyph := false

var _focus_scale := FocusScale.new()


func _ready() -> void:
	_focus_scale.watch(self)
	if shows_glyph:
		for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
			var box: StyleBox = get_theme_stylebox(state).duplicate()
			box.content_margin_left = _GLYPH_ROOM
			add_theme_stylebox_override(state, box)
		var glyph := ButtonGlyph.new()
		glyph.anchor_top = 0.5
		glyph.anchor_bottom = 0.5
		glyph.offset_left = 22.0
		glyph.offset_right = 52.0
		glyph.offset_top = -15.0
		glyph.offset_bottom = 15.0
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(glyph)
