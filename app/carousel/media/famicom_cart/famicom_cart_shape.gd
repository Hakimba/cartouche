# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name FamicomCartShape
extends ModelShape
## The dimensions of a 60-pin Famicom cartridge, in millimetres, the label facing +Z and the
## connector's foot at the bottom (see [FamicomCartGeometry]): a bevelled slab of the outline the
## NES Game Pak's is drawn as, its top corners rounder, the label's recess closed all round on its
## front, the foot's end open over the connector. Positions are from the centre of the outline.

## The least plastic, in millimetres, between the label's recess and the bevel round the front.
const RIM := 0.5

@export var width := 108.0:
	set(value):
		width = value
		emit_changed()
@export var height := 71.0:
	set(value):
		height = value
		emit_changed()
@export var depth := 17.0:
	set(value):
		depth = value
		emit_changed()
## The connector's foot under the shoulders: its width and height.
@export var foot := Vector2(92.3, 10.7):
	set(value):
		foot = value
		emit_changed()
@export var top_corner := 3.3:
	set(value):
		top_corner = value
		emit_changed()
## The shoulders' and the foot's corners.
@export var corner := 1.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 0.8:
	set(value):
		bevel = value
		emit_changed()
@export var label_size := Vector2(92.0, 45.0):
	set(value):
		label_size = value
		emit_changed()
@export var label_centre := Vector2(0.0, 5.6):
	set(value):
		label_centre = value
		emit_changed()
@export var label_corner := 1.0:
	set(value):
		label_corner = value
		emit_changed()
@export var recess := 0.4:
	set(value):
		recess = value
		emit_changed()
## The opening in the foot's end over the connector: its width and its height through the depth.
@export var opening := Vector2(86.0, 11.0):
	set(value):
		opening = value
		emit_changed()


func label_box() -> Rect2:
	return ShapeGeometry.centred(label_centre, label_size)


## The front above the shoulders, which holds the label.
func body() -> Rect2:
	return Rect2(-width / 2.0, foot.y - height / 2.0, width, height - foot.y)


func parts() -> Array[StringName]:
	return FamicomCartGeometry.PARTS


func _arrays(part: StringName, detail: int) -> Array:
	return FamicomCartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and recess > 0.0 and opening.x > 0.0 and opening.y > 0.0,
		&"bevel_fits": bevel > 0.0 and bevel < minf(corner, top_corner) and 2.0 * bevel < depth
			and recess < depth - 2.0 * bevel,
		&"foot_fits": foot.y >= corner and height - foot.y >= corner + top_corner and foot.x > 2.0 * corner
			and width - foot.x >= 2.0 * corner and opening.x < foot.x - 2.0 * corner
			and opening.y < depth - 2.0 * bevel,
		&"label_on_body": label_corner >= 0.0 and 2.0 * label_corner < minf(label_size.x, label_size.y)
			and ShapeGeometry.fits(label_box().grow(RIM), label_corner + RIM, body().grow(-bevel),
				Vector2(corner, top_corner) - Vector2.ONE * bevel),
		# The front is cut in two through the label's centre, across the top's and the foot's straight
		# edges.
		&"label_over_straight_edges": absf(label_centre.x) < minf(width / 2.0 - top_corner, foot.x / 2.0 - corner),
	}
