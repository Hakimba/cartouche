# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name ConsoleShape
extends ModelShape
## The dimensions of a top-loading console, in millimetres, as it lies on a table: its top up (+Y),
## its front towards +Z (see [ConsoleGeometry]). A rounded body in two blocks, the joint between
## them at [member seam]; a lid set in the top, hinged along its back edge, over the well where the
## drive's spindle holds the disc; ribs across the rest of the top. Plan positions are of centres,
## X to the right and Y towards the back, from the centre of the body.

@export var width := 230.0:
	set(value):
		width = value
		emit_changed()
@export var depth := 152.0:
	set(value):
		depth = value
		emit_changed()
@export var height := 28.0:
	set(value):
		height = value
		emit_changed()
@export var corner := 13.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 1.5:
	set(value):
		bevel = value
		emit_changed()
## Where the lower block ends and the upper one starts; the well's floor.
@export var seam := 10.0:
	set(value):
		seam = value
		emit_changed()
@export var lid_size := Vector2(138.0, 138.0):
	set(value):
		lid_size = value
		emit_changed()
@export var lid_centre := Vector2(-39.0, 1.0):
	set(value):
		lid_centre = value
		emit_changed()
@export var lid_corner := 8.0:
	set(value):
		lid_corner = value
		emit_changed()
@export var lid_thickness := 4.0:
	set(value):
		lid_thickness = value
		emit_changed()
## The gap all around the lid, between it and the edge of its opening.
@export var lid_gap := 1.0:
	set(value):
		lid_gap = value
		emit_changed()
## The height of a seated disc's centre, above the bottom of the body.
@export var seat_height := 19.5:
	set(value):
		seat_height = value
		emit_changed()
## The discs the well takes: they turn in it without touching its edge.
@export var disc_radius := 60.0:
	set(value):
		disc_radius = value
		emit_changed()
@export var rib_count := 14:
	set(value):
		rib_count = value
		emit_changed()
## The X of the first rib, then between two ribs.
@export var rib_start := 42.5:
	set(value):
		rib_start = value
		emit_changed()
@export var rib_pitch := 4.7:
	set(value):
		rib_pitch = value
		emit_changed()
@export var rib_width := 0.7:
	set(value):
		rib_width = value
		emit_changed()
@export var rib_length := 126.0:
	set(value):
		rib_length = value
		emit_changed()
@export var rib_raise := 0.3:
	set(value):
		rib_raise = value
		emit_changed()


func parts() -> Array[StringName]:
	return ConsoleGeometry.PARTS


func mesh_arrays(part: StringName, detail: int) -> Array:
	return ConsoleGeometry.arrays(self, part, detail)


func body() -> Rect2:
	return Rect2(-width / 2.0, -depth / 2.0, width, depth)


func lid_box() -> Rect2:
	return Rect2(lid_centre - lid_size / 2.0, lid_size)


## The opening the lid closes: the lid, grown by its gap.
func opening() -> Rect2:
	return lid_box().grow(lid_gap)


func ribs() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for i in rib_count:
		var x := rib_start + i * rib_pitch
		found.append(Rect2(x - rib_width / 2.0, -rib_length / 2.0, rib_width, rib_length))
	return found


## How round the ribs' ends are: short of a pill, which a rounded outline cannot draw.
func rib_corner() -> float:
	return 0.45 * minf(rib_width, rib_length)


## Where the lid turns, in the model's space: the back edge of its top, halfway through it.
func hinge() -> Vector3:
	return Vector3(0.0, height - lid_thickness / 2.0, -lid_box().end.y) * MeshBuilder.UNITS_PER_MM


## Where a seated disc's centre is, in the model's space, its axis (Z) pointing up.
func seat() -> Transform3D:
	var centre := Vector3(lid_centre.x, seat_height, -lid_centre.y) * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), centre)


func _rules() -> Dictionary[StringName, bool]:
	# The top, a millimetre inside its bevel, and the opening in it, both rounded.
	var top := body().grow(-bevel - 1.0)
	var top_corner := maxf(0.0, corner - bevel - 1.0)
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and height > 0.0 and lid_thickness > 0.0
			and lid_gap > 0.0 and disc_radius > 0.0,
		&"corner_rounds_the_bevel": corner > bevel + 0.1 and corner < minf(width, depth) / 2.0,
		&"blocks_hold_their_bevels": bevel > 0.0 and seam > 2.0 * bevel + 0.1
			and height - seam > 2.0 * bevel + 0.1,
		&"lid_inside_the_top": _within(opening(), lid_corner + lid_gap, top, top_corner),
		&"lid_corner_fits": lid_corner > 0.1 and lid_corner < minf(lid_size.x, lid_size.y) / 2.0 - 0.1,
		&"lid_thin_enough": lid_thickness < height - seam - 2.0,
		&"disc_turns_in_the_well": minf(lid_size.x, lid_size.y) / 2.0 > disc_radius + 1.0,
		&"seat_between_floor_and_lid": seat_height > seam + 2.0
			and seat_height < height - lid_thickness - 1.0,
		&"ribs_on_the_top_beside_the_lid": rib_count >= 0 and rib_width > 0.0 and rib_raise > 0.0
			and rib_width < rib_pitch and ribs().all(func(rib: Rect2) -> bool:
				return _within(rib, rib_corner(), top, top_corner) and not rib.grow(0.5).intersects(opening())),
	}


## Whether the rectangle [param inner], its corners rounded by [param inner_corner], lies within
## [param outer], rounded by [param outer_corner]: whether each of its corners' arcs does.
static func _within(inner: Rect2, inner_corner: float, outer: Rect2, outer_corner: float) -> bool:
	var inner_core := inner.grow(-inner_corner)
	var room := outer.grow(-outer_corner).grow(minf(0.0, outer_corner - inner_corner))
	var reach := maxf(0.0, outer_corner - inner_corner)
	for x: float in [inner_core.position.x, inner_core.end.x]:
		for y: float in [inner_core.position.y, inner_core.end.y]:
			var centre := Vector2(x, y)
			var nearest := centre.clamp(room.position, room.end)
			if centre.distance_to(nearest) > reach + 0.0001:
				return false
	return true
