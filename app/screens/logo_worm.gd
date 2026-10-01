# SPDX-License-Identifier: GPL-3.0-or-later
class_name LogoWorm
extends Line2D
## A worm of changing colour crawling round the outer edge of a label's outline, such as the
## welcome screen's "Cartouche". The edge is traced once from the label as drawn (in a viewport of
## its own), so it follows whatever font, size and outline the label has.

## Distance between the points of the edge, in pixels.
const _STEP := 2.0

## Part of the edge the worm covers.
@export_range(0.01, 1.0) var length_part := 0.22
## Seconds for one turn of the edge, and for one turn of the colours.
@export var turn_s := 27.0
@export var colour_s := 7.0

## Points evenly spaced along the edge, [constant _STEP] apart, going round once.
var _ring := PackedVector2Array()
var _time := 0.0


func _ready() -> void:
	set_process(false)


## Traces the outer edge of [param label] as it is drawn now, then starts crawling. Awaited: the
## label is drawn once apart, which takes a frame.
func follow(label: Label) -> void:
	var view := SubViewport.new()
	view.transparent_bg = true
	view.size = Vector2i(label.size)
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var copy: Label = label.duplicate()
	copy.set_anchors_preset(Control.PRESET_TOP_LEFT)
	copy.position = Vector2.ZERO
	copy.size = label.size
	view.add_child(copy)
	add_child(view)
	await RenderingServer.frame_post_draw
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(view.get_texture().get_image())
	view.queue_free()
	var outlines := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, bitmap.get_size()), 1.0)
	if outlines.is_empty():
		return
	var outer := outlines[0]
	for outline in outlines:
		if _area(outline) > _area(outer):
			outer = outline
	_ring = _evenly_spaced(outer, _STEP)
	position = label.position
	set_process(true)


func _process(delta: float) -> void:
	_time += delta
	var count := _ring.size()
	var head := fposmod(_time / turn_s, 1.0) * count
	var tail := head + length_part * count
	var span := PackedVector2Array([_on_ring(head)])
	for i in range(ceili(head), floori(tail) + 1):
		span.append(_ring[i % count])
	span.append(_on_ring(tail))
	points = span
	default_color = Color.from_hsv(fposmod(_time / colour_s, 1.0), 0.7, 0.95)


## The point of the ring at [param place], counted in ring points, between two of them.
func _on_ring(place: float) -> Vector2:
	var i := floori(place)
	return _ring[i % _ring.size()].lerp(_ring[(i + 1) % _ring.size()], place - i)


## Points along the closed [param polygon], [param step] apart.
static func _evenly_spaced(polygon: PackedVector2Array, step: float) -> PackedVector2Array:
	var spaced := PackedVector2Array([polygon[0]])
	var left := step
	for i in polygon.size():
		var from := polygon[i]
		var to := polygon[(i + 1) % polygon.size()]
		var side := from.distance_to(to)
		var walked := 0.0
		while side - walked >= left:
			walked += left
			spaced.append(from.lerp(to, walked / side))
			left = step
		left -= side - walked
	return spaced


static func _area(polygon: PackedVector2Array) -> float:
	var twice := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		twice += a.x * b.y - b.x * a.y
	return absf(twice) / 2.0
