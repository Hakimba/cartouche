# SPDX-License-Identifier: GPL-3.0-or-later
class_name SnesGeometry
extends RefCounted
## Builds the PAL Super Nintendo from its [SnesShape] as pure functions, so that tests check the
## geometry headless. Most parts are laid out in plan, X to the right and Y towards the back, swept
## up along Z, then turned into the model's space (top up, front towards +Z). The shell is lofted
## through [Level]s, its sides, back and front each following its own profile. The bay and the
## ports in it are drawn as seen from the front, the vents as seen from the back. The flaps and the
## eject lever are given about where they turn, the power knob and the reset button where they rest.
## The logos lie on the faces they are printed on (see ONBOARDING, "A logo").

const PARTS: Array[StringName] = [&"base", &"shell", &"panel", &"well", &"flap", &"eject", &"knob", &"reset",
	&"rings", &"power_well", &"eject_gap", &"bay", &"ports", &"contacts", &"vents", &"grooves", &"diode",
	&"badge", &"green", &"red", &"blue", &"yellow", &"nintendo_logo", &"super_nintendo_logo",
	&"entertainment_system_logo", &"power_logo", &"eject_logo", &"reset_logo", &"pal_version_logo", &"port_1_logo",
	&"port_2_logo"]
## A hair off the face they lie on: level with it, they would flicker.
const OFF := 0.05
const _PROFILE_STEPS := 5
## The faces on the front slope, each flat on its stretch of it (see [method _slope_logo]): their X
## from the left of the panel's opening and their width, then their bottom and their height up the
## slope, as fractions of its drop: the logos and the power light. The lettering stays whole, 0.24 mm
## off the slope at most: the label shader repeats its image, so a cut through the letters would show
## as a line.
const _ON_SLOPE: Dictionary[StringName, Rect2] = {
	&"nintendo_logo": Rect2(14.7, 0.8093, 26.3, 0.1425),
	&"super_nintendo_logo": Rect2(14.3, 0.4518, 55.1, 0.2772),
	&"entertainment_system_logo": Rect2(13.3, 0.2822, 53.2, 0.1565),
	&"diode": Rect2(126.9, 0.3297, 7.0, 0.0814),
}
## The controllers' ports in the bay, as seen from the front: their centres' X from the middle and Y
## from the bottom; each a grey frame around dark contacts, as wide and high, and as far sunk into
## the front and standing out of it as their Vector4 says.
const _PORTS: Array[Vector2] = [Vector2(-33.0, 25.0), Vector2(33.0, 25.0)]
const _PORT_BOXES: Dictionary[StringName, Vector4] = {&"ports": Vector4(40.0, 15.0, -0.55, 0.65),
	&"contacts": Vector4(34.0, 8.0, -0.45, 0.75)}
## The colours' badge on the panel: its centre from the panel's back right corner, its radius, how
## high it stands over the panel; each colour's dot on it, its centre from the badge's, its radii
## across and towards the back, from and to how high over the panel it stands.
const _BADGE := Vector4(-22.0, -27.0, 13.0, 0.08)
const _DOTS: Dictionary[StringName, Vector2] = {&"green": Vector2(-6.5, 0.0), &"red": Vector2(6.5, 0.0),
	&"blue": Vector2(0.0, 5.3), &"yellow": Vector2(0.0, -5.3)}
const _DOT := Vector2(4.29, 3.3)
const _DOT_HEIGHTS := Vector2(0.05, 0.13)
## Points around the badge and around a dot.
const _BADGE_POINTS := 32
const _DOT_POINTS := 16
## How many points of the slope a logo's face is kept clear of.
const _BULGE_STEPS := 8
## The words of the switch, in its well in front of the knob (from the middle of the knob's front
## edge); of the eject lever (from the middle of its front edge); of the reset button (likewise); the
## PAL mark on the back flap (from the middle of its free edge); each port's number, moulded in the bay.
const _POWER_LOGO := Rect2(-8.5, -6.7, 17.0, 3.8)
const _EJECT_LOGO := Rect2(-7.0, 6.9, 14.0, 3.6)
const _RESET_LOGO := Rect2(-8.0, 1.7, 16.0, 3.4)
const _PAL_LOGO := Rect2(-20.0, 1.0, 40.0, 2.4)
const _PORT_LOGO := Vector2(5.8, 5.8)
## The plates painted around the controls on the panel, as far past them each way: the reset
## button's ring, the eject lever's gap, the knob's way's ring and, a hair over it, the switch's well.
const _RESET_RING := Vector2(4.0, 4.0)
const _EJECT_GAP := Vector2(2.0, 2.0)
const _POWER_RING := Vector2(3.0, 9.0)
const _POWER_WELL := Vector2(1.0, 7.0)
## How far above the panel the switch's well lies.
const _WELL_PLATE := 0.1


## One height of the shell: how far in from the body its sides, its back and its front are there,
## and the outward normal of each one's profile, as (out, up).
class Level:
	var z: float
	var inset: Vector3
	var normals: Array[Vector2] = []


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: SnesShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var body := shape.body()
	var slot := shape.slot_box()
	var sunk := shape.panel_top() - SnesShape.SUNK
	var at := Transform3D(ShapeGeometry.PLAN, Vector3.ZERO)
	if part in _ON_SLOPE:
		return _slope_logo(mesh, shape, _ON_SLOPE[part])
	match part:
		&"base":
			ShapeGeometry.block(mesh, shape.tray(), Vector2.ONE * (shape.corner - shape.tray_inset),
				steps, 0.0, shape.tray_height + SnesShape.TRAY_BEVEL, SnesShape.TRAY_BEVEL, body)
		&"shell":
			_shell(mesh, shape, steps)
		&"panel":
			# Down into the tray, under the gap around it.
			var panel := shape.panel_box()
			ShapeGeometry.block(mesh, panel, Vector2.ONE * shape.panel_corner, steps, shape.tray_height - 0.5,
				shape.panel_top(), SnesShape.PANEL_BEVEL, panel, NAN, true,
				ShapeGeometry.rounded_box(slot, shape.slot_corner, steps))
		&"well":
			var lining := ShapeGeometry.rounded_box(slot.grow(-OFF), shape.slot_corner - OFF, steps)
			ShapeGeometry.sunk(mesh, lining, shape.tray_height + OFF, shape.panel_top() - OFF, slot)
		&"flap":
			var flap := Rect2(-shape.flap_width() / 2.0, -shape.flap_length(), shape.flap_width(), shape.flap_length())
			_plate(mesh, flap, minf(1.0, minf(flap.size.x, flap.size.y) / 2.0 - 0.05), steps,
				-shape.flap_thickness / 2.0, shape.flap_thickness / 2.0)
		&"eject":
			var lever := Rect2(Vector2(-shape.eject_size.x / 2.0, -shape.eject_size.y), shape.eject_size)
			_plate(mesh, lever, shape.button_corner, steps, -shape.eject_raise - SnesShape.SUNK, 0.0)
		&"knob":
			var knob := shape.knob_box()
			_plate(mesh, knob, shape.button_corner, steps, sunk, shape.panel_top() + shape.knob_size.z * 0.4)
			# The ridge a thumb pushes, across its front.
			var ridge := Rect2(knob.position, Vector2(knob.size.x, knob.size.y / 3.0))
			_plate(mesh, ridge, minf(shape.button_corner, ridge.size.y / 2.0 - 0.05), steps, sunk,
				shape.panel_top() + shape.knob_size.z)
		&"reset":
			_plate(mesh, shape.reset_box(), shape.button_corner, steps, sunk, shape.panel_top() + shape.reset_raise)
		&"rings", &"power_well", &"eject_gap":
			var plates: Array[Rect2] = [shape.knob_way().grow_individual(_POWER_RING.x, _POWER_RING.y, _POWER_RING.x,
				_POWER_RING.y), shape.reset_box().grow_individual(_RESET_RING.x, _RESET_RING.y, _RESET_RING.x,
				_RESET_RING.y)]
			var over := OFF
			if part == &"power_well":
				plates = [shape.knob_way().grow_individual(_POWER_WELL.x, _POWER_WELL.y, _POWER_WELL.x, _POWER_WELL.y)]
				over = _WELL_PLATE
			elif part == &"eject_gap":
				plates = [shape.eject_box().grow_individual(_EJECT_GAP.x, _EJECT_GAP.y, _EJECT_GAP.x, _EJECT_GAP.y)]
			for plate in plates:
				ShapeGeometry.flat(mesh, ShapeGeometry.square(plate), shape.panel_top() + over, Vector3.BACK, plate)
		&"bay":
			# Over the crease, which it interrupts.
			var bay := shape.bay_box()
			ShapeGeometry.flat(mesh, ShapeGeometry.rounded_box(bay, bay.size.y / 2.0, steps), body.end.y + 2.0 * OFF,
				Vector3.BACK, bay)
			at = Transform3D.IDENTITY
		&"ports", &"contacts":
			var box := _PORT_BOXES[part]
			for centre in _PORTS:
				var face_box := Rect2(centre.x - box.x / 2.0, centre.y - box.y / 2.0, box.x, box.y)
				ShapeGeometry.prism(mesh, ShapeGeometry.square(face_box), body.end.y + box.z, body.end.y + box.w)
			at = Transform3D.IDENTITY
		&"vents":
			for vent in shape.vents():
				var slit := ShapeGeometry.rounded_box(vent, minf(vent.size.x, vent.size.y) / 2.0, steps)
				ShapeGeometry.flat(mesh, slit, body.end.y + OFF, Vector3.BACK, vent)
			at = Transform3D(Basis(Vector3.LEFT, Vector3.UP, Vector3.FORWARD), Vector3.ZERO)
		&"badge":
			var centre := shape.panel_box().end + Vector2(_BADGE.x, _BADGE.y)
			ShapeGeometry.prism(mesh, ShapeGeometry.circle(centre, _BADGE.z, _BADGE_POINTS), shape.panel_top(),
				shape.panel_top() + _BADGE.w)
		&"green", &"red", &"blue", &"yellow":
			var centre := shape.panel_box().end + Vector2(_BADGE.x, _BADGE.y) + _DOTS[part]
			var dot := PackedVector2Array()
			for point in ShapeGeometry.circle(Vector2.ZERO, 1.0, _DOT_POINTS):
				dot.append(centre + point * _DOT)
			ShapeGeometry.prism(mesh, dot, shape.panel_top() + _DOT_HEIGHTS.x, shape.panel_top() + _DOT_HEIGHTS.y)
		&"grooves":
			var crease := ShapeGeometry.rounded_box(body.grow(OFF), shape.corner + OFF, steps)
			ShapeGeometry.wall(mesh, crease, shape.crease_height - shape.groove_width / 2.0,
				shape.crease_height + shape.groove_width / 2.0, body)
			var opening := shape.panel_opening()
			var heights := _levels(shape)
			for x: float in [opening.position.x + shape.panel_corner, opening.end.x - shape.panel_corner]:
				_groove(mesh, shape, heights, x, opening.position.y, 2)
				_groove(mesh, shape, heights, x, opening.end.y, 1)
		&"power_logo":
			var knob := shape.knob_box()
			_logo(mesh, Vector2(knob.get_center().x, knob.position.y), _POWER_LOGO, shape.panel_top() + _WELL_PLATE)
		&"eject_logo":
			_logo(mesh, Vector2(0.0, -shape.eject_size.y), _EJECT_LOGO, 0.0)
		&"reset_logo":
			var button := shape.reset_box()
			_logo(mesh, Vector2(button.get_center().x, button.position.y), _RESET_LOGO,
				shape.panel_top() + shape.reset_raise)
		&"pal_version_logo":
			_logo(mesh, Vector2(0.0, -shape.flap_length()), _PAL_LOGO, shape.flap_thickness / 2.0)
		&"port_1_logo", &"port_2_logo":
			# At either rounded end of the bay, as seen from the front.
			var bay := shape.bay_box()
			var side := -1.0 if part == &"port_1_logo" else 1.0
			var middle := bay.get_center() + Vector2(side * (bay.size.x - bay.size.y) / 2.0, 0.0)
			_logo(mesh, middle, Rect2(-_PORT_LOGO / 2.0, _PORT_LOGO), body.end.y + 2.0 * OFF)
			at = Transform3D.IDENTITY
	return ShapeGeometry.moved(mesh.arrays(), at)


## The heights the shell is lofted through, bottom to top: along its bottom round, then along the
## round of its sides, the round of its back and the slope of its front.
static func _levels(shape: SnesShape) -> Array[Level]:
	var heights := PackedFloat64Array()
	var drop := shape.height - shape.front_height
	for step in _PROFILE_STEPS + 1:
		var angle := PI / 2.0 * step / _PROFILE_STEPS
		heights.append(shape.tray_height + shape.bottom_round * (1.0 - cos(angle)))
		heights.append(shape.height - shape.side_round * (1.0 - sin(angle)))
		heights.append(shape.height - shape.back_round * (1.0 - sin(angle)))
		heights.append(shape.front_height + drop * pow(sin(angle), 2.0 / SnesShape.SLOPE_CURVE))
	heights.sort()
	var found: Array[Level] = []
	for z in heights:
		if found.is_empty() or z - found[-1].z > 0.01:
			found.append(_level(shape, z))
	return found


static func _level(shape: SnesShape, z: float) -> Level:
	var level := Level.new()
	level.z = z
	var bottom := _round(shape.bottom_round, shape.tray_height + shape.bottom_round - z, -1.0)
	var tops: Array[Vector3] = [_round(shape.side_round, z - shape.height + shape.side_round, 1.0),
		_round(shape.back_round, z - shape.height + shape.back_round, 1.0), _slope(shape, z)]
	for i in 3:
		level.inset[i] = bottom.x + tops[i].x
		level.normals.append(Vector2(bottom.y, bottom.z) if bottom.z < 0.0 else Vector2(tops[i].y, tops[i].z))
	return level


## How far in a quarter round of [param radius] is, [param into] it from where it starts, and its
## outward normal there, as (inset, out, up), its up turned by [param up].
static func _round(radius: float, into: float, up: float) -> Vector3:
	var along := clampf(into, 0.0, radius)
	var across := sqrt(radius * radius - along * along)
	return Vector3(radius - across, across / radius, up * along / radius)


## How far back the front slope is at height [param z], and its outward normal there, as
## (inset, out, up): a quarter of a superellipse from the front face up to the top.
static func _slope(shape: SnesShape, z: float) -> Vector3:
	var drop := shape.height - shape.front_height
	var rise := pow(clampf((z - shape.front_height) / drop, 0.0, 1.0), SnesShape.SLOPE_CURVE / 2.0)
	var run := sqrt(1.0 - rise * rise)
	var bend := 2.0 - 2.0 / SnesShape.SLOPE_CURVE
	var normal := Vector2(drop * pow(run, bend), shape.slope_run * pow(rise, bend)).normalized()
	return Vector3(shape.slope_run * (1.0 - pow(run, 2.0 / SnesShape.SLOPE_CURVE)), normal.x, normal.y)


## The outline of the shell at [param level]: the body, each side brought in by its inset, each
## corner rounded less as the sides it joins come in.
static func _outline(shape: SnesShape, level: Level, steps: int) -> PackedVector2Array:
	var inset := level.inset
	var box := Rect2(-shape.width / 2.0 + inset.x, -shape.depth / 2.0 + inset.z, shape.width - 2.0 * inset.x,
		shape.depth - inset.y - inset.z)
	return ShapeGeometry.rounded(box, maxf(shape.corner - minf(inset.x, inset.z), 0.5),
		maxf(shape.corner - minf(inset.x, inset.y), 0.5), steps)


## The shell, closed: its outlines joined level to level, each point's normal blending the profiles
## of the sides it faces, and its floor and its top around the panel's opening.
static func _shell(mesh: MeshBuilder, shape: SnesShape, steps: int) -> void:
	var body := shape.body()
	var outward := ShapeGeometry.rounded(body, shape.corner, shape.corner, steps)
	var inward := ShapeGeometry.rounded(body.grow(-1.0), shape.corner - 1.0, shape.corner - 1.0, steps)
	var heights := _levels(shape)
	var outlines: Array[PackedVector2Array] = []
	var rings: Array[PackedInt32Array] = []
	for level in heights:
		var outline := _outline(shape, level, steps)
		var ring := PackedInt32Array()
		for i in outline.size():
			var out := (outward[i] - inward[i]).normalized()
			var profile := level.normals[0] * out.x * out.x + level.normals[1 if out.y > 0.0 else 2] * out.y * out.y
			ring.append(ShapeGeometry.add(mesh, outline[i], level.z,
				Vector3(out.x * profile.x, out.y * profile.x, profile.y), body))
		outlines.append(outline)
		rings.append(ring)
	ShapeGeometry.join(mesh, rings)
	# The panel's opening goes through, its walls square, like a hole through a block.
	var opening := ShapeGeometry.rounded_box(shape.panel_opening(), shape.panel_corner + shape.panel_gap, steps)
	ShapeGeometry.band(mesh, outlines[0], opening, heights[0].z, Vector3.FORWARD, body)
	ShapeGeometry.band(mesh, outlines[-1], opening, heights[-1].z, Vector3.BACK, body)
	ShapeGeometry.sunk(mesh, opening, heights[0].z, heights[-1].z, body, false)


## A groove at [param x] from the panel's edge at [param from] across the flat of the top, then
## down its back (side 1) or its front (side 2) to the face below, a hair off the shell.
static func _groove(mesh: MeshBuilder, shape: SnesShape, heights: Array[Level], x: float, from: float,
		side: int) -> void:
	var toward := 1.0 if side == 1 else -1.0
	# Each point of its path, (y, z), and the shell's normal there, (out, up).
	var path: Array[Vector2] = [Vector2(from, shape.height)]
	var normals: Array[Vector2] = [Vector2(0.0, 1.0)]
	for k in range(heights.size() - 1, -1, -1):
		var level := heights[k]
		path.append(Vector2((shape.depth / 2.0 - level.inset[side]) * toward, level.z))
		normals.append(level.normals[side])
		if level.inset[side] <= 0.0:
			break
	var box := Rect2(x - shape.groove_width / 2.0, -shape.depth / 2.0, shape.groove_width, shape.depth)
	var previous := PackedInt32Array()
	for k in path.size():
		var normal := Vector3(0.0, toward * normals[k].x, normals[k].y)
		var across := PackedInt32Array()
		for along: float in [box.position.x, box.end.x]:
			var at := Vector3(along, path[k].x, path[k].y) + normal * OFF
			across.append(ShapeGeometry.add(mesh, Vector2(at.x, at.y), at.z, normal, box))
		if k > 0:
			mesh.quad(previous[0], previous[1], across[1], across[0])
		previous = across


## Adds the face of a logo: [param box] from [param at], at height [param z].
static func _logo(mesh: MeshBuilder, at: Vector2, box: Rect2, z: float) -> void:
	ShapeGeometry.decal(mesh, Rect2(at + box.position, box.size), z)


## The face of a logo on the front slope, [param at] its X and width from the left of the panel's
## opening, then its bottom and its height up the slope as fractions of the slope's drop: flat along
## the chord between them, out by as far as the slope bulges past it, so that it sinks nowhere into
## it; X across, Y up the slope.
static func _slope_logo(mesh: MeshBuilder, shape: SnesShape, at: Rect2) -> Array:
	var point := func(fraction: float) -> Vector2:
		var z := lerpf(shape.front_height, shape.height, fraction)
		return Vector2(_slope(shape, z).x - shape.depth / 2.0, z)
	var bottom: Vector2 = point.call(at.position.y)
	var top: Vector2 = point.call(at.end.y)
	var up := (top - bottom).normalized()
	var out := Vector2(-up.y, up.x)
	var bulge := 0.0
	for step in _BULGE_STEPS:
		var on: Vector2 = point.call(lerpf(at.position.y, at.end.y, (step + 0.5) / _BULGE_STEPS))
		bulge = maxf(bulge, out.dot(on - bottom))
	var length := bottom.distance_to(top)
	ShapeGeometry.decal(mesh, Rect2(shape.panel_opening().position.x + at.position.x, -length / 2.0, at.size.x,
		length), 0.0)
	var middle := (bottom + top) / 2.0 + out * bulge
	var face := Basis(Vector3.RIGHT, Vector3(0.0, up.x, up.y), Vector3(0.0, out.x, out.y))
	var origin := Vector3(0.0, middle.x, middle.y) * MeshBuilder.UNITS_PER_MM
	return ShapeGeometry.moved(mesh.arrays(), Transform3D(ShapeGeometry.PLAN, Vector3.ZERO) * Transform3D(face, origin))


## A plate of [param box], its corners rounded by [param corner], from [param low] to [param high],
## its edges rounded less than its corners, so that each outline along them keeps its shape.
static func _plate(mesh: MeshBuilder, box: Rect2, corner: float, steps: int, low: float, high: float) -> void:
	var edge := minf(minf(0.4, corner / 2.0), (high - low) / 3.0)
	ShapeGeometry.block(mesh, box, Vector2.ONE * corner, steps, low, high, edge, box)
