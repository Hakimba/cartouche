# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The bridge reads private members of the app's classes (see ONBOARDING, "The dev bridge"): a rename that
## leaves one behind must fail here, at the parse of the script that reads it.


func test_every_bridge_script_compiles_against_the_classes_it_reads() -> void:
	var paths := _scripts("res://dev/bridge")
	assert_array(paths).contains(["res://dev/bridge/commands.gd", "res://dev/bridge/views.gd", "res://dev/bridge/launch_view.gd"])
	for path in paths:
		var script := load(path) as GDScript
		assert_bool(script != null and script.can_instantiate()).override_failure_message("%s does not compile" % path).is_true()


func _scripts(folder: String) -> Array[String]:
	var found: Array[String] = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(".gd"):
			found.append(folder.path_join(file_name))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found
