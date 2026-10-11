# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbModel
extends ConsoleModel
## The Game Boy, built from its [GbShape]: the cartridge comes down into the bay at the top of its
## back, its label to the back; the power switch on the top slides right and the power light beside
## the screen comes on. It is shown by its front, its top leant a little towards the camera so that
## the bay shows as the cartridge comes down.

## A handheld is presented standing, its face to the camera, its top leant back towards it this far,
## in degrees, so that the slot shows as the cartridge comes down into it.
const _LEAN_DEGREES := 15.0
## How bright the power light is once on, as its material's emission energy.
const _LIT := 2.5

## How far the power switch has slid right, in millimetres.
var power_mm := 0.0:
	set(value):
		# Given each frame by the launch animation: the knob is moved only when it slides.
		if value != power_mm and is_node_ready():
			_power.position.x = value * MeshBuilder.UNITS_PER_MM
		power_mm = value

@onready var _power: Node3D = %Power


func _ready() -> void:
	_power.position.x = power_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as GbShape).travel()),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as GbShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func presented() -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(_LEAN_DEGREES))
