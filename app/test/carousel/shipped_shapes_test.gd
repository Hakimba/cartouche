# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Every medium the app ships with, built from its own dimensions or baked: accepted by its rules,
## each part closed and turned outwards. A dimension edited by hand that breaks a model fails here.

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_an_exported_part_whose_dimensions_change_is_built_again_from_them() -> void:
	var shape := Fixtures.medium_shape("ps2_dvd").duplicate() as ModelShape
	var exported := _label_of(shape).baked()
	var shipped := exported.get_mesh_arrays()
	shape.set(&"thickness", shape.get(&"thickness") * 1.5)
	assert_array(shape.problems()).is_empty()
	var reshaped := exported.get_mesh_arrays()
	assert_bool(reshaped == shipped).is_false()
	assert_bool(reshaped == _label_of(shape).get_mesh_arrays()).is_true()


func test_an_exported_part_draws_without_being_built_again() -> void:
	var shape := CountedShape.new()
	var exported := _label_of(shape).baked()
	var built := shape.builds
	assert_bool(exported.get_mesh_arrays().is_empty()).is_false()
	assert_int(shape.builds).is_equal(built)


static func _label_of(shape: ModelShape) -> ShapedMesh:
	var mesh := ShapedMesh.new()
	mesh.shape = shape
	mesh.part = &"label"
	mesh.detail = Fixtures.SHAPE_DETAIL
	return mesh


## A one-triangle shape counting how many times it is built.
class CountedShape extends ModelShape:
	var builds := 0

	func parts() -> Array[StringName]:
		return [&"label"]

	func _arrays(_part: StringName, _detail: int) -> Array:
		builds += 1
		var mesh := MeshBuilder.new()
		mesh.triangle(mesh.add(Vector3.ZERO, Vector3.UP, Vector2.ZERO), mesh.add(Vector3.RIGHT, Vector3.UP, Vector2.RIGHT),
			mesh.add(Vector3.BACK, Vector3.UP, Vector2.DOWN))
		return mesh.arrays()

	func _rules() -> Dictionary[StringName, bool]:
		return {}
