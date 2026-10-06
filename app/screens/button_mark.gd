# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonMark
extends RefCounted
## Draws a face button: its dark disc, and on it its mark in white, a letter in the theme's font
## or one of PlayStation's shapes drawn as strokes (fonts rarely have them).

const INK := Color(0.13, 0.14, 0.17)


## Draws a disc of [param radius] centred on [param at] in [param canvas], with [param mark]
## ("A", "✕", "○"…) [param size] pixels high on it; a capsule [param stretch] pixels longer on each
## side for a word (Start), its letters smaller.
static func draw(canvas: Control, mark: String, at: Vector2, radius: float, size: float, stretch := 0.0) -> void:
	canvas.draw_circle(at - Vector2(stretch, 0.0), radius, INK, true, -1.0, true)
	if stretch > 0.0:
		canvas.draw_circle(at + Vector2(stretch, 0.0), radius, INK, true, -1.0, true)
		canvas.draw_rect(Rect2(at - Vector2(stretch, radius), Vector2(stretch * 2.0, radius * 2.0)), INK)
		size *= 0.62
	var white := Color.WHITE
	var r := size * 0.4
	var width := maxf(2.0, size * 0.1)
	match mark:
		"✕":
			canvas.draw_line(at - Vector2(r, r), at + Vector2(r, r), white, width, true)
			canvas.draw_line(at + Vector2(-r, r), at + Vector2(r, -r), white, width, true)
		"○":
			canvas.draw_arc(at, r, 0.0, TAU, 32, white, width, true)
		"△":
			var top := at + Vector2(0, -r * 1.1)
			canvas.draw_polyline([top, at + Vector2(r * 1.1, r * 0.8), at + Vector2(-r * 1.1, r * 0.8), top], white, width, true)
		"□":
			canvas.draw_rect(Rect2(at - Vector2(r, r) * 0.9, Vector2(r, r) * 1.8), white, false, width, true)
		"◎":
			# A stick seen from above: its ring and its knob.
			canvas.draw_arc(at, r * 1.1, 0.0, TAU, 32, white, width, true)
			canvas.draw_circle(at, r * 0.45, white, true, -1.0, true)
		_:
			var font := canvas.get_theme_font(&"font", &"GlyphText")
			var font_size := roundi(size)
			var text_width := font.get_string_size(mark, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var baseline := at.y + (font.get_ascent(font_size) - font.get_descent(font_size)) / 2.0
			canvas.draw_string(font, Vector2(at.x - text_width / 2.0, baseline), mark, HORIZONTAL_ALIGNMENT_LEFT, -1,
				font_size, white)
