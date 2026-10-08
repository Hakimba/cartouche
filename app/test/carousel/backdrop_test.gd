# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const BACKDROP := preload("res://carousel/background.gdshader")


func test_the_dots_drift_a_tile_a_period_at_full_pace_slower_at_less_and_not_at_all_still() -> void:
	var dots := ShaderMaterial.new()
	dots.shader = BACKDROP
	var backdrop: Backdrop = auto_free(Backdrop.new())
	backdrop.material = dots
	add_child(backdrop)
	backdrop._process(backdrop.period_s / 10.0)
	assert_float(dots.get_shader_parameter(&"drift")).is_equal_approx(0.1, 1e-6)
	backdrop.pace = 0.5
	backdrop._process(backdrop.period_s / 10.0)
	assert_float(dots.get_shader_parameter(&"drift")).is_equal_approx(0.15, 1e-6)
	# Past a whole tile, the dots are where they started: no jump.
	backdrop.pace = 1.0
	backdrop._process(backdrop.period_s * 0.9)
	assert_float(dots.get_shader_parameter(&"drift")).is_equal_approx(0.05, 1e-6)
	backdrop.pace = 0.0
	assert_bool(backdrop.is_processing()).is_false()
	backdrop.pace = 1.0
	assert_bool(backdrop.is_processing()).is_true()


func test_no_shader_moves_with_the_engine_s_time_the_dots_move_with_their_drift() -> void:
	# A shader reading TIME is drawn again every frame, the app at rest or not.
	var uniforms := BACKDROP.get_shader_uniform_list().map(func(uniform: Dictionary) -> String: return uniform["name"])
	assert_array(uniforms).contains(["drift"])
	var shaders := _files("res://", ["gdshader", "gdshaderinc"])
	assert_array(shaders).is_not_empty()
	for path in shaders:
		var code := FileAccess.get_file_as_string(path)
		assert_bool(RegEx.create_from_string("\\bTIME\\b").search(code) == null).override_failure_message(path + " reads TIME").is_true()


## The files under [param folder] with one of [param extensions], add-ons left out.
func _files(folder: String, extensions: Array[String]) -> Array[String]:
	var found: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in extensions:
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		if sub not in ["addons", ".godot", "android"]:
			found.append_array(_files(folder.path_join(sub), extensions))
	return found
