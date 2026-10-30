# SPDX-License-Identifier: GPL-3.0-or-later
class_name Ps2SlimGeometry
extends RefCounted
## Builds the PS2 slim from its [Ps2SlimShape] as pure functions, so that tests check the geometry
## headless. Each part is laid out in plan, X to the right and Y towards the back, swept up along Z
## with [ShapeGeometry] blocks, then turned into the model's space: top up (+Y), front towards +Z.
## The slabs, and the grooves' backs between them, have the lid's opening through them, down to the
## well's floor; the lid is given around its hinge, which the model turns it about, its ribs with it.
## The drive's tray fills the well under the disc, laid out from the seat (see [method _tray]). The details on
## the front and the back are boxes on their faces, laid out in the model's space (see
## [constant DETAILS]). Each logo is a face of its own (see [method ShapeGeometry.decal]): those on
## the top laid out from the shape, the lid's around its hinge, those on the front as the details.

const PARTS: Array[StringName] = [&"slabs", &"dark", &"lid", &"lid_ribs", &"well", &"sled", &"lens", &"flex",
	&"label_plate", &"details", &"keys", &"tongues", &"receiver", &"badge_plate", &"power_ring", &"strip_logo", &"sony",
	&"disc_marks", &"badge", &"open_key", &"reset_key", &"port_marks", &"usb_mark", &"laser_label"]
## The details on the body's faces, by part, in groups on one face: `front` and `back`, the slabs';
## `base_front` and `base_back`, the base's, set back under the lid's side. Each group sinks into
## its face and stands out of it as far as its Vector2 says; each of its boxes is its centre's X
## from the body's left side (from its right one when negative), its centre's Y from the bottom
## (from the top when negative), its width and its height.
const DETAILS: Dictionary[StringName, Array] = {
	&"details": [
		# The controllers' ports and the memory cards' slots; the gaps round the open and reset keys.
		[&"front", Vector2(-0.5, 0.5), [Vector4(28.0, 5.4, 40.0, 8.5), Vector4(76.5, 5.4, 40.0, 8.5),
			Vector4(28.0, -6.9, 36.0, 2.0), Vector4(76.5, -6.9, 36.0, 2.0)]],
		[&"front", Vector2(-0.7, 0.1), [Vector4(112.2, -6.9, 22.0, 3.2), Vector4(-16.2, -6.9, 23.0, 3.2)]],
		# The USB ports and the vents in three columns.
		[&"base_front", Vector2(-0.5, 0.5), [Vector4(114.0, 5.0, 12.5, 5.0), Vector4(-90.5, 5.0, 12.5, 5.0),
			Vector4(-68.0, 2.5, 12.0, 1.3), Vector4(-68.0, 5.0, 12.0, 1.3), Vector4(-68.0, 7.5, 12.0, 1.3),
			Vector4(-54.0, 2.5, 12.0, 1.3), Vector4(-54.0, 5.0, 12.0, 1.3), Vector4(-54.0, 7.5, 12.0, 1.3),
			Vector4(-40.0, 2.5, 12.0, 1.3), Vector4(-40.0, 5.0, 12.0, 1.3), Vector4(-40.0, 7.5, 12.0, 1.3)]],
		# The network, optical and AV connectors, the vents along the slabs; the power inlet, deeper.
		[&"back", Vector2(-0.5, 0.5), [Vector4(85.0, 7.5, 14.0, 12.0), Vector4(63.0, 6.5, 9.0, 8.0),
			Vector4(39.0, 6.0, 24.0, 6.5), Vector4(73.0, -11.5, 8.0, 2.2), Vector4(60.0, -11.5, 8.0, 2.2),
			Vector4(47.0, -11.5, 8.0, 2.2), Vector4(34.0, -11.5, 8.0, 2.2), Vector4(21.0, -11.5, 8.0, 2.2),
			Vector4(8.0, -11.5, 8.0, 2.2)]],
		[&"back", Vector2(-0.3, 0.7), [Vector4(16.0, 6.0, 4.0, 4.0)]],
		[&"base_back", Vector2(-0.5, 0.5), [Vector4(-80.0, 4.5, 15.0, 1.6), Vector4(-63.0, 4.5, 15.0, 1.6),
			Vector4(-45.0, 4.5, 15.0, 1.6), Vector4(-26.0, 4.5, 15.0, 1.6)]],
	],
	# The open and reset keys; the ports' pins.
	&"keys": [
		[&"front", Vector2(-0.3, 0.3), [Vector4(112.2, -6.9, 21.0, 2.6), Vector4(-16.2, -6.9, 22.0, 2.6)]],
		[&"front", Vector2(-0.4, 0.6), [Vector4(28.0, 5.4, 33.0, 2.6), Vector4(76.5, 5.4, 33.0, 2.6)]],
	],
	&"tongues": [[&"base_front", Vector2(-0.4, 0.6), [Vector4(114.0, 5.6, 11.0, 1.6),
		Vector4(-90.5, 5.6, 11.0, 1.6)]]],
	# The remote's receiver.
	&"receiver": [[&"base_front", Vector2(-0.5, 0.5), [Vector4(-24.5, 5.0, 7.0, 7.0)]]],
	&"badge_plate": [[&"front", Vector2(0.0, 1.0), [Vector4(-68.5, -6.9, 8.6, 6.0)]]],
	# Round the power inlet.
	&"power_ring": [[&"back", Vector2(-0.5, 0.5), [Vector4(16.0, 6.0, 8.0, 8.0)]]],
}
## Where the logos on the front lie: their face, their centre as a box of [constant DETAILS], how
## far out of the face they lie (on the badge's plate, on a key).
const ON_FRONT: Dictionary[StringName, Array] = {
	&"badge": [&"front", Vector3(-68.5, -6.9, 1.0)], &"open_key": [&"front", Vector3(112.2, -6.9, 0.3)],
	&"reset_key": [&"front", Vector3(-16.2, -6.9, 0.3)], &"port_marks": [&"front", Vector3(50.5, 11.9, 0.0)],
	&"usb_mark": [&"base_front", Vector3(-103.25, 5.0, 0.0)],
}
## Each logo's size in millimetres, its image's (`ps2_slim_<part>.svg`).
const LOGOS: Dictionary[StringName, Vector2] = {
	&"strip_logo": Vector2(33.0, 12.0), &"sony": Vector2(23.8, 4.6), &"disc_marks": Vector2(67.5, 7.6),
	&"badge": Vector2(8.6, 6.0), &"open_key": Vector2(21.0, 2.6), &"reset_key": Vector2(22.0, 2.6),
	&"port_marks": Vector2(55.0, 2.4), &"usb_mark": Vector2(3.8, 6.6), &"laser_label": Vector2(42.0, 10.0),
}
## The plan size the top's grain repeats over: a grain finer than the UV square's.
const _GRAIN_MM := 40.0
## Half a DVD's thickness: what lies under a seated disc stays below its underside.
const _DISC_HALF_THICKNESS := 0.6
## Where the logos on the top lie: the strip's logo from this far short of the strip's back end; the
## maker's name from the body's back left corner (right, then towards the front); the disc marks from
## the lid's front right corner (left, then back), along its front.
const _STRIP_LOGO_FROM_BACK := 1.95
const _SONY_FROM_CORNER := Vector2(5.8, 8.6)
const _DISC_MARKS_FROM_CORNER := Vector2(2.5, 1.0)
## The drive (see [method _tray]). Its tray's deck stays this far under a disc at most, and leaves it
## this much room in its recess; the ledge round the opening, under the lid's edge, is this wide at most.
## The spindle's hole, the laser's slot (as wide), and the bridge over the slot's far end (its length, from the back), in millimetres.
const _UNDER_DISC := 2.0
const _RECESS_ROOM := 1.5
const _LEDGE := 2.0
const _HOLE_RADIUS := 15.0
const _SLOT_WIDTH := 23.0
const _BRIDGE_LENGTH := 13.0
## As shares of the recess's radius: the finger pockets' centres from the seat (X either way, then
## towards the front) and their radius; the label plate's centre in front of the seat and its size.
const _POCKET := Vector3(0.65, 0.62, 0.26)
const _PLATE := Vector3(0.73, 0.7, 0.195)
## The laser's sled in the slot, from this far behind the seat, this long; its lens, its centre from
## the seat and its radius; the rails it runs on, their radius; the flat cable from its back, across
## from the seat, in millimetres.
const _SLED := Vector2(14.0, 17.0)
const _LENS := Vector3(-1.0, 22.0, 2.2)
const _RAIL_RADIUS := 1.4
const _FLEX := Vector2(-7.5, 2.5)
## The lid's underside, its ribs moulded round the pressure pad that holds the disc on the spindle:
## concentric rings, spokes, and bars out to a frame round its edge; the pattern's radius as a share
## of the lid's half width; how far in the frame lies; the ribs' width, and their height at most.
const _RINGS := 4
const _SPOKES := 24
const _PRESS_SHARE := 0.73
const _FRAME_INSET := 3.0
const _RIB := Vector2(0.9, 1.2)
## From a side's plane (X across, Y up, Z towards the back) to the plan: the rails lie along Y.
const _ALONG := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP)


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: Ps2SlimShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var body := shape.body()
	var grain := Rect2(body.position, Vector2.ONE * _GRAIN_MM)
	var at := Transform3D(ShapeGeometry.PLAN, Vector3.ZERO)
	# As many points around the opening as around each slab, so that they join point to point.
	var opening := ShapeGeometry.rounded_box(shape.opening(), shape.lid_corner + shape.lid_gap, steps)
	match part:
		&"dark":
			ShapeGeometry.prism(mesh, _base(shape), 0.0, shape.seam, body)
			for groove in shape.grooves():
				ShapeGeometry.block(mesh, shape.groove_box(), Vector2.ONE * shape.groove_corner(), steps, groove.x,
					groove.y, shape.groove_bevel(), body, NAN, true, opening)
			var strip_corner := shape.strip_corner()
			ShapeGeometry.block(mesh, shape.strip(), Vector2.ONE * strip_corner, steps, shape.height,
				shape.height + shape.strip_raise, minf(shape.strip_raise * 0.3, strip_corner / 2.0), shape.strip())
		&"slabs":
			var low := shape.seam
			for groove in shape.grooves():
				_slab(mesh, shape, low, groove.x, steps, opening, grain)
				low = groove.y
			_slab(mesh, shape, low, shape.height, steps, opening, grain)
		&"lid":
			# Rounded less than its corners, so that each outline along the bevel keeps its shape.
			var edge := minf(minf(shape.bevel, shape.lid_thickness / 3.0), shape.lid_corner / 2.0)
			ShapeGeometry.block(mesh, shape.lid_box(), Vector2.ONE * shape.lid_corner, steps,
				shape.height - shape.lid_thickness, shape.height, edge, Rect2(shape.lid_box().position, grain.size))
			at.origin = -shape.hinge()
		&"lid_ribs":
			_lid_ribs(mesh, shape, steps, Rect2(shape.lid_box().position, grain.size))
			at.origin = -shape.hinge()
		&"well":
			# Its top just above the base's, which it hides; closed below, where the base is set back.
			ShapeGeometry.prism(mesh, opening, shape.seam / 2.0, shape.seam + 0.05, shape.opening())
			_tray(mesh, shape, steps, opening)
		&"sled", &"lens", &"flex":
			_laser(mesh, shape, part)
		&"label_plate", &"laser_label":
			var radius := _recess_radius(shape)
			var plate := ShapeGeometry.centred(shape.lid_centre - Vector2(0.0, _PLATE.x * radius),
				Vector2(_PLATE.y, _PLATE.z) * radius)
			var top := _levels(shape).y + 0.4
			if part == &"label_plate":
				ShapeGeometry.prism(mesh, ShapeGeometry.square(plate), top - 0.5, top)
			else:
				ShapeGeometry.decal(mesh, ShapeGeometry.centred(plate.get_center(),
					LOGOS[part] * minf(1.0, (plate.size.x - 1.0) / LOGOS[part].x)), top)
		&"strip_logo":
			# Read from the left end, its top towards the lid, from near the strip's back end; no wider
			# than the strip, so as never to lie over the lid.
			var size := LOGOS[part] * clampf((shape.strip_width - 1.0) / LOGOS[part].y, 0.01, 1.0)
			ShapeGeometry.decal(mesh, Rect2(0.0, -size.y / 2.0, size.x, size.y), shape.height + shape.strip_raise)
			at *= Transform3D(Basis(Vector3.DOWN, Vector3.RIGHT, Vector3.BACK),
				Vector3(shape.strip_x, shape.strip().end.y - _STRIP_LOGO_FROM_BACK, 0.0) * MeshBuilder.UNITS_PER_MM)
		&"sony":
			var corner := Vector2(body.position.x + _SONY_FROM_CORNER.x, body.end.y - _SONY_FROM_CORNER.y)
			ShapeGeometry.decal(mesh, Rect2(corner, LOGOS[part]), shape.height)
		&"disc_marks":
			# Along the lid's front, from near its right end: smaller on a lid too narrow for them.
			var lid := shape.lid_box()
			var size := LOGOS[part] * minf(1.0, (lid.size.x - 2.0 * _DISC_MARKS_FROM_CORNER.x) / LOGOS[part].x)
			var corner := Vector2(lid.end.x - _DISC_MARKS_FROM_CORNER.x - size.x,
				lid.position.y + _DISC_MARKS_FROM_CORNER.y)
			ShapeGeometry.decal(mesh, Rect2(corner, size), shape.height)
			at.origin = -shape.hinge()
		&"details", &"keys", &"tongues", &"receiver", &"badge_plate", &"power_ring":
			for group: Array in DETAILS[part]:
				var on: StringName = group[0]
				var depths: Vector2 = group[1]
				var boxes: Array = group[2]
				ShapeGeometry.boxes_on(mesh, boxes.map(func(box: Vector4) -> Vector4:
					var centre := _centre(shape, Vector2(box.x, box.y))
					return Vector4(centre.x, centre.y, box.z, box.w)), _face(shape, on), depths)
			at = Transform3D.IDENTITY
		_:
			var on: StringName = ON_FRONT[part][0]
			var place: Vector3 = ON_FRONT[part][1]
			var centre := _centre(shape, Vector2(place.x, place.y))
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(centre, LOGOS[part]), _face(shape, on) + place.z)
			at = Transform3D.IDENTITY
	return ShapeGeometry.moved(mesh.arrays(), at)


## The Z of [param face] in the model's space (see [constant DETAILS]).
static func _face(shape: Ps2SlimShape, face: StringName) -> float:
	match face:
		&"front":
			return shape.depth / 2.0
		&"base_front":
			return shape.depth / 2.0 - shape.base_inset.x
		&"back":
			return -shape.depth / 2.0
	return shape.base_inset.z - shape.depth / 2.0


## Where a detail placed at [param at] is centred on its face, X across the body and Y up (see
## [constant DETAILS]).
static func _centre(shape: Ps2SlimShape, at: Vector2) -> Vector2:
	var body := shape.body()
	return Vector2(at.x + (body.position.x if at.x >= 0.0 else body.end.x),
		at.y if at.y >= 0.0 else shape.height + at.y)


## The base's outline, counter-clockwise: the body's on the side away from the lid, set back by
## [member Ps2SlimShape.base_inset] on the lid's side (see [method Ps2SlimShape.base_box]).
static func _base(shape: Ps2SlimShape) -> PackedVector2Array:
	var body := shape.body()
	var set_back := shape.base_box()
	var x := set_back.position.x
	return PackedVector2Array([body.position, Vector2(x, body.position.y), set_back.position,
		Vector2(set_back.end.x, set_back.position.y), set_back.end, Vector2(x, set_back.end.y),
		Vector2(x, body.end.y), Vector2(body.position.x, body.end.y)])


## A slab of the body from [param low] to [param high], the [param opening] through it.
static func _slab(mesh: MeshBuilder, shape: Ps2SlimShape, low: float, high: float, steps: int,
		opening: PackedVector2Array, grain: Rect2) -> void:
	ShapeGeometry.block(mesh, shape.body(), Vector2.ONE * shape.corner, steps, low, high, shape.bevel, grain,
		NAN, true, opening)


## The drive's levels in the well, from the floor up, shared out between it and a seated disc's
## underside: the finger pockets' floor, the recess's, the top of the laser's sled, and the deck.
static func _levels(shape: Ps2SlimShape) -> Vector4:
	var deck := shape.seat_height - minf(_UNDER_DISC, (shape.seat_height - shape.seam) / 2.0)
	return Vector4(lerpf(shape.seam, deck, 0.3), lerpf(shape.seam, deck, 0.55), lerpf(shape.seam, deck, 0.775), deck)


## How wide the ledge round the opening is: narrower where a disc has less room, none without.
static func _ledge(shape: Ps2SlimShape) -> float:
	var opening := shape.opening()
	return clampf(minf(opening.size.x, opening.size.y) / 2.0 - shape.disc_radius - 0.5, 0.0, _LEDGE)


## The disc's recess about the seat: the disc's room round it, inside the ledge.
static func _recess_radius(shape: Ps2SlimShape) -> float:
	var opening := shape.opening()
	return minf(shape.disc_radius + _RECESS_ROOM, minf(opening.size.x, opening.size.y) / 2.0 - _ledge(shape) - 0.3)


## The laser's slot, in plan: from the seat back past the opening's back edge.
static func _slot(shape: Ps2SlimShape) -> Rect2:
	var width := minf(_SLOT_WIDTH, 0.6 * _recess_radius(shape))
	var centre := shape.lid_centre
	return Rect2(centre.x - width / 2.0, centre.y, width, shape.opening().end.y + 1.0 - centre.y)


## The bridge over the slot's far end, in plan: from the opening's back edge, wider than the slot.
static func _bridge(shape: Ps2SlimShape) -> Rect2:
	var slot := _slot(shape)
	var back := shape.opening().end.y
	var length := minf(_BRIDGE_LENGTH, (back - shape.lid_centre.y - _HOLE_RADIUS) / 2.0)
	return Rect2(slot.position.x - 2.0, back - length, slot.size.x + 4.0, length)


## Adds the drive's moulded tray in the well's outline [param opening]: a deck round the disc's
## recess, two finger pockets at its front corners sunk below it, and the keyhole through both (the
## spindle's hole and the laser's slot, back under the bridge) down to the well's floor; a ledge
## round the opening, under the lid's edge. Each a solid of its own, overlapping the next.
static func _tray(mesh: MeshBuilder, shape: Ps2SlimShape, steps: int, opening: PackedVector2Array) -> void:
	var levels := _levels(shape)
	var count := 16 * steps
	var centre := shape.lid_centre
	var radius := _recess_radius(shape)
	var uv := shape.opening()
	# The pockets stay as far inside the opening as the recess: the deck keeps a rim all round.
	var rim := _ledge(shape) + 0.3
	var inside := ShapeGeometry.rounded_box(uv.grow(-rim), maxf(shape.lid_corner + shape.lid_gap - rim, 0.05), steps)
	var keyhole := Geometry2D.merge_polygons(ShapeGeometry.circle(centre, minf(_HOLE_RADIUS, radius / 2.0), count),
		ShapeGeometry.square(_slot(shape)))[0]
	# Cut straight across at the bridge's front: the deck runs along the back.
	var front := shape.opening().position.y - 1.0
	var recess: PackedVector2Array = Geometry2D.intersect_polygons(ShapeGeometry.circle(centre, radius, count),
		ShapeGeometry.square(Rect2(uv.position.x, front, uv.size.x, _bridge(shape).position.y - front)))[0]
	var sunk: PackedVector2Array = Geometry2D.merge_polygons(recess, keyhole)[0]
	var bottom: PackedVector2Array = Geometry2D.clip_polygons(recess, keyhole)[0]
	for side: float in [-1.0, 1.0]:
		var pocket := ShapeGeometry.circle(centre + Vector2(side * _POCKET.x, -_POCKET.y) * radius, _POCKET.z * radius,
			int(count / 2.0))
		pocket = Geometry2D.intersect_polygons(pocket, inside)[0]
		ShapeGeometry.prism(mesh, ShapeGeometry.ccw(pocket), shape.seam, levels.x, uv)
		sunk = Geometry2D.merge_polygons(sunk, pocket)[0]
		bottom = Geometry2D.clip_polygons(bottom, pocket)[0]
	for deck in Geometry2D.clip_polygons(opening, sunk):
		ShapeGeometry.prism(mesh, ShapeGeometry.ccw(deck), shape.seam, levels.w, uv)
	ShapeGeometry.prism(mesh, ShapeGeometry.ccw(bottom), shape.seam, levels.y, uv)
	ShapeGeometry.prism(mesh, ShapeGeometry.square(_bridge(shape)), shape.seam,
		(levels.w + shape.seat_height - _DISC_HALF_THICKNESS) / 2.0, uv)
	var ledge := _ledge(shape)
	if ledge > 0.2:
		var inner := ShapeGeometry.rounded_box(shape.opening().grow(-ledge),
			maxf(shape.lid_corner + shape.lid_gap - ledge, 0.05), steps)
		_ring(mesh, opening, inner, shape.seam, shape.height - shape.lid_thickness - 0.1, uv)


## Adds the laser's [param part] in its slot: the sled on its rails, its lens, its flat cable back
## under the bridge.
static func _laser(mesh: MeshBuilder, shape: Ps2SlimShape, part: StringName) -> void:
	var levels := _levels(shape)
	var slot := _slot(shape)
	var centre := shape.lid_centre
	var bridge := _bridge(shape).position.y
	var sled := Rect2(slot.position.x + 0.5, centre.y + _SLED.x, slot.size.x - 1.0,
		minf(_SLED.y, bridge - 2.0 - centre.y - _SLED.x))
	match part:
		&"sled":
			ShapeGeometry.prism(mesh, ShapeGeometry.square(sled), shape.seam, levels.z, sled)
			var radius := minf(_RAIL_RADIUS, (levels.y - shape.seam) / 3.0)
			var height := lerpf(shape.seam, levels.y, 0.6)
			mesh.basis = _ALONG
			for x: float in [slot.position.x + radius + 0.3, slot.end.x - radius - 0.3]:
				ShapeGeometry.prism(mesh, ShapeGeometry.circle(Vector2(x, height), radius, 12),
					centre.y + _SLED.x * 0.6, bridge + 1.0)
		&"lens":
			var lens := ShapeGeometry.circle(centre + Vector2(_LENS.x, minf(_LENS.y, sled.get_center().y)), _LENS.z, 16)
			ShapeGeometry.prism(mesh, lens, levels.z - 0.2,
				levels.z + minf(1.0, (shape.seat_height - _DISC_HALF_THICKNESS - levels.z) / 2.0))
		&"flex":
			var share := slot.size.x / _SLOT_WIDTH
			var cable := Rect2(centre.x + _FLEX.x * share, sled.end.y - 2.0, (_FLEX.y - _FLEX.x) * share,
				bridge + 3.0 - sled.end.y)
			ShapeGeometry.prism(mesh, ShapeGeometry.square(cable), levels.z - 0.5, levels.z - 0.2, cable)


## Adds the ribs under the lid, moulded down from its underside as far as a closed lid leaves room
## above a seated disc: a frame round its edge, rings and spokes round the pressure pad in its
## middle, and bars from the rings out to the frame's sides and corners.
static func _lid_ribs(mesh: MeshBuilder, shape: Ps2SlimShape, steps: int, uv: Rect2) -> void:
	var underside := shape.height - shape.lid_thickness
	var low := underside - clampf(underside - shape.seat_height - _DISC_HALF_THICKNESS - 0.4, 0.05, _RIB.y)
	var high := underside + minf(0.3, shape.lid_thickness / 2.0)
	var lid := shape.lid_box()
	var centre := lid.get_center()
	var outer := lid.grow(-_FRAME_INSET)
	var inner := outer.grow(-_RIB.x)
	var corner := maxf(shape.lid_corner - _FRAME_INSET, _RIB.x + 0.05)
	var rounding := corner - _RIB.x
	_ring(mesh, ShapeGeometry.rounded_box(outer, corner, steps), ShapeGeometry.rounded_box(inner, rounding, steps), low,
		high, uv)
	var reach := _PRESS_SHARE * minf(lid.size.x, lid.size.y) / 2.0
	var count := 16 * steps
	for k in _RINGS:
		var radius := reach * (k + 1) / _RINGS
		_ring(mesh, ShapeGeometry.circle(centre, radius, count), ShapeGeometry.circle(centre, radius - _RIB.x, count),
			low, high, uv)
	ShapeGeometry.prism(mesh, ShapeGeometry.circle(centre, reach / _RINGS * 0.7, count), low, high, uv)
	for k in _SPOKES:
		var towards := Vector2.from_angle(TAU * k / _SPOKES)
		_bar(mesh, centre + towards * reach / _RINGS, centre + towards * reach, low, high, uv)
	for x: float in [-1.0, 1.0]:
		_bar(mesh, centre + Vector2(x * reach, 0.0), centre + Vector2(x * (inner.size.x / 2.0 + 0.3), 0.0), low, high,
			uv)
		_bar(mesh, centre + Vector2(0.0, x * reach), centre + Vector2(0.0, x * (inner.size.y / 2.0 + 0.3)), low, high,
			uv)
		for y: float in [-1.0, 1.0]:
			# To the centre of the frame's rounded corner: inside it however round.
			var to := centre + Vector2(x, y) * (inner.size / 2.0 - Vector2.ONE * rounding)
			if to.distance_to(centre) > reach + 1.0:
				_bar(mesh, centre + (to - centre).normalized() * reach, to, low, high, uv)


## Adds the solid between the outlines [param outer] and [param inner] (as many points each,
## counter-clockwise), from [param low] to [param high].
static func _ring(mesh: MeshBuilder, outer: PackedVector2Array, inner: PackedVector2Array, low: float, high: float,
		uv: Rect2) -> void:
	ShapeGeometry.band(mesh, outer, inner, high, Vector3.BACK, uv)
	ShapeGeometry.band(mesh, outer, inner, low, Vector3.FORWARD, uv)
	ShapeGeometry.wall(mesh, outer, low, high, uv)
	ShapeGeometry.sunk(mesh, inner, low, high, uv, false)


## Adds a rib as wide as [constant _RIB] from [param from] to [param to], from [param low] to
## [param high].
static func _bar(mesh: MeshBuilder, from: Vector2, to: Vector2, low: float, high: float, uv: Rect2) -> void:
	var side := (to - from).orthogonal().normalized() * _RIB.x / 2.0
	ShapeGeometry.prism(mesh, ShapeGeometry.ccw(PackedVector2Array([from - side, to - side, to + side, from + side])), low, high, uv)
