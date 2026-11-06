# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name BoxCartShape
extends ModelShape
## The dimensions of a cartridge shaped as a rounded box, in millimetres, the label facing +Z (see
## [BoxCartGeometry]): its outline's corners rounded, its front's and back's edges too, the label in a
## recess of the front, and ridges to grip it across the front above the label. A cartridge whose
## outline, back or connector shows more than that has a shape of its own.

## How far the grip's ridges stand out of the front.
const GRIP_RISE := 0.5
## How far the label and the ridges stay from the bevels and from each other.
const _MARGIN := 0.2

@export var width := 21.0:
	set(value):
		width = value
		emit_changed()
@export var height := 31.0:
	set(value):
		height = value
		emit_changed()
@export var depth := 3.3:
	set(value):
		depth = value
		emit_changed()
@export var corner := 1.5:
	set(value):
		corner = value
		emit_changed()
## How round the front's and the back's edges are.
@export var bevel := 0.4:
	set(value):
		bevel = value
		emit_changed()
## The label's left and top edges from the front's top left corner, its width and its height, as a
## scan of the front shows it.
@export var label := Rect2(1.5, 5.0, 18.0, 24.0):
	set(value):
		label = value
		emit_changed()
@export var label_corner := 1.0:
	set(value):
		label_corner = value
		emit_changed()
## How deep the label's recess is.
@export var recess := 0.3:
	set(value):
		recess = value
		emit_changed()
## The grip's ridges between the top edge and the label: how many, one every [code]y[/code], each
## [code]z[/code] high; none when there are no ridges.
@export var grip := Vector3.ZERO:
	set(value):
		grip = value
		emit_changed()


## The label seen from the front, from the outline's centre.
func label_box() -> Rect2:
	return Rect2(label.position.x - width / 2.0, height / 2.0 - label.end.y, label.size.x, label.size.y)


## The grip's ridges, as wide as the label, centred between the top edge and the label.
func ridges() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var count := int(grip.x)
	var box := label_box()
	var top := (height / 2.0 + box.end.y + (count - 1) * grip.y + grip.z) / 2.0
	for k in count:
		found.append(Rect2(box.position.x, top - grip.z - k * grip.y, box.size.x, grip.z))
	return found


func parts() -> Array[StringName]:
	return BoxCartGeometry.PARTS


func _arrays(part: StringName, detail: int) -> Array:
	return BoxCartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var face := Rect2(-width / 2.0, -height / 2.0, width, height).grow(-bevel)
	var box := label_box()
	var grips := ridges()
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and recess > 0.0 and label_corner >= 0.0,
		# The edges rounded within the corners, the label's recess within the depth.
		&"bevel_fits": bevel > 0.0 and corner > bevel and depth > 2.0 * (bevel + recess),
		# Clear of the bevels, the label's middle on the straight top and bottom edges, its corners within it.
		&"label_on_the_front": ShapeGeometry.within(box.grow(_MARGIN), face)
			and absf(box.get_center().x) < width / 2.0 - corner and 2.0 * label_corner < minf(box.size.x, box.size.y),
		&"grip_fits": grip.x >= 0.0 and (grips.is_empty() or grip.z > 0.0 and grip.y > grip.z
			and ShapeGeometry.within(grips[0], face) and grips[-1].position.y > box.end.y + _MARGIN),
	}
