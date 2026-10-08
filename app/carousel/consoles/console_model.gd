# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleModel
extends Node3D
## A console as the consoles screen shows it and a game goes into it, built from its
## [member shape]: the lid turns about its hinge, and the drive's [Spindle] sits in the well, where
## a seated disc's centre is the spindle's origin.

@export var shape: ConsoleShape

## How far the lid is open, in degrees.
var lid_degrees := 0.0:
	set(value):
		# Given each frame by the consoles' row: the lid is moved only when it turns.
		if value != lid_degrees and is_node_ready():
			_lid.rotation.x = -deg_to_rad(value)
		lid_degrees = value

var _fade: ModelFade

@onready var spindle: Spindle = %Spindle
@onready var _lid: Node3D = %Lid


func _ready() -> void:
	_lid.position = shape.hinge()
	spindle.transform = shape.seat()
	_fade = ModelFade.new(self)
	_lid.rotation.x = -deg_to_rad(lid_degrees)


## Where a seated disc's centre is, in the world, its axis (Z) pointing up out of the well.
func seat() -> Transform3D:
	return spindle.global_transform


## Fades the console [param amount], from 0 (opaque) to 1 (gone).
func fade(amount: float) -> void:
	_fade.apply(amount)
