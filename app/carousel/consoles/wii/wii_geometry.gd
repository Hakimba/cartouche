# SPDX-License-Identifier: GPL-3.0-or-later
class_name WiiGeometry
extends RefCounted
## Builds the Wii from its [WiiShape] as pure functions, so that tests check the geometry headless.
## The slab's blocks and everything on its front and back are laid out on the front (X across, Y up)
## and swept along Z, as the model has them; the side panels are laid out on a side and swept out of
## it; the flaps, the stand and its plate are laid out in plan (X across, Y towards the back) and
## swept up. The SD door is given around its hinge, the buttons at rest, as the model moves them.

const PARTS: Array[StringName] = [&"front", &"body", &"back", &"sides", &"flaps", &"rim", &"gap", &"door",
	&"well", &"sync", &"power", &"reset", &"eject", &"ports", &"sensor", &"stand", &"plate", &"logo", &"power_label",
	&"reset_label", &"eject_label", &"power_sign", &"eject_sign", &"sync_label", &"ati_logo", &"maker_logo"]
## The logos' faces, flat (see [method WiiShape.surfaces]), the size of their images: the console's
## name under the eject button, the buttons' names and the signs on the power and eject buttons, the
## sync button's name, and on the right side the graphics maker's logo and the maker's moulded name.
const LOGOS: Dictionary[StringName, Vector2] = {&"logo": Vector2(14.0, 7.4), &"power_label": Vector2(9.0, 3.2),
	&"reset_label": Vector2(9.0, 3.2), &"eject_label": Vector2(9.0, 3.2), &"power_sign": Vector2(8.6, 3.0),
	&"eject_sign": Vector2(8.6, 3.0), &"sync_label": Vector2(8.0, 3.2), &"ati_logo": Vector2(8.0, 8.6),
	&"maker_logo": Vector2(25.0, 8.6)}
## How far the console's name stands below the eject button, and each button's name from its button;
## how far the side's logos stand from the side panel's front and back ends, and below its top.
const LOGO_DROP := 4.55
const LABEL_GAP := 0.4
const SIDE_INSETS := Vector2(5.5, 8.0)
const SIDE_DROP := 8.5
const _DOOR_CORNER := 1.0
const _PANEL_CORNER := 2.0
const _PANEL_RAISE := 0.6
const _FLAP_RAISE := 0.4
## The connectors on the back, as fractions of its flat part seen from behind, from its top left
## corner: the USB pair, the vents, the AV and power ports; the sensor bar's, apart in its colour.
const _PORTS: Array[Rect2] = [Rect2(0.39, 0.12, 0.36, 0.1), Rect2(0.52, 0.61, 0.23, 0.15),
	Rect2(0.43, 0.78, 0.32, 0.07)]
const _VENTS := Rect2(0.07, 0.35, 0.77, 0.21)
const _VENT_ROWS := 5
const _SENSOR := Rect2(0.27, 0.64, 0.14, 0.06)


## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: WiiShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var at := Transform3D()
	var face := shape.face()
	var corners := Vector2.ONE * shape.corner
	var front := shape.depth / 2.0
	var back := -front
	match part:
		&"front":
			# Its back edge hidden in the body, so that only the body's bevel marks the joint.
			var opening := ShapeGeometry.rounded_box(shape.door_opening(), _DOOR_CORNER, steps)
			ShapeGeometry.block(mesh, face, corners, steps, front - shape.front_depth - shape.front_bevel, front,
				shape.front_bevel, face, NAN, true, opening)
		&"body":
			ShapeGeometry.block(mesh, face, corners, steps, back + shape.back_depth, front - shape.front_depth,
				shape.bevel, face)
		&"back":
			ShapeGeometry.block(mesh, face, corners, steps, back, back + shape.back_depth, shape.bevel, face)
		&"sides":
			var panel := shape.side_panel()
			var edge := shape.width / 2.0
			for side: Vector2 in [Vector2(edge - 0.5, edge + _PANEL_RAISE), Vector2(-edge - _PANEL_RAISE, -edge + 0.5)]:
				ShapeGeometry.block(mesh, panel, Vector2.ONE * _PANEL_CORNER, steps, side.x, side.y, 0.3, panel)
			at.basis = ShapeGeometry.SIDE
		&"flaps":
			var top := shape.face().end.y
			for span: Vector2 in [shape.memory_flap, shape.controller_flap]:
				var flap := shape.flap(span)
				ShapeGeometry.block(mesh, flap, Vector2.ONE * WiiShape.FLAP_CORNER, steps, top - 0.5,
					top + _FLAP_RAISE, 0.2, flap)
			at.basis = ShapeGeometry.PLAN
		&"rim":
			var slot := shape.slot()
			var through := ShapeGeometry.rounded_box(shape.gap(), shape.slot_gap / 2.0, steps)
			ShapeGeometry.block(mesh, slot, Vector2.ONE * shape.slot_rim / 2.0, steps, front - 0.5,
				front + WiiShape.RIM_RAISE, WiiShape.RIM_BEVEL, slot, NAN, true, through)
		&"gap":
			# The dark inside of the slot, a millimetre below its rim, that lights up.
			var inside := shape.gap().grow(-0.05)
			ShapeGeometry.block(mesh, inside, Vector2.ONE * inside.size.x / 2.0, steps, front - 0.4,
				front + WiiShape.RIM_RAISE - 1.0, 0.05, inside)
		&"door":
			var door := shape.door()
			ShapeGeometry.block(mesh, door, Vector2.ONE * (_DOOR_CORNER - WiiShape.DOOR_GAP), steps,
				front - WiiShape.DOOR_THICKNESS, front, 0.3, door)
			at.origin = -shape.door_hinge()
		&"well":
			var opening := shape.door_opening().grow(-0.05)
			ShapeGeometry.block(mesh, opening, Vector2.ONE * (_DOOR_CORNER - 0.05), steps, front - shape.front_depth,
				front - WiiShape.DOOR_WELL, 0.2, opening)
		&"sync":
			var sync := shape.sync_button()
			ShapeGeometry.block(mesh, sync, Vector2.ONE * 0.8, steps, front - WiiShape.DOOR_WELL - 0.5,
				front - WiiShape.DOOR_WELL + 1.0, 0.3, sync)
		&"power", &"reset", &"eject":
			var button := shape.button([&"power", &"reset", &"eject"].find(part))
			ShapeGeometry.block(mesh, button, Vector2.ONE * WiiShape.BUTTON_CORNER, steps, front - 0.5,
				front + WiiShape.BUTTON_RAISE, 0.5, button)
		&"logo":
			ShapeGeometry.decal(mesh, shape.logo(), front)
		&"power_label", &"reset_label", &"eject_label":
			# Under the power and reset buttons, over the eject one.
			var button := shape.button([&"power_label", &"reset_label", &"eject_label"].find(part))
			var size := LOGOS[part]
			var low := button.end.y + LABEL_GAP if part == &"eject_label" else button.position.y - LABEL_GAP - size.y
			ShapeGeometry.decal(mesh, Rect2(button.get_center().x - size.x / 2.0, low, size.x, size.y), front)
		&"power_sign", &"eject_sign":
			var button := shape.button(0 if part == &"power_sign" else 2)
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(button.get_center(), LOGOS[part]),
				front + WiiShape.BUTTON_RAISE)
		&"sync_label":
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(shape.sync_button().get_center(), LOGOS[part]),
				front - WiiShape.DOOR_WELL + 1.0)
		&"ati_logo", &"maker_logo":
			# On the right side's panel, near its top: one by its front, the other by its back.
			var panel := shape.side_panel()
			var size := LOGOS[part]
			var start := panel.position.x + SIDE_INSETS.x if part == &"ati_logo" else panel.end.x - SIDE_INSETS.y - size.x
			ShapeGeometry.decal(mesh, Rect2(start, panel.end.y - SIDE_DROP - size.y, size.x, size.y),
				shape.width / 2.0 + _PANEL_RAISE)
			at.basis = ShapeGeometry.SIDE
		&"ports":
			var flat := face.grow(-shape.corner - 0.5)
			for port in _PORTS:
				ShapeGeometry.prism(mesh, ShapeGeometry.square(_on_back(flat, port)), back - 0.3, back + 0.5)
			var cell := _VENTS.size / _VENT_ROWS
			for row in _VENT_ROWS:
				for column in _VENT_ROWS:
					var square := Rect2(_VENTS.position + cell * Vector2(column, row) + cell * 0.14, cell * 0.72)
					ShapeGeometry.prism(mesh, ShapeGeometry.square(_on_back(flat, square)), back - 0.3, back + 0.5)
		&"sensor":
			ShapeGeometry.prism(mesh, ShapeGeometry.square(_on_back(face.grow(-shape.corner - 0.5), _SENSOR)),
				back - 0.3, back + 0.5)
		&"stand":
			var opening := ShapeGeometry.rounded_box(shape.footprint().grow(WiiShape.STAND_GAP),
				shape.bevel + WiiShape.STAND_GAP, steps)
			var outer := shape.bevel + WiiShape.STAND_GAP + shape.stand_wall
			ShapeGeometry.block(mesh, shape.stand(), Vector2.ONE * outer, steps, shape.plate_thickness,
				shape.plate_thickness + shape.stand_height, WiiShape.STAND_BEVEL, shape.stand(), NAN, true, opening)
			at.basis = ShapeGeometry.PLAN
		&"plate":
			var plate := ShapeGeometry.square_around(Vector2.ZERO, shape.plate_radius)
			ShapeGeometry.block(mesh, plate, Vector2.ONE * shape.plate_radius, steps, 0.0, shape.plate_thickness,
				minf(0.8, shape.plate_thickness / 3.0), plate)
			at.basis = ShapeGeometry.PLAN
	return ShapeGeometry.moved(mesh.arrays(), at)


## [param fraction] of [param flat], the back's flat part, as seen from behind: its left is the
## model's right.
static func _on_back(flat: Rect2, fraction: Rect2) -> Rect2:
	var size := fraction.size * flat.size
	return Rect2(flat.end.x - (fraction.position.x * flat.size.x) - size.x,
		flat.end.y - (fraction.position.y * flat.size.y) - size.y, size.x, size.y)
