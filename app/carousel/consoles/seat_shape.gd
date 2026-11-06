# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name SeatShape
extends GlbConsoleShape
## The shape of a glb console whose seat stays where it is, given as data in its `<folder>_shape.tres`: in millimetres,
## in the model's axes (X to the right, Y up, Z out of its front).

## Where a seated medium's centre is.
@export var seat_centre := Vector3.ZERO:
	set(value):
		seat_centre = value
		emit_changed()
## How the seated medium is turned from its own axes, in degrees (Godot's Euler order, YXZ): a disc lying flat, its
## label up, is (-90, 0, 0); a medium upright, its label to the back, (0, 180, 0).
@export var seat_degrees := Vector3.ZERO:
	set(value):
		seat_degrees = value
		emit_changed()


func seat() -> Transform3D:
	return Transform3D(Basis.from_euler(seat_degrees * PI / 180.0), seat_centre * MeshBuilder.UNITS_PER_MM)
