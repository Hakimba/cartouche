# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")


func test_the_shelves_sent_by_the_plugin_are_read_as_the_library_games_they_point_to() -> void:
	# The shape of `toWireJson` in Wire.kt: shelves point into the library's games by index.
	var game := func(id: String, platform: String) -> Dictionary:
		return {"id": id, "platform_id": platform, "title": id, "identified": false, "discs": [{"name": id}], "last_disc": 0}
	var library := AndroidServices.Library.new({
		"games": [game.call("gba/B", "gba"), game.call("ps2/Z", "ps2"), game.call("ps2/A", "ps2")],
		"shelves": {"shelves": [
			{"platform": "ps2", "games": [2, 1], "selected": 1},
			{"platform": "gba", "games": [0], "selected": 0},
		], "selected": 1},
	})
	assert_int(library.selected_shelf).is_equal(1)
	var ids := library.shelves.map(func(shelf: AndroidServices.Shelf) -> Array:
		return [shelf.platform_id, shelf.selected, shelf.games.map(func(g: AndroidServices.Game) -> String: return g.id)])
	assert_array(ids).is_equal([["ps2", 1, ["ps2/A", "ps2/Z"]], ["gba", 0, ["gba/B"]]])


func test_what_the_carousel_shows_of_a_shelf_is_read_as_the_plugin_sends_it() -> void:
	# The shape of `View.toWireJson` in Wire.kt, numbers read from JSON as floats.
	var view: Dictionary = JSON.parse_string("""{"count": 3, "games": [2, 0], "groups": [{"label": "A", "start": 0},
		{"label": "#", "start": 1}], "keys": {"a": 0, " ": 1}}""")
	var browse := AndroidServices.Browse.new(view)
	assert_int(browse.count).is_equal(3)
	assert_array(Array(browse.games)).is_equal([2, 0])
	assert_array(browse.groups.map(func(group: AndroidServices.Group) -> Array: return [group.label, group.start])).is_equal(
		[["A", 0], ["#", 1]])
	assert_dict(browse.keys).is_equal({"a": 0, " ": 1})
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


func test_scraping_again_is_read_with_its_games_its_labels_found_and_the_consoles_not_scanned() -> void:
	var answer := AndroidServices.RescrapeAnswer.new({
		"ok": true, "library": "{}", "games": 57, "labels": 50, "failures": PackedStringArray(["gc: no folder"]),
	})
	assert_int(answer.games).is_equal(57)
	assert_int(answer.labels).is_equal(50)
	assert_array(answer.failures).is_equal(PackedStringArray(["gc: no folder"]))
	assert_array(AndroidServices.RescrapeAnswer.new({"ok": true, "library": "{}"}).failures).is_empty()


func test_the_library_answer_carries_the_scans_stored_for_its_games_and_those_found_to_have_none() -> void:
	var answer := AndroidServices.LibraryAnswer.new({
		"ok": true, "library": "{}", "art": JSON.stringify([{"game_id": "ps2/a", "path": "/art/a.jpg"}]),
		"absent": PackedStringArray(["ps2/b"]),
	})
	assert_array(answer.art.map(func(art: AndroidServices.Art) -> Array: return [art.game_id, art.path])).is_equal([["ps2/a", "/art/a.jpg"]])
	assert_array(answer.absent).is_equal(PackedStringArray(["ps2/b"]))
	var bare := AndroidServices.LibraryAnswer.new({"ok": true, "library": "{}"})
	assert_array(bare.art).is_empty()
	assert_array(bare.absent).is_empty()


func test_an_art_change_tells_the_progress_its_stall_and_the_scan_found() -> void:
	var change := AndroidServices.ArtChange.new({"done": 3, "total": 55, "found": {"game_id": "ps2/a", "path": "/art/a.jpg"}})
	assert_int(change.progress.done).is_equal(3)
	assert_int(change.progress.total).is_equal(55)
	assert_str(change.progress.stall).is_empty()
	assert_bool(change.has_found).is_true()
	assert_str(change.found.game_id).is_equal("ps2/a")
	var stalled := AndroidServices.ArtChange.new({"done": 3, "total": 55, "stall": "offline"})
	assert_str(stalled.progress.stall).is_equal("offline")
	assert_bool(stalled.has_found).is_false()
	assert_array(stalled.absent).is_empty()
	var absent := AndroidServices.ArtChange.new({"done": 4, "total": 55, "absent": PackedStringArray(["ps2/b", "ps2/c"])})
	assert_array(absent.absent).is_equal(PackedStringArray(["ps2/b", "ps2/c"]))


func test_the_settings_answer_carries_the_regions_the_plugin_takes_and_the_one_preferred() -> void:
	var answer := AndroidServices.SettingsAnswer.new({"ok": true, "first_launch": false,
		"preferred_region": "Japan", "preferred_regions": PackedStringArray(["Europe", "Japan"])})
	assert_str(answer.preferred_region).is_equal("Japan")
	assert_array(answer.preferred_regions).is_equal(PackedStringArray(["Europe", "Japan"]))
	var bare := AndroidServices.SettingsAnswer.new({"ok": true, "first_launch": false})
	assert_str(bare.preferred_region).is_empty()
	assert_array(bare.preferred_regions).is_empty()


func test_a_label_download_tells_how_far_it_has_come_an_unknown_size_and_its_end() -> void:
	var half := AndroidServices.LabelDownload.new({"game_id": "ps2/a", "fraction": 0.5})
	assert_str(half.game_id).is_equal("ps2/a")
	assert_bool(half.running).is_true()
	assert_float(half.fraction).is_equal(0.5)
	assert_float(AndroidServices.LabelDownload.new({"game_id": "ps2/a", "fraction": -1.0}).fraction).is_equal(-1.0)
	assert_bool(AndroidServices.LabelDownload.new({"game_id": "ps2/a"}).running).is_false()


func test_a_picture_picked_is_read_with_its_path_and_size_and_a_label_of_one_s_own_as_such() -> void:
	# The shapes of `OwnPicture.toWire` and of a game in Wire.kt.
	var picture := AndroidServices.LabelPicture.new({"ok": true, "picture": {"path": "/own/picked.jpg", "width": 640, "height": 480}})
	assert_str(picture.path).is_equal("/own/picked.jpg")
	assert_vector(picture.size).is_equal(Vector2i(640, 480))
	var game := {"id": "ps2/A", "platform_id": "ps2", "title": "A", "identified": false, "discs": [{"name": "A"}], "last_disc": 0}
	assert_bool(AndroidServices.Game.new(game).label_own).is_false()
	game["label_own"] = true
	assert_bool(AndroidServices.Game.new(game).label_own).is_true()
	game["original_title"] = "A of its own"
	assert_str(AndroidServices.Game.new(game).own_title()).is_equal("A of its own")
	game.erase("original_title")
	assert_str(AndroidServices.Game.new(game).own_title()).is_equal("A")


func test_a_game_is_read_with_the_medium_its_platform_gives_it_and_none_when_it_has_none() -> void:
	var game := {"id": "snes/A", "platform_id": "snes", "title": "A", "identified": false, "discs": [{"name": "A"}], "last_disc": 0}
	assert_str(AndroidServices.Game.new(game).medium).is_empty()
	game["medium"] = "sfc_cart"
	assert_str(AndroidServices.Game.new(game).medium).is_equal("sfc_cart")


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


func test_the_battery_is_read_as_the_plugin_sends_it_plugged_or_not_its_level_when_known() -> void:
	var plugged := AndroidServices.Battery.new({"level_percent": 57, "plugged": true})
	assert_bool(plugged.has_level).is_true()
	assert_int(plugged.level_percent).is_equal(57)
	assert_bool(plugged.plugged).is_true()
	var unknown := AndroidServices.Battery.new({"plugged": false})
	assert_bool(unknown.has_level).is_false()
	assert_bool(unknown.plugged).is_false()
	# Without the plugin, on a desktop, the demo's: full and charging, as the design draws it.
	var demo := Android.battery()
	assert_int(demo.level_percent).is_equal(100)
	assert_bool(demo.has_level and demo.plugged).is_true()


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

	func artFocus(ids: PackedStringArray) -> void:
		focus_calls.append(ids)

	func browse(_platform_id: String, _order: String, _typed: String) -> String:
		return """{"count": 3, "games": [2, 0], "groups": [], "keys": {}}"""

	func loadCatalog(_definitions: Dictionary, _profiles: String, _titles: Dictionary, _data_folders: String, _curtains: String,
			_art: Dictionary, _prints: Dictionary, _textures: Dictionary, supported: PackedStringArray) -> Dictionary:
		loaded_supported = supported
		return {"platforms": []}

	func titleMarks(_platform_id: String, _position: int, _typed: String) -> String:
		return "[[0, 3], [13, 4]]"


func test_the_catalog_summary_reads_the_consoles_a_person_may_add_in_their_order() -> void:
	var summary := AndroidServices.CatalogSummary.new({"platforms": [],
		"offered": [{"id": "xbox", "maker": "Microsoft", "model": "Xbox"}, {"id": "nes", "model": "Nintendo Entertainment System"}]})
	assert_array(summary.offered.map(func(c: AndroidServices.OfferedConsole) -> Array: return [c.id, c.maker, c.model])).is_equal(
		[["xbox", "Microsoft", "Xbox"], ["nes", "", "Nintendo Entertainment System"]])
	assert_array(AndroidServices.CatalogSummary.new({}).offered).is_empty()


func test_inv_15_the_settings_answer_tells_whether_games_float_off_when_the_plugin_says_nothing() -> void:
	assert_bool(AndroidServices.SettingsAnswer.new({"ok": true, "games_float": true}).games_float).is_true()
	assert_bool(AndroidServices.SettingsAnswer.new({"ok": true}).games_float).is_false()


func test_a_console_placed_is_read_with_the_order_the_plugin_answers_and_none_when_it_failed() -> void:
	var placed := AndroidServices.Placed.new({"ok": true, "order": PackedStringArray(["psx", "ps2", "gba"])})
	assert_array(placed.order).is_equal(PackedStringArray(["psx", "ps2", "gba"]))
	var refused := AndroidServices.Placed.new({"ok": false, "code": "gap_out_of_range", "detail": "x", "order": PackedStringArray(["a"])})
	assert_str(refused.code).is_equal("gap_out_of_range")
	assert_array(refused.order).is_empty()


func test_without_the_plugin_and_without_a_form_story_the_form_s_operations_are_unavailable() -> void:
	assert_bool((Android._plugin as DesktopPlugin).form().is_empty()).is_true()
	assert_array(Android.installed_players("ps2")).is_empty()
	assert_str((await Android.pick_folder()).code).is_equal("unavailable")
	assert_str((await Android.place_console("ps2", 0)).code).is_equal("unavailable")


func test_without_the_plugin_a_form_story_in_the_demo_answers_the_form_in_the_wire_shape() -> void:
	var story := {
		"type": "ps2", "games": 59, "library": JSON.stringify({"games": []}),
		"players": [{"player_id": "ps2.x", "player_name": "ps2 - X", "emulator_name": "X", "extensions": PackedStringArray(["iso"])}],
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


func test_a_form_story_read_from_the_demo_s_json_has_its_lists_of_texts_as_the_plugin_sends_them() -> void:
	var demo: Dictionary = JSON.parse_string("""{"form": {"players": [{"player_id": "a", "player_name": "a - A",
		"extensions": ["iso", "chd"]}], "folder": {"uri": "u", "name": "n", "place": {"volume": "card", "folders": ["ROMs", "ps2"]}}}}""")
	var story := DesktopPlugin.story_of(demo)
	var players: Array = story["players"]
	var player: Dictionary = players[0]
	var folder: Dictionary = story["folder"]
	assert_array(AndroidServices.Player.new(player).extensions).is_equal(PackedStringArray(["iso", "chd"]))
	assert_array(AndroidServices.Folder.new(folder).folders).is_equal(PackedStringArray(["ROMs", "ps2"]))
	assert_dict(DesktopPlugin.story_of({})).is_empty()


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


func test_the_fake_device_places_as_the_plugin_does_refusing_a_console_set_up_without_games() -> void:
	var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	device.consoles = {"ps2": 5, "gba": 3, "nes": 0}
	device.order = PackedStringArray(["gba", "ps2"])
	assert_array((await device.place_console("ps2", 0)).order).is_equal(PackedStringArray(["ps2", "gba"]))
	var empty := await device.place_console("nes", 0)
	assert_str(empty.code).is_equal("not_in_library")
	assert_array(empty.order).is_empty()
	assert_str((await device.place_console("ps2", 5)).code).is_equal("gap_out_of_range")
	assert_array(device.order).is_equal(PackedStringArray(["ps2", "gba"]))


func test_desktop_settings_save_every_choice_with_the_same_success_and_read_them_back() -> void:
	var services: AndroidServices = auto_free(AndroidServices.new())
	assert_bool(services.is_available()).is_false()
	assert_bool(FileAccess.file_exists(DesktopPlugin.DEMO)).is_true()
	assert_bool((await services.settings()).games_float).is_false()
	assert_bool((await services.settings()).has_button_style).is_false()
	assert_bool((await services.save_games_float(true)).ok).is_true()
	assert_bool((await services.save_button_style(&"nintendo")).ok).is_true()
	assert_bool((await services.save_edge_smoothing(&"2x")).ok).is_true()
	assert_bool((await services.save_preferred_region("Japan")).ok).is_true()
	var stored := await services.settings()
	assert_bool(stored.games_float).is_true()
	assert_str(stored.button_style).is_equal("nintendo")
	assert_str(stored.edge_smoothing).is_equal("2x")
	assert_str(stored.preferred_region).is_equal("Japan")
	assert_bool((await services.save_games_float(false)).ok).is_true()
	assert_bool((await services.settings()).games_float).is_false()


func test_desktop_detection_means_no_real_bridge_even_when_operations_are_faked() -> void:
	var services: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	assert_bool(services.is_available()).is_true()
	assert_bool(services._plugin is DesktopPlugin).is_true()
	assert_dict(services._query(&"battery", [], {})).is_equal(DesktopPlugin.demo("battery"))
