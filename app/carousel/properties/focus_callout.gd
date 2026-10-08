# SPDX-License-Identifier: GPL-3.0-or-later
class_name FocusCallout
extends Control
## What the focus is on, said beside it: a caption, and a thin black arrow from it to the part, as a
## diagram's callout. Hidden while nothing is pointed at.

const _INK := Color(0.13, 0.14, 0.17)
const _WIDTH := 2.5
## The arrow's head, in pixels: its length, and how far each side spreads.
const _HEAD := Vector2(14.0, 7.0)
const _FADE_S := 0.15

## Where the arrow starts and ends, in this control's space.
var _from := Vector2.ZERO
var _to := Vector2.ZERO
var _fade: Tween

@onready var _caption: Label = $Caption


func _ready() -> void:
	modulate.a = 0.0


func _draw() -> void:
	draw_line(_from, _to, _INK, _WIDTH, true)
	var back := (_from - _to).normalized() * _HEAD.x
	var side := back.orthogonal().normalized() * _HEAD.y
	draw_colored_polygon(PackedVector2Array([_to, _to + back + side, _to + back - side]), _INK)


## Says [param caption] with its left edge's middle at [param at], the arrow pointing at
## [param target]; shows it if it was hidden.
func point(caption: String, at: Vector2, target: Vector2) -> void:
	if _caption.text != caption or modulate.a < 1.0:
		_caption.text = caption
		# A label only grows by itself: back to the new text's size.
		_caption.reset_size()
		_fade_to(1.0)
	_caption.position = at - Vector2(0.0, _caption.size.y / 2.0)
	# Pointed at every frame: the arrow is drawn again only when it moves.
	if at != _from or target != _to:
		_from = at
		_to = target
		queue_redraw()


func clear() -> void:
	_fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if _fade:
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(self, ^"modulate:a", alpha, _FADE_S)
