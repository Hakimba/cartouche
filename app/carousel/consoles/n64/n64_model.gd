# SPDX-License-Identifier: GPL-3.0-or-later
class_name N64Model
extends ConsoleModel
## The Nintendo 64, built from its [N64Shape]: the slot's flaps fold down about their hinges as the
## cartridge comes down into it, the power switch and the reset button slide back, and the power
## light comes on.

## The flaps fully open, hanging down along the slot's walls, in degrees.
const _OPEN_DEGREES := 90.0
## How bright the power light is once on, as its material's emission energy.
const _LIT := 2.5

var flaps_degrees := 0.0:
	set(value):
		if value != flaps_degrees and is_node_ready():
			_fold(value)
		flaps_degrees = value
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_power.position.z = -value * MeshBuilder.UNITS_PER_MM
		power_mm = value
var reset_mm := 0.0:
	set(value):
		if value != reset_mm and is_node_ready():
			_reset.position.z = -value * MeshBuilder.UNITS_PER_MM
		reset_mm = value

@onready var _front_flap: Node3D = %FrontFlap
@onready var _back_flap: Node3D = %BackFlap
@onready var _power: Node3D = %Power
@onready var _reset: Node3D = %Reset


func _ready() -> void:
	_front_flap.position = (shape as N64Shape).flap_hinge(true)
	_back_flap.position = (shape as N64Shape).flap_hinge(false)
	_fold(flaps_degrees)
	_power.position.z = -power_mm * MeshBuilder.UNITS_PER_MM
	_reset.position.z = -reset_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"flaps_degrees", MovingPart.Role.FLAP, 0.0, _OPEN_DEGREES),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as N64Shape).travel(true)),
		MovingPart.new(&"reset_mm", MovingPart.Role.POSE, 0.0, (shape as N64Shape).travel(false)),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as N64Shape).seat()


func approach() -> Vector3:
	return Vector3.UP


func _fold(degrees: float) -> void:
	_front_flap.rotation.x = -deg_to_rad(degrees)
	_back_flap.rotation.x = deg_to_rad(degrees)
