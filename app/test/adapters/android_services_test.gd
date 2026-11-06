# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")


func test_the_shelves_sent_by_the_plugin_are_read_as_the_library_games_they_point_to() -> void:
	# Shelves point into the library's games by index (`Sent.Library`).
	var game := func(id: String, platform: String) -> Dictionary:
		return {"id": id, "platform_id": platform, "title": id, "identified": false, "discs": [{"name": id}], "last_disc": 0}
	var sent: Dictionary = JSON.parse_string(JSON.stringify({
		"games": [game.call("gba/B", "gba"), game.call("ps2/Z", "ps2"), game.call("ps2/A", "ps2")],
		"shelves": [
			{"platform_id": "ps2", "game_indexes": [2, 1], "selected": 1},
			{"platform_id": "gba", "game_indexes": [0], "selected": 0},
		],
		"selected_shelf": 1,
	}))
	var library := AndroidServices.Library.new(sent)
	assert_int(library.selected_shelf).is_equal(1)
	var ids := library.shelves.map(func(shelf: AndroidServices.Shelf) -> Array:
		return [shelf.platform_id, shelf.selected, shelf.games.map(func(g: AndroidServices.Game) -> String: return g.id)])
	assert_array(ids).is_equal([["ps2", 1, ["ps2/A", "ps2/Z"]], ["gba", 0, ["gba/B"]]])


func test_what_the_carousel_shows_of_a_shelf_is_read_as_the_plugin_sends_it() -> void:
	# From the plugin, its answer read as is; where the words typed are, as (start, length).
	var services: AndroidServices = auto_free(AndroidServices.new())
	services._plugin = auto_free(FakePlugin.new())
	assert_array(Array(services.browse("ps2", &"title", "ace").games)).is_equal([2, 0])
	assert_array(services.title_marks("ps2", 0, "dist ace")).is_equal([Vector2i(0, 3), Vector2i(13, 4)])
	# Without the plugin, nothing: no game, no key.
	var none := Android.browse("ps2", &"title", "ace")
	assert_int(none.count).is_equal(0)
	assert_array(Array(none.games)).is_empty()
	assert_array(Android.title_marks("ps2", 0, "ace")).is_empty()


func test_a_library_without_shelves_has_none() -> void:
	var library := AndroidServices.Library.new({"games": []})
	assert_array(library.shelves).is_empty()
	assert_int(library.selected_shelf).is_equal(0)


func test_a_picture_picked_is_read_with_its_size_and_a_game_with_its_own_title() -> void:
	var picture := AndroidServices.LabelPicture.new({"ok": true, "path": "/own/picked.jpg", "width": 640, "height": 480})
	assert_vector(picture.size).is_equal(Vector2i(640, 480))
	var game := {"id": "ps2/A", "platform_id": "ps2", "title": "A", "identified": false, "discs": [{"name": "A"}], "last_disc": 0}
	game["original_title"] = "A of its own"
	assert_str(AndroidServices.Game.new(game).own_title()).is_equal("A of its own")
	game.erase("original_title")
	assert_str(AndroidServices.Game.new(game).own_title()).is_equal("A")


func test_an_answer_asked_for_early_is_taken_once_it_arrives_however_late() -> void:
	# As on a device: the plugin answers frames after the asking.
	var late := AndroidServices.Asked.new(func() -> String:
		await get_tree().process_frame
		await get_tree().process_frame
		return "late")
	assert_bool(late.has_arrived).is_false()
	assert_str(await late.taken()).is_equal("late")
	# Already there when taken.
	var at_once := AndroidServices.Asked.new(func() -> String: return "at once")
	assert_bool(at_once.has_arrived).is_true()
	assert_str(await at_once.taken()).is_equal("at once")


func test_without_the_plugin_the_battery_is_the_demo_s_full_and_charging_as_the_design_draws_it() -> void:
	var demo := Android.battery()
	assert_int(demo.level_percent).is_equal(100)
	assert_bool(demo.has_level_percent and demo.plugged).is_true()


func test_art_focus_sends_the_ordered_ids_as_a_packed_string_array_to_the_plugin() -> void:
	var services: AndroidServices = auto_free(AndroidServices.new())
	var plugin: FakePlugin = auto_free(FakePlugin.new())
	services._plugin = plugin
	var games: Array[AndroidServices.Game] = []
	for id: String in ["ps2/B", "ps2/C", "ps2/A"]:
		games.append(AndroidServices.Game.new({"id": id, "platform_id": "ps2", "title": id, "identified": false,
			"discs": [{"name": id}], "last_disc": 0}))
	services.art_focus(games)
	assert_array(plugin.focus_calls).is_equal([PackedStringArray(["ps2/B", "ps2/C", "ps2/A"])])


## Answers as the Kotlin plugin does, as JSON text.
class FakePlugin extends Object:
	var focus_calls: Array[PackedStringArray] = []
	var loaded_supported := PackedStringArray()
	var loaded_coming := PackedStringArray()
	var launch_requests: Array[Dictionary] = []

	func launchGame(_id: int, request: Dictionary) -> String:
		launch_requests.append(request)
		return """{"ok": true}"""

	func artFocus(ids: PackedStringArray) -> void:
		focus_calls.append(ids)

	func browse(_platform_id: String, _order: String, _typed: String) -> String:
		return """{"count": 3, "games": [2, 0], "groups": [], "keys": {}}"""

	func loadCatalog(_definitions: Dictionary, _profiles: String, _data_folders: String, _curtains: String,
			supported: PackedStringArray, coming: PackedStringArray) -> String:
		loaded_supported = supported
		loaded_coming = coming
		return """{"platforms": []}"""

	func titleMarks(_platform_id: String, _position: int, _typed: String) -> String:
		return """{"marks": [{"start": 0, "length": 3}, {"start": 13, "length": 4}]}"""


func test_inv_21_a_start_is_asked_with_a_deadline_below_the_wait_of_the_carousel_that_gives_up_after_it() -> void:
	var services: AndroidServices = auto_free(AndroidServices.new())
	var plugin: FakePlugin = auto_free(FakePlugin.new())
	services._plugin = plugin
	var game := AndroidServices.Game.new({"id": "ps2/a", "platform_id": "ps2", "title": "A", "identified": false,
		"discs": [{"name": "A"}], "last_disc": 0})
	assert_bool((await services.launch_game(game, 0)).ok).is_true()
	assert_int(plugin.launch_requests.size()).is_equal(1)
	var within_ms: int = plugin.launch_requests[0].get("within_ms", -1)
	assert_int(within_ms).is_greater(0)
	assert_int(within_ms).is_less(int(GameLaunch.WAIT_TIMEOUT_S * 1000))
	assert_str(plugin.launch_requests[0]["game_id"]).is_equal("ps2/a")


func test_inv_15_a_settings_answer_without_a_value_reads_a_fresh_install_s_as_the_plugin_sends_it() -> void:
	var fresh := DesktopPlugin.settings_of(DesktopPlugin.demo("settings"))
	assert_dict(fresh).is_not_empty()
	var sent := AndroidServices.SettingsAnswer.new({"ok": true}.merged(fresh))
	var unsaid := AndroidServices.SettingsAnswer.new({"ok": true})
	var started := AndroidServices.BackdropAnswer.new()
	for key: String in fresh:
		# The lists of names are the plugin's to tell: none is known without it.
		if fresh[key] is not PackedStringArray:
			var answer: Object = started if key in started else unsaid
			assert_bool(answer.get(key) == fresh[key]).override_failure_message("%s: %s, sent %s" % [key, answer.get(key),
				fresh[key]]).is_true()
	assert_bool(sent.games_float).is_false()


func test_without_the_plugin_and_without_a_form_story_the_form_s_operations_are_unavailable() -> void:
	assert_bool((Android._plugin as DesktopPlugin).form().is_empty()).is_true()
	assert_array(Android.installed_players("ps2")).is_empty()
	assert_str((await Android.pick_folder()).code).is_equal("unavailable")
	assert_str((await Android.place_console("ps2", 0)).code).is_equal("unavailable")


func test_without_the_plugin_and_without_a_form_story_a_model_chosen_in_edit_is_saved() -> void:
	var path := DesktopPlugin._VARIANTS
	var kept := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var services: AndroidServices = auto_free(AndroidServices.new())
	var choices := AndroidServices.PlatformSetup.new()
	choices.variant_id = "switch_grey"
	var saved := await services.set_up_platform("switch", choices)
	if kept:
		FileAccess.open(path, FileAccess.WRITE).store_string(kept)
	else:
		DirAccess.remove_absolute(path)
	assert_bool(saved.ok).is_true()
	assert_str(saved.library.console_variants.get("switch", "")).is_equal("switch_grey")
	var shelves: Array = DesktopPlugin.demo("library")["shelves"]
	assert_int(saved.library.on_ring().size()).is_equal(shelves.size())


func test_without_the_plugin_the_demo_on_one_shelf_has_every_game_on_that_console_alone() -> void:
	var services: AndroidServices = auto_free(AndroidServices.new())
	var answer := await services.use_demo_library(0, "ps2")
	var games: Array = DesktopPlugin.demo("library")["games"]
	assert_array(answer.library.on_ring()).is_equal(PackedStringArray(["ps2"]))
	assert_int(answer.library.games_of("ps2").size()).is_equal(games.size())


func test_without_the_plugin_a_form_story_in_the_demo_answers_the_form_in_the_wire_shape() -> void:
	var story := {
		"type": "ps2", "games": 59, "library": {"games": []},
		"players": [{"id": "ps2.x", "name": "ps2 - X", "emulator_name": "X", "extensions": ["iso"]}],
		"folder": {"uri": "content://tree/x", "name": "ps2"},
		"placing": {"0": ["ps2", "psx"], "1": ["psx", "ps2"]},
	}
	var services: AndroidServices = auto_free(AndroidServices.new())
	var plugin := StoryPlugin.new()
	plugin.story = story
	services._plugin = plugin
	assert_array(services.installed_players("ps2").map(func(p: AndroidServices.Player) -> String: return p.emulator_name)).is_equal(["X"])
	assert_array(services.installed_players("gba")).is_empty()
	assert_str((await services.pick_folder()).folder.uri).is_equal("content://tree/x")
	assert_int((await services.preview_platform("ps2", AndroidServices.PlatformSetup.new())).report.games).is_equal(59)
	assert_int((await services.scan_platform("ps2")).report.games).is_equal(59)
	assert_bool((await services.set_up_platform("ps2", AndroidServices.PlatformSetup.new())).ok).is_true()
	assert_array((await services.place_console("ps2", 1)).order).is_equal(PackedStringArray(["psx", "ps2"]))
	var out_of_range := await services.place_console("ps2", 5)
	assert_str(out_of_range.code).is_equal("gap_out_of_range")
	assert_array(out_of_range.order).is_empty()


## The platform ids of the console manifests, sorted.
func _model_ids() -> Array:
	var ids := Appearance.defaults(ConsoleManifest.found()).keys()
	ids.sort()
	return ids


## The desktop stand-in with a form story in its demo.
class StoryPlugin extends DesktopPlugin:
	var story: Dictionary

	func form() -> Dictionary:
		return story


func test_the_catalog_is_loaded_with_the_platforms_of_the_console_manifests() -> void:
	var services: AndroidServices = auto_free(AndroidServices.new())
	var plugin: FakePlugin = auto_free(FakePlugin.new())
	services._plugin = plugin
	services._load_catalog()
	var expected := _model_ids()
	var sent := Array(plugin.loaded_supported)
	sent.sort()
	assert_array(sent).is_equal(expected)
	# The models without a launch animation of their own are named coming, and only they.
	for model in ConsoleManifest.found():
		assert_bool(ConsoleManifest.folder_of(model) in plugin.loaded_coming).is_equal(model.launch.is_empty())


func test_desktop_settings_save_every_choice_with_the_same_success_and_read_them_back() -> void:
	var services: AndroidServices = auto_free(AndroidServices.new())
	assert_bool(services.is_available()).is_false()
	assert_bool(FileAccess.file_exists(DesktopPlugin.DEMO)).is_true()
	assert_bool((await services.settings()).games_float).is_false()
	assert_bool((await services.settings()).has_button_style).is_false()
	assert_str(services.backdrop().backdrop).is_equal("light")
	assert_bool(services.backdrop().pixel_veil).is_true()
	assert_bool((await services.save_setting(&"backdrop", &"anthracite")).ok).is_true()
	assert_bool((await services.save_setting(&"pixel_veil", false)).ok).is_true()
	assert_bool((await services.save_setting(&"games_float", true)).ok).is_true()
	assert_bool((await services.save_setting(&"button_style", &"nintendo")).ok).is_true()
	assert_bool((await services.save_setting(&"edge_smoothing", &"2x")).ok).is_true()
	assert_bool((await services.save_setting(&"preferred_region", "Japan")).ok).is_true()
	var stored := await services.settings()
	assert_bool(stored.games_float).is_true()
	assert_str(stored.button_style).is_equal("nintendo")
	assert_str(stored.edge_smoothing).is_equal("2x")
	assert_str(stored.preferred_region).is_equal("Japan")
	assert_str(services.backdrop().backdrop).is_equal("anthracite")
	assert_bool(services.backdrop().pixel_veil).is_false()
	assert_bool((await services.save_setting(&"games_float", false)).ok).is_true()
	assert_bool((await services.settings()).games_float).is_false()


func test_desktop_detection_means_no_real_bridge_even_when_operations_are_faked() -> void:
	var services: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	assert_bool(services.is_available()).is_true()
	assert_bool(services._plugin is DesktopPlugin).is_true()
	assert_dict(JSON.parse_string(services._query(&"battery", []))).is_equal(DesktopPlugin.demo("battery"))


func test_inv_14_each_of_cartouche_s_own_definitions_is_sent_in_place_of_daijishou_s_of_its_name() -> void:
	var sent := AndroidServices.platform_definitions()
	var own := "res://data/platforms/cartouche"
	for file_name: String in DirAccess.get_files_at(own):
		if file_name.ends_with(".json"):
			assert_str(sent[file_name]).is_equal(FileAccess.get_file_as_string(own.path_join(file_name)))
