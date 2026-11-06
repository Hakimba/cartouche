# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name MegaDriveShape
extends GlbShape
## What the launch reads of a Mega Drive (its glb, `megadrive.glb`, or a variant's), in millimetres, in the model's
## axes: X to the right, Y up from the table, Z towards the front, from the body's middle.

## Where a seated cartridge's centre is: upright in the slot of the top, half of it standing out.
@export var cartridge_centre := Vector3(30.5, 60.0, -37.5):
	set(value):
		cartridge_centre = value
		emit_changed()


## Where a seated cartridge stands, in the model's space: upright, its label to the front.
func seat() -> Transform3D:
	return Transform3D(Basis(), cartridge_centre * MeshBuilder.UNITS_PER_MM)
