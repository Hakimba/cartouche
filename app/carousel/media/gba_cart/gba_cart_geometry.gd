# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbaCartGeometry
extends RefCounted
## Builds a Game Boy Advance cartridge from its [GbaCartShape] as pure functions, from the Game Boy
## cartridge's pieces ([GbCartGeometry]). Behind, a plate of the whole outline (the head and the
## body above the sleeve), its face laid around its recesses; under it the sleeve, narrower and
## thinner. In front, the body, swept with its chamfered sides, its face around the label's recess
## and the arrow; and the head, its front standing at each point across as high as the hump is
## there, swept from station to station across, its top edge rolled towards the front and its lower
## edge the hump's arch.

const PARTS: Array[StringName] = [&"label", &"shell", &"gloss", &"metal", &"screw", &"logo", &"marks"]
const ROLL_STEPS := 3


static func arrays(shape: GbaCartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var back := -shape.back()
	var whole := Rect2(-shape.width / 2.0, -shape.height / 2.0, shape.width, shape.height)
	var backs := shape.back_boxes()
	var stripes: Array[PackedVector2Array] = []
	for i in 2:
		stripes.append(ShapeGeometry.rounded_box(backs[i], GbaCartShape.FILLET, steps, backs[i].get_center().x))
	var label := ShapeGeometry.rounded_box(shape.label_box(), GbaCartShape.LABEL_CORNER, steps, 0.0)
	match part:
		&"label":
			ShapeGeometry.flat(mesh, label, shape.face() - GbaCartShape.RECESS, Vector3.BACK, shape.label_box())
		&"logo":
			GbCartGeometry.mark(mesh, shape.logo_box(), shape.face())
		&"marks":
			mesh.basis = ShapeGeometry.BEHIND
			GbCartGeometry.mark(mesh, shape.marks_box(), back - GbaCartShape.PANEL_DEPTH)
		&"gloss":
			mesh.basis = ShapeGeometry.BEHIND
			for stripe in stripes:
				ShapeGeometry.flat(mesh, stripe, back - GbaCartShape.STRIPE, Vector3.BACK, whole)
			ShapeGeometry.flat(mesh, _sleeve(MeshBuilder.new(), shape, steps, whole), back - GbaCartShape.SLEEVE_STEP,
				Vector3.BACK, whole)
		&"metal":
			# The opening's dark inside, a hair below the bottom edge so as not to flicker with it.
			var middle := (shape.joint() + shape.face()) / 2.0
			ShapeGeometry.prism(mesh, ShapeGeometry.square(Rect2(-GbaCartShape.CONNECTOR.x / 2.0, -shape.height / 2.0 - 0.05,
				GbaCartShape.CONNECTOR.x, 2.5)), middle - GbaCartShape.CONNECTOR.y / 2.0, middle + GbaCartShape.CONNECTOR.y / 2.0)
		&"screw":
			mesh.basis = ShapeGeometry.BEHIND
			var sunk := back - GbaCartShape.SCREW_SINK
			ShapeGeometry.prism(mesh, GbCartGeometry.circle_at(backs[4].get_center(), GbaCartShape.SCREW_HEAD / 2.0,
				steps), sunk - 0.1, sunk + GbaCartShape.SCREW_RISE)
		&"shell":
			_body(mesh, shape, steps, label, whole)
			_head(mesh, shape, steps, whole)
			mesh.basis = ShapeGeometry.BEHIND
			_plate(mesh, shape, steps, stripes, whole)
			_sleeve(mesh, shape, steps, whole)
	return mesh.arrays()


## The body's outline seen from the front, counter-clockwise, set in by [param inset] but on its
## sides, set in by [param sides] there (tapering to [param inset] at the bottom corners); its top
## hidden in the head.
static func body_outline(shape: GbaCartShape, inset: float, sides: float, steps: int) -> PackedVector2Array:
	var half := shape.body_width() / 2.0
	var bottom := -shape.height / 2.0
	var top := shape.at(shape.arch_drop / 2.0)
	var low := maxf(GbaCartShape.BOTTOM_CORNER - inset, GbCartGeometry.KEPT)
	var high := maxf(GbaCartShape.FILLET - inset, GbCartGeometry.KEPT)
	return ShapeGeometry.filleted(PackedVector2Array([Vector2(-half + inset, bottom + inset),
		Vector2(half - inset, bottom + inset), Vector2(half - sides, bottom + GbaCartShape.TAPER),
		Vector2(half - sides, top - inset), Vector2(-half + sides, top - inset),
		Vector2(-half + sides, bottom + GbaCartShape.TAPER)]), PackedFloat32Array([low, low, 0.0, high, high, 0.0]), steps)


## The back plate's outline seen from the front, counter-clockwise, set in by [param inset]: the
## head across the top, the body below it down to the sleeve.
static func plate_outline(shape: GbaCartShape, inset: float, steps: int) -> PackedVector2Array:
	var head := shape.width / 2.0 - inset
	var body := shape.body_width() / 2.0 - inset
	var low := shape.sleeve_top() + inset
	var under := shape.at(shape.head_drop) + inset
	var top := shape.height / 2.0 - inset
	var small := maxf(GbaCartShape.FILLET - inset, GbCartGeometry.KEPT)
	var outer := maxf(GbaCartShape.HEAD_CORNER - inset, GbCartGeometry.KEPT)
	var round_top := maxf(shape.corner - inset, GbCartGeometry.KEPT)
	return ShapeGeometry.filleted(PackedVector2Array([Vector2(-body, low), Vector2(body, low), Vector2(body, under),
		Vector2(head, under), Vector2(head, top), Vector2(-head, top), Vector2(-head, under), Vector2(-body, under)]),
		PackedFloat32Array([small, small, 0.0, outer, round_top, round_top, outer, 0.0]), steps)


static func _body(mesh: MeshBuilder, shape: GbaCartShape, steps: int, label: PackedVector2Array, whole: Rect2) -> void:
	var lines := PackedFloat32Array([0.0])
	var rings: Array[PackedVector3Array] = []
	for at in GbCartGeometry.chamfered(shape.joint(), shape.face(), 0.0, GbaCartShape.BEVEL, shape.chamfer):
		rings.append(GbCartGeometry.level(GbCartGeometry.crossed(body_outline(shape, at.x, at.y, steps), lines), at.z))
	GbCartGeometry.lofted(mesh, rings, whole)
	var face := shape.face()
	var recess := ShapeGeometry.rounded_box(shape.recess_box(), GbaCartShape.LABEL_CORNER + GbaCartShape.RECESS_MARGIN, steps,
		0.0)
	var box := shape.arrow_box()
	var arrow := ShapeGeometry.crossed(PackedVector2Array([Vector2(0.0, box.position.y), box.end,
		Vector2(box.position.x, box.end.y)]), 0.0)
	var holes: Array[PackedVector2Array] = [recess, arrow]
	ShapeGeometry.holed(mesh, ShapeGeometry.plan(rings[-1]), holes, face, Vector3.BACK, whole, lines)
	ShapeGeometry.band(mesh, recess, label, face - GbaCartShape.RECESS, Vector3.BACK, whole)
	ShapeGeometry.sunk(mesh, recess, face - GbaCartShape.RECESS, face, whole, false)
	ShapeGeometry.sunk(mesh, arrow, face - GbaCartShape.SHALLOW, face, whole)


static func _head(mesh: MeshBuilder, shape: GbaCartShape, steps: int, whole: Rect2) -> void:
	var stations := _stations(shape, steps)
	var joint := shape.joint()
	var lows := PackedVector2Array()
	var highs := PackedVector2Array()
	var roof: Array[PackedInt32Array] = []
	for x in stations:
		var low := Vector2(x, _under(shape, x))
		var high := Vector2(x, _over(shape, x))
		lows.append(low)
		highs.append(high)
		var z := shape.roof(x)
		var tilt := -shape.slope(x)
		var row := PackedInt32Array([ShapeGeometry.add(mesh, low, z, Vector3(tilt, 0.0, 1.0).normalized(), whole)])
		for k in ROLL_STEPS + 1:
			var angle := PI / 2.0 * k / ROLL_STEPS
			var at := Vector2(x, high.y - GbaCartShape.ROLL * (1.0 - sin(angle)))
			row.append(ShapeGeometry.add(mesh, at, z - GbaCartShape.ROLL * (1.0 - cos(angle)),
				Vector3(tilt * cos(angle), sin(angle), cos(angle)).normalized(), whole))
		roof.append(row)
	for j in stations.size() - 1:
		for r in roof[j].size() - 1:
			mesh.quad(roof[j][r], roof[j + 1][r], roof[j + 1][r + 1], roof[j][r + 1])
	var count := stations.size()
	for j in count - 1:
		for edge in 2:
			var points := lows if edge == 0 else highs
			var tops := PackedFloat32Array([shape.roof(stations[j]), shape.roof(stations[j + 1])])
			var lift := 0.0 if edge == 0 else GbaCartShape.ROLL
			var normal := (points[j + 1] - points[j]).orthogonal().normalized() * (1.0 if edge == 0 else -1.0)
			var out := Vector3(normal.x, normal.y, 0.0)
			mesh.quad(ShapeGeometry.add(mesh, points[j], joint, out, whole),
				ShapeGeometry.add(mesh, points[j + 1], joint, out, whole),
				ShapeGeometry.add(mesh, points[j + 1], tops[1] - lift, out, whole),
				ShapeGeometry.add(mesh, points[j], tops[0] - lift, out, whole))
	for j: int in [0, count - 1]:
		var side := Vector3(signf(stations[j]), 0.0, 0.0)
		var section := PackedInt32Array([ShapeGeometry.add(mesh, lows[j], joint, side, whole)])
		var z := shape.roof(stations[j])
		section.append(ShapeGeometry.add(mesh, lows[j], z, side, whole))
		for k in ROLL_STEPS + 1:
			var angle := PI / 2.0 * k / ROLL_STEPS
			section.append(ShapeGeometry.add(mesh, Vector2(stations[j], highs[j].y - GbaCartShape.ROLL * (1.0 - sin(angle))),
				z - GbaCartShape.ROLL * (1.0 - cos(angle)), side, whole))
		section.append(ShapeGeometry.add(mesh, highs[j], joint, side, whole))
		for k in range(1, section.size() - 1):
			mesh.triangle(section[0], section[k], section[k + 1])
	var plan := lows.duplicate()
	for j in range(count - 1, -1, -1):
		plan.append(highs[j])
	ShapeGeometry.flat(mesh, plan, joint, Vector3.FORWARD, whole)


static func _stations(shape: GbaCartShape, steps: int) -> PackedFloat32Array:
	var half := shape.width / 2.0
	var found: Array[float] = [0.0]
	for k in steps + 1:
		var turn := sin(PI / 2.0 * k / steps)
		found.append_array([half - shape.corner * (1.0 - turn), half - GbaCartShape.HEAD_CORNER * (1.0 - turn)])
	for i in GbaCartShape.STATIONS + 1:
		found.append(lerpf(shape.hump.x, shape.hump.y, float(i) / GbaCartShape.STATIONS))
	found.sort()
	var stations := PackedFloat32Array()
	for x in found:
		if stations.is_empty() or x - stations[-1] > 0.01:
			stations.append(x)
	var across := PackedFloat32Array()
	for i in range(stations.size() - 1, 0, -1):
		across.append(-stations[i])
	across.append_array(stations)
	return across


static func _under(shape: GbaCartShape, x: float) -> float:
	var off := absf(x) - shape.width / 2.0 + GbaCartShape.HEAD_CORNER
	var rounding := GbaCartShape.HEAD_CORNER - sqrt(maxf(0.0, GbaCartShape.HEAD_CORNER * GbaCartShape.HEAD_CORNER - off * off)) \
		if off > 0.0 else 0.0
	return shape.at(minf(shape.arch(x), shape.head_drop)) + rounding


static func _over(shape: GbaCartShape, x: float) -> float:
	var off := absf(x) - shape.width / 2.0 + shape.corner
	var rounding := shape.corner - sqrt(maxf(0.0, shape.corner * shape.corner - off * off)) if off > 0.0 else 0.0
	return shape.height / 2.0 - rounding


static func _plate(mesh: MeshBuilder, shape: GbaCartShape, steps: int, stripes: Array[PackedVector2Array],
		whole: Rect2) -> void:
	var back := -shape.back()
	var lines := PackedFloat32Array([-shape.stripe_offset, 0.0, shape.stripe_offset])
	var rings: Array[PackedVector3Array] = []
	for at in GbCartGeometry.levels(-shape.joint(), back, 0.0, GbaCartShape.BEVEL):
		rings.append(GbCartGeometry.level(GbCartGeometry.crossed(GbCartGeometry.mirrored(
			plate_outline(shape, at.x, steps)), lines), at.y))
	GbCartGeometry.lofted(mesh, rings, whole)
	var backs := shape.back_boxes()
	var panel := ShapeGeometry.rounded_box(backs[2], GbaCartShape.PANEL_CORNER, steps, 0.0)
	var centre := backs[3].get_center()
	var dimple: Array[PackedVector2Array] = [GbCartGeometry.circle_at(centre, GbaCartShape.DIMPLE / 2.0, steps),
		GbCartGeometry.circle_at(centre, GbaCartShape.DIMPLE * 0.35, steps),
		GbCartGeometry.circle_at(centre, GbaCartShape.DIMPLE / 10.0, steps)]
	var screw := GbCartGeometry.circle_at(backs[4].get_center(), GbaCartShape.SCREW_HOLE / 2.0, steps)
	var holes: Array[PackedVector2Array] = stripes.duplicate()
	holes.append_array([panel, dimple[0], screw])
	ShapeGeometry.holed(mesh, ShapeGeometry.plan(rings[-1]), holes, back, Vector3.BACK, whole, lines)
	for stripe in stripes:
		ShapeGeometry.sunk(mesh, stripe, back - GbaCartShape.STRIPE, back, whole, false)
	ShapeGeometry.sunk(mesh, panel, back - GbaCartShape.PANEL_DEPTH, back, whole)
	GbCartGeometry.coved(mesh, dimple, PackedFloat32Array([0.0, GbaCartShape.DIMPLE_DEPTH * 0.9,
		GbaCartShape.DIMPLE_DEPTH]), back, whole)
	ShapeGeometry.sunk(mesh, screw, back - GbaCartShape.SCREW_SINK, back, whole)


## Adds the connector's sleeve, seen from behind, but its smooth face, and gives that face's outline.
static func _sleeve(mesh: MeshBuilder, shape: GbaCartShape, steps: int, whole: Rect2) -> PackedVector2Array:
	var half := shape.body_width() / 2.0 - shape.sleeve_inset
	var sleeve := Rect2(-half, -shape.height / 2.0, 2.0 * half, shape.sleeve_height)
	return ShapeGeometry.slab(mesh, ShapeGeometry.rounded(sleeve, GbaCartShape.BOTTOM_CORNER, GbaCartShape.FILLET, steps),
		-shape.joint(), -shape.back() - GbaCartShape.SLEEVE_STEP, Vector2(0.0, GbaCartShape.BEVEL), whole, false)
