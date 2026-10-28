# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/dev/bridge/fixtures.gd")


func after_test() -> void:
	Fixtures.remove_tree("user://dev/process-snapshot")


func test_the_real_main_scene_reloads_and_replays_its_route_back_to_the_same_game() -> void:
	var output: Array = []
	var exit_code := OS.execute("timeout", PackedStringArray(["45s", OS.get_executable_path(), "--headless",
		"--path", ProjectSettings.globalize_path("res://"), "res://test/dev/bridge/process_probe.tscn",
		"--", "--welcome=skip"]), output, true)
	assert_int(exit_code).override_failure_message(str(output)).is_equal(0)
	var text := "\n".join(output)
	assert_str(text).contains("scene probe")
	assert_str(text).not_contains("SCRIPT ERROR")
	assert_str(text).contains('"matching":true')


func test_the_snapshot_argument_loads_before_the_desktop_main_scene() -> void:
	var folder := "user://dev/process-snapshot"
	DirAccess.make_dir_recursive_absolute(folder)
	var snapshot := {"library": {"ok": true, "library": '{"games":[]}',
		"art": '[{"game_id":"ps2/A","path":"/device/files/art/a.png"}]'},
		"settings": {"ok": true, "button_style": "nintendo"}, "variants": {"ps2": "ps2_fat"}}
	var file := FileAccess.open(folder.path_join("snapshot.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	var output: Array = []
	var directory := ProjectSettings.globalize_path(folder)
	var exit_code := OS.execute("timeout", PackedStringArray(["30s", OS.get_executable_path(), "--headless",
		"--path", ProjectSettings.globalize_path("res://"), "res://test/dev/bridge/process_probe.tscn",
		"--", "--snapshot=" + directory]), output, true)
	assert_int(exit_code).override_failure_message(str(output)).is_equal(0)
	var text := "\n".join(output)
	assert_str(text).contains('"style":"nintendo"')
	assert_str(text).contains('"ps2":"ps2_fat"')
	assert_str(text).contains(directory.path_join("files/art/a.png"))
	assert_str(text).not_contains("SCRIPT ERROR")
