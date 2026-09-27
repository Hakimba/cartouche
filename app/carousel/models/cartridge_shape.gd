# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name CartridgeShape
extends ModelShape
## The dimensions of a cartridge, in millimetres, the front facing +Z (see [CartridgeGeometry]).
## Three bevelled blocks: the body, whose label sits in a shallow recess with sloped edges; the
## upper part, wider on each side (the notches) and standing out in front as a ledge over the label,
## with a plate raised where a logo would be embossed; and a rounded ridge along the top edge.
## Positions are of centres, from the centre of the body's front.

## The least plastic, in millimetres, between the label's recess and the edge of the body's front.
const _RIM := 0.1

@export var width := 57.0:
	set(value):
		width = value
		emit_changed()
@export var height := 35.0:
	set(value):
		height = value
		emit_changed()
## The body's depth; the upper part and the ridge stand further out in front.
@export var depth := 6.6:
	set(value):
		depth = value
		emit_changed()
@export var top_corner := 3.0:
	set(value):
		top_corner = value
		emit_changed()
@export var bottom_corner := 1.2:
	set(value):
		bottom_corner = value
		emit_changed()
@export var bevel := 0.7:
	set(value):
		bevel = value
		emit_changed()
@export var upper_height := 8.5:
	set(value):
		upper_height = value
		emit_changed()
## How much wider the upper part is on each side, and how far it stands out over the body.
@export var notch := 0.8:
	set(value):
		notch = value
		emit_changed()
@export var ledge := 0.5:
	set(value):
		ledge = value
		emit_changed()
@export var ridge_height := 2.4:
	set(value):
		ridge_height = value
		emit_changed()
@export var ridge_raise := 0.5:
	set(value):
		ridge_raise = value
		emit_changed()
@export var label_size := Vector2(44.0, 22.5):
	set(value):
		label_size = value
		emit_changed()
@export var label_centre := Vector2(0.0, -4.3):
	set(value):
		label_centre = value
		emit_changed()
@export var label_corner := 1.5:
	set(value):
		label_corner = value
		emit_changed()
@export var recess := 0.5:
	set(value):
		recess = value
		emit_changed()
## Width of the sloped edge going down into the recess.
@export var recess_slope := 0.9:
	set(value):
		recess_slope = value
		emit_changed()
@export var plate_size := Vector2(36.0, 3.6):
	set(value):
		plate_size = value
		emit_changed()
@export var plate_centre := Vector2(0.0, 12.4):
	set(value):
		plate_centre = value
		emit_changed()
@export var plate_raise := 0.2:
	set(value):
		plate_raise = value
		emit_changed()


## Where the upper part starts.
func step() -> float:
	return height / 2.0 - upper_height


## The radius of the body's top corners, hidden in the upper part.
func hidden_corner() -> float:
	return bevel + 0.1


## The body's front, from its bottom to where the upper part starts.
func body() -> Rect2:
	return Rect2(notch - width / 2.0, -height / 2.0, width - 2.0 * notch, step() + height / 2.0)


func label_box() -> Rect2:
	return Rect2(label_centre - label_size / 2.0, label_size)


func plate_box() -> Rect2:
	return Rect2(plate_centre - plate_size / 2.0, plate_size)


func plate_corner() -> float:
	return minf(1.0, minf(plate_size.x, plate_size.y) / 2.0)


func parts() -> Array[StringName]:
	return CartridgeGeometry.PARTS


func mesh_arrays(part: StringName, detail: int) -> Array:
	return CartridgeGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var upper := Rect2(-width / 2.0, step(), width, upper_height)
	return {
		# Raised faces stand out of the ones under them: level, they would flicker.
		&"sizes_positive": width > 0.0 and height > 0.0 and depth > 0.0 and recess > 0.0
			and recess_slope >= 0.0 and plate_raise > 0.0 and ledge >= 0.0 and ridge_raise > 0.0
			and notch >= 0.0,
		&"bevel_fits": bevel > 0.0 and bevel < minf(bottom_corner, top_corner) and 2.0 * bevel < depth,
		# Each part is taller and wider than its two corners.
		&"upper_part_fits": upper_height > top_corner + hidden_corner()
			and upper_height < height - bottom_corner - hidden_corner()
			and width > 2.0 * top_corner and body().size.x > 2.0 * bottom_corner,
		&"ridge_fits": ridge_height > 2.0 * bevel and ridge_height < upper_height - 2.0 * bevel
			and ridge_height < depth + ledge and ridge_height < width - 2.0 * bevel,
		# The recess, sloped edges included, lies within the body's rounded front, with some plastic
		# left around it.
		&"label_on_body": label_corner > 0.0 and 2.0 * label_corner < minf(label_size.x, label_size.y)
			and _fits(label_box().grow(recess_slope + _RIM), label_corner + recess_slope + _RIM,
				body().grow(-bevel), bottom_corner - bevel, hidden_corner() - bevel),
		# The body's front is cut in two through the label's centre, across its straight edges.
		&"label_over_straight_edge":
			absf(label_centre.x) < body().end.x - maxf(bottom_corner, hidden_corner()),
		&"plate_on_upper_part": plate_box().end.y <= height / 2.0 - ridge_height
			and _fits(plate_box(), plate_corner(), upper.grow(-bevel), hidden_corner() - bevel,
				top_corner - bevel),
		&"recess_fits": recess < depth - 2.0 * bevel,
	}


## Whether the rectangle [param inner], its corners rounded by [param rounding], lies within
## [param outer], its bottom corners rounded by [param bottom] and its top ones by [param top].
## Impossible dimensions can turn either inside out: then it does not.
static func _fits(inner: Rect2, rounding: float, outer: Rect2, bottom: float, top: float) -> bool:
	if minf(inner.size.x, inner.size.y) <= 0.0 or minf(outer.size.x, outer.size.y) <= 0.0 \
			or not outer.encloses(inner):
		return false
	for quarter in 4:
		var corner := top if quarter < 2 else bottom
		var side := Vector2(1.0 if quarter in [0, 3] else -1.0, 1.0 if quarter < 2 else -1.0)
		var outer_centre := outer.get_center() + side * (outer.size / 2.0 - Vector2.ONE * corner)
		var inner_centre := inner.get_center() + side * (inner.size / 2.0 - Vector2.ONE * rounding)
		var beyond := (inner_centre - outer_centre) * side
		if beyond.x > 0.0 and beyond.y > 0.0 and beyond.length() + rounding > corner:
			return false
	return true
