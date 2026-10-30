# SPDX-License-Identifier: GPL-3.0-or-later
class_name PsxGeometry
extends RefCounted
## Builds the first PlayStation from its [PsxShape] as pure functions, so that tests check the
## geometry headless. Each part is laid out in plan, X to the right and Y towards the back, swept up
## along Z, then turned into the model's space: top up (+Y), front towards +Z. The wings and the
## deck are not rectangles (the well's arc cuts the one and widens the other), so they are slabs of
## any outline (see [method ShapeGeometry.slab]). The deck is one solid with the well sunk in it.
## The lid is given around its hinge and each moving button around the middle of its top, which the
## model moves them about. The drive lies on the well's floor. The details on the bay's front and on
## the back are boxes and jacks on their faces, laid out in the model's space (see
## [constant DETAILS]). Each logo is a face of its own (see [method ShapeGeometry.decal]): the lid's
## around its hinge, a button's word around its top, those on the bay's front as the details.

const PARTS: Array[StringName] = [&"left", &"right", &"centre", &"lid", &"power", &"reset", &"open",
	&"grooves", &"light", &"vents", &"louvres", &"drive", &"lens", &"frames", &"controller_ports", &"dark",
	&"audio_right", &"audio_left", &"video", &"lid_logo", &"sony", &"power_label", &"open_label",
	&"reset_label", &"port_1", &"port_2", &"memory_card"]
## The details on the bay's front and on the back, by part, in groups on one face (`bay` or
## `back`), each sinking into it and standing out of it as far as its Vector2 says; each of its
## boxes is its centre's X from the middle and Y from the bottom, its width and its height.
const DETAILS: Dictionary[StringName, Array] = {
	# The memory cards' frames; the lobes of the controllers' ports.
	&"frames": [[&"bay", Vector2(-0.4, 0.6), [Vector4(-34.0, 19.0, 50.0, 22.0), Vector4(34.0, 19.0, 50.0, 22.0)]],
		[&"bay", Vector2(0.0, 1.0), [Vector4(-47.0, 15.0, 11.5, 5.0), Vector4(-34.0, 15.0, 11.5, 5.0),
			Vector4(-21.0, 15.0, 11.5, 5.0), Vector4(21.0, 15.0, 11.5, 5.0), Vector4(34.0, 15.0, 11.5, 5.0),
			Vector4(47.0, 15.0, 11.5, 5.0)]]],
	&"controller_ports": [[&"bay", Vector2(-0.2, 0.8), [Vector4(-34.0, 15.0, 40.0, 8.5),
		Vector4(34.0, 15.0, 40.0, 8.5)]]],
	# The memory cards' slots; the parallel, serial, AV and mains connectors.
	&"dark": [[&"bay", Vector2(-0.2, 0.8), [Vector4(-34.0, 27.0, 42.0, 1.2), Vector4(34.0, 27.0, 42.0, 1.2)]],
		[&"back", Vector2(-0.4, 0.6), [Vector4(98.0, 17.0, 42.0, 12.0), Vector4(52.0, 21.0, 12.0, 6.0),
			Vector4(-32.0, 21.0, 16.0, 5.0), Vector4(-102.0, 17.0, 17.0, 9.0)]]],
}
## The audio and video jacks on the back, by part, their centres' X from the middle; their centres'
## Y, their radius, how far they sink into the back and stand out of it.
const JACKS: Dictionary[StringName, float] = {&"audio_right": 32.0, &"audio_left": 20.0, &"video": 8.0}
const JACK := Vector4(21.0, 3.2, -0.5, 3.5)
## The logos on the bay's front, each its centres as a box of [constant DETAILS] and how far out of
## the bay it lies (on a memory card's frame).
const ON_BAY: Dictionary[StringName, Array] = {&"port_1": [Vector3(-34.0, 33.6, 0.0)],
	&"port_2": [Vector3(34.0, 33.6, 0.0)], &"memory_card": [Vector3(-34.0, 23.0, 0.6), Vector3(34.0, 23.0, 0.6)]}
## The drive on the well's floor, under the disc: its centre from the well's, in plan, its size and
## height; the laser's lens on it, a flattened ball: its centre from the well's, its radius, its
## half height and how high its centre stands over the floor.
const _DRIVE := Vector2(12.0, 10.0)
const _DRIVE_SIZE := Vector3(66.0, 56.0, 2.0)
const _LENS := Vector2(24.0, 30.0)
const _LENS_SIZE := Vector3(2.2, 0.44, 2.5)
## Points around a jack or the lens, and rings of the lens from pole to pole.
const _ROUND_POINTS := 16
const _LENS_RINGS := 7
## Each logo's size in millimetres, its image's (`psx_<part>.svg`).
const LOGOS: Dictionary[StringName, Vector2] = {
	&"lid_logo": Vector2(26.0, 22.5), &"sony": Vector2(29.0, 7.0), &"power_label": Vector2(18.0, 4.0),
	&"open_label": Vector2(15.0, 4.0), &"reset_label": Vector2(11.0, 3.0), &"port_1": Vector2(5.0, 6.0),
	&"port_2": Vector2(5.0, 6.0), &"memory_card": Vector2(24.0, 3.0),
}
## Where the lid's logos are centred, from its centre, in plan.
const _ON_LID: Dictionary[StringName, Vector2] = {&"lid_logo": Vector2(0.0, -20.25), &"sony": Vector2(0.0, 49.0)}
## How far the moving buttons stand above the wings, and how deep they go into them.
const BUTTON_PROUD := 1.5
const BUTTON_DEPTH := 3.0


## The mesh arrays of [param part], its curves in [param detail] steps.
static func arrays(shape: PsxShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var count := 16 * steps
	var mesh := MeshBuilder.new()
	var body := shape.body()
	var at := Transform3D(ShapeGeometry.PLAN, Vector3.ZERO)
	var notch := ShapeGeometry.circle(shape.lid_centre, shape.notch(), count)
	match part:
		&"left", &"right":
			var side := -1 if part == &"left" else 1
			var wing := ShapeGeometry.rounded_box(shape.wing_box(side), shape.corner, steps)
			# Points closer than half a millimetre made one: a shorter side would fold as the bevel moves its ends in.
			ShapeGeometry.slab(mesh, ShapeGeometry.ccw(Geometry2D.clip_polygons(wing, notch)[0], 0.5), 0.0, shape.height,
				Vector2.ONE * shape.bevel, body)
		&"centre":
			var deck := ShapeGeometry.square(shape.centre_box())
			var well := ShapeGeometry.circle(shape.lid_centre, shape.opening(), count)
			_sunk(mesh, ShapeGeometry.ccw(Geometry2D.merge_polygons(deck, notch)[0], 0.5), 0.0, shape.deck(), shape.bevel, body, well,
				shape.deck() - shape.well_depth)
		&"lid":
			var lid := ShapeGeometry.circle(shape.lid_centre, shape.lid_radius, count)
			var top := shape.deck() + shape.lid_raise
			ShapeGeometry.slab(mesh, lid, top - shape.lid_thickness, top,
				Vector2.ONE * minf(shape.bevel, shape.lid_thickness / 3.0), body)
			at.origin = -shape.hinge()
		&"power", &"reset", &"open", &"power_label", &"reset_label", &"open_label":
			var pressed := StringName(part.trim_suffix("_label"))
			var button := shape.buttons()[pressed]
			var centre := Vector2(button.x, button.y)
			var top := shape.height + BUTTON_PROUD
			if part == pressed:
				ShapeGeometry.slab(mesh, ShapeGeometry.circle(centre, button.z, 4 * steps), top - BUTTON_DEPTH, top,
					Vector2.ONE * minf(0.6, button.z / 4.0), body)
			else:
				ShapeGeometry.decal(mesh, ShapeGeometry.centred(centre, LOGOS[part]), top)
			# A button that moves about its top, which the model moves; the reset one where it is drawn.
			if pressed != &"reset":
				at.origin = -button_top(shape, pressed)
		&"grooves":
			var on_top := shape.height + 0.1
			for button: Vector3 in shape.buttons().values():
				var centre := Vector2(button.x, button.y)
				ShapeGeometry.band(mesh, ShapeGeometry.circle(centre, button.z + shape.groove, 4 * steps),
					ShapeGeometry.circle(centre, button.z, 4 * steps), on_top, Vector3.BACK, body)
			var towards := (shape.open_centre - shape.lid_centre).normalized()
			var across := towards.orthogonal() * shape.groove / 2.0
			var from := shape.lid_centre + towards * shape.notch()
			var to := shape.open_centre - towards * (shape.button_radius + shape.groove)
			var strip := PackedVector2Array([from - across, to - across, to + across, from + across])
			ShapeGeometry.flat(mesh, strip, on_top, Vector3.BACK, body)
		&"light":
			ShapeGeometry.prism(mesh, ShapeGeometry.square(shape.light_box()), shape.height - 1.0, shape.height + 0.15,
				body)
		&"vents":
			for vent in shape.vents():
				for side: float in [1.0, -1.0]:
					var placed := Rect2(vent.position * Vector2(side, 1.0), vent.size * Vector2(side, 1.0))
					ShapeGeometry.prism(mesh, ShapeGeometry.square(placed.abs()), shape.vent_band.x, shape.vent_band.y,
						body)
		&"louvres":
			var reach := ((shape.vent_count - 1) * shape.vent_pitch + shape.vent_width) / 2.0 + 1.0
			for side: float in [1.0, -1.0]:
				var x := side * (shape.width / 2.0 + 0.1)
				var normal := Vector3(side, 0.0, 0.0)
				var corners: Array[int] = []
				for point: Vector2 in [Vector2(-reach, shape.vent_band.x), Vector2(reach, shape.vent_band.x),
						Vector2(reach, shape.vent_band.y), Vector2(-reach, shape.vent_band.y)]:
					corners.append(mesh.add(Vector3(x, point.x, point.y), normal, Vector2.ZERO))
				mesh.quad(corners[0], corners[1], corners[2], corners[3])
		&"lid_logo", &"sony":
			ShapeGeometry.decal(mesh, ShapeGeometry.centred(shape.lid_centre + _ON_LID[part], LOGOS[part]),
				shape.deck() + shape.lid_raise)
			at.origin = -shape.hinge()
		&"drive":
			var floor_height := shape.deck() - shape.well_depth
			var box := Rect2(shape.lid_centre + _DRIVE - Vector2(_DRIVE_SIZE.x, _DRIVE_SIZE.y) / 2.0,
				Vector2(_DRIVE_SIZE.x, _DRIVE_SIZE.y))
			ShapeGeometry.prism(mesh, ShapeGeometry.square(box), floor_height, floor_height + _DRIVE_SIZE.z)
		&"lens":
			var centre := shape.deck() - shape.well_depth + _LENS_SIZE.z
			var rings: Array[PackedVector3Array] = []
			for k in _LENS_RINGS + 1:
				var angle := PI * (1.0 - float(k) / _LENS_RINGS)
				var ring := PackedVector3Array()
				var radius := maxf(sin(angle), ShapeGeometry.TIP) * _LENS_SIZE.x
				for point in ShapeGeometry.circle(shape.lid_centre + _LENS, radius,
						_ROUND_POINTS):
					ring.append(Vector3(point.x, point.y, centre + cos(angle) * _LENS_SIZE.y))
				rings.append(ring)
			ShapeGeometry.swept(mesh, rings, body)
		&"frames", &"controller_ports", &"dark":
			for group: Array in DETAILS[part]:
				var on: StringName = group[0]
				var depths: Vector2 = group[1]
				var boxes: Array = group[2]
				ShapeGeometry.boxes_on(mesh, boxes, _face(shape, on), depths)
			at = Transform3D.IDENTITY
		&"audio_right", &"audio_left", &"video":
			var back := _face(shape, &"back")
			ShapeGeometry.prism(mesh, ShapeGeometry.circle(Vector2(JACKS[part], JACK.x), JACK.y, _ROUND_POINTS),
				back - JACK.w, back - JACK.z)
			at = Transform3D.IDENTITY
		_:
			for place: Vector3 in ON_BAY[part]:
				ShapeGeometry.decal(mesh, ShapeGeometry.centred(Vector2(place.x, place.y), LOGOS[part]),
					_face(shape, &"bay") + place.z)
			at = Transform3D.IDENTITY
	return ShapeGeometry.moved(mesh.arrays(), at)


## The Z of [param face] in the model's space (see [constant DETAILS]): the bay's front, set back
## from the wings', or the back.
static func _face(shape: PsxShape, face: StringName) -> float:
	return shape.depth / 2.0 - shape.bay if face == &"bay" else -shape.depth / 2.0


## The middle of [param part]'s top (a button), at rest, in the model's space: where it is pressed.
static func button_top(shape: PsxShape, part: StringName) -> Vector3:
	var button := shape.buttons()[part]
	return ShapeGeometry.PLAN * Vector3(button.x, button.y, shape.height + BUTTON_PROUD) * MeshBuilder.UNITS_PER_MM


## Adds the solid of [param outline] (counter-clockwise, no point twice) from [param back] to [param
## front], its edges rounded by [param bevel], with [param well] (a circle in a multiple of 4
## points, counter-clockwise, inside the top, the line from front to back through its centre
## crossing the top where its edges are straight) sunk in it down to [param well_floor].
static func _sunk(mesh: MeshBuilder, outline: PackedVector2Array, back: float, front: float, bevel: float,
		uv: Rect2, well: PackedVector2Array, well_floor: float) -> void:
	# The top around the well is made of two halves, either side of the line through its centre.
	var cut := well[int(well.size() / 4.0)].x
	var face := ShapeGeometry.slab(mesh, ShapeGeometry.crossed(outline, cut), back, front, Vector2.ONE * bevel, uv,
		false)
	ShapeGeometry.holed(mesh, face, [well], front, Vector3.BACK, uv, PackedFloat32Array([cut]))
	ShapeGeometry.sunk(mesh, well, well_floor, front, uv)
