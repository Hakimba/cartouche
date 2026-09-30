# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShapeGeometry
extends RefCounted
## The pieces models are built from, as pure functions over a [MeshBuilder]: rounded outlines in the
## XY plane, blocks swept from them along Z with rounded edges, flat faces and walls. Outlines are
## counter-clockwise; the same box and corners give the same number of points, so that two outlines
## can be joined point to point.

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


## The rectangle [param box] rounded by [param corner] at each corner, with a point wherever it
## crosses the vertical line at [param cut] (see [method crossed]).
static func rounded_box(box: Rect2, corner: float, steps: int, cut := NAN) -> PackedVector2Array:
	return crossed(rounded(box, corner, corner, steps), cut)


## The steps of each rounded corner for [param detail] (8 for 128); 3 at least, so that the corners'
## sides stay within a tenth of a millimetre of their arcs.
static func corner_steps(detail: int) -> int:
	return maxi(3, floori(detail / 16.0))


## Adds the block of the rectangle [param box], its bottom corners rounded by [param corners].x
## and its top ones by [param corners].y, from [param back] to [param front], its edges rounded by
## [param bevel], and gives the outline of its front; the front itself is left out when
## [param closed] is false. Each outline along the bevels is the box shrunk, its corners with it,
## so that none folds; they all get a point where they cross the vertical line at [param cut].
## A [param hole] (an outline with as many points as the front's, inside it) goes through the
## block, its walls square.
static func block(mesh: MeshBuilder, box: Rect2, corners: Vector2, steps: int, back: float,
		front: float, bevel: float, uv: Rect2, cut := NAN, closed := true,
		hole := PackedVector2Array()) -> PackedVector2Array:
	var shrunk := func(by: float) -> PackedVector2Array:
		return crossed(rounded(box.grow(-by), corners.x - by, corners.y - by, steps), cut)
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
			ring.append(add(mesh, loop[i], at.y, Vector3(out.x * at.z, out.y * at.z, at.w), uv))
		rings.append(ring)
	for k in profile.size() - 1:
		for i in outline.size():
			var next := (i + 1) % outline.size()
			mesh.quad(rings[k][i], rings[k + 1][i], rings[k + 1][next], rings[k][next])
	if hole.is_empty():
		flat(mesh, face, back, Vector3.FORWARD, uv)
		if closed:
			flat(mesh, face, front, Vector3.BACK, uv)
		return face
	band(mesh, face, hole, back, Vector3.FORWARD, uv)
	band(mesh, face, hole, front, Vector3.BACK, uv)
	var inwards := hole.duplicate()
	inwards.reverse()
	wall(mesh, inwards, back, front, uv)
	return face


## Adds the point [param point] at height [param z], its UV taken from where it lies in [param box].
static func add(mesh: MeshBuilder, point: Vector2, z: float, normal: Vector3, box: Rect2) -> int:
	var uv := Vector2((point.x - box.position.x) / box.size.x, (box.end.y - point.y) / box.size.y)
	return mesh.add(Vector3(point.x, point.y, z), normal, uv)


## The flat face inside [param loop] (a simple polygon) at height [param z].
static func flat(mesh: MeshBuilder, loop: PackedVector2Array, z: float, normal: Vector3,
		box: Rect2) -> void:
	var corners := PackedInt32Array()
	for point in loop:
		corners.append(add(mesh, point, z, normal, box))
	var triangles := Geometry2D.triangulate_polygon(loop)
	for t in range(0, triangles.size(), 3):
		mesh.triangle(corners[triangles[t]], corners[triangles[t + 1]], corners[triangles[t + 2]])


## The flat face between [param outer] and [param inner], two outlines of as many points, at
## height [param z].
static func band(mesh: MeshBuilder, outer: PackedVector2Array, inner: PackedVector2Array, z: float,
		normal: Vector3, box: Rect2) -> void:
	for i in outer.size():
		var next := (i + 1) % outer.size()
		mesh.quad(add(mesh, outer[i], z, normal, box), add(mesh, outer[next], z, normal, box),
			add(mesh, inner[next], z, normal, box), add(mesh, inner[i], z, normal, box))


## The wall along (counter-clockwise) [param loop] from [param low] to [param high], facing out.
static func wall(mesh: MeshBuilder, loop: PackedVector2Array, low: float, high: float,
		box: Rect2) -> void:
	for i in loop.size():
		var next := (i + 1) % loop.size()
		var out := (loop[next] - loop[i]).orthogonal().normalized()
		var normal := Vector3(out.x, out.y, 0.0)
		mesh.quad(add(mesh, loop[i], low, normal, box), add(mesh, loop[next], low, normal, box),
			add(mesh, loop[next], high, normal, box), add(mesh, loop[i], high, normal, box))


## [param loop] with a point added wherever it crosses the vertical line at [param x].
static func crossed(loop: PackedVector2Array, x: float) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in loop.size():
		var next := loop[(i + 1) % loop.size()]
		found.append(loop[i])
		if (loop[i].x - x) * (next.x - x) < 0.0:
			found.append(loop[i].lerp(next, (x - loop[i].x) / (next.x - loop[i].x)))
	return found


## The indexes of the lowest and highest points of [param loop] on the vertical line at [param x].
static func cuts(loop: PackedVector2Array, x: float) -> PackedInt32Array:
	var on := range(loop.size()).filter(func(i: int) -> bool: return is_equal_approx(loop[i].x, x))
	on.sort_custom(func(a: int, b: int) -> bool: return loop[a].y < loop[b].y)
	return PackedInt32Array([on[0], on[-1]])


## The points of [param loop] from index [param from] to [param to], both included, going forwards.
static func between(loop: PackedVector2Array, from: int, to: int) -> PackedVector2Array:
	var found := PackedVector2Array()
	var i := from
	while i != to:
		found.append(loop[i])
		i = (i + 1) % loop.size()
	found.append(loop[to])
	return found
