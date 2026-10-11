# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name WiiShape
extends ModelShape
## The dimensions of the Wii (RVL-001), a slot-loading disc console, in millimetres, as it usually
## stands: upright on its stand, its front towards +Z, its right side towards +X (see [WiiGeometry]).
## Heights are from the table. A slab in three blocks, the front panel, the body and the back panel,
## of one cross-section (X across, Y up); a raised panel on each side; two flaps on the top, over the
## GameCube ports. On the front: the slot, a raised rim around a dark gap the disc goes through, edge
## first, its label to the right; the power, reset and eject buttons in a column beside it; the SD
## card door, flush in its opening, hinged on its left edge. The stand wraps the slab's foot, on a
## round plate. Front positions are given from the top of the slab, plan positions on the top from
## its back.

## How far the buttons stand out of the front, and how round they are, and the slot's rim; how deep
## the SD door's opening is behind the door, the gap around the door, and the door's thickness; how
## far the door swings open.
const BUTTON_RAISE := 1.8
const BUTTON_CORNER := 1.2
## How round the flaps on the top are.
const FLAP_CORNER := 1.5
const RIM_RAISE := 1.2
const RIM_BEVEL := 0.5
const DOOR_WELL := 3.0
const DOOR_GAP := 0.4
const DOOR_THICKNESS := 1.2
const DOOR_SWING := 100.0
## The sync button behind the door, at the top of its opening, estimated from the photo of the door
## open: how far it keeps from the door's sides and top, and its height.
const SYNC_INSET := Vector2(1.0, 2.0)
const SYNC_HEIGHT := 4.0
## The gap between the stand and the slab, and the stand's rounded edges.
const STAND_GAP := 0.3
const STAND_BEVEL := 1.0

@export var width := 44.0:
	set(value):
		width = value
		emit_changed()
@export var height := 157.0:
	set(value):
		height = value
		emit_changed()
@export var depth := 215.4:
	set(value):
		depth = value
		emit_changed()
## How round the slab's long edges are, and the edges at each end of its blocks; the front panel's
## front edges, rounder.
@export var corner := 3.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 1.0:
	set(value):
		bevel = value
		emit_changed()
@export var front_bevel := 2.5:
	set(value):
		front_bevel = value
		emit_changed()
## How deep the front and back panels are.
@export var front_depth := 12.0:
	set(value):
		front_depth = value
		emit_changed()
@export var back_depth := 9.0:
	set(value):
		back_depth = value
		emit_changed()
## How far the side panels keep from the side's edges and from the end panels.
@export var panel_inset := 4.0:
	set(value):
		panel_inset = value
		emit_changed()
## The slot: the middle of its rim across the front (X), from how far below the top to how far its
## rim reaches, the rim's width and the gap's.
@export var slot_x := 9.0:
	set(value):
		slot_x = value
		emit_changed()
@export var slot_span := Vector2(13.0, 145.0):
	set(value):
		slot_span = value
		emit_changed()
@export var slot_rim := 7.0:
	set(value):
		slot_rim = value
		emit_changed()
@export var slot_gap := 4.0:
	set(value):
		slot_gap = value
		emit_changed()
## The buttons' column across the front (X), their size, and the middles of the power, reset and
## eject buttons below the top.
@export var buttons_x := -11.0:
	set(value):
		buttons_x = value
		emit_changed()
@export var button_size := Vector2(10.5, 4.5):
	set(value):
		button_size = value
		emit_changed()
@export var buttons_from_top := Vector3(17.5, 32.0, 139.5):
	set(value):
		buttons_from_top = value
		emit_changed()
## The SD door, from its left edge to its right one (X), and from how far below the top to how far.
@export var door_x := Vector2(-17.0, -6.0):
	set(value):
		door_x = value
		emit_changed()
@export var door_span := Vector2(48.0, 109.0):
	set(value):
		door_span = value
		emit_changed()
## The flaps on the top, over the memory card slots and the controller ports, from how far from the
## back to how far.
@export var memory_flap := Vector2(13.0, 75.0):
	set(value):
		memory_flap = value
		emit_changed()
@export var controller_flap := Vector2(79.0, 196.0):
	set(value):
		controller_flap = value
		emit_changed()
## The stand: its height over the plate, its walls around the slab, and how deep the slab sits in it;
## the round plate under it.
@export var stand_height := 32.0:
	set(value):
		stand_height = value
		emit_changed()
@export var stand_wall := 3.0:
	set(value):
		stand_wall = value
		emit_changed()
@export var stand_sink := 3.0:
	set(value):
		stand_sink = value
		emit_changed()
@export var plate_radius := 80.0:
	set(value):
		plate_radius = value
		emit_changed()
@export var plate_thickness := 2.5:
	set(value):
		plate_thickness = value
		emit_changed()
## The discs it takes, and how far behind the front a seated one's centre is.
@export var disc_radius := 60.0:
	set(value):
		disc_radius = value
		emit_changed()
@export var disc_depth := 75.0:
	set(value):
		disc_depth = value
		emit_changed()


func parts() -> Array[StringName]:
	return WiiGeometry.PARTS


func surfaces() -> Array[StringName]:
	var flat: Array[StringName] = []
	flat.assign(WiiGeometry.LOGOS.keys())
	return flat


## The slab's underside, sunk in its stand.
func bottom() -> float:
	return plate_thickness + stand_height - stand_sink


## The slab's cross-section, the front seen from in front (X across, Y up).
func face() -> Rect2:
	return Rect2(-width / 2.0, bottom(), width, height)


## Where the front panel is flat, inside its rounded edges.
func front_flat() -> Rect2:
	return face().grow(-front_bevel - 0.5)


## The slot's rim on the front, and the gap through it.
func slot() -> Rect2:
	return Rect2(slot_x - slot_rim / 2.0, face().end.y - slot_span.y, slot_rim, slot_span.y - slot_span.x)


func gap() -> Rect2:
	return slot().grow(-(slot_rim - slot_gap) / 2.0)


## The power (0), reset (1) or eject (2) button on the front, at rest.
func button(index: int) -> Rect2:
	var centre := Vector2(buttons_x, face().end.y - buttons_from_top[index])
	return ShapeGeometry.centred(centre, button_size)


## The console's name on the front, under the eject button.
func logo() -> Rect2:
	var size := WiiGeometry.LOGOS[&"logo"]
	return Rect2(-size.x / 2.0, button(2).position.y - WiiGeometry.LOGO_DROP - size.y, size.x, size.y)


## The SD door on the front, and the opening it closes.
func door() -> Rect2:
	return Rect2(door_x.x, face().end.y - door_span.y, door_x.y - door_x.x, door_span.y - door_span.x)


func door_opening() -> Rect2:
	return door().grow(DOOR_GAP)


## The front the door sweeps as it swings open about its left edge, out to the left.
func door_sweep() -> Rect2:
	var reach := door().size.x * absf(cos(deg_to_rad(DOOR_SWING))) + DOOR_THICKNESS
	return door().grow_side(SIDE_LEFT, reach)


## The door's hinge, its front left edge, in the model's space.
func door_hinge() -> Vector3:
	return Vector3(door().position.x, door().get_center().y, depth / 2.0) * MeshBuilder.UNITS_PER_MM


## The red sync button behind the door, at the top of its opening.
func sync_button() -> Rect2:
	var opening := door()
	return Rect2(opening.position.x + SYNC_INSET.x, opening.end.y - SYNC_INSET.y - SYNC_HEIGHT,
		opening.size.x - 2.0 * SYNC_INSET.x, SYNC_HEIGHT)


## A side panel, on the side's plane (X towards the back, Y up).
func side_panel() -> Rect2:
	var length := depth - front_depth - back_depth - 2.0 * panel_inset
	return Rect2(front_depth + panel_inset - depth / 2.0, bottom() + panel_inset, length, height - 2.0 * panel_inset)


## A flap on the top, in plan (X across, Y towards the back), from [param span] (from the back).
func flap(span: Vector2) -> Rect2:
	var across := width / 2.0 - corner - 0.5
	return Rect2(-across, depth / 2.0 - span.y, 2.0 * across, span.y - span.x)


## The stand, in plan, and the slab's own plan, which sits in it.
func stand() -> Rect2:
	return footprint().grow(stand_wall + STAND_GAP)


func footprint() -> Rect2:
	return Rect2(-width / 2.0, -depth / 2.0, width, depth)


## Where a seated disc stands, in the model's space: upright behind the slot's gap, edge on to it, its
## axis (Z) and its label towards the right.
func seat() -> Transform3D:
	var centre := Vector3(slot_x, gap().get_center().y, depth / 2.0 - disc_depth)
	return Transform3D(Basis(Vector3.FORWARD, Vector3.UP, Vector3.RIGHT), centre * MeshBuilder.UNITS_PER_MM)


func _arrays(part: StringName, detail: int) -> Array:
	return WiiGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var flat := front_flat()
	var front: Array[Rect2] = [button(0), button(1), button(2), slot(), door_opening()]
	var panel := side_panel()
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and depth > 0.0 and disc_radius > 0.0
			and plate_radius > 1.0 and plate_thickness > 0.0
			and minf(button_size.x, button_size.y) > 2.0 * BUTTON_CORNER + 0.1,
		&"edges_round": bevel > 0.0 and front_bevel > 0.0 and corner > maxf(bevel, front_bevel) + 0.1
			and corner < width / 2.0 - 0.1,
		&"blocks_hold_their_bevels": front_depth > maxf(front_bevel, DOOR_WELL) + 0.5
			and back_depth > 2.0 * bevel + 0.1 and depth - front_depth - back_depth > 2.0 * bevel + 0.1,
		&"panels_on_the_flat_sides": panel_inset > corner + 0.1 and panel.size.x > 6.0 and panel.size.y > 6.0,
		&"slot_on_the_front": slot_gap > 0.5 and slot_gap < slot_rim - 2.0 * RIM_BEVEL - 0.2,
		&"disc_through_the_slot": gap().size.y > 2.0 * (disc_radius + 1.0)
			and disc_depth > front_depth + disc_radius and disc_depth + disc_radius < depth - back_depth,
		# The door, wider than its sync button, swings open clear of the buttons and the slot.
		&"front_parts_apart": door().size.x > 4.0 and door().size.y > 8.0 and ShapeGeometry.apart(front, flat)
			and ShapeGeometry.apart([button(0), button(1), button(2), slot(), door_sweep().merge(door_opening())],
			flat.merge(door_sweep()), 1.0),
		# Each longer and wider than its two corners.
		&"flaps_on_the_top": memory_flap.x > back_depth + 0.5
			and memory_flap.y - memory_flap.x > 2.0 * FLAP_CORNER + 0.2 and controller_flap.x > memory_flap.y + 1.0
			and controller_flap.y - controller_flap.x > 2.0 * FLAP_CORNER + 0.2
			and controller_flap.y < depth - front_depth - 0.5 and flap(memory_flap).size.x > 2.0 * FLAP_CORNER + 0.2,
		# Below the front's parts.
		&"stand_wraps_the_foot": stand_wall > STAND_BEVEL + STAND_GAP + 0.1
			and stand_height > 2.0 * STAND_BEVEL + 0.1 and stand_sink > 0.5 and stand_sink < stand_height - 1.0
			and front.all(func(part: Rect2) -> bool: return part.position.y > bottom() + stand_sink + 0.5)
			and logo().position.y > bottom() + stand_sink,
	}
