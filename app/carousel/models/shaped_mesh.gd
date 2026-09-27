# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name ShapedMesh
extends PrimitiveMesh
## One part of a model built from its dimensions (a [ModelShape]); it is rebuilt when they change,
## in the editor too.

@export var shape: ModelShape:
	set(value):
		if shape:
			shape.changed.disconnect(request_update)
		shape = value
		if shape:
			shape.changed.connect(request_update)
		request_update()
## Which part of the shape, such as `label`.
@export var part: StringName:
	set(value):
		part = value
		request_update()
## Steps around the curves: more is smoother and costs more vertices.
@export_range(8, 512) var detail := 128:
	set(value):
		detail = value
		request_update()


func _create_mesh_array() -> Array:
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
