# SPDX-License-Identifier: GPL-3.0-or-later
class_name N64CartGeometry
extends RefCounted
## Builds a Nintendo 64 Game Pak from its [N64CartShape] as pure functions, so that tests check the
## geometry headless. Each layer is the outline, or the outline cut where the layer is not, swept
## along Z into the layer under it; on the core's front, the band and the two wings either side of
## it, their edges rolled round, the grooves between them down to the core; the label's recess sunk
## in the band's face, the label lying on its floor. The grooves go on as notches cut in the layers'
## tops and as slits through the back's, each lined in the dark its narrow depth shows. What is
## printed or moulded on the back is a thin plate of its own, laid out turned round so that it reads
## the right way from behind.

const PARTS: Array[StringName] = [&"label", &"shell", &"grooves", &"screws", &"sticker", &"lettering",
	&"contacts"]
## The straight pieces of every arched top, whatever the detail, and of a wing's: a corner's rounding
## then fits on the piece next to it at any detail.
const ARCS := 8
const WING_ARCS := 2
## Steps round a rolled edge.
const ROLL_STEPS := 3


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: N64CartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var whole := shape.whole()
	var back := -shape.depth / 2.0
	var face := shape.face()
	match part:
		&"label":
			var label := _arched(shape.label_box(), shape.label_arch, shape.label_corners, steps)
			ShapeGeometry.prism(mesh, label, face - N64CartShape.OVERLAP, face + N64CartShape.LABEL_THICKNESS,
				shape.label_box())
		&"screws":
			for side: float in [-1.0, 1.0]:
				var screw := ShapeGeometry.circle(shape.screw_centre * Vector2(side, 1.0), shape.screw_radius,
					2 * steps)
				ShapeGeometry.prism(mesh, screw, back - N64CartShape.SCREW_PROUD, back + N64CartShape.OVERLAP, whole)
		&"sticker":
			mesh.basis = ShapeGeometry.BEHIND
			var seen := ShapeGeometry.behind(shape.sticker_box())
			ShapeGeometry.prism(mesh, ShapeGeometry.rounded_box(seen, shape.sticker_corner, steps),
				-back - N64CartShape.OVERLAP, N64CartShape.STICKER_THICKNESS - back, seen)
		&"lettering":
			mesh.basis = ShapeGeometry.BEHIND
			var seen := ShapeGeometry.behind(shape.lettering_box())
			ShapeGeometry.prism(mesh, ShapeGeometry.square(seen), -back - N64CartShape.OVERLAP,
				N64CartShape.LETTERING_PROUD - back, seen)
		&"contacts":
			var bottom := -shape.height / 2.0
			var board := Rect2(-shape.contacts_width / 2.0, bottom + N64CartShape.CONTACT_INSET, shape.contacts_width,
				shape.slot_depth - N64CartShape.CONTACT_INSET + N64CartShape.OVERLAP)
			ShapeGeometry.prism(mesh, ShapeGeometry.square(board), -N64CartShape.BOARD / 2.0,
				N64CartShape.BOARD / 2.0, whole)
		&"shell":
			_shell(mesh, shape, steps)
		&"grooves":
			_linings(mesh, shape)
	return mesh.arrays()


## The outline, its edges [param inset] inside the outline's; its top notched by [param notches]
## (each its middle's X and how far its floor is under the top's middle).
static func outline(shape: N64CartShape, steps: int, inset := 0.0,
		notches := PackedVector2Array()) -> PackedVector2Array:
	var box := shape.whole().grow(-inset)
	var corners := Vector2(shape.bottom_corner, shape.top_corner) - Vector2.ONE * inset
	return _rounded_top(box, shape.arch_within(inset, box.size.x / 2.0), corners.y,
		ShapeGeometry.square(box).slice(0, 2), PackedFloat32Array([corners.x, corners.x]), steps,
		_notched(shape, notches), shape.groove / 2.0, shape.mouth())


## The band's outline, from the bottom edge to the top's arc, its edges [param inset] inside it.
static func band(shape: N64CartShape, steps: int, inset := 0.0) -> PackedVector2Array:
	return _arched(shape.band_box().grow(-inset), shape.arch_within(inset, shape.band_width / 2.0 - inset),
		Vector2.ONE * (shape.wing_corner() - inset), steps)


## The label's recess in the band: the label grown by the gap left around it.
static func recess(shape: N64CartShape, steps: int) -> PackedVector2Array:
	return _arched(shape.label_box().grow(N64CartShape.LABEL_GAP), shape.label_arch,
		shape.label_corners + Vector2.ONE * N64CartShape.LABEL_GAP, steps)


## The layers, back to front, each sunk into the one under it, the grooves cut in them.
static func _shell(mesh: MeshBuilder, shape: N64CartShape, steps: int) -> void:
	var whole := shape.whole()
	var back := -shape.depth / 2.0
	var front := shape.depth / 2.0
	var face := shape.face()
	var rails := shape.rails()
	var hollow := back + shape.notch_depth
	var slot := shape.slot_size.y / 2.0
	var at_front := _lines(shape.front_line(), shape.groove_depth)
	var back_layer := _back(shape, steps)
	_rolled(mesh, back_layer, _rolls(shape, back_layer, shape.bevel, shape.back_line(), shape.mouth()),
		hollow + N64CartShape.OVERLAP, back, whole)
	ShapeGeometry.prism(mesh, outline(shape, steps, 0.0, _lines(shape.back_line(), shape.groove_depth)), hollow,
		-slot, whole)
	ShapeGeometry.prism(mesh, _slotted(shape, steps, at_front), -slot, slot, whole)
	var core := outline(shape, steps, 0.0, at_front)
	_rolled(mesh, core, _rolls(shape, core, shape.bevel, shape.front_line(), shape.mouth()), slot, rails, whole)
	# Their square sides cover the core's rounded edge, but at the rails and in the grooves; deep
	# enough for their rolled edges.
	var low := rails - shape.shoulder - N64CartShape.OVERLAP
	var corner := shape.wing_corner()
	for side: float in [-1.0, 1.0]:
		var wing := _wing(shape, steps, side)
		_rolled(mesh, wing, _rolls(shape, wing, shape.shoulder, shape.front_line(), corner), low, face, whole)
	# The band's face cut through the middle, around the label's recess.
	var band_loop := ShapeGeometry.crossed(band(shape, steps), 0.0)
	var top := _rolled(mesh, band_loop, _rolls(shape, band_loop, shape.shoulder, shape.front_line(), corner), low,
		front, whole, false)
	var hole := ShapeGeometry.crossed(recess(shape, steps), 0.0)
	ShapeGeometry.holed(mesh, top, [hole], front, Vector3.BACK, whole, PackedFloat32Array([0.0]))
	ShapeGeometry.sunk(mesh, hole, face, front, whole)
	_rim(mesh, shape, steps)


## The two notches either side of the middle, [param x] from it, their floors [param y] from the top
## (from the right one, as [method _rounded_top] cuts them).
static func _lines(x: float, y: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(-x, y)])


## [param notches] given from the top, set down under the arc: each floor's height.
static func _notched(shape: N64CartShape, notches: PackedVector2Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	for notch in notches:
		found.append(Vector2(notch.x, _top(shape.whole(), shape.arch, notch.x) - notch.y))
	return found


## The radius each point of [param loop] is rolled by: [param roll], down to the grooves' lips
## within [param reach] of the walls of the grooves either side of the middle at [param line].
static func _rolls(shape: N64CartShape, loop: PackedVector2Array, roll: float, line: float,
		reach: float) -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for point in loop:
		var near := absf(absf(point.x) - line) - shape.groove / 2.0
		found.append(lerpf(shape.lip, roll, clampf(near / reach, 0.0, 1.0)))
	return found


## Adds the solid of [param loop] (as [method ShapeGeometry.slab] has it) from its square end at
## [param square] to its face at [param face], each point's edge there rolled round by its own radius
## in [param rolls], and gives the outline of the face, left open when [param closed] is false.
static func _rolled(mesh: MeshBuilder, loop: PackedVector2Array, rolls: PackedFloat32Array, square: float,
		face: float, uv: Rect2, closed := true) -> PackedVector2Array:
	var towards := signf(face - square)
	var outwards := PackedVector2Array()
	var ring := PackedInt32Array()
	for i in loop.size():
		var before := (loop[i] - loop[i - 1]).orthogonal().normalized()
		var after := (loop[(i + 1) % loop.size()] - loop[i]).orthogonal().normalized()
		var out := (before + after).normalized()
		outwards.append(out / out.dot(before))
		ring.append(ShapeGeometry.add(mesh, loop[i], square, Vector3(out.x, out.y, 0.0), uv))
	var rings: Array[PackedInt32Array] = [ring]
	var turned := loop
	for k in ROLL_STEPS + 1:
		var angle := PI / 2.0 * k / ROLL_STEPS
		ring = PackedInt32Array()
		turned = PackedVector2Array()
		for i in loop.size():
			turned.append(loop[i] - outwards[i] * rolls[i] * (1.0 - cos(angle)))
			var out := outwards[i].normalized() * cos(angle)
			ring.append(ShapeGeometry.add(mesh, turned[i], face - towards * rolls[i] * (1.0 - sin(angle)),
				Vector3(out.x, out.y, towards * sin(angle)), uv))
		rings.append(ring)
	ShapeGeometry.join(mesh, rings)
	ShapeGeometry.flat(mesh, loop, square, Vector3(0.0, 0.0, -towards), uv)
	if closed:
		ShapeGeometry.flat(mesh, turned, face, Vector3(0.0, 0.0, towards), uv)
	return turned


## The linings of the grooves, a shade darker than the shell where light reaches less: down the front from the top to the bottom, over the top through
## the front half and through the back one, and down the back from the top to the sticker and from
## the sticker to the bottom.
static func _linings(mesh: MeshBuilder, shape: N64CartShape) -> void:
	var whole := shape.whole()
	var half := shape.groove / 2.0
	var front := shape.depth / 2.0
	var bottom := -shape.height / 2.0
	var slot := shape.slot_size.y / 2.0
	var corner := shape.wing_corner()
	var sticker := shape.sticker_box()
	for side: float in [-1.0, 1.0]:
		var at_front := side * shape.front_line()
		var at_back := side * shape.back_line()
		var top_front := _top(whole, shape.arch, at_front)
		var top_back := _top(whole, shape.arch, at_back)
		mesh.basis = Basis()
		_lining(mesh, at_front, half, shape.rails(), shape.face() - shape.lip, Vector2(bottom, top_front),
			Vector2(bottom + corner, top_front - corner))
		# Over the top, laid out as the front's are: Y along the groove (from the front towards the
		# back), Z out of the face.
		mesh.basis = ShapeGeometry.PLAN
		var along := Vector2(-shape.rails(), slot)
		_lining(mesh, at_front, half, top_front - shape.groove_depth, top_front - shape.lip, along, along)
		along = Vector2(slot, front - shape.lip)
		_lining(mesh, at_back, half, top_back - shape.groove_depth, top_back - shape.lip, along, along)
		# Down the back, turned to face it.
		mesh.basis = Basis.FLIP_Z
		var floor_at := front - shape.groove_depth
		_lining(mesh, at_back, half, floor_at, front - shape.lip, Vector2(sticker.end.y, top_back),
			Vector2(sticker.end.y, top_back - shape.lip))
		_lining(mesh, at_back, half, floor_at, front - shape.lip, Vector2(bottom, sticker.position.y),
			Vector2(bottom, sticker.position.y))
	mesh.basis = Basis()


## Adds the lining of the groove [param half] each side of [param x], laid out along Y in a face
## towards +Z: a slab a hair thick on [param floor_at] from [param ends].x to .y, and one on each
## wall, standing a hair out of it, from the floor up to [param lip] where the walls run straight,
## from [param straight].x to .y.
static func _lining(mesh: MeshBuilder, x: float, half: float, floor_at: float, lip: float, ends: Vector2,
		straight: Vector2) -> void:
	var hair := N64CartShape.LINING
	ShapeGeometry.prism(mesh, ShapeGeometry.square(Rect2(x - half + hair, ends.x, 2.0 * (half - hair),
		ends.y - ends.x)), floor_at, floor_at + hair)
	for wall: float in [x - half, x + half]:
		ShapeGeometry.prism(mesh, ShapeGeometry.square(Rect2(wall - hair, straight.x, 2.0 * hair,
			straight.y - straight.x)), floor_at, lip)


## The wing on the side [param side] (-1 the left, 1 the right): from the side to its groove, under
## the top's arc, stepped down at its foot by the rail.
static func _wing(shape: N64CartShape, steps: int, side: float) -> PackedVector2Array:
	var box := shape.whole()
	var low := box.position
	var inner := -shape.band_width / 2.0 - shape.groove
	var rail := low.x + shape.rail_size.x
	var wing := shape.wing_corner()
	var left := PackedVector2Array([Vector2(inner, low.y)])
	var rounding := PackedFloat32Array([wing])
	for i in WING_ARCS + 1:
		var x := lerpf(inner, low.x, float(i) / WING_ARCS)
		left.append(Vector2(x, _top(box, shape.arch, x)))
		rounding.append(wing if i == 0 else shape.top_corner if i == WING_ARCS else 0.0)
	left.append_array([Vector2(low.x, low.y + shape.rail_size.y + shape.rail_slant),
		Vector2(rail, low.y + shape.rail_size.y), Vector2(rail, low.y)])
	rounding.append_array([wing, N64CartShape.RAIL_CORNER, wing])
	if side < 0.0:
		return ShapeGeometry.filleted(left, rounding, steps)
	# Mirrored, and turned back counter-clockwise.
	var right := PackedVector2Array()
	var radii := PackedFloat32Array()
	for i in range(left.size() - 1, -1, -1):
		right.append(left[i] * Vector2(-1.0, 1.0))
		radii.append(rounding[i])
	return ShapeGeometry.filleted(right, radii, steps)


## The oval's rim standing out of the back, around the moulded name.
static func _rim(mesh: MeshBuilder, shape: N64CartShape, steps: int) -> void:
	var whole := shape.whole()
	var back := -shape.depth / 2.0
	var low := back - shape.oval_rim.y
	var high := back + N64CartShape.OVERLAP
	var cut := shape.oval_centre.x
	var pill := func(box: Rect2) -> PackedVector2Array:
		return ShapeGeometry.rounded_box(box, minf(box.size.x, box.size.y) / 2.0, steps, cut)
	var outer: PackedVector2Array = pill.call(shape.oval_box())
	var inner: PackedVector2Array = pill.call(shape.oval_inside())
	var lines := PackedFloat32Array([cut])
	ShapeGeometry.holed(mesh, outer, [inner], low, Vector3.FORWARD, whole, lines)
	ShapeGeometry.holed(mesh, outer, [inner], high, Vector3.BACK, whole, lines)
	ShapeGeometry.wall(mesh, outer, low, high, whole)
	ShapeGeometry.sunk(mesh, inner, low, high, whole, false)


## The back's outline, cut by the two indentations, and slit by its grooves from the top down to the
## sticker and from the sticker down to the bottom.
static func _back(shape: N64CartShape, steps: int) -> PackedVector2Array:
	var low := shape.whole().position
	var inner := low.x + shape.notch_from
	var outer := inner + shape.notch_size.x
	var top := low.y + shape.notch_size.y
	var corner := shape.bottom_corner
	var line := -shape.back_line()
	var half := shape.groove / 2.0
	var mouth := shape.mouth()
	var sticker := shape.sticker_box()
	var slits := PackedVector2Array([Vector2(-line, sticker.end.y), Vector2(line, sticker.end.y)])
	return _mirrored(shape, [low, Vector2(inner, low.y), Vector2(inner, top), Vector2(outer, top),
		Vector2(outer, low.y), Vector2(line - half - mouth, low.y), Vector2(line - half, low.y),
		Vector2(line - half, sticker.position.y), Vector2(line + half, sticker.position.y), Vector2(line + half, low.y),
		Vector2(line + half + mouth, low.y)], [corner, corner, 0.0, 0.0, corner, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0], steps,
		slits)


## The outline cut by the slot along the bottom, its top by [param notches] (see [method outline]).
static func _slotted(shape: N64CartShape, steps: int, notches: PackedVector2Array) -> PackedVector2Array:
	var low := shape.whole().position
	var edge := -shape.slot_size.x / 2.0
	return _mirrored(shape, [low, Vector2(edge, low.y), Vector2(edge, low.y + shape.slot_depth)],
		[shape.bottom_corner, 0.0, 0.0], steps, _notched(shape, notches))


## The outline under the arched top whose left half under its top corner is [param left] (from the
## side down towards the middle, rounded by [param radii]), the right half mirroring it; its top
## notched by [param notches] (see [method _rounded_top]).
static func _mirrored(shape: N64CartShape, left: PackedVector2Array, radii: PackedFloat32Array,
		steps: int, notches := PackedVector2Array()) -> PackedVector2Array:
	var below := left.duplicate()
	var rounding := radii.duplicate()
	for i in range(left.size() - 1, -1, -1):
		below.append(left[i] * Vector2(-1.0, 1.0))
		rounding.append(radii[i])
	return _rounded_top(shape.whole(), shape.arch, shape.top_corner, below, rounding, steps, notches,
		shape.groove / 2.0, shape.mouth())


## The rectangle [param box], its bottom corners rounded by [param corners].x, under an arched top
## rising [param arch] over its corners, rounded by [param corners].y.
static func _arched(box: Rect2, arch: float, corners: Vector2, steps: int) -> PackedVector2Array:
	return _rounded_top(box, arch, corners.y, ShapeGeometry.square(box).slice(0, 2),
		PackedFloat32Array([corners.x, corners.x]), steps)


## The outline of [param below] (its points under the top corners, counter-clockwise from the left
## side down to the right one, rounded by [param radii]) under the top of [param box]: its corners,
## rounded by [param corner], and the arc between them rising [param arch] over them, in
## [constant ARCS] pieces; each of [param notches] (its middle's X and its floor's height, from the
## right one) cut down square into its piece, [param half] wide each side, with a point on the
## piece [param mouth] beyond each wall, where the edge's roll has eased into the groove's lips.
static func _rounded_top(box: Rect2, arch: float, corner: float, below: PackedVector2Array,
		radii: PackedFloat32Array, steps: int, notches := PackedVector2Array(), half := 0.0,
		mouth := 0.0) -> PackedVector2Array:
	var polygon := PackedVector2Array()
	var rounding := PackedFloat32Array()
	for i in ARCS + 1:
		var point := Vector2(box.end.x - box.size.x * i / ARCS, 0.0)
		point.y = _top(box, arch, point.x)
		for notch in notches:
			if i > 0 and point.x < notch.x and notch.x < polygon[-1].x:
				# Its walls stand on the piece's chord.
				var from := polygon[-1]
				var on := func(x: float) -> Vector2:
					return Vector2(x, lerpf(from.y, point.y, (from.x - x) / (from.x - point.x)))
				for out: float in [1.0, -1.0]:
					var wall := notch.x + out * half
					var points: Array[Vector2] = [on.call(wall + out * mouth), on.call(wall), Vector2(wall, notch.y)]
					if out < 0.0:
						points.reverse()
					polygon.append_array(points)
					rounding.append_array([0.0, 0.0, 0.0])
		polygon.append(point)
		rounding.append(corner if i % ARCS == 0 else 0.0)
	polygon.append_array(below)
	rounding.append_array(radii)
	return ShapeGeometry.filleted(polygon, rounding, steps)


## The height at [param x] of the arc over [param box], rising [param arch] from its corners to its
## middle at the box's top.
static func _top(box: Rect2, arch: float, x: float) -> float:
	var radius := (box.size.x * box.size.x / 4.0 + arch * arch) / (2.0 * arch)
	var off := x - box.get_center().x
	return box.end.y - radius + sqrt(radius * radius - off * off)
