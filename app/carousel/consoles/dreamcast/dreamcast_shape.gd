# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name DreamcastShape
extends GlbShape
## What the launch reads of the Dreamcast (its glb, `dreamcast.glb`), in millimetres, in the model's axes: X to the
## right, Y up from the table, Z towards the front, from the body's middle.

## Where a seated disc's centre is: on the drive's spindle under the lid.
@export var disc_centre := Vector3(0.0, 62.0, -5.0):
	set(value):
		disc_centre = value
		emit_changed()


## Where a seated disc stands, in the model's space: lying flat, its label up.
func seat() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), disc_centre * MeshBuilder.UNITS_PER_MM)
