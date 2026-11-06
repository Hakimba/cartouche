# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name SnesShape
extends GlbConsoleShape
## What the launch reads of the PAL Super Nintendo (its glb, `snes.glb`), in millimetres, in the model's
## axes: X to the right, Y up from the table, Z towards the front, from the middle of the body's depth. A
## cartridge goes down the slot, label to the front, pushing the two flaps down about their hinges.

@export var seat_at := Vector3(0.0, 66.2, -25.69):
	set(value):
		seat_at = value
		emit_changed()
## How far the power knob slides back, from off to on, in millimetres.
@export var power_travel := 4.5:
	set(value):
		power_travel = value
		emit_changed()


## Where a seated cartridge's centre is, in the model's space: its label to the front.
func seat() -> Transform3D:
	return Transform3D(Basis(), seat_at * MeshBuilder.UNITS_PER_MM)
