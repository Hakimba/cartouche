# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShapeGeometry
extends RefCounted
## The pieces models are built from, as pure functions over a [MeshBuilder]: rounded outlines in the
## XY plane, blocks and slabs swept from them along Z with rounded or rolled edges, prisms, solids
## swept through outlines, flat faces (around holes), recesses and walls, and the checks their
## shapes' rules make. Outlines are counter-clockwise; the same box and corners give the same number
## of points, so that two outlines can be joined point to point.

## From plan (X right, Y towards the back, Z up) to a model's space (Y up, Z towards the front),
## and from a side (X towards the back, Y up, Z out of the right side).
const PLAN := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
const SIDE := Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT)
## From the front's frame to the back's: what is printed or moulded on a back is laid out with the
## mesh turned so ([member MeshBuilder.basis]), seen from behind, X to the right (see [method behind]).
const BEHIND := Basis(Vector3.UP, PI)
const _BEVEL_STEPS := 3
## Shorter than this, in millimetres, a side is none: the corners either side of it share a point.
const _NONE := 0.0001
## How wide a rounded solid's tip or pole is, as a share of its radius: a point would leave its
## last ring no face.
const TIP := 0.005
## How far a logo's face stands over the surface it lies on, in millimetres.
const _DECAL_OFF := 0.05
## A cartridge slot's connector: how high it stands at the slot's foot, the cartridge's edge resting
## on it; the slit along its top that edge goes into, its width and depth, and the housing's ends
## beyond it; its contacts, how many, their pitch, and each one's width and height on the slit's floor.
const CONNECTOR_HEIGHT := 3.0
const _SLIT := Vector2(1.8, 2.0)
const _SLIT_END := 2.0
const _CONTACTS := 32
const _CONTACT_PITCH := 1.5
const _CONTACT := Vector2(0.6, 0.4)


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


## The circle of [param radius] around [param centre] in [param count] points, counter-clockwise.
static func circle(centre: Vector2, radius: float, count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in count:
		points.append(centre + Vector2.from_angle(TAU * i / count) * radius)
	return points


## The rectangle of [param size] centred on [param centre].
static func centred(centre: Vector2, size: Vector2) -> Rect2:
	return Rect2(centre - size / 2.0, size)


## The square around the circle of [param radius] about [param centre].
static func square_around(centre: Vector2, radius: float) -> Rect2:
	return Rect2(centre - Vector2.ONE * radius, Vector2.ONE * 2.0 * radius)


## The outline of the two bars [param across] and [param upright] crossing (a D-pad's),
## counter-clockwise from the bottom right corner of the right arm.
static func cross(across: Rect2, upright: Rect2) -> PackedVector2Array:
	var low := across.position.y
	var high := across.end.y
	var left := upright.position.x
	var right := upright.end.x
	return PackedVector2Array([Vector2(across.end.x, low), Vector2(across.end.x, high), Vector2(right, high),
		Vector2(right, upright.end.y), Vector2(left, upright.end.y), Vector2(left, high),
		Vector2(across.position.x, high), Vector2(across.position.x, low), Vector2(left, low),
		Vector2(left, upright.position.y), Vector2(right, upright.position.y), Vector2(right, low)])


## The smallest box around [param loop].
static func bounds(loop: PackedVector2Array) -> Rect2:
	var box := Rect2(loop[0], Vector2.ZERO)
	for point in loop:
		box = box.expand(point)
	return box


## The [param polygon] (counter-clockwise), each corner rounded by its radius in
## [param radii], convex or reflex, in [param steps] steps; a corner of no radius, or one that does
## not turn (its sides in line), stays the one point.
static func filleted(polygon: PackedVector2Array, radii: PackedFloat32Array, steps: int) -> PackedVector2Array:
	var loop := PackedVector2Array()
	var count := polygon.size()
	for i in count:
		var into := polygon[i] - polygon[i - 1]
		var out_of := polygon[(i + 1) % count] - polygon[i]
		var first := into.orthogonal().normalized()
		var last := out_of.orthogonal().normalized()
		# The arc's centre: inside a convex corner, outside a reflex one.
		var turn := signf(into.cross(out_of))
		if radii[i] < _NONE or turn == 0.0:
			loop.append(polygon[i])
			continue
		var centre := polygon[i] - turn * (first + last) * radii[i] / (1.0 + first.dot(last))
		var sweep := angle_difference(first.angle(), last.angle())
		for step in steps + 1:
			loop.append(centre + turn * Vector2.from_angle(first.angle() + sweep * step / steps) * radii[i])
	return loop


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


## Adds the solid of [param loop] (counter-clockwise, a simple polygon of any corners, its convex
## ones rounder than its bevels) from [param back] to [param front], its edges rounded as
## [method profile] has them, and gives the outline of its front; the front itself is left out
## when [param closed] is false. Each outline along a bevel is the loop moved in along its corners'
## bisectors, so that every one has as many points.
static func slab(mesh: MeshBuilder, loop: PackedVector2Array, back: float, front: float, bevels: Vector2,
		uv: Rect2, closed := true) -> PackedVector2Array:
	var outwards := _outwards(loop)
	var rings: Array[PackedInt32Array] = []
	var outlines: Array[PackedVector2Array] = []
	for at in profile(back, front, bevels):
		var ring := PackedInt32Array()
		var outline := PackedVector2Array()
		for i in loop.size():
			outline.append(loop[i] - outwards[i] * at.x)
			var out := outwards[i].normalized() * at.z
			ring.append(add(mesh, outline[i], at.y, Vector3(out.x, out.y, at.w), uv))
		rings.append(ring)
		outlines.append(outline)
	join(mesh, rings)
	flat(mesh, outlines[0], back, Vector3.FORWARD, uv)
	if closed:
		flat(mesh, outlines[-1], front, Vector3.BACK, uv)
	return outlines[-1]


## Adds the solid of [param box], its corners rounded by [param corner] seen from the front, from
## [param low] to [param high], its edges at [param high] rolled round towards its face, each by
## its own radius: the sides' [param rolls].x, the bottom's .y and the top's .z; and gives the
## outline of the face, at [param high], left to the caller (a face with holes). Each outline round
## the rolls lies at one height, each edge set in as far as its own roll has turned there, so that
## none twists however different the rolls; each gets a point where it crosses the vertical line at
## [param cut], as the face's does. A [param hole] (inside the face, crossed by that line) goes
## through the solid, its walls square.
static func rolled(mesh: MeshBuilder, box: Rect2, corner: float, low: float, high: float, rolls: Vector3,
		steps: int, uv: Rect2, cut := NAN, hole := PackedVector2Array()) -> PackedVector2Array:
	var largest := maxf(maxf(rolls.x, rolls.y), rolls.z)
	var levels := PackedFloat32Array([low])
	for k in _BEVEL_STEPS + 1:
		levels.append(high - largest * (1.0 - sin(PI / 2.0 * k / _BEVEL_STEPS)))
	var rings: Array[PackedInt32Array] = []
	var base := rounded_box(box, corner, steps, cut)
	var loop := base
	for z in levels:
		var side := _turned(rolls.x, high - z)
		var bottom := _turned(rolls.y, high - z)
		var top := _turned(rolls.z, high - z)
		var shrunk := Rect2(box.position + Vector2(side.x, bottom.x), box.size - Vector2(2.0 * side.x, bottom.x + top.x))
		loop = rounded_box(shrunk, corner, steps, cut)
		var centres := shrunk.grow(-corner)
		var ring := PackedInt32Array()
		for point in loop:
			# Out of its corner's arc, or square to its side; turned up as far as its edges' rolls.
			var out := (point - point.clamp(centres.position, centres.end)).normalized()
			var ends := top if out.y > 0.0 else bottom
			var normal := Vector3(out.x * cos(side.y), out.y * cos(ends.y),
				absf(out.x) * sin(side.y) + absf(out.y) * sin(ends.y))
			ring.append(add(mesh, point, z, normal, uv))
		rings.append(ring)
	join(mesh, rings)
	if hole.is_empty():
		flat(mesh, base, low, Vector3.FORWARD, uv)
		return loop
	holed(mesh, base, [hole], low, Vector3.FORWARD, uv, PackedFloat32Array([cut]))
	sunk(mesh, hole, low, high, uv, false)
	return loop


## Adds the square-edged solid of [param loop] (a simple polygon, counter-clockwise) from
## [param low] to [param high], its UV taken from where it lies in [param uv], by default its own
## bounds.
static func prism(mesh: MeshBuilder, loop: PackedVector2Array, low: float, high: float, uv := Rect2()) -> void:
	if not uv.has_area():
		uv = bounds(loop)
	wall(mesh, loop, low, high, uv)
	flat(mesh, loop, low, Vector3.FORWARD, uv)
	flat(mesh, loop, high, Vector3.BACK, uv)


## Adds a box on the face at Z [param face] (in a model's space, facing out the way its sign
## points) for each of [param boxes], its centre's X and Y, its width and its height: from
## [param depths].x into the face to [param depths].y out of it.
static func boxes_on(mesh: MeshBuilder, boxes: Array, face: float, depths: Vector2) -> void:
	var z := Vector2.ONE * face + depths * signf(face)
	for box: Vector4 in boxes:
		prism(mesh, square(centred(Vector2(box.x, box.y), Vector2(box.z, box.w))), minf(z.x, z.y), maxf(z.x, z.y))


## Adds the housing of a cartridge slot's connector, laid out in plan (see [constant PLAN]): the box
## [param box] from [param low] up to [param high], the slit its contacts are in along the middle of
## its top, closed at both ends (see [method contacts]).
static func connector(mesh: MeshBuilder, box: Rect2, low: float, high: float) -> void:
	var slit := _slit(box)
	var bottom := high - _SLIT.y
	prism(mesh, square(box), low, bottom)
	for lip: Rect2 in [Rect2(box.position, Vector2(box.size.x, slit.position.y - box.position.y)),
			Rect2(box.position.x, slit.end.y, box.size.x, box.end.y - slit.end.y),
			Rect2(box.position.x, slit.position.y, _SLIT_END, slit.size.y),
			Rect2(slit.end.x, slit.position.y, _SLIT_END, slit.size.y)]:
		prism(mesh, square(lip), bottom, high)


## Adds the contacts on the floor of the slit of the connector [param box] whose top is at
## [param high] (see [method connector]), across it and evenly spaced along it.
static func contacts(mesh: MeshBuilder, box: Rect2, high: float) -> void:
	var slit := _slit(box)
	var bottom := high - _SLIT.y
	for i in _CONTACTS:
		var x := slit.get_center().x + (i - (_CONTACTS - 1) / 2.0) * _CONTACT_PITCH
		prism(mesh, square(Rect2(x - _CONTACT.x / 2.0, slit.position.y, _CONTACT.x, slit.size.y)), bottom,
			bottom + _CONTACT.y)


## Whether a connector fits the box [param box]: its slit and contacts along the middle, lips on
## either side.
static func holds_connector(box: Rect2) -> bool:
	return box.size.x > _CONTACTS * _CONTACT_PITCH + 2.0 * _SLIT_END and box.size.y > _SLIT.x + 0.8


## Adds the solid of [param loop] (a simple polygon, counter-clockwise) standing from [param low]
## up to a plane roof, its height at each point of [param loop] in [param roof]: square walls.
static func wedge(mesh: MeshBuilder, loop: PackedVector2Array, low: float, roof: PackedFloat32Array,
		uv: Rect2) -> void:
	flat(mesh, loop, low, Vector3.FORWARD, uv)
	var ring := PackedVector3Array()
	for i in loop.size():
		ring.append(Vector3(loop[i].x, loop[i].y, roof[i]))
	_cap(mesh, ring, 1.0, uv)
	wall(mesh, loop, low, 0.0, uv, roof)


## [param box], on a back as seen from the front, as seen from behind (see [constant BEHIND]):
## mirrored across.
static func behind(box: Rect2) -> Rect2:
	return Rect2(-box.end.x, box.position.y, box.size.x, box.size.y)


## Adds the face a logo is drawn on: [param box], laid a hair over the surface at height [param z]
## so as not to flicker with it, its UV square the logo's image, upright (see ONBOARDING, "Adding a
## console": a logo).
static func decal(mesh: MeshBuilder, box: Rect2, z: float) -> void:
	flat(mesh, square(box), z + _DECAL_OFF, Vector3.BACK, box)


## Adds the solid swept through [param rings] (outlines of as many points, counter-clockwise seen
## along Z, from the back to the front), each point's normal turned out along its outline and
## across to the next. Without a [param hole], the first and the last close it, plane, level or
## leaning; with one (an outline of as many points, inside them all, the first and the last level),
## it goes through the solid, its walls square. The quads [param gap] spans are left open (see
## [method join]).
static func swept(mesh: MeshBuilder, rings: Array[PackedVector3Array], uv: Rect2,
		hole := PackedVector2Array(), gap := Rect2i()) -> void:
	joined(mesh, rings, uv, gap)
	if hole.is_empty():
		_cap(mesh, rings[0], -1.0, uv)
		_cap(mesh, rings[-1], 1.0, uv)
		return
	var low := rings[0][0].z
	var high := rings[-1][0].z
	band(mesh, plan(rings[0]), hole, low, Vector3.FORWARD, uv)
	band(mesh, plan(rings[-1]), hole, high, Vector3.BACK, uv)
	sunk(mesh, hole, low, high, uv, false)


## Adds each of [param rings] (as many points each), each point's normal turned out along its ring
## and across to the next, and joins each ring to the next, but for the quads [param gap] spans (see
## [method join]).
static func joined(mesh: MeshBuilder, rings: Array[PackedVector3Array], uv: Rect2, gap := Rect2i()) -> void:
	var indices: Array[PackedInt32Array] = []
	for k in rings.size():
		var ring := PackedInt32Array()
		var count := rings[k].size()
		for i in count:
			var along := rings[k][(i + 1) % count] - rings[k][i - 1]
			var across := rings[mini(k + 1, rings.size() - 1)][i] - rings[maxi(k - 1, 0)][i]
			var point := rings[k][i]
			ring.append(add(mesh, Vector2(point.x, point.y), point.z, along.cross(across).normalized(), uv))
		indices.append(ring)
	join(mesh, indices, gap)


## Whether the rectangle [param inner], its corners rounded by [param rounding], lies within
## [param outer], its bottom corners rounded by [param corners].x and its top ones by
## [param corners].y. Impossible dimensions can turn either inside out: then it does not.
static func fits(inner: Rect2, rounding: float, outer: Rect2, corners: Vector2) -> bool:
	if minf(inner.size.x, inner.size.y) <= 0.0 or minf(outer.size.x, outer.size.y) <= 0.0 \
			or not outer.grow(_NONE).encloses(inner):
		return false
	for quarter in 4:
		var corner := corners.y if quarter < 2 else corners.x
		var side := Vector2(1.0 if quarter in [0, 3] else -1.0, 1.0 if quarter < 2 else -1.0)
		var outer_centre := outer.get_center() + side * (outer.size / 2.0 - Vector2.ONE * corner)
		var inner_centre := inner.get_center() + side * (inner.size / 2.0 - Vector2.ONE * rounding)
		var beyond := (inner_centre - outer_centre) * side
		if beyond.x > 0.0 and beyond.y > 0.0 and beyond.length() + rounding > corner + _NONE:
			return false
	return true


## Whether [param inner] lies within [param outer], both with an area: a box turned inside out holds
## nothing (Rect2 cannot tell, and complains).
static func within(inner: Rect2, outer: Rect2) -> bool:
	return inner.has_area() and outer.has_area() and outer.encloses(inner)


## Whether [param one] and [param other], both with an area, overlap.
static func overlap(one: Rect2, other: Rect2) -> bool:
	return one.has_area() and other.has_area() and one.intersects(other)


## Whether every point of [param points] lies inside [param loop].
static func inside(points: PackedVector2Array, loop: PackedVector2Array) -> bool:
	return Array(points).all(func(point: Vector2) -> bool: return Geometry2D.is_point_in_polygon(point, loop))


## Whether each of [param boxes] has an area and lies within [param area], none of them nearer
## another than [param gap]. An area turned inside out holds none (Rect2 cannot tell).
static func apart(boxes: Array[Rect2], area: Rect2, gap := 0.0) -> bool:
	if not area.has_area() or not boxes.all(func(box: Rect2) -> bool: return box.has_area() and area.encloses(box)):
		return false
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if boxes[i].grow(gap / 2.0).intersects(boxes[j].grow(gap / 2.0)):
				return false
	return true


## [param built] moved by [param at]: its points, and its normals and tangents turned with them.
static func moved(built: Array, at: Transform3D) -> Array:
	var points: PackedVector3Array = built[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = built[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = built[Mesh.ARRAY_TANGENT]
	built[Mesh.ARRAY_VERTEX] = at * points
	built[Mesh.ARRAY_NORMAL] = Transform3D(at.basis, Vector3.ZERO) * normals
	for i in points.size():
		var tangent := at.basis * Vector3(tangents[4 * i], tangents[4 * i + 1], tangents[4 * i + 2])
		tangents[4 * i] = tangent.x
		tangents[4 * i + 1] = tangent.y
		tangents[4 * i + 2] = tangent.z
	built[Mesh.ARRAY_TANGENT] = tangents
	return built


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


## [param loop] with a point added wherever it crosses the vertical line at [param x]; with an
## [param inset], wherever the loop moved that far in ([method moved_in], as [method slab] moves it
## along its bevels) crosses the line, set out from there square to its side, so that the moved loop
## has its point on the line, even round a corner.
static func crossed(loop: PackedVector2Array, x: float, inset := 0.0) -> PackedVector2Array:
	var on := moved_in(loop, inset) if inset > 0.0 else loop
	var found := PackedVector2Array()
	for i in loop.size():
		var next := (i + 1) % loop.size()
		found.append(loop[i])
		if (on[i].x - x) * (on[next].x - x) < 0.0:
			# Exactly on the line, as cuts() finds it: Vector2's lerp, in single precision, lands beside it.
			var at := Vector2(x, lerpf(on[i].y, on[next].y, (x - on[i].x) / (on[next].x - on[i].x)))
			found.append(at + (loop[next] - loop[i]).orthogonal().normalized() * inset)
	return found


## [param loop] (counter-clockwise) moved [param by] in along its corners' bisectors, its sides each
## that far from where they were, as [method slab] moves it along its bevels.
static func moved_in(loop: PackedVector2Array, by: float) -> PackedVector2Array:
	var found := PackedVector2Array()
	var outwards := _outwards(loop)
	for i in loop.size():
		found.append(loop[i] - outwards[i] * by)
	return found


## How far each point of [param loop] moves out along its corner's bisector for its sides to move
## out by one.
static func _outwards(loop: PackedVector2Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in loop.size():
		var before := (loop[i] - loop[i - 1]).orthogonal().normalized()
		var after := (loop[(i + 1) % loop.size()] - loop[i]).orthogonal().normalized()
		var out := (before + after).normalized()
		found.append(out / out.dot(before))
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


## Adds the plane face inside [param ring], turned along Z as the sign of [param towards]; the ring
## leans less than upright, its plan an outline with an area.
static func _cap(mesh: MeshBuilder, ring: PackedVector3Array, towards: float, uv: Rect2) -> void:
	# Its normal by Newell's method, however it leans.
	var normal := Vector3.ZERO
	for i in ring.size():
		var next := ring[(i + 1) % ring.size()]
		normal += Vector3((ring[i].y - next.y) * (ring[i].z + next.z), (ring[i].z - next.z) * (ring[i].x + next.x),
			(ring[i].x - next.x) * (ring[i].y + next.y))
	assert(not is_zero_approx(normal.z), "ShapeGeometry: an upright face has no side along Z")
	laid(mesh, ring, normal.normalized() * signf(normal.z) * towards, uv)


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


## How far an edge rolled by [param roll] is set in at [param drop] below the face, and the angle
## its roll has turned through there: none above its start.
static func _turned(roll: float, drop: float) -> Vector2:
	if drop >= roll:
		return Vector2.ZERO
	var angle := asin((roll - drop) / roll)
	return Vector2(roll * (1.0 - cos(angle)), angle)


static func _slit(box: Rect2) -> Rect2:
	return Rect2(box.position.x + _SLIT_END, box.get_center().y - _SLIT.x / 2.0, box.size.x - 2.0 * _SLIT_END,
		_SLIT.x)
