# SPDX-License-Identifier: GPL-3.0-or-later
class_name Backdrop
extends ColorRect
## The app's backdrop (`background.gdshader`): big pale dots drifting diagonally, one tile every
## [member period_s] at full [member pace].

@export var period_s := 14.0

## How fast the dots drift, from 1 down to 0, still ([Resting]).
var pace := 1.0:
	set(value):
		pace = value
		set_process(pace > 0.0)

## How far the dots have drifted, in tiles, from 0 to 1.
var _drift := 0.0

@onready var _dots: ShaderMaterial = material


func _ready() -> void:
	add_to_group(Resting.PACED)


func _process(delta: float) -> void:
	_drift = fmod(_drift + delta * pace / period_s, 1.0)
	_dots.set_shader_parameter(&"drift", _drift)
