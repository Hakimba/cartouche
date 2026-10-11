# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GbCartShape
extends ModelShape
## The dimensions of a Game Boy cartridge (a Game Pak, the Game Boy Color's grey ones too), in
## millimetres, the label facing +Z, the connector edge at the bottom (see [GbCartGeometry]). Its
## outline: a rounded rectangle, its top corner on the right cut by the notch the console's lock
## takes, grooves cut into both sides near the top. In front, a deep pill across the top, its walls
## curving down to a floor where the console's name is moulded, the grooves running on from the
## sides beside it, the label in a recess below, a sunk arrow under it, and the lower part's sides
## chamfered wide. Behind, two smooth stripes down the sides, the moulded marks at the top, a
## dimple and a sunk screw; the bottom, the connector's sleeve, a step lower. Positions down the
## cartridge (`*_drop`) are from its top edge, everything centred across but the stripes and grooves.

## The radius of the outline's small convex corners: the notch's top one, the sleeve's.
const FILLET := 0.4
## How far the two halves' edges round off along their joint: the seam's line around the sides.
const SEAM := 0.15
const LABEL_CORNER := 0.8
## Each groove's height, how far it is cut into the sides, and into the front.
const GROOVE := 1.0
const TOOTH := 0.5
const GROOVE_DEPTH := 0.45
## The plastic left between a groove's end on the front and its cut in the side.
const SLOT_GAP := 0.1
## How far above the bottom edge the chamfer is full, and how high its end rises at the step.
const TAPER := 2.5
const RAMP := 0.3
## The pill's walls, from its rim down to its floor: how far in and how deep, as shares of the
## cove's width and the pill's depth, a quarter round flattening towards the floor.
const COVE: Array[Vector2] = [Vector2(0.0, 0.0), Vector2(0.15, 0.4), Vector2(0.4, 0.75), Vector2(1.0, 1.0)]
## The moulded name's face on the pill's floor.
const LOGO := Vector2(36.0, 4.6)
## The moulded marks' face at the top of the back: MADE IN JAPAN in its frame, PAT.PEND. under it.
const MARKS := Vector2(21.0, 7.0)
## The depth of the arrow and of the back's smooth stripes.
const SHALLOW := 0.5
const STRIPE := 0.25
## How much lower than the back the connector's sleeve is.
const SLEEVE_STEP := 0.4
const DIMPLE := 3.8
const DIMPLE_DEPTH := 0.8
const SCREW_HOLE := 4.6
const SCREW_HEAD := 3.0
const SCREW_SINK := 1.5
const SCREW_RISE := 0.6
## The least plastic left between two recesses, or a recess and the edge of its face.
const RIM := 0.3

@export var width := 58.0:
	set(value):
		width = value
		emit_changed()
@export var height := 65.5:
	set(value):
		height = value
		emit_changed()
@export var depth := 7.5:
	set(value):
		depth = value
		emit_changed()
## The top corners' radius, the notch's outer one's too.
@export var corner := 1.5:
	set(value):
		corner = value
		emit_changed()
@export var bottom_corner := 1.0:
	set(value):
		bottom_corner = value
		emit_changed()
## How far the front's and the back's edges round off.
@export var bevel := 0.25:
	set(value):
		bevel = value
		emit_changed()
## The chamfer of the lower part's front sides: how far across and how deep, and where it starts.
@export var chamfer := Vector2(1.8, 1.9):
	set(value):
		chamfer = value
		emit_changed()
@export var step_drop := 26.3:
	set(value):
		step_drop = value
		emit_changed()
## Whether the top right corner (seen from the front) is cut, and by how much across and down.
@export var notched := true:
	set(value):
		notched = value
		emit_changed()
@export var notch := Vector2(5.1, 2.7):
	set(value):
		notch = value
		emit_changed()
## The pill at its rim, its centre, its depth, and how far its walls reach in to its floor.
@export var pill_size := Vector2(43.2, 12.2):
	set(value):
		pill_size = value
		emit_changed()
@export var pill_drop := 9.95:
	set(value):
		pill_drop = value
		emit_changed()
@export var pill_depth := 1.7:
	set(value):
		pill_depth = value
		emit_changed()
@export var cove := 2.6:
	set(value):
		cove = value
		emit_changed()
## The grooves down each side: how many, the first one's top, from one to the next, and how far
## from the side they reach on the front.
@export var grooves := 5:
	set(value):
		grooves = value
		emit_changed()
@export var groove_drop := 5.6:
	set(value):
		groove_drop = value
		emit_changed()
@export var groove_pitch := 2.05:
	set(value):
		groove_pitch = value
		emit_changed()
@export var groove_length := 4.6:
	set(value):
		groove_length = value
		emit_changed()
@export var label_size := Vector2(43.6, 37.8):
	set(value):
		label_size = value
		emit_changed()
## The label's top edge.
@export var label_drop := 18.7:
	set(value):
		label_drop = value
		emit_changed()
## The recess's floor showing around the label, and its depth.
@export var recess_margin := 0.7:
	set(value):
		recess_margin = value
		emit_changed()
@export var recess := 0.5:
	set(value):
		recess = value
		emit_changed()
## The arrow pointing to the connector: its width and height, and its top edge.
@export var arrow := Vector2(8.6, 4.2):
	set(value):
		arrow = value
		emit_changed()
@export var arrow_drop := 58.4:
	set(value):
		arrow_drop = value
		emit_changed()
## The connector's sleeve, up from the bottom edge.
@export var sleeve_height := 10.6:
	set(value):
		sleeve_height = value
		emit_changed()
## The back's stripes: their centres' distance from the middle, their width, and their top and
## bottom ends.
@export var stripe_offset := 15.4:
	set(value):
		stripe_offset = value
		emit_changed()
@export var stripe_width := 3.0:
	set(value):
		stripe_width = value
		emit_changed()
@export var stripe_span := Vector2(1.0, 54.0):
	set(value):
		stripe_span = value
		emit_changed()
## The centre of the moulded marks at the top of the back.
@export var marks_drop := 5.2:
	set(value):
		marks_drop = value
		emit_changed()
@export var dimple_drop := 32.4:
	set(value):
		dimple_drop = value
		emit_changed()
@export var screw_drop := 48.9:
	set(value):
		screw_drop = value
		emit_changed()
## The opening of the connector along the bottom edge, its width and its height across the
## thickness, the board's edge dark inside.
@export var connector := Vector2(52.0, 2.0):
	set(value):
		connector = value
		emit_changed()


## The height of a point [param drop] below the top edge.
func at(drop: float) -> float:
	return height / 2.0 - drop


func label_box() -> Rect2:
	return Rect2(-label_size.x / 2.0, at(label_drop + label_size.y), label_size.x, label_size.y)


func recess_box() -> Rect2:
	return label_box().grow(recess_margin)


func pill_box() -> Rect2:
	return ShapeGeometry.centred(Vector2(0.0, at(pill_drop)), pill_size)


func floor_box() -> Rect2:
	return pill_box().grow(-cove)


func logo_box() -> Rect2:
	return ShapeGeometry.centred(Vector2(0.0, at(pill_drop)), LOGO)


func arrow_box() -> Rect2:
	return Rect2(-arrow.x / 2.0, at(arrow_drop + arrow.y), arrow.x, arrow.y)


## The top of the connector's sleeve.
func sleeve_top() -> float:
	return sleeve_height - height / 2.0


## Each groove's bottom and top, the highest first.
func groove_spans() -> Array[Vector2]:
	var spans: Array[Vector2] = []
	for i in grooves:
		var top := at(groove_drop + i * groove_pitch)
		spans.append(Vector2(top - GROOVE, top))
	return spans


## Each groove's end on the right of the front (mirrored on the left): from its reach to just short
## of its cut in the side.
func slot_boxes() -> Array[Rect2]:
	var outer := width / 2.0 - TOOTH - bevel - SLOT_GAP
	var boxes: Array[Rect2] = []
	for span in groove_spans():
		boxes.append(Rect2(width / 2.0 - groove_length, span.x, outer - width / 2.0 + groove_length, GROOVE))
	return boxes


## Where the grooves' ends on the front are cut through, the vertical line through their middle.
func slot_line() -> float:
	return width / 2.0 - (groove_length + TOOTH + bevel + SLOT_GAP) / 2.0


## The back's recesses, as seen from the back: the two stripes, the dimple and the screw's hole.
func back_boxes() -> Array[Rect2]:
	var stripe := Vector2(stripe_width, stripe_span.y - stripe_span.x)
	var middle := at((stripe_span.x + stripe_span.y) / 2.0)
	return [ShapeGeometry.centred(Vector2(-stripe_offset, middle), stripe),
		ShapeGeometry.centred(Vector2(stripe_offset, middle), stripe),
		ShapeGeometry.square_around(Vector2(0.0, at(dimple_drop)), DIMPLE / 2.0),
		ShapeGeometry.square_around(Vector2(0.0, at(screw_drop)), SCREW_HOLE / 2.0)]


func marks_box() -> Rect2:
	return ShapeGeometry.centred(Vector2(0.0, at(marks_drop)), MARKS)


func parts() -> Array[StringName]:
	return GbCartGeometry.PARTS


func _arrays(part: StringName, detail: int) -> Array:
	return GbCartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var front := depth / 2.0
	var lowest := groove_drop + (grooves - 1) * groove_pitch + GROOVE
	var top_reach := maxf(corner, notch.y + corner) if notched else corner
	var whole := Rect2(-width / 2.0, -height / 2.0, width, height)
	var back := back_boxes()
	var front_holes: Array[Rect2] = [pill_box(), recess_box(), arrow_box()]
	var back_holes := back.duplicate()
	back_holes.append(marks_box())
	var middle_apart := back_holes.slice(2).all(func(box: Rect2) -> bool: return box.end.x < back[1].position.x - RIM)
	var slots_fit := slot_boxes().all(func(slot: Rect2) -> bool:
		return slot.size.x > 0.5 and slot.position.x > pill_box().end.x + RIM)
	var front_face := GbCartGeometry.outline(self, -height / 2.0, bevel, chamfer.x, 4)
	var back_face := GbCartGeometry.outline(self, sleeve_top(), bevel, bevel, 4)
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and depth > 0.0 and recess > 0.0
			and recess_margin > 0.0 and label_size.x > 2.0 * LABEL_CORNER and label_size.y > 2.0 * LABEL_CORNER
			and pill_size.x > pill_size.y and pill_size.y > 0.0 and pill_depth > 0.0 and cove > 0.0
			and arrow.x > 0.0 and arrow.y > 0.0 and stripe_width > 0.0 and connector.x > 0.0 and connector.y > 0.0
			and grooves >= 0 and chamfer.x > 0.0 and chamfer.y > 0.0 and step_drop > 0.0,
		# Every rounded corner rounder than the bevels; each half, the sleeve's too, thicker than its
		# two, the chamfer, and the deepest recess in it.
		&"bevels_fit": bevel > SEAM and bevel < FILLET and corner > bevel and bottom_corner > bevel
			and chamfer.x > bevel and chamfer.y > bevel and front - chamfer.y > SEAM
			and front - SLEEVE_STEP > SEAM + bevel
			and front - SEAM > maxf(maxf(recess, SCREW_SINK), maxf(pill_depth, GROOVE_DEPTH)) + 0.1,
		# Each side of the outline holds the corners and the steps on it, top to bottom: the notch or
		# the corner, the grooves, the chamfer's end, its taper, the bottom corner.
		&"outline_fits": width - 2.0 * maxf(chamfer.x, TOOTH) > 2.0 * pill_size.x / 3.0
			and bottom_corner + 0.1 < TAPER and height - step_drop > sleeve_height + TAPER + RAMP
			and step_drop - RAMP > (lowest if grooves > 0 else top_reach) + bevel + 0.1
			and (grooves == 0 or groove_drop > top_reach + bevel + 0.1)
			and (not notched or notch.x > corner + FILLET and notch.y > FILLET
				and notch.x < width - 2.0 * corner - FILLET),
		&"grooves_apart": grooves <= 1 or groove_pitch > GROOVE + 2.0 * bevel + 0.2,
		# The lines cutting the faces through the grooves' ends and the stripes cross their straight
		# top and bottom edges.
		&"lines_cross_straight_edges": _straight_across(slot_line(), chamfer.x)
			and _straight_across(stripe_offset, bevel),
		&"front_on_its_face": holds(front_face, front_holes) and ShapeGeometry.apart(front_holes, whole, RIM)
			and ShapeGeometry.fits(logo_box(), 0.0, floor_box(), Vector2.ONE * floor_box().size.y / 2.0) and slots_fit,
		# The stripes' lines down the back cross none of the recesses and marks in the middle.
		&"back_on_its_face": holds(back_face, back_holes) and ShapeGeometry.apart(back_holes, whole, RIM)
			and middle_apart,
		&"connector_on_the_bottom": connector.x < width - 2.0 * maxf(bottom_corner, chamfer.x)
			and connector.y < depth - 2.0 * bevel,
	}


## Whether the vertical lines at ±[param x] cross the outline's top edge (or the notch's floor) and
## its bottom one where they are straight, the bottom corners set in by [param low].
func _straight_across(x: float, low: float) -> bool:
	var half := width / 2.0
	var top := (x < half - corner - 0.05) if not notched or x < half - notch.x - FILLET - 0.05 \
		else (x > half - notch.x + 0.05 and x < half - corner - 0.05)
	return x > 0.05 and top and x < half - maxf(bottom_corner, low) - 0.05


## Whether each of [param boxes], rounded and with some plastic around it, lies inside [param face].
static func holds(face: PackedVector2Array, boxes: Array[Rect2]) -> bool:
	return boxes.all(func(box: Rect2) -> bool: return box.has_area() and ShapeGeometry.inside(
		ShapeGeometry.rounded_box(box.grow(RIM), minf(LABEL_CORNER, minf(box.size.x, box.size.y) / 2.0) + RIM, 3),
		face))
