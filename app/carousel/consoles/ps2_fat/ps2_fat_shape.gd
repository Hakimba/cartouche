# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name Ps2FatShape
extends GlbShape
## The bench's tray pivot and disc recess, in millimetres in the model's frame.

@export var tray_pivot := Vector3(58.8519, 58.43225, 0.0):
	set(value):
		tray_pivot = value
		emit_changed()
@export var recess := Vector3(1.26, 3.59, 16.1):
	set(value):
		recess = value
		emit_changed()
@export var tray_travel := 138.6:
	set(value):
		tray_travel = value
		emit_changed()


func seat(travel: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0),
		(tray_pivot + recess + Vector3.BACK * travel) * MeshBuilder.UNITS_PER_MM)
