# SPDX-License-Identifier: GPL-3.0-or-later
class_name BatteryChip
extends StudioPill
## The battery's level in the top bar, and a bolt drawn after it while the device is plugged in. The bolt
## is drawn rather than written as the system's emoji, whose font takes some 12 MB of memory for that one
## character.

var _plugged := false
## The bolt, rasterised once.
var _bolt: ImageTexture


func _draw() -> void:
	super._draw()
	if not _plugged:
		return
	if not _bolt:
		var path := " ".join(Array(_bolt_shape(Vector2.ZERO)).map(func(point: Vector2) -> String: return "%f,%f" % [point.x, point.y]))
		var room := (StudioTokens.BOLT_VIEW * _bolt_scale()).ceil()
		var picture := Image.new()
		picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><path d="M%sz" fill="#%s"/></svg>'
			% [room.x, room.y, path, StudioTokens.BOLT.to_html(false)])
		_bolt = ImageTexture.create_from_image(picture)
	# The browser draws the bolt's SVG rasterised, its box on whole pixels.
	draw_texture(_bolt, _bolt_corner().round())


## The bolt's outline in the pill, after the level; none while unplugged.
func bolt() -> PackedVector2Array:
	if not _plugged:
		return PackedVector2Array()
	return _bolt_shape(_bolt_corner().round())


func _bolt_shape(corner: Vector2) -> PackedVector2Array:
	return Transform2D(0.0, Vector2.ONE * _bolt_scale(), 0.0, corner) * PackedVector2Array(StudioTokens.BOLT_SHAPE)


func _bolt_scale() -> float:
	return StudioTokens.BOLT_HEIGHT / StudioTokens.BOLT_VIEW.y


## The bolt's top left: after the level, centred with it.
func _bolt_corner() -> Vector2:
	return Vector2(_text_left() + _line.width + _beside_text() - StudioTokens.BOLT_VIEW.x * _bolt_scale(),
		(size.y - StudioTokens.BOLT_HEIGHT) / 2.0)


## Shows [param battery]: its level when known, and the bolt while it is plugged in.
func show_battery(battery: AndroidServices.Battery) -> void:
	_plugged = battery.plugged
	text = "%d %%" % battery.level_percent if battery.has_level else ""
	queue_redraw()
	Diagnostics.trace("battery", "%s, %s" % [text if text else "level unknown", "plugged in" if _plugged else "unplugged"])


## The bolt after the level, the design's gap between them (none without a level).
func _beside_text() -> float:
	if not _plugged:
		return 0.0
	return (StudioTokens.PILL_GAP if text else 0.0) + StudioTokens.BOLT_VIEW.x * StudioTokens.BOLT_HEIGHT / StudioTokens.BOLT_VIEW.y
