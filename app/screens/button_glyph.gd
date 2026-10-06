# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonGlyph
extends Control
## The mark of a controller button on a small dark pastille, as the [Controls] style draws it.

## Every glyph, redrawn when the style changes.
const GROUP := &"button_glyphs"

## The button, as [method Controls.mark] names it.
@export var button := &"a"


func _ready() -> void:
	# A button named by a word (Start) is a capsule as long as the word.
	custom_minimum_size = Vector2(76 if Controls.mark(button).length() > 2 else 30, 30)
	add_to_group(GROUP)


func _draw() -> void:
	var radius := minf(size.x, size.y) / 2.0
	ButtonMark.draw(self, Controls.mark(button), size / 2.0, radius, radius * 1.3, size.x / 2.0 - radius)
