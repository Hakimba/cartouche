# SPDX-License-Identifier: GPL-3.0-or-later
class_name NesModel
extends ConsoleModel
## The NES, drawn from its glb (`nes.glb`) and read by its [NesShape]: its door, lifted by hand before the
## cartridge comes and closed once it is in, turns up and back about its lid's back edge and stands open
## above the top; its tray, carrying the cartridge, stands tilted up about its back to take it and is
## pressed down level once it is in; its power button stays pushed in while it is on, its diode lit; its
## reset button goes in when pressed. Each part turns or slides from the rest the glb gives its node.

## How bright the diode once lit.
const _LIT := 2.0

## How far the door is open, in degrees.
var door_degrees := 0.0:
	set(value):
		# Each is given each frame by the launch animation: moved only when it changes.
		if value != door_degrees and is_node_ready():
			_door.rotation.x = -deg_to_rad(value)
		door_degrees = value
## How far the tray is tilted up, in degrees.
var tray_degrees := 0.0:
	set(value):
		if value != tray_degrees and is_node_ready():
			_tray.rotation.x = -deg_to_rad(value)
		tray_degrees = value
## How far the power and reset buttons are pushed in, in millimetres.
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_power.position.z = _power_front - value * MeshBuilder.UNITS_PER_MM
		power_mm = value
var reset_mm := 0.0:
	set(value):
		if value != reset_mm and is_node_ready():
			_reset.position.z = _reset_front - value * MeshBuilder.UNITS_PER_MM
		reset_mm = value

@onready var _door: Node3D = $Model/nes/door
@onready var _tray: Node3D = $Model/nes/tray
@onready var _power: Node3D = $Model/nes/power
@onready var _reset: Node3D = $Model/nes/reset
@onready var _power_front := _power.position.z
@onready var _reset_front := _reset.position.z


func _ready() -> void:
	Diagnostics.trace("console", "model=nes glb")
	_door.rotation.x = -deg_to_rad(door_degrees)
	_tray.rotation.x = -deg_to_rad(tray_degrees)
	_power.position.z = _power_front - power_mm * MeshBuilder.UNITS_PER_MM
	_reset.position.z = _reset_front - reset_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"door_degrees", MovingPart.Role.OPENING, 0.0, NesShape.DOOR_OPEN),
		MovingPart.new(&"tray_degrees", MovingPart.Role.OPENING, 0.0, (shape as NesShape).tray_tilt),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, NesShape.BUTTON_IN),
		MovingPart.new(&"reset_mm", MovingPart.Role.POSE, 0.0, NesShape.BUTTON_IN),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as NesShape).seat(tray_degrees)


## A cartridge slides in through the open door, label up, its connector first: along its top edge,
## which lies along the tray towards the front.
func approach() -> Vector3:
	return Vector3.UP


func _lights() -> Array[MeshInstance3D]:
	return [$Model/nes/led]
