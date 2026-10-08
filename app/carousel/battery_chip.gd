# SPDX-License-Identifier: GPL-3.0-or-later
class_name BatteryChip
extends Label
## The battery's level in the top bar, and a bolt drawn after it while the device is plugged in. The
## bolt is drawn rather than written as the system's emoji, whose font takes some 12 MB of memory for
## that one character.

## The bolt's outline, in parts of its size, and its colours: close to the emoji's.
const _BOLT: Array[Vector2] = [Vector2(0.5, 0.0), Vector2(1.0, 0.0), Vector2(0.66, 0.42), Vector2(0.92, 0.42),
	Vector2(0.1, 1.0), Vector2(0.36, 0.56), Vector2(0.06, 0.56)]
const _FILL := Color("ffcd2e")
const _EDGE := Color("f2a900")

var _plugged := false


func _draw() -> void:
	var points := bolt()
	if points.is_empty():
		return
	draw_colored_polygon(points, _FILL)
	points.append(points[0])
	draw_polyline(points, _EDGE, 1.0, true)


## The bolt's outline in the chip, after the level; none while unplugged.
func bolt() -> PackedVector2Array:
	if not _plugged:
		return PackedVector2Array()
	var room := _room()
	var size_of := Vector2(0.8, 1.0) * room * 0.58
	var corner := Vector2(size.x - get_theme_stylebox(&"normal").get_margin(SIDE_RIGHT) - (room + size_of.x) / 2.0,
		(size.y - size_of.y) / 2.0)
	return Transform2D(0.0, size_of, 0.0, corner) * PackedVector2Array(_BOLT)


## Shows [param battery]: its level when known, and the bolt while it is plugged in.
func show_battery(battery: AndroidServices.Battery) -> void:
	text = "%d %%" % battery.level_percent if battery.has_level else ""
	_plugged = battery.plugged
	custom_minimum_size.x = 0.0
	if _plugged:
		var font := get_theme_font(&"font")
		var font_size := get_theme_font_size(&"font_size")
		var gap := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if text else 0.0
		custom_minimum_size.x = get_theme_stylebox(&"normal").get_minimum_size().x + gap + _room() \
			+ font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	queue_redraw()
	Diagnostics.trace("battery", "%s, %s" % [text if text else "level unknown", "plugged in" if _plugged else "unplugged"])


## The room the bolt takes after the level, about the emoji's.
func _room() -> float:
	return get_theme_font(&"font").get_height(get_theme_font_size(&"font_size")) * 0.92
