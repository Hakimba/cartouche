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


static func _is_glb(model: Node) -> bool:
	return model.find_children("*", "Node3D", true, false).any(func(node: Node) -> bool:
		return node.scene_file_path.get_extension() == "glb")
