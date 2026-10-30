# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GbaCartShape
extends ModelShape
## The dimensions of a Game Boy Advance cartridge (a Game Pak), in millimetres, the label facing +Z,
## the connector edge at the bottom (see [GbaCartGeometry]). Its head, along the top, is wider than
## its body and stands out in front: a little at its ends, and in the middle as a hump, highest at
## the top, whose lower edge curves up from the head's ends to the middle; below that arch, a band
## of the body's face where the console's name is moulded, then the label in its recess and a sunk
## arrow under it, the body's sides chamfered wide. Behind, a plate across head and body: two
## smooth stripes, a sunk screw, a recessed panel with the moulded marks, a dimple; below it, the
## connector's sleeve, narrower and a step lower. Positions down the cartridge (`*_drop`) are from
## its top edge; through its thickness, from its back.

const FILLET := 0.4
## How far the edges round off; the head's lower outer corners and the body's bottom ones; how far
## the head's ends stand out over the body's face; how much lower than the back the sleeve is.
const BEVEL := 0.25
const HEAD_CORNER := 0.6
const BOTTOM_CORNER := 0.6
const HEAD_RAISE := 0.3
const SLEEVE_STEP := 0.3
## The label's recess, its floor showing round the label, and the arrow's gap under it; the back's
## panel's depth, and where the stripes start below the top edge.
const RECESS := 0.4
const RECESS_MARGIN := 0.5
const ARROW_GAP := 0.5
const PANEL_DEPTH := 0.4
const STRIPE_TOP := 0.8
## The opening of the connector along the bottom edge, across and through the body's thickness.
const CONNECTOR := Vector2(50.6, 2.2)
const LABEL_CORNER := 0.8
## How far the hump's top edge rounds off towards the front.
const ROLL := 0.8
## How far above the bottom edge the body's chamfer is full.
const TAPER := 2.0
## The hump's stations on each side, between its flat middle and its ends.
const STATIONS := 8
## The moulded name's face on the band, and the marks' face on the back's panel.
const LOGO := Vector2(22.0, 2.6)
const MARKS := Vector2(20.0, 8.4)
const PANEL_CORNER := 1.5
## The depth of the arrow and of the back's smooth stripes.
const SHALLOW := 0.6
const STRIPE := 0.25
const DIMPLE := 3.8
const DIMPLE_DEPTH := 0.8
const SCREW_HOLE := 3.2
const SCREW_HEAD := 2.4
const SCREW_SINK := 1.2
const SCREW_RISE := 0.5
## The least plastic left between two recesses, or a recess and the edge of its face.
const RIM := 0.3

@export var width := 57.5:
	set(value):
		width = value
		emit_changed()
@export var height := 33.0:
	set(value):
		height = value
		emit_changed()
## Through the hump; the body, without it, and the back's plate, from the back; the body centred.
@export var depth := 7.9:
	set(value):
		depth = value
		emit_changed()
@export var body_depth := 5.25:
	set(value):
		body_depth = value
		emit_changed()
@export var plate_depth := 1.85:
	set(value):
		plate_depth = value
		emit_changed()
## The head: how far down it reaches, how much wider than the body it is on each side, its top
## corners.
@export var head_drop := 6.7:
	set(value):
		head_drop = value
		emit_changed()
@export var shoulder := 1.9:
	set(value):
		shoulder = value
		emit_changed()
@export var corner := 2.0:
	set(value):
		corner = value
		emit_changed()
## The chamfer of the body's front sides, across and deep.
@export var chamfer := Vector2(1.5, 1.4):
	set(value):
		chamfer = value
		emit_changed()
## The hump: half the width of its flat middle, and of its whole; its lower edge's drop in the
## middle, from where it curves down to the head's lower edge at its ends.
@export var hump := Vector2(3.0, 23.0):
	set(value):
		hump = value
		emit_changed()
@export var arch_drop := 2.0:
	set(value):
		arch_drop = value
		emit_changed()
@export var label_size := Vector2(40.6, 20.76):
	set(value):
		label_size = value
		emit_changed()
@export var label_drop := 7.2:
	set(value):
		label_drop = value
		emit_changed()
@export var arrow := Vector2(6.6, 2.4):
	set(value):
		arrow = value
		emit_changed()
## The connector's sleeve, up from the bottom edge, and how much narrower than the body on each side.
@export var sleeve_height := 11.5:
	set(value):
		sleeve_height = value
		emit_changed()
@export var sleeve_inset := 1.6:
	set(value):
		sleeve_inset = value
		emit_changed()
## The back's stripes: their centres' distance from the middle, and their width.
@export var stripe_offset := 14.4:
	set(value):
		stripe_offset = value
		emit_changed()
@export var stripe_width := 2.9:
	set(value):
		stripe_width = value
		emit_changed()
## The back's recessed panel, and its centre.
@export var panel_size := Vector2(22.4, 10.4):
	set(value):
		panel_size = value
		emit_changed()
@export var panel_drop := 11.0:
	set(value):
		panel_drop = value
		emit_changed()


func at(drop: float) -> float:
	return height / 2.0 - drop


## The heights of the back and of the body's face, centred on the body as the seat has it; of the
## hump's top, of the joint between the back's plate and the front, and of the head's ends.
func back() -> float:
	return -body_depth / 2.0


func face() -> float:
	return body_depth / 2.0


func peak() -> float:
	return depth + back()


func joint() -> float:
	return plate_depth + back()


func head_front() -> float:
	return face() + HEAD_RAISE


func body_width() -> float:
	return width - 2.0 * shoulder


## The drop of the hump's lower edge at [param x] across, in the middle of the head down to its
## lower edge at the hump's ends.
func arch(x: float) -> float:
	return arch_drop + (head_drop - arch_drop) * minf(1.0, pow(x / hump.y, 2.0))


## How high the head's front stands at [param x] across, from its ends' to the hump's top.
func roof(x: float) -> float:
	var off := maxf(0.0, absf(x) - hump.x) / (hump.y - hump.x)
	return head_front() + (peak() - head_front()) * maxf(0.0, 1.0 - off * off)


## The slope of [method roof] at [param x].
func slope(x: float) -> float:
	var off := (absf(x) - hump.x) / (hump.y - hump.x)
	if off <= 0.0 or off >= 1.0:
		return 0.0
	return -2.0 * off / (hump.y - hump.x) * (peak() - head_front()) * signf(x)


## The top of the connector's sleeve.
func sleeve_top() -> float:
	return sleeve_height - height / 2.0


func label_box() -> Rect2:
	return Rect2(-label_size.x / 2.0, at(label_drop + label_size.y), label_size.x, label_size.y)


func recess_box() -> Rect2:
	return label_box().grow(RECESS_MARGIN)


func arrow_box() -> Rect2:
	return Rect2(-arrow.x / 2.0, at(arrow_drop() + arrow.y), arrow.x, arrow.y)


## The moulded name's centre on the band, half way between the arch and the label's recess.
func logo_drop() -> float:
	return (arch(LOGO.x / 2.0) + label_drop - RECESS_MARGIN) / 2.0


func arrow_drop() -> float:
	return label_drop + label_size.y + RECESS_MARGIN + ARROW_GAP


## The stripes' top and bottom, down to the sleeve; the screw above the panel, the dimple between it
## and the sleeve.
func stripe_span() -> Vector2:
	return Vector2(STRIPE_TOP, height - sleeve_height - BEVEL - RIM - 0.2)


func screw_drop() -> float:
	return panel_drop - panel_size.y / 2.0 - SCREW_HOLE / 2.0 - 0.5


func dimple_drop() -> float:
	return (panel_drop + panel_size.y / 2.0 + height - sleeve_height) / 2.0


func logo_box() -> Rect2:
	return ShapeGeometry.centred(Vector2(0.0, at(logo_drop())), LOGO)


## The back's recesses, as seen from the back: the two stripes, the panel, the dimple and the
## screw's hole.
func back_boxes() -> Array[Rect2]:
	var stripe := Vector2(stripe_width, stripe_span().y - stripe_span().x)
	var middle := at((stripe_span().x + stripe_span().y) / 2.0)
	return [ShapeGeometry.centred(Vector2(-stripe_offset, middle), stripe),
		ShapeGeometry.centred(Vector2(stripe_offset, middle), stripe),
		ShapeGeometry.centred(Vector2(0.0, at(panel_drop)), panel_size),
		ShapeGeometry.square_around(Vector2(0.0, at(dimple_drop())), DIMPLE / 2.0),
		ShapeGeometry.square_around(Vector2(0.0, at(screw_drop())), SCREW_HOLE / 2.0)]


func marks_box() -> Rect2:
	return ShapeGeometry.centred(Vector2(0.0, at(panel_drop)), MARKS)


func parts() -> Array[StringName]:
	return GbaCartGeometry.PARTS


func _arrays(part: StringName, detail: int) -> Array:
	return GbaCartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var half := body_width() / 2.0
	var whole := Rect2(-width / 2.0, -height / 2.0, width, height)
	var front_holes: Array[Rect2] = [recess_box(), arrow_box()]
	var behind := back_boxes()
	var middle_apart := behind.slice(2).all(func(box: Rect2) -> bool: return box.end.x < behind[1].position.x - RIM)
	var body_face := GbaCartGeometry.body_outline(self, BEVEL, chamfer.x, 4)
	var back_face := GbaCartGeometry.plate_outline(self, BEVEL, 4)
	var recess_top := label_drop - RECESS_MARGIN
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and depth > 0.0 and label_size.x > 2.0 * LABEL_CORNER
			and label_size.y > 2.0 * LABEL_CORNER and arrow.x > 0.0 and arrow.y > 0.0 and stripe_width > 0.0
			and panel_size.x > 0.0 and panel_size.y > 0.0 and chamfer.x > 0.0 and chamfer.y > 0.0 and shoulder > 0.0
			and sleeve_inset > 0.0 and hump.x >= 0.0,
		&"layers_fit": plate_depth > maxf(SCREW_SINK, DIMPLE_DEPTH) + BEVEL + 0.1
			and plate_depth > SLEEVE_STEP + BEVEL + 0.1 and plate_depth > PANEL_DEPTH + 0.3
			and body_depth - plate_depth > chamfer.y + BEVEL + 0.1 and chamfer.y > BEVEL and chamfer.x > BEVEL
			and body_depth - plate_depth > maxf(RECESS, SHALLOW) + CONNECTOR.y / 2.0 + 0.5
			and peak() - head_front() > ROLL + 0.2 and head_front() - ROLL > joint() + 0.1,
		&"outline_fits": corner > BEVEL and head_drop > corner + HEAD_CORNER + ROLL + 0.1 and half > maxf(chamfer.x, BOTTOM_CORNER) + 2.0
			and height - head_drop > sleeve_height + 0.5 and sleeve_height > BOTTOM_CORNER + FILLET + 0.1
			and BOTTOM_CORNER + 0.1 < TAPER and TAPER < height - head_drop - 0.5
			and half - sleeve_inset > BOTTOM_CORNER + 1.0,
		&"hump_fits": hump.x + 1.0 < hump.y and hump.y < width / 2.0 - maxf(corner, HEAD_CORNER) - 0.1
			and arch_drop > ROLL + 0.3 and arch_drop < head_drop - 0.5,
		&"front_on_its_face": GbCartShape.holds(body_face, front_holes)
			and ShapeGeometry.apart(front_holes, whole, RIM)
			and recess_top > arch(recess_box().size.x / 2.0) + RIM,
		&"logo_on_the_band": recess_top - arch(LOGO.x / 2.0) > LOGO.y + 0.2 and LOGO.x / 2.0 < half - chamfer.x - 0.5,
		&"back_on_its_face": GbCartShape.holds(back_face, behind) and ShapeGeometry.apart(behind, whole, RIM)
			and middle_apart
			and ShapeGeometry.fits(marks_box(), 0.0, behind[2], Vector2.ONE * PANEL_CORNER),
		&"lines_cross_straight_edges": stripe_offset > 0.05 and stripe_offset < half - FILLET - 0.05,
		&"connector_on_the_bottom": CONNECTOR.x < body_width() - 2.0 * BOTTOM_CORNER - 1.0
			and CONNECTOR.y < body_depth - plate_depth - 2.0 * BEVEL,
	}
