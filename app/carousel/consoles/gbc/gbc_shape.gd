# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GbcShape
extends GlbShape
## What the launch reads of the Game Boy Color (its glb, `gbc.glb`), a handheld standing as it is held,
## in millimetres, in the model's axes: X to the right, Y up, Z out of the face, from the middle of the
## outline and of the shell's depth. A cartridge goes down the pocket at the top of the back, label to
## the back; the power switch on the right side slides to switch on.

## The shell's height and depth, from its back to its face.
@export var height := 133.5:
	set(value):
		height = value
		emit_changed()
@export var depth := 22.0:
	set(value):
		depth = value
		emit_changed()
## The cartridge the slot takes, its width, height and thickness; how far its top stands out of the
## console's top, and its label behind the back (in front of the back plate's wall).
@export var cartridge := Vector3(58.0, 65.5, 7.5):
	set(value):
		cartridge = value
		emit_changed()
@export var cartridge_rise := 3.0:
	set(value):
		cartridge_rise = value
		emit_changed()
@export var cartridge_inset := 2.5:
	set(value):
		cartridge_inset = value
		emit_changed()
## How far the power switch slides, from the printed OFF at the top of its recess down to the printed ON.
@export var power_travel := 4.5:
	set(value):
		power_travel = value
		emit_changed()


## Where a seated cartridge stands, in the model's space: upright in the pocket, its label to the back.
func seat() -> Transform3D:
	var bottom := height / 2.0 + cartridge_rise - cartridge.y
	var centre := Vector3(0.0, bottom + cartridge.y / 2.0, cartridge_inset + cartridge.z / 2.0 - depth / 2.0)
	return Transform3D(Basis(Vector3.UP, PI), centre * MeshBuilder.UNITS_PER_MM)
