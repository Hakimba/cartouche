# SPDX-License-Identifier: GPL-3.0-or-later
class_name Spindle
extends Node3D
## A disc drive's spindle, as a disc is put on it: the motor, and the turntable, hub and balls it
## turns. Its axis is its z; a seated disc's centre is its origin.

var _parts: Array[GeometryInstance3D] = []

@onready var _rotor: Node3D = $Rotor


func _ready() -> void:
	_parts.assign(find_children("*", "GeometryInstance3D", true, false))


## Turns what the motor drives [param angle] radians about the axis.
func turn(angle: float) -> void:
	_rotor.basis = Basis(Vector3.BACK, angle)


## Sets how transparent the spindle is, from 0 (opaque) to 1 (gone).
func fade(amount: float) -> void:
	for part in _parts:
		part.transparency = amount
