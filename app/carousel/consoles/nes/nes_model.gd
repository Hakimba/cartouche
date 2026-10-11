# SPDX-License-Identifier: GPL-3.0-or-later
class_name NesModel
extends ConsoleModel
## The NES, built from its [NesShape]: its door, lifted by hand before the cartridge comes and closed
## once it is in, turns up and back about its lid's back edge and stands open above the top; its
## tray, carrying the cartridge, stands tilted up about its back to take it and is pressed down level
## once it is in; its power button stays pushed in while it is on, its diode lit; its reset button
## goes in when pressed.

## How bright the diode once lit.
const _LIT := 2.0

## How far the door is open, in degrees.
var door_degrees := 0.0:
	set(value):
		# Each is given each frame by the launch animation: moved only when it changes.
		if value != door_degrees and is_node_ready():
			_door.transform = (shape as NesShape).door(value)
		door_degrees = value
## How far the tray is tilted up, in degrees.
var tray_degrees := 0.0:
	set(value):
		if value != tray_degrees and is_node_ready():
			_tray.transform = (shape as NesShape).tray(value)
		tray_degrees = value
## How far the power and reset buttons are pushed in, in millimetres.
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

@onready var _door: Node3D = %Door
@onready var _tray: Node3D = %Tray
@onready var _power: Node3D = %Power
@onready var _reset: Node3D = %Reset


func _ready() -> void:
	_door.transform = (shape as NesShape).door(door_degrees)
	_tray.transform = (shape as NesShape).tray(tray_degrees)
	_power.position.z = -power_mm * MeshBuilder.UNITS_PER_MM
	_reset.position.z = -reset_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"door_degrees", MovingPart.Role.OPENING, 0.0, NesShape.DOOR_OPEN),
		MovingPart.new(&"tray_degrees", MovingPart.Role.OPENING, 0.0, (shape as NesShape).tray_tilt),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as NesShape).button_travel(NesShape.POWER_IN)),
		MovingPart.new(&"reset_mm", MovingPart.Role.POSE, 0.0, (shape as NesShape).button_travel(NesShape.RESET_IN)),
		MovingPart.new(&"light_energy", MovingPart.Role.LIGHT, 0.0, _LIT),
	]


func seat() -> Transform3D:
	return (shape as NesShape).seat(tray_degrees)


## A cartridge slides in through the open door, label up, its connector first: along its top edge,
## which lies along the tray towards the front.
func approach() -> Vector3:
	return Vector3.UP
