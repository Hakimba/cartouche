# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name N64Shape
extends ModelShape
## The dimensions of the Nintendo 64, a top-loading cartridge console, in millimetres, as it lies on
## a table: its top up (+Y), its front towards +Z (see [N64Geometry]). A body in two shells on four
## feet, the joint between them at [member seam], the upper one's top edges rounded off by its
## [member crown]; two lobes at its front corners, standing out of its sides and front. The top is
## no flat deck: a tongue runs along the middle of its back half, the slot in it, and its sides fall
## to the lower shoulders; ahead of the slot, a ramp with vents climbs in a U to the hill at the
## front, the top's highest part, which carries the memory lid, the power switch and the reset
## button on its flanks (see [method top_height]). The slot takes the cartridge through two spring
## flaps inside a dark bezel, hinged along its long edges, that fold down into it. Plan positions
## are of centres, X to the right and Y towards the back, from the centre of the outline.

## How high the feet lift the body off the table; how far in from each lobe's outline its foot keeps,
## and the pads at the back corners, from the side and the back to their outer corner, and their size.
const FEET := 4.5
const POD_FOOT_INSET := 6.0
const BACK_FEET := Rect2(45.0, 35.0, 30.0, 20.0)
## The bezel around the flaps; the gap between a flap and the bezel, and between the two flaps.
const BEZEL := 2.5
const FLAP_GAP := 0.4
## The tongue's floor stays flat this far around the slot.
const SURROUND := 3.0
## The recesses the power switch and the reset button slide in, and their knobs.
const POWER_RECESS := Vector2(22.0, 44.0)
const POWER_KNOB := Vector2(17.0, 26.0)
const RESET_RECESS := Vector2(21.0, 44.0)
const RESET_KNOB := Vector2(17.0, 30.0)
## Each knob stands this high over the top, and leaves this much at each end of its recess.
const KNOB_HEIGHT := 4.0
const KNOB_MARGIN := 1.0
## How round the lobes' edges are.
const POD_ROUND := 7.0
## The share of a fall (the tongue's or the hill's sides, the ramp) that rounds off at each end,
## the rest of it a straight slope.
const FALL_ROUND := 0.2
## How far the memory lid keeps at least from the ramp's crest and from the top's front edge.
const LID_GAP := 2.0
## The logo's plate behind the slot; the vents' slits, fanned out this far each side from a point
## this far behind the slot's centre, from and to these shares of the ramp; the slits along each
## side of the lower shell, and how far they keep from its bottom and from the seam.
const LOGO := Vector2(38.0, 9.0)
const VENT_WIDTH := 2.0
const VENT_SPREAD := deg_to_rad(35.0)
const VENT_FOCUS := 40.0
const VENT_REACH := Vector2(0.15, 0.9)
const SIDE_VENTS := 16
const SIDE_VENT_PITCH := 4.4
const SIDE_VENT_MARGIN := 5.0
## The dark plate on the front, under the hill.
const BADGE_WIDTH := 48.0

## The lobes' outer edges, and their fronts.
@export var width := 260.0:
	set(value):
		width = value
		emit_changed()
## Both shells, side to side.
@export var body_width := 236.0:
	set(value):
		body_width = value
		emit_changed()
@export var depth := 190.0:
	set(value):
		depth = value
		emit_changed()
## The top of the hill.
@export var height := 73.0:
	set(value):
		height = value
		emit_changed()
## The tongue's floor, where the slot is.
@export var back_height := 62.0:
	set(value):
		back_height = value
		emit_changed()
## The top's sides, before they round off.
@export var shoulder_height := 54.0:
	set(value):
		shoulder_height = value
		emit_changed()
## Where the lower shell ends and the upper one starts; the floor of the slot's well.
@export var seam := 31.0:
	set(value):
		seam = value
		emit_changed()
@export var corner := 20.0:
	set(value):
		corner = value
		emit_changed()
## How round the shells' edges are along the seam and the bottom.
@export var bevel := 2.5:
	set(value):
		bevel = value
		emit_changed()
## How far the upper shell's top edges round off, inwards and down.
@export var crown := Vector2(11.0, 9.0):
	set(value):
		crown = value
		emit_changed()
## How far the body's front stands behind the pods'.
@export var front_inset := 10.0:
	set(value):
		front_inset = value
		emit_changed()
@export var pod_size := Vector2(48.0, 88.0):
	set(value):
		pod_size = value
		emit_changed()
@export var pod_height := 44.0:
	set(value):
		pod_height = value
		emit_changed()
## The tongue's flat width, and how far out its sides fall to the shoulders.
@export var tongue := Vector2(148.0, 30.0):
	set(value):
		tongue = value
		emit_changed()
## The hill's flat width, and how far out its flanks fall to the shoulders.
@export var hill := Vector2(64.0, 62.0):
	set(value):
		hill = value
		emit_changed()
## The U the ramp climbs to: its width across the slot's centre, and how far ahead of it its crest
## stands.
@export var bowl := Vector2(150.0, 59.0):
	set(value):
		bowl = value
		emit_changed()
## The opening through the tongue, bezel included.
@export var slot_size := Vector2(126.0, 30.0):
	set(value):
		slot_size = value
		emit_changed()
## The Y of the slot's centre.
@export var slot_centre := 42.0:
	set(value):
		slot_centre = value
		emit_changed()
@export var flap_thickness := 1.5:
	set(value):
		flap_thickness = value
		emit_changed()
## How far the closed flaps' tops stand below the tongue's floor.
@export var flap_recess := 4.5:
	set(value):
		flap_recess = value
		emit_changed()
## The cartridge the slot takes, its width, height and thickness, and how high its bottom edge
## stands once in.
@export var cartridge := Vector3(116.0, 76.6, 18.5):
	set(value):
		cartridge = value
		emit_changed()
@export var cartridge_floor := 36.0:
	set(value):
		cartridge_floor = value
		emit_changed()
## The X of the reset button, and of the power switch on the other side.
@export var switch_x := 64.0:
	set(value):
		switch_x = value
		emit_changed()
## The memory lid, on the hill.
@export var lid_size := Vector2(56.0, 46.0):
	set(value):
		lid_size = value
		emit_changed()
@export var vent_count := 18:
	set(value):
		vent_count = value
		emit_changed()


func parts() -> Array[StringName]:
	return N64Geometry.PARTS


func surfaces() -> Array[StringName]:
	var flat: Array[StringName] = [&"well", &"recesses"]
	flat.append_array(N64Geometry.LOGOS.keys())
	return flat


## The outline of both shells.
func body() -> Rect2:
	return Rect2(-body_width / 2.0, front_inset - depth / 2.0, body_width, depth - front_inset)


## The pod at the front corner on the [param side] (-1 left, 1 right).
func pod(side: float) -> Rect2:
	var outer := Rect2(width / 2.0 - pod_size.x, -depth / 2.0, pod_size.x, pod_size.y)
	return outer if side > 0.0 else Rect2(-outer.end.x, outer.position.y, pod_size.x, pod_size.y)


func pod_corner() -> float:
	return minf(pod_size.x, pod_size.y) / 2.0 - 2.0


## The pads the body stands on: one under each pod, one at each back corner.
func feet() -> Array[Rect2]:
	var back := Rect2(body_width / 2.0 - BACK_FEET.position.x, body().end.y - BACK_FEET.position.y,
		BACK_FEET.size.x, BACK_FEET.size.y)
	return [pod(-1.0).grow(-POD_FOOT_INSET), pod(1.0).grow(-POD_FOOT_INSET), back,
		Rect2(-back.end.x, back.position.y, back.size.x, back.size.y)]


## How high the top stands at [param at], before its edges round off: the tongue's floor, its
## sides falling to the shoulders, climbs the ramp ahead of the slot to the hill, whose flanks
## fall to the shoulders too.
func top_height(at: Vector2) -> float:
	var tongue_top := lerpf(shoulder_height, back_height, _flat(at.x, tongue))
	var hill_top := lerpf(shoulder_height, height, _flat(at.x, hill))
	return lerpf(tongue_top, hill_top, ramp(at))


## How far up the ramp [param at] stands, from 0 on the tongue to 1 past the crest. The ramp runs
## between two U-shaped curves around the slot's centre, of the bowl's width: the floor's, as far
## ahead as [method floor_reach], and the crest's, as far as [member bowl]'s length.
func ramp(at: Vector2) -> float:
	var ahead := slot_centre - at.y
	if ahead <= 0.0:
		return 0.0
	var reach := _reach_through(at.x, ahead)
	return _rise((reach - floor_reach()) / (bowl.y - floor_reach())) * _rise(ahead / floor_reach())


## How far ahead of the slot's centre the floor reaches, just enough to hold [method surround].
func floor_reach() -> float:
	var around := surround()
	return _reach_through(around.size.x / 2.0, around.size.y / 2.0)


## The Y of the ramp's crest, ahead of the slot.
func crest() -> float:
	return slot_centre - bowl.y


func slot() -> Rect2:
	return Rect2(-slot_size.x / 2.0, slot_centre - slot_size.y / 2.0, slot_size.x, slot_size.y)


## The tongue's flat floor around the slot.
func surround() -> Rect2:
	return slot().grow(SURROUND)


## The flap hinged along the slot's front edge (`front`) or its back one.
func flap(front: bool) -> Rect2:
	var opening := slot().grow(-BEZEL - FLAP_GAP)
	var half := (opening.size.y - FLAP_GAP) / 2.0
	return Rect2(opening.position.x, opening.position.y if front else opening.end.y - half,
		opening.size.x, half)


## Where the flap turns, in the model's space: its bottom edge along the bezel, so that it folds
## down into the slot, never against the bezel.
func flap_hinge(front: bool) -> Vector3:
	var edge := flap(front).position.y if front else flap(front).end.y
	return Vector3(0.0, back_height - flap_recess - flap_thickness, -edge) * MeshBuilder.UNITS_PER_MM


## The memory lid, on the hill's flat top, halfway between the crest and the top's front edge.
func lid() -> Rect2:
	var centre := (body().position.y + crown.x + crest()) / 2.0
	return Rect2(-lid_size.x / 2.0, centre - lid_size.y / 2.0, lid_size.x, lid_size.y)


## The recess of the power switch (`power`) or of the reset button, on the hill's flank beside the
## lid.
func recess(power: bool) -> Rect2:
	var size := POWER_RECESS if power else RESET_RECESS
	var centre := Vector2(-switch_x if power else switch_x, lid().get_center().y)
	return ShapeGeometry.centred(centre, size)


## The knob of [method recess], at rest at its front end.
func knob(power: bool) -> Rect2:
	var size := POWER_KNOB if power else RESET_KNOB
	var room := recess(power)
	return Rect2(Vector2(room.get_center().x - size.x / 2.0, room.position.y + KNOB_MARGIN), size)


## How far the knob slides back, to the back end of its recess.
func travel(power: bool) -> float:
	return recess(power).size.y - knob(power).size.y - 2.0 * KNOB_MARGIN


## How steeply the top rises to the right under [method recess], as height per width: the hill's
## flank, straight there.
func flank(power: bool) -> float:
	var centre := recess(power).get_center()
	return (top_height(centre + Vector2.RIGHT) - top_height(centre + Vector2.LEFT)) / 2.0


## The [param index]th slit on the ramp, its ends in plan: fanned out from a point behind the slot,
## from low on the ramp to high on it.
func vent(index: int) -> PackedVector2Array:
	var angle := lerpf(-VENT_SPREAD, VENT_SPREAD, (index + 0.5) / maxi(1, vent_count))
	var focus := Vector2(0.0, slot_centre + VENT_FOCUS)
	var towards := Vector2(sin(angle), -cos(angle))
	var ends := PackedVector2Array()
	for share: float in [VENT_REACH.x, VENT_REACH.y]:
		var reach := lerpf(floor_reach(), bowl.y, share)
		var span := Vector2(0.0, VENT_FOCUS + bowl.length())
		for halving in 32:
			var middle := focus + towards * (span.x + span.y) / 2.0
			if _reach_through(middle.x, slot_centre - middle.y) < reach:
				span.x = (span.x + span.y) / 2.0
			else:
				span.y = (span.x + span.y) / 2.0
		ends.append(focus + towards * span.x)
	return ends


## Where a seated cartridge stands, in the model's space: upright in the slot, its label to the
## front.
func seat() -> Transform3D:
	var centre := Vector3(0.0, cartridge_floor + cartridge.y / 2.0, -slot_centre)
	return Transform3D(Basis(), centre * MeshBuilder.UNITS_PER_MM)


## How far ahead of the slot's centre the U through [param x] and [param ahead] reaches: the U is
## (x / half width)^4 + (ahead / reach)^4 = 1, square across the slot, round at its front.
func _reach_through(x: float, ahead: float) -> float:
	var across := 1.0 - pow(absf(x) / (bowl.x / 2.0), 4.0)
	return ahead / pow(across, 0.25) if across > 0.0 else INF


## 1 on the flat middle of [param flat_and_fall] (its width, then how far out it falls), down to 0
## past its fall.
static func _flat(x: float, flat_and_fall: Vector2) -> float:
	return 1.0 - _rise((absf(x) - flat_and_fall.x / 2.0) / flat_and_fall.y)


## From 0 at [param share] 0 up to 1 at 1: rounded at both ends, straight between.
static func _rise(share: float) -> float:
	var along := clampf(share, 0.0, 1.0)
	var slope := 1.0 / (1.0 - FALL_ROUND)
	if along < FALL_ROUND:
		return slope * along * along / (2.0 * FALL_ROUND)
	if along > 1.0 - FALL_ROUND:
		return 1.0 - slope * (1.0 - along) * (1.0 - along) / (2.0 * FALL_ROUND)
	return slope * (along - FALL_ROUND / 2.0)


func _arrays(part: StringName, detail: int) -> Array:
	return N64Geometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var outline := body()
	var inside := outline.grow(-crown.x - 1.0)
	var lowest_flap := back_height - flap_recess - flap_thickness - flap(true).size.y
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and seam > 0.0 and flap_thickness > 0.0
			and flap_recess > 0.0 and cartridge.x > 0.0 and cartridge.y > 0.0 and cartridge.z > 0.0,
		&"shells_hold_their_edges": bevel > 0.0 and crown.x > 0.0 and crown.y > 0.0
			and seam > FEET + 2.0 * bevel + 0.1 and shoulder_height - crown.y - seam > bevel + 0.1,
		&"top_climbs_to_the_hill": back_height > shoulder_height + 1.0 and height > back_height + 2.0,
		&"corners_round_the_edges": corner > crown.x + 0.1 and corner < minf(outline.size.x, outline.size.y) / 2.0,
		# The top is drawn along rays from the slot's centre: deeper than wide, they leave the corners
		# of the slot's surround between them, and the flaps fold through the floor around it.
		&"no_deeper_than_wide": depth <= width,
		&"pods_at_the_front_corners": pod_corner() > POD_ROUND + 0.1 and pod_size.x < width / 2.0 - 2.0
			and pod_size.y > front_inset + corner and pod_height > FEET + 2.0 * POD_ROUND + 0.1
			and pod_size.y - depth / 2.0 < outline.end.y - corner - SIDE_VENTS * SIDE_VENT_PITCH
			and pod_height < shoulder_height,
		&"tongue_and_hill_on_the_top": tongue.y > 1.0 and hill.x > 0.0 and hill.y > 1.0
			and tongue.x / 2.0 < inside.end.x and hill.x / 2.0 < inside.end.x,
		&"slot_in_the_tongue": surround().size.x <= tongue.x and inside.has_area() and surround().has_area()
			and inside.encloses(surround())
			and surround().size.x < bowl.x - 2.0 and floor_reach() < bowl.y - 5.0,
		&"slot_takes_the_cartridge": slot_size.x - 2.0 * BEZEL > cartridge.x + 2.0
			and slot_size.y - 2.0 * (BEZEL + FLAP_GAP + flap_thickness) > cartridge.z + 1.0,
		&"flaps_fold_into_the_slot": flap_thickness < 2.9 and flap(true).size.y > flap_thickness + 0.1
			and flap_recess > 1.0 and lowest_flap > seam + 1.0,
		&"cartridge_stands_out_of_the_slot": cartridge_floor > seam
			and cartridge_floor + cartridge.y > height + 5.0,
		&"logo_behind_the_slot": slot().end.y + LOGO.y + 4.0 < inside.end.y and LOGO.x < tongue.x,
		&"lid_on_the_hill": lid_size.x > 8.0 and lid_size.y > 8.0 and lid_size.x <= hill.x
			and lid().position.y - LID_GAP > outline.position.y + crown.x and lid().end.y + LID_GAP < crest(),
		&"switches_on_the_hill_s_flanks": _switch_fits(true) and _switch_fits(false),
		&"vents_fit": vent_count > 0 and _vents_apart() and seam > FEET + 2.0 * SIDE_VENT_MARGIN + 2.0
			and bevel < SIDE_VENT_MARGIN and SIDE_VENTS * SIDE_VENT_PITCH < outline.end.y - corner,
		&"badge_on_the_front": height - crown.y - seam > 15.0 and BADGE_WIDTH <= hill.x,
	}


## Whether the recess of the power switch (`power`) or of the reset button lies on the straight
## part of the hill's flank, ahead of the crest and behind the top's front edge, clear of the lid,
## its knob sliding in it.
func _switch_fits(power: bool) -> bool:
	var room := recess(power)
	var out := absf(room.get_center().x)
	var beside := N64Geometry.LOGOS[&"switch_label"].x + N64Geometry.SWITCH_LABEL_GAP if power else 0.0
	return out - room.size.x / 2.0 >= hill.x / 2.0 + FALL_ROUND * hill.y \
		and out + room.size.x / 2.0 + beside <= hill.x / 2.0 + (1.0 - FALL_ROUND) * hill.y \
		and room.end.y < crest() and room.position.y > body().position.y + crown.x + 1.0 \
		and not room.grow(2.0).intersects(lid()) and travel(power) > 1.0


## Whether the slits stand apart where they are closest, low on the ramp.
func _vents_apart() -> bool:
	for index in vent_count - 1:
		if vent(index)[0].distance_to(vent(index + 1)[0]) < VENT_WIDTH + 0.8:
			return false
	return true
