# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioPill
extends SatinPanel
## One line of text on a frost pill, centred in it with what it holds beside the text, cut with an
## ellipsis when it does not fit. The pill keeps the size it is given.

## The text's role.
var role := StudioTokens.Role.PILL:
	set(value):
		role = value
		_line = StudioText.of(role, tr(text))
		queue_redraw()
var text := "":
	set(shown):
		if shown == text:
			return
		text = shown
		_line = StudioText.of(role, tr(shown))
		queue_redraw()

var _line := StudioText.of(StudioTokens.Role.PILL, "")


func _init() -> void:
	look = StudioTokens.Look.FROST
	mouse_filter = MOUSE_FILTER_IGNORE


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSLATION_CHANGED:
			_line = StudioText.of(role, tr(text))
			queue_redraw()
		NOTIFICATION_RESIZED:
			queue_redraw()


func _draw() -> void:
	# Room for the text: the pill less its round ends and what else it centres with the text.
	_line.fit(size.x - 2.0 * StudioTokens.FROST_RADIUS - _beside_text())
	_line.draw(self, Vector2(_text_left(), (size.y - _line.height) / 2.0), StudioTokens.INK)


## How wide what the pill centres after its text is: nothing.
func _beside_text() -> float:
	return 0.0


## Where the text starts, from the pill's left: the text and what is beside it centred together.
func _text_left() -> float:
	return (size.x - _line.width - _beside_text()) / 2.0
