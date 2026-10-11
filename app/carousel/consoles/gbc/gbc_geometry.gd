# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbcGeometry
extends RefCounted
## Builds the Game Boy Color from its [GbcShape] as pure functions, so that tests check the geometry
## headless. Every part is laid out as the console is seen from the front, X to the right and Y up,
## and swept along Z towards the face, as the model has it: the front half's rings from its seam to
## its face, rolling back as the face does; rounded blocks for the back half, the bezel and the
## buttons; square prisms for the D-pad's cross, the wheel's teeth and the small parts on the edges.
## The back plate is its wall, rounded at the back, and a square-edged slab in front of it with the
## slot cut out of it. What lies in the back is laid out seen from behind (see
## [constant ShapeGeometry.BEHIND]), the holes sunk in it: the back plate with the sticker's and the
## lower screws', the pocket's sides with the upper ones', the bulge with the notch under the latch, the
## battery cover with its panel. The power knob is given at rest, as the model slides it. The marks are
## their images' faces ([method ShapeGeometry.decal]) on the face's flat part, the bezel, the buttons'
## tops, the sticker's recess or the cover's panel.

const PARTS: Array[StringName] = [&"shell", &"bezel", &"screen", &"led", &"dpad", &"buttons", &"pills",
	&"openings", &"ir_window", &"recesses", &"power_knob", &"wheel", &"screws", &"sticker", &"battery_cover",
	&"cover_gap", &"cover_mark", &"slot", &"contacts",
	&"logo", &"power_waves", &"power_label", &"comm_label", &"nintendo", &"select_label", &"start_label",
	&"a_label", &"b_label"]
## How deep the buttons go into the shell, below where the face rolls back.
const _SUNK := 1.5
const _WHEEL_TOOTH := 0.6
## The steps of each rounded edge of the front half, as [ShapeGeometry]'s blocks have; the rings
## from the face's edge in to the panel.
const _BEVEL_STEPS := 3
const _ROLL_STEPS := 6
## How far the openings lie in front of the face, so as to show on it.
const _LIFT := 0.03
## Swaps X and Y, so that [method ShapeGeometry.crossed] crosses outlines at a height.
const _SWAP := Transform2D(Vector2(0.0, 1.0), Vector2(1.0, 0.0), Vector2.ZERO)


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: GbcShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var outline := shape.outline()
	var front := shape.depth / 2.0
	var back := -front
	var on_bezel := front + GbcShape.BEZEL_RAISE
	# The back's frame, seen from behind: the bulge's face and the battery cover's.
	var on_bulge := front + shape.battery_rise
	var on_cover := on_bulge + GbcShape.COVER_RAISE
	if part in GbcShape.MARKS:
		var size := GbcShape.MARKS[part]
		var under := on_bezel if part in GbcShape.ON_BEZEL else front
		if part in GbcShape.ON_BUTTONS:
			under = front + GbcShape.BUTTON_RISE
		ShapeGeometry.decal(mesh, ShapeGeometry.centred(shape.mark(part), size), under)
	match part:
		&"shell":
			_front_half(mesh, shape, steps)
			var hidden := shape.bevel + 0.1
			# The back half reaches into the front one as far as its rounded edge, leaving a thin seam.
			var joint := shape.seam() + shape.bevel
			var wall := back + shape.back_wall()
			ShapeGeometry.slab(mesh, shape.slotted(steps), wall, joint, Vector2.ZERO, outline)
			for side: float in [-1.0, 1.0]:
				for rib in shape.ribs():
					var x := side * outline.end.x - (1.0 if side > 0.0 else GbcShape.RIB_PROUD)
					ShapeGeometry.prism(mesh,
						ShapeGeometry.square(Rect2(x, rib.position.x, 1.0 + GbcShape.RIB_PROUD,
						rib.size.x)), rib.position.y, rib.end.y)
			mesh.basis = ShapeGeometry.BEHIND
			var holes := shape.plate_holes(steps)
			var plate := ShapeGeometry.slab(mesh, shape.plate_behind(steps), -wall, front, Vector2(0.0, shape.bevel),
				outline, false)
			ShapeGeometry.holed(mesh, plate, holes, front, Vector3.BACK, outline, shape.plate_lines())
			for hole in holes:
				var sink := GbcShape.STICKER_SINK if hole == holes[0] else GbcShape.SCREW_SINK
				ShapeGeometry.sunk(mesh, hole, front - sink, front, outline)
			for side: float in [-1.0, 1.0]:
				var box := shape.pocket_side(side)
				var middle := box.get_center().x
				var screw := _round(ShapeGeometry.square_around(Vector2(middle, shape.screws()[0].y),
					GbcShape.SCREW_RADIUS), steps)
				var top := ShapeGeometry.block(mesh, box, Vector2(hidden, shape.top_corner), steps, -joint, front,
					shape.bevel, outline, middle, false)
				ShapeGeometry.holed(mesh, top, [screw], front, Vector3.BACK, outline, PackedFloat32Array([middle]))
				ShapeGeometry.sunk(mesh, screw, front - GbcShape.SCREW_SINK, front, outline)
			var bulge_corners := Vector2(shape.bottom_corner - GbcShape.BULGE_MARGIN, GbcShape.BULGE_TOP_CORNER)
			var notch := ShapeGeometry.rounded_box(shape.notch(), 0.5, steps, 0.0)
			var bulge := ShapeGeometry.block(mesh, shape.bulge(), bulge_corners, steps, front - 0.5, on_bulge,
				GbcShape.BULGE_BEVEL, outline, 0.0, false)
			ShapeGeometry.holed(mesh, bulge, [notch], on_bulge, Vector3.BACK, outline, PackedFloat32Array([0.0]))
			ShapeGeometry.sunk(mesh, notch, on_bulge - GbcShape.NOTCH.z, on_bulge, outline)
		&"bezel":
			ShapeGeometry.block(mesh, shape.bezel(), shape.bezel_corners, steps, front - 0.3, on_bezel, 0.3,
				shape.bezel())
		&"screen":
			ShapeGeometry.block(mesh, shape.screen(), Vector2.ONE * 0.5, steps, on_bezel - 0.2, on_bezel + 0.05, 0.1,
				shape.screen())
		&"led":
			_disc(mesh, shape.led, GbcShape.LED_RADIUS, on_bezel - 0.2, on_bezel + 0.3, 0.2, steps)
		&"dpad":
			ShapeGeometry.prism(mesh, _cross(shape.dpad, shape.dpad_size), front - shape.side_drop - _SUNK,
				front + GbcShape.DPAD_RISE)
		&"buttons":
			for centre: Vector2 in [shape.button_a, shape.button_b]:
				_disc(mesh, centre, shape.button_diameter / 2.0, front - shape.side_drop - _SUNK,
					front + GbcShape.BUTTON_RISE, 1.2, steps)
		&"pills":
			for centre: Vector2 in [shape.select(), shape.start]:
				var pill := shape.pill(centre)
				ShapeGeometry.block(mesh, pill, Vector2.ONE * pill.size.y / 2.0, steps, front - 1.0,
					front + GbcShape.PILL_RISE, 0.5, pill)
		&"openings":
			# The speaker's holes, wherever its circle and the face's flat part leave them room.
			var room := ShapeGeometry.rounded(shape.face().grow(-GbcShape.HOLE_RADIUS - 0.5),
				shape.bottom_corner - shape.bevel, shape.top_corner - shape.bevel, steps)
			var pitch := GbcShape.HOLE_PITCH
			var rows := floori(shape.speaker_radius / pitch)
			for row in range(-rows, rows + 1):
				for column in range(-rows - 1, rows + 1):
					var at := shape.speaker + Vector2((column + 0.5 * (row & 1)) * pitch, row * pitch * sqrt(3.0) / 2.0)
					if at.distance_to(shape.speaker) < shape.speaker_radius - GbcShape.HOLE_RADIUS \
							and Geometry2D.is_point_in_polygon(at, room):
						_laid(mesh, shape, ShapeGeometry.circle(at, GbcShape.HOLE_RADIUS, 6), PackedVector2Array([at]))
			# The gap around each button.
			var gap := GbcShape.GAP
			_laid(mesh, shape, _cross(shape.dpad, shape.dpad_size, gap), _cross(shape.dpad, shape.dpad_size))
			for centre: Vector2 in [shape.button_a, shape.button_b]:
				var radius := shape.button_diameter / 2.0
				_laid(mesh, shape, _round(ShapeGeometry.square_around(centre, radius + gap), steps),
					_round(ShapeGeometry.square_around(centre, radius), steps))
			for centre: Vector2 in [shape.select(), shape.start]:
				_laid(mesh, shape, _round(shape.pill(centre, gap), steps), _round(shape.pill(centre), steps))
		&"ir_window":
			var top := shape.height / 2.0
			var under := front - shape.bevel - 0.4
			ShapeGeometry.prism(mesh,
				ShapeGeometry.square(Rect2(shape.ir_x - shape.ir_width / 2.0, top - 0.8, shape.ir_width,
				0.9)), under - GbcShape.IR_DEPTH, under)
		&"recesses":
			var right := outline.end.x
			var recess := shape.recess()
			ShapeGeometry.prism(mesh, ShapeGeometry.square(Rect2(right - 0.3, recess.position.x, 0.35, recess.size.x)),
				recess.position.y, recess.end.y)
			var link := shape.link()
			ShapeGeometry.prism(mesh, ShapeGeometry.square(Rect2(-right - 0.05, link.position.x, 0.35, link.size.x)),
				link.position.y, link.end.y)
		&"power_knob":
			var knob := shape.knob()
			ShapeGeometry.prism(mesh,
				ShapeGeometry.square(Rect2(outline.end.x - 2.0, knob.position.x, 2.0 + GbcShape.KNOB_PROUD,
				knob.size.x)), knob.position.y, knob.end.y)
		&"wheel":
			var middle := shape.side_middle()
			ShapeGeometry.prism(mesh, _teeth(shape.wheel_centre()), middle - GbcShape.WHEEL_THICKNESS / 2.0,
				middle + GbcShape.WHEEL_THICKNESS / 2.0)
		&"screws":
			# Their heads at the foot of their holes.
			mesh.basis = ShapeGeometry.BEHIND
			var foot := front - GbcShape.SCREW_SINK
			for at in shape.screws():
				_disc(mesh, at, GbcShape.SCREW_HEAD.x, foot - 0.05, foot + GbcShape.SCREW_HEAD.y, 0.3, steps)
		&"slot", &"contacts":
			var high := shape.slot_floor() + ShapeGeometry.CONNECTOR_HEIGHT
			mesh.basis = ShapeGeometry.PLAN
			if part == &"slot":
				ShapeGeometry.connector(mesh, shape.connector(), shape.slot_floor(), high)
			else:
				ShapeGeometry.contacts(mesh, shape.connector(), high)
		&"sticker":
			mesh.basis = ShapeGeometry.BEHIND
			ShapeGeometry.decal(mesh, shape.sticker(), front - GbcShape.STICKER_SINK)
		&"battery_cover":
			# Standing on the bulge, the panel sunk in it.
			mesh.basis = ShapeGeometry.BEHIND
			var panel := ShapeGeometry.rounded_box(shape.cover_panel(), GbcShape.PANEL_CORNER, steps, 0.0)
			var face := ShapeGeometry.slab(mesh, shape.cover(0.0, steps), on_bulge - 0.3, on_cover, Vector2(0.0, 0.3),
				outline, false)
			ShapeGeometry.holed(mesh, face, [panel], on_cover, Vector3.BACK, outline, PackedFloat32Array([0.0]))
			ShapeGeometry.sunk(mesh, panel, on_cover - GbcShape.PANEL_SINK, on_cover, outline)
		&"cover_gap":
			# The parting gap's dark at the cover's foot.
			mesh.basis = ShapeGeometry.BEHIND
			ShapeGeometry.slab(mesh, shape.cover(GbcShape.COVER_GAP, steps), on_bulge - 0.3, on_bulge + _LIFT,
				Vector2.ZERO, outline)
		&"cover_mark":
			mesh.basis = ShapeGeometry.BEHIND
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(shape.cover_panel().get_center(), GbcShape.COVER_MARK),
				on_cover - GbcShape.PANEL_SINK)
	return mesh.arrays()


## Adds the front half, from the seam to the face: rings around its rounded edges as a block's,
## then from the face's edge in to the panel's, every point lowered as far as the face rolls back
## there ([method GbcShape.drop]); the panel and the seam close it.
static func _front_half(mesh: MeshBuilder, shape: GbcShape, steps: int) -> void:
	var levels := shape.levels()
	var ring := func(box: Rect2, corners: Vector2) -> PackedVector2Array:
		var loop := ShapeGeometry.rounded(box, corners.x, corners.y, steps)
		for level in levels:
			loop = _SWAP * ShapeGeometry.crossed(_SWAP * loop, level)
		return loop
	var outline := shape.outline()
	var corners := Vector2(shape.bottom_corner, shape.top_corner)
	var bevel := shape.bevel
	var edge: PackedVector2Array = ring.call(outline, corners)
	var face: PackedVector2Array = ring.call(outline.grow(-bevel), corners - Vector2.ONE * bevel)
	var panel: PackedVector2Array = ring.call(shape.panel(), GbcShape.PANEL_CORNERS)
	var front := shape.depth / 2.0
	var rings: Array[PackedInt32Array] = []
	# Around the seam's rounded edge, from the back across to the side, then around the face's.
	for k in 2 * _BEVEL_STEPS + 2:
		var at_front := k > _BEVEL_STEPS
		var angle := PI / 2.0 * absi(k - _BEVEL_STEPS - int(at_front)) / _BEVEL_STEPS
		var sweep := bevel * (1.0 - cos(angle))
		var drop := bevel * (1.0 - sin(angle))
		var loop: PackedVector2Array = ring.call(outline.grow(-sweep), corners - Vector2.ONE * sweep)
		var points := PackedInt32Array()
		for i in loop.size():
			var out := (edge[i] - face[i]).normalized()
			var side := Vector3(out.x, out.y, 0.0) * cos(angle)
			var z := front - drop - shape.drop(face[i]) if at_front else shape.seam() + drop
			var normal := side + (_normal(shape, face[i]) if at_front else Vector3.FORWARD) * sin(angle)
			points.append(ShapeGeometry.add(mesh, loop[i], z, normal, outline))
		rings.append(points)
	for k in range(1, _ROLL_STEPS + 1):
		var points := PackedInt32Array()
		for i in face.size():
			# The last ring is the panel's outline itself, which a lerp can miss by a hair.
			var at := panel[i] if k == _ROLL_STEPS else face[i].lerp(panel[i], float(k) / _ROLL_STEPS)
			points.append(ShapeGeometry.add(mesh, at, front - shape.drop(at), _normal(shape, at), outline))
		rings.append(points)
	ShapeGeometry.join(mesh, rings)
	ShapeGeometry.flat(mesh, panel, front, Vector3.BACK, outline)
	ShapeGeometry.flat(mesh, face, shape.seam(), Vector3.FORWARD, outline)


## The face's normal at [param at], as it rolls back.
static func _normal(shape: GbcShape, at: Vector2) -> Vector3:
	var step := 0.01
	return Vector3(shape.drop(at + Vector2(step, 0.0)) - shape.drop(at - Vector2(step, 0.0)),
		shape.drop(at + Vector2(0.0, step)) - shape.drop(at - Vector2(0.0, step)), 2.0 * step).normalized()


## Adds the flat ring between [param outer] and [param inner] (as many points, or the one point a
## hole is filled to), laid on the face as it rolls back.
static func _laid(mesh: MeshBuilder, shape: GbcShape, outer: PackedVector2Array, inner: PackedVector2Array) -> void:
	for i in outer.size():
		var next := (i + 1) % outer.size()
		if inner.size() == 1:
			mesh.triangle(_on_face(mesh, shape, outer[i]), _on_face(mesh, shape, outer[next]),
				_on_face(mesh, shape, inner[0]))
		else:
			mesh.quad(_on_face(mesh, shape, outer[i]), _on_face(mesh, shape, outer[next]),
				_on_face(mesh, shape, inner[next]), _on_face(mesh, shape, inner[i]))


static func _on_face(mesh: MeshBuilder, shape: GbcShape, at: Vector2) -> int:
	return ShapeGeometry.add(mesh, at, shape.depth / 2.0 + _LIFT - shape.drop(at), _normal(shape, at), shape.outline())


## The D-pad's cross of [param size] around [param centre], grown by [param by].
static func _cross(centre: Vector2, size: float, by := 0.0) -> PackedVector2Array:
	var arm := size * GbcShape.DPAD_ARM / 2.0 + by
	var reach := size / 2.0 + by
	return ShapeGeometry.cross(Rect2(centre - Vector2(reach, arm), Vector2(reach, arm) * 2.0),
		Rect2(centre - Vector2(arm, reach), Vector2(arm, reach) * 2.0))


## Adds the round block of [param radius] around [param centre].
static func _disc(mesh: MeshBuilder, centre: Vector2, radius: float, low: float, high: float, bevel: float,
		steps: int) -> void:
	var box := ShapeGeometry.square_around(centre, radius)
	ShapeGeometry.block(mesh, box, Vector2.ONE * radius, steps, low, high, bevel, box)


## The outline of [param box], its ends or corners fully rounded.
static func _round(box: Rect2, steps: int) -> PackedVector2Array:
	var radius := minf(box.size.x, box.size.y) / 2.0
	return ShapeGeometry.rounded(box, radius, radius, steps)


## The volume wheel's toothed rim, seen along its axis.
static func _teeth(centre: Vector2) -> PackedVector2Array:
	var rim := PackedVector2Array()
	for i in 2 * GbcShape.WHEEL_TEETH:
		var radius := GbcShape.WHEEL_RADIUS - (_WHEEL_TOOTH if i % 2 else 0.0)
		rim.append(centre + Vector2.from_angle(PI * i / GbcShape.WHEEL_TEETH) * radius)
	return rim
