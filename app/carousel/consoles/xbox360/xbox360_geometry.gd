# SPDX-License-Identifier: GPL-3.0-or-later
class_name Xbox360Geometry
extends RefCounted
## Builds the Xbox 360 from its [Xbox360Shape] as pure functions, so that tests check the geometry
## headless. The body, the front's details, the bezel and the drive's opening are swept along Z from
## outlines seen from the front (X right, Y up), in the model's space; what lies on the ends and
## under the body, and the tray's drive (see [DiscTray]), are laid out in their own plane and turned
## into the model's space as they are added (see [member MeshBuilder.basis]). The tray is given at
## rest. Each logo is a face of its own (see [method ShapeGeometry.decal]), on the front or, for the
## top's, in its own plane, at rest on what it is printed on.

const PARTS: Array[StringName] = [&"shell", &"gaps", &"window", &"details", &"grilles", &"drive", &"badge",
	&"feet", &"bezel", &"tray", &"tray_window", &"hub", &"clamp_ring", &"drive_opening", &"eject", &"power", &"ring",
	&"bezel_logo", &"top_logo", &"memory_a", &"memory_b", &"power_mark", &"eject_mark"]
## Each logo's size in millimetres, its image's (`xbox360_<part>.svg`).
const LOGOS: Dictionary[StringName, Vector2] = {
	&"bezel_logo": Vector2(38.0, 8.0), &"top_logo": Vector2(106.0, 15.0), &"memory_a": Vector2(32.0, 4.0),
	&"memory_b": Vector2(32.0, 4.0), &"power_mark": Vector2(6.0, 6.0), &"eject_mark": Vector2(8.0, 8.0),
}
## The top's wordmark: read from the right end, from the front to the back, its letters' tops towards
## the left end; centred a little right of the middle and in front of it, in plan (X, Z to the front).
const _TOP_READ := Basis(Vector3.FORWARD, Vector3.LEFT, Vector3.UP)
const _TOP_LOGO_AT := Vector2(8.0, 15.0)
## From each plane to the model's space, X and Y in the plane and Z out of it: the plan (X right, Y
## towards the front, Z up); the left and the right ends (X towards the front, Y up). The plan and
## the right end are mirrored, which changes nothing: faces are turned by their normals.
const _PLAN := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.UP)
const _LEFT_END := Basis(Vector3.BACK, Vector3.UP, Vector3.LEFT)
const _RIGHT_END := Basis(Vector3.BACK, Vector3.UP, Vector3.RIGHT)
## The seam's width; how far the memory unit flaps stand out of the front, and the grilles out of the
## ends; the hard drive's and its badge's rounded edges, and how far the badge stands out of it; the
## gaps between the ring's lights.
const _SEAM_WIDTH := 0.6
const _FLAP_RAISE := 0.3
const _GRILLE_RAISE := 0.4
const _DRIVE_BEVEL := 6.0
const _BADGE_RAISE := 1.0
const _RING_GAP_DEGREES := 6.0
## The feet: their radius, and how far their centres are in from the ends and from the front and back.
const _FOOT_RADIUS := 6.0
const _FOOT_INSET := Vector2(22.0, 28.0)


## The mesh arrays of [param part], its curves in [param detail] steps.
static func arrays(shape: Xbox360Shape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.depth / 2.0
	var lying := front + Xbox360Shape.RAISE
	match part:
		&"shell":
			_shell(mesh, shape, steps)
		&"gaps":
			_seam(mesh, shape, steps)
			for band in shape.vents():
				_vents(mesh, shape, band)
			_honeycomb(mesh, shape)
			var hole := shape.eject_hole().grow(-Xbox360Shape.RAISE)
			ShapeGeometry.sunk(mesh, ShapeGeometry.circle(shape.eject_centre(), hole.size.x / 2.0, 16 * steps),
				front - Xbox360Shape.EJECT_DEPTH + Xbox360Shape.RAISE, front, hole)
			for port in shape.ports():
				ShapeGeometry.flat(mesh, ShapeGeometry.rounded_box(port, port.size.y / 4.0, steps),
					-lying, Vector3.FORWARD, port)
		&"window":
			var window := shape.window()
			ShapeGeometry.flat(mesh, ShapeGeometry.rounded_box(window, window.size.y / 3.0, steps), lying,
				Vector3.BACK, window)
		&"details":
			for flap in shape.memory_units():
				_raised(mesh, flap, front, _FLAP_RAISE, steps)
			_raised(mesh, shape.usb_flap(), front, 0.4, steps)
			_raised(mesh, shape.sync(), front, 0.6, steps)
			_raised(mesh, shape.boss(), front, Xbox360Shape.BOSS_RAISE, steps)
		&"grilles":
			var grilles := shape.grilles()
			for end: Array in [[grilles[0], _RIGHT_END], [grilles[1], _LEFT_END]]:
				var grille: Rect2 = end[0]
				mesh.basis = end[1]
				ShapeGeometry.block(mesh, grille, Vector2.ONE * 3.0, steps, shape.width / 2.0 - 0.5,
					shape.width / 2.0 + _GRILLE_RAISE, 0.3, grille)
		&"drive":
			var drive := shape.drive()
			var from := shape.width / 2.0 - Xbox360Shape.DRIVE_EMBED
			var to := shape.width / 2.0 + shape.drive_protrusion
			mesh.basis = _LEFT_END
			ShapeGeometry.block(mesh, drive, Vector2.ONE * Xbox360Shape.DRIVE_CORNER, steps, from, to,
				minf(_DRIVE_BEVEL, (to - from) / 2.0 - 0.5), drive)
		&"badge":
			var badge := ShapeGeometry.centred(shape.drive().get_center(), Xbox360Shape.BADGE)
			var face := shape.width / 2.0 + shape.drive_protrusion
			mesh.basis = _LEFT_END
			ShapeGeometry.block(mesh, badge, Vector2.ONE * badge.size.y / 2.0, steps, face - 0.5, face + _BADGE_RAISE,
				0.5, badge)
		&"feet":
			mesh.basis = _PLAN
			for x: float in [-1.0, 1.0]:
				for z: float in [-1.0, 1.0]:
					var centre := Vector2(x, z) * (Vector2(shape.width, shape.depth) / 2.0 - _FOOT_INSET)
					var foot := ShapeGeometry.square_around(centre, _FOOT_RADIUS)
					var top := shape.foot_height + shape.sag(centre.x) + 0.5
					ShapeGeometry.block(mesh, foot, Vector2.ONE * _FOOT_RADIUS, steps, 0.0, top, minf(0.6, top / 3.0),
						foot)
		&"bezel":
			var bezel := shape.bezel()
			ShapeGeometry.block(mesh, bezel, Vector2.ONE * bezel.size.y / 2.0, 2 * steps,
				front - Xbox360Shape.BEZEL_THICKNESS, front, 0.8, bezel)
		&"tray":
			mesh.basis = ShapeGeometry.PLAN
			DiscTray.plate(mesh, shape.plate_plan(), shape.plate_levels(), shape.disc_plan(), shape.disc_radius, steps)
		&"tray_window":
			mesh.basis = ShapeGeometry.PLAN
			DiscTray.window_floor(mesh, shape.disc_plan(), shape.disc_radius, shape.plate_levels().x, steps)
		&"hub":
			mesh.basis = ShapeGeometry.PLAN
			DiscTray.hub(mesh, shape.disc_plan(), shape.plate_levels(), steps)
		&"clamp_ring":
			mesh.basis = ShapeGeometry.PLAN
			DiscTray.clamp_ring(mesh, shape.disc_plan(), shape.plate_levels().y, steps)
		&"drive_opening":
			var slot := shape.slot().grow(-DiscTray.RAISE)
			var mouth := ShapeGeometry.rounded(slot, slot.size.y / 2.0, slot.size.y / 2.0, 2 * steps)
			DiscTray.opening(mesh, mouth, shape.plate(), front - Xbox360Shape.BEZEL_THICKNESS - Xbox360Shape.TRAY_GAP,
				front - shape.pocket_depth() + DiscTray.RAISE)
		&"eject":
			var low := front - Xbox360Shape.EJECT_DEPTH + 0.3
			ShapeGeometry.block(mesh, shape.eject(), Vector2.ONE * shape.eject_radius, 4 * steps, low,
				front + Xbox360Shape.EJECT_RAISE, 0.5 * Xbox360Shape.EJECT_RAISE, shape.eject())
		&"power":
			var radius := shape.ring_radii.x - 0.3
			var button := ShapeGeometry.square_around(shape.power_centre, radius)
			_raised(mesh, button, front + Xbox360Shape.BOSS_RAISE, Xbox360Shape.BUTTON_RAISE, steps)
		&"ring":
			var low := front + Xbox360Shape.BOSS_RAISE - 0.2
			for quarter in 4:
				var lit := _sector(shape.power_centre, shape.ring_radii, quarter * 90.0 + _RING_GAP_DEGREES / 2.0,
					(quarter + 1) * 90.0 - _RING_GAP_DEGREES / 2.0, 2 * steps)
				ShapeGeometry.flat(mesh, lit, low, Vector3.FORWARD, shape.boss())
				ShapeGeometry.flat(mesh, lit, low + 0.2 + Xbox360Shape.RING_RAISE, Vector3.BACK, shape.boss())
				ShapeGeometry.wall(mesh, lit, low, low + 0.2 + Xbox360Shape.RING_RAISE, shape.boss())
		&"bezel_logo":
			var bezel := shape.bezel()
			_logo(mesh, part, Vector2(bezel.end.x - 5.0 - LOGOS[part].x / 2.0, bezel.get_center().y), front)
		&"top_logo":
			# The top curves down to the middle: the wordmark as high as its edge furthest from it.
			var size := LOGOS[part]
			mesh.basis = _TOP_READ
			_logo(mesh, part, Vector2(-_TOP_LOGO_AT.y, -_TOP_LOGO_AT.x),
				shape.height - shape.sag(absf(_TOP_LOGO_AT.x) + size.y / 2.0))
		&"memory_a", &"memory_b":
			_logo(mesh, part, shape.memory_units()[0 if part == &"memory_a" else 1].get_center(), front + _FLAP_RAISE)
		&"power_mark":
			_logo(mesh, part, shape.power_centre, front + Xbox360Shape.BOSS_RAISE + Xbox360Shape.BUTTON_RAISE)
		&"eject_mark":
			_logo(mesh, part, shape.eject_centre(), front + Xbox360Shape.EJECT_RAISE)
	return mesh.arrays()


## Adds [param part]'s logo centred on [param centre], at [param z] (see [method ShapeGeometry.decal]).
static func _logo(mesh: MeshBuilder, part: StringName, centre: Vector2, z: float) -> void:
	ShapeGeometry.decal(mesh, ShapeGeometry.centred(centre, LOGOS[part]), z)


## The body: swept along Z from its front outline between rounded edges, the slot's pocket going in
## from the front.
static func _shell(mesh: MeshBuilder, shape: Xbox360Shape, steps: int) -> void:
	var back := -shape.depth / 2.0
	var front := shape.depth / 2.0
	var box := shape.front()
	var outline := func(by: float) -> PackedVector2Array: return _outline(shape, by, steps)
	var face := ShapeGeometry.rounded_sides(mesh, outline, back, front, shape.bevel, box)
	ShapeGeometry.flat(mesh, face, back, Vector3.FORWARD, box)
	# The front has the slot and, left of it, the eject button's hole through it: drawn as its halves
	# above and below the slot's middle, each a simple outline, joined along the two ends' points at
	# that height and round the holes' halves, met left to right above, right to left below.
	var slot := _slot(shape, 2 * steps)
	var hole := _eject_hole(shape, steps)
	var level := shape.slot().get_center().y
	var ends := ShapeGeometry.cuts(_swapped(face), level)
	var met: Array[Array] = [[hole, slot], [slot, hole]]
	for half in 2:
		var piece := ShapeGeometry.between(face, ends[1 - half], ends[half])
		for loop: PackedVector2Array in met[half]:
			var loop_ends := ShapeGeometry.cuts(_swapped(loop), level)
			var inner := ShapeGeometry.between(loop, loop_ends[1 - half], loop_ends[half])
			inner.reverse()
			piece.append_array(inner)
		ShapeGeometry.flat(mesh, piece, front, Vector3.BACK, box)
	ShapeGeometry.sunk(mesh, slot, front - shape.pocket_depth(), front, box)
	ShapeGeometry.sunk(mesh, hole, front - Xbox360Shape.EJECT_DEPTH, front, box)


## The body's front outline shrunk by [param by], counter-clockwise: the rounded rectangle of
## [method Xbox360Shape.front], with points across its top and bottom, curved in by
## [method Xbox360Shape.sag], and a point on each end at the slot's middle height. Any [param by]
## gives as many points, in the same places along the outline.
static func _outline(shape: Xbox360Shape, by: float, steps: int) -> PackedVector2Array:
	var box := shape.front().grow(-by)
	var corner := shape.corner - by
	var loop := ShapeGeometry.rounded_box(box, corner, steps)
	var across := shape.width / 2.0 - shape.corner
	var cuts := 2 * steps + 1
	for i in cuts:
		loop = ShapeGeometry.crossed(loop, lerpf(-across, across, (i + 0.5) / cuts))
	loop = _swapped(ShapeGeometry.crossed(_swapped(loop), shape.slot().get_center().y))
	var middle := box.get_center().y
	var straight := box.size.y / 2.0 - corner
	# The corners and the top and bottom curve in; the ends' points at the slot's height stay.
	for i in loop.size():
		var off := loop[i].y - middle
		if absf(off) > straight - 0.001:
			loop[i].y -= signf(off) * shape.sag(loop[i].x)
	return loop


## The slot's outline, counter-clockwise, round at both ends.
static func _slot(shape: Xbox360Shape, steps: int) -> PackedVector2Array:
	var slot := shape.slot()
	return ShapeGeometry.rounded(slot, slot.size.y / 2.0, slot.size.y / 2.0, steps)


## The eject button's round hole, counter-clockwise, in as many points round as the button.
static func _eject_hole(shape: Xbox360Shape, steps: int) -> PackedVector2Array:
	return ShapeGeometry.circle(shape.eject_centre(), shape.eject_hole().size.x / 2.0, 16 * steps)


## [param loop] with each point's X and Y swapped: its crossings at a height are found as those at an X.
static func _swapped(loop: PackedVector2Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	for point in loop:
		found.append(Vector2(point.y, point.x))
	return found


## The faceplate's seam: a thin band round the body, just above it.
static func _seam(mesh: MeshBuilder, shape: Xbox360Shape, steps: int) -> void:
	var outline := _outline(shape, -Xbox360Shape.RAISE, steps)
	var face := _outline(shape, shape.bevel, steps)
	var box := shape.front()
	var at := Vector2(shape.seam() - _SEAM_WIDTH / 2.0, shape.seam() + _SEAM_WIDTH / 2.0)
	for i in outline.size():
		var next := (i + 1) % outline.size()
		var out := (outline[i] - face[i]).normalized()
		var normal := Vector3(out.x, out.y, 0.0)
		var out_next := (outline[next] - face[next]).normalized()
		var normal_next := Vector3(out_next.x, out_next.y, 0.0)
		mesh.quad(ShapeGeometry.add(mesh, outline[i], at.x, normal, box),
			ShapeGeometry.add(mesh, outline[next], at.x, normal_next, box),
			ShapeGeometry.add(mesh, outline[next], at.y, normal_next, box),
			ShapeGeometry.add(mesh, outline[i], at.y, normal, box))


## The holes of a vent along an end of the top, in [param band] of the plan: rows along it, every
## other one shifted by half a hole, each hole following the top's curve.
static func _vents(mesh: MeshBuilder, shape: Xbox360Shape, band: Rect2) -> void:
	var pitch := Xbox360Shape.VENT_PITCH
	var on_top := func(point: Vector2) -> Vector3:
		return Vector3(point.x, shape.height - shape.sag(point.x) + Xbox360Shape.RAISE, point.y)
	for row in Xbox360Shape.VENT_ROWS:
		var shift := pitch / 2.0 * (row % 2)
		for k in floori((band.size.y - shift) / pitch):
			var centre := band.position + Vector2((row + 0.5) * pitch, shift + (k + 0.5) * pitch)
			_hole(mesh, centre, Xbox360Shape.VENT_HOLE / 2.0, on_top, Vector3.UP)


## The honeycomb's holes at the back, in staggered rows, but across the rib at its middle.
static func _honeycomb(mesh: MeshBuilder, shape: Xbox360Shape) -> void:
	var area := shape.honeycomb()
	var holes := Xbox360Shape.HONEYCOMB_HOLES
	var on_back := func(point: Vector2) -> Vector3:
		return Vector3(point.x, point.y, -shape.depth / 2.0 - Xbox360Shape.RAISE)
	var rows := floori(area.size.y / holes.y)
	for row in rows:
		var y := area.position.y + (area.size.y - (rows - 1) * holes.y) / 2.0 + row * holes.y
		if absf(y - area.get_center().y) < holes.y / 2.0:
			continue
		var shift := holes.x / 2.0 * (row % 2)
		for k in floori((area.size.x - shift) / holes.x):
			_hole(mesh, Vector2(area.position.x + shift + (k + 0.5) * holes.x, y), holes.z / 2.0, on_back,
				Vector3.FORWARD)


## A round hole of [param radius] at [param centre], drawn as a hexagon whose points [param placed]
## puts in the model's space, facing [param normal].
static func _hole(mesh: MeshBuilder, centre: Vector2, radius: float, placed: Callable, normal: Vector3) -> void:
	var corners := PackedInt32Array()
	for k in 6:
		var at: Vector3 = placed.call(centre + Vector2.from_angle(k * PI / 3.0) * radius)
		corners.append(mesh.add(at, normal, Vector2.ZERO))
	for k in range(1, 5):
		mesh.triangle(corners[0], corners[k], corners[k + 1])


## A rounded detail standing [param raise] out of the front at [param front], round at its ends,
## its edges rounded, from half a millimetre inside it.
static func _raised(mesh: MeshBuilder, box: Rect2, front: float, raise: float, steps: int) -> void:
	var radius := minf(box.size.x, box.size.y) / 2.0
	ShapeGeometry.block(mesh, box, Vector2.ONE * radius, steps, front - 0.5, front + raise, 0.4 * raise, box)


## The ring of lights' sector about [param centre] between [param radii], from [param from] to
## [param to] degrees, counter-clockwise, its arcs in [param steps] steps.
static func _sector(centre: Vector2, radii: Vector2, from: float, to: float, steps: int) -> PackedVector2Array:
	var found := PackedVector2Array()
	for step in steps + 1:
		found.append(centre + Vector2.from_angle(deg_to_rad(lerpf(from, to, float(step) / steps))) * radii.y)
	for step in steps + 1:
		found.append(centre + Vector2.from_angle(deg_to_rad(lerpf(to, from, float(step) / steps))) * radii.x)
	return found
