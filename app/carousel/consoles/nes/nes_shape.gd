# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name NesShape
extends ModelShape
## The dimensions of the NES (PAL NES-001), a front-loading console, in millimetres, as it lies on a
## table: its top up (+Y), its front towards +Z (see [NesGeometry]). Positions are of centres, X to
## the right and Y up, in the model's axes; X from the middle of the body, Y from the table.
##
## Two shells: the lower one, its sides sloping in towards the table, and the upper one, a dark
## stripe across it from front to back over vents. Left of the stripe, a notch in the upper shell's
## top front holds the door, an L seen from the side: its lid over the notch and its face down the
## front, a lip under it. The door turns up and back about its lid's back edge and stands open above
## the top, its face tipped back, over the throat a cartridge goes in through. The cartridge slides
## in on a tray tilted up at the front, then is pressed down level; it turns about the tray's back,
## where its connector is.

## The door's thickness, and the gap all around it.
const DOOR := 2.0
const GAP := 0.6
## The door open, in degrees, its lid standing up under its face tipped back (measured on a photo of
## the console being loaded); nothing behind its hinge stops it short of lying flat on the top.
const DOOR_OPEN := 65.0
## The placeholder's rebound: it takes an opening a tenth past its end.
const REBOUND := 1.1
## The lip's thickness, under the door.
const WALL := 2.5
## A tray's rail: its width, and how far it stands above a cartridge lying on the tray; how far the
## tray goes past the throat's back wall, under the door.
const RAIL := 4.0
const RAIL_RISE := 3.0
const TRAY_REACH := 11.5
## The diode, square, beside the power button; the buttons' spacing, how round their corners and
## then their edges are.
const DIODE := 3.0
const SPACING := 3.0
const BUTTON_ROUND := Vector2(1.2, 0.8)
## How far the power button latches in, and the reset button goes in pressed (estimated from photos
## of the two at rest and pressed); less when they stand out less (see [method button_travel]).
const POWER_IN := 2.5
const RESET_IN := 2.5
## The least a button goes in for its press to show.
const SHOWN_PRESS := 0.5
## Of each vent's pitch, the slat.
const SLAT := 0.62
## The stripe's front, on the upper shell, in three bands: the bottom one and the top one, as
## fractions of the upper shell's height.
const BANDS := Vector2(0.22, 0.21)

@export var width := 255.0:
	set(value):
		width = value
		emit_changed()
@export var depth := 202.0:
	set(value):
		depth = value
		emit_changed()
@export var height := 85.0:
	set(value):
		height = value
		emit_changed()
## Where the upper shell starts: the lower shell's height.
@export var seam := 47.0:
	set(value):
		seam = value
		emit_changed()
## How round the shells' upright edges are, then those along their top and bottom.
@export var corner := 1.8:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 1.5:
	set(value):
		bevel = value
		emit_changed()
## How much narrower the lower shell is on each side at the table than at the seam.
@export var slope := 12.0:
	set(value):
		slope = value
		emit_changed()
## The stripe's X and width.
@export var stripe := Vector2(73.5, 40.0):
	set(value):
		stripe = value
		emit_changed()
## How deep the stripe's dark pieces are on the top, at the front and at the back: the vents lie
## between them.
@export var stripe_ends := Vector2(35.0, 38.0):
	set(value):
		stripe_ends = value
		emit_changed()
@export var vent_count := 19:
	set(value):
		vent_count = value
		emit_changed()
## The notch's width, its right edge the stripe's left one, and its depth from the front.
@export var notch := Vector2(145.0, 34.0):
	set(value):
		notch = value
		emit_changed()
## The lip's height, under the door.
@export var lip := 10.2:
	set(value):
		lip = value
		emit_changed()
## The cartridges the slot takes: their width, length and thickness.
@export var cartridge := Vector3(119.0, 133.0, 19.0):
	set(value):
		cartridge = value
		emit_changed()
## How far behind the front a seated cartridge's front end is.
@export var cartridge_inset := 6.0:
	set(value):
		cartridge_inset = value
		emit_changed()
## How far the tray's front is tilted up to take a cartridge, in degrees.
@export var tray_tilt := 10.0:
	set(value):
		tray_tilt = value
		emit_changed()
## The panel of the power and reset buttons, on the lower shell's front.
@export var panel_size := Vector2(51.0, 35.0):
	set(value):
		panel_size = value
		emit_changed()
@export var panel_centre := Vector2(-70.5, 24.5):
	set(value):
		panel_centre = value
		emit_changed()
@export var button_size := Vector2(18.0, 12.0):
	set(value):
		button_size = value
		emit_changed()
## How far the buttons stand out of their panel, the power off.
@export var button_raise := 6.0:
	set(value):
		button_raise = value
		emit_changed()
## Each controller port's opening, under the stripe.
@export var port_size := Vector2(14.0, 24.0):
	set(value):
		port_size = value
		emit_changed()


func parts() -> Array[StringName]:
	return NesGeometry.PARTS


func surfaces() -> Array[StringName]:
	return [&"throat", &"door_logo", &"power_logo", &"reset_logo", &"ports_logo"]


func front() -> float:
	return depth / 2.0


func stripe_left() -> float:
	return stripe.x - stripe.y / 2.0


func notch_left() -> float:
	return stripe_left() - notch.x


## The upper shell left of the stripe, in plan (X right, Y back), counter-clockwise: the notch cut
## out of its front right.
func upper_outline() -> PackedVector2Array:
	var half := depth / 2.0
	var throat := notch.y - half
	return PackedVector2Array([Vector2(-width / 2.0, -half), Vector2(notch_left(), -half),
		Vector2(notch_left(), throat), Vector2(stripe_left(), throat), Vector2(stripe_left(), half),
		Vector2(-width / 2.0, half)])


## The lower shell's front, counter-clockwise.
func lower_outline() -> PackedVector2Array:
	return PackedVector2Array([Vector2(slope - width / 2.0, 0.0), Vector2(width / 2.0 - slope, 0.0),
		Vector2(width / 2.0, seam), Vector2(-width / 2.0, seam)])


## The door's face, closed, in front view: from over the lip up to the top.
func door_box() -> Rect2:
	var bottom := seam + lip + GAP
	return Rect2(notch_left() + GAP, bottom, notch.x - 2.0 * GAP, height - bottom)


## Where the door turns, its lid's top back edge (Z, Y).
func hinge() -> Vector2:
	return Vector2(front() - notch.y + GAP, height)


## The door turned [param degrees] up and back about its hinge, in the model's space.
func door(degrees: float) -> Transform3D:
	var at := Vector3(0.0, hinge().y, hinge().x) * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(degrees)), at)


## Where a cartridge passes the door, tilted on the open tray: half way between the lip and the
## door's lid.
func way_in_height() -> float:
	return (seam + lip + height - DOOR) / 2.0


## Where the tray turns, at a seated cartridge's back end, on its axis (Y, Z).
func pivot() -> Vector2:
	var back := front() - cartridge_inset - cartridge.y
	return Vector2(way_in_height() - (front() - back) * tan(deg_to_rad(tray_tilt)), back)


## The tray tilted [param degrees] up about its pivot, in the model's space.
func tray(degrees: float) -> Transform3D:
	var at := Vector3(notch_left() + notch.x / 2.0, pivot().x, pivot().y) * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(degrees)), at)


## Where a seated cartridge's centre is, in the model's space, the tray tilted [param degrees]: its
## label up, its top edge towards the front.
func seat(degrees: float) -> Transform3D:
	var centre := Vector3(0.0, 0.0, cartridge.y / 2.0) * MeshBuilder.UNITS_PER_MM
	return tray(degrees) * Transform3D(Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP), centre)


## The tray's rails, side by side across X, from the pivot (Y up, Z forwards from it).
func rail_box() -> AABB:
	var top := cartridge.z / 2.0 + RAIL_RISE
	var bottom := seam + 0.5 - pivot().x
	var length := front() - notch.y + TRAY_REACH - pivot().y
	return AABB(Vector3(-cartridge.x / 2.0 - RAIL, bottom, 0.0),
		Vector3(cartridge.x + 2.0 * RAIL, top - bottom, length))


## The buttons on their panel, in front view: the power one, then the reset one.
func button_box(index: int) -> Rect2:
	var start := panel_centre.x - panel_size.x / 2.0 + 2.0 * SPACING + DIODE
	var left := start + index * (button_size.x + SPACING)
	return Rect2(left, panel_centre.y - button_size.y / 2.0, button_size.x, button_size.y)


func diode_box() -> Rect2:
	var left := panel_centre.x - panel_size.x / 2.0 + SPACING
	return Rect2(left, panel_centre.y - DIODE / 2.0, DIODE, DIODE)


func panel_box() -> Rect2:
	return ShapeGeometry.centred(panel_centre, panel_size)


## The stripe's part of the lower shell, its front the ports' column, its back the connectors'.
func column() -> Rect2:
	return Rect2(stripe_left(), 0.0, stripe.y, seam)


## Each port's opening, in front view: high on the column, in each half of it.
func port_box(index: int) -> Rect2:
	var top := seam - corner - 2.5
	var left := stripe.x + (index - 0.5) * stripe.y / 2.0 - port_size.x / 2.0
	return Rect2(left, top - port_size.y, port_size.x, port_size.y)


## How far a button that goes [param travel] in when pressed goes, standing [member button_raise]
## out of its panel (see [method ConsoleModel.press_travel]).
func button_travel(travel: float) -> float:
	return ConsoleModel.press_travel(button_raise, travel)


## How round the ports' openings are.
func port_corner() -> float:
	return minf(2.0, minf(port_size.x, port_size.y) / 2.0 - 0.1)


func _arrays(part: StringName, detail: int) -> Array:
	return NesGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var tilt := deg_to_rad(tray_tilt)
	var stripe_right := stripe.x + stripe.y / 2.0
	var vents := depth - stripe_ends.x - stripe_ends.y
	var closed := door_box()
	var rails := rail_box()
	# The tray's front top about its pivot (Z, Y), open as far as the rebound takes it: it must stay
	# under the door closed and, going back the most, in front of the throat's back wall.
	var front_top := Transform2D(tilt * REBOUND, Vector2.ZERO) * Vector2(rails.end.z, rails.end.y)
	var seat_open := Transform2D(tilt, Vector2.ZERO) * Vector2(cartridge.y / 2.0, 0.0)
	var lower_front := func(box: Rect2, margin: float) -> bool:
		var inset := slope * (1.0 - box.position.y / seam)
		var half := width / 2.0 - inset - margin
		return box.position.y > margin and box.end.y < seam - margin and box.position.x > -half \
			and box.end.x < half
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and height > 0.0 and lip > 0.0
			and slope >= 0.0 and cartridge.x > 0.0 and cartridge.y > 0.0 and cartridge.z > 0.0
			and cartridge_inset > 0.0 and port_size.x > 0.0 and port_size.y > 0.0
			and panel_size.x > 0.0 and panel_size.y > 0.0
			and minf(button_size.x, button_size.y) > 2.0 * BUTTON_ROUND.x + 0.1,
		&"edges_round_the_bevel": bevel > 0.0 and corner > bevel + 0.1,
		&"shells_hold_their_bevels": seam > 2.0 * corner + 2.0
			and height - seam > lip + 2.0 * corner
			and (height - seam) * minf(BANDS.x, BANDS.y) > 2.0 * corner + 0.2,
		&"outlines_round": _rounds(upper_outline(), corner + bevel)
			and _rounds(lower_outline(), corner + bevel),
		&"stripe_on_the_top": stripe.y > 4.0 * corner + 2.0
			and stripe_right < width / 2.0 - 2.0 * corner - 2.0 and stripe_ends.x > 4.0 * corner
			and stripe_ends.y > 4.0 * corner and vents > 2.0,
		&"vents_fit": vent_count >= 1 and SLAT * vents / vent_count > 0.6,
		&"notch_beside_the_stripe": notch.x > 2.0 * corner + 2.0 * GAP + 4.0
			and notch_left() > 2.0 * corner + 2.0 - width / 2.0 and notch.y <= stripe_ends.x
			and notch.y > 2.0 * corner,
		&"door_holds_its_lid_and_face": lip > 2.0 and closed.size.y > DOOR + 2.0 and notch.y > DOOR + GAP + 2.0,
		# Under the door's lid closed; lifted, the door only rises above it.
		&"cartridge_passes_the_door": tray_tilt > 0.0 and tray_tilt < 30.0
			and cartridge.z / cos(tilt) + 2.0 < height - DOOR - seam - lip
			and cartridge.x + 2.0 * RAIL + 2.0 < closed.size.x,
		&"cartridge_sinks_behind_the_lip": pivot().x + cartridge.z / 2.0 < seam + lip
			and pivot().y > 5.0 - front()
			and cartridge.y / 2.0 + cartridge_inset > notch.y - TRAY_REACH,
		&"tray_moves_inside": rails.size.y > 2.0
			and pivot().x + front_top.y < height - DOOR - 0.5
			and pivot().y + front_top.x > front() - notch.y + 0.5
			and pivot().x + seat_open.y > seam + 1.0,
		# Its buttons stand out of it as far as a console's moving parts may.
		&"panel_on_the_lower_front": lower_front.call(panel_box(), 2.0)
			and panel_box().end.x < stripe_left() - 2.0 and button_raise < ConsoleModel.PROUD_MM - 0.5
			and ShapeGeometry.within(button_box(1), panel_box().grow(-1.0)) and panel_size.y > DIODE + 2.0,
		# Pressed, each still stands out of the panel: it goes in less when it stands out less.
		&"buttons_press_in_and_show": button_travel(minf(POWER_IN, RESET_IN)) >= SHOWN_PRESS,
		&"ports_fit": port_size.x + 4.0 < stripe.y / 2.0 and port_size.y + corner + 6.0 < seam
			and stripe_right < width / 2.0 - slope - 2.0,
	}


## Whether the outline [param corners] (counter-clockwise) can have each corner rounded by
## [param radius]: every side is longer than the arcs that start at its ends.
static func _rounds(corners: PackedVector2Array, radius: float) -> bool:
	var count := corners.size()
	var reach := func(i: int) -> float:
		var before := corners[i] - corners[(i + count - 1) % count]
		var after := corners[(i + 1) % count] - corners[i]
		return radius * tan(absf(before.angle_to(after)) / 2.0)
	for i in count:
		var side := corners[(i + 1) % count].distance_to(corners[i])
		if side <= reach.call(i) + reach.call((i + 1) % count) + 0.1:
			return false
	return true
