# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Every console and medium the app ships with, built from its own dimensions: accepted by its rules,
## each part closed and turned outwards. A dimension edited by hand that breaks a model fails here.

const Fixtures := preload("res://test/carousel/fixtures.gd")
## The detail every part is built at.
const DETAIL := 32


func test_every_shipped_console_is_accepted_and_built_closed_part_by_part() -> void:
	var checked := 0
	for manifest in ConsoleManifest.found():
		var console: ConsoleModel = auto_free(Fixtures.new_console(manifest.scene))
		if _is_glb(console):
			continue
		checked += 1
		var shape := console.shape
		assert_array(shape.problems()).override_failure_message("%s refused: %s" % [manifest.platform,
			shape.problems()]).is_empty()
		for part in shape.parts():
			var meshes: Array[Array] = [shape.mesh_arrays(part, DETAIL)]
			_assert_whole("%s %s" % [manifest.platform, part], meshes, part not in shape.surfaces())
	assert_int(checked).is_greater(0)


func test_every_shipped_medium_is_accepted_and_built_closed_with_its_label_on_it() -> void:
	var media := MediumManifest.found()
	assert_int(media.size()).is_greater(0)
	for medium: String in media:
		var shape := Fixtures.medium_shape(medium)
		assert_array(shape.parts()).contains([&"label"])
		assert_array(shape.problems()).override_failure_message("%s refused: %s" % [medium,
			shape.problems()]).is_empty()
		var meshes: Array[Array] = []
		for part in shape.parts():
			meshes.append(shape.mesh_arrays(part, DETAIL))
		_assert_whole(medium, meshes, true)


func test_every_shipped_part_exported_already_built_draws_the_arrays_its_code_builds() -> void:
	var scenes: Array[String] = []
	for manifest in ConsoleManifest.found():
		scenes.append(manifest.scene)
	for medium: String in MediumManifest.found():
		scenes.append(MediumManifest.found()[medium].scene)
	var stored := "user://exported_part.res"
	var checked := 0
	for scene in scenes:
		var model: Node3D = auto_free((load(scene) as PackedScene).instantiate())
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var mesh := part.mesh as ShapedMesh
			if not mesh:
				continue
			checked += 1
			assert_int(ResourceSaver.save(mesh.baked(), stored)).is_equal(OK)
			var exported: ShapedMesh = ResourceLoader.load(stored, "", ResourceLoader.CACHE_MODE_IGNORE)
			assert_bool(exported.built.is_empty()).override_failure_message("%s %s exported unbuilt" % [scene,
				mesh.part]).is_false()
			assert_bool(exported.get_mesh_arrays() == mesh.get_mesh_arrays()).override_failure_message(
				"%s %s exported differs from its code" % [scene, mesh.part]).is_true()
	DirAccess.remove_absolute(stored)
	assert_int(checked).is_greater(100)


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


## Asserts that [param meshes] hold faces and, when [param solid], that they close round a volume
## turned outwards.
func _assert_whole(what: String, meshes: Array[Array], solid: bool) -> void:
	for arrays in meshes:
		assert_array(arrays).override_failure_message("%s built nothing" % what).is_not_empty()
		if arrays.is_empty():
			return
	if not solid:
		return
	assert_array(Fixtures.open_edges(meshes)).override_failure_message("%s is open" % what).is_empty()
	for volume in Fixtures.volumes(meshes):
		assert_float(volume).override_failure_message("%s turned inwards" % what).is_greater(0.0)


static func _label_of(shape: ModelShape) -> ShapedMesh:
	var mesh := ShapedMesh.new()
	mesh.shape = shape
	mesh.part = &"label"
	mesh.detail = DETAIL
	return mesh


static func _is_glb(model: Node) -> bool:
	return model.find_children("*", "Node3D", true, false).any(func(node: Node) -> bool:
		return node.scene_file_path.get_extension() == "glb")


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
