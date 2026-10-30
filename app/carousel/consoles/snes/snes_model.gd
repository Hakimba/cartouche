# SPDX-License-Identifier: GPL-3.0-or-later
class_name SnesModel
extends ConsoleModel
## The PAL Super Nintendo, drawn from its glb (`snes.glb`) and read by its [SnesShape]: a cartridge goes
## down the slot, pushing its two flaps, flat at rest, down about their hinges; the eject lever turns about
## its back edge, the power knob slides back, the reset button goes down. Each part turns or slides from the
## rest the glb gives its node.

var flaps_degrees := 0.0:
	set(value):
		if value != flaps_degrees and is_node_ready():
			_place_flaps(value)
		flaps_degrees = value
var eject_degrees := 0.0:
	set(value):
		if value != eject_degrees and is_node_ready():
			_eject.rotation.x = deg_to_rad(value)
		eject_degrees = value
var power_mm := 0.0:
	set(value):
		if value != power_mm and is_node_ready():
			_knob.position.z = _knob_off - value * MeshBuilder.UNITS_PER_MM
		power_mm = value
var reset_mm := 0.0:
	set(value):
		if value != reset_mm and is_node_ready():
			_reset.position.y = _reset_up - value * MeshBuilder.UNITS_PER_MM
		reset_mm = value

@onready var _back_flap: Node3D = $Model/snes/back_flap
@onready var _front_flap: Node3D = $Model/snes/front_flap
@onready var _eject: Node3D = $Model/snes/eject
@onready var _knob: Node3D = $Model/snes/knob
@onready var _reset: Node3D = $Model/snes/reset
@onready var _knob_off := _knob.position.z
@onready var _reset_up := _reset.position.y


func _ready() -> void:
	Diagnostics.trace("console", "model=snes glb")
	_place_flaps(flaps_degrees)
	_eject.rotation.x = deg_to_rad(eject_degrees)
	_knob.position.z = _knob_off - power_mm * MeshBuilder.UNITS_PER_MM
	_reset.position.y = _reset_up - reset_mm * MeshBuilder.UNITS_PER_MM


func moving_parts() -> Array[MovingPart]:
	return [
		MovingPart.new(&"flaps_degrees", MovingPart.Role.FLAP, 0.0, SnesShape.FLAPS_HANG),
		MovingPart.new(&"eject_degrees", MovingPart.Role.POSE, 0.0, SnesShape.EJECT_PRESS),
		MovingPart.new(&"power_mm", MovingPart.Role.POWER, 0.0, (shape as SnesShape).power_travel),
		MovingPart.new(&"reset_mm", MovingPart.Role.POSE, 0.0, SnesShape.RESET_PRESS),
	]


func seat() -> Transform3D:
	return (shape as SnesShape).seat()


func approach() -> Vector3:
	return Vector3.UP


func _place_flaps(degrees: float) -> void:
	_back_flap.rotation.x = deg_to_rad(degrees)
	_front_flap.rotation.x = -deg_to_rad(degrees)
