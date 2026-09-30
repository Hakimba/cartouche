# SPDX-License-Identifier: GPL-3.0-or-later
class_name Spindle
extends Node3D
## A disc drive's spindle, as a disc is put on it: the motor, and the turntable, hub and balls it
## turns. Its axis is its z; a seated disc's centre is its origin.

var _fade: ModelFade

@onready var _rotor: Node3D = $Rotor


## Turns what the motor drives [param angle] radians about the axis.
func turn(angle: float) -> void:
	_rotor.basis = Basis(Vector3.BACK, angle)


## Fades the spindle [param amount], from 0 (opaque) to 1 (gone). Its materials are copied for it
## only once it fades: a spindle inside a console fades with it.
func fade(amount: float) -> void:
	if not _fade:
		_fade = ModelFade.new(self)
	_fade.apply(amount)
