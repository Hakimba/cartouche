# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShapeGeometry
extends RefCounted
## The pieces models are built from, as pure functions over a [MeshBuilder]: rounded outlines in the
## XY plane, blocks swept from them along Z with rounded edges, prisms, flat faces (around holes),
## recesses and walls, and the check their shapes' rules make. Outlines are counter-clockwise; the same
## box and corners give the same number of points, so that two outlines can be joined point to point.

const _BEVEL_STEPS := 3
## Shorter than this, in millimetres, a side is none: the corners either side of it share a point.
const _NONE := 0.0001


## A rounded rectangle, counter-clockwise, its bottom corners of radius [param bottom], its top
## ones of [param top], each in [param steps] steps. Corners as round as the box is wide or high
## meet in one point: a pill, a circle.
static func rounded(box: Rect2, bottom: float, top: float, steps: int) -> PackedVector2Array:
	# The straight side before each corner, from the right one up to the top right corner on.
	var sides: Array[float] = [box.size.y - bottom - top, box.size.x - 2.0 * top, box.size.y - bottom - top,
		box.size.x - 2.0 * bottom]
	var points := PackedVector2Array()
	for quarter in 4:
		var radius := top if quarter < 2 else bottom
		var x := box.end.x - radius if quarter in [0, 3] else box.position.x + radius
		var y := box.end.y - radius if quarter < 2 else box.position.y + radius
		for step in steps + 1:
			if (step == 0 and sides[quarter] < _NONE) or (step > 0 and radius < _NONE):
				continue
			var angle := deg_to_rad(quarter * 90.0 + 90.0 * step / steps)
			points.append(Vector2(x, y) + Vector2.from_angle(angle) * radius)
	return points


## The outline of [param box], its corners square: counter-clockwise from its bottom left.
static func square(box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end,
		Vector2(box.position.x, box.end.y)])


static func bounds(loop: PackedVector2Array) -> Rect2:
	var box := Rect2(loop[0], Vector2.ZERO)
	for point in loop:
		box = box.expand(point)
	return box


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
## [param bevel] (positive, see [method rounded_sides]), and gives the outline of its front; the
## front itself is left out when [param closed] is false. Each outline along the bevels is the box shrunk, its corners with it,
## so that none folds; they all get a point where they cross the vertical line at [param cut].
## A [param hole] (an outline with as many points as the front's, inside it) goes through the
## block, its walls square.
static func block(mesh: MeshBuilder, box: Rect2, corners: Vector2, steps: int, back: float,
		front: float, bevel: float, uv: Rect2, cut := NAN, closed := true,
		hole := PackedVector2Array()) -> PackedVector2Array:
	var shrunk := func(by: float) -> PackedVector2Array:
		return crossed(rounded(box.grow(-by), corners.x - by, corners.y - by, steps), cut)
	var face := rounded_sides(mesh, shrunk, back, front, bevel, uv)
	if hole.is_empty():
		flat(mesh, face, back, Vector3.FORWARD, uv)
		if closed:
			flat(mesh, face, front, Vector3.BACK, uv)
		return face
	band(mesh, face, hole, back, Vector3.FORWARD, uv)
	band(mesh, face, hole, front, Vector3.BACK, uv)
	sunk(mesh, hole, back, front, uv, false)
	return face


## Adds the sides of a solid from [param back] to [param front], its edges rounded by [param bevel]
## (see [method profile]), each outline along them [param outline] shrunk by how far in it is (an
## outline of as many points for any), and gives the outline of its ends. The [param bevel] must
## be positive, its outlines rounder than it: each point's normal is turned out of the side from
## the outline it is shrunk to, and those never fold.
static func rounded_sides(mesh: MeshBuilder, outline: Callable, back: float, front: float, bevel: float,
		uv: Rect2) -> PackedVector2Array:
	assert(bevel > 0.0, "ShapeGeometry: square edges have no normals out of a shrunk outline")
	var edges := profile(back, front, Vector2.ONE * bevel)
	var whole: PackedVector2Array = outline.call(0.0)
	# Shrunk as the outlines round it are, in single precision: else a point of the face may stand a
	# hair beside its edge's, and leave the solid open.
	var face: PackedVector2Array = outline.call(edges[0].x)
	var rings: Array[PackedInt32Array] = []
	for at in edges:
		var loop: PackedVector2Array = outline.call(at.x)
		var ring := PackedInt32Array()
		for i in loop.size():
			var out := (whole[i] - face[i]).normalized()
			ring.append(add(mesh, loop[i], at.y, Vector3(out.x * at.z, out.y * at.z, at.w), uv))
		rings.append(ring)
	join(mesh, rings)
	return face


## The outlines a solid's rounded edges go through, from [param back] to [param front], those at the
## back rounded by [param bevels].x and at the front by [param bevels].y: each how far in it is, its
## height, and its normal's share out of the side and along Z (in single precision: a face's outline
## is shrunk by its first's). A square end (no bevel) is the one
## outline, its normal out of the side.
static func profile(back: float, front: float, bevels: Vector2) -> Array[Vector4]:
	var found: Array[Vector4] = []
	for end in 2:
		var bevel := bevels[end]
		var steps := _BEVEL_STEPS if bevel > 0.0 else 0
		for step in steps + 1:
			var angle := PI / 2.0 * step / _BEVEL_STEPS
			var sweep := bevel * (1.0 - cos(angle))
			var drop := bevel * (1.0 - sin(angle))
			if end == 0:
				found.push_front(Vector4(sweep, back + drop, cos(angle), -sin(angle)))
			else:
				found.append(Vector4(sweep, front - drop, cos(angle), sin(angle)))
	return found


## Adds the square-edged solid of [param loop] (a simple polygon, counter-clockwise) from
## [param low] to [param high], its UV taken from where it lies in [param uv], by default its own
## bounds.
static func prism(mesh: MeshBuilder, loop: PackedVector2Array, low: float, high: float, uv := Rect2()) -> void:
	if not uv.has_area():
		uv = bounds(loop)
	wall(mesh, loop, low, high, uv)
	flat(mesh, loop, low, Vector3.FORWARD, uv)
	flat(mesh, loop, high, Vector3.BACK, uv)


## Whether [param inner] lies within [param outer], both with an area: a box turned inside out holds
## nothing (Rect2 cannot tell, and complains).
static func within(inner: Rect2, outer: Rect2) -> bool:
	return inner.has_area() and outer.has_area() and outer.encloses(inner)


## Joins each of [param rings] (as many points each) to the next, but for the quads [param gap]
## spans: from point gap.position.x of ring gap.position.y, gap.size.x points along and gap.size.y
## rings across, an opening the caller closes.
static func join(mesh: MeshBuilder, rings: Array[PackedInt32Array], gap := Rect2i()) -> void:
	for k in rings.size() - 1:
		for i in rings[k].size():
			if gap.has_point(Vector2i(i, k)):
				continue
			var next := (i + 1) % rings[k].size()
			mesh.quad(rings[k][i], rings[k + 1][i], rings[k + 1][next], rings[k][next])


## Adds the point [param point] at height [param z], its UV taken from where it lies in [param box].
static func add(mesh: MeshBuilder, point: Vector2, z: float, normal: Vector3, box: Rect2) -> int:
	var uv := Vector2((point.x - box.position.x) / box.size.x, (box.end.y - point.y) / box.size.y)
	return mesh.add(Vector3(point.x, point.y, z), normal, uv)


## The flat face inside [param loop] (a simple polygon) at height [param z].
static func flat(mesh: MeshBuilder, loop: PackedVector2Array, z: float, normal: Vector3,
		box: Rect2) -> void:
	var ring := PackedVector3Array()
	for point in loop:
		ring.append(Vector3(point.x, point.y, z))
	laid(mesh, ring, normal, box)


## The face inside [param ring], a simple polygon in plan, each point at its own height, turned
## towards [param normal]: plane, or laid on a curved surface.
static func laid(mesh: MeshBuilder, ring: PackedVector3Array, normal: Vector3, box: Rect2) -> void:
	var outline := plan(ring)
	var corners := PackedInt32Array()
	for i in ring.size():
		corners.append(add(mesh, outline[i], ring[i].z, normal, box))
	var triangles := Geometry2D.triangulate_polygon(outline)
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


## The flat face inside [param outline] at height [param z], turned towards [param normal], around
## [param holes] (inside it, apart), laid in pieces between the vertical [param lines] (ascending):
## each hole crossed by one of them, and it and the outline given a point wherever a line crosses
## them (see [method crossed]), the outline crossed twice by each.
static func holed(mesh: MeshBuilder, outline: PackedVector2Array, holes: Array[PackedVector2Array], z: float,
		normal: Vector3, uv: Rect2, lines: PackedFloat32Array) -> void:
	var last := lines.size()
	for k in last + 1:
		var left := cuts(outline, lines[k - 1]) if k > 0 else PackedInt32Array()
		var right := cuts(outline, lines[k]) if k < last else PackedInt32Array()
		var piece: PackedVector2Array
		if k == 0:
			piece = between(outline, right[1], right[0])
		elif k == last:
			piece = between(outline, left[0], left[1])
		else:
			piece = between(outline, left[0], right[0])
		if k < last:
			# Up the line on the right, round the left halves of its holes.
			piece.append_array(_halves(holes, lines[k], 1.0))
		if 0 < k and k < last:
			piece.append_array(between(outline, right[1], left[1]))
		if k > 0:
			piece.append_array(_halves(holes, lines[k - 1], -1.0))
		flat(mesh, piece, z, normal, uv)


## Adds the recess of [param hole] (counter-clockwise), cut in a face at [param top]: its walls,
## facing in, down to [param bottom], and its floor unless [param floored] is false.
static func sunk(mesh: MeshBuilder, hole: PackedVector2Array, bottom: float, top: float, uv: Rect2,
		floored := true) -> void:
	var inwards := hole.duplicate()
	inwards.reverse()
	wall(mesh, inwards, bottom, top, uv)
	if floored:
		flat(mesh, hole, bottom, Vector3.BACK, uv)


## The wall along (counter-clockwise) [param loop] from [param low] to [param high], or to each
## point's height in [param roof] when given, facing out.
static func wall(mesh: MeshBuilder, loop: PackedVector2Array, low: float, high: float,
		box: Rect2, roof := PackedFloat32Array()) -> void:
	for i in loop.size():
		var next := (i + 1) % loop.size()
		var out := (loop[next] - loop[i]).orthogonal().normalized()
		var normal := Vector3(out.x, out.y, 0.0)
		mesh.quad(add(mesh, loop[i], low, normal, box), add(mesh, loop[next], low, normal, box),
			add(mesh, loop[next], high if roof.is_empty() else roof[next], normal, box),
			add(mesh, loop[i], high if roof.is_empty() else roof[i], normal, box))


## [param loop] with a point added wherever it crosses the vertical line at [param x].
static func crossed(loop: PackedVector2Array, x: float) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in loop.size():
		var next := (i + 1) % loop.size()
		found.append(loop[i])
		if (loop[i].x - x) * (loop[next].x - x) < 0.0:
			# Exactly on the line, as cuts() finds it: Vector2's lerp, in single precision, lands beside it.
			found.append(Vector2(x, lerpf(loop[i].y, loop[next].y, (x - loop[i].x) / (loop[next].x - loop[i].x))))
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


static func plan(ring: PackedVector3Array) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for point in ring:
		outline.append(Vector2(point.x, point.y))
	return outline


## The halves of the holes the vertical line at [param x] crosses, beside it on the left going up
## when [param upwards] is positive, on the right going down otherwise.
static func _halves(holes: Array[PackedVector2Array], x: float, upwards: float) -> PackedVector2Array:
	var crossing: Array[PackedVector2Array] = []
	crossing.assign(holes.filter(func(hole: PackedVector2Array) -> bool:
		var box := bounds(hole)
		return box.position.x < x and x < box.end.x))
	crossing.sort_custom(func(a: PackedVector2Array, b: PackedVector2Array) -> bool:
		return (bounds(a).position.y - bounds(b).position.y) * upwards < 0.0)
	var found := PackedVector2Array()
	for hole in crossing:
		var ends := cuts(hole, x)
		# Between its ends counter-clockwise: round its right half from the bottom, its left one from the top.
		var half := between(hole, ends[0], ends[1]) if upwards < 0.0 else between(hole, ends[1], ends[0])
		half.reverse()
		found.append_array(half)
	return found

