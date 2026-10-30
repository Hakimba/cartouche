# SPDX-License-Identifier: GPL-3.0-or-later
class_name ButtonHint
extends Control
## A controller button and what it does, small: "Y Settings", the key then its label, in a [HintRow].

## The button, as [method Controls.mark] names it.
@export var button := &"a"
@export var text := "":
	set(shown):
		if shown == text:
			return
		text = shown
		_label = StudioText.of(StudioTokens.Role.HINT, tr(shown))
		update_minimum_size()
		queue_redraw()

var _key := SatinPanel.Backing.new(self, StudioTokens.Look.KEY)
var _label := StudioText.of(StudioTokens.Role.HINT, "")


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	add_to_group(ButtonGlyph.GROUP)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_label = StudioText.of(StudioTokens.Role.HINT, tr(text))
			update_minimum_size()
			queue_redraw()
		NOTIFICATION_RESIZED:
			queue_redraw()


func _get_minimum_size() -> Vector2:
	var key := ButtonGlyph.key_size(button)
	return Vector2(key.x + StudioTokens.HINT_GAP + _label.width, maxf(key.y, _label.height))


func _draw() -> void:
	var key := ButtonGlyph.key_size(button)
	ButtonGlyph.draw_key(self, _key, Rect2(Vector2(0.0, (size.y - key.y) / 2.0), key), button)
	_label.draw(self, Vector2(key.x + StudioTokens.HINT_GAP, (size.y - _label.height) / 2.0), StudioTokens.INK)
