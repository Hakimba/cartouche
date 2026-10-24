# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonGlyph
extends Control
## The mark of a controller button on the design's dark key, as the [Controls] style draws it.

## Every glyph, redrawn when the style changes.
const GROUP := &"button_glyphs"

## The button, as [method Controls.mark] names it.
@export var button := &"a"

var _key := SatinPanel.Backing.new(self, StudioTokens.Look.KEY)


func _ready() -> void:
	custom_minimum_size = ButtonGlyph.key_size(button)
	add_to_group(GROUP)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	ButtonGlyph.draw_key(self, _key, Rect2(Vector2.ZERO, size), button)


## The key's size: a disc, or a capsule for a mark longer than a letter (the pad's arrows, a word).
static func key_size(of: StringName) -> Vector2:
	var key := StudioTokens.KEY_SIZE
	return Vector2(StudioTokens.PAD_KEY_WIDTH if Controls.mark(of).length() > 2 else key, key)


## Draws the key of [param of] on [param box] of [param canvas], its dark material on [param key].
static func draw_key(canvas: CanvasItem, key: SatinPanel.Backing, box: Rect2, of: StringName) -> void:
	var height := box.size.y
	var scale_by := height / StudioTokens.KEY_SIZE
	key.place(box, height / 2.0 if box.size.x <= height else StudioTokens.PAD_KEY_RADIUS * scale_by)
	ButtonMark.draw_mark(canvas, Controls.mark(of), box.get_center(), scale_by, StudioTokens.KEY_RADIUS * 1.3 * scale_by)
