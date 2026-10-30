# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbCartGeometry
extends RefCounted
## Builds a Game Boy cartridge from its [GbCartShape] as pure functions; its pieces the Game Boy
## Advance's cartridge shares ([GbaCartGeometry]). Each half is swept through outlines of its
## sides, each set in as far as its edges round off at its height (the lower front's sides by
## their chamfer), its outer face laid in pieces around its recesses: in front the pill, whose
## walls curve down to its floor, the label's recess, the arrow and the grooves' ends; behind the
## stripes, the dimple and the screw's hole. Below the back's upper half, the connector's sleeve,
## thinner. The moulded lettering is the face of a thin plate over its surface.

const PARTS: Array[StringName] = [&"label", &"shell", &"gloss", &"metal", &"screw", &"logo", &"marks"]
## The smallest radius a corner keeps as its edges are set in: as many points at every height.
const KEPT := 0.01
## How far a moulded mark's plate stands over its surface, and down into it.
const MARK_OVER := 0.05


static func arrays(shape: GbCartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.depth / 2.0
	var sunk_label := front - shape.recess
	var label := ShapeGeometry.rounded_box(shape.label_box(), GbCartShape.LABEL_CORNER, steps, 0.0)
	var whole := Rect2(-shape.width / 2.0, -shape.height / 2.0, shape.width, shape.height)
	var backs := shape.back_boxes()
	var screw := backs[3].get_center()
	var stripes: Array[PackedVector2Array] = []
	for i in 2:
		stripes.append(ShapeGeometry.rounded_box(backs[i], GbCartShape.FILLET, steps, backs[i].get_center().x))
	match part:
		&"label":
			ShapeGeometry.flat(mesh, label, sunk_label, Vector3.BACK, shape.label_box())
		&"logo":
			mark(mesh, shape.logo_box(), front - shape.pill_depth)
		&"marks":
			mesh.basis = ShapeGeometry.BEHIND
			mark(mesh, shape.marks_box(), front)
		&"gloss":
			mesh.basis = ShapeGeometry.BEHIND
			for stripe in stripes:
				ShapeGeometry.flat(mesh, stripe, front - GbCartShape.STRIPE, Vector3.BACK, whole)
			ShapeGeometry.flat(mesh, _sleeve(MeshBuilder.new(), shape, steps, whole), front - GbCartShape.SLEEVE_STEP,
				Vector3.BACK, whole)
		&"metal":
			# The opening's dark inside, a hair below the bottom edge so as not to flicker with it.
			ShapeGeometry.prism(mesh, ShapeGeometry.square(Rect2(-shape.connector.x / 2.0, -shape.height / 2.0 - 0.05,
				shape.connector.x, 2.5)), -shape.connector.y / 2.0, shape.connector.y / 2.0)
		&"screw":
			mesh.basis = ShapeGeometry.BEHIND
			var sunk := front - GbCartShape.SCREW_SINK
			ShapeGeometry.prism(mesh, circle_at(screw, GbCartShape.SCREW_HEAD / 2.0, steps), sunk - 0.1,
				sunk + GbCartShape.SCREW_RISE)
		&"shell":
			_front(mesh, shape, steps, label, whole)
			mesh.basis = ShapeGeometry.BEHIND
			_back(mesh, shape, steps, stripes, whole)
	return mesh.arrays()


## The outline seen from the front, counter-clockwise, from [param bottom] up, set in by
## [param inset] all round but on the lower part's sides, set in by [param lower] there: its
## bottom corners, the chamfer's taper and end at the step, the grooves cut into the sides, the
## notch in its top right corner.
static func outline(shape: GbCartShape, bottom: float, inset: float, lower: float, steps: int) -> PackedVector2Array:
	var half := shape.width / 2.0
	var top := shape.height / 2.0
	var stepped := top - shape.step_drop
	var low := (shape.bottom_corner if bottom <= -top else GbCartShape.FILLET) - inset
	var corners := PackedVector2Array([Vector2(-half + inset, bottom + inset), Vector2(half - inset, bottom + inset)])
	var radii := PackedFloat32Array([maxf(low, KEPT), maxf(low, KEPT)])
	var right := PackedVector2Array([Vector2(half - lower, bottom + GbCartShape.TAPER), Vector2(half - lower, stepped),
		Vector2(half - inset, stepped + GbCartShape.RAMP)])
	var spans := shape.groove_spans()
	for k in range(spans.size() - 1, -1, -1):
		var gap := Vector2(spans[k].x - inset, spans[k].y + inset)
		var cut := half - GbCartShape.TOOTH - inset
		right.append_array([Vector2(half - inset, gap.x), Vector2(cut, gap.x), Vector2(cut, gap.y),
			Vector2(half - inset, gap.y)])
	corners.append_array(right)
	radii.resize(corners.size())
	var outer := maxf(shape.corner - inset, KEPT)
	if shape.notched:
		var floor_y := top - shape.notch.y - inset
		corners.append_array([Vector2(half - inset, floor_y), Vector2(half - shape.notch.x - inset, floor_y),
			Vector2(half - shape.notch.x - inset, top - inset)])
		radii.append_array([outer, 0.0, maxf(GbCartShape.FILLET - inset, KEPT)])
	else:
		corners.append(Vector2(half - inset, top - inset))
		radii.append(outer)
	corners.append(Vector2(-half + inset, top - inset))
	radii.append(outer)
	for i in range(right.size() - 1, -1, -1):
		corners.append(Vector2(-right[i].x, right[i].y))
	radii.resize(corners.size())
	return ShapeGeometry.filleted(corners, radii, steps)


## Adds the solid swept through [param rings] (outlines of as many points, counter-clockwise, from
## the back to the front), each point's normal turned out along its outline and across to the
## next, and its back face; its front, the last ring, is left to the caller.
static func lofted(mesh: MeshBuilder, rings: Array[PackedVector3Array], uv: Rect2) -> void:
	ShapeGeometry.joined(mesh, rings, uv)
	ShapeGeometry.flat(mesh, ShapeGeometry.plan(rings[0]), rings[0][0].z, Vector3.FORWARD, uv)


## Adds a recess of the outlines [param rings] (as many points each, counter-clockwise, each inside
## the one before) cut in a face at [param top], each the depth below it in [param depths] (the
## first none): its walls, facing in and up, and its floor.
static func coved(mesh: MeshBuilder, rings: Array[PackedVector2Array], depths: PackedFloat32Array, top: float,
		uv: Rect2) -> void:
	var lifted: Array[PackedVector3Array] = []
	for k in rings.size():
		lifted.append(level(rings[k], top - depths[k]))
	ShapeGeometry.joined(mesh, lifted, uv)
	ShapeGeometry.flat(mesh, rings[-1], top - depths[-1], Vector3.BACK, uv)


## Adds the face a moulded mark is drawn on: the top of a thin plate over [param box] on the face
## at [param z], its UV square the mark's image, upright.
static func mark(mesh: MeshBuilder, box: Rect2, z: float) -> void:
	ShapeGeometry.prism(mesh, ShapeGeometry.square(box), z - MARK_OVER, z + MARK_OVER, box)


## [param loop] at height [param z], as the ring of a solid.
static func level(loop: PackedVector2Array, z: float) -> PackedVector3Array:
	var ring := PackedVector3Array()
	for point in loop:
		ring.append(Vector3(point.x, point.y, z))
	return ring


## [param loop] seen from behind: mirrored across, still counter-clockwise.
static func mirrored(loop: PackedVector2Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	for i in range(loop.size() - 1, -1, -1):
		found.append(Vector2(-loop[i].x, loop[i].y))
	return found


## A circle with a point exactly on the vertical line through its centre, at its top and bottom.
static func circle_at(centre: Vector2, radius: float, steps: int) -> PackedVector2Array:
	var loop := ShapeGeometry.circle(centre, radius, 4 * steps)
	loop[steps] = centre + Vector2(0.0, radius)
	loop[3 * steps] = centre - Vector2(0.0, radius)
	return loop


## How far each outline of a piece is set in, and the height it lies at, from its joint at
## [param joint] to its face at [param face]: rounded by [param seam] at the joint (square without),
## then by [param bevel] at the face.
static func levels(joint: float, face: float, seam: float, bevel: float) -> Array[Vector2]:
	var turn := 1.0 - sqrt(0.5)
	var found: Array[Vector2] = [Vector2(seam, joint)]
	if seam > 0.0:
		found.append_array([Vector2(seam * turn, joint + seam * turn), Vector2(0.0, joint + seam)])
	found.append_array([Vector2(0.0, face - bevel), Vector2(bevel * turn, face - bevel * turn), Vector2(bevel, face)])
	return found


## As [method levels], each outline's sides set in further by a chamfer of [param chamfer] (across
## and deep) at the face: how far each is set in, its sides, and its height.
static func chamfered(joint: float, face: float, seam: float, bevel: float, chamfer: Vector2) -> Array[Vector3]:
	var foot := face - chamfer.y
	var heights := levels(joint, face, seam, bevel)
	heights.insert(heights.size() - 3, Vector2(0.0, foot))
	var found: Array[Vector3] = []
	for at in heights:
		found.append(Vector3(at.x, maxf(at.x, chamfer.x * clampf((at.y - foot) / chamfer.y, 0.0, 1.0)), at.y))
	return found


static func _front(mesh: MeshBuilder, shape: GbCartShape, steps: int, label: PackedVector2Array, whole: Rect2) -> void:
	var front := shape.depth / 2.0
	var lines := PackedFloat32Array([-shape.slot_line(), 0.0, shape.slot_line()])
	var rings: Array[PackedVector3Array] = []
	for at in chamfered(0.0, front, GbCartShape.SEAM, shape.bevel, shape.chamfer):
		rings.append(level(crossed(outline(shape, -shape.height / 2.0, at.x, at.y, steps), lines), at.z))
	lofted(mesh, rings, whole)
	var recess := ShapeGeometry.rounded_box(shape.recess_box(), GbCartShape.LABEL_CORNER + shape.recess_margin,
		steps, 0.0)
	var box := shape.arrow_box()
	var arrow := ShapeGeometry.crossed(PackedVector2Array([Vector2(0.0, box.position.y), box.end,
		Vector2(box.position.x, box.end.y)]), 0.0)
	var pill: Array[PackedVector2Array] = []
	var depths := PackedFloat32Array()
	for cove in GbCartShape.COVE:
		var into := shape.pill_box().grow(-shape.cove * cove.x)
		pill.append(ShapeGeometry.rounded_box(into, into.size.y / 2.0, steps, 0.0))
		depths.append(shape.pill_depth * cove.y)
	var slots: Array[PackedVector2Array] = []
	for slot in shape.slot_boxes():
		for side: float in [-1.0, 1.0]:
			var mirrored_slot := Rect2(slot.position.x if side > 0.0 else -slot.end.x, slot.position.y, slot.size.x,
				slot.size.y)
			slots.append(ShapeGeometry.crossed(ShapeGeometry.square(mirrored_slot), side * shape.slot_line()))
	var holes: Array[PackedVector2Array] = [pill[0], recess, arrow]
	holes.append_array(slots)
	ShapeGeometry.holed(mesh, ShapeGeometry.plan(rings[-1]), holes, front, Vector3.BACK, whole, lines)
	coved(mesh, pill, depths, front, whole)
	ShapeGeometry.band(mesh, recess, label, front - shape.recess, Vector3.BACK, whole)
	ShapeGeometry.sunk(mesh, recess, front - shape.recess, front, whole, false)
	ShapeGeometry.sunk(mesh, arrow, front - GbCartShape.SHALLOW, front, whole)
	for slot in slots:
		ShapeGeometry.sunk(mesh, slot, front - GbCartShape.GROOVE_DEPTH, front, whole)


static func _back(mesh: MeshBuilder, shape: GbCartShape, steps: int, stripes: Array[PackedVector2Array],
		whole: Rect2) -> void:
	var front := shape.depth / 2.0
	var lines := PackedFloat32Array([-shape.stripe_offset, 0.0, shape.stripe_offset])
	var rings: Array[PackedVector3Array] = []
	for at in levels(0.0, front, GbCartShape.SEAM, shape.bevel):
		rings.append(level(crossed(mirrored(outline(shape, shape.sleeve_top(), at.x, at.x, steps)), lines), at.y))
	lofted(mesh, rings, whole)
	var backs := shape.back_boxes()
	var dimple: Array[PackedVector2Array] = [circle_at(backs[2].get_center(), GbCartShape.DIMPLE / 2.0, steps),
		circle_at(backs[2].get_center(), GbCartShape.DIMPLE * 0.35, steps),
		circle_at(backs[2].get_center(), GbCartShape.DIMPLE / 10.0, steps)]
	var screw := circle_at(backs[3].get_center(), GbCartShape.SCREW_HOLE / 2.0, steps)
	var holes: Array[PackedVector2Array] = stripes.duplicate()
	holes.append_array([dimple[0], screw])
	ShapeGeometry.holed(mesh, ShapeGeometry.plan(rings[-1]), holes, front, Vector3.BACK, whole, lines)
	for stripe in stripes:
		ShapeGeometry.sunk(mesh, stripe, front - GbCartShape.STRIPE, front, whole, false)
	coved(mesh, dimple, PackedFloat32Array([0.0, GbCartShape.DIMPLE_DEPTH * 0.9, GbCartShape.DIMPLE_DEPTH]), front,
		whole)
	ShapeGeometry.sunk(mesh, screw, front - GbCartShape.SCREW_SINK, front, whole)
	_sleeve(mesh, shape, steps, whole)


## Adds the connector's sleeve but its smooth face, and gives that face's outline.
static func _sleeve(mesh: MeshBuilder, shape: GbCartShape, steps: int, whole: Rect2) -> PackedVector2Array:
	var sleeve := Rect2(-shape.width / 2.0, -shape.height / 2.0, shape.width, shape.sleeve_height)
	return ShapeGeometry.slab(mesh, ShapeGeometry.rounded(sleeve, shape.bottom_corner, GbCartShape.FILLET, steps), 0.0,
		shape.depth / 2.0 - GbCartShape.SLEEVE_STEP, Vector2(GbCartShape.SEAM, shape.bevel), whole, false)


## [param loop] given a point wherever it crosses each of the vertical [param lines].
static func crossed(loop: PackedVector2Array, lines: PackedFloat32Array) -> PackedVector2Array:
	var found := loop
	for x in lines:
		found = ShapeGeometry.crossed(found, x)
	return found
