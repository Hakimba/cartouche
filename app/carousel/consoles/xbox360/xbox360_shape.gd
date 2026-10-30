# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name Xbox360Shape
extends ModelShape
## The dimensions of the first Xbox 360 (2005), in millimetres, as it lies flat on a table: its top
## up (+Y), its front towards +Z, X to the right from the middle of its front (see
## [Xbox360Geometry]). Heights are from the table. One body, swept from its front outline back to
## its back, its top and bottom curved in towards the middle; the faceplate's seam runs round it a
## little behind the front. On the front: the disc tray's slot at the upper left, the eject button
## at its left end; below them the infrared window, the two memory unit flaps and the sync button;
## the power button in its ring of four lights, on a round boss; the USB ports' flap at the right.
## A grille on each end, the hard drive on the left one in front of which the grille is cut short;
## dotted vents along both ends of the top; a honeycomb vent and the ports at the back.

## The gap around the tray in its slot; its bezel's thickness; its plate, above the slot's bottom,
## and its thickness; the room left between a disc and the bezel; the gap between the eject button
## and the slot; the eject button's own gap round it, in its round hole in the front, and how deep
## that hole goes.
const TRAY_GAP := 0.5
const BEZEL_THICKNESS := 4.0
const PLATE_ABOVE := 1.5
const PLATE_THICKNESS := 4.0
const DISC_ROOM := 3.0
const EJECT_GAP := 2.5
const EJECT_HOLE_GAP := 0.8
const EJECT_DEPTH := 2.5
## What lies on a face is drawn just above it, which it would fight; half a DVD's thickness.
const RAISE := 0.05
const DISC_HALF_THICKNESS := 0.6
## How far the boss, the button inside the ring, the ring and the eject button stand out of what
## they lie on.
const BOSS_RAISE := 0.8
const BUTTON_RAISE := 0.5
const RING_RAISE := 0.3
const EJECT_RAISE := 0.8
## The row below the slot, its middle's height: the infrared window, the memory unit flaps (from
## the slot's left end) and the sync button (its centre from the slot's left end, and its radius).
const ROW_HEIGHT := 21.0
const WINDOW := Rect2(1.0, -4.5, 21.5, 9.0)
const MEMORY_UNITS: Array[Rect2] = [Rect2(30.0, -5.0, 41.0, 10.0), Rect2(78.0, -5.0, 41.0, 10.0)]
const SYNC := Vector3(131.3, 0.0, 4.85)
## The USB ports' flap, its size and how far in from the right end, its middle half way up the end.
const USB_FLAP := Vector2(16.5, 58.0)
const USB_INSET := 18.0
## The hard drive: its corners' radius, how far it goes into the body, how far it stays from the
## top and the bottom, the back, and the grille in front of it; its badge's size.
const DRIVE_CORNER := 10.0
const DRIVE_EMBED := 5.0
const DRIVE_MARGINS := Vector3(4.0, 3.0, 2.0)
const FRONT_GRILLE := 55.0
const BADGE := Vector2(64.0, 20.0)
## The top's vents along each end: how far in from it, their rows, the holes' pitch and size, how far
## from the back and from the seam.
const VENT_INSET := 19.0
const VENT_ROWS := 5
const VENT_PITCH := 4.6
const VENT_HOLE := 2.6
const VENT_ENDS := Vector2(25.0, 42.0)
## The back's honeycomb, from the right end (seen from the front) and up from the table, with a rib
## across its middle; its holes' pitch, the rows' spacing and the holes' size. The ports, from the
## right end (the mains inlet) or the left one (the others), up from the table.
const HONEYCOMB := Rect2(42.0, 10.0, 150.0, 60.0)
const HONEYCOMB_HOLES := Vector3(7.0, 6.0, 5.5)
const MAINS := Rect2(14.0, 11.0, 20.0, 14.0)
const PORTS: Array[Rect2] = [Rect2(68.0, 18.0, 32.0, 9.0), Rect2(42.0, 18.0, 14.0, 12.0), Rect2(42.0, 40.0, 12.0, 5.0)]

@export var width := 309.0:
	set(value):
		width = value
		emit_changed()
@export var depth := 258.0:
	set(value):
		depth = value
		emit_changed()
## At the ends; the top and the bottom are each [member dip] closer to the middle at the middle.
@export var height := 83.0:
	set(value):
		height = value
		emit_changed()
@export var dip := 2.5:
	set(value):
		dip = value
		emit_changed()
## The body's underside at the ends, on its feet.
@export var foot_height := 2.0:
	set(value):
		foot_height = value
		emit_changed()
## The front outline's corners, and the rounding of the body's edges at the front and the back.
@export var corner := 9.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 5.0:
	set(value):
		bevel = value
		emit_changed()
## How far behind the front the faceplate's seam runs.
@export var faceplate_depth := 12.0:
	set(value):
		faceplate_depth = value
		emit_changed()
## The tray's slot, from its left end to its right one (X), from its bottom to its top: its ends
## are round.
@export var slot_span := Vector2(-124.5, 13.5):
	set(value):
		slot_span = value
		emit_changed()
@export var slot_levels := Vector2(45.5, 62.5):
	set(value):
		slot_levels = value
		emit_changed()
## The eject button, round, at the slot's left end.
@export var eject_radius := 8.0:
	set(value):
		eject_radius = value
		emit_changed()
@export var disc_radius := 60.0:
	set(value):
		disc_radius = value
		emit_changed()
## The power button's boss: its centre on the front and its radius; the ring of lights round the
## button, from its inner radius to its outer one.
@export var power_centre := Vector2(68.5, 41.5):
	set(value):
		power_centre = value
		emit_changed()
@export var boss_radius := 23.5:
	set(value):
		boss_radius = value
		emit_changed()
@export var ring_radii := Vector2(13.0, 15.0):
	set(value):
		ring_radii = value
		emit_changed()
## How far the hard drive stands out of the left end.
@export var drive_protrusion := 16.0:
	set(value):
		drive_protrusion = value
		emit_changed()


func parts() -> Array[StringName]:
	return Xbox360Geometry.PARTS


func surfaces() -> Array[StringName]:
	var flat: Array[StringName] = [&"gaps", &"window", &"tray_window", &"drive_opening"]
	flat.append_array(Xbox360Geometry.LOGOS.keys())
	return flat


## The front outline before its top and bottom are curved in.
func front() -> Rect2:
	return Rect2(-width / 2.0, foot_height, width, height - foot_height)


## How far the top and the bottom are curved in at [param x]: [member dip] at the middle, nothing at
## the ends.
func sag(x: float) -> float:
	return dip * (1.0 - pow(2.0 * x / width, 2.0))


## Where things lie flat on the front, and on the back: clear of the rounded corners and edges.
func face() -> Rect2:
	var flat := front().grow(-bevel)
	return Rect2(-width / 2.0 + corner, flat.position.y + dip, width - 2.0 * corner, flat.size.y - 2.0 * dip)


func seam() -> float:
	return depth / 2.0 - faceplate_depth


func slot() -> Rect2:
	return Rect2(slot_span.x, slot_levels.x, slot_span.y - slot_span.x, slot_levels.y - slot_levels.x)


func eject_centre() -> Vector2:
	return Vector2(slot_span.x - EJECT_GAP - eject_radius, slot().get_center().y)


## The tray's bezel, closing the slot at rest, flush with the front.
func bezel() -> Rect2:
	return slot().grow(-TRAY_GAP)


## The plate behind the bezel, seen from the front: as wide as the slot's round ends let it be at
## its underside, the gap kept.
func plate() -> Rect2:
	var radius := bezel().size.y / 2.0
	var below := bezel().get_center().y - slot_levels.x - PLATE_ABOVE
	var inset := radius - sqrt(maxf(0.0, radius * radius - below * below)) + TRAY_GAP
	var span := bezel().grow_individual(-inset, 0.0, -inset, 0.0)
	return Rect2(span.position.x, slot_levels.x + PLATE_ABOVE, span.size.x, PLATE_THICKNESS)


func plate_length() -> float:
	return 2.0 * (disc_radius + DISC_ROOM) + 20.0


## How deep the slot goes in, to hold the plate at rest.
func pocket_depth() -> float:
	return BEZEL_THICKNESS + plate_length() + TRAY_GAP


## The centre of the disc lying on the plate at rest, in plan: X, and Z towards the front.
func disc_centre() -> Vector2:
	return Vector2(plate().get_center().x, depth / 2.0 - BEZEL_THICKNESS - DISC_ROOM - disc_radius)


## How far the tray slides out: enough for its disc to clear the front, by a few millimetres.
func tray_travel() -> float:
	return depth / 2.0 - disc_centre().y + disc_radius + 3.0


## The plate and the disc's centre in plan, as [DiscTray] lays them out (X, and Y towards the back),
## at rest: the plate from just inside the bezel back to its end.
func plate_plan() -> Rect2:
	var back := depth / 2.0 - BEZEL_THICKNESS
	return Rect2(plate().position.x, -back - 0.5, plate().size.x, plate_length() + 0.5)


func disc_plan() -> Vector2:
	return disc_centre() * Vector2(1.0, -1.0)


## The plate's foot and top.
func plate_levels() -> Vector2:
	return Vector2(plate().position.y, plate().end.y)


## Where the tray's disc lies, in the model's space, the tray slid [param travel_mm] out: on its
## recess's floor, its axis (Z) up, its label too.
func seat(travel_mm: float) -> Transform3D:
	var centre := disc_centre()
	var at := Vector3(centre.x, DiscTray.floor_level(plate().end.y) + DISC_HALF_THICKNESS, centre.y + travel_mm)
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), at * MeshBuilder.UNITS_PER_MM)


func eject() -> Rect2:
	return ShapeGeometry.square_around(eject_centre(), eject_radius)


## The round hole in the front the eject button sits in, its gap round it.
func eject_hole() -> Rect2:
	return eject().grow(EJECT_HOLE_GAP)


## The infrared window, the memory unit flaps and the sync button: the row below the slot, placed
## from its left end.
func window() -> Rect2:
	return Rect2(WINDOW.position + _row(), WINDOW.size)


func memory_units() -> Array[Rect2]:
	var found: Array[Rect2] = []
	for unit in MEMORY_UNITS:
		found.append(Rect2(unit.position + _row(), unit.size))
	return found


func sync() -> Rect2:
	return ShapeGeometry.square_around(_row() + Vector2(SYNC.x, SYNC.y), SYNC.z)


func boss() -> Rect2:
	return ShapeGeometry.square_around(power_centre, boss_radius)


func usb_flap() -> Rect2:
	var centre := Vector2(width / 2.0 - USB_INSET - USB_FLAP.x / 2.0, front().get_center().y)
	return ShapeGeometry.centred(centre, USB_FLAP)


## Everything on the front beside the slot, each in its box.
func front_details() -> Array[Rect2]:
	var found: Array[Rect2] = [eject_hole(), window(), sync(), boss(), usb_flap()]
	found.append_array(memory_units())
	return found


## The vents along each end of the top, in plan (X, and Z towards the front): the right end's, then
## the left end's.
func vents() -> Array[Rect2]:
	var across := VENT_ROWS * VENT_PITCH
	var from := -depth / 2.0 + VENT_ENDS.x
	var length := seam() - VENT_ENDS.y - from
	var outer := width / 2.0 - VENT_INSET
	return [Rect2(outer - across, from, across, length), Rect2(-outer, from, across, length)]


## The hard drive on the left end, in its plane (X towards the front, Y up from the table).
func drive() -> Rect2:
	var back := -depth / 2.0 + DRIVE_MARGINS.y
	var front_edge := seam() - 1.0 - FRONT_GRILLE - DRIVE_MARGINS.z
	var low := foot_height + DRIVE_MARGINS.x
	return Rect2(back, low, front_edge - back, height - DRIVE_MARGINS.x - low)


## Each end's grille, in the end's plane (X towards the front, Y up from the table): the right one,
## then the left one, cut short in front of the hard drive.
func grilles() -> Array[Rect2]:
	var flat := Rect2(-depth / 2.0 + bevel, foot_height + corner, seam() - 1.0 + depth / 2.0 - bevel,
		height - foot_height - 2.0 * corner).grow(-0.5)
	return [flat, flat.grow_side(SIDE_LEFT, -(flat.size.x - FRONT_GRILLE))]


## The honeycomb at the back, seen from the front (X to the right), and the ports: the mains inlet,
## then the others.
func honeycomb() -> Rect2:
	return Rect2(width / 2.0 - HONEYCOMB.end.x, HONEYCOMB.position.y, HONEYCOMB.size.x, HONEYCOMB.size.y)


func ports() -> Array[Rect2]:
	var found: Array[Rect2] = [Rect2(width / 2.0 - MAINS.end.x, MAINS.position.y, MAINS.size.x, MAINS.size.y)]
	for port in PORTS:
		found.append(Rect2(port.position - Vector2(width / 2.0, 0.0), port.size))
	return found


func _arrays(part: StringName, detail: int) -> Array:
	return Xbox360Geometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var outline := front()
	var straight := outline.size.y / 2.0 - corner
	var on_the_front := front_details()
	on_the_front.append(slot())
	var on_the_back := ports()
	on_the_back.append(honeycomb())
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and disc_radius > 0.0 and eject_radius > 0.0
			and drive_protrusion > 1.0 and foot_height > 0.0 and dip >= 0.0,
		&"corner_rounds_the_bevel": bevel > 0.1 and corner > bevel + 0.1 and straight > 4.0,
		&"curved_in_gently": dip < 0.04 * width and outline.size.y - 2.0 * dip > 2.0 * corner + 2.0,
		&"slot_level_on_the_ends": absf(slot().get_center().y - outline.get_center().y) < straight - 0.5,
		&"front_details_on_the_face_and_apart": ShapeGeometry.apart(on_the_front, face().grow(-0.5), 1.0),
		&"ring_on_the_boss": ring_radii.x > 2.0 and ring_radii.y > ring_radii.x + 0.5
			and ring_radii.y < boss_radius - 1.0,
		&"tray_in_its_slot": plate().end.y + 2.0 * DISC_HALF_THICKNESS < bezel().get_center().y
			and depth > pocket_depth() + bevel + 1.0,
		&"disc_fits_the_tray": DiscTray.fits(plate_plan(), plate_levels(), disc_plan(), disc_radius),
		&"faceplate_seam_behind_the_bevel": faceplate_depth > bevel + 1.0,
		&"vents_on_the_top": VENT_INSET > corner + 0.5 and VENT_ENDS.x > bevel + 0.5 and vents()[0].position.x > 1.0
			and vents()[0].size.y > VENT_PITCH,
		# Its edges stay in the body where the end curves away under them: round its corners, round its
		# back edge.
		&"drive_on_the_left_end": BADGE.x < drive().size.x - 2.0 * DRIVE_CORNER
			and BADGE.y < drive().size.y - 2.0 * DRIVE_CORNER
			and _curved_in(corner, DRIVE_MARGINS.x) + _curved_in(bevel, DRIVE_MARGINS.y) < DRIVE_EMBED - 0.5,
		&"back_details_on_the_back_and_apart": ShapeGeometry.apart(on_the_back, face().grow(-0.5), 1.0),
	}


## How far an edge rounded by [param radius] has curved in [param along] from where it starts.
static func _curved_in(radius: float, along: float) -> float:
	return radius - sqrt(radius * radius - pow(radius - along, 2.0)) if along < radius else 0.0


## Where the row below the slot starts: the slot's left end, at the row's height.
func _row() -> Vector2:
	return Vector2(slot_span.x, ROW_HEIGHT)
