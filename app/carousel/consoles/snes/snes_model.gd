# SPDX-License-Identifier: GPL-3.0-or-later
class_name SnesModel
extends ConsoleModel
## The PAL Super Nintendo, built from its [SnesShape]: a cartridge goes down the slot, pushing its
## two flaps down about their hinges; the eject lever turns about its back edge, the power knob
## slides back, the reset button goes down. Each part is moved only when its value changes: the
## launch animation gives them every frame.

## How far the flaps are turned down from closed, in degrees.
var flaps_degrees := 0.0:
	set(value):
		if value != flaps_degrees and is_node_ready():
			_place_flaps(value)
		flaps_degrees = value
## How far the eject lever is pressed, in degrees.
var eject_degrees := 0.0:
	set(value):
		if value != eject_degrees and is_node_ready():
			_eject.rotation.x = deg_to_rad(value)
		eject_degrees = value
## How far the power knob is slid back, towards on, in millimetres.
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_knob.position.z = -value * MeshBuilder.UNITS_PER_MM
		power_mm = value
## How far the reset button is pressed, in millimetres.
var reset_mm := 0.0:
	set(value):
		if value != reset_mm and is_node_ready():
			_reset.position.y = -value * MeshBuilder.UNITS_PER_MM
		reset_mm = value

@onready var _back_flap: Node3D = %BackFlap
@onready var _front_flap: Node3D = %FrontFlap
@onready var _eject: Node3D = %Eject
@onready var _knob: Node3D = %Knob
@onready var _reset: Node3D = %Reset


func _ready() -> void:
	var hinges := (shape as SnesShape).hinges()
	_back_flap.position = hinges[0]
	_front_flap.position = hinges[1]
	_eject.position = (shape as SnesShape).eject_pivot()
	_place_flaps(flaps_degrees)
	_eject.rotation.x = deg_to_rad(eject_degrees)
	_knob.position.z = -power_mm * MeshBuilder.UNITS_PER_MM
	_reset.position.y = -reset_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"flaps_degrees", MovingPart.Role.FLAP, 0.0, (shape as SnesShape).flap_swing()),
		MovingPart.new(&"eject_degrees", MovingPart.Role.POSE, 0.0, (shape as SnesShape).eject_press()),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as SnesShape).power_travel),
		MovingPart.new(&"reset_mm", MovingPart.Role.POSE, 0.0, (shape as SnesShape).reset_travel()),
	]


func seat() -> Transform3D:
	return (shape as SnesShape).seat()


func approach() -> Vector3:
	return Vector3.UP


## Both flaps lean down towards the middle of the slot, the front one turned to face the back one.
func _place_flaps(degrees: float) -> void:
	var down := deg_to_rad((shape as SnesShape).flap_tilt + degrees)
	_back_flap.rotation = Vector3(down, 0.0, 0.0)
	_front_flap.rotation = Vector3(down, PI, 0.0)
