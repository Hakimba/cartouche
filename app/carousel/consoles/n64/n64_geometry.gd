# SPDX-License-Identifier: GPL-3.0-or-later
class_name N64Geometry
extends RefCounted
## Builds the Nintendo 64 from its [N64Shape] as pure functions, so that tests check the geometry
## headless. Parts on the top are laid out in plan, X to the right and Y towards the back, swept up
## along Z, then turned into the model's space: top up (+Y), front towards +Z. Parts on a face are
## laid out on it and swept out of it. The upper shell's top follows [method N64Shape.top_height]:
## its outlines are taken along rays from the slot's centre, from the seam up its sides, round its
## top edges and in across its top to the flat floor around the slot, which goes through it down to
## the seam (see [method ShapeGeometry.swept]). The slits on the ramp follow the top too; the
## switches lie on the hill's flanks, leant with them. Each flap is given around its hinge, and each
## knob at rest, as the model moves them.

const PARTS: Array[StringName] = [&"feet", &"lower", &"upper", &"pods", &"well", &"bezel", &"flap_front",
	&"flap_back", &"lid", &"logo", &"badge", &"vents", &"side_vents", &"recesses", &"power_knob",
	&"reset_knob", &"ports", &"pins", &"led", &"badge_logo", &"maker_logo", &"lid_label", &"power_label",
	&"reset_label", &"switch_label"]
## The logos' faces, flat (see [method N64Shape.surfaces]), the size of their images: the console's
## name and the four N on the badge, the maker's name on the plate behind the slot, the memory lid's
## lettering, each knob's name and the power switch's ON and OFF, beside its recess.
const LOGOS: Dictionary[StringName, Vector2] = {&"badge_logo": Vector2(45.0, 23.6),
	&"maker_logo": Vector2(35.2, 6.2), &"lid_label": Vector2(44.0, 40.0), &"power_label": Vector2(13.0, 4.5),
	&"reset_label": Vector2(13.0, 4.5), &"switch_label": Vector2(5.0, 7.0)}
## How far the power switch's ON and OFF lie outside its recess.
const SWITCH_LABEL_GAP := 0.5
const _SLOT_CORNER := 2.0
const _RECESS_CORNER := 9.0
## Steps around a rounded edge; rays from the slot's centre per corner step; outlines across the
## top, from its edges in to the slot's floor; steps along a slit.
const _EDGE_STEPS := 3
const _RAYS_PER_STEP := 20
const _TOP_RINGS := 14
const _SLIT_STEPS := 4
## How far the slits on the ramp sink into the top, and stand out of it.
const _SLIT_DEPTHS := Vector2(-1.0, 0.3)
## Estimated from the photos: the memory lid's corners, how far it sinks into the hill and stands out
## of it; its tab at the middle of its back edge (its width, its length, how far it reaches past
## the lid, how far it stands out of the hill); its lettering's top from the lid's back edge.
const _LID_CORNER := 4.0
const _LID_DEPTHS := Vector2(-1.0, 0.4)
const _LID_TAB := Vector4(12.0, 5.0, 2.0, 1.2)
const _LID_LABEL_FROM_BACK := 3.5
## The badge's plate: from above the seam to below the hill's rounded edge, how round, how far it
## sinks into the front and stands out of it.
const _BADGE_MARGINS := Vector2(5.0, 2.0)
const _BADGE_CORNER := 3.0
const _BADGE_DEPTHS := Vector2(-1.0, 0.8)
## The round details on the front, each its radius, how far it sinks into the front and stands out
## of it, and its points around: the controllers' ports, grey rings around dark pins on the seam,
## their centres' X from the middle; the power light, its centre this far below the seam.
const _ROUND: Dictionary[StringName, Vector4] = {&"ports": Vector4(11.5, -1.5, 2.5, 24),
	&"pins": Vector4(7.0, -1.6, 2.6, 16), &"led": Vector4(2.8, -0.4, 0.8, 16)}
const _PORTS: Array[float] = [-63.0, -36.0, 36.0, 63.0]
const _LIGHT_BELOW_SEAM := 11.0


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: N64Shape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var at := Transform3D(ShapeGeometry.PLAN, Vector3.ZERO)
	var body := shape.body()
	var slot := ShapeGeometry.rounded_box(shape.slot(), _SLOT_CORNER, steps)
	match part:
		&"feet":
			for foot in shape.feet():
				ShapeGeometry.prism(mesh, ShapeGeometry.square(foot), 0.0, N64Shape.FEET + 0.5)
		&"lower":
			ShapeGeometry.block(mesh, body, Vector2.ONE * shape.corner, steps, N64Shape.FEET, shape.seam,
				shape.bevel, body)
		&"upper":
			var centre := Vector2(0.0, shape.slot_centre)
			var rays := _rays(shape, _RAYS_PER_STEP * steps)
			ShapeGeometry.swept(mesh, _upper(shape, centre, rays), body,
				_outline(shape.slot(), _SLOT_CORNER, centre, rays))
		&"pods":
			for side: float in [-1.0, 1.0]:
				ShapeGeometry.block(mesh, shape.pod(side), Vector2.ONE * shape.pod_corner(), steps, N64Shape.FEET,
					shape.pod_height, N64Shape.POD_ROUND, body)
		&"well":
			# Just above the lower shell's top, which it hides.
			ShapeGeometry.flat(mesh, slot, shape.seam + 0.05, Vector3.BACK, shape.slot())
		&"bezel":
			# A hair inside the slot's walls, from under the flaps' hinges to just below the floor.
			var inside := ShapeGeometry.rounded_box(shape.slot().grow(-N64Shape.BEZEL), 1.0, steps)
			var bottom := shape.back_height - shape.flap_recess - shape.flap_thickness - 1.0
			ShapeGeometry.block(mesh, shape.slot().grow(-0.05), Vector2.ONE * _SLOT_CORNER, steps, bottom,
				shape.back_height - 1.0, 0.3, shape.slot(), NAN, true, inside)
		&"flap_front", &"flap_back":
			var front := part == &"flap_front"
			var flap := shape.flap(front)
			var top := shape.back_height - shape.flap_recess
			ShapeGeometry.block(mesh, flap, Vector2.ONE * minf(1.0, flap.size.y / 3.0), steps,
				top - shape.flap_thickness, top, shape.flap_thickness / 3.0, flap)
			at.origin = -shape.flap_hinge(front)
		&"lid":
			var lid := shape.lid()
			ShapeGeometry.block(mesh, lid, Vector2.ONE * _LID_CORNER, steps, shape.height + _LID_DEPTHS.x,
				shape.height + _LID_DEPTHS.y, 0.3, lid)
			var tab := Rect2(-_LID_TAB.x / 2.0, lid.end.y + _LID_TAB.z - _LID_TAB.y, _LID_TAB.x, _LID_TAB.y)
			ShapeGeometry.prism(mesh, ShapeGeometry.square(tab), shape.height + _LID_DEPTHS.x,
				shape.height + _LID_TAB.w)
		&"lid_label":
			# Ahead of the lid's tab.
			var lid := shape.lid()
			var size := LOGOS[part]
			ShapeGeometry.decal(mesh, Rect2(Vector2(-size.x / 2.0, lid.end.y - size.y - _LID_LABEL_FROM_BACK), size),
				shape.height + _LID_DEPTHS.y)
		&"logo", &"maker_logo":
			# A plate on the tongue behind the slot, where the maker's name stands.
			var behind := Vector2(0.0, (shape.slot().end.y + body.end.y - shape.crown.x) / 2.0)
			var logo := ShapeGeometry.centred(behind, N64Shape.LOGO)
			if part == &"logo":
				ShapeGeometry.block(mesh, logo, Vector2.ONE * 4.0, steps, shape.back_height - 0.5,
					shape.back_height + 0.4, 0.2, logo)
			else:
				ShapeGeometry.decal(mesh, ShapeGeometry.centred(behind, LOGOS[part]), shape.back_height + 0.4)
		&"badge", &"badge_logo":
			# On the front face, below the hill's rounded edge.
			var face := Rect2(-N64Shape.BADGE_WIDTH / 2.0, shape.seam + _BADGE_MARGINS.x, N64Shape.BADGE_WIDTH,
				shape.height - shape.crown.y - shape.seam - _BADGE_MARGINS.x - _BADGE_MARGINS.y)
			if part == &"badge":
				ShapeGeometry.block(mesh, face, Vector2.ONE * _BADGE_CORNER, steps, -body.position.y + _BADGE_DEPTHS.x,
					-body.position.y + _BADGE_DEPTHS.y, 0.4, face)
			else:
				ShapeGeometry.decal(mesh, ShapeGeometry.centred(face.get_center(), LOGOS[part]),
					-body.position.y + _BADGE_DEPTHS.y)
			at.basis = Basis()
		&"ports", &"pins", &"led":
			var stud := _ROUND[part]
			var centres: Array[Vector2] = [Vector2(0.0, shape.seam - _LIGHT_BELOW_SEAM)]
			if part != &"led":
				centres.assign(_PORTS.map(func(x: float) -> Vector2: return Vector2(x, shape.seam)))
			for centre in centres:
				ShapeGeometry.prism(mesh, ShapeGeometry.circle(centre, stud.x, int(stud.w)),
					-body.position.y + stud.y, -body.position.y + stud.z)
			at.basis = Basis()
		&"vents":
			for index in shape.vent_count:
				var ends := shape.vent(index)
				_draped(mesh, shape, ends[0], ends[1])
		&"side_vents":
			# Towards the back of the lower shell.
			var last := body.end.y - shape.corner
			for i in N64Shape.SIDE_VENTS:
				var y := last - (i + 0.5) * N64Shape.SIDE_VENT_PITCH
				var slit := Rect2(y - N64Shape.VENT_WIDTH / 2.0, N64Shape.FEET + N64Shape.SIDE_VENT_MARGIN,
					N64Shape.VENT_WIDTH, shape.seam - N64Shape.FEET - 2.0 * N64Shape.SIDE_VENT_MARGIN)
				ShapeGeometry.prism(mesh, ShapeGeometry.square(slit), body.end.x - 1.0, body.end.x + 0.3)
				ShapeGeometry.prism(mesh, ShapeGeometry.square(slit), body.position.x - 0.3, body.position.x + 1.0)
			at.basis = ShapeGeometry.SIDE
		&"recesses":
			# The switches' recesses, and the gap around the memory lid.
			var lid_gap := shape.lid().grow(0.8)
			for recess: Rect2 in [shape.recess(true), shape.recess(false), lid_gap]:
				var rounding := 4.8 if recess == lid_gap else _RECESS_CORNER
				# Laid on the top, a hair above it.
				var on_top := PackedVector3Array()
				for point in ShapeGeometry.rounded_box(recess, rounding, steps):
					on_top.append(Vector3(point.x, point.y, shape.top_height(point) + 0.05))
				ShapeGeometry.laid(mesh, on_top, Vector3.BACK, recess)
		&"power_knob", &"reset_knob", &"power_label", &"reset_label", &"switch_label":
			# Laid out around its recess's centre, then leant with the flank under it.
			var power := part in [&"power_knob", &"power_label", &"switch_label"]
			var knob := shape.knob(power)
			var local := Rect2(-knob.size.x / 2.0, knob.position.y, knob.size.x, knob.size.y)
			match part:
				&"power_knob", &"reset_knob":
					ShapeGeometry.block(mesh, local, Vector2.ONE * (5.0 if power else 7.0), steps, -2.0,
						N64Shape.KNOB_HEIGHT, 1.0, local)
				&"switch_label":
					# On the flank outside the recess, by the knob at rest: over the facets the top is drawn
					# with there, which stand up to 0.3 mm above it.
					var size := LOGOS[part]
					var room := shape.recess(power)
					ShapeGeometry.decal(mesh, Rect2(Vector2(-room.size.x / 2.0 - size.x - SWITCH_LABEL_GAP,
						room.get_center().y - 4.0 - size.y / 2.0), size), 0.3)
				_:
					# Across the knob's front end.
					var size := LOGOS[part]
					ShapeGeometry.decal(mesh, Rect2(Vector2(-size.x / 2.0, local.position.y + 3.0), size),
						N64Shape.KNOB_HEIGHT)
			if part == &"power_knob":
				var grip := Rect2(local.position.x + 2.0, local.get_center().y - 1.0, local.size.x - 4.0, 2.0)
				ShapeGeometry.prism(mesh, ShapeGeometry.square(grip), N64Shape.KNOB_HEIGHT - 0.5,
					N64Shape.KNOB_HEIGHT + 1.8)
			var centre := shape.recess(power).get_center()
			at *= Transform3D(Basis(Vector3.UP, -atan(shape.flank(power))),
				Vector3(centre.x, 0.0, shape.top_height(centre)) * MeshBuilder.UNITS_PER_MM)
	return ShapeGeometry.moved(mesh.arrays(), at)


## The upper shell's outlines along [param rays] from [param centre]: from the seam up, its lower
## edge rounded by the bevel, its sides straight, its top edges rounded off by the crown, then in
## across its top to the flat floor around the slot.
static func _upper(shape: N64Shape, centre: Vector2, rays: PackedVector2Array) -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	var body := shape.body()
	var edge := _outline(body.grow(-shape.crown.x), shape.corner - shape.crown.x, centre, rays)
	var around := _outline(shape.surround(), _SLOT_CORNER + N64Shape.SURROUND, centre, rays)
	for k in _EDGE_STEPS + 1:
		var angle := PI / 2.0 * k / _EDGE_STEPS
		var inset := shape.bevel * (1.0 - sin(angle))
		var ring := PackedVector3Array()
		for point in _outline(body.grow(-inset), shape.corner - inset, centre, rays):
			ring.append(Vector3(point.x, point.y, shape.seam + shape.bevel * (1.0 - cos(angle))))
		rings.append(ring)
	for k in _EDGE_STEPS + 1:
		var angle := PI / 2.0 * k / _EDGE_STEPS
		var inset := shape.crown.x * (1.0 - cos(angle))
		var outline := _outline(body.grow(-inset), shape.corner - inset, centre, rays)
		var ring := PackedVector3Array()
		for i in rays.size():
			ring.append(Vector3(outline[i].x, outline[i].y,
				shape.top_height(edge[i]) - shape.crown.y * (1.0 - sin(angle))))
		rings.append(ring)
	for k in range(1, _TOP_RINGS + 1):
		# Closer together towards the slot, where the ramp climbs.
		var share := 1.0 - pow(1.0 - float(k) / _TOP_RINGS, 1.5)
		var ring := PackedVector3Array()
		for i in rays.size():
			var point := edge[i].lerp(around[i], share)
			ring.append(Vector3(point.x, point.y, shape.back_height if k == _TOP_RINGS else shape.top_height(point)))
		rings.append(ring)
	return rings


## [param count] directions from the slot's centre, counter-clockwise, as many towards each of the
## body's corners.
static func _rays(shape: N64Shape, count: int) -> PackedVector2Array:
	var body := shape.body()
	var rays := PackedVector2Array()
	for i in count:
		var angle := TAU * i / count
		var reach := body.end.y - shape.slot_centre if sin(angle) > 0.0 else shape.slot_centre - body.position.y
		rays.append(Vector2(cos(angle) * body.size.x / 2.0, sin(angle) * reach).normalized())
	return rays


## Where each of [param rays] from [param centre] leaves [param box], its corners rounded by
## [param radius].
static func _outline(box: Rect2, radius: float, centre: Vector2, rays: PackedVector2Array) -> PackedVector2Array:
	var inner := box.grow(-radius)
	var points := PackedVector2Array()
	for towards in rays:
		var reach := INF
		for axis in 2:
			if towards[axis] != 0.0:
				var side := box.end[axis] if towards[axis] > 0.0 else box.position[axis]
				reach = minf(reach, (side - centre[axis]) / towards[axis])
		var point := centre + towards * reach
		var nearest := point.clamp(inner.position, inner.end)
		if nearest.x != point.x and nearest.y != point.y:
			# Through a rounded corner: where the ray leaves its circle.
			var from := centre - nearest
			var along := from.dot(towards)
			point = centre + towards * (-along + sqrt(along * along - from.length_squared() + radius * radius))
		points.append(point)
	return points


## Adds the slit from [param from] to [param to] on the ramp, following the top: sunk into it and
## standing a little out of it.
static func _draped(mesh: MeshBuilder, shape: N64Shape, from: Vector2, to: Vector2) -> void:
	var along := (to - from).normalized()
	var side := along.orthogonal() * N64Shape.VENT_WIDTH / 2.0
	# The four edges along the slit, around its section: low and high, on either side.
	var edge_at := func(step: int, edge: int) -> Vector3:
		var point := from.lerp(to, float(step) / _SLIT_STEPS) + side * (1.0 if edge in [1, 2] else -1.0)
		return Vector3(point.x, point.y, shape.top_height(point) + (_SLIT_DEPTHS.y if edge >= 2 else _SLIT_DEPTHS.x))
	var out := Vector3(side.x, side.y, 0.0).normalized()
	var faces: Array[Vector3] = [Vector3.FORWARD, out, Vector3.BACK, -out]
	var box := Rect2(from, Vector2.ONE)
	for step in _SLIT_STEPS:
		for edge in 4:
			var next := (edge + 1) % 4
			_face(mesh, [edge_at.call(step, edge), edge_at.call(step + 1, edge), edge_at.call(step + 1, next),
				edge_at.call(step, next)], faces[edge], box)
	for end: int in [0, _SLIT_STEPS]:
		_face(mesh, [edge_at.call(end, 0), edge_at.call(end, 1), edge_at.call(end, 2), edge_at.call(end, 3)],
			Vector3(along.x, along.y, 0.0) * (1.0 if end > 0 else -1.0), box)


## Adds the face of [param corners], four in order around it, turned towards [param normal].
static func _face(mesh: MeshBuilder, corners: Array, normal: Vector3, box: Rect2) -> void:
	var indices := PackedInt32Array()
	for point: Vector3 in corners:
		indices.append(ShapeGeometry.add(mesh, Vector2(point.x, point.y), point.z, normal, box))
	mesh.quad(indices[0], indices[1], indices[2], indices[3])
