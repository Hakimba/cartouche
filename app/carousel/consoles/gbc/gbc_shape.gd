# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GbcShape
extends ModelShape
## The dimensions of the Game Boy Color, a handheld in an opaque shell, in millimetres, standing as
## it is held: its face towards +Z, its top up (+Y) (see [GbcGeometry]). The shell's front half runs
## from the [method seam] to the face, its edges rounded, its top corners tighter than its bottom
## ones; its face is flat over the bezel and a [method panel] below it, and rolls back from the panel
## towards the sides and, most, towards the bottom edge (see [method drop]). Its back half has at its
## top the pocket the cartridge goes down into, label to the back; the slot goes on down behind the
## back plate's wall to the connector at its foot, the cartridge's lower part in it; the sticker
## sunk in the back plate, below that the battery cover's bulge, the cover standing on it with the
## GAME BOY panel sunk in it, its latch's tongue over the notch sunk in the bulge; the screws sunk in
## the pocket's sides and in the back plate by its edges. On the face: the dark bezel with the screen and
## the power light, the D-pad, A and B, select and start, each in a dark gap, the speaker's holes; on
## the top, the infrared window; on the right side, the power switch, sliding up; on the left, the
## volume wheel and the link port; ribs on both sides above them. Plan positions are of centres, X to
## the right and Y up, from the centre of the outline.

## How far the bezel stands out of the face; the power light's radius.
const BEZEL_RAISE := 0.5
const LED_RADIUS := 1.1
## The D-pad's arms, as a fraction of its size; how far it, A and B, and select and start stand out.
const DPAD_ARM := 0.34
const DPAD_RISE := 2.0
const BUTTON_RISE := 2.5
const PILL := Vector2(6.8, 2.8)
const PILL_RISE := 1.2
## The dark gap around each button, where it comes out of the face.
const GAP := 0.5
## The speaker's holes.
const HOLE_RADIUS := 0.55
const HOLE_PITCH := 2.4
## The panel's bottom corners and its top ones; how far below the bezel the face takes to roll back
## fully towards the sides.
const PANEL_CORNERS := Vector2(6.0, 1.0)
const ROLL_EASE := 8.0
## The power switch's recess along the side (its length up the side, its width across) and its knob;
## how far the knob stands out of the side, and the room it leaves at each end of the recess.
const RECESS := Vector2(15.0, 4.2)
const KNOB := Vector2(6.0, 3.2)
const KNOB_PROUD := 0.4
const KNOB_MARGIN := 0.5
## The volume wheel, standing out of the left side; the link port above it.
const WHEEL_RADIUS := 7.5
const WHEEL_PROUD := 1.8
const WHEEL_THICKNESS := 3.0
const WHEEL_TEETH := 28
const LINK := Vector2(9.0, 5.0)
const LINK_ABOVE := 14.5
## The ribs on each side: how many, each one's length up the side and across it, how far it stands
## out, and their spacing.
const RIBS := 4
const RIB := Vector2(1.2, 5.0)
const RIB_PROUD := 0.6
const RIB_PITCH := 4.0
## How far the infrared window runs back from the face's rounded edge.
const IR_DEPTH := 5.0
## The battery cover's bulge above the bottom edge, how round its edges are, and its top corners.
const BULGE_MARGIN := 1.5
const BULGE_BEVEL := 2.0
const BULGE_TOP_CORNER := 4.0
## The screws on the back: the upper ones', in the pocket's sides, how far below the top, the lower
## ones' in from the sides and below the top; their holes' radius and depth, their heads' radius and
## height.
const SCREW_BELOW_TOP := 13.7
const LOW_SCREWS := Vector2(5.0, 56.6)
const SCREW_RADIUS := 2.2
const SCREW_SINK := 3.0
const SCREW_HEAD := Vector2(1.7, 0.8)
## The sticker, its corners, how far below the top and how deep it is sunk.
const STICKER := Vector2(60.0, 25.6)
const STICKER_CORNER := 1.0
const STICKER_BELOW_TOP := 41.8
const STICKER_SINK := 0.3
## The battery cover on the bulge: in from its sides and its top, up from its bottom; how far it
## stands out, its parting gap. Its latch's tongue down the middle of its bottom, how wide and how far
## down; the notch below it in the bulge, how high and deep. The panel sunk in it: its size and corners,
## how far below the cover's middle, how deep; the moulded words' image in it.
const COVER_IN := Vector3(3.0, 2.5, 18.5)
const COVER_RAISE := 0.4
const COVER_GAP := 0.4
const LATCH := Vector2(14.6, 4.2)
const NOTCH := Vector3(16.0, 4.0, 2.0)
const PANEL := Vector2(39.4, 11.7)
const PANEL_CORNER := 1.0
const PANEL_DROP := 3.0
const PANEL_SINK := 0.3
const COVER_MARK := Vector2(34.0, 7.0)
## The slot's corners at its foot; the connector there, in from the slot's walls by this.
const SLOT_FILLET := 1.0
const CONNECTOR_PLAY := 0.3
## The marks printed and moulded on the face, by part: the size of each one's image (the folder's
## gbc_<part>.svg). The logo and the power light's two lie on the bezel, the A and B ones on the
## buttons' tops.
const MARKS: Dictionary[StringName, Vector2] = {
	&"logo": Vector2(40.0, 5.4), &"power_waves": Vector2(4.8, 2.6), &"power_label": Vector2(8.0, 2.2),
	&"comm_label": Vector2(14.4, 2.6), &"nintendo": Vector2(23.0, 5.2), &"select_label": Vector2(11.4, 3.0),
	&"start_label": Vector2(8.6, 3.0), &"a_label": Vector2(3.6, 3.6), &"b_label": Vector2(3.6, 3.6),
}
const ON_BEZEL: Array[StringName] = [&"logo", &"power_waves", &"power_label"]
const ON_BUTTONS: Array[StringName] = [&"a_label", &"b_label"]
## Where the marks' centres are: the logo over the bezel's bottom and Nintendo's under it, the power
## light's waves and label from the light, the infrared window's from its middle across and from the top down, the
## select and start ones from their buttons.
const LOGO_OVER_BEZEL := 6.8
const NINTENDO_UNDER_BEZEL := 7.55
const WAVES_FROM_LED := Vector2(4.0, -0.05)
const POWER_FROM_LED := Vector2(3.3, -3.2)
const COMM_FROM_IR := Vector2(4.5, -3.0)
const LABEL_FROM_PILL := Vector2(-0.25, -6.0)

@export var width := 78.0:
	set(value):
		width = value
		emit_changed()
@export var height := 133.5:
	set(value):
		height = value
		emit_changed()
## The shell's depth, from its back to its face; the battery cover stands further out.
@export var depth := 22.0:
	set(value):
		depth = value
		emit_changed()
@export var top_corner := 3.5:
	set(value):
		top_corner = value
		emit_changed()
@export var bottom_corner := 9.0:
	set(value):
		bottom_corner = value
		emit_changed()
## How round the shell's edges are.
@export var bevel := 2.0:
	set(value):
		bevel = value
		emit_changed()
## The face's flat panel below the bezel: its width, and its bottom's height above the bottom edge.
@export var panel_width := 52.0:
	set(value):
		panel_width = value
		emit_changed()
@export var chin_height := 13.8:
	set(value):
		chin_height = value
		emit_changed()
## How far the face has rolled back at its edge, towards each side and towards the bottom.
@export var side_drop := 1.5:
	set(value):
		side_drop = value
		emit_changed()
@export var chin_drop := 3.5:
	set(value):
		chin_drop = value
		emit_changed()
## The pocket at the top of the back: how far down from the top it is open, how deep from the back
## (the slot's front wall).
@export var pocket_length := 21.0:
	set(value):
		pocket_length = value
		emit_changed()
@export var pocket_depth := 10.3:
	set(value):
		pocket_depth = value
		emit_changed()
## The slot between the pocket's sides.
@export var slot_width := 58.5:
	set(value):
		slot_width = value
		emit_changed()
## The cartridge the slot takes, its width, height and thickness; how far its top stands out of the
## console's top, and its label behind the back (in front of the back plate's wall).
@export var cartridge := Vector3(58.0, 65.5, 7.5):
	set(value):
		cartridge = value
		emit_changed()
@export var cartridge_rise := 3.0:
	set(value):
		cartridge_rise = value
		emit_changed()
@export var cartridge_inset := 2.5:
	set(value):
		cartridge_inset = value
		emit_changed()
## The battery cover's bulge on the back, its width and height, and how far it stands out.
@export var battery_size := Vector2(74.0, 62.5):
	set(value):
		battery_size = value
		emit_changed()
@export var battery_rise := 5.4:
	set(value):
		battery_rise = value
		emit_changed()
## The bezel, its top this far below the console's top, its bottom corners rounder than its top
## ones; the screen, its top this far below the bezel's.
@export var bezel_size := Vector2(67.8, 60.2):
	set(value):
		bezel_size = value
		emit_changed()
@export var bezel_top := 5.3:
	set(value):
		bezel_top = value
		emit_changed()
@export var bezel_corners := Vector2(4.5, 2.0):
	set(value):
		bezel_corners = value
		emit_changed()
@export var screen_size := Vector2(44.5, 39.5):
	set(value):
		screen_size = value
		emit_changed()
@export var screen_top := 7.6:
	set(value):
		screen_top = value
		emit_changed()
## The power light, on the bezel left of the screen.
@export var led := Vector2(-31.4, 42.5):
	set(value):
		led = value
		emit_changed()
@export var dpad := Vector2(-22.3, -21.0):
	set(value):
		dpad = value
		emit_changed()
@export var dpad_size := 18.8:
	set(value):
		dpad_size = value
		emit_changed()
@export var button_a := Vector2(27.5, -18.6):
	set(value):
		button_a = value
		emit_changed()
@export var button_b := Vector2(13.6, -23.2):
	set(value):
		button_b = value
		emit_changed()
@export var button_diameter := 9.3:
	set(value):
		button_diameter = value
		emit_changed()
## Start, select its mirror left of the middle.
@export var start := Vector2(5.6, -43.0):
	set(value):
		start = value
		emit_changed()
## The speaker's holes, within this circle and the face.
@export var speaker := Vector2(25.6, -52.0):
	set(value):
		speaker = value
		emit_changed()
@export var speaker_radius := 11.0:
	set(value):
		speaker_radius = value
		emit_changed()
## The Y of the power switch's recess, and how far its knob slides up to switch on.
@export var power_y := 29.2:
	set(value):
		power_y = value
		emit_changed()
@export var power_travel := 4.5:
	set(value):
		power_travel = value
		emit_changed()
## The Y of the volume wheel's centre; of the middle of the ribs on both sides.
@export var wheel_y := 17.7:
	set(value):
		wheel_y = value
		emit_changed()
@export var ribs_y := 49.0:
	set(value):
		ribs_y = value
		emit_changed()
## The infrared window's centre and width, along the top.
@export var ir_x := -21.0:
	set(value):
		ir_x = value
		emit_changed()
@export var ir_width := 12.0:
	set(value):
		ir_width = value
		emit_changed()


func parts() -> Array[StringName]:
	return GbcGeometry.PARTS


func surfaces() -> Array[StringName]:
	var found: Array[StringName] = [&"openings", &"sticker", &"cover_mark"]
	found.append_array(MARKS.keys())
	return found


func outline() -> Rect2:
	return Rect2(-width / 2.0, -height / 2.0, width, height)


## The face's flat part, inside its rounded edge.
func face() -> Rect2:
	return outline().grow(-bevel)


## The face's flat panel below the bezel, reaching up to the top, where the face is flat across.
func panel() -> Rect2:
	return Rect2(-panel_width / 2.0, chin_height - height / 2.0, panel_width, height - chin_height - bevel - 1.0)


## How far the face has rolled back at [param at]: not at all over the panel and above the bezel's
## bottom, up to [member side_drop] towards the sides and [member chin_drop] towards the bottom edge,
## the two added together in the bottom corners.
func drop(at: Vector2) -> float:
	var corner := Vector2(panel_width / 2.0, panel().position.y) + Vector2(-1.0, 1.0) * PANEL_CORNERS.x
	# How far out of the panel, as from a rounded box.
	var off := Vector2(maxf(absf(at.x) - corner.x, 0.0), minf(at.y - corner.y, 0.0))
	var out := off.normalized() * maxf(off.length() - PANEL_CORNERS.x, 0.0)
	var sides := minf(out.x / (width / 2.0 - bevel - panel_width / 2.0), 1.0)
	var chin := minf(-out.y / (chin_height - bevel), 1.0)
	var eased := clampf((bezel().position.y - at.y) / ROLL_EASE, 0.0, 1.0)
	return side_drop * _rolled(sides) * eased + chin_drop * _rolled(chin)


## The heights at which the face's rolling back changes down the sides: the bezel's bottom, where it
## has fully rolled back, and just above the panel's bottom corners. The front half's outlines get
## a point at each.
func levels() -> PackedFloat32Array:
	var bottom := bezel().position.y
	return PackedFloat32Array([bottom, bottom - ROLL_EASE, panel().position.y + PANEL_CORNERS.x + 1.0])


## Where the front half meets the back half, from the middle of the depth.
func seam() -> float:
	return pocket_depth - depth / 2.0


## The middle of the front half's flat sides, where the switch, the wheel and the link port are.
func side_middle() -> float:
	return (seam() + depth / 2.0) / 2.0


## The pocket's opening between its sides.
func slot() -> Rect2:
	return Rect2(-slot_width / 2.0, height / 2.0 - pocket_length, slot_width, pocket_length)


## The back half below the pocket.
func back_plate() -> Rect2:
	return Rect2(-width / 2.0, -height / 2.0, width, height - pocket_length)


## How thick the back plate's wall is, the slot's back wall below the pocket: as thick as its edges
## round, and a little more.
func back_wall() -> float:
	return bevel + 0.2


## The back half below the pocket, square-edged in front of its wall, with the slot cut out of its
## top down to the connector's foot.
func slotted(steps: int) -> PackedVector2Array:
	var box := back_plate()
	var top := box.end.y
	var low := slot_floor()
	var half := slot_width / 2.0
	return ShapeGeometry.filleted(PackedVector2Array([box.position, Vector2(box.end.x, box.position.y),
			Vector2(box.end.x, top), Vector2(half, top), Vector2(half, low), Vector2(-half, low), Vector2(-half, top),
			Vector2(box.position.x, top)]),
		PackedFloat32Array([bottom_corner, bottom_corner, 0.0, 0.0, SLOT_FILLET, SLOT_FILLET, 0.0, 0.0]), steps)


## The foot of the slot, under the connector.
func slot_floor() -> float:
	return cartridge_bottom() - ShapeGeometry.CONNECTOR_HEIGHT


## The connector at the slot's foot, in plan: X to the right, Y towards the back.
func connector() -> Rect2:
	return Rect2(-slot_width / 2.0, -seam(), slot_width, pocket_depth - back_wall()).grow(-CONNECTOR_PLAY)


## The pocket's side on the [param side] (-1 left, 1 right), reaching down into the back plate.
func pocket_side(side: float) -> Rect2:
	var low := slot().position.y - bevel - 1.0
	var outer := Rect2(slot_width / 2.0, low, (width - slot_width) / 2.0, height / 2.0 - low)
	return outer if side > 0.0 else Rect2(-outer.end.x, low, outer.size.x, outer.size.y)


func bulge() -> Rect2:
	return Rect2(-battery_size.x / 2.0, BULGE_MARGIN - height / 2.0, battery_size.x, battery_size.y)


func bezel() -> Rect2:
	var top := height / 2.0 - bezel_top
	return Rect2(-bezel_size.x / 2.0, top - bezel_size.y, bezel_size.x, bezel_size.y)


func screen() -> Rect2:
	var top := bezel().end.y - screen_top
	return Rect2(-screen_size.x / 2.0, top - screen_size.y, screen_size.x, screen_size.y)


## The centre of the mark [param part] on the face.
func mark(part: StringName) -> Vector2:
	match part:
		&"logo":
			return Vector2(0.0, bezel().position.y + LOGO_OVER_BEZEL)
		&"nintendo":
			return Vector2(0.0, bezel().position.y - NINTENDO_UNDER_BEZEL)
		&"power_waves":
			return led + WAVES_FROM_LED
		&"power_label":
			return led + POWER_FROM_LED
		&"comm_label":
			return Vector2(ir_x, height / 2.0) + COMM_FROM_IR
		&"select_label":
			return select() + LABEL_FROM_PILL
		&"start_label":
			return start + LABEL_FROM_PILL
	return button_a if part == &"a_label" else button_b


func select() -> Vector2:
	return Vector2(-start.x, start.y)


## The pill of select or start centred on [param centre], grown by [param by].
func pill(centre: Vector2, by := 0.0) -> Rect2:
	return ShapeGeometry.centred(centre, PILL).grow(by)


## The power switch's recess, along the right side: Y up it and Z across it.
func recess() -> Rect2:
	return Rect2(Vector2(power_y, side_middle()) - RECESS / 2.0, RECESS)


## The knob at rest, at the recess's lower end.
func knob() -> Rect2:
	var room := recess()
	return Rect2(room.position.x + KNOB_MARGIN, room.get_center().y - KNOB.y / 2.0, KNOB.x, KNOB.y)


func wheel_centre() -> Vector2:
	return Vector2(WHEEL_RADIUS - WHEEL_PROUD - width / 2.0, wheel_y)


## The link port, along the left side: Y up it and Z across it.
func link() -> Rect2:
	return Rect2(Vector2(wheel_y + LINK_ABOVE, side_middle()) - LINK / 2.0, LINK)


## The ribs along each side: Y up it and Z across it.
func ribs() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for i in RIBS:
		var at := ribs_y + (i - (RIBS - 1) / 2.0) * RIB_PITCH
		found.append(Rect2(Vector2(at, side_middle()) - RIB / 2.0, RIB))
	return found


## The screws on the back, the same seen from behind: in the middle of the pocket's sides, and by
## the back plate's edges.
func screws() -> PackedVector2Array:
	var side := (width + slot_width) / 4.0
	var top := height / 2.0 - SCREW_BELOW_TOP
	var beside := width / 2.0 - LOW_SCREWS.x
	var low := height / 2.0 - LOW_SCREWS.y
	return PackedVector2Array([Vector2(-side, top), Vector2(side, top), Vector2(-beside, low), Vector2(beside, low)])


## The sticker between the slot and the battery cover.
func sticker() -> Rect2:
	return Rect2(-STICKER.x / 2.0, height / 2.0 - STICKER_BELOW_TOP - STICKER.y, STICKER.x, STICKER.y)


## The holes sunk in the back plate, seen from behind, crossed by [method plate_lines]: the
## sticker's, the lower screws'.
func plate_holes(steps: int) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = [ShapeGeometry.rounded_box(sticker(), STICKER_CORNER, steps, 0.0)]
	for screw in screws().slice(2):
		found.append(ShapeGeometry.rounded_box(ShapeGeometry.square_around(screw, SCREW_RADIUS), SCREW_RADIUS, steps))
	return found


func plate_lines() -> PackedFloat32Array:
	var x := width / 2.0 - LOW_SCREWS.x
	return PackedFloat32Array([-x, 0.0, x])


## The back plate's outline seen from behind (see [constant ShapeGeometry.BEHIND]), with a point
## where its face, inside its rounded edge, crosses each of [method plate_lines].
func plate_behind(steps: int) -> PackedVector2Array:
	var hidden := bevel + 0.1
	var loop := ShapeGeometry.filleted(ShapeGeometry.square(back_plate()),
		PackedFloat32Array([bottom_corner, bottom_corner, hidden, hidden]), steps)
	for x in plate_lines():
		loop = ShapeGeometry.crossed(loop, x, bevel)
	return loop


## The battery cover's outline, its latch's tongue down the middle of its bottom, [param margin]
## outside it, counter-clockwise from the tongue's bottom left.
func cover(margin: float, steps: int) -> PackedVector2Array:
	var box := Rect2(bulge().position + Vector2(COVER_IN.x, COVER_IN.z),
		battery_size - Vector2(2.0 * COVER_IN.x, COVER_IN.y + COVER_IN.z)).grow(margin)
	var tongue := Rect2(-LATCH.x / 2.0 - margin, box.position.y - LATCH.y, LATCH.x + 2.0 * margin, LATCH.y)
	var convex := 2.0 + margin
	var tip := 1.0 + margin
	var concave := 1.0 - margin
	return ShapeGeometry.crossed(ShapeGeometry.filleted(PackedVector2Array([tongue.position,
			Vector2(tongue.end.x, tongue.position.y), Vector2(tongue.end.x, box.position.y),
			Vector2(box.end.x, box.position.y), box.end, Vector2(box.position.x, box.end.y), box.position,
			Vector2(tongue.position.x, box.position.y)]),
		PackedFloat32Array([tip, tip, concave, convex, convex, convex, convex, concave]), steps), 0.0)


## The panel sunk in the battery cover, and the notch in the bulge under its latch.
func cover_panel() -> Rect2:
	var middle := ShapeGeometry.bounds(cover(0.0, 3)).get_center() - Vector2(0.0, PANEL_DROP)
	return ShapeGeometry.centred(middle, PANEL)


func notch() -> Rect2:
	var top := ShapeGeometry.bounds(cover(0.0, 3)).position.y - COVER_GAP - 0.2
	return Rect2(-NOTCH.x / 2.0, top - NOTCH.y, NOTCH.x, NOTCH.y)


## The cartridge's lowest edge once in.
func cartridge_bottom() -> float:
	return height / 2.0 + cartridge_rise - cartridge.y


## Where a seated cartridge stands, in the model's space: upright in the pocket, its label to the
## back.
func seat() -> Transform3D:
	var centre := Vector3(0.0, cartridge_bottom() + cartridge.y / 2.0,
		cartridge_inset + cartridge.z / 2.0 - depth / 2.0)
	return Transform3D(Basis(Vector3.UP, PI), centre * MeshBuilder.UNITS_PER_MM)


func _arrays(part: StringName, detail: int) -> Array:
	return GbcGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var flat := face().grow(-0.5)
	var down := levels()
	# The sides' flat part, between the face's rolling back and the top corners, and across.
	var straight := Vector2(down[0], height / 2.0 - top_corner)
	var sides := Vector2(seam() + bevel, depth / 2.0 - bevel)
	var buttons: Array[Rect2] = [ShapeGeometry.square_around(dpad, dpad_size / 2.0 + GAP),
		ShapeGeometry.square_around(button_a, button_diameter / 2.0 + GAP),
		ShapeGeometry.square_around(button_b, button_diameter / 2.0 + GAP), pill(select(), GAP), pill(start, GAP)]
	var ribbed := ribs()[0].merge(ribs()[-1])
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and depth > 0.0 and cartridge.x > 0.0
			and cartridge.y > 0.0 and cartridge.z > 0.0 and battery_size.x > 0.0 and battery_size.y > 0.0
			and screen_size.x > 0.0 and screen_size.y > 0.0 and ir_width > 0.0,
		&"shell_holds_its_edges": bevel > 0.0 and top_corner > bevel + 0.1 and bottom_corner > bevel + 0.1
			and 2.0 * maxf(top_corner, bottom_corner) < width and top_corner + bottom_corner < height,
		# Each level down the sides lies on their straight part, below the one above it; the face keeps
		# in front of the seam's rounded edge where it has rolled back most.
		&"face_rolls_back_below_the_bezel": side_drop > 0.0 and chin_drop > 0.0
			and panel_width > 2.0 * PANEL_CORNERS.x + 1.0 and panel_width < width - 2.0 * bevel - 1.0
			and chin_height > bevel + 1.0 and down[0] < minf(straight.y, panel().end.y - PANEL_CORNERS.y)
			and down[1] > down[2]
			and down[2] > bottom_corner - height / 2.0
			and side_drop + chin_drop < depth / 2.0 - seam() - 2.0 * bevel - 1.0,
		# The front half, the back plate and the pocket's sides each hold their rounded edges.
		&"pocket_in_the_back": pocket_depth > 2.0 * bevel + 0.1 and depth - pocket_depth > 2.0 * bevel + 0.1
			and (width - slot_width) / 2.0 > 2.0 * top_corner + 0.1 and pocket_length > top_corner + 0.1
			and pocket_length < height / 2.0,
		&"slot_takes_the_cartridge": slot_width > cartridge.x + 0.4 and cartridge_inset > back_wall() + 0.1
			and pocket_depth > cartridge_inset + cartridge.z + 0.2,
		# Its top stands out of the console's, its bottom goes down behind the back plate's wall onto
		# the connector, which stands above the bottom edge's rounded corners.
		&"cartridge_stands_in_the_slot": cartridge_rise > 0.0
			and cartridge.y - cartridge_rise > pocket_length + bevel + SLOT_FILLET + 1.0
			and slot_floor() > bottom_corner + 1.0 - height / 2.0 and ShapeGeometry.holds_connector(connector()),
		# Its bottom corners follow the outline's, inside them.
		&"battery_cover_on_the_back": battery_rise + 0.5 > 2.0 * BULGE_BEVEL + 0.1
			and bottom_corner - BULGE_MARGIN > BULGE_BEVEL + 0.1 and battery_size.x < width - 2.0 * BULGE_MARGIN
			and battery_size.x > 2.0 * bottom_corner and battery_size.y > bottom_corner + BULGE_TOP_CORNER,
		# The upper screws' holes on the pocket's sides' faces; the sticker and the lower ones' on the
		# back plate's, between the pocket and the bulge, clear of each other; the notch above the
		# bulge's bottom edge, the panel inside the cover.
		&"screws_and_sticker_on_the_back": (width - slot_width) / 2.0 > 2.0 * (SCREW_RADIUS + bevel) + 1.0
			and SCREW_BELOW_TOP + SCREW_RADIUS + 1.0 < pocket_length
			and ShapeGeometry.apart([sticker(), ShapeGeometry.square_around(screws()[2], SCREW_RADIUS),
				ShapeGeometry.square_around(screws()[3], SCREW_RADIUS)],
				Rect2(-width / 2.0 + bevel + 0.5, bulge().end.y + 1.0, width - 2.0 * bevel - 1.0,
					slot().position.y - 2.0 - bulge().end.y), 1.0)
			and notch().position.y > bulge().position.y + BULGE_BEVEL + 1.0
			and ShapeGeometry.within(cover_panel(), ShapeGeometry.bounds(cover(-2.0, 3))),
		&"bezel_on_the_face": bezel_corners.x > 0.4 and bezel_corners.y > 0.4
			and 2.0 * maxf(bezel_corners.x, bezel_corners.y) < minf(bezel_size.x, bezel_size.y)
			and ShapeGeometry.within(bezel(), flat) and ShapeGeometry.within(screen(), bezel().grow(-1.0))
			and ShapeGeometry.within(ShapeGeometry.square_around(led, LED_RADIUS + 0.5), bezel())
			and not screen().grow(LED_RADIUS + 0.5).has_point(led),
		&"buttons_on_the_face": dpad_size > 2.0 and button_diameter > 2.0 and ShapeGeometry.apart(buttons, flat)
			and buttons.all(func(button: Rect2) -> bool: return not ShapeGeometry.overlap(button, bezel())),
		&"speaker_on_the_face": speaker_radius > HOLE_PITCH and flat.has_area() and flat.has_point(speaker),
		&"switch_on_the_right_side": power_travel > 0.5
			and power_travel < RECESS.x - KNOB.x - 2.0 * KNOB_MARGIN
			and _along(recess(), straight, sides),
		&"wheel_and_link_on_the_left_side": _along(link(), straight, sides)
			and _along(Rect2(wheel_y - WHEEL_RADIUS, side_middle() - WHEEL_THICKNESS / 2.0,
				2.0 * WHEEL_RADIUS, WHEEL_THICKNESS), straight, sides)
			and link().position.x > wheel_y + WHEEL_RADIUS,
		&"ribs_above_the_switch_and_the_link": _along(ribbed, straight, sides)
			and ribbed.position.x > maxf(recess().end.x, link().end.x),
		&"ir_window_on_the_top": absf(ir_x) + ir_width / 2.0 < width / 2.0 - top_corner
			and depth / 2.0 - bevel - 0.4 - IR_DEPTH > seam() + bevel,
	}


## How far the face has rolled back [param t] of the way to its edge, as a fraction of how far it
## does at the edge: already sloping where it leaves the panel, steeper towards the edge.
static func _rolled(t: float) -> float:
	return t * (1.0 + t) / 2.0


## Whether [param room] (Y up a side, Z across it) lies within the side's flat part: [param straight]
## up it and [param sides] across it.
static func _along(room: Rect2, straight: Vector2, sides: Vector2) -> bool:
	return room.position.x > straight.x and room.end.x < straight.y and room.position.y > sides.x \
		and room.end.y < sides.y
