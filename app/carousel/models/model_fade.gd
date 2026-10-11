# SPDX-License-Identifier: GPL-3.0-or-later
class_name ModelFade
extends RefCounted
## Fades a model on every renderer. Godot's per-instance transparency does not show on the mobile
## renderer, the one handhelds use, so the model's materials fade themselves. A transparent
## material costs more and is sorted by object, so a model draws with its own opaque materials
## whenever it is not faded, and with transparent copies of them while it is, their depth still
## written so that a faded model hides what is behind it. The copies of our shaders take the amount
## as their `fade` instance uniform; standard materials, as their albedo's alpha.

## The fading variant of each of our opaque shaders.
const FADING: Dictionary[Shader, Shader] = {
	preload("res://carousel/models/label.gdshader"): preload("res://carousel/models/label_fading.gdshader"),
	preload("res://carousel/models/disc_mirror.gdshader"): preload("res://carousel/models/disc_mirror_fading.gdshader"),
	preload("res://carousel/models/solid.gdshader"): preload("res://carousel/models/solid_fading.gdshader"),
}

## How faded the model is, from 0 (opaque) to 1 (gone, and not drawn at all).
var amount := 0.0

var _surfaces: Array[Surface] = []
var _copies: Dictionary[Material, Material] = {}


## Makes a fading copy of each material of [param model], one per material however many surfaces
## share it.
func _init(model: Node3D) -> void:
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not geometry.mesh:
			continue
		for index in geometry.mesh.get_surface_count():
			var own := geometry.get_active_material(index)
			if not own:
				continue
			if own not in _copies:
				_copies[own] = _fading(own)
			_surfaces.append(Surface.new(geometry, index, own, _copies[own]))


## Fades the model [param to], from 0 (opaque) to 1 (gone).
func apply(to: float) -> void:
	if to == amount:
		return
	amount = to
	for material: Material in _copies.values():
		if material is BaseMaterial3D:
			var standard: BaseMaterial3D = material
			standard.albedo_color.a = 1.0 - to
	for surface in _surfaces:
		surface.show(to)


## Sets the shader [param parameter] to [param value] on each material [param geometry] is drawn
## with, its own and its fading copy.
func set_shader_value(geometry: MeshInstance3D, parameter: StringName, value: Variant) -> void:
	for surface in _surfaces:
		if surface.geometry == geometry:
			for material: ShaderMaterial in [surface.own, surface.fading]:
				material.set_shader_parameter(parameter, value)


static func _fading(material: Material) -> Material:
	if material is BaseMaterial3D:
		var standard: BaseMaterial3D = material.duplicate()
		standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		standard.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
		return standard
	if material is ShaderMaterial:
		var shaded: ShaderMaterial = material
		if shaded.shader in FADING:
			var fading: ShaderMaterial = shaded.duplicate()
			fading.shader = FADING[shaded.shader]
			return fading
	# Transparent already, fading itself by its `fade` instance uniform: clear plastic.
	return material


## One surface of the model, drawn with its own material or its fading copy.
class Surface:
	var geometry: MeshInstance3D
	var index: int
	var own: Material
	var fading: Material
	## The material drawn now: set again only when it changes, as setting it rebuilds how the
	## surface is drawn.
	var _drawn: Material

	func _init(drawn: MeshInstance3D, surface: int, material: Material, copy: Material) -> void:
		geometry = drawn
		index = surface
		own = material
		fading = copy

	func show(amount: float) -> void:
		var drawn := fading if amount > 0.0 else own
		if drawn != _drawn:
			_drawn = drawn
			geometry.set_surface_override_material(index, drawn)
		geometry.visible = amount < 0.999
		if fading is ShaderMaterial:
			geometry.set_instance_shader_parameter(&"fade", amount)
