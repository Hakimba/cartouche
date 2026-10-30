# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbGeometry
extends RefCounted
## Builds the Game Boy from its [GbShape] as pure functions, so that tests check the geometry
## headless. Parts on the front and the back are laid out in its plane (X right, Y up) and swept
## along Z, the model's own axes; parts on a side are laid out on it (X from the front backwards, Y
## up) and swept out of it, parts on the top or the bottom in plan (X right, Y from the front
## backwards) and swept up. Each outline is swept as a slab whose ends' edges are rounded or square
## ([method ShapeGeometry.slab]): the shells are slabs of the front's outline, the slot of the power
## switch and the cartridge's slot notched out of their tops, the plate closing the latter's back
## below the bay. What lies in the back is laid out seen from behind (see
## [constant ShapeGeometry.BEHIND]): its face with the screws' holes and the latch's notch sunk in it,
## the plate with the sticker's. The knob is given at rest, as the model moves it. The marks are their
## images' faces ([method ShapeGeometry.decal]).

const PARTS: Array[StringName] = [&"front_shell", &"back_shell", &"plates", &"battery_cover", &"cover_gap",
	&"ribs", &"screws", &"sticker", &"bezel",
	&"screen", &"stripe_upper", &"stripe_lower", &"led", &"dpad", &"buttons", &"pills", &"speaker", &"band",
	&"side_openings", &"phones", &"wheels", &"knob", &"slot", &"contacts", &"logo", &"dot_matrix",
	&"battery_label", &"a_label", &"b_label", &"select_label", &"start_label", &"power_label", &"phones_label"]
## How deep the parts on the front go into it, and how far the flat ones stand over it.
const _SUNK := 1.0
const _OVER := 0.05
const _GROOVE := 0.5
## The rounding of the power slot's corners, at the top and at its floor.
const _SLOT_CORNERS := Vector2(0.8, 0.5)


## The mesh arrays of [param part], its curves in [method ShapeGeometry.corner_steps].
static func arrays(shape: GbShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var at := Transform3D.IDENTITY
	var uv := shape.face_box()
	var front := shape.depth / 2.0
	var back := -front
	var seam := front - shape.seam
	if part in GbShape.MARKS:
		var size := GbShape.MARKS[part]
		ShapeGeometry.decal(mesh, ShapeGeometry.centred(shape.mark(part), size),
			front + (_GROOVE if part in GbShape.ON_BEZEL else 0.0))
	match part:
		&"front_shell":
			ShapeGeometry.slab(mesh, shape.face(0.0, steps), seam, front, Vector2(GbShape.SEAM_BEVEL, shape.bevel), uv)
		&"back_shell":
			var slot_back := seam - shape.power().size.y
			var bay_floor := back + shape.slot_thickness()
			var slot := Rect2(shape.power().position.x, shape.height - GbShape.SLOT_SINK, shape.power_slot,
				GbShape.SLOT_SINK)
			ShapeGeometry.slab(mesh, shape.notched(slot, _SLOT_CORNERS.x, _SLOT_CORNERS.y, steps), slot_back, seam,
				Vector2(0.0, GbShape.SEAM_BEVEL), uv)
			ShapeGeometry.slab(mesh, shape.face(0.0, steps), bay_floor, slot_back, Vector2.ZERO, uv)
			for rail in shape.rails():
				ShapeGeometry.slab(mesh, ShapeGeometry.rounded_box(rail, 0.5, steps), bay_floor - GbShape.RAIL_RISE,
					bay_floor + _OVER, Vector2(0.2, 0.0), uv)
			mesh.basis = ShapeGeometry.BEHIND
			var holes := shape.back_holes(steps)
			var face := ShapeGeometry.slab(mesh, shape.back_behind(steps), -bay_floor, front,
				Vector2(0.0, shape.back_bevel), uv, false)
			ShapeGeometry.holed(mesh, face, holes, front, Vector3.BACK, uv, shape.back_lines())
			for hole in holes:
				ShapeGeometry.sunk(mesh, hole, front - GbShape.SCREW_SINK, front, uv)
		&"plates":
			mesh.basis = ShapeGeometry.BEHIND
			var top := front + GbShape.BACK_RISE
			var sticker := ShapeGeometry.rounded_box(GbShape.STICKER, GbShape.STICKER_CORNER, steps, 0.0)
			var face := ShapeGeometry.slab(mesh, ShapeGeometry.rounded_box(shape.plate(), 1.5, steps, 0.0), front, top,
				Vector2(0.0, 0.8), uv, false)
			ShapeGeometry.holed(mesh, face, [sticker], top, Vector3.BACK, uv, PackedFloat32Array([0.0]))
			ShapeGeometry.sunk(mesh, sticker, top - GbShape.STICKER_SINK, top, uv)
		&"sticker":
			mesh.basis = ShapeGeometry.BEHIND
			ShapeGeometry.decal(mesh, GbShape.STICKER, front + GbShape.BACK_RISE - GbShape.STICKER_SINK)
		&"battery_cover":
			var top := back - GbShape.BACK_RISE
			ShapeGeometry.slab(mesh, shape.cover(0.0, steps), top, back + shape.back_bevel, Vector2(0.8, 0.0), uv)
			for rib in shape.cover_ribs():
				ShapeGeometry.slab(mesh, ShapeGeometry.square(rib), top - GbShape.COVER_RIB_RISE, top + 0.3,
					Vector2.ZERO, uv)
		&"cover_gap":
			ShapeGeometry.slab(mesh, shape.cover(GbShape.GAP, steps), back - _OVER, back + _SUNK, Vector2.ZERO, uv)
		&"ribs":
			for rib in shape.ribs():
				ShapeGeometry.slab(mesh, ShapeGeometry.square(rib), back - GbShape.RIB_RISE, back + 0.5, Vector2.ZERO,
					uv)
		&"screws":
			mesh.basis = ShapeGeometry.BEHIND
			var foot := front - GbShape.SCREW_SINK
			for screw in shape.screws():
				ShapeGeometry.slab(mesh, shape.disc(screw, GbShape.SCREW_HEAD.x, steps), foot - _OVER,
					foot + GbShape.SCREW_HEAD.y, Vector2(0.0, 0.3), uv)
		&"bezel":
			var rounds := GbShape.BEZEL_CORNERS
			var radii := PackedFloat32Array([rounds.x, rounds.y, rounds.x, rounds.x])
			ShapeGeometry.slab(mesh, ShapeGeometry.filleted(ShapeGeometry.square(shape.bezel()), radii, steps),
				front - _GROOVE, front + _GROOVE, Vector2(0.0, 0.3), uv)
		&"screen":
			ShapeGeometry.slab(mesh, ShapeGeometry.rounded_box(shape.screen(), GbShape.SCREEN_ROUND, steps), front,
				front + _GROOVE + _OVER, Vector2.ZERO, uv)
		&"stripe_upper", &"stripe_lower":
			var colour := 0 if part == &"stripe_upper" else 1
			for left: bool in [true, false]:
				ShapeGeometry.slab(mesh, ShapeGeometry.square(shape.stripe(colour, left)), front,
					front + _GROOVE + _OVER, Vector2.ZERO, uv)
		&"led":
			ShapeGeometry.slab(mesh, shape.disc(shape.led(), GbShape.LED_RADIUS, steps), front, front + 0.75,
				Vector2(0.0, 0.2), uv)
		&"dpad":
			ShapeGeometry.slab(mesh, shape.dpad(steps), front - _SUNK, front + GbShape.DPAD_RISE, Vector2(0.0, 0.8), uv)
		&"buttons":
			for centre: Vector2 in [shape.a_button, shape.b_button()]:
				ShapeGeometry.slab(mesh, shape.disc(centre, shape.button_diameter / 2.0, steps), front - _SUNK,
					front + GbShape.BUTTON_RISE, Vector2(0.0, 1.2), uv)
		&"pills":
			for select: bool in [true, false]:
				ShapeGeometry.slab(mesh, shape.pill(select, steps), front - _SUNK, front + GbShape.PILL_RISE,
					Vector2(0.0, 0.5), uv)
		&"speaker":
			for i in shape.speaker_slits:
				ShapeGeometry.slab(mesh, shape.slit(i, steps), front - _SUNK, front + _OVER, Vector2.ZERO, uv)
		&"band":
			var across := shape.width / 2.0 - shape.bevel
			var low := shape.band()
			var grooves: Array[Rect2] = [Rect2(-across, low - _GROOVE / 2.0, 2.0 * across, _GROOVE)]
			for side: float in [-1.0, 1.0]:
				var x := side * (shape.width / 2.0 - GbShape.BAND_END) - _GROOVE / 2.0
				grooves.append(Rect2(x, low, _GROOVE, shape.height - low - shape.bevel - 0.2))
			for groove in grooves:
				ShapeGeometry.slab(mesh, ShapeGeometry.square(groove), front - 0.3, front + _OVER, Vector2.ZERO, uv)
		&"side_openings":
			for side: float in [-1.0, 1.0]:
				var openings := shape.openings(side)
				var inside := side * (shape.width / 2.0 - _SUNK)
				var outside := side * (shape.width / 2.0 + _OVER)
				for opening in openings:
					var laid := Rect2(opening.position - Vector2(front, 0.0), opening.size)
					ShapeGeometry.slab(mesh, ShapeGeometry.rounded_box(laid, openings[opening], steps),
						minf(inside, outside), maxf(inside, outside), Vector2.ZERO, laid)
			at.basis = ShapeGeometry.SIDE
		&"phones":
			var jack := Vector2(GbShape.PHONES.x, GbShape.PHONES.y - front)
			ShapeGeometry.slab(mesh, shape.disc(jack, GbShape.PHONES.z, steps), -_OVER, _SUNK, Vector2.ZERO, uv)
			at.basis = ShapeGeometry.PLAN
		&"wheels":
			for side: float in [-1.0, 1.0]:
				var window := shape.window(side).get_center()
				var centre := Vector2(side * (shape.width / 2.0 + GbShape.WHEEL_OUT - GbShape.WHEEL_RADIUS), window.y)
				var middle := front - window.x
				ShapeGeometry.slab(mesh, shape.disc(centre, GbShape.WHEEL_RADIUS, steps),
					middle - GbShape.WHEEL_THICKNESS / 2.0, middle + GbShape.WHEEL_THICKNESS / 2.0,
					Vector2(0.3, 0.3), uv)
		&"slot":
			ShapeGeometry.slab(mesh, ShapeGeometry.square(shape.lock()), back + shape.slot_thickness() - _OVER,
				back + shape.slot_thickness() + _SUNK, Vector2.ZERO, uv)
			mesh.basis = ShapeGeometry.PLAN
			ShapeGeometry.connector(mesh, _laid(shape, shape.connector()), shape.slot().position.y,
				shape.slot().position.y + ShapeGeometry.CONNECTOR_HEIGHT)
		&"contacts":
			ShapeGeometry.contacts(mesh, _laid(shape, shape.connector()),
				shape.slot().position.y + ShapeGeometry.CONNECTOR_HEIGHT)
			at.basis = ShapeGeometry.PLAN
		&"knob":
			var laid := _laid(shape, shape.knob())
			ShapeGeometry.slab(mesh, ShapeGeometry.rounded_box(laid, 1.0, steps),
				shape.height - GbShape.SLOT_SINK - 0.5, shape.height + GbShape.KNOB_PROUD, Vector2(0.0, 0.8), laid)
			at.basis = ShapeGeometry.PLAN
	return ShapeGeometry.moved(mesh.arrays(), at)


## [param box], laid out seen from above from the front backwards, in plan (see [constant ShapeGeometry.PLAN]).
static func _laid(shape: GbShape, box: Rect2) -> Rect2:
	return Rect2(box.position - Vector2(0.0, shape.depth / 2.0), box.size)
