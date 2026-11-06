# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name SwitchShape
extends GlbShape
## What the launch reads of the Nintendo Switch (its glb, `switch.glb`, or a variant's), standing as it is held, in
## millimetres, in the model's axes: X to the right, Y up, Z out of the face, from the middle of the outline and of the
## shell's depth.

## Where a seated game card's centre is: in the slot at the right of the top edge.
@export var card_centre := Vector3(62.0, 40.0, -2.0):
	set(value):
		card_centre = value
		emit_changed()


## Where a seated game card stands, in the model's space: upright, its label to the screen's side.
func seat() -> Transform3D:
	return Transform3D(Basis(), card_centre * MeshBuilder.UNITS_PER_MM)
