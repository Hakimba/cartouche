# SPDX-License-Identifier: GPL-3.0-or-later
class_name WiiModel
extends ConsoleModel
## The Wii, built from its [WiiShape]: the disc goes in edge first through the slot, which glows blue
## once it is in; the power button is pressed and let go, the eject button presses in, the SD door
## swings open about its left edge.

## How far the buttons press in, in millimetres, unless they stand out less (see
## [method ConsoleModel.press_travel]); how bright the slot glows once lit.
const _PRESS_MM := 1.5
const _LIT := 2.5
## Standing, it shows a thin front: turned about its height, its right side shows too.
const _TURN_DEGREES := -30.0

var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_power.position.z = -value * MeshBuilder.UNITS_PER_MM
		power_mm = value
var eject_mm := 0.0:
	set(value):
		if value != eject_mm and is_node_ready():
			_eject.position.z = -value * MeshBuilder.UNITS_PER_MM
		eject_mm = value
var door_degrees := 0.0:
	set(value):
		if value != door_degrees and is_node_ready():
			_door.rotation.y = -deg_to_rad(value)
		door_degrees = value

@onready var _power: Node3D = %Power
@onready var _eject: Node3D = %Eject
@onready var _door: Node3D = %Door


func _ready() -> void:
	_door.position = (shape as WiiShape).door_hinge()
	_door.rotation.y = -deg_to_rad(door_degrees)
	_power.position.z = -power_mm * MeshBuilder.UNITS_PER_MM
	_eject.position.z = -eject_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER_PRESS, 0.0, _pressed()),
		MovingPart.new(&"eject_mm", MovingPart.Role.POSE, 0.0, _pressed()),
		MovingPart.new(&"door_degrees", MovingPart.Role.POSE, 0.0, WiiShape.DOOR_SWING),
	]


func seat() -> Transform3D:
	return (shape as WiiShape).seat()


## Out of the slot, towards the front: along the seat's -X (see [method WiiShape.seat]).
func approach() -> Vector3:
	return Vector3.LEFT


func presented() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(_TURN_DEGREES))


func _pressed() -> float:
	return press_travel(WiiShape.BUTTON_RAISE, _PRESS_MM)
