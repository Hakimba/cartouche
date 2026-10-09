# SPDX-License-Identifier: GPL-3.0-or-later
class_name TitleMarks
extends Control
## Underlines, in the title it lies over, where the words typed in the ribbon are ([GameSearch]),
## and makes them bolder.

const _THICKNESS := 3.0
## The letters drawn again this far to the right: bolder, in the title's own font.
const _BOLDER := 0.8
## How far below the letters' baseline the line runs.
const _BELOW := 5.0

## (start, length) in characters of the title.
var marks: Array[Vector2i] = []:
	set(found):
		marks = found
		queue_redraw()

@onready var _title: Label = get_parent()


func _draw() -> void:
	var font := _title.get_theme_font(&"font")
	var font_size := _title.get_theme_font_size(&"font_size")
	var y := (_title.size.y - font.get_height(font_size)) / 2.0 + font.get_ascent(font_size) + _BELOW
	var ink := _title.get_theme_color(&"font_color")
	for mark in marks:
		var start := font.get_string_size(_title.text.left(mark.x), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var width := font.get_string_size(_title.text.substr(mark.x, mark.y), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_line(Vector2(start, y), Vector2(start + width, y), ink, _THICKNESS, true)
		draw_string(font, Vector2(start + _BOLDER, y - _BELOW), _title.text.substr(mark.x, mark.y), HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, ink)
