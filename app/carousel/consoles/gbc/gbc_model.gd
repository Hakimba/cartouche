# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbcModel
extends ConsoleModel
## The Game Boy Color, built from its [GbcShape]: a cartridge goes down into the pocket at the top of
## its back, label to the back; the power switch on its right side slides up and the power light by
## the screen comes on. Each part is moved only when its value changes: the launch animation gives
## them every frame.

## How bright the power light is once on, as its material's emission energy.
const _LIT := 2.5
## A handheld is presented standing, its face to the camera, its top leant back towards it this far,
## in degrees, so that the slot shows as the cartridge comes down into it.
const _LEAN_DEGREES := 15.0

## How far the power knob has slid up, in millimetres.
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_power.position.y = value * MeshBuilder.UNITS_PER_MM
		power_mm = value

@onready var _power: Node3D = %Power


func _ready() -> void:
	_power.position.y = power_mm * MeshBuilder.UNITS_PER_MM


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
