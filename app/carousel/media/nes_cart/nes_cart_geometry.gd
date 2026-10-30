# SPDX-License-Identifier: GPL-3.0-or-later
class_name NesCartGeometry
extends RefCounted
## Builds a NES Game Pak from its [NesCartShape] as pure functions, so that tests check the geometry
## headless. Recesses are not cut out of a solid: the shell's middle is a square-edged slab of the
## outline, and the front and the back are laid on it as solids of their own, each closed, bevelled
## where it meets the outside: the faces around the recesses, the floors and bars inside them, the
## pocket's floor the middle's own face. What is printed on the back is a thin plate of its own. The
## outline is given as its corners and their radii ([method outline], [method loop]), which the
## Famicom's cartridge shares.

const PARTS: Array[StringName] = [&"label", &"shell", &"opening", &"screws", &"sticker", &"lettering"]
## How far the pieces laid on a face go into it, hidden, and how far the opening and the screws'
## holes stand out of theirs, so as not to flicker with them.
const _SUNK := 0.1
const OVER := 0.03


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: NesCartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.depth / 2.0
	var recess := _recess(shape, steps)
	match part:
		&"label":
			ShapeGeometry.flat(mesh, recess, front - shape.recess, Vector3.BACK, shape.label_box())
		&"shell":
			_shell(mesh, shape, steps, recess)
		&"opening":
			opening(mesh, shape.opening, -shape.height / 2.0)
			for at in shape.screws():
				ShapeGeometry.prism(mesh, ShapeGeometry.circle(at, shape.screw.x / 2.0, 4 * steps), -front - OVER,
					_SUNK - front)
		&"screws":
			for at in shape.screws():
				ShapeGeometry.prism(mesh, ShapeGeometry.circle(at, shape.screw.y / 2.0, 4 * steps),
					-front - 2.0 * OVER, _SUNK - front)
		&"sticker":
			printed(mesh, shape.sticker_box(), front, front + shape.sticker_thickness)
		&"lettering":
			printed(mesh, shape.plate_box(), front + shape.plate_rise, front + shape.plate_rise + OVER)
	return mesh.arrays()


## Adds a thin plate printed on the back, seen from the front at [param box], from [param low] to
## [param high] out of the back, its image upright seen from behind.
static func printed(mesh: MeshBuilder, box: Rect2, low: float, high: float) -> void:
	mesh.basis = ShapeGeometry.BEHIND
	var seen := ShapeGeometry.behind(box)
	ShapeGeometry.prism(mesh, ShapeGeometry.square(seen), low - _SUNK, high, seen)
	mesh.basis = Basis()


## The corners of a cartridge's outline, counter-clockwise from its stub's bottom left, each its X,
## its Y and its radius: [param size] wide and high around the centre, its stub [param stub] at the
## bottom, its top corners rounded by [param top], the others by [param corner], its shoulders'
## inner corners square; [param cuts] (right to left, each its right X, its left X and its depth)
## cut into its top edge, their mouths rounded by [param mouth].
static func outline(size: Vector2, stub: Vector2, top: float, corner: float, mouth: float,
		cuts: Array[Vector3]) -> Array[Vector3]:
	var half := size / 2.0
	var shoulders := stub.y - half.y
	var corners: Array[Vector3] = [Vector3(-stub.x / 2.0, -half.y, corner), Vector3(stub.x / 2.0, -half.y, corner),
		Vector3(stub.x / 2.0, shoulders, 0.0), Vector3(half.x, shoulders, corner), Vector3(half.x, half.y, top)]
	for cut in cuts:
		corners.append_array([Vector3(cut.x, half.y, mouth), Vector3(cut.x, half.y - cut.z, 0.0),
			Vector3(cut.y, half.y - cut.z, 0.0), Vector3(cut.y, half.y, mouth)])
	corners.append_array([Vector3(-half.x, half.y, top), Vector3(-half.x, shoulders, corner),
		Vector3(-stub.x / 2.0, shoulders, 0.0)])
	return corners


## The outline through [param corners] (each its X, its Y and its radius), each rounded in
## [param steps] steps.
static func loop(corners: Array[Vector3], steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radii := PackedFloat32Array()
	for at in corners:
		points.append(Vector2(at.x, at.y))
		radii.append(at.z)
	return ShapeGeometry.filleted(points, radii, steps)


## Adds the dark opening over a cartridge's connector, [param size] wide and through its depth, on
## its end at the height [param bottom].
static func opening(mesh: MeshBuilder, size: Vector2, bottom: float) -> void:
	mesh.basis = ShapeGeometry.PLAN
	ShapeGeometry.prism(mesh, ShapeGeometry.square(ShapeGeometry.centred(Vector2.ZERO, size)), bottom - OVER,
		bottom + _SUNK)
	mesh.basis = Basis()


static func _recess(shape: NesCartShape, steps: int) -> PackedVector2Array:
	var box := shape.label_box()
	var mouth := shape.label_corner
	return loop([Vector3(box.position.x, box.position.y, mouth), Vector3(box.end.x, box.position.y, mouth),
		Vector3(box.end.x, box.end.y, 0.0), Vector3(box.position.x, box.end.y, 0.0)], steps)


static func _shell(mesh: MeshBuilder, shape: NesCartShape, steps: int, recess: PackedVector2Array) -> void:
	var whole := ShapeGeometry.centred(Vector2.ZERO, Vector2(shape.width, shape.height))
	var front := shape.depth / 2.0
	var middle := front - shape.relief()
	_faces(mesh, shape, steps, whole)
	_channel(mesh, shape, steps, whole)
	ShapeGeometry.wall(mesh, recess, middle, front - shape.recess, whole)
	ShapeGeometry.flat(mesh, recess, middle, Vector3.FORWARD, whole)
	ShapeGeometry.prism(mesh, shape.triangle(), front - _SUNK, front + shape.triangle_rise, whole)
	ShapeGeometry.prism(mesh, ShapeGeometry.square(shape.plate_box()), -front - shape.plate_rise, _SUNK - front,
		whole)


static func _faces(mesh: MeshBuilder, shape: NesCartShape, steps: int, whole: Rect2) -> void:
	var size := whole.size
	var top := size.y / 2.0
	var front := shape.depth / 2.0
	var middle := front - shape.relief()
	var tips := shape.mouth()
	var channel := shape.channel_box()
	var label := shape.label_box()
	var notches := shape.notches()
	var corners := outline(size, shape.stub, shape.corner, shape.corner, tips, notches)
	ShapeGeometry.prism(mesh, loop(corners, steps), -middle, middle, whole)
	var left: Array[Vector3] = []
	left.assign(corners.filter(func(at: Vector3) -> bool: return at.x < channel.position.x))
	left.insert(1, Vector3(channel.position.x, -top, tips))
	left.insert(2, Vector3(channel.position.x, top, tips))
	var right: Array[Vector3] = [Vector3(channel.end.x, -top, tips)]
	right.append_array(corners.filter(func(at: Vector3) -> bool: return at.x > channel.end.x))
	right.append_array([Vector3(label.end.x, top, tips), Vector3(label.end.x, label.position.y, shape.label_corner),
		Vector3(label.position.x, label.position.y, shape.label_corner), Vector3(label.position.x, top, tips),
		Vector3(channel.end.x, top, tips)])
	ShapeGeometry.slab(mesh, loop(left, steps), middle, front, Vector2(0.0, shape.bevel), whole)
	ShapeGeometry.slab(mesh, loop(right, steps), middle, front, Vector2(0.0, shape.bevel), whole)
	var pocket := Vector3(channel.end.x, channel.position.x, shape.pocket)
	var back := outline(size, shape.stub, shape.corner, shape.corner, tips, [notches[0], pocket, notches[1]])
	for i in back.size():
		var at := back[i]
		if is_equal_approx(at.y, top - shape.pocket) and channel.position.x <= at.x and at.x <= channel.end.x:
			back[i].z = shape.pocket_corner
	ShapeGeometry.slab(mesh, loop(back, steps), -front, -middle, Vector2(shape.bevel, 0.0), whole)


static func _channel(mesh: MeshBuilder, shape: NesCartShape, steps: int, whole: Rect2) -> void:
	var top := whole.end.y
	var middle := shape.depth / 2.0 - shape.relief()
	var floor_level := shape.depth / 2.0 - shape.channel_depth
	var channel := shape.channel_box()
	var foot := top - shape.pocket
	var under_pocket := Rect2(channel.position.x, -top, channel.size.x, whole.size.y - shape.pocket)
	ShapeGeometry.prism(mesh, ShapeGeometry.square(under_pocket), middle, floor_level, whole)
	for box in shape.bars():
		ShapeGeometry.prism(mesh, ShapeGeometry.square(box), floor_level, floor_level + shape.bar_rise, whole)
	ShapeGeometry.prism(mesh, ShapeGeometry.rounded(shape.tab_box(), shape.tab.z, shape.tab.z, steps), floor_level,
		floor_level + shape.bar_rise, whole)
	var radius := shape.pocket_corner
	if radius > 0.0:
		for side: float in [1.0, -1.0]:
			var corner := Vector2(channel.position.x if side > 0.0 else channel.end.x, foot)
			var centre := corner + Vector2(side, 1.0) * radius
			var fillet := PackedVector2Array([corner])
			for i in steps + 1:
				var angle := PI / 2.0 * i / steps
				fillet.append(centre - Vector2(side * sin(angle), cos(angle)) * radius)
			if side < 0.0:
				fillet.reverse()
			ShapeGeometry.prism(mesh, fillet, middle - _SUNK, floor_level, whole)
	for side: float in [1.0, -1.0]:
		for box in shape.pocket_bars():
			_pad(mesh, box, middle, middle + shape.bar_rise, side, whole)


static func _pad(mesh: MeshBuilder, box: Rect2, low: float, high: float, side: float, uv: Rect2) -> void:
	ShapeGeometry.prism(mesh, ShapeGeometry.square(box), minf(low * side, high * side), maxf(low * side, high * side),
		uv)
