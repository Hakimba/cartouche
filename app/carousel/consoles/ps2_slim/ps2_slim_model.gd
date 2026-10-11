# SPDX-License-Identifier: GPL-3.0-or-later
class_name Ps2SlimModel
extends ConsoleModel
## The PS2 slim, built from its [Ps2SlimShape]: the lid turns about its hinge, and the drive's
## [Spindle] sits in the well, where a seated disc's centre is the spindle's origin.

## The lid fully open, in degrees.
const _OPEN_DEGREES := 88.0

## How far the lid is open, in degrees.
var lid_degrees := 0.0:
	set(value):
		# Given each frame by the launch animation: the lid is moved only when it turns.
		if value != lid_degrees and is_node_ready():
			_lid.rotation.x = -deg_to_rad(value)
		lid_degrees = value

@onready var _spindle: Spindle = %Spindle
@onready var _lid: Node3D = %Lid


func _ready() -> void:
	_lid.position = (shape as Ps2SlimShape).hinge()
	_spindle.transform = (shape as Ps2SlimShape).seat()
	_lid.rotation.x = -deg_to_rad(lid_degrees)


func moving_parts() -> Array[MovingPart]:
	return [MovingPart.new(&"lid_degrees", MovingPart.Role.OPENING, 0.0, _OPEN_DEGREES)]


func seat() -> Transform3D:
	return (shape as Ps2SlimShape).seat()


func hold(angle: float) -> void:
	_spindle.turn(angle)
