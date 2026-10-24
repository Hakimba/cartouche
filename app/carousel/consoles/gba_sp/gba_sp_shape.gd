# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GbaSpShape
extends GlbShape
## The bench's front slot: the cartridge lies label down and goes in towards the hinge.

@export var cartridge_centre := Vector3(0.0, -2.815, 24.4):
	set(value):
		cartridge_centre = value
		emit_changed()
@export var power_travel := 1.8:
	set(value):
		power_travel = value
		emit_changed()


func seat() -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN),
		cartridge_centre * MeshBuilder.UNITS_PER_MM)
