# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GcShape
extends ModelShape
## The dimensions of the GameCube, a top-loading cube, in millimetres, as it lies on a table: its
## top up (+Y), its front towards +Z (see [GcGeometry]). A base and a body above it, rounded; a lid
## over most of the top, hinged along its back edge, over a shallow well that steps down from a
## shelf to a ledge round the recess the drive's plate fills, where the spindle holds the disc; three
## round buttons straddling the lid's edges, each in a collar the lid is notched around (power at the
## back left, reset at the front left, open at the front right); the power light's window before the
## lid; the controller ports' panel on the front, vents on both sides, the handle at the back. Plan
## positions are of centres, X to the right and Y towards the back, from the centre of the body;
## heights from its bottom. What hugs an edge is placed from that edge.

## How deep the spindle's turntable goes under a seated disc (see spindle.tscn): it stands on the
## drive's plate, the recess's floor, its motor under it.
const TURNTABLE_DEPTH := 2.1
## The lid opens past upright, so that it never leans over the well.
const OPEN_DEGREES := 95.0
## How far the buttons stand above the top, the gap around them, how deep they and their collars go:
## down to the shelf under the lid, which they stand on.
const BUTTON_RAISE := 0.4
const BUTTON_CLEARANCE := 0.3
const BUTTON_DEPTH := 4.0
## The power light's window, a circular segment before the lid: its chord, how far it bulges
## and the steps along its arc.
const LAMP := Vector2(32.0, 3.5)
const LAMP_STEPS := 16
## The recess, which the drive's dark plate fills, is this much wider than the discs.
const DRIVE_MARGIN := 5.0
## The ledge round the recess: how wide it is, and how far below the shelf.
const LEDGE := Vector2(8.0, 2.5)
## The pickup's slot through the drive's plate, behind the spindle, in discs' radii from the seat.
const SLOT := Rect2(-0.05, 0.35, 0.25, 0.67)
const HANDLE_THICKNESS := 5.0
## The points round every circle of the model.
const CIRCLE_POINTS := 48

@export var width := 150.0:
	set(value):
		width = value
		emit_changed()
@export var depth := 161.0:
	set(value):
		depth = value
		emit_changed()
@export var height := 110.0:
	set(value):
		height = value
		emit_changed()
@export var corner := 4.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 2.5:
	set(value):
		bevel = value
		emit_changed()
## Where the base ends and the body starts.
@export var seam := 23.5:
	set(value):
		seam = value
		emit_changed()
## How far the lid's sides are from the body's left and right sides, and its front and back edges
## from the body's front and back.
@export var lid_sides := Vector2(16.0, 16.0):
	set(value):
		lid_sides = value
		emit_changed()
@export var lid_ends := Vector2(18.0, 5.0):
	set(value):
		lid_ends = value
		emit_changed()
@export var lid_thickness := 3.0:
	set(value):
		lid_thickness = value
		emit_changed()
## The gap all around the lid, between it and the edge of its opening.
@export var lid_gap := 0.8:
	set(value):
		lid_gap = value
		emit_changed()
@export var lid_corner := 3.0:
	set(value):
		lid_corner = value
		emit_changed()
@export var button_radius := 8.0:
	set(value):
		button_radius = value
		emit_changed()
## The width of the ring of the top around each button, which the lid is notched around.
@export var button_collar := 2.2:
	set(value):
		button_collar = value
		emit_changed()
## How far in front of the lid's back edge the power button is, on its left edge.
@export var power_inset := 33.5:
	set(value):
		power_inset = value
		emit_changed()
## How far behind the lid's front edge the reset and open buttons are, on its side edges.
@export var button_inset := 5.0:
	set(value):
		button_inset = value
		emit_changed()
## Where a seated disc's centre is: a little in front of the round dark face in the lid.
@export var seat_centre := Vector2(0.0, -7.5):
	set(value):
		seat_centre = value
		emit_changed()
## How far below the top a seated disc's centre is.
@export var seat_depth := 8.0:
	set(value):
		seat_depth = value
		emit_changed()
## The discs the well takes: they turn in it without touching its edge.
@export var disc_radius := 40.0:
	set(value):
		disc_radius = value
		emit_changed()
## The round dark face in the lid: its centre and radius.
@export var dimple_centre := Vector2.ZERO:
	set(value):
		dimple_centre = value
		emit_changed()
@export var dimple_radius := 41.0:
	set(value):
		dimple_radius = value
		emit_changed()
## The controller ports' panel on the front, centred across it, its bottom this far above the seam.
@export var panel_size := Vector2(117.0, 58.0):
	set(value):
		panel_size = value
		emit_changed()
@export var panel_lift := 3.0:
	set(value):
		panel_lift = value
		emit_changed()
## Each side's vent: its size and its centre, along the depth (Y) and up.
@export var vent_size := Vector2(56.5, 53.5):
	set(value):
		vent_size = value
		emit_changed()
@export var vent_centre := Vector2(4.0, 60.0):
	set(value):
		vent_centre = value
		emit_changed()
## How far the handle reaches behind the back; how far below the top its band starts, and how tall
## it is.
@export var handle_reach := 30.0:
	set(value):
		handle_reach = value
		emit_changed()
@export var handle_band := Vector2(11.0, 27.0):
	set(value):
		handle_band = value
		emit_changed()


func parts() -> Array[StringName]:
	return GcGeometry.PARTS


func surfaces() -> Array[StringName]:
	var flat: Array[StringName] = [&"well", &"slot", &"dimple", &"lamp", &"ports"]
	flat.append_array(GcGeometry.LOGOS.keys())
	return flat


func body() -> Rect2:
	return Rect2(-width / 2.0, -depth / 2.0, width, depth)


func lid_box() -> Rect2:
	var whole := body()
	return Rect2(whole.position + Vector2(lid_sides.x, lid_ends.x),
		whole.size - Vector2(lid_sides.x + lid_sides.y, lid_ends.x + lid_ends.y))


func seat_height() -> float:
	return height - seat_depth


func well_floor() -> float:
	return seat_height() - TURNTABLE_DEPTH


## The height of the shelf under the lid, and of the ledge below it.
func shelf() -> float:
	return height - BUTTON_DEPTH


func ledge() -> float:
	return shelf() - LEDGE.y


## The round recess, counter-clockwise, centred under the seat; grown by [param grow].
func recess(grow := 0.0) -> PackedVector2Array:
	return ShapeGeometry.circle(seat_centre, disc_radius + DRIVE_MARGIN + grow, CIRCLE_POINTS)


## The pickup's slot, counter-clockwise.
func slot() -> PackedVector2Array:
	var box := Rect2(seat_centre + SLOT.position * disc_radius, SLOT.size * disc_radius)
	return ShapeGeometry.rounded(box, 0.0, 0.0, 1)


## The bottom and the top of the handle's band.
func handle_heights() -> Vector2:
	return Vector2(height - handle_band.x - handle_band.y, height - handle_band.x)


## How wide the handle is across the back, its ends on its flat part.
func handle_span() -> float:
	return width - 2.0 * (corner + bevel + 2.0)


## The buttons' centres, by name: they straddle the lid's edges.
func buttons() -> Dictionary[StringName, Vector2]:
	var lid := lid_box()
	var front := lid.position.y + button_inset
	return {
		&"power": Vector2(lid.position.x, lid.end.y - power_inset),
		&"reset": Vector2(lid.position.x, front),
		&"open": Vector2(lid.end.x, front),
	}


func notch_radius() -> float:
	return button_radius + button_collar


## The lid's outline, counter-clockwise: its box, rounded, notched around each button's collar and
## the gap; empty when the notches would cut it apart.
func lid_outline(steps: int) -> PackedVector2Array:
	var found: Array[PackedVector2Array] = [ShapeGeometry.rounded_box(lid_box(), lid_corner, steps)]
	for centre: Vector2 in buttons().values():
		if found.size() != 1:
			return PackedVector2Array()
		# Round the circle, so that the lid's sides keep their distance from the collar's corners.
		var notch := ShapeGeometry.circle(centre, (notch_radius() + lid_gap) / cos(PI / CIRCLE_POINTS), CIRCLE_POINTS)
		found = Geometry2D.clip_polygons(found[0], notch)
	return found[0] if found.size() == 1 else PackedVector2Array()


## The opening the lid closes, counter-clockwise: the lid grown by its gap, and each button's collar
## (which the top keeps); empty when a collar does not straddle the lid's edge.
func opening(steps: int) -> PackedVector2Array:
	var found: Array[PackedVector2Array] = [
		ShapeGeometry.rounded_box(lid_box().grow(lid_gap), lid_corner + lid_gap, steps)]
	for centre: Vector2 in buttons().values():
		if found.size() != 1:
			return PackedVector2Array()
		found = Geometry2D.merge_polygons(found[0], ShapeGeometry.circle(centre, notch_radius(), CIRCLE_POINTS))
	return found[0] if found.size() == 1 else PackedVector2Array()


## The top inside its bevel, counter-clockwise, where the opening and the light's window lie.
func top(steps: int) -> PackedVector2Array:
	var inset := bevel + 0.3
	return ShapeGeometry.rounded_box(body().grow(-inset), maxf(0.1, corner - inset), steps)


## The power light's window, counter-clockwise: a circular segment, its chord along the front of the
## opening, centred on the seat.
func lamp() -> PackedVector2Array:
	var chord := lid_box().position.y - lid_gap - 0.5
	var radius := (LAMP.x * LAMP.x / 4.0 + LAMP.y * LAMP.y) / (2.0 * LAMP.y)
	var centre := Vector2(seat_centre.x, chord - LAMP.y + radius)
	var half := asin(LAMP.x / 2.0 / radius)
	var found := PackedVector2Array()
	for step in LAMP_STEPS + 1:
		found.append(centre + Vector2.from_angle(-PI / 2.0 - half + 2.0 * half * step / LAMP_STEPS) * radius)
	return found


## Where the lid turns, in the model's space: the back edge of its top, halfway through it.
func hinge() -> Vector3:
	return Vector3(0.0, height - lid_thickness / 2.0, -lid_box().end.y) * MeshBuilder.UNITS_PER_MM


## Where a seated disc's centre is, in the model's space, its axis (Z) pointing up.
func seat() -> Transform3D:
	var centre := Vector3(seat_centre.x, seat_height(), -seat_centre.y) * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), centre)


func _arrays(part: StringName, detail: int) -> Array:
	return GcGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var sizes := width > 0.0 and depth > 0.0 and height > 0.0 and lid_thickness > 0.0 and lid_gap > 0.0 \
		and button_radius > 0.0 and disc_radius > 0.0 and dimple_radius > 0.0
	var lid_corner_fits := lid_corner > 0.1 and lid_corner < minf(lid_box().size.x, lid_box().size.y) / 2.0 - 0.1
	var collar_fits := button_collar > BUTTON_CLEARANCE + 0.2
	var lid := lid_outline(8) if sizes and lid_corner_fits and collar_fits else PackedVector2Array()
	var face := top(8) if corner > bevel + 0.1 else PackedVector2Array()
	var hole := opening(8) if not lid.is_empty() else PackedVector2Array()
	var notches: Array[Vector2] = []
	notches.assign(buttons().values())
	var band := handle_heights()
	var panel_bottom := seam + panel_lift
	return {
		&"sizes_positive": sizes,
		&"corner_rounds_the_bevel": corner > bevel + 0.1 and corner < minf(width, depth) / 2.0,
		&"blocks_hold_their_bevels": bevel > 0.0 and seam > 2.0 * bevel + 0.1 and height - seam > 2.0 * bevel + 0.1,
		&"lid_corner_fits": lid_corner_fits,
		&"collars_wider_than_their_gaps": collar_fits,
		&"lid_in_one_piece_round_the_collars": not lid.is_empty(),
		&"collars_straddle_the_lid_s_edges": not hole.is_empty(),
		&"lid_and_collars_inside_the_top": not face.is_empty() and not hole.is_empty()
			and ShapeGeometry.inside(hole, face),
		&"collars_apart_beside_the_well": notches.all(func(at: Vector2) -> bool:
			return absf(at.x - seat_centre.x) > notch_radius() + 1.0 and notches.all(func(other: Vector2) -> bool:
				return other == at or at.distance_to(other) > 2.0 * notch_radius() + 1.0)),
		&"lid_clears_the_disc": lid_thickness < seat_depth - 2.0,
		# Turning about the middle of its back edge, the lid's lower back edge swings back past the gap,
		# under the top, by a millimetre at most.
		&"lid_clears_the_top_behind_it": lid_thickness / 2.0 < lid_gap + 1.0,
		&"floor_above_the_base": well_floor() > seam + 1.0,
		&"disc_under_the_ledge": seat_height() < ledge() - 1.0,
		&"disc_and_drive_in_the_well": not lid.is_empty() and ShapeGeometry.inside(recess(LEDGE.x), lid),
		&"lid_opens_behind_the_disc": seat_centre.y + disc_radius + 1.0 < lid_box().end.y - lid_thickness,
		&"dimple_on_the_lid": not lid.is_empty()
			and ShapeGeometry.inside(ShapeGeometry.circle(dimple_centre, dimple_radius, CIRCLE_POINTS), lid),
		&"lamp_before_the_lid": not face.is_empty() and not hole.is_empty() and ShapeGeometry.inside(lamp(), face)
			and Array(lamp()).all(func(point: Vector2) -> bool: return not Geometry2D.is_point_in_polygon(point, hole)),
		&"panel_on_the_front": panel_lift > 0.0 and panel_size.x > 0.0 and panel_size.y > 0.0
			and panel_bottom + panel_size.y < height - bevel
			and panel_size.x / 2.0 + GcGeometry.PANEL_BULGE < width / 2.0 - corner,
		&"vents_on_the_sides": vent_size.x > 0.0 and vent_size.y > 0.0
			and absf(vent_centre.x) + vent_size.x / 2.0 < depth / 2.0 - corner
			and vent_centre.y - vent_size.y / 2.0 > seam + bevel and vent_centre.y + vent_size.y / 2.0 < height - bevel,
		&"handle_behind_the_back": handle_reach > HANDLE_THICKNESS + 1.0 and handle_reach < handle_span() / 3.0
			and handle_band.x > bevel and handle_band.y > 1.0 and band.x > seam + bevel,
	}
