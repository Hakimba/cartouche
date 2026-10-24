# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonMark
extends RefCounted
## Draws a face button's mark in white: a letter in the design's key face, or one of PlayStation's shapes
## drawn as strokes (fonts rarely have them); and, for the button style cards, the dark disc under it.

## How wide the pad's two arrows are drawn on a key of the design's size, in px (2.8 cqw).
const PAD_ARROWS_PX := 35.84

## Each letter shaped once, by its text, then by its scale.
static var _letters: Dictionary[String, Dictionary] = {}


## Draws a disc of [param radius] centred on [param at] in [param canvas], with [param mark] ("A", "✕",
## "○"…) [param size] pixels high on it; a capsule [param stretch] pixels longer on each side for a word
## (Start), its letters smaller.
static func draw(canvas: CanvasItem, mark: String, at: Vector2, radius: float, size: float, stretch := 0.0) -> void:
	canvas.draw_circle(at - Vector2(stretch, 0.0), radius, StudioTokens.INK, true, -1.0, true)
	if stretch > 0.0:
		canvas.draw_circle(at + Vector2(stretch, 0.0), radius, StudioTokens.INK, true, -1.0, true)
		canvas.draw_rect(Rect2(at - Vector2(stretch, radius), Vector2(stretch * 2.0, radius * 2.0)), StudioTokens.INK)
		size *= 0.62
	draw_mark(canvas, mark, at, size / StudioTokens.ROLE_PX[StudioTokens.Role.KEY], size)


## Draws [param mark] centred on [param at] in [param canvas]: a letter at the key role's size times
## [param letter_scale], a shape [param shape_size] pixels high.
static func draw_mark(canvas: CanvasItem, mark: String, at: Vector2, letter_scale: float, shape_size: float) -> void:
	var white := Color.WHITE
	var r := shape_size * 0.4
	var width := maxf(2.0, shape_size * 0.1)
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
		"← →":
			for arrow in pad_arrows(at, letter_scale * PAD_ARROWS_PX / 26.0):
				canvas.draw_colored_polygon(arrow, white)
		"◎":
			# A stick seen from above: its ring and its knob.
			canvas.draw_arc(at, r * 1.1, 0.0, TAU, 32, white, width, true)
			canvas.draw_circle(at, r * 0.45, white, true, -1.0, true)
		_:
			var by_scale: Dictionary = _letters.get_or_add(mark, {})
			if letter_scale not in by_scale:
				by_scale[letter_scale] = StudioText.of(StudioTokens.Role.KEY, mark, letter_scale)
			var letters: StudioText = by_scale[letter_scale]
			letters.draw(canvas, at - Vector2(letters.width, letters.height) / 2.0, white)


## The pad's two arrows as the design draws them (a 26 x 12 box, a triangle at each end), [param unit] px to a unit of
## it, centred on [param at]: the left one, then the right one.
static func pad_arrows(at: Vector2, unit: float) -> Array[PackedVector2Array]:
	var arrows: Array[PackedVector2Array] = []
	for ends: Vector2 in [Vector2(1.0, 8.0), Vector2(25.0, 18.0)]:
		var points := PackedVector2Array([Vector2(ends.x, 6.0), Vector2(ends.y, 1.0), Vector2(ends.y, 11.0)])
		for k in 3:
			points[k] = at + (points[k] - Vector2(13.0, 6.0)) * unit
		arrows.append(points)
	return arrows
