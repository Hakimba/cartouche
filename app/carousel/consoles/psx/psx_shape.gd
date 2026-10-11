# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name PsxShape
extends ModelShape
## The dimensions of the first PlayStation, a top-loading console, in millimetres, as it lies on a
## table: its top up (+Y), its front towards +Z (see [PsxGeometry]). Two wings run front to back
## along its sides, the power and reset buttons on the left one, the open button on the right;
## between them a lower deck, set back from their fronts over the ports, holds the round lid,
## hinged along its back edge over the well where the drive's spindle holds the disc. The well's
## opening is wider than the deck: the wings' inner sides are cut by an arc around it. Ribs run
## up both sides. Plan positions are of centres, X to the right and Y towards the back, from the
## centre of the body.

## The discs the well takes: a CD.
const DISC_RADIUS := 60.0
## The power light, in front of the power button: its size in plan.
const LIGHT_SIZE := Vector2(1.4, 4.0)

@export var width := 270.0:
	set(value):
		width = value
		emit_changed()
@export var depth := 188.0:
	set(value):
		depth = value
		emit_changed()
@export var height := 60.0:
	set(value):
		height = value
		emit_changed()
@export var corner := 5.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 1.6:
	set(value):
		bevel = value
		emit_changed()
## The deck between the wings: its width, how far below their tops, how far back from their fronts.
@export var centre_width := 130.0:
	set(value):
		centre_width = value
		emit_changed()
@export var step := 4.5:
	set(value):
		step = value
		emit_changed()
@export var bay := 8.0:
	set(value):
		bay = value
		emit_changed()
@export var lid_radius := 75.0:
	set(value):
		lid_radius = value
		emit_changed()
@export var lid_centre := Vector2(0.0, 0.0):
	set(value):
		lid_centre = value
		emit_changed()
@export var lid_thickness := 6.0:
	set(value):
		lid_thickness = value
		emit_changed()
## How far the lid's top stands above the deck.
@export var lid_raise := 4.0:
	set(value):
		lid_raise = value
		emit_changed()
## The gap all around the lid, between it and the edge of its opening.
@export var lid_gap := 0.8:
	set(value):
		lid_gap = value
		emit_changed()
## The deck left around the opening where it cuts into the wings.
@export var rim := 3.0:
	set(value):
		rim = value
		emit_changed()
## How far below the deck the well's floor is, and a seated disc's centre.
@export var well_depth := 17.0:
	set(value):
		well_depth = value
		emit_changed()
@export var seat_depth := 8.0:
	set(value):
		seat_depth = value
		emit_changed()
@export var power_centre := Vector2(-97.0, -66.0):
	set(value):
		power_centre = value
		emit_changed()
@export var reset_centre := Vector2(-95.0, -24.0):
	set(value):
		reset_centre = value
		emit_changed()
@export var open_centre := Vector2(97.0, -54.0):
	set(value):
		open_centre = value
		emit_changed()
## The power and open buttons' radius, then the reset button's.
@export var button_radius := 18.0:
	set(value):
		button_radius = value
		emit_changed()
@export var reset_radius := 8.5:
	set(value):
		reset_radius = value
		emit_changed()
## The groove around each button.
@export var groove := 1.0:
	set(value):
		groove = value
		emit_changed()
## The ribs up each side: how many, their pitch and width, from and to what heights, how far out.
@export var vent_count := 40:
	set(value):
		vent_count = value
		emit_changed()
@export var vent_pitch := 4.0:
	set(value):
		vent_pitch = value
		emit_changed()
@export var vent_width := 1.8:
	set(value):
		vent_width = value
		emit_changed()
@export var vent_band := Vector2(10.0, 48.0):
	set(value):
		vent_band = value
		emit_changed()
@export var vent_fin := 1.2:
	set(value):
		vent_fin = value
		emit_changed()


func parts() -> Array[StringName]:
	return PsxGeometry.PARTS


func surfaces() -> Array[StringName]:
	var flat: Array[StringName] = [&"grooves", &"louvres"]
	flat.append_array(PsxGeometry.LOGOS.keys())
	return flat


func body() -> Rect2:
	return Rect2(-width / 2.0, -depth / 2.0, width, depth)


func wing() -> float:
	return (width - centre_width) / 2.0


## The wing on the left ([param side] -1) or on the right (1), whole.
func wing_box(side: int) -> Rect2:
	var x := -width / 2.0 if side < 0 else width / 2.0 - wing()
	return Rect2(x, -depth / 2.0, wing(), depth)


## The deck, from behind the bay to the back.
func centre_box() -> Rect2:
	return Rect2(-centre_width / 2.0, -depth / 2.0 + bay, centre_width, depth - bay)


func deck() -> float:
	return height - step


## The radius of the well's opening, then of the arc it cuts in the wings.
func opening() -> float:
	return lid_radius + lid_gap


func notch() -> float:
	return opening() + rim


## Where the lid turns, in the model's space: its back edge, halfway through it.
func hinge() -> Vector3:
	var back := lid_centre.y + lid_radius
	return Vector3(lid_centre.x, deck() + lid_raise - lid_thickness / 2.0, -back) * MeshBuilder.UNITS_PER_MM


## Where a seated disc's centre is, in the model's space, its axis (Z) pointing up.
func seat() -> Transform3D:
	var centre := Vector3(lid_centre.x, deck() - seat_depth, -lid_centre.y) * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), centre)


## Each button's centre and radius, by name.
func buttons() -> Dictionary[StringName, Vector3]:
	return {
		&"power": Vector3(power_centre.x, power_centre.y, button_radius),
		&"reset": Vector3(reset_centre.x, reset_centre.y, reset_radius),
		&"open": Vector3(open_centre.x, open_centre.y, button_radius),
	}


## The power light, at the front of the left wing's top, in front of the power button.
func light_box() -> Rect2:
	var front := -depth / 2.0 + bevel + 0.5
	return Rect2(power_centre.x - LIGHT_SIZE.x / 2.0, front, LIGHT_SIZE.x, LIGHT_SIZE.y)


## The ribs of the right side, along Y; the left side's are their mirror.
func vents() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var first := -(vent_count - 1) * vent_pitch / 2.0
	for i in vent_count:
		var y := first + i * vent_pitch
		found.append(Rect2(width / 2.0 - 0.5, y - vent_width / 2.0, vent_fin + 0.5, vent_width))
	return found


func _arrays(part: StringName, detail: int) -> Array:
	return PsxGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	# On the flat of its wing's top, clear of the well's arc.
	var on_wing := func(button: Vector3, side: int) -> bool:
		var reach := button.z + groove
		var top := wing_box(side)
		var room := top.size / 2.0 - Vector2.ONE * (bevel + 0.5 + reach)
		var off := (Vector2(button.x, button.y) - top.get_center()).abs()
		return off.x < room.x and off.y < room.y \
			and Vector2(button.x, button.y).distance_to(lid_centre) > notch() + reach + 0.5
	var pressed := buttons()
	var power_reach := button_radius + groove
	var centre := centre_box()
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and height > 0.0 and lid_thickness > 0.0
			and lid_gap > 0.0 and bay > 0.0 and well_depth > 0.0 and seat_depth > 0.0
			and button_radius > 0.0 and reset_radius > 0.0 and groove > 0.0,
		&"corner_rounds_the_bevel": bevel > 0.0 and corner > bevel + 0.1 and corner < wing() / 2.0 - 0.1,
		&"wings_beside_the_deck": centre_width > 0.0 and wing() > 2.0 * corner + 0.2,
		&"deck_below_the_wings": step > bevel + 0.1 and deck() > well_depth + 2.0 * bevel + 1.0,
		&"lid_rests_in_the_deck": lid_raise >= lid_thickness / 2.0 and lid_raise < lid_thickness - 0.5
			and lid_raise < step,
		&"opening_inside_the_top": rim > bevel + 0.1 and absf(lid_centre.x) < centre_width / 2.0 - 1.0
			and lid_centre.y - notch() > centre.position.y + bevel + 1.0
			and lid_centre.y + notch() < centre.end.y - bevel - 1.0
			and absf(lid_centre.x) + notch() < width / 2.0 - corner - 1.0,
		&"disc_turns_in_the_well": lid_radius > DISC_RADIUS + 1.0,
		&"seat_between_floor_and_lid": seat_depth < well_depth - 2.0
			and seat_depth > lid_thickness - lid_raise + 3.0,
		&"buttons_on_the_wings": on_wing.call(pressed[&"power"], -1) and on_wing.call(pressed[&"reset"], -1)
			and on_wing.call(pressed[&"open"], 1)
			and power_centre.distance_to(reset_centre) > power_reach + reset_radius + groove + 0.5
			and power_centre.y - power_reach > light_box().end.y + 0.5,
		&"vents_up_the_sides": vent_count >= 1 and vent_width > 0.0 and vent_width < vent_pitch
			and vent_fin > 0.0 and vent_band.x > bevel + 0.5 and vent_band.y < height - bevel - 0.5
			and vent_band.x < vent_band.y - 1.0
			and (vent_count - 1) * vent_pitch + vent_width < depth - 2.0 * corner - 2.0,
	}
