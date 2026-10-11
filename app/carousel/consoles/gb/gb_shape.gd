# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GbShape
extends ModelShape
## The dimensions of the Game Boy (DMG-01), a handheld, in millimetres, as it stands: its bottom on
## the table (Y up from it), its front towards +Z, X to the right from its middle (see
## [GbGeometry]). A body in two shells, the front one [member seam] deep; the outline of its front a
## rectangle with one large corner, bottom right. On the front: a groove across the top band, the
## screen's bezel with its light and its two stripes, the pad, the A and B buttons, the select and
## start buttons tilted, the speaker's slits. At the top of the back, the bay the cartridge stands
## in, open at the back and the top, its label flush with the back, two rails down its floor and the
## hole the power switch's lock comes through; the slot goes on down behind the raised plate, which
## hides the cartridge's lower part, to the connector at its foot, the sticker sunk in it; the
## battery cover lower down, ribbed, its latch's tongue under the notch a finger pushes it down by;
## four screws sunk in the back beside the bay and the plate. The power switch slides in a slot on
## the top, between the seam and the bay; the contrast and volume wheels stand out of the sides. Positions on the front are of centres, in its plane; on the sides
## and the top, from the front backwards.

const SEAM_BEVEL := 0.6
## The bezel's three small corners and its large one, bottom right; how far the screen's top is
## below the bezel's, the screen centred across it; the screen's corners; where the light's centre
## is, from the bezel's left and top, and its radius.
const BEZEL_CORNERS := Vector2(3.0, 10.0)
const SCREEN_DROP := 8.0
const SCREEN_ROUND := 0.6
const LED_AT := Vector2(5.3, 21.5)
const LED_RADIUS := 1.3
## The two stripes over the screen: how far in from the bezel's top and sides, their spacing and
## width, and the length of the left and right ones (the lettering between them is left out).
const STRIPE_INSET := 3.0
const STRIPE_GAP := 1.5
const STRIPE_WIDTH := 0.5
const STRIPE_LENGTHS := Vector2(19.5, 8.5)
## The groove across the front, this far over the bezel; the two short ones above it, this far in
## from each side.
const BAND_GAP := 1.5
const BAND_END := 6.5
## The B button's centre from the A one's, the start button's from the select one's, and the
## size of these two.
const B_FROM_A := Vector2(-14.6, -5.8)
const START_FROM_SELECT := Vector2(14.6, -1.0)
const PILL := Vector2(11.0, 3.6)
## How far the pad, the A and B buttons and the select and start buttons stand out of the front.
const DPAD_RISE := 2.8
const BUTTON_RISE := 2.6
const PILL_RISE := 1.2
## The select and start buttons' tilt, and the speaker slits', their tops to the left; from each
## slit's centre to the next one's.
const PILL_TILT_DEGREES := 26.0
const SPEAKER_SLIT := Vector2(1.4, 15.0)
const SPEAKER_TILT_DEGREES := 30.0
const SPEAKER_STEP := Vector2(4.3, 2.0)
## The bay, wider and thicker than the cartridge by this; its inner corners at its floor; how far a
## seated cartridge's top stands over the console's.
const BAY_PLAY := Vector2(1.5, 0.6)
const BAY_FILLET := 1.0
const CARTRIDGE_RISE := 1.0
## The connector at the slot's foot, in from the slot's walls by this.
const CONNECTOR_PLAY := 0.3
## The rails down the bay's floor: their centres from its middle, how wide, how far they stand out
## of it, how far below the console's top they start and above the plate they stop. The lock's
## hole, against the bay's wall on the switch's side: its size, how far below the top.
const RAIL_X := 15.0
const RAIL_WIDTH := 2.0
const RAIL_RISE := 0.4
const RAIL_ENDS := Vector2(1.5, 5.0)
const LOCK := Vector2(5.3, 1.6)
const LOCK_BELOW_TOP := 2.4
## The power switch's slot: its centre from the left side, how deep, the wall it leaves in front of
## the bay; its knob: how wide, the room it leaves at each end of the slot and in front and behind,
## how far it stands over the top.
const POWER_FROM_SIDE := 13.7
const SLOT_SINK := 2.5
const POWER_WALL := 1.9
const KNOB_WIDTH := 5.0
const KNOB_MARGIN := 0.3
const KNOB_GAP := 0.75
const KNOB_PROUD := 0.45
## The raised plate under the bay, wider than it on each side by this (past the slot's rounded
## edges), down to this far over the battery cover; how far they stand out of the back; how far the
## ribs between and beside them stand out, their pitch and width.
const PLATE_MARGIN := 4.5
const PLATE_GAP := 10.4
const COVER := Rect2(-31.5, 8.0, 63.0, 58.0)
const BACK_RISE := 1.5
const RIB_RISE := 0.5
const RIB_PITCH := 4.3
const RIB_WIDTH := 1.6
## The battery cover's parting gap; its latch's tongue up the middle of its top, how wide and how far
## up, the grip across it and how far below its top; the notch above it, sunk in the back as the
## screws' holes are. The cover's ribs: how wide, how far they stand out, where they start below its
## top, and the flat part they leave at its bottom.
const GAP := 0.45
const LATCH := Vector2(14.0, 5.4)
const LATCH_GRIP := Vector2(8.0, 0.9)
const GRIP_BELOW := 2.0
const NOTCH := Rect2(-7.0, 71.9, 14.0, 3.0)
const COVER_RIB := 3.0
const COVER_RIB_RISE := 0.35
const COVER_RIB_FROM := 1.5
const COVER_FLAT := 19.0
## The sticker on the plate, its corners, how deep it is sunk.
const STICKER := Rect2(-23.0, 80.5, 46.0, 20.3)
const STICKER_CORNER := 0.8
const STICKER_SINK := 0.3
## The slits along each side, the lowest one's height.
const SIDE_SLITS := 11
const RIB_LOW := 29.5
## The screws at the back: how far below the top, in from the sides; their holes' radius and depth,
## their heads' radius and height.
const SCREWS: Array[float] = [15.0, 66.0]
const SCREW_FROM_SIDE := 7.0
const SCREW_RADIUS := 2.5
const SCREW_SINK := 3.0
const SCREW_HEAD := Vector2(1.9, 0.8)
## The wheels, how far they stand out of the side, how thick; their windows, from the top, as long
## and as wide as this: the contrast one's in front of the seam, the volume one's behind it.
const WHEEL_RADIUS := 9.0
const WHEEL_OUT := 1.0
const WHEEL_THICKNESS := 3.0
const CONTRAST_WINDOW := Vector3(45.0, 18.0, 7.6)
const VOLUME_WINDOW := Vector3(53.0, 13.0, 6.1)
## The link port (right) and the power jack (left): from the top, their size, how far behind the seam.
const LINK := Vector3(29.0, 9.0, 5.0)
const LINK_BEHIND := 1.5
const JACK := Vector3(25.0, 5.2, 5.2)
const JACK_BEHIND := 2.9
## The headphones' jack, under the bottom: its X, how far behind the front, its radius.
const PHONES := Vector3(-7.0, 7.0, 1.8)
## The marks printed and moulded on the front, by part: the size of each one's image (the folder's
## gb_<part>.svg), the button labels drawn tilted as the select and start buttons are. The two on
## the bezel lie on it.
const MARKS: Dictionary[StringName, Vector2] = {
	&"logo": Vector2(52.0, 6.0), &"dot_matrix": Vector2(38.0, 2.6), &"battery_label": Vector2(9.6, 2.6),
	&"a_label": Vector2(3.5, 3.2), &"b_label": Vector2(3.5, 3.2), &"select_label": Vector2(12.3, 7.5),
	&"start_label": Vector2(10.7, 6.7), &"power_label": Vector2(16.8, 3.8), &"phones_label": Vector2(13.4, 3.2),
}
const ON_BEZEL: Array[StringName] = [&"dot_matrix", &"battery_label"]
## Where the marks' centres are: the logo's from the bezel's bottom left corner, the battery's label
## from the light, the A and B ones from their buttons, the select and start ones under theirs; the
## power switch's from the slot's left end, half way down the top band; the headphones', from the
## jack across and from the bottom up.
const LOGO_FROM_BEZEL := Vector2(24.5, -6.25)
const BATTERY_FROM_LED := Vector2(1.45, -4.45)
const LABEL_FROM_BUTTON := Vector2(4.5, -6.9)
const LABEL_UNDER_PILL := 4.0
const POWER_LABEL_IN := 0.4
const PHONES_LABEL := Vector2(0.4, 7.0)

@export var width := 90.0:
	set(value):
		width = value
		emit_changed()
@export var height := 148.0:
	set(value):
		height = value
		emit_changed()
## From the front to the back, the raised plates left out.
@export var depth := 30.5:
	set(value):
		depth = value
		emit_changed()
## The front's three small corners, and its large one, bottom right.
@export var corner := 4.5:
	set(value):
		corner = value
		emit_changed()
@export var big_corner := 26.0:
	set(value):
		big_corner = value
		emit_changed()
## How round the front's edges are, and the back's.
@export var bevel := 2.0:
	set(value):
		bevel = value
		emit_changed()
@export var back_bevel := 3.0:
	set(value):
		back_bevel = value
		emit_changed()
## How deep the front shell is.
@export var seam := 13.5:
	set(value):
		seam = value
		emit_changed()
@export var bezel_size := Vector2(74.0, 56.5):
	set(value):
		bezel_size = value
		emit_changed()
## The X of the bezel's centre, and how far below the top its top is.
@export var bezel_offset := Vector2(-2.0, 10.5):
	set(value):
		bezel_offset = value
		emit_changed()
@export var screen_size := Vector2(47.0, 43.0):
	set(value):
		screen_size = value
		emit_changed()
@export var dpad_centre := Vector2(-27.6, 50.5):
	set(value):
		dpad_centre = value
		emit_changed()
## The pad's span, end to end, and the width of its arms.
@export var dpad_size := Vector2(22.0, 7.3):
	set(value):
		dpad_size = value
		emit_changed()
@export var a_button := Vector2(30.0, 50.8):
	set(value):
		a_button = value
		emit_changed()
@export var button_diameter := 10.5:
	set(value):
		button_diameter = value
		emit_changed()
@export var select_button := Vector2(-13.8, 26.0):
	set(value):
		select_button = value
		emit_changed()
## The lowest speaker slit's centre, and how many.
@export var speaker_start := Vector2(12.7, 9.5):
	set(value):
		speaker_start = value
		emit_changed()
@export var speaker_slits := 6:
	set(value):
		speaker_slits = value
		emit_changed()
## How far down from the top the bay is open at the back.
@export var bay_depth := 28.0:
	set(value):
		bay_depth = value
		emit_changed()
## The cartridge the bay takes: its width, height and thickness.
@export var cartridge := Vector3(58.0, 65.5, 7.5):
	set(value):
		cartridge = value
		emit_changed()
## The power switch's slot, side to side.
@export var power_slot := 10.2:
	set(value):
		power_slot = value
		emit_changed()


func parts() -> Array[StringName]:
	return GbGeometry.PARTS


func surfaces() -> Array[StringName]:
	var found: Array[StringName] = [&"sticker"]
	found.append_array(MARKS.keys())
	return found


## The front's rectangle, its corners left square.
func face_box() -> Rect2:
	return Rect2(-width / 2.0, 0.0, width, height)


## The front's outline, [param margin] inside its edges, counter-clockwise from the bottom left.
func face(margin: float, steps: int) -> PackedVector2Array:
	var radii := PackedFloat32Array()
	for radius: float in [corner, big_corner, corner, corner]:
		radii.append(maxf(radius - margin, 0.0))
	return ShapeGeometry.filleted(ShapeGeometry.square(face_box().grow(-margin)), radii, steps)


## The front's outline with [param notch] cut out of its top, the notch's corners at the top
## rounded by [param convex] and at its floor by [param concave], counter-clockwise from the bottom
## left.
func notched(notch: Rect2, convex: float, concave: float, steps: int) -> PackedVector2Array:
	var at := ShapeGeometry.square(face_box())
	var top := at[2].y
	var cut := PackedVector2Array([Vector2(notch.end.x, top), Vector2(notch.end.x, notch.position.y),
		notch.position, Vector2(notch.position.x, top)])
	return ShapeGeometry.filleted(at.slice(0, 3) + cut + at.slice(3),
		PackedFloat32Array([corner, big_corner, corner, convex, concave, concave, convex, corner]), steps)


## The bay, seen from the back: from its floor to the top.
func bay() -> Rect2:
	var across := cartridge.x + BAY_PLAY.x
	return Rect2(-across / 2.0, height - bay_depth, across, bay_depth)


## How deep the bay is from the back, the cartridge's slot.
func slot_thickness() -> float:
	return cartridge.z + BAY_PLAY.y


## The bay's corners at the top, rounded wider than the back's edges so that they stay round.
func bay_corner() -> float:
	return back_bevel + 0.5


## The front's outline with the slot cut out of its top.
func back(steps: int) -> PackedVector2Array:
	return notched(slot(), bay_corner(), BAY_FILLET, steps)


## The slot the cartridge goes down, seen from the back: the bay, and on down behind the plate to
## the connector's foot.
func slot() -> Rect2:
	var low := height + CARTRIDGE_RISE - cartridge.y - ShapeGeometry.CONNECTOR_HEIGHT
	return Rect2(bay().position.x, low, bay().size.x, height - low)


## The connector at the slot's foot, seen from above: X to the right, Y from the front backwards.
func connector() -> Rect2:
	return Rect2(bay().position.x, depth - slot_thickness(), bay().size.x, slot_thickness()).grow(-CONNECTOR_PLAY)


## The rails down the bay's floor and the lock's hole by its top, seen from the back.
func rails() -> Array[Rect2]:
	var low := bay().position.y + RAIL_ENDS.y
	var length := bay_depth - RAIL_ENDS.x - RAIL_ENDS.y
	return [Rect2(-RAIL_X - RAIL_WIDTH / 2.0, low, RAIL_WIDTH, length),
		Rect2(RAIL_X - RAIL_WIDTH / 2.0, low, RAIL_WIDTH, length)]


func lock() -> Rect2:
	return Rect2(bay().position.x, height - LOCK_BELOW_TOP - LOCK.y, LOCK.x, LOCK.y)


## The power switch's slot, seen from above: X to the right, Y from the front backwards; from the
## seam to its wall in front of the bay.
func power() -> Rect2:
	return Rect2(POWER_FROM_SIDE - width / 2.0 - power_slot / 2.0, seam, power_slot,
		depth - seam - slot_thickness() - POWER_WALL)


## The power switch's knob, at rest at the slot's left end (off).
func knob() -> Rect2:
	var room := power()
	return Rect2(room.position.x + KNOB_MARGIN, room.position.y + KNOB_GAP, KNOB_WIDTH, room.size.y - 2.0 * KNOB_GAP)


## How far the knob slides right, to the slot's right end (on).
func travel() -> float:
	return power_slot - KNOB_WIDTH - 2.0 * KNOB_MARGIN


func bezel() -> Rect2:
	return Rect2(bezel_offset.x - bezel_size.x / 2.0, height - bezel_offset.y - bezel_size.y, bezel_size.x,
		bezel_size.y)


func screen() -> Rect2:
	var box := bezel()
	return Rect2(box.get_center().x - screen_size.x / 2.0, box.end.y - SCREEN_DROP - screen_size.y, screen_size.x,
		screen_size.y)


func led() -> Vector2:
	return Vector2(bezel().position.x + LED_AT.x, bezel().end.y - LED_AT.y)


## The stripe of [param colour] (0 the upper one), left (`left`) or right of the lettering.
func stripe(colour: int, left: bool) -> Rect2:
	var box := bezel()
	var length := STRIPE_LENGTHS.x if left else STRIPE_LENGTHS.y
	var x := box.position.x + STRIPE_INSET if left else box.end.x - STRIPE_INSET - length
	return Rect2(x, box.end.y - STRIPE_INSET - colour * STRIPE_GAP - STRIPE_WIDTH, length, STRIPE_WIDTH)


## The height of the groove across the front.
func band() -> float:
	return bezel().end.y + BAND_GAP


## The pad's outline, a cross with rounded ends and inner corners.
func dpad(steps: int) -> PackedVector2Array:
	var arm := dpad_size.y / 2.0
	var end := dpad_size.x / 2.0
	var at := PackedVector2Array()
	var radii := PackedFloat32Array()
	# Each arm's two outer corners, then the inner corner before the next arm.
	for quarter in 4:
		var turn := Transform2D(PI / 2.0 * quarter, dpad_centre)
		for arm_corner: Vector2 in [Vector2(-arm, -end), Vector2(arm, -end), Vector2(arm, -arm)]:
			at.append(turn * arm_corner)
		radii.append_array([1.2, 1.2, 0.8])
	return ShapeGeometry.filleted(at, radii, steps)


func b_button() -> Vector2:
	return a_button + B_FROM_A


func disc(centre: Vector2, radius: float, steps: int) -> PackedVector2Array:
	return ShapeGeometry.rounded_box(ShapeGeometry.square_around(centre, radius), radius,
		steps)


## The select (`select`) or start button, tilted.
func pill(select: bool, steps: int) -> PackedVector2Array:
	var centre := select_button if select else select_button + START_FROM_SELECT
	var flat := ShapeGeometry.rounded_box(Rect2(-PILL / 2.0, PILL), PILL.y / 2.0, steps)
	return Transform2D(deg_to_rad(PILL_TILT_DEGREES), centre) * flat


## The speaker's slit [param index], from the lowest.
func slit(index: int, steps: int) -> PackedVector2Array:
	var flat := ShapeGeometry.rounded_box(Rect2(-SPEAKER_SLIT / 2.0, SPEAKER_SLIT), SPEAKER_SLIT.x / 2.0, steps)
	return Transform2D(deg_to_rad(SPEAKER_TILT_DEGREES), speaker_start + index * SPEAKER_STEP) * flat


## The centre of the mark [param part] on the front.
func mark(part: StringName) -> Vector2:
	match part:
		&"logo":
			return bezel().position + LOGO_FROM_BEZEL
		&"dot_matrix":
			return (stripe(0, true).end + stripe(1, false).position) / 2.0
		&"battery_label":
			return led() + BATTERY_FROM_LED
		&"a_label", &"b_label":
			return (a_button if part == &"a_label" else b_button()) + LABEL_FROM_BUTTON
		&"select_label", &"start_label":
			var centre := select_button if part == &"select_label" else select_button + START_FROM_SELECT
			return centre + Vector2(0.0, -LABEL_UNDER_PILL).rotated(deg_to_rad(PILL_TILT_DEGREES))
		&"power_label":
			return Vector2(power().position.x + POWER_LABEL_IN + MARKS[part].x / 2.0, (band() + height - bevel) / 2.0)
	return Vector2(PHONES.x, 0.0) + PHONES_LABEL


## The plate under the bay, wider than it, hiding the cartridge's lower part.
func plate() -> Rect2:
	var low := COVER.end.y + PLATE_GAP
	return Rect2(bay().position.x - PLATE_MARGIN, low, bay().size.x + 2.0 * PLATE_MARGIN, bay().position.y - low)


## The battery cover's outline, its latch's tongue up the middle of its top, [param margin] outside
## it, counter-clockwise from the bottom left.
func cover(margin: float, steps: int) -> PackedVector2Array:
	var box := COVER.grow(margin)
	var tongue := Rect2(-LATCH.x / 2.0 - margin, box.end.y, LATCH.x + 2.0 * margin, LATCH.y)
	var convex := 1.5 + margin
	var tip := 1.0 + margin
	var concave := 1.0 - margin
	return ShapeGeometry.filleted(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end,
			Vector2(tongue.end.x, box.end.y), tongue.end, Vector2(tongue.position.x, tongue.end.y), tongue.position,
			Vector2(box.position.x, box.end.y)]),
		PackedFloat32Array([convex, convex, convex, concave, tip, tip, concave, convex]), steps)


## The ribs across the battery cover, but for its flat bottom, and the grip across its latch.
func cover_ribs() -> Array[Rect2]:
	var found: Array[Rect2] = [Rect2(-LATCH_GRIP.x / 2.0, COVER.end.y + LATCH.y - GRIP_BELOW, LATCH_GRIP.x,
		LATCH_GRIP.y)]
	var top := COVER.end.y - COVER_RIB_FROM
	while top - COVER_RIB > COVER.position.y + COVER_FLAT:
		found.append(Rect2(COVER.position.x + COVER_RIB_FROM, top - COVER_RIB, COVER.size.x - 2.0 * COVER_RIB_FROM,
			COVER_RIB))
		top -= RIB_PITCH
	return found


## The ribs on the back: across it between the plate and the battery cover, either side of the
## latch, and on each side of the cover.
func ribs() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var across := width / 2.0 - back_bevel - 0.5
	var latch := NOTCH.end.x + 1.0
	var y := COVER.end.y + RIB_PITCH / 2.0
	while y + RIB_WIDTH / 2.0 < plate().position.y - 1.0:
		found.append_array([Rect2(-across, y - RIB_WIDTH / 2.0, across - latch, RIB_WIDTH),
			Rect2(latch, y - RIB_WIDTH / 2.0, across - latch, RIB_WIDTH)])
		y += RIB_PITCH
	for i in SIDE_SLITS:
		var low := RIB_LOW + i * RIB_PITCH - RIB_WIDTH / 2.0
		if low + RIB_WIDTH < COVER.end.y:
			found.append(Rect2(-across, low, across + COVER.position.x - 1.0, RIB_WIDTH))
			found.append(Rect2(COVER.end.x + 1.0, low, across - COVER.end.x - 1.0, RIB_WIDTH))
	return found


## The screws' centres on the back, the same seen from behind.
func screws() -> PackedVector2Array:
	var found := PackedVector2Array()
	var x := width / 2.0 - SCREW_FROM_SIDE
	for below in SCREWS:
		found.append_array([Vector2(-x, height - below), Vector2(x, height - below)])
	return found


## The back's outline seen from behind (see [constant ShapeGeometry.BEHIND]), with a point where
## its face, inside its rounded edge, crosses each line its holes are laid out by (see
## [method back_lines]).
func back_behind(steps: int) -> PackedVector2Array:
	var loop := Transform2D.FLIP_X * back(steps)
	loop.reverse()
	for x in back_lines():
		loop = ShapeGeometry.crossed(loop, x, back_bevel)
	return loop


## The lines down the back through its holes: the screws' columns and the middle, through the latch's
## notch.
func back_lines() -> PackedFloat32Array:
	var x := width / 2.0 - SCREW_FROM_SIDE
	return PackedFloat32Array([-x, 0.0, x])


## The holes sunk in the back, seen from behind: the latch's notch, the screws'.
func back_holes(steps: int) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = [ShapeGeometry.rounded_box(NOTCH, 0.5, steps, 0.0)]
	for screw in screws():
		found.append(ShapeGeometry.crossed(disc(screw, SCREW_RADIUS, steps), screw.x))
	return found


## The openings in the side of [param side] (-1 left, 1 right), seen from it: X from the front
## backwards, Y up; each with the radius of its corners.
func openings(side: float) -> Dictionary[Rect2, float]:
	var found: Dictionary[Rect2, float] = {window(side): 1.0}
	var port := LINK if side > 0.0 else JACK
	var behind := LINK_BEHIND if side > 0.0 else JACK_BEHIND
	found[Rect2(seam + behind, height - port.x - port.y / 2.0, port.z, port.y)] = 1.0 if side > 0.0 else port.y / 2.0
	for i in SIDE_SLITS:
		found[Rect2(seam + 2.0, RIB_LOW + i * RIB_PITCH - RIB_WIDTH / 2.0, depth - seam - back_bevel - 2.5,
			RIB_WIDTH)] = RIB_WIDTH / 2.0
	return found


## The window of the side's wheel: the contrast one (left) in front of the seam, the volume one
## (right) behind it.
func window(side: float) -> Rect2:
	var sized := CONTRAST_WINDOW if side < 0.0 else VOLUME_WINDOW
	var front := seam - SEAM_BEVEL - sized.z if side < 0.0 else seam + SEAM_BEVEL
	return Rect2(front, height - sized.x - sized.y / 2.0, sized.z, sized.y)


## Where a seated cartridge stands, in the model's space: upright in the bay, its label to the back,
## flush with it.
func seat() -> Transform3D:
	var centre := Vector3(0.0, height + CARTRIDGE_RISE - cartridge.y / 2.0, (cartridge.z - depth) / 2.0)
	return Transform3D(Basis(Vector3.UP, PI), centre * MeshBuilder.UNITS_PER_MM)


func _arrays(part: StringName, detail: int) -> Array:
	return GbGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var controls: Array[PackedVector2Array] = [ShapeGeometry.square(bezel()), dpad(3),
		disc(a_button, button_diameter / 2.0, 3), disc(b_button(), button_diameter / 2.0, 3), pill(true, 3),
		pill(false, 3)]
	for i in speaker_slits:
		controls.append(slit(i, 3))
	var on_floor := rails()
	on_floor.append(lock())
	var on_back := _outlines([plate(), COVER])
	for screw in screws():
		on_back.append(disc(screw, SCREW_RADIUS, 3))
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and depth > 0.0 and cartridge.x > 0.0
			and cartridge.y > 0.0 and cartridge.z > 0.0,
		# Each shell holds its rounded edges, and the corners round more than the edges: their chords
		# too, three a quarter at least, as the slabs move their outlines in along the corners' bisectors.
		&"shells_hold_their_edges": bevel > 0.0 and back_bevel > 0.0 and seam > bevel + SEAM_BEVEL + 0.1
			and corner * cos(PI / 12.0) > maxf(bevel, back_bevel) + 0.1 and big_corner > corner
			and big_corner < minf(width, height) / 2.0 - corner,
		&"bay_in_the_back": slot_thickness() > back_bevel + 0.5
			and (width - bay().size.x) / 2.0 > corner + bay_corner() + 1.0
			and bay_depth > bay_corner() + BAY_FILLET + 1.0 and plate().size.y > 4.0,
		# Its lower part hides behind the plate, down to the connector: the plate covers the slot's
		# foot and its rounded edges.
		&"cartridge_stands_in_the_bay": cartridge.y > bay_depth + CARTRIDGE_RISE + 2.0
			and slot().position.y > plate().position.y + BAY_FILLET + 0.5 and PLATE_MARGIN > back_bevel + 0.2
			and ShapeGeometry.holds_connector(connector()),
		# The rails clear of the plate, of each other and of the lock's hole, all on the bay's floor;
		# the cartridge clear of the rails.
		&"rails_on_the_bay_floor": bay_depth > RAIL_ENDS.x + RAIL_ENDS.y + 2.0 and BAY_PLAY.y > RAIL_RISE + 0.1
			and ShapeGeometry.apart(on_floor, bay().grow(0.01), 1.0),
		# The knob slides in its slot, beside the front's top corner, its sides straight between its
		# rounded corners, long enough for its bevel.
		&"power_slot_on_the_top": knob().size.y > 3.0 and travel() > 1.0
			and power_slot / 2.0 < POWER_FROM_SIDE - corner - 1.0 and height > SLOT_SINK + 1.0,
		&"screen_in_the_bezel": BEZEL_CORNERS.y < minf(bezel_size.x, bezel_size.y) / 2.0
			and ShapeGeometry.within(screen(), bezel().grow(-1.0)) and screen_size.x > 2.0 * SCREEN_ROUND + 0.1
			and screen_size.y > 2.0 * SCREEN_ROUND + 0.1,
		&"light_beside_the_screen": ShapeGeometry.within(_led(), bezel().grow(-1.0))
			and not ShapeGeometry.overlap(_led().grow(1.0), screen()),
		# Over the screen by the constants they are laid out with, the left ones clear of the right ones.
		&"stripes_over_the_screen": stripe(0, true).end.x + 2.0 < stripe(0, false).position.x,
		# The grooves run below the front's top corners, the short ones up to its rounded edge.
		&"band_under_the_top": height - band() > corner + 1.0 and height - band() > bevel + 1.0
			and BAND_END > corner and BAND_END < width / 2.0 - 1.0,
		&"controls_on_the_front": dpad_size.y > 2.6 and dpad_size.x > dpad_size.y + 4.0 and button_diameter > 2.6
			and speaker_slits > 0 and _laid_out(controls, face(bevel + 0.2, 8), 0.5),
		&"plates_and_screws_on_the_back": _laid_out(on_back, face(back_bevel + 1.0, 8), 1.0)
			and ShapeGeometry.within(STICKER, plate().grow(-1.0))
			and ribs().all(func(rib: Rect2) -> bool: return rib.size.x > 1.0)
			and _laid_out(_outlines(ribs()), face(back_bevel + 0.2, 8), 0.0),
		&"openings_on_the_sides": _openings_fit(-1.0) and _openings_fit(1.0),
	}


func _led() -> Rect2:
	return ShapeGeometry.square_around(led(), LED_RADIUS)


## Whether each opening of the side of [param side] lies on its flat part, clear of the seam and of
## the others, and its wheel shows through its window.
func _openings_fit(side: float) -> bool:
	var low := (big_corner if side > 0.0 else corner) + 1.0
	var flat := Rect2(bevel + 0.5, low, depth - bevel - back_bevel - 1.0, height - corner - 1.0 - low)
	var holes := _outlines(openings(side).keys())
	holes.append(ShapeGeometry.square(Rect2(seam - SEAM_BEVEL + 0.01, low + 0.1, 2.0 * SEAM_BEVEL - 0.02,
		flat.size.y - 0.2)))
	var chord := 2.0 * sqrt(WHEEL_RADIUS * WHEEL_RADIUS - (WHEEL_RADIUS - WHEEL_OUT) ** 2)
	return window(side).size.x > WHEEL_THICKNESS + 1.0 and window(side).size.y > chord + 1.0 \
		and _laid_out(holes, ShapeGeometry.square(flat), 0.0)


## Whether every outline of [param laid] lies within [param region] and keeps [param gap] from the
## others.
static func _laid_out(laid: Array[PackedVector2Array], region: PackedVector2Array, gap: float) -> bool:
	for i in laid.size():
		if not ShapeGeometry.inside(laid[i], region):
			return false
		var grown: Array[PackedVector2Array] = [laid[i]]
		if gap > 0.0:
			grown = Geometry2D.offset_polygon(laid[i], gap)
		for other: PackedVector2Array in laid.slice(i + 1):
			for around: PackedVector2Array in grown:
				if not Geometry2D.intersect_polygons(around, other).is_empty():
					return false
	return true


static func _outlines(boxes: Array) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	for box: Rect2 in boxes:
		found.append(ShapeGeometry.square(box))
	return found
