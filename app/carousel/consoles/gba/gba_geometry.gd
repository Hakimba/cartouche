# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbaGeometry
extends RefCounted
## Builds the Game Boy Advance from its [GbaShape] as pure functions, so that tests check the
## geometry headless. Parts on the face are laid out in its plane and swept towards it, which is the
## model's space already: X right, Y up, Z out of the face. The shells and the hump are swept
## through their outline, shrunk along the round edges (see [method ShapeGeometry.swept]); the
## hump's back leans forward down the console, and the cartridge's slot opens in its top, below the
## shells' by the cartridge's head: the hump is left open there and the slot's upright walls and
## floor close it. The shells' back is laid out seen from behind (see
## [constant ShapeGeometry.BEHIND]), the screws' holes sunk in it; what lies on the hump's back, in its
## frame. Parts on the top are laid out in plan and turned up; ports on the bottom lie in its frame
## where they are. Each shoulder button is given around its pivot, and the power switch's knob in its
## own frame, as the model moves them. The marks are their images' faces
## ([method ShapeGeometry.decal]), each turned about its centre.

const PARTS: Array[StringName] = [&"body", &"hump", &"bezel", &"screen", &"logo", &"plates", &"dpad",
	&"wells", &"buttons", &"led", &"speaker", &"link_port", &"bottom_ports", &"slot", &"contacts",
	&"shoulder_left", &"shoulder_right", &"side_panels", &"switch_knob", &"battery_cover", &"cover_gap",
	&"cover_mark", &"label", &"screws", &"nintendo",
	&"power_label", &"start_label", &"select_label", &"a_label", &"b_label", &"lens_logo"]
const _BEVEL_STEPS := 3
## How far flat details stand off the face they lie on.
const _OFF := 0.05
## Where the keys and plates start, inside the face.
const _SUNK := 1.0
## How far over the face the marks lie: on the lens, the maker's plate, the slanted plates and the
## keys' tops, as those parts are built.
const _MARKS_OVER: Dictionary[StringName, float] = {
	&"lens_logo": 0.5, &"nintendo": 0.3, &"power_label": 0.0, &"start_label": 0.3, &"select_label": 0.3,
	&"a_label": GbaShape.KEY_HEIGHT, &"b_label": GbaShape.KEY_HEIGHT,
}


## The mesh arrays of [param part], its curves in [method ShapeGeometry.corner_steps].
static func arrays(shape: GbaShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var at := Transform3D()
	var face := shape.face()
	var whole := Rect2(-shape.width / 2.0, -shape.height / 2.0, shape.width, shape.height)
	if part in GbaShape.MARKS:
		var size := GbaShape.MARKS[part]
		var placed := shape.mark(part)
		ShapeGeometry.decal(mesh, Rect2(-size / 2.0, size), face + _MARKS_OVER[part])
		at = Transform3D(Basis(Vector3.BACK, placed.get_rotation()),
			Vector3(placed.origin.x, placed.origin.y, 0.0) * MeshBuilder.UNITS_PER_MM)
	match part:
		&"body":
			var outline := func(inset: float) -> PackedVector2Array:
				return shape.body_outline(inset, steps)
			var rings := _rings(_body_levels(shape), outline, 0.0, 0.0)
			ShapeGeometry.joined(mesh, rings, whole)
			ShapeGeometry.flat(mesh, ShapeGeometry.plan(rings[-1]), face, Vector3.BACK, whole)
			mesh.basis = ShapeGeometry.BEHIND
			var back := Transform2D.FLIP_X * ShapeGeometry.plan(rings[0])
			back.reverse()
			var holes: Array[PackedVector2Array] = []
			for screw in shape.screws():
				holes.append(ShapeGeometry.rounded_box(ShapeGeometry.square_around(screw, GbaShape.SCREW_RADIUS),
					GbaShape.SCREW_RADIUS, steps))
			ShapeGeometry.holed(mesh, back, holes, -shape.back(), Vector3.BACK, whole, shape.screw_lines())
			for hole in holes:
				ShapeGeometry.sunk(mesh, hole, -shape.back() - GbaShape.SCREW_SINK, -shape.back(), whole)
		&"screws":
			mesh.basis = ShapeGeometry.BEHIND
			var foot := -shape.back() - GbaShape.SCREW_SINK
			for screw in shape.screws():
				var head := ShapeGeometry.square_around(screw, GbaShape.SCREW_HEAD.x)
				ShapeGeometry.block(mesh, head, Vector2.ONE * GbaShape.SCREW_HEAD.x, steps, foot - _OFF,
					foot + GbaShape.SCREW_HEAD.y, 0.3, head)
		&"hump":
			_hump(mesh, shape, steps, whole)
		&"bezel":
			ShapeGeometry.block(mesh, shape.bezel(), GbaShape.BEZEL_CORNERS, steps, face - _SUNK, face + 0.5, 0.4,
				shape.bezel())
		&"screen":
			ShapeGeometry.flat(mesh, ShapeGeometry.rounded_box(shape.screen(), 0.5, steps), face + 0.5 + _OFF,
				Vector3.BACK, shape.screen())
		&"logo":
			var ends := Vector2.ONE * GbaShape.LOGO.y / 2.0
			ShapeGeometry.block(mesh, shape.logo(), ends, steps, face - _SUNK, face + 0.3, 0.2, shape.logo())
		&"plates":
			for plate in shape.plates(steps):
				ShapeGeometry.prism(mesh, plate, face - _SUNK, face + 0.3)
		&"dpad":
			for bar in shape.dpad_bars():
				ShapeGeometry.block(mesh, bar, Vector2.ONE * 1.2, steps, face - _SUNK, face + GbaShape.KEY_HEIGHT,
					0.8, bar)
		&"wells":
			var bars := shape.dpad_bars()
			ShapeGeometry.flat(mesh, ShapeGeometry.cross(bars[0].grow(0.8), bars[1].grow(0.8)), face + _OFF,
				Vector3.BACK, whole)
		&"buttons":
			for button: Rect2 in shape.round_controls().slice(0, 4):
				var size := button.size.x
				var top := face + (GbaShape.KEY_HEIGHT if size > GbaShape.SMALL_BUTTON else 1.5)
				ShapeGeometry.block(mesh, button, Vector2.ONE * size / 2.0, steps, face - _SUNK, top,
					size / 6.0, button)
		&"led":
			var light: Rect2 = shape.round_controls()[4]
			ShapeGeometry.block(mesh, light, Vector2.ONE * GbaShape.LED_SIZE / 2.0, steps, face - 0.5,
				face + 0.6, 0.5, light)
		&"speaker":
			for slit in shape.slits():
				ShapeGeometry.prism(mesh, slit, face - _SUNK, face + _OFF)
		&"link_port":
			var port := shape.link_port()
			ShapeGeometry.flat(mesh, ShapeGeometry.rounded_box(port, 0.6, steps), shape.height / 2.0 + _OFF,
				Vector3.BACK, port)
			at.basis = ShapeGeometry.PLAN
		&"slot":
			ShapeGeometry.connector(mesh, shape.connector(), shape.slot_floor(),
				shape.slot_floor() + ShapeGeometry.CONNECTOR_HEIGHT)
			at.basis = ShapeGeometry.PLAN
		&"contacts":
			ShapeGeometry.contacts(mesh, shape.connector(), shape.slot_floor() + ShapeGeometry.CONNECTOR_HEIGHT)
			at.basis = ShapeGeometry.PLAN
		&"bottom_ports":
			for port: Array in shape.bottom_ports(steps):
				var frame: Transform3D = port[0]
				var loop: PackedVector2Array = port[1]
				var origin := frame.basis.inverse() * frame.origin
				var laid := Transform2D(0.0, Vector2(origin.x, origin.y)) * loop
				mesh.basis = frame.basis
				ShapeGeometry.flat(mesh, laid, origin.z + _OFF, Vector3.BACK, ShapeGeometry.bounds(laid))
		&"shoulder_left", &"shoulder_right":
			var right := part == &"shoulder_right"
			_grey(mesh, shape, true, right, steps, whole)
			at.origin = -shape.shoulder_pivot(right)
		&"side_panels":
			for right: bool in [false, true]:
				_grey(mesh, shape, false, right, steps, whole)
		&"switch_knob":
			# In its frame on the bottom: along it, towards the face, out of the console; its grip's ridge
			# across it.
			var knob := Rect2(-GbaShape.SWITCH_KNOB / 2.0, GbaShape.SWITCH_KNOB)
			ShapeGeometry.block(mesh, knob, Vector2.ONE * 0.8, steps, -1.0, 1.2, 0.4, knob)
			var ridge := Rect2(-0.4, knob.position.y, 0.8, knob.size.y)
			ShapeGeometry.block(mesh, ridge, Vector2.ONE * 0.3, steps, 0.9, 1.7, 0.2, ridge)
		&"battery_cover":
			var recesses: Array[PackedVector2Array] = [
				ShapeGeometry.rounded_box(GbaShape.PANEL, GbaShape.PANEL_CORNER, steps, 0.0),
				ShapeGeometry.rounded_box(GbaShape.LATCH_NOTCH, 0.5, steps, 0.0)]
			var top := ShapeGeometry.slab(mesh, shape.cover(0.0, steps), -0.5, GbaShape.COVER_RAISE, Vector2(0.0, 0.2),
				whole, false)
			ShapeGeometry.holed(mesh, top, recesses, GbaShape.COVER_RAISE, Vector3.BACK, whole,
				PackedFloat32Array([0.0]))
			for hole in recesses:
				ShapeGeometry.sunk(mesh, hole, GbaShape.COVER_RAISE - GbaShape.PANEL_SINK, GbaShape.COVER_RAISE, whole)
			at = shape.back_frame()
		&"cover_gap":
			ShapeGeometry.slab(mesh, shape.cover(GbaShape.COVER_GAP, steps), -0.5, _OFF, Vector2.ZERO, whole)
			at = shape.back_frame()
		&"cover_mark":
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(GbaShape.PANEL.get_center(), GbaShape.COVER_MARK),
				GbaShape.COVER_RAISE - GbaShape.PANEL_SINK)
			at = shape.back_frame()
		&"label":
			ShapeGeometry.decal(mesh, GbaShape.LABEL, 0.0)
			at = shape.back_frame()
	return ShapeGeometry.moved(mesh.arrays(), at)


## The shells' levels, each an inset and a Z, from their back to the face: the back's round edge,
## the seam's groove, the face's round edge.
static func _body_levels(shape: GbaShape) -> Array[Vector2]:
	var levels: Array[Vector2] = []
	for k in _BEVEL_STEPS + 1:
		var angle := PI / 2.0 * k / _BEVEL_STEPS
		levels.append(Vector2(GbaShape.BACK_BEVEL * (1.0 - sin(angle)),
			shape.back() + GbaShape.BACK_BEVEL * (1.0 - cos(angle))))
	for step: Vector2 in [Vector2(0.0, -1.0), Vector2(1.0, -1.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
		levels.append(Vector2(0.0, shape.seam()) + step * GbaShape.SEAM_GROOVE)
	for k in _BEVEL_STEPS + 1:
		var angle := PI / 2.0 * k / _BEVEL_STEPS
		levels.append(Vector2(shape.bevel * (1.0 - cos(angle)), shape.face() - shape.bevel * (1.0 - sin(angle))))
	return levels


## Adds the hump, swept through its levels (see [method _hump_levels]), its top left open over the
## slot, between the end of its back's round edge and the shells' back; the slot's walls, upright,
## and its floor close it (see [method ShapeGeometry.sunk]).
static func _hump(mesh: MeshBuilder, shape: GbaShape, steps: int, uv: Rect2) -> void:
	var half := shape.slot_width / 2.0
	var outline := func(inset: float) -> PackedVector2Array:
		return shape.outline(shape.hump_width / 2.0, GbaShape.HUMP_CORNER, inset, GbaShape.HUMP_GAP, steps,
			PackedFloat32Array([half]), shape.hump_top())
	var top := shape.hump_top()
	var rings := _rings(_hump_levels(shape), outline, shape.hump_lean(), top)
	# The slot's back edge is on the last ring of the round edge, its front one on the next; along
	# the top the outline runs from the right to the left.
	var back := _BEVEL_STEPS
	var plan: PackedVector2Array = outline.call(0.0)
	var from := ShapeGeometry.cuts(plan, half)[1]
	var to := ShapeGeometry.cuts(plan, -half)[1]
	ShapeGeometry.swept(mesh, rings, uv, PackedVector2Array(), Rect2i(from, back, to - from, 1))
	var hole := PackedVector2Array()
	for i in range(to, from - 1, -1):
		hole.append(Vector2(rings[back + 1][i].x, -rings[back + 1][i].z))
	for i in range(from, to + 1):
		hole.append(Vector2(rings[back][i].x, -rings[back][i].z))
	mesh.basis = ShapeGeometry.PLAN
	ShapeGeometry.sunk(mesh, hole, shape.slot_floor(), top, uv)
	mesh.basis = Basis()


## The hump's levels at its top, from its back's round edge to inside the shells, where its top
## meets theirs flush: past the round of their back edges. The shells' back, the slot's front wall,
## is one of them.
static func _hump_levels(shape: GbaShape) -> Array[Vector2]:
	var levels: Array[Vector2] = []
	for k in _BEVEL_STEPS + 1:
		var angle := PI / 2.0 * k / _BEVEL_STEPS
		levels.append(Vector2(GbaShape.HUMP_BEVEL * (1.0 - sin(angle)),
			shape.hump_back() + GbaShape.HUMP_BEVEL * (1.0 - cos(angle))))
	levels.append_array([Vector2(0.0, shape.back()), Vector2(0.0, shape.back() + GbaShape.BACK_BEVEL)])
	return levels


## Adds the grey part at the right end or the left (`right`), the shoulder button (`button`) or the
## panel (see [method GbaShape.grey_end]): swept over the back shell's edge from the back's round
## edge to the seam, standing off it, its inner side inside the shells.
static func _grey(mesh: MeshBuilder, shape: GbaShape, button: bool, right: bool, steps: int, uv: Rect2) -> void:
	var inner := shape.grey_end(button, GbaShape.GREY_DEPTH, steps)
	var centre := Vector2(GbaShape.BACK_BEVEL, shape.back() + GbaShape.BACK_BEVEL)
	var levels: Array[Vector2] = []
	for level: Vector2 in _body_levels(shape).slice(0, _BEVEL_STEPS + 1):
		levels.append(level + (level - centre).normalized() * _OFF)
	levels.append(Vector2(-_OFF, shape.seam() - GbaShape.SEAM_GROOVE + _OFF))
	var rings: Array[PackedVector3Array] = []
	for level in levels:
		var outer := shape.grey_end(button, level.x, steps)
		# Its ends' walls start a hair inside, so that the outer face keeps its own normals there.
		var loop := PackedVector2Array([outer[0].move_toward(inner[0], 0.01)]) + outer
		loop.append(outer[-1].move_toward(inner[-1], 0.01))
		for i in range(inner.size() - 1, -1, -1):
			loop.append(inner[i])
		if not right:
			loop = Transform2D.FLIP_X * loop
			loop.reverse()
		var ring := PackedVector3Array()
		for point in loop:
			ring.append(Vector3(point.x, point.y, level.y))
		rings.append(ring)
	ShapeGeometry.swept(mesh, rings, uv)


## The rings of an outline, its [param outline] shrunk by each level's inset at its Z, leaning
## forward [param lean] for each millimetre below [param top].
static func _rings(levels: Array[Vector2], outline: Callable, lean: float,
		top: float) -> Array[PackedVector3Array]:
	var rings: Array[PackedVector3Array] = []
	for level in levels:
		var ring := PackedVector3Array()
		var loop: PackedVector2Array = outline.call(level.x)
		for point in loop:
			ring.append(Vector3(point.x, point.y, level.y + lean * (top - point.y)))
		rings.append(ring)
	return rings
