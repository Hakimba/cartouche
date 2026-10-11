# SPDX-License-Identifier: GPL-3.0-or-later
class_name GcGeometry
extends RefCounted
## Builds the GameCube from its [GcShape] as pure functions, so that tests check the geometry
## headless. The parts on the top are laid out in plan, X to the right and Y towards the back, swept
## up along Z, then turned into the model's space: top up (+Y), front towards +Z. The body has the
## well through its top, in steps: the opening down to the shelf, the ledge, the recess down to its
## floor; the flat round each step is made of two halves either side of the seat, each a simple
## outline. The front's parts are laid out on the front face, X to the right and Y up, standing out
## along Z. The lid and its dimple are given around the hinge, which the model turns them about.

const PARTS: Array[StringName] = [&"base", &"body", &"collars", &"lid", &"dimple", &"power", &"reset", &"open",
	&"lamp", &"well", &"slot", &"panel", &"ports", &"grille", &"vents", &"handle", &"feet", &"lid_logo",
	&"maker_logo", &"power_label", &"reset_label", &"open_label", &"port_dots"]
## The logos' faces, flat (see [method GcShape.surfaces]), the size of their images: the console's name
## on the lid's dark face, the maker's name moulded by the lid's back right corner, each button's name
## moulded on the lid beside its collar, and the ports' numbers in dots over them.
const LOGOS: Dictionary[StringName, Vector2] = {&"lid_logo": Vector2(40.0, 11.0), &"maker_logo": Vector2(28.4, 8.6),
	&"power_label": Vector2(15.0, 3.0), &"reset_label": Vector2(15.0, 3.0), &"open_label": Vector2(15.0, 3.0),
	&"port_dots": Vector2(100.0, 4.0)}
## Where the maker's name stands, from the lid's back right corner; how far each button's name stands
## from the button's centre, on the lid, towards its back.
const MAKER_INSET := Vector2(27.5, 8.0)
const LABEL_REACH := 13.5
## How far the panel's sides bulge, and how far it stands out of the front.
const PANEL_BULGE := 2.5
const PANEL_RAISE := 1.2
## Where the ports and the memory cards' slots are on the panel, as fractions of its width and
## height from its bottom middle; the ports' radius and the slots' size in the same fractions, the
## groove round a slot's flap in millimetres.
const PORTS: Array[float] = [-0.36, -0.12, 0.12, 0.36]
const PORT_HEIGHT := 0.63
const PORT_RADIUS := 0.052
const SLOTS: Array[float] = [-0.244, 0.244]
const SLOT_HEIGHT := 0.17
const SLOT_SIZE := Vector2(0.31, 0.09)
const SLOT_GROOVE := 0.6
## The vents' holes across and up, and the width of the bars between them, which stand out.
const VENT_HOLES := Vector2i(8, 9)
const VENT_BAR := 1.4
const VENT_RAISE := 0.6
## The slots of the back's vent, and its two connectors, as boxes on the back: their centre's X as a
## fraction of the width, then their bottom, width and height in millimetres.
const BACK_SLOTS := 9
const BACK_SLOT := Vector4(-0.413, 30.0, 3.0, 22.0)
const BACK_SLOT_PITCH := 0.05
const CONNECTORS: Array[Vector4] = [Vector4(0.12, 33.0, 20.0, 7.0), Vector4(0.293, 31.0, 10.0, 10.0)]
## The rubber feet under the front corners, below the body's bottom (the model's origin): their
## centre's distance from the side and the front, their size and height.
const FEET := Vector2(22.0, 5.0)
const FOOT := Vector3(12.0, 8.0, 2.5)
## How far the handle's ends go into the back.
const _HANDLE_BURIED := 3.0
const _HANDLE_POINTS := 24


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: GcShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var body := shape.body()
	var top := shape.height
	var at := Transform3D(ShapeGeometry.PLAN, Vector3.ZERO)
	match part:
		&"base":
			ShapeGeometry.block(mesh, body, Vector2.ONE * shape.corner, steps, 0.0, shape.seam, shape.bevel, body)
		&"body":
			var cut := shape.seat_centre.x
			var face := ShapeGeometry.block(mesh, body, Vector2.ONE * shape.corner, steps, shape.seam, top,
				shape.bevel, body, cut, false)
			var hole := ShapeGeometry.crossed(shape.opening(steps), cut)
			var outlines: Array[PackedVector2Array] = [face, hole, shape.recess(GcShape.LEDGE.x), shape.recess()]
			var heights: Array[float] = [top, shape.shelf(), shape.ledge(), shape.well_floor()]
			for step in heights.size() - 1:
				ShapeGeometry.holed(mesh, outlines[step], [outlines[step + 1]], heights[step], Vector3.BACK, body,
					PackedFloat32Array([cut]))
				ShapeGeometry.sunk(mesh, outlines[step + 1], heights[step + 1], heights[step], body,
					step == heights.size() - 2)
		&"collars":
			for centre: Vector2 in shape.buttons().values():
				var outer := ShapeGeometry.circle(centre, shape.notch_radius(), GcShape.CIRCLE_POINTS)
				var inner := ShapeGeometry.circle(centre, shape.button_radius + GcShape.BUTTON_CLEARANCE,
					GcShape.CIRCLE_POINTS)
				var low := top - GcShape.BUTTON_DEPTH
				ShapeGeometry.band(mesh, outer, inner, top, Vector3.BACK, body)
				ShapeGeometry.band(mesh, outer, inner, low, Vector3.FORWARD, body)
				ShapeGeometry.wall(mesh, outer, low, top, body)
				ShapeGeometry.sunk(mesh, inner, low, top, body, false)
		&"lid":
			ShapeGeometry.prism(mesh, shape.lid_outline(steps), top - shape.lid_thickness, top, body)
			at.origin = -shape.hinge()
		&"dimple":
			var dimple := ShapeGeometry.circle(shape.dimple_centre, shape.dimple_radius, GcShape.CIRCLE_POINTS)
			ShapeGeometry.flat(mesh, dimple, top + 0.05, Vector3.BACK, body)
			at.origin = -shape.hinge()
		&"lid_logo", &"maker_logo":
			# The console's name a hair over the dark face.
			var on_dimple := part == &"lid_logo"
			var centre := shape.dimple_centre if on_dimple else shape.lid_box().end - MAKER_INSET
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(centre, LOGOS[part]), top + (0.05 if on_dimple else 0.0))
			at.origin = -shape.hinge()
		&"power_label", &"reset_label", &"open_label":
			# Along the collar, the letters' tops away from the button.
			var button: Vector2 = shape.buttons()[StringName(part.trim_suffix("_label"))]
			var outwards := Vector2(-signf(button.x), 1.0).normalized()
			var centre := button + outwards * LABEL_REACH
			ShapeGeometry.decal(mesh, Rect2(-LOGOS[part] / 2.0, LOGOS[part]), top)
			at.origin = -shape.hinge()
			at *= Transform3D(Basis(Vector3.BACK, outwards.angle() - PI / 2.0),
				Vector3(centre.x, centre.y, 0.0) * MeshBuilder.UNITS_PER_MM)
		&"power", &"reset", &"open":
			var button := ShapeGeometry.circle(shape.buttons()[part], shape.button_radius, GcShape.CIRCLE_POINTS)
			ShapeGeometry.prism(mesh, button, top - GcShape.BUTTON_DEPTH, top + GcShape.BUTTON_RAISE, body)
		&"lamp":
			ShapeGeometry.flat(mesh, shape.lamp(), top + 0.05, Vector3.BACK, body)
		&"well":
			ShapeGeometry.flat(mesh, shape.recess(), shape.well_floor() + 0.05, Vector3.BACK, body)
		&"slot":
			ShapeGeometry.flat(mesh, shape.slot(), shape.well_floor() + 0.1, Vector3.BACK, body)
		&"panel", &"ports", &"port_dots":
			_front(mesh, shape, part, steps)
			at = Transform3D(Basis(), Vector3(0.0, 0.0, shape.depth / 2.0) * MeshBuilder.UNITS_PER_MM)
		&"grille", &"vents":
			_vents(mesh, shape, part)
		&"handle":
			var band := shape.handle_heights()
			ShapeGeometry.prism(mesh, _handle(shape), band.x, band.y, body)
		&"feet":
			for side: float in [-1.0, 1.0]:
				var centre := Vector2(side * (shape.width / 2.0 - FEET.x), -shape.depth / 2.0 + FEET.y)
				_box(mesh, AABB(Vector3(centre.x - FOOT.x / 2.0, centre.y - FOOT.y / 2.0, -FOOT.z), FOOT))
	return ShapeGeometry.moved(mesh.arrays(), at)


static func _box(mesh: MeshBuilder, box: AABB) -> void:
	var square := box.abs()
	var plan := Rect2(square.position.x, square.position.y, square.size.x, square.size.y)
	ShapeGeometry.prism(mesh, ShapeGeometry.square(plan), square.position.z, square.end.z, plan)


## The panel, its sides bulging, the ports on it (the controllers', the memory cards' slots) or the ports'
## numbers, on the front face: X to the right, Y up, Z out of it.
static func _front(mesh: MeshBuilder, shape: GcShape, part: StringName, steps: int) -> void:
	var size := shape.panel_size
	var bottom := shape.seam + shape.panel_lift
	var face := Rect2(-size.x / 2.0, bottom, size.x, size.y)
	if part == &"panel":
		var outline := PackedVector2Array()
		var sides := 2 * steps
		for side: float in [1.0, -1.0]:
			for k in sides + 1:
				var along := float(k) / sides
				var y := lerpf(bottom, bottom + size.y, along if side > 0.0 else 1.0 - along)
				outline.append(Vector2(side * (size.x / 2.0 + PANEL_BULGE * sin(PI * along)), y))
		# Its back deep in the body, behind the bevel along the seam.
		ShapeGeometry.prism(mesh, outline, -shape.bevel - 0.5, PANEL_RAISE, face)
		return
	if part == &"port_dots":
		# Just over the ports.
		var size_mm := LOGOS[part]
		var over := bottom + PORT_HEIGHT * size.y + PORT_RADIUS * size.x + 1.5
		ShapeGeometry.decal(mesh, Rect2(-size_mm.x / 2.0, over, size_mm.x, size_mm.y), PANEL_RAISE)
		return
	var out := PANEL_RAISE + 0.05
	for x in PORTS:
		var centre := Vector2(x * size.x, bottom + PORT_HEIGHT * size.y)
		ShapeGeometry.flat(mesh, ShapeGeometry.circle(centre, PORT_RADIUS * size.x, 32), out, Vector3.BACK, face)
	# Each memory card's slot: the groove round its flap.
	for x in SLOTS:
		var slot := Rect2(Vector2(x * size.x, bottom + SLOT_HEIGHT * size.y) - SLOT_SIZE * size / 2.0, SLOT_SIZE * size)
		ShapeGeometry.band(mesh, ShapeGeometry.square(slot),
			ShapeGeometry.square(slot.grow(-SLOT_GROOVE)), out, Vector3.BACK, face)


## The vents: on each side, a grid of bars standing out ([code]grille[/code]) over a dark back
## ([code]vents[/code]); and the back's slots and connectors, dark.
static func _vents(mesh: MeshBuilder, shape: GcShape, part: StringName) -> void:
	var vent := ShapeGeometry.centred(shape.vent_centre, shape.vent_size)
	var pitch := vent.size / Vector2(VENT_HOLES)
	for side: float in [-1.0, 1.0]:
		var face := side * shape.width / 2.0
		if part == &"vents":
			_box(mesh, AABB(Vector3(face - side, vent.position.x, vent.position.y), Vector3(side * 1.05, vent.size.x,
				vent.size.y)))
			continue
		var depth := Vector2(face - side, face + side * VENT_RAISE)
		for i in VENT_HOLES.x + 1:
			var y := vent.position.x + i * pitch.x
			_box(mesh, AABB(Vector3(depth.x, y - VENT_BAR / 2.0, vent.position.y),
				Vector3(depth.y - depth.x, VENT_BAR, vent.size.y)))
		for j in VENT_HOLES.y + 1:
			var z := vent.position.y + j * pitch.y
			_box(mesh, AABB(Vector3(depth.x, vent.position.x, z - VENT_BAR / 2.0),
				Vector3(depth.y - depth.x, vent.size.x, VENT_BAR)))
	if part == &"vents":
		var back := shape.depth / 2.0
		var boxes: Array[Vector4] = CONNECTORS.duplicate()
		for i in BACK_SLOTS:
			boxes.append(BACK_SLOT + Vector4(i * BACK_SLOT_PITCH, 0.0, 0.0, 0.0))
		for box in boxes:
			_box(mesh, AABB(Vector3(box.x * shape.width - box.z / 2.0, back - 1.0, box.y),
				Vector3(box.z, 1.05, box.w)))


## The handle's outline in plan, counter-clockwise: a band along an arc behind the back, its ends in
## the back's flat part.
static func _handle(shape: GcShape) -> PackedVector2Array:
	var span := shape.handle_span()
	var rise := shape.handle_reach + _HANDLE_BURIED
	var radius := (span * span / 4.0 + rise * rise) / (2.0 * rise)
	var centre := Vector2(0.0, shape.depth / 2.0 - _HANDLE_BURIED + rise - radius)
	var half := asin(span / 2.0 / radius)
	var outline := PackedVector2Array()
	for along: float in [radius, radius - GcShape.HANDLE_THICKNESS]:
		var arc := PackedVector2Array()
		for k in _HANDLE_POINTS + 1:
			arc.append(centre + Vector2.from_angle(PI / 2.0 - half + 2.0 * half * k / _HANDLE_POINTS) * along)
		if along < radius:
			arc.reverse()
		outline.append_array(arc)
	return outline
