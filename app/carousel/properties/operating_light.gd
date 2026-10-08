# SPDX-License-Identifier: GPL-3.0-or-later
class_name OperatingLight
extends ColorRect
## The light over a staged game (see `operating_light.gdshader`), between the backdrop and the 3D.

## What the light was last given: given each frame, it is sent to the GPU only when it changes.
var _centre := Vector2.ZERO
var _radius := 0.0
var _darkness := -1.0

@onready var _material: ShaderMaterial = material


func _ready() -> void:
	look(Vector2.ZERO, 0.0, 0.0)


## The light on [param centre] (in the 1280×960 design), its pool [param radius] wide, the room
## [param darkness] dark, from 0 (nothing drawn) to 1.
func look(centre: Vector2, radius: float, darkness: float) -> void:
	if centre == _centre and radius == _radius and darkness == _darkness:
		return
	_centre = centre
	_radius = radius
	_darkness = darkness
	visible = darkness > 0.001
	_material.set_shader_parameter(&"centre", centre)
	_material.set_shader_parameter(&"radius", radius)
	_material.set_shader_parameter(&"darkness", darkness)
