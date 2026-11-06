# SPDX-License-Identifier: GPL-3.0-or-later
class_name SeatShape
extends Resource
## Where a console's medium seats, given as data in its `<folder>_shape.tres`: in millimetres, in the model's axes (X to
## the right, Y up, Z out of its front), every moving part at 0.

## Where a seated medium's centre is.
@export var seat_centre := Vector3.ZERO
## How the seated medium is turned from its own axes, in degrees (Godot's Euler order, YXZ): a disc lying flat, its
## label up, is (-90, 0, 0); a medium upright, its label to the back, (0, 180, 0).
@export var seat_degrees := Vector3.ZERO
## The moving part carrying the seated medium (a tray), by its property, if any: the seat slides with it, or turns with
## it about [member pivot].
@export var carrier: StringName
@export var pivot := Vector3.ZERO


## Where a seated medium stands, every moving part at 0 (see [method ConsoleModel.seat]).
func seat() -> Transform3D:
	return Transform3D(Basis.from_euler(seat_degrees * PI / 180.0), seat_centre * MeshBuilder.UNITS_PER_MM)
