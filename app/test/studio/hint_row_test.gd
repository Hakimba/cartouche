# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const ProjectFiles := preload("res://test/studio/project_files.gd")


## The scenes' hints, read from their files. The hints made in code are the search's, added to its row
## (`GameSearch._hints`, typed `HintRow`), so none can stand outside one.
func test_every_button_hint_of_the_app_stands_in_a_hint_row() -> void:
	var hint_script := preload("res://screens/button_hint.gd")
	var row_scene := preload("res://studio/hint_row.tscn")
	var found := 0
	for path in ProjectFiles.under("res://", ["tscn"], ["addons", ".godot", "android", "test", "dev"]):
		var state := (load(path) as PackedScene).get_state()
		var by_path: Dictionary[NodePath, int] = {}
		for node in state.get_node_count():
			by_path[state.get_node_path(node)] = node
		for node in state.get_node_count():
			if _property(state, node, &"script") != hint_script:
				continue
			found += 1
			var parent := by_path[state.get_node_path(node, true)]
			assert_object(state.get_node_instance(parent)).override_failure_message("%s %s" % [path, state.get_node_path(node)]) \
				.is_equal(row_scene)
	assert_int(found).is_greater(20)


func _property(state: SceneState, node: int, named: StringName) -> Variant:
	for i in state.get_node_property_count(node):
		if state.get_node_property_name(node, i) == named:
			return state.get_node_property_value(node, i)
	return null
