# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name N64CartShape
extends ModelShape
## The dimensions of a Nintendo 64 Game Pak, in millimetres, in the seat's frame: centred, +Z out of
## the label, +Y towards its top edge (see [N64CartGeometry]). One outline, its top an arc, its sides
## straight, swept through layers from the back: the back, cut at its bottom corners by the two
## indentations the console's flaps pass; the core, split along its bottom by the slot the board's
## contacts sit in; the front's wings, stepped down at their bottom corners; and the central band
## standing over them between two grooves, the label in its recess; the front's edges rolled round.
## The back carries the printed caution sticker, two screws and the maker's name moulded in a raised
## oval rim. The grooves, narrow and deep, read as dark lines: those of the front go up over the top
## and run down the back, through the screws, broken by the sticker. Positions are of centres, from
## the centre of the outline.

## How far each layer goes into the one under it.
const OVERLAP := 0.05
## The plastic left between the label and its recess's wall, and how thick the label is.
const LABEL_GAP := 0.3
const LABEL_THICKNESS := 0.1
## How far inside a groove's walls its lining stands.
const LINING := 0.04
## The corner a stepped-down rail makes with the wing over it.
const RAIL_CORNER := 0.8
## How much rounder than the bevel a corner swept with it stays.
const ROUNDER := 0.1
## The least a label, a mark or the contacts measure across: smaller, they would hold no volume.
const SMALLEST := 1.0
## How far the sticker and the screws' heads stand out of the back, and the moulded name out of the
## oval.
const STICKER_THICKNESS := 0.15
const SCREW_PROUD := 0.1
const LETTERING_PROUD := 0.03
## The board between the halves: its thickness, and how far in from the bottom edge its contacts
## start.
const BOARD := 1.2
const CONTACT_INSET := 1.5

@export var width := 116.0:
	set(value):
		width = value
		emit_changed()
@export var height := 76.6:
	set(value):
		height = value
		emit_changed()
@export var depth := 18.5:
	set(value):
		depth = value
		emit_changed()
## How far the middle of the top rises over its corners.
@export var arch := 11.3:
	set(value):
		arch = value
		emit_changed()
@export var top_corner := 4.0:
	set(value):
		top_corner = value
		emit_changed()
@export var bottom_corner := 1.0:
	set(value):
		bottom_corner = value
		emit_changed()
## How round the back's edges are, and the front's: the wings', the band's and the rails'.
@export var bevel := 0.8:
	set(value):
		bevel = value
		emit_changed()
@export var shoulder := 2.6:
	set(value):
		shoulder = value
		emit_changed()
## The central band of the front, from the bottom edge to the top, and how far it stands over the
## wings either side: the depth of the label's recess; the groove between it and each wing.
@export var band_width := 70.0:
	set(value):
		band_width = value
		emit_changed()
@export var band_raise := 0.5:
	set(value):
		band_raise = value
		emit_changed()
@export var groove := 0.5:
	set(value):
		groove = value
		emit_changed()
## How round every groove's lips are, and how deep those over the top and down the back go.
@export var lip := 0.25:
	set(value):
		lip = value
		emit_changed()
@export var groove_depth := 1.5:
	set(value):
		groove_depth = value
		emit_changed()
@export var label_size := Vector2(58.3, 64.4):
	set(value):
		label_size = value
		emit_changed()
@export var label_centre := Vector2(0.0, -0.7):
	set(value):
		label_centre = value
		emit_changed()
## How far the middle of the label's top rises over its corners.
@export var label_arch := 1.4:
	set(value):
		label_arch = value
		emit_changed()
## The radius of the label's bottom corners and of its top ones.
@export var label_corners := Vector2(2.1, 4.5):
	set(value):
		label_corners = value
		emit_changed()
## The rails along the sides at the bottom of the front, stepped down from the wings: their width
## and their height at their inner edge; their top rises this much more to the side.
@export var rail_size := Vector2(7.4, 24.0):
	set(value):
		rail_size = value
		emit_changed()
@export var rail_slant := 2.4:
	set(value):
		rail_slant = value
		emit_changed()
@export var rail_step := 1.0:
	set(value):
		rail_step = value
		emit_changed()
## The indentations at the bottom corners of the back: how far each starts from the side, its width
## and its height, and how deep it goes.
@export var notch_from := 7.7:
	set(value):
		notch_from = value
		emit_changed()
@export var notch_size := Vector2(11.3, 10.0):
	set(value):
		notch_size = value
		emit_changed()
@export var notch_depth := 3.5:
	set(value):
		notch_depth = value
		emit_changed()
## The slot along the bottom between the halves: its width and its height through the thickness,
## and how far up it goes; the contacts across it.
@export var slot_size := Vector2(85.0, 2.4):
	set(value):
		slot_size = value
		emit_changed()
@export var slot_depth := 5.0:
	set(value):
		slot_depth = value
		emit_changed()
@export var contacts_width := 74.0:
	set(value):
		contacts_width = value
		emit_changed()
## The back's caution sticker, its screws (the right one; the left one mirrors it; the back's
## grooves run through them), its oval: the rim's outer size, its centre, the rim's width and how far
## it stands out.
@export var sticker_size := Vector2(81.3, 38.9):
	set(value):
		sticker_size = value
		emit_changed()
@export var sticker_centre := Vector2(0.0, -4.25):
	set(value):
		sticker_centre = value
		emit_changed()
@export var sticker_corner := 2.0:
	set(value):
		sticker_corner = value
		emit_changed()
@export var screw_centre := Vector2(34.8, 26.7):
	set(value):
		screw_centre = value
		emit_changed()
@export var screw_radius := 2.0:
	set(value):
		screw_radius = value
		emit_changed()
@export var oval_size := Vector2(29.0, 7.0):
	set(value):
		oval_size = value
		emit_changed()
@export var oval_centre := Vector2(0.0, 28.1):
	set(value):
		oval_centre = value
		emit_changed()
@export var oval_rim := Vector2(0.75, 0.3):
	set(value):
		oval_rim = value
		emit_changed()


func whole() -> Rect2:
	return Rect2(-width / 2.0, -height / 2.0, width, height)


## How far the middle of a top edge rises over the points [param half] either side of it, the edge
## [param inset] inside the outline's and round with it.
func arch_within(inset: float, half: float) -> float:
	var radius := (width * width / 4.0 + arch * arch) / (2.0 * arch) - inset
	return radius - sqrt(radius * radius - half * half)


func band_box() -> Rect2:
	return Rect2(-band_width / 2.0, -height / 2.0, band_width, height)


func label_box() -> Rect2:
	return ShapeGeometry.centred(label_centre, label_size)


func sticker_box() -> Rect2:
	return ShapeGeometry.centred(sticker_centre, sticker_size)


func oval_box() -> Rect2:
	return ShapeGeometry.centred(oval_centre, oval_size)


## The inside of the oval's rim, a pill.
func oval_inside() -> Rect2:
	return oval_box().grow(-oval_rim.x)


## Where the maker's name is moulded: within the pill inside the rim, clear of its round ends.
func lettering_box() -> Rect2:
	var inside := oval_inside().size
	return ShapeGeometry.centred(oval_centre, Vector2(inside.x - 0.6 * inside.y, 0.7 * inside.y))


## The round of the wings' and the band's corners, seen from the front: rounder than the edges
## rolled round them, even drawn in the fewest steps (three, each a chord nearer the centre).
func wing_corner() -> float:
	return shoulder / cos(PI / 12.0) + ROUNDER


## Where the grooves run, either side of the middle: on the front, between the band and the wings;
## over the top and down the back, the back's through its screws.
func front_line() -> float:
	return band_width / 2.0 + groove / 2.0


func back_line() -> float:
	return screw_centre.x


## How far along an edge either side of a groove's mouth the edge's roll eases into the groove's
## lips.
func mouth() -> float:
	return 2.5 * bevel


## The front of the wings, the floor of the label's recess.
func face() -> float:
	return depth / 2.0 - band_raise


## The front of the rails and of the core.
func rails() -> float:
	return face() - rail_step


func parts() -> Array[StringName]:
	return N64CartGeometry.PARTS


func _arrays(part: StringName, detail: int) -> Array:
	return N64CartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var sized := (width > 0.0 and height > 0.0 and depth > 0.0 and arch > 0.0 and band_width > 0.0
		and band_raise > 0.0 and label_size.x > 0.0 and label_size.y > 0.0 and label_arch > 0.0
		and label_corners.x > 0.0 and label_corners.y > 0.0 and rail_size.x > 0.0 and rail_size.y > 0.0
		and rail_slant >= 0.0 and rail_step > 0.0 and notch_from > 0.0 and notch_size.x > 0.0
		and notch_size.y > 0.0 and notch_depth > 0.0 and slot_size.x > 0.0 and slot_size.y > 0.0
		and slot_depth > 0.0 and contacts_width > 0.0 and sticker_size.x > 0.0 and sticker_size.y > 0.0
		and sticker_corner > 0.0 and screw_radius > 0.0 and oval_size.x > 0.0 and oval_size.y > 0.0
		and shoulder > 0.0 and groove > 0.0 and oval_rim.x > 0.0 and oval_rim.y > 0.0 and lip > 0.0
		and groove_depth > 0.0)
	var side := height - arch
	# Each corner stays round inside the bevel; the straight sides between two corners keep a bevel
	# of length, which the bevel's outlines shorten.
	var wing := wing_corner()
	var corners_hold := (bevel > 0.0 and bevel + ROUNDER < minf(bottom_corner, top_corner)
		and top_corner + bevel < width / N64CartGeometry.ARCS and bottom_corner + top_corner + bevel < side
		and 2.0 * bottom_corner + bevel < width and arch < width / 2.0 and wing < top_corner)
	# Each wing, between the side and its groove, holds its corners: at its foot, beside the rail;
	# along its top, on each piece of its arc. The band's top corners each lie on a piece of its arc.
	var across := width / 2.0 - band_width / 2.0 - groove
	var band_fits := (across - rail_size.x > 2.0 * wing and across / N64CartGeometry.WING_ARCS > maxf(top_corner, wing)
		and wing < band_width / N64CartGeometry.ARCS)
	var shaped := sized and corners_hold and band_fits
	var steps := 3
	var label_fits := (2.0 * maxf(label_corners.x, label_corners.y) < minf(label_size.x, label_size.y)
		and label_arch + label_corners.x + label_corners.y < label_size.y
		and label_corners.y + LABEL_GAP < (label_size.x + 2.0 * LABEL_GAP) / N64CartGeometry.ARCS
		and LABEL_THICKNESS < band_raise and minf(label_size.x, label_size.y) > SMALLEST)
	# Each groove holds its lining, its lips tighter than the edges easing into them and shallower
	# than its floor, its floor within the back's thickness; over the top, each lies within a piece
	# of the arc with its easing; down the back, between the oval and the indentations.
	var reach := groove / 2.0 + mouth()
	var lines := [front_line(), back_line()].all(func(x: float) -> bool:
		var piece := floorf((width / 2.0 - x) * N64CartGeometry.ARCS / width)
		var edge := width / 2.0 - piece * width / N64CartGeometry.ARCS
		return x + reach < edge and x - reach > edge - width / N64CartGeometry.ARCS)
	var grooves_fit := (sized and lines and groove > 2.0 * LINING and lip < minf(bevel, shoulder)
		and lip < rail_step and groove_depth > lip and groove_depth < notch_depth
		and back_line() - reach > oval_size.x / 2.0 + absf(oval_centre.x)
		and back_line() + reach + bottom_corner < width / 2.0 - notch_from - notch_size.x)
	var marks: Array[PackedVector2Array] = [ShapeGeometry.square(sticker_box()), ShapeGeometry.square(oval_box()),
		ShapeGeometry.square(ShapeGeometry.square_around(screw_centre, screw_radius))]
	var back_face := N64CartGeometry.outline(self, steps, bevel) if shaped else PackedVector2Array()
	var above_notches := notch_size.y + bevel - height / 2.0
	return {
		&"sizes_positive": sized,
		&"outline_holds_its_corners": corners_hold,
		# Back to front: the back over its indentations' floor, the core's two halves either side of
		# the slot, the front layer over the rails.
		&"layers_in_depth": notch_depth > bevel and notch_depth + OVERLAP - depth / 2.0 < -slot_size.y / 2.0
			and rails() - slot_size.y / 2.0 > bevel,
		&"indentations_fit": notch_from > 2.0 * bottom_corner + bevel and notch_size.x > 2.0 * bottom_corner
			and notch_from + notch_size.x < width / 2.0 - bottom_corner - bevel and notch_size.y > bottom_corner
			and notch_size.y + bottom_corner + top_corner + bevel < side,
		&"rails_fit": rail_size.x > maxf(bottom_corner + bevel, wing) + RAIL_CORNER
			and rail_size.y > wing + RAIL_CORNER and width / 2.0 - rail_size.x > bottom_corner + bevel
			and rail_size.y + rail_slant > bottom_corner + wing
			and rail_size.y + rail_slant + wing + top_corner + bevel < side,
		&"band_on_the_face": band_fits,
		&"grooves_fit": grooves_fit,
		# The label's recess within the band's flat face, across its middle, where the face is cut.
		&"label_in_the_band": label_fits and shaped and absf(label_centre.x) < label_size.x / 2.0
			and ShapeGeometry.inside(N64CartGeometry.recess(self, steps), N64CartGeometry.band(self, steps, shoulder)),
		&"slot_fits": slot_size.x < width - 2.0 * bottom_corner - 2.0 and contacts_width < slot_size.x
			and BOARD < slot_size.y and contacts_width > SMALLEST and slot_depth > CONTACT_INSET + OVERLAP
			and slot_depth + bottom_corner + top_corner < side,
		# The marks lie on the back's flat face, above the indentations.
		&"marks_on_the_back": 2.0 * sticker_corner < minf(sticker_size.x, sticker_size.y) and shaped
			and 2.0 * oval_rim.x < minf(oval_size.x, oval_size.y)
			and marks.all(func(mark: PackedVector2Array) -> bool:
				var box := ShapeGeometry.bounds(mark)
				return (ShapeGeometry.inside(mark, back_face) and box.position.y > above_notches
					and minf(box.size.x, box.size.y) > SMALLEST)),
	}
