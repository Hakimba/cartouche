# SPDX-License-Identifier: GPL-3.0-or-later
class_name RingFit
extends RefCounted
## The ordering ring's size rule: the consoles stand at even angles on an ellipse, each at its real size
## against the others, all on one scale, the largest at which no two silhouette boxes touch. A console's
## width on the screen is its [method width] in cqw (1 cqw is [constant CQW] px of the 1280 × 960 frame);
## its box is a fraction of its 4:3 picture, which the picture spans whole. Pure.

## The ring's centre and radii, in px of the 1280 × 960 frame.
const CENTRE := Vector2(640.0, 471.04)
const RADII := Vector2(390.4, 325.12)
const CQW := 12.8
## How much bigger the bottom of the ring stands than the top, how much the pointed console grows (the fit
## assumes every console has), and the room kept between two boxes (cqw).
const NEAR := 0.045
const GROWTH := 1.06
const ROOM := 1.2
## The PS2's box is the yardstick: at most this wide (cqw), whether or not the library has one. [member PS2_BOX] is
## its silhouette, a fraction of its picture.
const WIDEST := 12.5
const PS2_BOX := Rect2(0.256, 0.298, 0.552, 0.376)
## How fast everything on the ring follows its target, per second.
const FOLLOW := 14.0
## The lowest edge of each console's silhouette in the design's picture, a fraction of its height: where its contact
## shadow starts.
const FLOORS: Dictionary[String, float] = {
	"ps2_slim": 0.674, "psx": 0.802, "nes": 0.698, "snes": 0.729, "n64": 0.744, "gc": 0.775, "wii": 0.779,
	"xbox": 0.760, "xbox360": 0.806, "gb": 0.760, "gbc": 0.725, "gba": 0.702,
}
const _BISECTIONS := 26
## Each console's real size over its fitted pose, and the depth its pose pushed it back to.
const _SIZES: Dictionary[String, Vector2] = {
	"ps2_slim": Vector2(1.533, -0.367), "psx": Vector2(1.816, 0.044), "nes": Vector2(1.70, -0.299),
	"snes": Vector2(1.334, -0.955), "n64": Vector2(1.733, 0.044), "gc": Vector2(1.134, -2.579),
	"wii": Vector2(2.194, 0.068), "xbox": Vector2(2.155, -0.272), "xbox360": Vector2(2.176, -1.064),
	"gb": Vector2(1.485, 0.004), "gbc": Vector2(1.336, -0.138), "gba": Vector2(0.964, 0.041),
}
const _ATELIER_Z := 3.7


## How big console [param folder] stands against the PS2: its real size, undoing the depth its pose pushed
## it to. 1 for a console the table does not know.
static func weight_of(folder: String) -> float:
	return _stood(folder) / _stood("ps2_slim") if _SIZES.has(folder) else 1.0


## The ring's place at [param angle] (radians), in px of the 1280 × 960 frame: 0 is the bottom, and the angle
## grows counter-clockwise on the screen.
static func place(angle: float) -> Vector2:
	return CENTRE + Vector2(RADII.x * sin(angle), RADII.y * cos(angle))


## The width in cqw of a console's picture of [param weight] on the scale [param size] at [param angle].
static func width(weight: float, size: float, angle: float) -> float:
	return size * weight * (1.0 + NEAR * cos(angle))


## The distance in px from a console's place to the edge of its box along the ring's radial, the box as large
## as the console pointed at stands.
static func ext(box: Rect2, weight: float, size: float, angle: float) -> float:
	var across := width(weight, size, angle) * GROWTH
	var radial := Vector2(RADII.x * sin(angle), RADII.y * cos(angle)).normalized()
	var reach := minf(across * box.size.x / 2.0 / maxf(absf(radial.x), 1e-9),
		across * 0.75 * box.size.y / 2.0 / maxf(absf(radial.y), 1e-9))
	return reach * CQW


## The largest scale in cqw, at most [param cap], at which no two of the consoles' boxes touch: console i has the
## silhouette box [code]boxes[i][/code] (fractions of its picture), the [code]weights[i][/code] and the
## [code]angles[i][/code]. It returns [code]low[/code], the last scale that kept the room (0 when none does): never one
## that fails, whatever the 26 halvings left between it and the next.
static func scale(boxes: Array[Rect2], weights: PackedFloat64Array, angles: PackedFloat64Array, cap: float) -> float:
	if _apart(boxes, weights, angles, cap):
		return cap
	var low := 0.0
	var high := cap
	for _i in _BISECTIONS:
		var middle := (low + high) / 2.0
		if _apart(boxes, weights, angles, middle):
			low = middle
		else:
			high = middle
	return low


## The least room in px between two of the consoles' boxes on the scale [param size], each grown as the pointed one is:
## the larger of the gaps along the two axes, the least over every pair; infinite for fewer than two consoles. Two
## consoles are apart when it is at least [constant ROOM] cqw.
static func least_room(boxes: Array[Rect2], weights: PackedFloat64Array, angles: PackedFloat64Array, size: float) -> float:
	var count := boxes.size()
	var places := PackedVector2Array()
	var sizes := PackedVector2Array()
	for i in count:
		var across := width(weights[i], size, angles[i])
		places.append(place(angles[i]) / CQW)
		sizes.append(Vector2(boxes[i].size.x, 0.75 * boxes[i].size.y) * across)
	var least := INF
	for i in count:
		for j in range(i + 1, count):
			var gap := (places[i] - places[j]).abs() - (sizes[i] + sizes[j]) / 2.0 * GROWTH
			least = minf(least, maxf(gap.x, gap.y))
	return least * CQW


static func _apart(boxes: Array[Rect2], weights: PackedFloat64Array, angles: PackedFloat64Array, size: float) -> bool:
	return least_room(boxes, weights, angles, size) >= ROOM * CQW


static func _stood(folder: String) -> float:
	var size := _SIZES[folder]
	return size.x * (_ATELIER_Z - size.y)
