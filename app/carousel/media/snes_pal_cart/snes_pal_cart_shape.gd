# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name SnesPalCartShape
extends ModelShape
## The dimensions of the European Super Nintendo's cartridge, the Super Famicom's too, in
## millimetres, its label facing +Z and its top edge +Y, from the centre of its body (see
## [SnesPalCartGeometry]). Two halves meet half way through: the back one, its edges rounded, the
## front one set in a hair at the seam, its sides and its end rolled round towards the face; the
## connector's slot cut into the end across the seam, the board's contacts inside. On the face, the
## label's recess across the top, a plate standing out down the middle above and below it, the
## lower one with a long grip slot; screws in the wings' lower corners, slits up the sides' rolls;
## on the back, the warning sticker's recess and two small holes.

## How far the label's and the sticker's recesses keep from the edges of the faces they lie in.
const RIM := 0.5
## The board in the slot, and the gaps between its tongues of contacts.
const BOARD_THICKNESS := 1.6
const BOARD_GAP := 2.2
## How far in from the end the board stops, and how much of it its contacts cover.
const BOARD_INSET := 1.5
const CONTACT_LENGTH := 6.0
## How much of each contact's pitch it is wide.
const CONTACT_SHARE := 0.62
## How far the plates' backs lie above the front half's, so that neither shows through the other.
const PLATE_BACK := 0.3
## The plates' corners, seen from the front.
const PLATE_CORNER := 0.8
## How far up the side's roll the slits go, as an angle off the side.
const SLIT_REACH := 72.0
## How far down the side the slits go below the roll.
const SLIT_SIDE := 1.5
## How far the screws' heads stand out of the face.
const SCREW_PROUD := 0.15
## The ridges along the grip's floor either side of its middle: how wide, how far they stand out.
const RIDGE := Vector2(0.35, 0.25)

@export var width := 128.0:
	set(value):
		width = value
		emit_changed()
@export var height := 87.0:
	set(value):
		height = value
		emit_changed()
@export var thickness := 20.0:
	set(value):
		thickness = value
		emit_changed()
## The corners of the outline, seen from the front.
@export var corner := 2.0:
	set(value):
		corner = value
		emit_changed()
@export var back_round := 1.0:
	set(value):
		back_round = value
		emit_changed()
## How far the front half is set in from the back one: the seam's line.
@export var seam := 0.15:
	set(value):
		seam = value
		emit_changed()
## The connector's slot in the end: its width and its height across the thickness, centred on the
## seam, and how deep it goes in.
@export var slot_size := Vector2(97.8, 9.0):
	set(value):
		slot_size = value
		emit_changed()
@export var slot_depth := 7.0:
	set(value):
		slot_depth = value
		emit_changed()
## How far the front half's sides, its end and its top roll round towards the face.
@export var side_round := 4.2:
	set(value):
		side_round = value
		emit_changed()
@export var end_round := 3.0:
	set(value):
		end_round = value
		emit_changed()
@export var top_round := 1.5:
	set(value):
		top_round = value
		emit_changed()
## The plates down the middle of the face: how wide, how far they stand out of the wings, their
## edges' round (the lower one's end rolls further), and how far past the body's end and top they
## reach.
@export var plate_width := 87.0:
	set(value):
		plate_width = value
		emit_changed()
@export var plate_raise := 0.8:
	set(value):
		plate_raise = value
		emit_changed()
@export var plate_round := 0.6:
	set(value):
		plate_round = value
		emit_changed()
@export var plate_end_round := 2.0:
	set(value):
		plate_end_round = value
		emit_changed()
@export var plate_lip := 0.4:
	set(value):
		plate_lip = value
		emit_changed()
## The strip of the wings' level left between the label's recess and each plate.
@export var land := 0.6:
	set(value):
		land = value
		emit_changed()
@export var label_size := Vector2(107.8, 37.3):
	set(value):
		label_size = value
		emit_changed()
@export var label_centre := Vector2(0.0, 19.5):
	set(value):
		label_centre = value
		emit_changed()
@export var label_corner := 2.0:
	set(value):
		label_corner = value
		emit_changed()
@export var recess := 0.6:
	set(value):
		recess = value
		emit_changed()
## The grip slot in the lower plate, its ends round: its outline on the plate, its walls' slope
## down to its floor, its depth, and the middle of its floor raised.
@export var grip_size := Vector2(73.9, 8.1):
	set(value):
		grip_size = value
		emit_changed()
@export var grip_centre := Vector2(0.0, -13.9):
	set(value):
		grip_centre = value
		emit_changed()
@export var grip_slope := 1.4:
	set(value):
		grip_slope = value
		emit_changed()
@export var grip_depth := 2.5:
	set(value):
		grip_depth = value
		emit_changed()
@export var grip_middle := 25.6:
	set(value):
		grip_middle = value
		emit_changed()
@export var grip_rise := 0.5:
	set(value):
		grip_rise = value
		emit_changed()
@export var grip_ridges := 5:
	set(value):
		grip_ridges = value
		emit_changed()
## The slits up each side's roll near the top: how many, how far apart, the first one's centre from
## the top, and how tall each is.
@export var slit_count := 5:
	set(value):
		slit_count = value
		emit_changed()
@export var slit_pitch := 4.0:
	set(value):
		slit_pitch = value
		emit_changed()
@export var slit_from_top := 8.3:
	set(value):
		slit_from_top = value
		emit_changed()
@export var slit_height := 1.6:
	set(value):
		slit_height = value
		emit_changed()
## The screws' centres from the sides and from the end, on the face's wings.
@export var screw_inset := Vector2(7.4, 6.0):
	set(value):
		screw_inset = value
		emit_changed()
@export var screw_radius := 2.2:
	set(value):
		screw_radius = value
		emit_changed()
## The warning sticker's recess on the back, as seen from the front (X to the right of the face).
@export var sticker_size := Vector2(75.0, 22.0):
	set(value):
		sticker_size = value
		emit_changed()
@export var sticker_centre := Vector2(0.0, -20.0):
	set(value):
		sticker_centre = value
		emit_changed()
@export var sticker_recess := 0.4:
	set(value):
		sticker_recess = value
		emit_changed()
## The two small holes in the back: their centres from the sides and from the end.
@export var hole_inset := Vector2(8.2, 13.0):
	set(value):
		hole_inset = value
		emit_changed()
@export var hole_radius := 1.3:
	set(value):
		hole_radius = value
		emit_changed()
## The board's contacts on each face: the middle tongue's, each side tongue's (none for a board of
## one tongue), and their pitch.
@export var centre_contacts := 23:
	set(value):
		centre_contacts = value
		emit_changed()
@export var side_contacts := 4:
	set(value):
		side_contacts = value
		emit_changed()
@export var contact_pitch := 2.5:
	set(value):
		contact_pitch = value
		emit_changed()


## The whole outline, seen from the front.
func outline() -> Rect2:
	return ShapeGeometry.centred(Vector2.ZERO, Vector2(width, height))


## The front half's outline, set in at the seam.
func front_outline() -> Rect2:
	return outline().grow(-seam)


## Where the face of the wings lies, below the plates'.
func wings() -> float:
	return thickness / 2.0 - plate_raise


## The face of the wings, inside the front half's rolls.
func face() -> Rect2:
	var box := front_outline()
	return Rect2(box.position + Vector2(side_round, end_round),
		box.size - Vector2(2.0 * side_round, end_round + top_round))


func label_box() -> Rect2:
	return ShapeGeometry.centred(label_centre, label_size)


## The lower plate, from below the label to past the end, and the strip above the label.
func lower_plate() -> Rect2:
	var bottom := -height / 2.0 + seam - plate_lip
	return Rect2(-plate_width / 2.0, bottom, plate_width, label_box().position.y - land - bottom)


func top_strip() -> Rect2:
	var low := label_box().end.y + land
	return Rect2(-plate_width / 2.0, low, plate_width, height / 2.0 - seam + plate_lip - low)


## The plates' faces, inside their edges' round.
func lower_plate_face() -> Rect2:
	var box := lower_plate()
	return Rect2(box.position + Vector2(plate_round, plate_end_round),
		box.size - Vector2(2.0 * plate_round, plate_end_round + plate_round))


func top_strip_face() -> Rect2:
	return top_strip().grow(-plate_round)


## Where the plates' backs lie, inside the front half.
func plate_back() -> float:
	return slot_size.y / 2.0 + PLATE_BACK


func grip_box() -> Rect2:
	return ShapeGeometry.centred(grip_centre, grip_size)


## The grip's ends are round: their radius a hair under half its height, so that its outline keeps
## as many points as its floor's.
func grip_corner() -> float:
	return grip_size.y / 2.0 * 0.98


func grip_floor() -> Rect2:
	return grip_box().grow(-grip_slope)


## The ridges along the grip's floor, either side of its middle, out to where its ends round off.
func ridges() -> Array[Rect2]:
	var floor_box := grip_floor()
	var reach := floor_box.size.x / 2.0 - (grip_corner() - grip_slope) - grip_middle / 2.0
	var found: Array[Rect2] = []
	for i in grip_ridges:
		var y := floor_box.position.y + floor_box.size.y * (i + 1) / (grip_ridges + 1) - RIDGE.x / 2.0
		for x: float in [grip_centre.x - grip_middle / 2.0 - reach, grip_centre.x + grip_middle / 2.0]:
			found.append(Rect2(x, y, reach, RIDGE.x))
	return found


## The slits' centres from the top edge.
func slits() -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for i in slit_count:
		found.append(height / 2.0 - slit_from_top - i * slit_pitch)
	return found


func screws() -> PackedVector2Array:
	var y := -height / 2.0 + screw_inset.y
	return PackedVector2Array([Vector2(-width / 2.0 + screw_inset.x, y), Vector2(width / 2.0 - screw_inset.x, y)])


func holes() -> PackedVector2Array:
	var y := -height / 2.0 + hole_inset.y
	return PackedVector2Array([Vector2(-width / 2.0 + hole_inset.x, y), Vector2(width / 2.0 - hole_inset.x, y)])


func sticker_box() -> Rect2:
	return ShapeGeometry.centred(sticker_centre, sticker_size)


## The back's face, inside its rounded edges.
func back_face() -> Rect2:
	return outline().grow(-back_round)


## The board's tongues, left to right, as seen from the front.
func tongues() -> Array[Rect2]:
	return SnesPalCartGeometry.board_tongues(-height / 2.0, slot_depth, centre_contacts, side_contacts, contact_pitch)


func parts() -> Array[StringName]:
	return SnesPalCartGeometry.PARTS


func title_area() -> Rect2:
	return Rect2(0.04, 0.1, 0.92, 0.56)


func platform_area() -> Rect2:
	return Rect2(0.2, 0.74, 0.6, 0.16)


func _arrays(part: StringName, detail: int) -> Array:
	return SnesPalCartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var front := front_outline()
	var lowest := -height / 2.0
	var wings_face := face()
	var plate_face := lower_plate_face()
	var straight := front.grow(-corner - top_round)
	var screw := screws()[1]
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and thickness > 0.0 and plate_raise > 0.0 and land > 0.0
			and recess > 0.0 and grip_slope > 0.0 and grip_depth > 0.0 and grip_rise > 0.0 and slit_height > 0.0
			and screw_radius > 0.0 and sticker_recess > 0.0 and hole_radius > 0.0 and plate_lip > 0.0
			and slit_count >= 0 and side_contacts >= 0 and centre_contacts > 0 and contact_pitch > 0.0,
		# Each half thicker than its rolls, the slot between their faces; each face wider and taller
		# than its corners.
		&"halves_hold_their_rolls": corner > 0.0 and seam > 0.0 and back_round > 0.0 and side_round > 0.0
			and end_round > 0.0 and top_round > 0.0
			and thickness / 2.0 - slot_size.y / 2.0 > back_round + sticker_recess + 0.2
			and wings() - slot_size.y / 2.0 > maxf(maxf(side_round, end_round), top_round) + 0.2
			and wings_face.size.x > 2.0 * corner and wings_face.size.y > 2.0 * corner
			and back_face().size.x > 2.0 * corner and back_face().size.y > 2.0 * corner,
		# Across the straight end, deeper than the board's inset and short of the label's height.
		&"slot_in_the_end": slot_size.x > 0.0 and slot_size.y > BOARD_THICKNESS + 1.0
			and slot_size.x / 2.0 < front.end.x - corner - 0.5 and slot_depth > BOARD_INSET + 2.0
			and slot_depth < height / 2.0,
		&"board_in_the_slot": SnesPalCartGeometry.across(tongues()) < slot_size.x - 1.0,
		# Down the middle of the wings' face, taller than their edges' round, standing out of them.
		&"plates_on_the_face": plate_width > 2.0 * PLATE_CORNER and plate_width / 2.0 < wings_face.end.x
			and wings() > plate_back() + 0.1
			and plate_round > 0.0 and plate_end_round > 0.0
			and thickness / 2.0 - plate_back() > maxf(plate_round, plate_end_round) + 0.1
			and plate_face.size.x > 2.0 * PLATE_CORNER and plate_face.size.y > 2.0 * PLATE_CORNER
			and top_strip_face().size.x > 2.0 * PLATE_CORNER and top_strip_face().size.y > 2.0 * PLATE_CORNER,
		# The recess, with plastic around it, within the wings' face; its floor above the slot.
		&"label_on_the_face": label_corner > 0.0 and 2.0 * label_corner < minf(label_size.x, label_size.y)
			and ShapeGeometry.fits(label_box().grow(RIM), label_corner + RIM, wings_face, Vector2.ONE * corner)
			and wings() - recess > slot_size.y / 2.0 + 0.2,
		# Inside the lower plate's face, sunk through it into the front half, its floor above the
		# plate's back; the floor's raised middle across its straight part, its ridges apart; under the
		# label's straight edges, the line the face round both is cut along.
		&"grip_in_the_plate": 2.0 * grip_slope < grip_size.y * 0.98 and grip_size.x > grip_size.y
			and ShapeGeometry.fits(grip_box().grow(0.3), grip_corner() + 0.3, plate_face, Vector2.ONE * PLATE_CORNER)
			and thickness / 2.0 - grip_depth > plate_back() + 0.3 and grip_rise < grip_depth - plate_raise
			and grip_middle > 0.0 and grip_middle < grip_floor().size.x - 2.0 * (grip_corner() - grip_slope)
			and grip_ridges >= 0 and grip_floor().size.y > (grip_ridges + 1) * RIDGE.x
			and absf(grip_centre.x - label_centre.x) < label_size.x / 2.0 - label_corner,
		# Along the straight part of each side, apart, on a roll rounder than they go into it; none at
		# all is a side without.
		&"slits_on_the_sides": slit_count == 0 or (slit_pitch > slit_height and side_round > 0.6
			and wings() - side_round - SLIT_SIDE > 0.0
			and slits()[0] + slit_height / 2.0 < straight.end.y
			and slits()[-1] - slit_height / 2.0 > lowest + seam + corner + end_round),
		# On the wings' face, clear of the plate, below the label.
		&"screws_on_the_wings": ShapeGeometry.within(Rect2(screw, Vector2.ZERO).grow(screw_radius + 0.3), wings_face)
			and screw.x - screw_radius > plate_width / 2.0 + 0.3
			and screw.y + screw_radius < label_box().position.y - 0.3,
		# The sticker's recess and the holes on the back's face, apart.
		&"back_holds_the_sticker_and_the_holes": ShapeGeometry.fits(sticker_box().grow(RIM), 2.0 * RIM,
				back_face(), Vector2.ONE * corner)
			and ShapeGeometry.apart([Rect2(holes()[0], Vector2.ZERO).grow(hole_radius),
				Rect2(holes()[1], Vector2.ZERO).grow(hole_radius), sticker_box()], back_face().grow(-0.3), 0.3),
	}
