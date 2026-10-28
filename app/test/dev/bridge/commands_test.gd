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


func test_INV_EX_01_the_export_filter_excludes_every_bridge_file_only_in_release() -> void:
	for path: String in ["res://dev/bridge/bridge.gd", "res://dev/bridge/packs.gdc", "res://dev/bridge/sub/file.json"]:
		assert_bool(ExportFilter.excludes(path, false)).is_true()
		assert_bool(ExportFilter.excludes(path, true)).is_false()
	for path: String in ["res://dev/diagnostics.gd", "res://dev/bridge_other.gd", "res://carousel/carousel.tscn"]:
		assert_bool(ExportFilter.excludes(path, false)).is_false()


func test_INV_EX_02_without_the_flag_or_without_debug_no_bridge_is_added() -> void:
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


func test_the_start_pack_replaces_a_resource_JSON_before_the_bridge_starts() -> void:
	var replacement := "{\"value\":\"from start pack\"}"
	var result := Packs.new().write([Fixtures.file("res://test/dev/bridge/probe.json", replacement)], true)
	assert_bool(result["ok"]).is_true()
	assert_bool(FileAccess.file_exists(Packs.directory().path_join(Packs.START))).is_false()
	var diagnostics: Fixtures.DiagnosticHost = auto_free(Fixtures.DiagnosticHost.new())
	diagnostics.enabled = true
	diagnostics.bridge_flag = true
	add_child(diagnostics)
	diagnostics.start_bridge()
	assert_str(FileAccess.get_file_as_string("res://test/dev/bridge/probe.json")).is_equal(replacement)
	var restored := Packs.new().write([Fixtures.file("res://test/dev/bridge/probe.json", "{\"value\":\"original\"}\n")])
	ProjectSettings.load_resource_pack(str(restored["pack"]), true)


func test_state_answers_the_route_focus_and_playback_state_with_the_request_id() -> void:
	_commands.route = [{"press": "ui_accept", "wait": 2}]
	var answer := await _commands.run({"id": "a", "cmd": "state"})
	assert_str(answer["id"]).is_equal("a")
	assert_str(answer["cmd"]).is_equal("state")
	assert_bool(answer["ok"]).is_true()
	assert_array(answer["route"]).is_equal(_commands.route)
	assert_bool(answer["paused"]).is_false()
	for field: String in ["screen", "focus", "console", "game", "fps", "frame_ms", "rig"]:
		assert_bool(answer.has(field)).is_true()


func test_a_shot_asked_without_the_model_is_taken_with_it_hidden_and_shows_it_again_after() -> void:
	var host: Fixtures.SeeingHost = auto_free(Fixtures.SeeingHost.new())
	add_child(host)
	host.host = Fixtures.ProbeScene.new()
	host.add_child(host.host)
	await host.run({"cmd": "shot", "format": "png"})
	var hidden := await host.run({"cmd": "shot", "format": "png", "hide": "model"})
	assert_bool(hidden["ok"]).is_true()
	assert_array(host.seen).is_equal([true, false])
	assert_bool((host.host as Fixtures.ProbeScene).row.selected().model.visible).is_true()


func test_shot_encodes_a_picture_as_PNG_or_JPEG_with_its_exact_size() -> void:
	for format: String in ["png", "jpg"]:
		var answer := await _commands.run({"id": 7, "cmd": "shot", "format": format, "quality": 0.7})
		assert_bool(answer["ok"]).is_true()
		assert_int(answer["w"]).is_equal(8)
		assert_int(answer["h"]).is_equal(6)
		var bytes: PackedByteArray = answer["_bytes"]
		assert_int(answer["size"]).is_equal(bytes.size())
		var image := Image.new()
		var error := image.load_png_from_buffer(bytes) if format == "png" else image.load_jpg_from_buffer(bytes)
		assert_int(error).is_equal(OK)
		assert_vector(image.get_size()).is_equal(Vector2i(8, 6))
	assert_bool((await _commands.run({"cmd": "shot", "format": "webp"}))["ok"]).is_false()


func test_a_route_starts_fresh_and_replays_press_push_release_and_wait_steps() -> void:
	var route := [{"press": "ui_accept", "wait": 1}, {"push": "ui_left", "wait": 2},
		{"release": "ui_left", "wait": 1}, {"shot": "ignored", "wait": 1}]
	assert_bool((await _commands.run({"cmd": "go", "route": route}))["ok"]).is_true()
	var scene := _commands.host as Fixtures.ProbeScene
	assert_int(scene.presses).is_equal(1)
	assert_bool(Input.is_action_pressed(&"ui_left")).is_false()
	assert_int(_commands.reloads).is_equal(1)
	assert_array(_commands.route).is_equal(route)
	assert_bool((await _commands.run({"cmd": "go", "route": route}))["ok"]).is_true()
	assert_int((_commands.host as Fixtures.ProbeScene).presses).is_equal(1)
	assert_int(_commands.reloads).is_equal(2)


func test_a_held_route_leaves_the_app_paused_on_the_first_frame_of_its_last_press() -> void:
	var route := [{"press": "ui_accept", "wait": 0, "hold": true}]
	assert_bool((await _commands.run({"cmd": "go", "route": route}))["ok"]).is_true()
	var scene := _commands.host as Fixtures.ProbeScene
	assert_int(scene.presses).is_equal(1)
	assert_bool(_commands.paused).is_true()
	var held := scene.seconds
	await get_tree().process_frame
	assert_float(scene.seconds).is_equal(held)
	await _commands.run({"cmd": "resume"})
	assert_bool(_commands.paused).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool((await _commands.run({"cmd": "go", "route": [{"press": "ui_accept", "hold": "yes"}]}))["ok"]).is_false()


func test_reload_forgets_both_light_caches_and_the_plinth_pictures_then_replays_the_route() -> void:
	var original := StudioLights.rig_of("nes", &"consoles").sources[0].energy
	assert_bool(ConsoleRow.has_rig("nes")).is_true()
	var picture := ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
	Plinth._stills[Plinth._key("nes")] = picture
	var data: Dictionary = JSON.parse_string(_lights_text)
	var lights: Dictionary = data["lights"]
	var nes: Dictionary = lights["nes"]
	var consoles: Dictionary = nes["consoles"]
	var sources: Array = consoles["sources"]
	var source: Dictionary = sources[0]
	source["energy"] = original + 2.0
	_commands.route = [{"press": "ui_accept", "wait": 2}]
	var result := await _commands.run({"cmd": "reload", "files": [Fixtures.file(StudioLights.FILE, JSON.stringify(data))]})
	assert_bool(result["ok"]).is_true()
	var row := (_commands.host as Fixtures.ProbeScene).row
	assert_float(row.lights().lights()[0].light_energy).is_equal_approx(original + 2.0, 1e-5)
	assert_int((_commands.host as Fixtures.ProbeScene).presses).is_equal(1)
	assert_object(Plinth.still_of("nes")).is_null()
	assert_bool(result.has("ms")).is_true()
	# An empty set is a cached result too.
	lights.erase("nes")
	result = await _commands.run({"cmd": "reload", "files": [Fixtures.file(StudioLights.FILE, JSON.stringify(data))]})
	assert_bool(result["ok"]).is_true()
	assert_bool(ConsoleRow.has_rig("nes")).is_false()


func test_a_reload_of_a_value_the_tool_already_tuned_loads_it_without_pressing_the_route_again() -> void:
	var original := StudioLights.rig_of("nes", &"consoles").sources[0].energy
	var data: Dictionary = JSON.parse_string(_lights_text)
	var lights: Dictionary = data["lights"]
	var nes: Dictionary = lights["nes"]
	var consoles: Dictionary = nes["consoles"]
	var sources: Array = consoles["sources"]
	var source: Dictionary = sources[0]
	source["energy"] = original + 2.0
	_commands.route = [{"press": "ui_accept", "wait": 2}]
	var host := _commands.host
	var result := await _commands.run({"cmd": "reload", "replay": false, "files": [Fixtures.file(StudioLights.FILE, JSON.stringify(data))]})
	assert_bool(result["ok"]).is_true()
	# The new file is read, and no scene was started again nor any press replayed.
	assert_float(StudioLights.rig_of("nes", &"consoles").sources[0].energy).is_equal_approx(original + 2.0, 1e-5)
	assert_object(_commands.host).is_same(host)


func test_a_light_added_by_the_tool_is_built_where_the_app_stands_without_a_replay() -> void:
	_commands.route = [{"press": "ui_accept", "wait": 2}]
	var data: Dictionary = JSON.parse_string(_lights_text)
	assert_bool((await _commands.run({"cmd": "reload", "files": [Fixtures.file(StudioLights.FILE, JSON.stringify(data))]}))["ok"]).is_true()
	var probe := _commands.host as Fixtures.ProbeScene
	var count := probe.row.lights().lights().size()
	var presses := probe.presses
	var lights: Dictionary = data["lights"]
	var nes: Dictionary = lights["nes"]
	var consoles: Dictionary = nes["consoles"]
	var sources: Array = consoles["sources"]
	var first: Dictionary = sources[0]
	sources.append(first.duplicate(true))
	var result := await _commands.run({"cmd": "reload", "replay": false, "files": [Fixtures.file(StudioLights.FILE, JSON.stringify(data))]})
	assert_bool(result["ok"]).is_true()
	assert_object(_commands.host).is_same(probe)
	assert_int(probe.presses).is_equal(presses)
	assert_int(probe.row.lights().lights().size()).is_equal(count + 1)


func test_reload_turntable_changes_the_start_the_next_scene_reads_and_forgets_its_picture() -> void:
	var original := Plinth.start_of("nes")
	var data: Dictionary = JSON.parse_string(_turntable_text)
	var consoles: Dictionary = data["consoles"]
	var pose: Dictionary = consoles["nes"]
	pose["yaw"] = original.rotation.y + 23.0
	pose["roll"] = original.rotation.z - 11.0
	pose["pitch"] = 7.5
	pose["position"] = [0.1, -0.2, 0.3]
	pose["size"] = 1.25
	var answer := await _commands.run({"cmd": "reload", "files": [Fixtures.file(Plinth.TURNTABLE_FILE, JSON.stringify(data))]})
	assert_bool(answer["ok"]).is_true()
	var start := (_commands.host as Fixtures.ProbeScene).start
	assert_vector(start.rotation).is_equal_approx(Vector3(7.5, original.rotation.y + 23, original.rotation.z - 11), Vector3.ONE * 1e-4)
	assert_vector(start.position).is_equal_approx(Vector3(0.1, -0.2, 0.3), Vector3.ONE * 1e-6)
	assert_float(start.size).is_equal(1.25)


func test_reload_media_poses_changes_the_pose_the_next_layout_stands_at() -> void:
	var stood := GamesLayout.new("gba_cart").chosen
	var data: Dictionary = JSON.parse_string(_media_text)
	var media: Dictionary = data["media"]
	var gba: Dictionary = media["gba_cart"]
	gba["position"] = [0.5, 0.25, -0.1]
	gba["scale"] = 1.1
	var answer := await _commands.run({"cmd": "reload", "files": [Fixtures.file(GamesLayout.FILE, JSON.stringify(data))]})
	assert_bool(answer["ok"]).is_true()
	var moved := GamesLayout.new("gba_cart").chosen
	assert_vector(moved.origin).is_equal_approx(Vector3(0.5, 0.25, -0.1), Vector3.ONE * 1e-5)
	assert_float(moved.basis.get_scale().x).is_equal_approx(1.1, 1e-5)
	assert_bool(moved.basis.orthonormalized().is_equal_approx(stood.basis.orthonormalized())).is_true()
	assert_vector(GamesLayout.new("gb_cart").chosen.origin).is_equal_approx(Vector3(0.028, 0.243, -0.015), Vector3.ONE * 1e-5)


func test_INV_EX_03_reload_restart_and_snapshot_only_write_beneath_the_dev_directory() -> void:
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


func test_pause_holds_time_and_input_resume_restores_them_and_step_advances_fixed_frames() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	await get_tree().process_frame
	await _commands.run({"cmd": "pause"})
	var stopped := scene.seconds
	await _commands.run({"cmd": "pause"})
	assert_float(Engine.time_scale).is_equal(0.0)
	assert_bool(get_viewport().is_input_disabled()).is_true()
	for frame in 3: await get_tree().process_frame
	assert_float(scene.seconds).is_equal(stopped)
	assert_bool((await _commands.run({"cmd": "step", "frames": 3}))["ok"]).is_true()
	assert_float(scene.seconds - stopped).is_equal_approx(3.0 / 60.0, 1e-6)
	assert_float(Engine.time_scale).is_equal(0.0)
	await _commands.run({"cmd": "resume"})
	assert_bool(get_tree().paused).is_false()
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool(get_viewport().is_input_disabled()).is_false()


func test_scrub_samples_the_launch_at_the_requested_time_and_holds_it() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var sequence := ConsoleSequence.new()
	var player := AnimationPlayer.new()
	sequence.player = player
	sequence.consoles = scene.row
	sequence.row = ShelfRow.new()
	sequence.layer = ConsoleLayer.new()
	sequence.layer.view = SubViewport.new()
	sequence.layer.add_child(sequence.layer.view)
	sequence.add_child(sequence.row)
	sequence.add_child(sequence.layer)
	scene.add_child(player)
	scene.add_child(sequence)
	var animation := Animation.new()
	animation.length = 2.0
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, ^"Probe:value")
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, 2.0, 10.0)
	var probe := ValueProbe.new()
	probe.name = "Probe"
	scene.add_child(probe)
	sequence.use(animation)
	assert_bool((await _commands.run({"cmd": "scrub", "t": 0.8}))["ok"]).is_true()
	assert_float(probe.value).is_equal_approx(4.0, 1e-5)
	assert_bool(_commands.paused).is_true()
	await get_tree().process_frame
	assert_float(probe.value).is_equal_approx(4.0, 1e-5)


func test_snapshot_returns_the_plugin_s_own_answers_and_its_variants_without_saving() -> void:
	var services: Fixtures.SnapshotServices = auto_free(Fixtures.SnapshotServices.new())
	add_child(services)
	_commands.android = services
	var answer := await _commands.run({"cmd": "snapshot"})
	assert_bool(answer["ok"]).is_true()
	assert_dict(answer["library"]).is_equal(services.payload)
	assert_dict(answer["settings"]).is_equal(services.choices)
	assert_dict(answer["variants"]).is_equal({"ps2": "ps2_fat"})
	assert_array(services.requests).is_equal([&"library", &"settings"])


func test_bad_commands_answer_an_error_without_losing_their_id() -> void:
	for message: Dictionary in [{"cmd": "missing"}, {"cmd": "go", "route": [{} , 3]},
		{"cmd": "go", "route": [{"press": "unknown"}]}, {"cmd": "reload", "files": "x"},
		{"cmd": "step", "frames": -1}, {"cmd": "step", "frames": 1.5}, {"cmd": "scrub", "t": -1},
		{"cmd": "pick", "x": "x", "y": 1}, {"cmd": "tune", "values": 2}]:
		message["id"] = 42
		var answer := await _commands.run(message)
		assert_bool(answer["ok"]).is_false()
		assert_int(answer["id"]).is_equal(42)
		assert_str(answer["error"]).is_not_empty()


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


func test_an_in_flight_old_plinth_picture_cannot_fill_a_forgotten_cache() -> void:
	var original := Plinth._drawer
	var calls: Array[Texture2D] = []
	Plinth._drawer = func(_folder: String) -> ImageTexture:
		await get_tree().process_frame
		await get_tree().process_frame
		return ImageTexture.create_from_image(Image.create_empty(2, 2, false, Image.FORMAT_RGBA8))
	Plinth.request_still("nes", func(texture: Texture2D) -> void: calls.append(texture))
	Plinth.forget()
	for frame in 4: await get_tree().process_frame
	assert_object(Plinth.still_of("nes")).is_null()
	assert_array(calls).is_empty()
	Plinth._drawer = original


func test_step_advances_a_real_animation_player_and_tween_by_the_requested_fixed_time() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var probe := ValueProbe.new()
	probe.name = "Probe"
	scene.add_child(probe)
	var player := AnimationPlayer.new()
	scene.add_child(player)
	var animation := Animation.new()
	animation.length = 1.0
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, ^"Probe:value")
	animation.track_insert_key(track, 0.0, 0.0)
	animation.track_insert_key(track, 1.0, 1.0)
	var animations := AnimationLibrary.new()
	animations.add_animation(&"sample", animation)
	player.add_animation_library(&"", animations)
	player.play(&"sample")
	player.seek(0.0, true)
	var tween := scene.create_tween()
	tween.tween_property(probe, ^"other", 1.0, 1.0)
	await _commands.run({"cmd": "pause"})
	assert_bool((await _commands.run({"cmd": "step", "frames": 6}))["ok"]).is_true()
	assert_float(probe.value).is_equal_approx(0.1, 1e-5)
	assert_float(probe.other).is_equal_approx(0.1, 1e-5)


func test_a_restart_prepares_the_next_start_pack_and_never_touches_the_one_a_start_mounted() -> void:
	var folder := Packs.directory()
	var files := [Fixtures.file(Plinth.TURNTABLE_FILE, _turntable_text)]
	assert_bool((await _commands.run({"cmd": "restart", "files": files}))["ok"]).is_true()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.NEXT))).is_true()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.START))).is_false()
	assert_array(Array(DirAccess.get_files_at(folder)).filter(func(file_name: String) -> bool:
		return file_name.begins_with("source_") or file_name.ends_with(".tmp"))).is_empty()
	# The next start makes it the start pack.
	Packs.mount_start()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.START))).is_true()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.NEXT))).is_false()
	# Another restart, or one without files, leaves the mounted file as it is.
	var mounted := FileAccess.get_sha256(folder.path_join(Packs.START))
	var other := [Fixtures.file(Plinth.TURNTABLE_FILE, _turntable_text + " ")]
	assert_bool((await _commands.run({"cmd": "restart", "files": other}))["ok"]).is_true()
	assert_str(FileAccess.get_sha256(folder.path_join(Packs.START))).is_equal(mounted)
	assert_bool((await _commands.run({"cmd": "restart", "files": []}))["ok"]).is_true()
	assert_str(FileAccess.get_sha256(folder.path_join(Packs.START))).is_equal(mounted)
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.NEXT))).is_false()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.NONE))).is_true()
	# At the next start, the marker removes the start pack; a restart with files after it takes the marker back.
	Packs.mount_start()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.START))).is_false()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.NONE))).is_false()
	await _commands.run({"cmd": "restart", "files": []})
	await _commands.run({"cmd": "restart", "files": files})
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.NONE))).is_false()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.NEXT))).is_true()


func test_purge_cleans_only_the_instance_s_own_folder_and_keeps_its_start_pack() -> void:
	var folder := "user://dev/test_purge"
	var neighbour := "user://dev/test_neighbour"
	DirAccess.make_dir_recursive_absolute(folder)
	DirAccess.make_dir_recursive_absolute(neighbour)
	var stale := ["overlay_1.pck", "source_1_0.bin", "start_next.pck.tmp"]
	for file_name: String in stale + [Packs.START]:
		FileAccess.open(folder.path_join(file_name), FileAccess.WRITE).close()
	FileAccess.open(neighbour.path_join("overlay_1.pck"), FileAccess.WRITE).close()
	Packs.use(folder)
	Packs.purge()
	# Back to the tests' folder, whose mounted overlays a purge must not remove.
	Packs.use(Fixtures.PACKS)
	Packs._purged = true
	for file_name: String in stale:
		assert_bool(FileAccess.file_exists(folder.path_join(file_name))).is_false()
	assert_bool(FileAccess.file_exists(folder.path_join(Packs.START))).is_true()
	assert_bool(FileAccess.file_exists(neighbour.path_join("overlay_1.pck"))).is_true()
	Fixtures.remove_tree(neighbour)
	Fixtures.remove_tree(folder)


func test_a_route_with_a_held_direction_plays_it_at_the_recorded_speed_for_as_long_as_it_was_recorded() -> void:
	# 25 frames of 0.02 s held, the rest replayed fast.
	var route := [{"push": "ui_right", "wait": 25}, {"release": "ui_right", "wait": 25}]
	assert_bool((await _commands.run({"cmd": "go", "route": route}))["ok"]).is_true()
	var scene := _commands.host as Fixtures.ProbeScene
	assert_float(scene.held_scale).is_equal(1.0)
	assert_float(scene.held_s).is_greater_equal(0.49)
	assert_float(Engine.time_scale).is_equal(1.0)
	assert_bool(Input.is_action_pressed(&"ui_right")).is_false()


func test_waits_count_game_time_so_a_press_wait_is_a_fraction_of_it_at_the_replay_speed() -> void:
	var started := Time.get_ticks_msec()
	assert_bool((await _commands.run({"cmd": "go", "route": [{"press": "ui_accept", "wait": 400}]}))["ok"]).is_true()
	# 8 s of game time, replayed 8 times faster: about one second, never the eight of real time.
	assert_int(Time.get_ticks_msec() - started).is_between(800, 3000)


func test_a_script_is_refused_by_reload_and_restart() -> void:
	for command: String in ["reload", "restart"]:
		var answer := await _commands.run({"cmd": command,
			"files": [Fixtures.file("res://studio/studio_tokens.gd", "extends RefCounted")]})
		assert_bool(answer["ok"]).is_false()
		assert_bool(FileAccess.file_exists(Packs.directory().path_join(Packs.NEXT))).is_false()


func test_a_file_read_at_start_is_refused_by_reload() -> void:
	var answer := await _commands.run({"cmd": "reload",
		"files": [Fixtures.file("res://data/platforms/profiles.json", "{}")]})
	assert_bool(answer["ok"]).is_false()
	assert_str(str(answer["error"])).contains("use restart")


func test_a_font_is_refused_by_reload_and_prepared_by_restart() -> void:
	var font := Fixtures.file("res://fonts/probe.ttf", "x")
	var answer := await _commands.run({"cmd": "reload", "files": [font]})
	assert_bool(answer["ok"]).is_false()
	assert_str(str(answer["error"])).contains("use restart")
	assert_bool((await _commands.run({"cmd": "restart", "files": [font]}))["ok"]).is_true()


func test_speed_set_while_paused_survives_resume() -> void:
	assert_bool((await _commands.run({"cmd": "tune", "target": "speed", "value": 0.25}))["ok"]).is_true()
	assert_float(Engine.time_scale).is_equal(0.25)
	await _commands.run({"cmd": "pause"})
	assert_float(Engine.time_scale).is_equal(0.0)
	await _commands.run({"cmd": "tune", "target": "speed", "value": 0.05})
	assert_float(Engine.time_scale).is_equal(0.0)
	await _commands.run({"cmd": "resume"})
	assert_float(Engine.time_scale).is_equal(0.05)
	for invalid: Variant in [-1, 0, 21, "slow"]:
		assert_bool((await _commands.run({"cmd": "tune", "target": "speed", "value": invalid}))["ok"]).is_false()
