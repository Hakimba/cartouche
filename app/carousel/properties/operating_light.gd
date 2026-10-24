# SPDX-License-Identifier: GPL-3.0-or-later
class_name OperatingLight
extends ColorRect
## The light over a staged model, between the backdrop and the 3D.

var _centre := Vector2.ZERO
var _radius := 0.0
var _darkness := -1.0
var _radii := Vector2.ZERO
var _gel := StudioTokens.NEUTRAL
var _shaped := false

@onready var _material: ShaderMaterial = material


func _ready() -> void:
	look(Vector2.ZERO, 0.0, 0.0)


## Console properties retain their circular operating light.
func look(centre: Vector2, radius: float, darkness: float) -> void:
	if not _shaped and centre == _centre and radius == _radius and darkness == _darkness:
		return
	_shaped = false
	_centre = centre
	_radius = radius
	_darkness = darkness
	visible = darkness > 0.001
	_material.set_shader_parameter(&"shaped", false)
	_material.set_shader_parameter(&"centre", centre)
	_material.set_shader_parameter(&"radius", radius)
	_material.set_shader_parameter(&"darkness", darkness)


func shaped(box: Rect2, gel: Color, opacity: float) -> void:
	var radii := box.size + Vector2(200.0, 260.0)
	var centre := box.get_center()
	if _shaped and centre == _centre and radii == _radii and gel == _gel and opacity == _darkness:
		return
	_shaped = true
	_centre = centre
	_radii = radii
	_gel = gel
	_darkness = opacity
	visible = opacity > 0.001
	_material.set_shader_parameter(&"shaped", true)
	_material.set_shader_parameter(&"centre", centre)
	_material.set_shader_parameter(&"radii", radii)
	_material.set_shader_parameter(&"pool_color", _pool_color(gel))
	_material.set_shader_parameter(&"darkness", opacity)


static func _pool_color(gel: Color) -> Color:
	var alpha := 0.46 * 0.86 + 0.14
	var dark := Color(46.0 / 255.0, 33.0 / 255.0, 22.0 / 255.0)
	var lab := StudioMaterial.oklab(dark).lerp(StudioMaterial.oklab(gel), 0.14 / alpha)
	var mixed := StudioMaterial.srgb(lab)
	return Color(mixed, alpha)
