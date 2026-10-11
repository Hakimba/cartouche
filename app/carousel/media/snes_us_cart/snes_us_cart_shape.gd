# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name SnesUsCartShape
extends ModelShape
## The dimensions of the North American Super Nintendo's cartridge, in millimetres, its label facing
## +Z and its top edge +Y, from the centre of its outline (see [SnesUsCartGeometry]). A boxy body in
## two halves as the European one's ([SnesPalCartGeometry]), its edges barely rounded, the
## connector's slot cut into its end; down the middle of the face a body standing out, from the end
## to past the top (its tab), with the label's recess in its upper part and, below, two rails either
## side of the grip, whose floor slopes up from a channel down its middle; grooves round the wings
## and the back; screws in the wings' lower corners; on the back, the warning sticker's recess and
## the notches either side of the slot that the consoles' tabs go into.

## How far the raised body's back lies above the front half's, so that neither shows through the
## other.
const BODY_BACK := 0.3
## The raised body's corners, seen from the front.
const BODY_CORNER := 0.8
## How far a groove's or a notch's dark face stands over the faces it lies on.
const DARK_OFF := 0.04
## How far short of the end the rails and the grip's sides stop, over the front half's rolled edge.
const END_SET := 0.3

@export var width := 136.0:
	set(value):
		width = value
		emit_changed()
## From the end to the top of the tab.
@export var height := 88.0:
	set(value):
		height = value
		emit_changed()
@export var thickness := 20.0:
	set(value):
		thickness = value
		emit_changed()
## How far the raised body stands past the wings' top edge.
@export var tab := 2.5:
	set(value):
		tab = value
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
## How far round the front half's edges roll towards the face.
@export var front_round := 1.2:
	set(value):
		front_round = value
		emit_changed()
## How far the front half is set in from the back one: the seam's line.
@export var seam := 0.15:
	set(value):
		seam = value
		emit_changed()
## The connector's slot in the end: its width and its height across the thickness, centred on the
## seam, and how deep it goes in.
@export var slot_size := Vector2(97.8, 10.0):
	set(value):
		slot_size = value
		emit_changed()
@export var slot_depth := 7.0:
	set(value):
		slot_depth = value
		emit_changed()
## The raised body down the middle: how wide, how far it stands out of the wings, its edges' round.
@export var body_width := 92.0:
	set(value):
		body_width = value
		emit_changed()
@export var body_raise := 2.0:
	set(value):
		body_raise = value
		emit_changed()
@export var body_round := 0.8:
	set(value):
		body_round = value
		emit_changed()
## The rails either side of the grip, and where the grip's top, the body's upper part's lower edge,
## lies.
@export var rail_width := 4.0:
	set(value):
		rail_width = value
		emit_changed()
@export var grip_top := -6.5:
	set(value):
		grip_top = value
		emit_changed()
## The channel down the middle of the grip, and how far its floor lies below the grip's sides', at
## the grip's top and at the end.
@export var channel_width := 26.0:
	set(value):
		channel_width = value
		emit_changed()
@export var channel_depth := Vector2(0.3, 1.5):
	set(value):
		channel_depth = value
		emit_changed()
@export var label_size := Vector2(88.0, 38.0):
	set(value):
		label_size = value
		emit_changed()
@export var label_centre := Vector2(0.0, 23.5):
	set(value):
		label_centre = value
		emit_changed()
@export var label_corner := 1.5:
	set(value):
		label_corner = value
		emit_changed()
@export var recess := 0.6:
	set(value):
		recess = value
		emit_changed()
## The grooves round the wings and the back: how many, how far apart, the first one's centre from
## the top of the wings, and how wide each is.
@export var groove_count := 5:
	set(value):
		groove_count = value
		emit_changed()
@export var groove_pitch := 14.6:
	set(value):
		groove_pitch = value
		emit_changed()
@export var groove_from_top := 12.3:
	set(value):
		groove_from_top = value
		emit_changed()
@export var groove_width := 0.7:
	set(value):
		groove_width = value
		emit_changed()
## The screws' centres from the sides and from the end, on the wings.
@export var screw_inset := Vector2(12.0, 7.5):
	set(value):
		screw_inset = value
		emit_changed()
@export var screw_radius := 2.2:
	set(value):
		screw_radius = value
		emit_changed()
## The warning sticker's recess on the back, as seen from the front (X to the right of the face).
@export var sticker_size := Vector2(78.0, 32.0):
	set(value):
		sticker_size = value
		emit_changed()
@export var sticker_centre := Vector2(0.0, 14.7):
	set(value):
		sticker_centre = value
		emit_changed()
@export var sticker_recess := 0.4:
	set(value):
		sticker_recess = value
		emit_changed()
## The notches in the back either side of the slot: their centres from the sides, and their width,
## their length up from the end and their depth into the back.
@export var notch_inset := 12.4:
	set(value):
		notch_inset = value
		emit_changed()
@export var notch_size := Vector3(5.5, 11.5, 9.0):
	set(value):
		notch_size = value
		emit_changed()
## The board's contacts on each face: the middle tongue's, each side tongue's (none for a board of
## one tongue), and their pitch.
@export var centre_contacts := 23:
	set(value):
		centre_contacts = value
		emit_changed()
@export var side_contacts := 0:
	set(value):
		side_contacts = value
		emit_changed()
@export var contact_pitch := 2.5:
	set(value):
		contact_pitch = value
		emit_changed()


## The wings' outline, the tab left out, seen from the front.
func outline() -> Rect2:
	return Rect2(-width / 2.0, -height / 2.0, width, height - tab)


## The front half's outline, set in at the seam.
func front_outline() -> Rect2:
	return outline().grow(-seam)


## Where the face of the wings lies, below the raised body's.
func wings() -> float:
	return thickness / 2.0 - body_raise


## The face of the wings, inside the front half's rolled edges.
func face() -> Rect2:
	return front_outline().grow(-front_round)


## The raised body's upper part, from the grip's top to the tab's, and its rails, from the end to a
## little into the upper part.
func upper_body() -> Rect2:
	return Rect2(-body_width / 2.0, grip_top, body_width, height / 2.0 - grip_top)


func rails() -> Array[Rect2]:
	var bottom := -height / 2.0 + seam + END_SET
	var tall := grip_top + 2.0 * BODY_CORNER - bottom
	return [Rect2(-body_width / 2.0, bottom, rail_width, tall),
		Rect2(body_width / 2.0 - rail_width, bottom, rail_width, tall)]


## The grip's sides, either side of the channel, from the end to under the upper part, each reaching
## into its rail further than the rail's edge rolls.
func grip_sides() -> Array[Rect2]:
	var bottom := -height / 2.0 + seam + END_SET
	var inner := body_width / 2.0 - rail_width + body_round + 0.1
	var tall := grip_top + BODY_CORNER - bottom
	return [Rect2(-inner, bottom, inner - channel_width / 2.0, tall),
		Rect2(channel_width / 2.0, bottom, inner - channel_width / 2.0, tall)]


## Where the raised body's back lies, inside the front half: the upper part's, and the rails' and
## the grip's sides', below the front half's rolled end.
func body_back() -> float:
	return slot_size.y / 2.0 + BODY_BACK


func rails_back() -> float:
	return wings() - front_round - 0.1


func label_box() -> Rect2:
	return ShapeGeometry.centred(label_centre, label_size)


## The grooves' centres from the end.
func grooves() -> PackedFloat32Array:
	var found := PackedFloat32Array()
	for i in groove_count:
		found.append(outline().end.y - groove_from_top - i * groove_pitch)
	return found


func screws() -> PackedVector2Array:
	var y := -height / 2.0 + screw_inset.y
	return PackedVector2Array([Vector2(-width / 2.0 + screw_inset.x, y), Vector2(width / 2.0 - screw_inset.x, y)])


func sticker_box() -> Rect2:
	return ShapeGeometry.centred(sticker_centre, sticker_size)


## The notches in the back, seen from the front.
func notches() -> Array[Rect2]:
	var size := Vector2(notch_size.x, notch_size.y)
	var y := -height / 2.0
	return [Rect2(Vector2(-width / 2.0 + notch_inset - size.x / 2.0, y), size),
		Rect2(Vector2(width / 2.0 - notch_inset - size.x / 2.0, y), size)]


## The back's face, inside its rounded edges.
func back_face() -> Rect2:
	return outline().grow(-back_round)


func tongues() -> Array[Rect2]:
	return SnesPalCartGeometry.board_tongues(-height / 2.0, slot_depth, centre_contacts, side_contacts, contact_pitch)


func parts() -> Array[StringName]:
	return SnesPalCartGeometry.PARTS


func title_area() -> Rect2:
	return Rect2(0.06, 0.1, 0.88, 0.56)


func platform_area() -> Rect2:
	return Rect2(0.2, 0.74, 0.6, 0.16)


func _arrays(part: StringName, detail: int) -> Array:
	return SnesUsCartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var wings_face := face()
	var upper := upper_body().grow(-body_round)
	var screw := screws()[1]
	var lowest := -height / 2.0 + seam + END_SET
	var found := grooves()
	var notch := notches()[1]
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and thickness > 0.0 and body_raise > 0.0 and recess > 0.0
			and groove_width > 0.0 and screw_radius > 0.0 and sticker_recess > 0.0 and groove_count >= 0
			and side_contacts >= 0 and centre_contacts > 0 and contact_pitch > 0.0 and tab > 0.0,
		# Each half thicker than its rolls, the slot between their faces; each face wider and taller
		# than its corners.
		&"halves_hold_their_rolls": corner > 0.0 and seam > 0.0 and back_round > 0.0 and front_round > 0.0
			and thickness / 2.0 - slot_size.y / 2.0 > back_round + sticker_recess + 0.2
			and wings() - slot_size.y / 2.0 > front_round + 0.2
			and wings_face.size.x > 2.0 * corner and wings_face.size.y > 2.0 * corner
			and back_face().size.x > 2.0 * corner and back_face().size.y > 2.0 * corner,
		&"slot_in_the_end": slot_size.x > 0.0 and slot_size.y > SnesPalCartShape.BOARD_THICKNESS + 1.0
			and slot_size.x / 2.0 < front_outline().end.x - corner - 0.5
			and slot_depth > SnesPalCartShape.BOARD_INSET + 2.0 and slot_depth < height / 2.0,
		&"board_in_the_slot": SnesPalCartGeometry.across(tongues()) < slot_size.x - 1.0,
		# Down the middle of the wings' face, standing out of it, its upper part over the grip with room
		# for its edges; the rails and the channel apart, the channel's floor below the sides'.
		&"body_on_the_face": body_width / 2.0 < wings_face.end.x and body_round > 0.0
			and thickness / 2.0 - body_back() > body_round + 0.1 and wings() > body_back() + 0.1
			and thickness / 2.0 - rails_back() > body_round + 0.1
			and upper.size.x > 2.0 * BODY_CORNER and upper.size.y > 2.0 * BODY_CORNER
			and rail_width > 2.0 * body_round + 2.0 * BODY_CORNER
			and grip_top - lowest > 2.0 * BODY_CORNER + body_round
			and channel_width > 0.0 and channel_width / 2.0 < body_width / 2.0 - rail_width - 0.5
			and channel_depth.x > 0.05 and channel_depth.y >= channel_depth.x and channel_depth.y < body_raise - 0.1,
		# The recess, with plastic around it, within the upper part's face; its floor above the
		# wings'.
		&"label_on_the_body": label_corner > 0.0 and 2.0 * label_corner < minf(label_size.x, label_size.y)
			and ShapeGeometry.fits(label_box().grow(SnesPalCartShape.RIM), label_corner + SnesPalCartShape.RIM, upper,
				Vector2.ONE * BODY_CORNER)
			and recess < body_raise - 0.1,
		# Along the wings' straight sides, apart, clear of the screws and the notches.
		&"grooves_on_the_wings": groove_count == 0 or (groove_pitch > 2.0 * groove_width
			and found[0] + groove_width / 2.0 < wings_face.end.y - corner
			and found[-1] - groove_width / 2.0 > maxf(screw.y + screw_radius, notch.end.y) + 0.3),
		# On the wings' face, clear of the raised body.
		&"screws_on_the_wings": ShapeGeometry.within(Rect2(screw, Vector2.ZERO).grow(screw_radius + 0.3), wings_face)
			and screw.x - screw_radius > body_width / 2.0 + 0.3,
		# The sticker's recess and the notches on the back's face, the notches beside the slot,
		# shallower than the back half.
		&"back_holds_the_sticker_and_the_notches": ShapeGeometry.fits(sticker_box().grow(SnesPalCartShape.RIM),
				2.0 * SnesPalCartShape.RIM, back_face(), Vector2.ONE * corner)
			and notch_size.x > 0.0 and notch_size.y > 0.0 and notch_size.z > 0.0
			and notch.position.x > slot_size.x / 2.0 + 0.5 and notch.end.x < back_face().end.x - corner
			and notch_size.z < thickness / 2.0 - 0.5
			and not sticker_box().grow(SnesPalCartShape.RIM).intersects(notch),
	}
