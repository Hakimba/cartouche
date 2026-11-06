# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name MasterSystemShape
extends GlbShape
## What the launch reads of the Master System (its glb, `mastersystem.glb`), in millimetres, in the model's axes: X to
## the right, Y up from the table, Z towards the front, from the body's middle.

## Where a seated cartridge's centre is: upright in the slot of the top, half of it standing out.
@export var cartridge_centre := Vector3(63.25, 70.0, -39.7):
	set(value):
		cartridge_centre = value
		emit_changed()


## Where a seated cartridge stands, in the model's space: upright, its label to the front.
func seat() -> Transform3D:
	return Transform3D(Basis(), cartridge_centre * MeshBuilder.UNITS_PER_MM)
