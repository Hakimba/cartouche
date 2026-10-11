# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name Ps2SlimShape
extends ModelShape
## The dimensions of the PS2 slim, a top-loading console, in millimetres, as it lies on a table:
## its top up (+Y), its front towards +Z (see [Ps2SlimGeometry]). A body of sharp edges in two
## parts, the joint between them at [member seam]: below it the base, set back under the lid's side
## by [member base_inset], the other side reaching the edges; above it thin slabs, cut all around by
## grooves. A lid as wide as that side of the top, hinged along its back edge over the well where
## the drive's spindle holds the disc; beside it a raised strip across the top, from front to back.
## Plan positions are of centres, X to the right and Y towards the back, from the centre of the body.

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
@export var corner := 1.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 0.4:
	set(value):
		bevel = value
		emit_changed()
## Where the base ends and the slabs start; the well's floor.
@export var seam := 10.0:
	set(value):
		seam = value
		emit_changed()
@export var lid_size := Vector2(129.0, 146.0):
	set(value):
		lid_size = value
		emit_changed()
@export var lid_centre := Vector2(47.5, 0.0):
	set(value):
		lid_centre = value
		emit_changed()
@export var lid_corner := 1.0:
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
## The raised strip beside the lid: the X of its centre, its size and how far it stands out.
@export var strip_x := -25.3:
	set(value):
		strip_x = value
		emit_changed()
@export var strip_width := 13.4:
	set(value):
		strip_width = value
		emit_changed()
@export var strip_length := 149.0:
	set(value):
		strip_length = value
		emit_changed()
@export var strip_raise := 0.2:
	set(value):
		strip_raise = value
		emit_changed()
## How far the base is set back under the lid's side: from the front, the side and the back.
@export var base_inset := Vector3(5.0, 12.0, 8.0):
	set(value):
		base_inset = value
		emit_changed()
## The grooves around the slabs, the first under the top slab, as thick as the lid; those that
## would leave a slab too thin for its bevels are left out, and all of them when they would reach
## the lid's opening.
@export var groove_count := 3:
	set(value):
		groove_count = value
		emit_changed()
## From the top of a groove to the top of the next one down.
@export var groove_pitch := 4.6:
	set(value):
		groove_pitch = value
		emit_changed()
@export var groove_height := 1.2:
	set(value):
		groove_height = value
		emit_changed()
@export var groove_depth := 1.5:
	set(value):
		groove_depth = value
		emit_changed()


func parts() -> Array[StringName]:
	return Ps2SlimGeometry.PARTS


func surfaces() -> Array[StringName]:
	var logos: Array[StringName] = []
	logos.assign(Ps2SlimGeometry.LOGOS.keys())
	return logos


func body() -> Rect2:
	return Rect2(-width / 2.0, -depth / 2.0, width, depth)


func lid_box() -> Rect2:
	return ShapeGeometry.centred(lid_centre, lid_size)


## The opening the lid closes: the lid, grown by its gap.
func opening() -> Rect2:
	return lid_box().grow(lid_gap)


func strip() -> Rect2:
	return Rect2(strip_x - strip_width / 2.0, -strip_length / 2.0, strip_width, strip_length)


## How round the strip's ends are: no rounder than the body's corners, a pill at most.
func strip_corner() -> float:
	return minf(corner, minf(strip_width, strip_length) / 2.0)


## The base under the lid's side, set back from the edges, in plan: from the opening's side to
## [member base_inset] in from the body's.
func base_box() -> Rect2:
	var from := Vector2(opening().position.x, body().position.y + base_inset.x)
	return Rect2(from, Vector2(body().end.x - base_inset.y, body().end.y - base_inset.z) - from)


## The heights of the grooves' bottoms (x) and tops (y), from the bottom up: laid from the top
## down, each leaves the slabs above and below it thick enough for their bevels; none when they
## would reach the opening.
func grooves() -> Array[Vector2]:
	var found: Array[Vector2] = []
	var inside := groove_box().grow(-groove_bevel() - 0.1)
	if not ShapeGeometry.fits(opening(), lid_corner + lid_gap, inside,
			Vector2.ONE * maxf(0.0, groove_corner() - groove_bevel() - 0.1)):
		return found
	var holds := 2.0 * bevel + 0.1
	var above := height
	for k in groove_count:
		var top := height - lid_thickness - k * groove_pitch
		if above - top < holds or top - groove_height - seam < holds:
			break
		found.append(Vector2(top - groove_height, top))
		above = top - groove_height
	found.reverse()
	return found


## The plan of the body inside the grooves, and its corners: as round as the body's, but always
## rounder than the grooves' edges.
func groove_box() -> Rect2:
	return body().grow(-groove_depth)


func groove_corner() -> float:
	return maxf(corner - groove_depth, groove_bevel() + 0.05)


## How round the grooves' edges are: a quarter of their height, as round as the body's at most.
func groove_bevel() -> float:
	return minf(bevel, groove_height / 4.0)


## Where the lid turns, in the model's space: the back edge of its top, halfway through it.
func hinge() -> Vector3:
	return Vector3(0.0, height - lid_thickness / 2.0, -lid_box().end.y) * MeshBuilder.UNITS_PER_MM


## Where a seated disc's centre is, in the model's space, its axis (Z) pointing up.
func seat() -> Transform3D:
	var centre := Vector3(lid_centre.x, seat_height, -lid_centre.y) * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), centre)


func _arrays(part: StringName, detail: int) -> Array:
	return Ps2SlimGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	# The top, a millimetre inside its bevel, and the opening in it, both rounded; the centres of
	# the opening's corners inside those of the top's, so that the faces joining their outlines
	# point to point never fold.
	var top := body().grow(-bevel - 1.0)
	var top_corner := maxf(0.0, corner - bevel - 1.0)
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and height > 0.0 and lid_thickness > 0.0
			and lid_gap > 0.0 and disc_radius > 0.0,
		&"corner_rounds_the_bevel": corner > bevel + 0.1 and corner < minf(width, depth) / 2.0,
		&"blocks_hold_their_bevels": bevel > 0.0 and seam > 2.0 * bevel + 0.1
			and height - seam > 2.0 * bevel + 0.1,
		&"lid_inside_the_top": ShapeGeometry.fits(opening(), lid_corner + lid_gap, top, Vector2.ONE * top_corner)
			and corner < minf(width, depth) / 2.0
			and ShapeGeometry.within(opening().grow(-lid_corner - lid_gap), body().grow(-corner)),
		&"lid_corner_fits": lid_corner > 0.1 and lid_corner < minf(lid_size.x, lid_size.y) / 2.0 - 0.1,
		&"lid_thin_enough": lid_thickness < height - seam - 2.0,
		&"disc_turns_in_the_well": minf(lid_size.x, lid_size.y) / 2.0 > disc_radius + 1.0,
		&"seat_between_floor_and_lid": seat_height > seam + 2.0
			and seat_height < height - lid_thickness - 1.0,
		&"base_under_the_lid_s_side": base_inset.x > 0.1 and base_inset.y > 0.1 and base_inset.z > 0.1
			and base_box().size.x > 1.0 and base_box().size.y > 1.0,
		&"grooves_sizes_positive": groove_count >= 0 and groove_height > 0.0 and groove_pitch > groove_height
			and groove_depth > 0.0,
		&"strip_on_the_top_beside_the_lid": strip_raise > 0.0
			and ShapeGeometry.fits(strip(), strip_corner(), top, Vector2.ONE * top_corner)
			and not ShapeGeometry.overlap(strip().grow(0.5), opening()),
	}
