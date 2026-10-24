# SPDX-License-Identifier: GPL-3.0-or-later
class_name HintRow
extends SatinPanel
## The one hint row of every screen: its [ButtonHint] children on a frost pill at the design's place,
## bottom left, a thin line between each two, growing to the right only (the bottom right stays free).
## Hints are laid at their exact x (a BoxContainer would round each to a whole pixel).


func _init() -> void:
	look = StudioTokens.Look.FROST
	mouse_filter = MOUSE_FILTER_IGNORE


func _ready() -> void:
	set_notify_transform(true)
	_pin()
	_fit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_pin()


## The design's place on the screen, wherever the screen's own parts start and wherever they move.
func _pin() -> void:
	if global_position != StudioTokens.HINTS.position:
		global_position = StudioTokens.HINTS.position


func _lay_out() -> void:
	_fit()
	var x := StudioTokens.HINTS_PADDING_LEFT
	for hint in _shown():
		var width := hint.get_combined_minimum_size().x
		fit_child_in_rect(hint, Rect2(x, 0.0, width, size.y))
		x += width + 2.0 * StudioTokens.HINTS_GAP + StudioTokens.HINT_SEPARATOR.x
	queue_redraw()


func _get_minimum_size() -> Vector2:
	var hints := _shown()
	var width := StudioTokens.HINTS_PADDING_LEFT + StudioTokens.HINTS_PADDING_RIGHT \
		+ maxf(0.0, hints.size() - 1.0) * (2.0 * StudioTokens.HINTS_GAP + StudioTokens.HINT_SEPARATOR.x)
	for hint in hints:
		width += hint.get_combined_minimum_size().x
	return Vector2(width, StudioTokens.HINTS.size.y)


func _draw() -> void:
	for line in separators():
		draw_rect(line, StudioTokens.LINE)


## The thin lines between each two hints shown, in the row.
func separators() -> Array[Rect2]:
	var hints := _shown()
	var lines: Array[Rect2] = []
	var line := StudioTokens.HINT_SEPARATOR
	for i in hints.size() - 1:
		var x := hints[i].position.x + hints[i].size.x + StudioTokens.HINTS_GAP
		lines.append(Rect2(x, (size.y - line.y) / 2.0, line.x, line.y))
	return lines


## The row as wide as its hints, never wider: hiding one shrinks it.
func _fit() -> void:
	var fitted := _get_minimum_size()
	if size != fitted:
		size = fitted
