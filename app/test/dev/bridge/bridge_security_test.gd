# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/dev/bridge/fixtures.gd")
const Commands := preload("res://dev/bridge/commands.gd")
const Packs := preload("res://dev/bridge/packs.gd")
const ExportFilter := preload("res://addons/cartouche_dev/export_filter.gd")

var _commands: Fixtures.CommandHost
var _lights_text: String
var _turntable_text: String
var _media_text: String
## What the user's files held before a test wrote its own, and the files that were not there.
var _kept: Dictionary[String, PackedByteArray] = {}
var _created: Array[String] = []


func before() -> void:
	Packs.use(Fixtures.PACKS)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lights_text = FileAccess.get_file_as_string(StudioLights.FILE)
	_turntable_text = FileAccess.get_file_as_string(Plinth.TURNTABLE_FILE)
	_media_text = FileAccess.get_file_as_string(GamesLayout.FILE)


func before_test() -> void:
	_commands = Fixtures.CommandHost.new()
	add_child(_commands)


func after_test() -> void:
	_commands.free()
	for path: String in _kept:
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_buffer(_kept[path])
		file.close()
	for path in _created:
		DirAccess.remove_absolute(path)
	_kept.clear()
	_created.clear()
	for file_name: String in [Packs.START, Packs.NEXT, Packs.NONE, "start_next.pck.tmp"]:
		DirAccess.remove_absolute(Packs.directory().path_join(file_name))
	var packed := Packs.new().write([Fixtures.file(StudioLights.FILE, _lights_text),
		Fixtures.file(Plinth.TURNTABLE_FILE, _turntable_text), Fixtures.file(GamesLayout.FILE, _media_text)])
	ProjectSettings.load_resource_pack(str(packed["pack"]), true)
	StudioLights.forget()
	ConsoleRow.forget()
	Plinth.forget()
	GamesLayout.forget()


func test_inv_24_the_export_filter_excludes_every_bridge_file_only_in_release() -> void:
	for path: String in ["res://dev/bridge/bridge.gd", "res://dev/bridge/packs.gdc", "res://dev/bridge/sub/file.json"]:
		assert_bool(ExportFilter.excludes(path, false)).is_true()
		assert_bool(ExportFilter.excludes(path, true)).is_false()
	for path: String in ["res://dev/diagnostics.gd", "res://dev/bridge_other.gd", "res://carousel/carousel.tscn"]:
		assert_bool(ExportFilter.excludes(path, false)).is_false()


func test_inv_24_without_the_flag_or_without_debug_no_bridge_is_added() -> void:
	assert_bool(Diagnostics.flag("bridge")).is_false()
	assert_bool(Diagnostics.has_node("Bridge")).is_false()
	var diagnostics: Fixtures.DiagnosticHost = auto_free(Fixtures.DiagnosticHost.new())
	add_child(diagnostics)
	diagnostics.enabled = true
	diagnostics.start_bridge()
	assert_int(diagnostics.get_child_count()).is_equal(0)
	diagnostics.bridge_flag = true
	diagnostics.enabled = false
	diagnostics.start_bridge()
	assert_int(diagnostics.get_child_count()).is_equal(0)
	diagnostics.enabled = true
	diagnostics.start_bridge()
	assert_bool(diagnostics.has_node("Bridge")).is_true()
	diagnostics.start_bridge()
	assert_int(diagnostics.get_child_count()).is_equal(1)


func test_inv_24_reload_restart_and_snapshot_only_write_beneath_the_dev_directory() -> void:
	DirAccess.make_dir_recursive_absolute("user://labels")
	for path: String in ["user://library.json", "user://settings.json", "user://labels/own.png"]:
		if FileAccess.file_exists(path):
			_kept[path] = FileAccess.get_file_as_bytes(path)
		else:
			_created.append(path)
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string("keep " + path)
		file.close()
	var saved_files := _user_files("user://")
	var disk_text := FileAccess.get_file_as_string(StudioLights.FILE)
	var files := [Fixtures.file("res://data/bridge_probe.json", "{\"live\":true}")]
	assert_bool((await _commands.run({"cmd": "reload", "files": files}))["ok"]).is_true()
	assert_bool((await _commands.run({"cmd": "restart", "files": files}))["ok"]).is_true()
	assert_bool((await _commands.run({"cmd": "snapshot"}))["ok"]).is_true()
	assert_dict(_user_files("user://")).is_equal(saved_files)
	assert_str(FileAccess.get_file_as_string(StudioLights.FILE)).is_equal(disk_text)
	assert_bool(FileAccess.file_exists(Packs.directory().path_join(Packs.NEXT))).is_true()
	for path: String in ["user://settings.json", "res://../settings.json", "res://data/../../settings.json", "/tmp/outside"]:
		assert_bool((await _commands.run({"cmd": "reload", "files": [Fixtures.file(path, "broken")]}))["ok"]).is_false()
	assert_dict(_user_files("user://")).is_equal(saved_files)


func _user_files(directory: String) -> Dictionary:
	var files := {}
	for file_name in DirAccess.get_files_at(directory):
		var path := directory.path_join(file_name)
		files[path] = FileAccess.get_sha256(path)
	for file_name in DirAccess.get_directories_at(directory):
		if directory == "user://" and file_name in ["dev", "logs"]: continue
		files.merge(_user_files(directory.path_join(file_name)))
	return files

class ValueProbe extends Node:
	var value := 0.0
	var other := 0.0
