# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name DiscShape
extends ModelShape
## The dimensions of an optical disc, in millimetres, measured from its centre: the carousel builds
## the disc from them (see [DiscGeometry]). From the centre out, the clear hub holds the hole and
## the stacking ring; the label is printed on top from [member label_inner] to [member label_outer];
## underneath, the mirror layer runs from [member mirror_inner] to [member mirror_outer], recorded
## from [member data_inner] to [member data_outer]; a clear rim closes the disc.

@export var radius := 60.0:
	set(value):
		radius = value
		emit_changed()
@export var thickness := 1.2:
	set(value):
		thickness = value
		emit_changed()
@export var hole := 7.5:
	set(value):
		hole = value
		emit_changed()
## Centre, width and height of the raised ring that keeps stacked discs apart.
@export var ring := 17.0:
	set(value):
		ring = value
		emit_changed()
@export var ring_width := 1.2:
	set(value):
		ring_width = value
		emit_changed()
@export var ring_height := 0.15:
	set(value):
		ring_height = value
		emit_changed()
@export var label_inner := 18.5:
	set(value):
		label_inner = value
		emit_changed()
@export var label_outer := 59.0:
	set(value):
		label_outer = value
		emit_changed()
@export var mirror_inner := 18.5:
	set(value):
		mirror_inner = value
		emit_changed()
@export var mirror_outer := 58.5:
	set(value):
		mirror_outer = value
		emit_changed()
@export var data_inner := 22.5:
	set(value):
		data_inner = value
		emit_changed()
@export var data_outer := 57.0:
	set(value):
		data_outer = value
		emit_changed()


func parts() -> Array[StringName]:
	return DiscGeometry.PARTS


func _arrays(part: StringName, detail: int) -> Array:
	return DiscGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var edge := radius - thickness / 2.0
	var hub := ring + ring_width / 2.0
	return {
		&"sizes_positive": thickness > 0.0 and ring_height >= 0.0 and ring_width > 0.0,
		&"ring_outside_hole": hole > 0.0 and ring - ring_width / 2.0 > hole,
		&"ring_inside_label_and_mirror": hub < minf(label_inner, mirror_inner),
		&"label_inside_rim": label_inner < label_outer and label_outer < edge,
		&"data_on_mirror":
			mirror_inner < data_inner and data_inner < data_outer and data_outer < mirror_outer,
		&"mirror_inside_rim": mirror_outer < edge,
	}


## The title goes between the rim and the hub, above it; the platform below the hub.
func title_area() -> Rect2:
	var hub := label_inner / radius / 2.0
	var rim := label_outer / radius / 2.0 * 0.8
	return Rect2(0.2, 0.5 - rim, 0.6, maxf(0.02, rim - hub - 0.02))


func platform_area() -> Rect2:
	return Rect2(0.2, 0.5 + label_inner / radius / 2.0 + 0.09, 0.6, 0.18)
