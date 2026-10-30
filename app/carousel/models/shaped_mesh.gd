# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name ShapedMesh
extends PrimitiveMesh
## One part of a model built from its dimensions (a [ModelShape]); it is rebuilt when they change,
## in the editor too. An exported app finds the part already built ([method baked]): the same arrays,
## without the GDScript building them at start.

@export var shape: ModelShape:
	set(value):
		if shape:
			shape.changed.disconnect(_reshape)
		shape = value
		if shape:
			shape.changed.connect(_reshape)
		_reshape()
## Which part of the shape, such as `label`.
@export var part: StringName:
	set(value):
		part = value
		_reshape()
## Steps around the curves: more is smoother and costs more vertices.
@export_range(8, 512) var detail := 128:
	set(value):
		detail = value
		_reshape()
## The arrays [member shape] built for [member part] when the app was exported, until drawn; empty, they are
## built here. Any change of what they are built from forgets them.
@export_storage var built: Array = []


## This part with its arrays built now, as the export stores it.
func baked() -> ShapedMesh:
	var copy: ShapedMesh = duplicate()
	copy.built = _create_mesh_array()
	return copy


func _create_mesh_array() -> Array:
	if not built.is_empty():
		var drawn := built
		# Let go once drawn, the renderer holding its copy; not while exporting, which draws before it stores.
		if not Engine.is_editor_hint():
			built = []
		return drawn
	if not shape:
		push_error("ShapedMesh: no shape")
		return []
	if part not in shape.parts():
		push_error("ShapedMesh: no part %s in %s" % [part, shape.parts()])
		return []
	var arrays := shape.mesh_arrays(part, detail)
	if arrays.is_empty():
		push_error("ShapedMesh: %s cannot be built, rules broken: %s" % [part, shape.problems()])
	return arrays


func _reshape() -> void:
	built = []
	request_update()
