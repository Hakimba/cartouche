# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name SnesShape
extends ModelShape
## The dimensions of the PAL Super Nintendo, a top-loading cartridge console, in millimetres, as it
## lies on a table: its top up, its front towards the player (see [SnesGeometry]). A low tray, set
## in under a shell whose top is flat at the back and comes down in front, in a rounded slope, to a
## low front face; the top frames a recessed panel; through the panel, the slot a cartridge goes down
## into, label to the front, pushing apart the two flaps hinged along its long edges; in front of the
## slot, the power slider, the eject lever and the reset button. Plan positions are of centres, X to
## the right and Y towards the back, from the centre of the body.

## How far the eject lever, the power knob and the reset button go down into the panel.
const SUNK := 3.0
const PANEL_BEVEL := 0.4
const TRAY_BEVEL := 1.0
## How square the front slope's curve is: 2 a quarter of an ellipse, less a flatter slope between
## tighter bends.
const SLOPE_CURVE := 1.5

@export var width := 200.0:
	set(value):
		width = value
		emit_changed()
@export var depth := 242.0:
	set(value):
		depth = value
		emit_changed()
@export var height := 72.0:
	set(value):
		height = value
		emit_changed()
## The body's corners, seen from above.
@export var corner := 13.0:
	set(value):
		corner = value
		emit_changed()
## The tray under the shell: its height, where the shell starts, how far in it is set at the sides
## and the back, and how far back from the front, out of sight under the front face.
@export var tray_height := 11.6:
	set(value):
		tray_height = value
		emit_changed()
@export var tray_inset := 6.0:
	set(value):
		tray_inset = value
		emit_changed()
@export var tray_front := 24.0:
	set(value):
		tray_front = value
		emit_changed()
## How round the shell is along its bottom edges, along its top edges on the sides and at the back.
@export var bottom_round := 2.5:
	set(value):
		bottom_round = value
		emit_changed()
@export var side_round := 12.0:
	set(value):
		side_round = value
		emit_changed()
@export var back_round := 12.0:
	set(value):
		back_round = value
		emit_changed()
## How high the front face rises before the top slopes back from it, and how far back the slope
## reaches the top.
@export var front_height := 46.0:
	set(value):
		front_height = value
		emit_changed()
@export var slope_run := 21.0:
	set(value):
		slope_run = value
		emit_changed()
## The line where the shell's two halves meet, all around.
@export var crease_height := 25.0:
	set(value):
		crease_height = value
		emit_changed()
@export var panel_size := Vector2(156.0, 190.0):
	set(value):
		panel_size = value
		emit_changed()
@export var panel_centre := Vector2(0.0, 0.0):
	set(value):
		panel_centre = value
		emit_changed()
@export var panel_corner := 5.0:
	set(value):
		panel_corner = value
		emit_changed()
## How far the panel lies below the top around it, and the gap between them.
@export var panel_drop := 1.5:
	set(value):
		panel_drop = value
		emit_changed()
@export var panel_gap := 0.4:
	set(value):
		panel_gap = value
		emit_changed()
@export var slot_size := Vector2(143.0, 26.0):
	set(value):
		slot_size = value
		emit_changed()
@export var slot_centre := Vector2(0.0, 15.0):
	set(value):
		slot_centre = value
		emit_changed()
@export var slot_corner := 3.0:
	set(value):
		slot_corner = value
		emit_changed()
@export var flap_thickness := 1.2:
	set(value):
		flap_thickness = value
		emit_changed()
## How far below the panel the flaps are hinged, how far down towards the middle they lean
## closed, in degrees, and the gap between their edges there.
@export var flap_drop := 2.0:
	set(value):
		flap_drop = value
		emit_changed()
@export var flap_tilt := 8.0:
	set(value):
		flap_tilt = value
		emit_changed()
@export var flap_gap := 0.6:
	set(value):
		flap_gap = value
		emit_changed()
## The cartridges the slot takes: the widest one's width (the North American one's), the height and thickness
## of the European one, and how deep they go in.
@export var cartridge := Vector3(136.0, 87.0, 20.0):
	set(value):
		cartridge = value
		emit_changed()
@export var insertion := 38.0:
	set(value):
		insertion = value
		emit_changed()
@export var eject_size := Vector2(55.0, 30.0):
	set(value):
		eject_size = value
		emit_changed()
@export var eject_centre := Vector2(0.0, -58.0):
	set(value):
		eject_centre = value
		emit_changed()
## How far the eject lever stands above the panel; pressed, it is level with it.
@export var eject_raise := 2.5:
	set(value):
		eject_raise = value
		emit_changed()
## The power knob, width, depth and height above the panel; its centre switched off, and how far
## back it slides to switch on.
@export var knob_size := Vector3(22.0, 9.0, 2.5):
	set(value):
		knob_size = value
		emit_changed()
@export var knob_centre := Vector2(-47.0, -56.0):
	set(value):
		knob_centre = value
		emit_changed()
@export var power_travel := 4.5:
	set(value):
		power_travel = value
		emit_changed()
@export var reset_size := Vector2(22.0, 24.0):
	set(value):
		reset_size = value
		emit_changed()
@export var reset_centre := Vector2(47.0, -58.0):
	set(value):
		reset_centre = value
		emit_changed()
## How far the reset button stands above the panel.
@export var reset_raise := 0.8:
	set(value):
		reset_raise = value
		emit_changed()
@export var button_corner := 2.0:
	set(value):
		button_corner = value
		emit_changed()
## The recess the controller ports sit in, across the front, its ends round.
@export var bay_size := Vector2(144.0, 19.0):
	set(value):
		bay_size = value
		emit_changed()
@export var bay_bottom := 15.4:
	set(value):
		bay_bottom = value
		emit_changed()
## The slits across the back: how many, from centre to centre, each one's size and its bottom.
@export var vent_count := 25:
	set(value):
		vent_count = value
		emit_changed()
@export var vent_pitch := 6.0:
	set(value):
		vent_pitch = value
		emit_changed()
@export var vent_size := Vector2(2.4, 25.0):
	set(value):
		vent_size = value
		emit_changed()
@export var vent_bottom := 29.5:
	set(value):
		vent_bottom = value
		emit_changed()
## How wide the grooves are: the crease, and those between the top's strips, from the panel down
## the slope in front and down the round behind.
@export var groove_width := 0.8:
	set(value):
		groove_width = value
		emit_changed()


func parts() -> Array[StringName]:
	return SnesGeometry.PARTS


func surfaces() -> Array[StringName]:
	return [&"well", &"rings", &"power_well", &"eject_gap", &"bay", &"vents", &"grooves", &"diode", &"nintendo_logo",
		&"super_nintendo_logo", &"entertainment_system_logo", &"power_logo", &"eject_logo", &"reset_logo",
		&"pal_version_logo", &"port_1_logo", &"port_2_logo"]


func body() -> Rect2:
	return Rect2(-width / 2.0, -depth / 2.0, width, depth)


func tray() -> Rect2:
	return Rect2(-width / 2.0 + tray_inset, -depth / 2.0 + tray_front, width - 2.0 * tray_inset,
		depth - tray_inset - tray_front)


## The flat of the top, inside its rounded edges and its slope, and how round its corners are.
func top() -> Rect2:
	return Rect2(-width / 2.0 + side_round, -depth / 2.0 + slope_run, width - 2.0 * side_round,
		depth - slope_run - back_round)


func top_corner() -> float:
	return maxf(corner - minf(side_round, minf(slope_run, back_round)), 0.5)


func panel_box() -> Rect2:
	return ShapeGeometry.centred(panel_centre, panel_size)


func panel_top() -> float:
	return height - panel_drop


## The opening in the shell the panel sits in: the panel, grown by its gap.
func panel_opening() -> Rect2:
	return panel_box().grow(panel_gap)


func slot_box() -> Rect2:
	return ShapeGeometry.centred(slot_centre, slot_size)


## How far each flap's hinge lies in from its edge of the slot: hung open, it keeps clear of it.
func flap_inset() -> float:
	return flap_thickness / 2.0 + 0.3


## Each flap, from its hinge to its edge in the middle of the slot, and across it.
func flap_length() -> float:
	return (slot_size.y / 2.0 - flap_inset() - flap_gap / 2.0) / cos(deg_to_rad(flap_tilt))


func flap_width() -> float:
	return slot_size.x - 2.0 * slot_corner - flap_gap


## How far the flaps turn down from closed to hanging straight.
func flap_swing() -> float:
	return 90.0 - flap_tilt


## Where the back flap turns, then the front one, in the model's space.
func hinges() -> Array[Vector3]:
	var at := panel_top() - flap_drop
	return [_to_model(Vector3(slot_centre.x, slot_box().end.y - flap_inset(), at)),
		_to_model(Vector3(slot_centre.x, slot_box().position.y + flap_inset(), at))]


func eject_box() -> Rect2:
	return ShapeGeometry.centred(eject_centre, eject_size)


## Where the eject lever turns, in the model's space: the back edge of its top.
func eject_pivot() -> Vector3:
	return _to_model(Vector3(eject_centre.x, eject_box().end.y, panel_top() + eject_raise))


## How far the eject lever turns, pressed: until its front edge is level with the panel.
func eject_press() -> float:
	return rad_to_deg(asin(clampf(eject_raise / eject_size.y, 0.0, 1.0)))


func knob_box() -> Rect2:
	var size := Vector2(knob_size.x, knob_size.y)
	return ShapeGeometry.centred(knob_centre, size)


## The panel the knob covers, from off to on.
func knob_way() -> Rect2:
	return knob_box().grow_side(SIDE_BOTTOM, power_travel)


func reset_box() -> Rect2:
	return ShapeGeometry.centred(reset_centre, reset_size)


## How far the reset button goes down pressed: as far as it stands out, but for what a pressed
## button still shows (see [method ConsoleModel.press_travel]) out of its ring, painted a hair over
## the panel.
func reset_travel() -> float:
	return ConsoleModel.press_travel(reset_raise - SnesGeometry.OFF, reset_raise)


## Where a seated cartridge's centre is, in the model's space: [member insertion] down the slot,
## its label to the front.
func seat() -> Transform3D:
	var centre := Vector3(slot_centre.x, slot_centre.y, panel_top() - insertion + cartridge.y / 2.0)
	return Transform3D(Basis(), _to_model(centre))


## The bay, as seen from the front: X to the right, Y up.
func bay_box() -> Rect2:
	return Rect2(-bay_size.x / 2.0, bay_bottom, bay_size.x, bay_size.y)


## The slits, as seen from the back: X to the left, Y up.
func vents() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var first := -(vent_count - 1) * vent_pitch / 2.0
	for i in vent_count:
		found.append(Rect2(first + i * vent_pitch - vent_size.x / 2.0, vent_bottom, vent_size.x, vent_size.y))
	return found


func _arrays(part: StringName, detail: int) -> Array:
	return SnesGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var buttons: Array[Rect2] = [eject_box(), knob_box(), reset_box()]
	var reaches: Array[Rect2] = [eject_box(), knob_way(), reset_box()]
	# The flat of the front and of the back, between their corners and their rounded edges.
	var flat_from := tray_height + bottom_round + 0.5
	var front := Rect2(-width / 2.0 + corner + 1.0, flat_from, width - 2.0 * corner - 2.0,
		front_height - flat_from - 0.5)
	var back := Rect2(front.position, Vector2(front.size.x, height - back_round - flat_from - 0.5))
	var across := Vector2(cartridge.x, cartridge.z)
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and height > 0.0 and panel_gap > 0.0
			and flap_thickness > 0.2 and flap_gap > 0.05 and cartridge.x > 0.0 and cartridge.y > 0.0
			and cartridge.z > 0.0 and power_travel > 0.1 and groove_width > 0.0,
		# Each height of the shell keeps straight sides between its corners, the tray's too.
		&"corner_rounds_the_edges": corner > side_round + 0.1 and corner > tray_inset + TRAY_BEVEL + 0.1
			and corner < minf(top().size.x, top().size.y) / 2.0 - 0.1,
		# The shell starts on the tray, rounds its bottom edges, rises straight, then rounds or slopes
		# its top edges; the tray goes up into it.
		&"shell_holds_its_profile": tray_height > 2.0 * TRAY_BEVEL + 0.1 and tray_inset > 0.1
			and tray_front >= tray_inset and tray().size.y > 2.0 * corner
			and bottom_round > 0.1 and side_round > 0.1 and back_round > 0.1 and slope_run > 0.5
			and flat_from + 0.5 < minf(front_height, minf(height - side_round, height - back_round))
			and front_height < height - 1.0,
		&"crease_on_the_faces": crease_height - groove_width / 2.0 > flat_from
			and crease_height + groove_width / 2.0 < front_height - 0.5,
		&"panel_inside_the_top": panel_corner > PANEL_BEVEL + 0.1
			and panel_corner < minf(panel_size.x, panel_size.y) / 2.0 - 0.1
			and ShapeGeometry.fits(panel_opening().grow(1.0), panel_corner + panel_gap + 1.0, top(),
				Vector2.ONE * top_corner()),
		&"panel_below_the_top": panel_drop > 0.1 and panel_top() > tray_height + 2.0 * PANEL_BEVEL + 1.0,
		&"slot_in_the_panel": slot_corner > 0.1 and slot_corner < minf(slot_size.x, slot_size.y) / 2.0 - 0.1
			and ShapeGeometry.fits(slot_box().grow(1.0), slot_corner + 1.0, panel_box(), Vector2.ONE * panel_corner),
		# Closed, the flaps lie below the panel; open, they hang clear of the well's floor.
		&"flaps_fit_the_slot": flap_tilt >= 0.0 and flap_tilt < 45.0 and flap_length() > 1.0
			and flap_width() > 1.0 and flap_drop > flap_thickness / 2.0 + 0.1
			and panel_top() - flap_drop - flap_length() - flap_thickness > tray_height + 1.0,
		&"cartridge_passes_the_open_flaps": cartridge.z / 2.0 + 0.2 < slot_size.y / 2.0 - flap_inset()
			- flap_thickness / 2.0
			and ShapeGeometry.fits(ShapeGeometry.centred(slot_centre, across), 0.0, slot_box(),
				Vector2.ONE * slot_corner),
		&"cartridge_stands_in_the_slot": insertion > flap_drop + flap_length() and insertion < cartridge.y - 1.0
			and panel_top() - insertion > tray_height + 1.0,
		&"buttons_round_their_corners": button_corner > 0.1 and buttons.all(func(button: Rect2) -> bool:
				return minf(button.size.x, button.size.y) > 2.0 * button_corner + 0.2),
		# Each where it moves, the knob all along its way.
		&"buttons_apart_on_the_panel": reaches.all(func(reach: Rect2) -> bool:
				return (ShapeGeometry.fits(reach, 0.0, panel_box().grow(-1.0), Vector2.ZERO)
					and not reach.grow(1.0).intersects(slot_box())))
			and not reaches[0].intersects(reaches[1]) and not reaches[1].intersects(reaches[2])
			and not reaches[0].intersects(reaches[2]),
		# A button stands out of the top a little at most, as a console's moving parts do.
		&"buttons_stand_a_little_out": eject_raise > 0.1 and eject_raise < eject_size.y
			and knob_size.z > 0.3 and reset_travel() > 0.1
			and maxf(eject_raise, maxf(knob_size.z, reset_raise)) <= panel_drop + ConsoleModel.PROUD_MM,
		&"bay_on_the_front": bay_size.x > bay_size.y and bay_size.y > 0.2
			and ShapeGeometry.fits(bay_box(), 0.0, front, Vector2.ZERO),
		&"vents_on_the_back": vent_count >= 1 and vent_size.x > 0.0 and vent_size.y > 0.0
			and vent_size.x < vent_pitch and vent_bottom > crease_height + groove_width
			and vents().all(func(vent: Rect2) -> bool: return ShapeGeometry.fits(vent, 0.0, back, Vector2.ZERO)),
	}


static func _to_model(plan: Vector3) -> Vector3:
	return Vector3(plan.x, plan.z, -plan.y) * MeshBuilder.UNITS_PER_MM
