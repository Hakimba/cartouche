# SPDX-License-Identifier: GPL-3.0-or-later
class_name GbaModel
extends ConsoleModel
## The Game Boy Advance, built from its [GbaShape]: the power switch slides along the bottom
## towards the middle, the power light comes on, and the shoulder buttons press down about the
## inner ends. It is presented standing, its screen to the camera, leant back enough to show the
## cartridge going down into the top.

## The shoulder buttons fully pressed, in degrees; how bright the power light is once on.
const _PRESS_DEGREES := 3.5
const _LIT := 2.5
## A handheld is presented standing, its face to the camera, its top leant back towards it this far,
## in degrees, so that the slot shows as the cartridge comes down into it.
const _LEAN_DEGREES := 18.0

## How far the power switch has slid on, in millimetres.
var power_mm := 0.0:
	set(value):
		# Given each frame by the launch animation: the parts are moved only when they move.
		if value != power_mm and is_node_ready():
			_slide(value)
		power_mm = value
## How far the shoulder buttons are pressed, in degrees.
var shoulders_degrees := 0.0:
	set(value):
		if value != shoulders_degrees and is_node_ready():
			_press(value)
		shoulders_degrees = value

var _switch_rest: Transform3D

@onready var _power: Node3D = %Power
@onready var _left: Node3D = %LeftShoulder
@onready var _right: Node3D = %RightShoulder


func _ready() -> void:
	_switch_rest = (shape as GbaShape).switch_rest()
	_left.position = (shape as GbaShape).shoulder_pivot(false)
	_right.position = (shape as GbaShape).shoulder_pivot(true)
	_power.transform = _switch_rest
	_slide(power_mm)
	_press(shoulders_degrees)


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as GbaShape).switch_travel()),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
		MovingPart.new(&"shoulders_degrees", MovingPart.Role.POSE, 0.0, _PRESS_DEGREES),
	]


func seat() -> Transform3D:
	return (shape as GbaShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func presented() -> Basis:
	return Basis(Vector3.RIGHT, deg_to_rad(_LEAN_DEGREES))


func _slide(mm: float) -> void:
	_power.position = _switch_rest.origin + _switch_rest.basis.x * mm * MeshBuilder.UNITS_PER_MM


## Each button's outer end goes down: the left one turns forward about Z, the right one back.
func _press(degrees: float) -> void:
	_left.rotation.z = deg_to_rad(degrees)
	_right.rotation.z = -deg_to_rad(degrees)
