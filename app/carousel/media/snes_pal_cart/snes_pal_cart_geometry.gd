# SPDX-License-Identifier: GPL-3.0-or-later
class_name SnesPalCartGeometry
extends RefCounted
## Builds the European Super Nintendo's cartridge from its [SnesPalCartShape] as pure functions, so
## that tests check the geometry headless. Every piece is a solid of its own, closed, laid over the
## others: the back half's skin, the two layers either side of the seam notched for the slot, the
## front half's skin with its rolled edges, the label's recess and the grip, the plates on it. The
## pieces the North American cartridge shares are public.

const PARTS: Array[StringName] = [&"label", &"shell", &"metal", &"dark", &"board"]
const _SLIT_STEPS := 3
## A slit's dark face stands this far over the roll it lies on, and goes this far into it.
const _SLIT_OFF := 0.04
const _SLIT_INTO := 0.5
## Lays a section drawn in X and Z (as X and Y) along Y: from a side's plane into the model's.
const _ACROSS := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
## Points round a screw's head or a hole.
const _ROUND := 16


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: SnesPalCartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.thickness / 2.0
	match part:
		&"label":
			ShapeGeometry.flat(mesh, _label(shape, steps), shape.wings() - shape.recess, Vector3.BACK, shape.label_box())
		&"shell":
			_shell(mesh, shape, steps)
		&"metal":
			screws(mesh, shape.screws(), shape.screw_radius, shape.wings())
			contacts(mesh, shape.tongues(), shape.centre_contacts, shape.side_contacts, shape.contact_pitch)
		&"dark":
			for y in shape.slits():
				for side: float in [-1.0, 1.0]:
					_slit(mesh, side, y, shape.slit_height, shape.front_outline().end.x, shape.wings(), shape.side_round)
			for at in shape.holes():
				ShapeGeometry.prism(mesh, ShapeGeometry.circle(at, shape.hole_radius, _ROUND), -front - _SLIT_OFF,
					-front + 0.15)
		&"board":
			board(mesh, shape.tongues())
	return mesh.arrays()


## Adds the back half's skin of [param outline] (its corners rounded by [param corner], its back's
## edges by [param bevel]), from its back, [param back] behind the middle, to [param seam] behind
## it, the [param sticker]'s recess [param depth] deep in its back.
static func back_half(mesh: MeshBuilder, outline: Rect2, corner: float, bevel: float, back: float, seam: float,
		sticker: Rect2, depth: float, steps: int) -> void:
	# Built facing the back as a front half faces the front.
	mesh.basis = Basis.FLIP_Z
	var cut := sticker.get_center().x
	var face := ShapeGeometry.rolled(mesh, outline, corner, seam, back, Vector3.ONE * bevel, steps, outline, cut)
	var recess := ShapeGeometry.rounded_box(sticker, SnesPalCartShape.RIM, steps, cut)
	ShapeGeometry.holed(mesh, face, [recess], back, Vector3.BACK, outline, PackedFloat32Array([cut]))
	ShapeGeometry.sunk(mesh, recess, back - depth, back, outline)
	mesh.basis = Basis()


## Adds the two layers either side of the middle, [param seam] thick each, notched for the slot of
## [param slot] (its width, and how deep it goes in): the back one of [param outline], the front
## one set in by [param inset] (its corners rounded by [param corner]).
static func slot_layers(mesh: MeshBuilder, outline: Rect2, corner: float, inset: float, seam: float, slot: Vector2,
		steps: int) -> void:
	ShapeGeometry.slab(mesh, _notched(outline, corner, slot, steps), -seam, 0.0, Vector2.ZERO, outline)
	ShapeGeometry.slab(mesh, _notched(outline.grow(-inset), corner, slot - Vector2(0.0, inset), steps), 0.0, seam,
		Vector2.ZERO, outline)


## The board's tongues, left to right as seen from the front, from [param end] (the cartridge's)
## into the slot [param depth] deep: the middle one with [param middle] contacts, the side ones, with
## [param sides] each, only when it has any; [param pitch] apart.
static func board_tongues(end: float, depth: float, middle: int, sides: int, pitch: float) -> Array[Rect2]:
	var bottom := end + SnesPalCartShape.BOARD_INSET
	var length := depth - SnesPalCartShape.BOARD_INSET + 1.0
	var width := middle * pitch + 1.0
	var found: Array[Rect2] = [Rect2(-width / 2.0, bottom, width, length)]
	if sides > 0:
		var side := sides * pitch + 1.0
		var from := width / 2.0 + SnesPalCartShape.BOARD_GAP
		found.push_front(Rect2(-from - side, bottom, side, length))
		found.append(Rect2(from, bottom, side, length))
	return found


## How wide [param tongues] are together.
static func across(tongues: Array[Rect2]) -> float:
	return tongues[-1].end.x - tongues[0].position.x


## Adds the screws' heads at [param centres], of [param radius], standing out of the face at
## [param face].
static func screws(mesh: MeshBuilder, centres: PackedVector2Array, radius: float, face: float) -> void:
	for at in centres:
		ShapeGeometry.prism(mesh, ShapeGeometry.circle(at, radius, _ROUND), face - 0.15,
			face + SnesPalCartShape.SCREW_PROUD)


## Adds the board's [param tongues], through the middle of the thickness.
static func board(mesh: MeshBuilder, tongues: Array[Rect2]) -> void:
	var half := SnesPalCartShape.BOARD_THICKNESS / 2.0
	for tongue in tongues:
		ShapeGeometry.prism(mesh, ShapeGeometry.square(tongue), -half, half)


## Adds the contacts on both faces of [param tongues] (the middle one with [param middle] of them,
## the others with [param sides]), [param pitch] apart from the tongue's edge.
static func contacts(mesh: MeshBuilder, tongues: Array[Rect2], middle: int, sides: int, pitch: float) -> void:
	var boxes: Array[Vector4] = []
	for tongue in tongues:
		# Within the slot, short of the millimetre of the tongue held in its floor.
		var length := minf(SnesPalCartShape.CONTACT_LENGTH, tongue.size.y - 2.0)
		var count := middle if tongues.size() == 1 or tongue == tongues[1] else sides
		for i in count:
			boxes.append(Vector4(tongue.position.x + 0.5 + pitch * (i + 0.5), tongue.position.y + 0.5 + length / 2.0,
				pitch * SnesPalCartShape.CONTACT_SHARE, length))
	var half := SnesPalCartShape.BOARD_THICKNESS / 2.0
	for face: float in [-half, half]:
		ShapeGeometry.boxes_on(mesh, boxes, face, Vector2(-0.02, 0.05))


static func _shell(mesh: MeshBuilder, shape: SnesPalCartShape, steps: int) -> void:
	var whole := shape.outline()
	var front := shape.thickness / 2.0
	var seam := shape.slot_size.y / 2.0
	back_half(mesh, whole, shape.corner, shape.back_round, front, seam, shape.sticker_box(), shape.sticker_recess,
		steps)
	slot_layers(mesh, whole, shape.corner, shape.seam, seam, Vector2(shape.slot_size.x, shape.slot_depth), steps)
	var cut := shape.grip_centre.x
	var label := _label(shape, steps)
	var grip := ShapeGeometry.rounded_box(shape.grip_box(), shape.grip_corner(), steps, cut)
	var grip_floor := ShapeGeometry.rounded_box(shape.grip_floor(), shape.grip_corner() - shape.grip_slope, steps, cut)
	var wings := shape.wings()
	var face := ShapeGeometry.rolled(mesh, shape.front_outline(), shape.corner, seam, wings,
		Vector3(shape.side_round, shape.end_round, shape.top_round), steps, whole, cut)
	ShapeGeometry.holed(mesh, face, [grip, label], wings, Vector3.BACK, whole, PackedFloat32Array([cut]))
	ShapeGeometry.sunk(mesh, label, wings - shape.recess, wings, whole, false)
	var bottom := front - shape.grip_depth
	var rings: Array[PackedInt32Array] = [PackedInt32Array(), PackedInt32Array()]
	for i in grip.size():
		var run := grip[i] - grip_floor[i]
		var normal := Vector3(-run.x * (wings - bottom), -run.y * (wings - bottom), run.length_squared())
		rings[0].append(ShapeGeometry.add(mesh, grip[i], wings, normal, whole))
		rings[1].append(ShapeGeometry.add(mesh, grip_floor[i], bottom, normal, whole))
	ShapeGeometry.join(mesh, rings)
	ShapeGeometry.flat(mesh, grip_floor, bottom, Vector3.BACK, whole)
	var middle := ShapeGeometry.centred(shape.grip_centre, Vector2(shape.grip_middle, shape.grip_floor().size.y))
	ShapeGeometry.prism(mesh, ShapeGeometry.square(middle), bottom - 0.3, bottom + shape.grip_rise, whole)
	for ridge in shape.ridges():
		ShapeGeometry.prism(mesh, ShapeGeometry.square(ridge), bottom - 0.1, bottom + SnesPalCartShape.RIDGE.y, whole)
	var corner := SnesPalCartShape.PLATE_CORNER
	var plate := shape.plate_back()
	var lower := ShapeGeometry.rolled(mesh, shape.lower_plate(), corner, plate, front,
		Vector3(shape.plate_round, shape.plate_end_round, shape.plate_round), steps, whole, cut, grip)
	ShapeGeometry.holed(mesh, lower, [grip], front, Vector3.BACK, whole, PackedFloat32Array([cut]))
	var strip := ShapeGeometry.rolled(mesh, shape.top_strip(), corner, plate, front, Vector3.ONE * shape.plate_round,
		steps, whole)
	ShapeGeometry.flat(mesh, strip, front, Vector3.BACK, whole)


## The outline of [param box], its corners rounded by [param corner], its bottom edge notched in the
## middle [param notch].x wide and [param notch].y deep.
static func _notched(box: Rect2, corner: float, notch: Vector2, steps: int) -> PackedVector2Array:
	var loop := ShapeGeometry.rounded(box, corner, corner, steps)
	var bottom := box.position.y
	var half := notch.x / 2.0
	# After the bottom left corner, the third of four.
	var at := 3 * (steps + 1)
	for point: Vector2 in [Vector2(-half, bottom), Vector2(-half, bottom + notch.y), Vector2(half, bottom + notch.y),
			Vector2(half, bottom)]:
		loop.insert(at, point)
		at += 1
	return loop


## Adds a slit up the roll of the right side ([param side] 1) or the left one (-1), [param tall]
## high around [param y]: a dark face laid a hair over the side, from below its roll up the roll of
## [param roll] that the side, at [param edge] from the middle, turns through to the face at
## [param face].
static func _slit(mesh: MeshBuilder, side: float, y: float, tall: float, edge: float, face: float, roll: float) -> void:
	var centre := Vector2(edge - roll, face - roll)
	var outer := PackedVector2Array([Vector2(edge + _SLIT_OFF, centre.y - SnesPalCartShape.SLIT_SIDE)])
	var inner := PackedVector2Array([Vector2(edge - _SLIT_INTO, centre.y - SnesPalCartShape.SLIT_SIDE)])
	for step in _SLIT_STEPS + 1:
		var out := Vector2.from_angle(deg_to_rad(SnesPalCartShape.SLIT_REACH) * step / _SLIT_STEPS)
		outer.append(centre + out * (roll + _SLIT_OFF))
		inner.append(centre + out * (roll - _SLIT_INTO))
	inner.reverse()
	outer.append_array(inner)
	for i in outer.size():
		outer[i].x *= side
	if Geometry2D.is_polygon_clockwise(outer):
		outer.reverse()
	mesh.basis = _ACROSS
	ShapeGeometry.prism(mesh, outer, -y - tall / 2.0, -y + tall / 2.0)
	mesh.basis = Basis()


## The label's outline, cut along the grip's middle as the face round it is.
static func _label(shape: SnesPalCartShape, steps: int) -> PackedVector2Array:
	return ShapeGeometry.rounded_box(shape.label_box(), shape.label_corner, steps, shape.grip_centre.x)

