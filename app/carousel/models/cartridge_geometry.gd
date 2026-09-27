# SPDX-License-Identifier: GPL-3.0-or-later
class_name CartridgeGeometry
extends RefCounted
## Builds a cartridge from its [CartridgeShape] as pure functions, so that tests check the geometry
## headless. Each block is a rounded outline swept with bevels from its back to its front; the
## body's front has the label's recess, with sloped edges, whose floor is the label.

const PARTS: Array[StringName] = [&"label", &"shell"]
const _BEVEL_STEPS := 3


## A rounded rectangle, counter-clockwise, its bottom corners of radius [param bottom], its top
## ones of [param top], each in [param steps] steps.
static func rounded(box: Rect2, bottom: float, top: float, steps: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for quarter in 4:
		var radius := top if quarter < 2 else bottom
		var x := box.end.x - radius if quarter in [0, 3] else box.position.x + radius
		var y := box.end.y - radius if quarter < 2 else box.position.y + radius
		for step in steps + 1:
			var angle := deg_to_rad(quarter * 90.0 + 90.0 * step / steps)
			var point := Vector2(x, y) + Vector2.from_angle(angle) * radius
			# Where two corners meet (a pill has no straight sides), their points are one.
			if points.is_empty() or not point.is_equal_approx(points[-1]):
				points.append(point)
	if points[0].is_equal_approx(points[-1]):
		points.remove_at(points.size() - 1)
	return points


## The steps of each rounded corner for [param detail] (8 for 128); 3 at least, so that the corners'
## sides stay within [constant CartridgeShape._RIM] of their arcs.
static func corner_steps(detail: int) -> int:
	return maxi(3, floori(detail / 16.0))


## The mesh arrays of [param part], its corners rounded in [method corner_steps]; none when
## [param shape] has [method CartridgeShape.problems] or no such part.
static func arrays(shape: CartridgeShape, part: StringName, detail: int) -> Array:
	if not shape.problems().is_empty() or part not in PARTS:
		return []
	var steps := corner_steps(detail)
	var mesh := MeshBuilder.new()
	var back := -shape.depth / 2.0
	var front := shape.depth / 2.0
	var recessed := front - shape.recess
	# Both loops get a point where the vertical line through the label crosses them, where the
	# body's front is cut in two around the recess.
	var cut := shape.label_centre.x
	var label_corner := shape.label_corner
	var label := _crossed(rounded(shape.label_box(), label_corner, label_corner, steps), cut)
	if part == &"label":
		_flat(mesh, label, recessed, Vector3.BACK, shape.label_box())
		return mesh.arrays()
	var whole := Rect2(-shape.width / 2.0, -shape.height / 2.0, shape.width, shape.height)
	var half := shape.width / 2.0
	var top := shape.height / 2.0
	var body_corners := Vector2(shape.bottom_corner, shape.hidden_corner())
	var face := _block(mesh, shape.body(), body_corners, steps, back, front, shape.bevel, whole, cut,
		false)
	# The recess's edge, sloping down to the label: the label's outline, grown.
	var slope_corner := label_corner + shape.recess_slope
	var edge_box := shape.label_box().grow(shape.recess_slope)
	var edge := _crossed(rounded(edge_box, slope_corner, slope_corner, steps), cut)
	var outside_corner := label_corner + 1.0
	var outside_box := shape.label_box().grow(1.0)
	var outside := _crossed(rounded(outside_box, outside_corner, outside_corner, steps), cut)
	var face_cuts := _cuts(face, cut)
	var edge_cuts := _cuts(edge, cut)
	for side in 2:
		var around := _between(face, face_cuts[side], face_cuts[1 - side])
		var inside := _between(edge, edge_cuts[side], edge_cuts[1 - side])
		inside.reverse()
		around.append_array(inside)
		_flat(mesh, around, front, Vector3.BACK, whole)
	for i in label.size():
		var next := (i + 1) % label.size()
		var towards_label := (label[i] - outside[i]).normalized()
		var slope := Vector3(towards_label.x * shape.recess, towards_label.y * shape.recess,
			shape.recess_slope)
		mesh.quad(_add(mesh, label[i], recessed, slope, whole),
			_add(mesh, label[next], recessed, slope, whole),
			_add(mesh, edge[next], front, slope, whole), _add(mesh, edge[i], front, slope, whole))
	var upper_front := front + shape.ledge
	var upper := Rect2(-half, shape.step(), shape.width, shape.upper_height)
	var upper_corners := Vector2(shape.hidden_corner(), shape.top_corner)
	_block(mesh, upper, upper_corners, steps, back, upper_front, shape.bevel, whole)
	var plate := rounded(shape.plate_box(), shape.plate_corner(), shape.plate_corner(), steps)
	_flat(mesh, plate, upper_front + shape.plate_raise, Vector3.BACK, whole)
	_wall(mesh, plate, upper_front, upper_front + shape.plate_raise, whole)
	# The ridge: a bar rounded all along, its back and top hidden in the upper part.
	var ends := shape.ridge_height / 2.0
	var ridge := Rect2(-half + shape.bevel, top - shape.ridge_height - 0.01,
		shape.width - 2.0 * shape.bevel, shape.ridge_height)
	var ridge_back := upper_front - shape.ridge_height
	# Rounded almost all the way: a thinner flat front would fold at the ends.
	var ridge_front := upper_front + shape.ridge_raise
	_block(mesh, ridge, Vector2.ONE * ends, steps, ridge_back, ridge_front, ends * 0.8, whole)
	return mesh.arrays()


## Adds the block of the rectangle [param box], its bottom corners rounded by [param corners].x
## and its top ones by [param corners].y, from [param back] to [param front], its edges rounded by
## [param bevel], and gives the outline of its front; the front itself is left out when
## [param closed] is false. Each outline along the bevels is the box shrunk, its corners with it,
## so that none folds; they all get a point where they cross the vertical line at [param cut].
static func _block(mesh: MeshBuilder, box: Rect2, corners: Vector2, steps: int, back: float,
		front: float, bevel: float, uv: Rect2, cut := NAN, closed := true) -> PackedVector2Array:
	var shrunk := func(by: float) -> PackedVector2Array:
		return _crossed(rounded(box.grow(-by), corners.x - by, corners.y - by, steps), cut)
	var outline: PackedVector2Array = shrunk.call(0.0)
	var face: PackedVector2Array = shrunk.call(bevel)
	var profile: Array[Vector4] = []
	for step in _BEVEL_STEPS + 1:
		var angle := PI / 2.0 * step / _BEVEL_STEPS
		var sweep := bevel * (1.0 - cos(angle))
		var drop := bevel * (1.0 - sin(angle))
		profile.push_front(Vector4(sweep, back + drop, cos(angle), -sin(angle)))
		profile.append(Vector4(sweep, front - drop, cos(angle), sin(angle)))
	var rings: Array[PackedInt32Array] = []
	for at in profile:
		var loop: PackedVector2Array = shrunk.call(at.x)
		var ring := PackedInt32Array()
		for i in loop.size():
			var out := (outline[i] - face[i]).normalized()
			ring.append(_add(mesh, loop[i], at.y, Vector3(out.x * at.z, out.y * at.z, at.w), uv))
		rings.append(ring)
	for k in profile.size() - 1:
		for i in outline.size():
			var next := (i + 1) % outline.size()
			mesh.quad(rings[k][i], rings[k + 1][i], rings[k + 1][next], rings[k][next])
	_flat(mesh, face, back, Vector3.FORWARD, uv)
	if closed:
		_flat(mesh, face, front, Vector3.BACK, uv)
	return face


## Adds the point [param point] at height [param z], its UV taken from where it lies in [param box].
static func _add(mesh: MeshBuilder, point: Vector2, z: float, normal: Vector3, box: Rect2) -> int:
	var uv := Vector2((point.x - box.position.x) / box.size.x, (box.end.y - point.y) / box.size.y)
	return mesh.add(Vector3(point.x, point.y, z), normal, uv)


## The flat face inside [param loop] (a simple polygon) at height [param z].
static func _flat(mesh: MeshBuilder, loop: PackedVector2Array, z: float, normal: Vector3,
		box: Rect2) -> void:
	var corners := PackedInt32Array()
	for point in loop:
		corners.append(_add(mesh, point, z, normal, box))
	var triangles := Geometry2D.triangulate_polygon(loop)
	for t in range(0, triangles.size(), 3):
		mesh.triangle(corners[triangles[t]], corners[triangles[t + 1]], corners[triangles[t + 2]])


## The wall along (counter-clockwise) [param loop] from [param low] to [param high], facing out.
static func _wall(mesh: MeshBuilder, loop: PackedVector2Array, low: float, high: float,
		box: Rect2) -> void:
	for i in loop.size():
		var next := (i + 1) % loop.size()
		var out := (loop[next] - loop[i]).orthogonal().normalized()
		var normal := Vector3(out.x, out.y, 0.0)
		mesh.quad(_add(mesh, loop[i], low, normal, box), _add(mesh, loop[next], low, normal, box),
			_add(mesh, loop[next], high, normal, box), _add(mesh, loop[i], high, normal, box))


## [param loop] with a point added wherever it crosses the vertical line at [param x].
static func _crossed(loop: PackedVector2Array, x: float) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in loop.size():
		var next := loop[(i + 1) % loop.size()]
		found.append(loop[i])
		if (loop[i].x - x) * (next.x - x) < 0.0:
			found.append(loop[i].lerp(next, (x - loop[i].x) / (next.x - loop[i].x)))
	return found


## The indexes of the lowest and highest points of [param loop] on the vertical line at [param x].
static func _cuts(loop: PackedVector2Array, x: float) -> PackedInt32Array:
	var on := range(loop.size()).filter(func(i: int) -> bool: return is_equal_approx(loop[i].x, x))
	on.sort_custom(func(a: int, b: int) -> bool: return loop[a].y < loop[b].y)
	return PackedInt32Array([on[0], on[-1]])


## The points of [param loop] from index [param from] to [param to], both included, going forwards.
static func _between(loop: PackedVector2Array, from: int, to: int) -> PackedVector2Array:
	var found := PackedVector2Array()
	var i := from
	while i != to:
		found.append(loop[i])
		i = (i + 1) % loop.size()
	found.append(loop[to])
	return found
