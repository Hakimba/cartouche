# SPDX-License-Identifier: GPL-3.0-or-later
class_name XboxGeometry
extends RefCounted
## Builds the Xbox from its [XboxShape] as pure functions, so that tests check the geometry
## headless. Each part is laid out in plan, X to the right and Y towards the back, swept up along Z,
## then turned into the model's space: top up (+Y), front towards +Z. The rounded layers are
## [ShapeGeometry] blocks; the strip, the X and the grilles are prisms, its facets and fins wedges,
## their roofs sloping; the jewel's dome is swept through rings. The tray (its drive's plate, hub and
## clamp ring, see [DiscTray]) and the buttons are given at rest. The details on the front and the
## back (the ports, the power button's ring, the connectors) and the drive's opening behind the tray
## are laid out on their faces in the model's space. Each logo is a face of its own (see
## [method ShapeGeometry.decal]): the bezel's on the tray at rest, each button's mark on its button,
## each of the jewel's letters tangent to its dome, those on the front as the details.

const PARTS: Array[StringName] = [&"lower", &"strip", &"upper", &"cross", &"facets", &"fins", &"vents",
	&"grille", &"grille_bars", &"feet", &"module", &"tray", &"tray_window", &"hub", &"clamp_ring", &"drive_opening", &"eject", &"power", &"jewel", &"jewel_ring",
	&"power_ring", &"ports", &"port_openings", &"connectors", &"back_vent", &"vent_bars", &"bezel_logo",
	&"jewel_x_left", &"jewel_b", &"jewel_o", &"jewel_x_right", &"port_1", &"port_2", &"port_3", &"port_4",
	&"microsoft", &"disc_marks", &"eject_mark", &"power_mark"]
## The boxes on the back, by part, each its centre's X from the middle and Y from the table, its
## width and its height, all of a part sinking into the back and standing out of it as far as its
## Vector2 says: the mains, AV and network connectors; the vent and the bars across it.
const ON_BACK: Dictionary[StringName, Array] = {
	&"connectors": [Vector2(-1.0, 1.0), [Vector4(104.0, 17.0, 26.0, 16.0), Vector4(-29.0, 20.0, 34.0, 12.0),
		Vector4(-103.0, 22.0, 16.0, 14.0)]],
	&"back_vent": [Vector2(-0.5, 0.5), [Vector4(0.0, 52.0, 230.0, 28.0)]],
	&"vent_bars": [Vector2(-1.0, 1.0), [Vector4(0.0, 42.0, 230.0, 3.0), Vector4(0.0, 52.0, 230.0, 3.0),
		Vector4(0.0, 62.0, 230.0, 3.0)]],
}
## The logos on the front, each its centre's X from the middle and Y from the table, on the front
## or on the strip's front, set back.
const ON_FRONT: Dictionary[StringName, Array] = {
	&"port_1": [&"front", Vector2(-94.0, 32.0)], &"port_2": [&"front", Vector2(-58.0, 32.0)],
	&"port_3": [&"front", Vector2(58.0, 32.0)], &"port_4": [&"front", Vector2(94.0, 32.0)],
	&"microsoft": [&"front", Vector2(134.0, 14.5)], &"disc_marks": [&"strip", Vector2(116.0, 58.5)],
}
## The controllers' ports on the front, their centres' X from the middle, at one height: each a
## pill across, flattened into the front (half in it), around a smaller one, its opening. Each pill
## is its radius, its length end to end, how flat it is (its depth over its height), its rings
## along each rounded end and along its middle, and its points around.
const PORTS: Array[float] = [-94.0, -58.0, 58.0, 94.0]
const PORT_HEIGHT := 19.0
const PILLS: Dictionary[StringName, Array] = {&"ports": [6.5, 23.0, 0.12, 2, 16],
	&"port_openings": [3.5, 15.0, 0.25, 1, 12]}
## The ring around the power button, on the front's middle panel: the radius of its middle and of
## its tube; its points around and around its tube.
const POWER_RING := Vector2(5.9, 0.7)
const POWER_RING_POINTS := Vector2i(32, 8)
## The jewel: the dark ring's thickness about the X's top; the dome's points around, and its steps
## from its top down to its foot, each a ninth of a half turn of the flattened ball, the fourth one
## standing straight on the X.
const _JEWEL_RING_THICKNESS := 1.0
const _JEWEL_POINTS := 48
const _DOME_STEPS := 4
## Each logo's size in millimetres, its image's (`xbox_<part>.svg`, both Xs of the jewel `xbox_jewel_x.svg`).
const LOGOS: Dictionary[StringName, Vector2] = {
	&"bezel_logo": Vector2(47.0, 8.8), &"jewel_x_left": Vector2(13.1, 9.4), &"jewel_b": Vector2(13.4, 9.4),
	&"jewel_o": Vector2(12.0, 9.4), &"jewel_x_right": Vector2(13.1, 9.4), &"port_1": Vector2(5.0, 6.5),
	&"port_2": Vector2(5.0, 6.5), &"port_3": Vector2(5.0, 6.5), &"port_4": Vector2(5.0, 6.5),
	&"microsoft": Vector2(27.0, 5.0), &"disc_marks": Vector2(48.0, 12.0), &"eject_mark": Vector2(9.0, 9.0),
	&"power_mark": Vector2(6.0, 6.0),
}
## Where each of the jewel's letters is centred, from its middle, as a fraction of its radius.
const _JEWEL_LETTERS: Dictionary[StringName, float] = {
	&"jewel_x_left": -0.577, &"jewel_b": -0.205, &"jewel_o": 0.2, &"jewel_x_right": 0.58,
}
## The feet: their radius, and how far their centres are in from the corners' centres.
const _FOOT_RADIUS := 8.0
const _FOOT_INSET := 18.0
## How deep the buttons go into the front.
const _BUTTON_DEPTH := 3.0


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: XboxShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var body := shape.body()
	var corners := Vector2.ONE * shape.corner
	var at := Transform3D(ShapeGeometry.PLAN, Vector3.ZERO)
	match part:
		&"lower":
			ShapeGeometry.block(mesh, body, corners, steps, shape.foot_height, shape.strip_bottom, shape.bevel, body)
		&"strip":
			var strip := ShapeGeometry.rounded_box(shape.strip(), shape.corner - shape.strip_recess, steps)
			var slotted := Geometry2D.clip_polygons(strip, ShapeGeometry.square(shape.slot()))[0]
			ShapeGeometry.prism(mesh, slotted, shape.strip_bottom, shape.strip_top, body)
		&"upper":
			ShapeGeometry.block(mesh, body, corners, steps, shape.strip_top, shape.lip_top, shape.bevel, body)
		&"cross":
			var outline := ShapeGeometry.rounded(body, shape.corner, shape.corner, steps)
			var cross := PackedVector2Array()
			var wedges := shape.wedges()
			# Each corner's arc, then the wedge cut into the straight side after it.
			for quarter in 4:
				cross.append_array(outline.slice(quarter * (steps + 1), (quarter + 1) * (steps + 1)))
				cross.append_array(wedges[quarter])
			ShapeGeometry.prism(mesh, cross, shape.lip_top, shape.cross_top, body)
		&"facets":
			var wedges := shape.wedges()
			# Sloping from the X's crossing down to a millimetre above the lip; the wedges turn clockwise.
			var edge := shape.lip_top + 1.0
			for facet: PackedVector2Array in [wedges[0], wedges[2]]:
				var loop := facet.duplicate()
				loop.reverse()
				ShapeGeometry.wedge(mesh, loop, shape.lip_top, PackedFloat32Array([edge, shape.cross_top, edge]), body)
		&"fins":
			var high := shape.cross_top - 1.5
			var low := lerpf(shape.lip_top, shape.cross_top, 0.25)
			for fin in shape.fins():
				var loop := ShapeGeometry.square(fin)
				var tops := PackedFloat32Array()
				for point in loop:
					tops.append(high if absf(point.x) < absf(fin.get_center().x) else low)
				ShapeGeometry.wedge(mesh, loop, shape.lip_top, tops, body)
		&"vents":
			# The dark floor between the fins, from the side's bevel in.
			var wedges := shape.wedges()
			for wedge: PackedVector2Array in [wedges[1], wedges[3]]:
				var base := wedge.duplicate()
				for i: int in [0, 2]:
					base[i].x -= signf(base[i].x) * shape.bevel
				ShapeGeometry.flat(mesh, base, shape.lip_top + XboxShape.VENTS_RAISE, Vector3.BACK, body)
		&"grille":
			_on_both_sides(mesh, shape, shape.side_grille(), 0.4, body)
		&"grille_bars":
			for bar in shape.grille_bars():
				_on_both_sides(mesh, shape, bar, XboxShape.GRILLE_RAISE, body)
		&"feet":
			var inset := body.grow(-shape.corner - _FOOT_INSET)
			var size := Vector2.ONE * 2.0 * _FOOT_RADIUS
			var edge := minf(1.0, shape.foot_height / 3.0)
			for x: float in [inset.position.x, inset.end.x]:
				for y: float in [inset.position.y, inset.end.y]:
					var foot := ShapeGeometry.centred(Vector2(x, y), size)
					ShapeGeometry.block(mesh, foot, Vector2.ONE * 0.45 * size.x, steps, 0.0, shape.foot_height,
						edge, foot)
		&"module":
			var module := ShapeGeometry.square(shape.module())
			ShapeGeometry.prism(mesh, module, shape.foot_height + 1.0, shape.strip_bottom - 1.0, body)
		&"tray":
			var bezel := shape.bezel()
			var levels := shape.plate_levels()
			var rounding := minf(1.0, shape.bezel_thickness / 3.0)
			ShapeGeometry.block(mesh, bezel, Vector2.ONE * rounding, steps, shape.strip_bottom + XboxShape.TRAY_GAP,
				shape.strip_top - XboxShape.TRAY_GAP, 0.8 * rounding, bezel)
			DiscTray.plate(mesh, shape.plate(), levels, shape.disc_centre(), shape.disc_radius, steps)
		&"tray_window":
			DiscTray.window_floor(mesh, shape.disc_centre(), shape.disc_radius, shape.plate_levels().x, steps)
		&"hub":
			DiscTray.hub(mesh, shape.disc_centre(), shape.plate_levels(), steps)
		&"clamp_ring":
			DiscTray.clamp_ring(mesh, shape.disc_centre(), shape.plate_levels().y, steps)
		&"drive_opening":
			# Through the strip's whole height, behind the bezel at rest.
			var slot := shape.slot()
			var mouth := Rect2(slot.position.x, shape.strip_bottom, slot.size.x, shape.strip_top - shape.strip_bottom)
			var levels := shape.plate_levels()
			var plate := Rect2(shape.plate().position.x, levels.x, shape.plate().size.x, levels.y - levels.x)
			DiscTray.opening(mesh, ShapeGeometry.square(mouth.grow(-DiscTray.RAISE)), plate,
				-shape.bezel().end.y - XboxShape.TRAY_GAP, -slot.end.y + DiscTray.RAISE)
			at = Transform3D.IDENTITY
		&"eject", &"power", &"eject_mark", &"power_mark":
			# Into the body, so that pressed in they stay in it; each mark on its button.
			var cap := XboxShape.EJECT if part in [&"eject", &"eject_mark"] else XboxShape.POWER
			var centre := Vector2(cap.x, cap.y)
			var panel := shape.depth / 2.0 + XboxShape.MODULE_SIZE.y
			if part in LOGOS:
				ShapeGeometry.decal(mesh, ShapeGeometry.centred(centre, LOGOS[part]),
					panel + XboxShape.BUTTON_RAISE)
			else:
				var disc := ShapeGeometry.square_around(centre, cap.z)
				ShapeGeometry.block(mesh, disc, Vector2.ONE * cap.z, steps, panel - _BUTTON_DEPTH,
					panel + XboxShape.BUTTON_RAISE, 0.3, disc)
			at = Transform3D.IDENTITY
		&"bezel_logo":
			# On the bezel's front, from near its left end, halfway up the strip.
			var size := LOGOS[part]
			var from := Vector2(shape.bezel().position.x + 4.7, (shape.strip_bottom + shape.strip_top - size.y) / 2.0)
			ShapeGeometry.decal(mesh, Rect2(from, size), -shape.bezel().position.y)
			at = Transform3D.IDENTITY
		&"jewel_x_left", &"jewel_b", &"jewel_o", &"jewel_x_right":
			# The jewel is half a flattened sphere: the letter tangent to it at its middle.
			var across := _JEWEL_LETTERS[part]
			var height := sqrt(1.0 - across * across)
			var slope := atan(shape.jewel_rise * across / (shape.jewel_radius * height))
			ShapeGeometry.decal(mesh, Rect2(-LOGOS[part] / 2.0, LOGOS[part]), 0.0)
			at *= Transform3D(Basis(Vector3(0.0, 1.0, 0.0), slope),
				Vector3(across * shape.jewel_radius, 0.0, shape.cross_top + shape.jewel_rise * height)
				* MeshBuilder.UNITS_PER_MM)
		&"jewel_ring":
			ShapeGeometry.prism(mesh, ShapeGeometry.circle(Vector2.ZERO, shape.ring_radius, _JEWEL_POINTS),
				shape.cross_top - _JEWEL_RING_THICKNESS / 2.0, shape.cross_top + _JEWEL_RING_THICKNESS / 2.0)
		&"jewel":
			# From its foot up to its tip.
			var step := PI / (2 * _DOME_STEPS + 1)
			var rings: Array[PackedVector3Array] = [_ring(Vector3(0.0, 0.0, shape.cross_top),
				Vector2.ONE * shape.jewel_radius * sin(_DOME_STEPS * step), _JEWEL_POINTS)]
			for k in range(_DOME_STEPS, -1, -1):
				rings.append(_ring(Vector3(0.0, 0.0, shape.cross_top + shape.jewel_rise * cos(k * step)),
					Vector2.ONE * shape.jewel_radius * maxf(sin(k * step), ShapeGeometry.TIP), _JEWEL_POINTS))
			ShapeGeometry.swept(mesh, rings, body)
		&"power_ring":
			# Its rings around its tube, each round the button.
			var centre := Vector2(XboxShape.POWER.x, XboxShape.POWER.y)
			var panel := shape.depth / 2.0 + XboxShape.MODULE_SIZE.y
			var rings: Array[PackedInt32Array] = []
			for k in POWER_RING_POINTS.y:
				var turn := TAU * k / POWER_RING_POINTS.y
				var ring := PackedInt32Array()
				for out in ShapeGeometry.circle(Vector2.ZERO, 1.0, POWER_RING_POINTS.x):
					ring.append(ShapeGeometry.add(mesh, centre + out * (POWER_RING.x + POWER_RING.y * cos(turn)),
						panel + POWER_RING.y * sin(turn), Vector3(out.x * cos(turn), out.y * cos(turn), sin(turn)),
						ShapeGeometry.square_around(centre, POWER_RING.x + POWER_RING.y)))
				rings.append(ring)
			rings.append(rings[0])
			ShapeGeometry.join(mesh, rings)
			at = Transform3D.IDENTITY
		&"ports", &"port_openings":
			# Laid out along X: each pill's rings across it, round its length.
			var pill: Array = PILLS[part]
			var radius: float = pill[0]
			var length: float = pill[1]
			var flat: float = pill[2]
			var ends: int = pill[3]
			var count: int = pill[4]
			# Each ring's place along the pill from its middle, and its share of the radius: from the
			# left tip round to the middle, along it, round to the right tip.
			var step := PI / 2.0 / (ends + 1)
			var straight := length / 2.0 - radius
			# The tips a hair across even the way the pill is flattened.
			var tip := ShapeGeometry.TIP / flat
			var profile: Array[Vector2] = []
			for k in ends + 2:
				profile.append(Vector2(-straight - radius * cos(k * step), maxf(sin(k * step), tip)))
			for k in range(1, ends + 1):
				profile.append(Vector2(lerpf(-straight, straight, float(k) / (ends + 1)), 1.0))
			for k in range(ends + 1, -1, -1):
				profile.append(Vector2(straight + radius * cos(k * step), maxf(sin(k * step), tip)))
			for x in PORTS:
				var rings: Array[PackedVector3Array] = []
				for ring in profile:
					rings.append(_ring(Vector3(PORT_HEIGHT, shape.depth / 2.0, x + ring.x),
						Vector2(radius, radius * flat) * ring.y, count))
				ShapeGeometry.swept(mesh, rings, body)
			# From laid out along X, Y up and Z out of the front, to the model's space.
			at = Transform3D(Basis(Vector3.UP, Vector3.BACK, Vector3.RIGHT), Vector3.ZERO)
		&"connectors", &"back_vent", &"vent_bars":
			var depths: Vector2 = ON_BACK[part][0]
			var boxes: Array = ON_BACK[part][1]
			ShapeGeometry.boxes_on(mesh, boxes, -shape.depth / 2.0, depths)
			at = Transform3D.IDENTITY
		_:
			var on: StringName = ON_FRONT[part][0]
			var centre: Vector2 = ON_FRONT[part][1]
			var face := shape.depth / 2.0 - (shape.strip_recess if on == &"strip" else 0.0)
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(centre, LOGOS[part]), face)
			at = Transform3D.IDENTITY
	return ShapeGeometry.moved(mesh.arrays(), at)


## The ring of [param count] points around [param centre]'s X and Y at its height, its radii
## [param radii] along X and Y.
static func _ring(centre: Vector3, radii: Vector2, count: int) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for point in ShapeGeometry.circle(Vector2.ZERO, 1.0, count):
		ring.append(centre + Vector3(point.x * radii.x, point.y * radii.y, 0.0))
	return ring


## A box standing out of each side by [param raise], over [param area] of the side (Y along it, up
## from the table), from just inside the wall.
static func _on_both_sides(mesh: MeshBuilder, shape: XboxShape, area: Rect2, raise: float, box: Rect2) -> void:
	for side: float in [-1.0, 1.0]:
		var inner := side * (shape.width / 2.0 - 0.5)
		var outer := side * (shape.width / 2.0 + raise)
		var plan := Rect2(minf(inner, outer), area.position.x, absf(outer - inner), area.size.x)
		ShapeGeometry.prism(mesh, ShapeGeometry.square(plan), area.position.y, area.end.y, box)
