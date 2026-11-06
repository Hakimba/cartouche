# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name PspShape
extends GlbShape
## What the launch reads of the PSP (its glb, `psp.glb`), a handheld standing as it is held, in millimetres, in the
## model's axes: X to the right, Y up, Z out of the face, from the middle of the outline and of the shell's depth.

## Where a seated UMD's centre is: in the drive behind the back's window.
@export var umd_centre := Vector3(5.0, 0.0, -6.0):
	set(value):
		umd_centre = value
		emit_changed()


## Where a seated UMD stands, in the model's space: upright in the back, its label to the back.
func seat() -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), umd_centre * MeshBuilder.UNITS_PER_MM)
