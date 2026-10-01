# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiscoveryBadge
extends Control
## The sticker a console just added shows on: a rounded burst of nine lobes, white inside going
## pale blue, a golden rim, a golden halo and rays behind. Its picture is a child, drawn over it.

const RIM := Color(0.949, 0.706, 0.0)
const LOBES := 9
const RAYS := 14
## How far the rays reach, as a part of the badge's larger side.
const RAY_REACH := 0.78

## How far the rays have come in, from 0 (none) to 1.
var rays_shown := 1.0:
	set(value):
		rays_shown = value
		queue_redraw()

## The burst's outlines at the badge's size, worked out once: glow layers, rim, inside.
var _glows: Array[PackedVector2Array] = []
var _outline := PackedVector2Array()
var _inner := PackedVector2Array()


func _ready() -> void:
	resized.connect(_shape)
	_shape()


func _draw() -> void:
	var centre := size / 2.0
	_draw_rays(centre)
	var glow := RIM
	glow.a = 0.1
	for layer in _glows:
		draw_colored_polygon(layer, glow)
	draw_colored_polygon(_outline, Color.WHITE)
	_draw_closed(_outline, RIM, 10.0)
	var edge := Color(0.86, 0.9, 0.98)
	for i in _inner.size():
		draw_polygon([centre, _inner[i], _inner[(i + 1) % _inner.size()]], [Color.WHITE, edge, edge])
	var faint := RIM
	faint.a = 0.35
	_draw_closed(_inner, faint, 3.0)


func _shape() -> void:
	_glows.clear()
	for layer in 4:
		_glows.append(burst(size, 1.02 + layer * 0.035))
	_outline = burst(size, 1.0)
	_inner = burst(size, 0.86)


func _draw_rays(centre: Vector2) -> void:
	var reach := maxf(size.x, size.y) * RAY_REACH * lerpf(0.6, 1.0, rays_shown)
	var turn := deg_to_rad(-12.0) * (1.0 - rays_shown)
	var near := RIM
	near.a = 0.5 * rays_shown
	var far := RIM
	far.a = 0.0
	for i in RAYS:
		var a := turn + i * TAU / RAYS
		draw_polygon([centre, centre + Vector2.from_angle(a) * reach, centre + Vector2.from_angle(a + 0.09) * reach],
			[near, far, far])


func _draw_closed(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


## The burst filling [param area], [param growth] times its size from its centre: lobes and
## hollows alternate, a little uneven, joined by smooth curves through them.
static func burst(area: Vector2, growth: float) -> PackedVector2Array:
	var corners := PackedVector2Array()
	for i in LOBES * 2:
		var a := -PI / 2.0 + i * PI / LOBES
		var reach := (1.0 if i % 2 == 0 else 0.8) * growth * (1.0 + 0.035 * sin(i * 2.3))
		corners.append(area / 2.0 + Vector2(cos(a) * area.x, sin(a) * area.y) / 2.0 * reach)
	var curve := Curve2D.new()
	# Round once more, back to the first corner, which closes the curve.
	for i in corners.size() + 1:
		var tangent := (corners[(i + 1) % corners.size()] - corners[i - 1]) / 6.0
		curve.add_point(corners[i % corners.size()], -tangent, tangent)
	var points := curve.tessellate(4, 3.0)
	points.remove_at(points.size() - 1)
	return points
