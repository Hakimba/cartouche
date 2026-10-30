# SPDX-License-Identifier: GPL-3.0-or-later
class_name RingFit
extends RefCounted
## The ordering ring's size rule: the consoles stand at even angles on an ellipse, each at its real size
## against the others, all on one scale, the largest at which no two silhouette boxes touch. A console's
## width on the screen is its [method width] in units of [constant FormPaint.CQW] px (CQW units below);
## its box is a fraction of its 4:3 picture, which the picture spans whole. Pure.

## The ring's centre and radii, in px of the 1280 × 960 frame.
const CENTRE := Vector2(640.0, 471.04)
const RADII := Vector2(390.4, 325.12)
## How much bigger the bottom of the ring stands than the top, how much the pointed console grows (the fit
## assumes every console has), and the room kept between two boxes (CQW units).
const NEAR := 0.045
const GROWTH := 1.06
const ROOM := 1.2
## The PS2's box is the yardstick: at most this wide (CQW units), whether or not the library has one. [member PS2_BOX] is
## its silhouette, a fraction of its picture.
const WIDEST := 12.5
const PS2_BOX := Rect2(0.256, 0.298, 0.552, 0.376)
## How fast everything on the ring follows its target, per second.
const _FOLLOW := 14.0
const _BISECTIONS := 26
const _ATELIER_Z := 3.7

## Each console's weight, by folder, read once from its manifest.
static var _weights: Dictionary[String, float] = {}


## How big console [param folder] stands against the PS2: its real size, undoing the depth its pose pushed
## it to ([member ConsoleManifest.ring_size]). 1 for a console not measured.
static func weight_of(folder: String) -> float:
	if folder not in _weights:
		var stood := _stood(folder)
		_weights[folder] = stood / _stood("ps2_slim") if stood != 0.0 else 1.0
	return _weights[folder]


## The part of the way to its target everything on the ring covers in [param delta] seconds.
static func share(delta: float) -> float:
	return 1.0 - exp(-_FOLLOW * minf(delta, Motion.MAX_STEP_S))


## [param value] [param part] of the way to [param target], and there once within a ten-thousandth of it.
static func toward(value: float, target: float, part: float) -> float:
	return target if absf(target - value) < 1e-4 else lerpf(value, target, part)


## The same for an angle in radians, the shorter way round.
static func turn_toward(angle: float, target: float, part: float) -> float:
	var gap := wrapf(target - angle, -PI, PI)
	return target if absf(gap) < 1e-4 else angle + gap * part


## The ring's place at [param angle] (radians), in px of the 1280 × 960 frame: 0 is the bottom, and the angle
## grows counter-clockwise on the screen.
static func place(angle: float) -> Vector2:
	return CENTRE + Vector2(RADII.x * sin(angle), RADII.y * cos(angle))


## The width in CQW units of a console's picture of [param weight] on the scale [param size] at [param angle].
static func width(weight: float, size: float, angle: float) -> float:
	return size * weight * (1.0 + NEAR * cos(angle))


## The distance in px from a console's place to the edge of its box along the ring's radial, the box as large
## as the console pointed at stands.
static func ext(box: Rect2, weight: float, size: float, angle: float) -> float:
	var across := width(weight, size, angle) * GROWTH
	var radial := Vector2(RADII.x * sin(angle), RADII.y * cos(angle)).normalized()
	var reach := minf(across * box.size.x / 2.0 / maxf(absf(radial.x), 1e-9),
		across * 0.75 * box.size.y / 2.0 / maxf(absf(radial.y), 1e-9))
	return reach * FormPaint.CQW


## The largest scale in CQW units, at most [param cap], at which no two of the consoles' boxes touch: console i has the
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
## consoles are apart when it is at least [constant ROOM] CQW units.
static func least_room(boxes: Array[Rect2], weights: PackedFloat64Array, angles: PackedFloat64Array, size: float) -> float:
	var count := boxes.size()
	var places := PackedVector2Array()
	var sizes := PackedVector2Array()
	for i in count:
		var across := width(weights[i], size, angles[i])
		places.append(place(angles[i]) / FormPaint.CQW)
		sizes.append(Vector2(boxes[i].size.x, 0.75 * boxes[i].size.y) * across)
	var least := INF
	for i in count:
		for j in range(i + 1, count):
			var gap := (places[i] - places[j]).abs() - (sizes[i] + sizes[j]) / 2.0 * GROWTH
			least = minf(least, maxf(gap.x, gap.y))
	return least * FormPaint.CQW


static func _apart(boxes: Array[Rect2], weights: PackedFloat64Array, angles: PackedFloat64Array, size: float) -> bool:
	return least_room(boxes, weights, angles, size) >= ROOM * FormPaint.CQW


static func _stood(folder: String) -> float:
	var manifest := ConsoleManifest.of(folder)
	var size := manifest.ring_size if manifest else Vector2.ZERO
	return size.x * (_ATELIER_Z - size.y)
