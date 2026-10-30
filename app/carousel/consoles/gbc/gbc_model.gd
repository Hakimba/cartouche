# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbcModel
extends ConsoleModel
## The Game Boy Color, drawn from its glb (`gbc.glb`) and read by its [GbcShape]: a cartridge goes down
## the pocket at the top of its back, label to the back; the power switch on its right side rests on the
## printed OFF and slides down to ON, and the power light by the screen comes on.

## How bright the power light is once on, as its material's emission energy.
const _LIT := 2.5
## A handheld is presented standing, its face to the camera, its top leant back towards it this far,
## in degrees, so that the slot shows as the cartridge comes down into it.
const _LEAN_DEGREES := 15.0

var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_power.position.y = _power_top - value * MeshBuilder.UNITS_PER_MM
		power_mm = value

@onready var _power: Node3D = $Model/gbc/power
@onready var _power_top := _power.position.y


func _ready() -> void:
	Diagnostics.trace("console", "model=gbc glb")
	_power.position.y = _power_top - power_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as GbcShape).power_travel),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as GbcShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func presented() -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(_LEAN_DEGREES))


func _lights() -> Array[MeshInstance3D]:
	return [$Model/gbc/led]
