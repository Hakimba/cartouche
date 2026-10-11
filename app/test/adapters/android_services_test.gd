# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


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


func test_INV_E2_5_01_without_the_plugin_the_catalog_and_the_demo_library_are_the_desktop_demo() -> void:
	# Tests run without the plugin, like the editor.
	assert_bool(Android.is_available()).is_false()
	var demo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AndroidServices.DESKTOP_DEMO))
	var platforms: Array = demo["catalog"]["platforms"]
	var ids := platforms.map(func(platform: Dictionary) -> String: return platform["id"])
	assert_array(ids).is_not_empty()
	assert_array(Android.catalog.platforms.map(func(platform: AndroidServices.Platform) -> String: return platform.id)).is_equal(ids)
	var answer := await Android.use_demo_library(5000)
	assert_bool(answer.ok).is_true()
	var games: Array = demo["library"]["games"]
	assert_int(answer.library.games.size()).is_equal(games.size())
	assert_array(answer.library.shelves.map(func(shelf: AndroidServices.Shelf) -> String: return shelf.platform_id)).is_equal(ids)


func test_the_plugin_gets_daijisho_s_definitions_and_cartouche_s_own() -> void:
	assert_array(AndroidServices.platform_definitions().keys()).contains(
		["SonyPlayStation2.json", "MicrosoftXbox.json", "MicrosoftXbox360.json"])


func test_the_library_answer_carries_the_scans_stored_for_its_games() -> void:
	var answer := AndroidServices.LibraryAnswer.new({
		"ok": true, "library": "{}", "art": JSON.stringify([{"game_id": "ps2/a", "path": "/art/a.jpg"}]),
	})
	assert_array(answer.art.map(func(art: AndroidServices.Art) -> Array: return [art.game_id, art.path])).is_equal([["ps2/a", "/art/a.jpg"]])
	assert_array(AndroidServices.LibraryAnswer.new({"ok": true, "library": "{}"}).art).is_empty()


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


func test_a_console_renamed_is_read_with_its_name_and_one_given_its_own_back_without() -> void:
	# The shape `CartouchePlugin.renameConsole` answers with.
	var named := AndroidServices.ConsoleRenamed.new({"ok": true, "name": "Ma PS2"})
	assert_bool(named.has_name and named.name == "Ma PS2").is_true()
	assert_bool(AndroidServices.ConsoleRenamed.new({"ok": true}).has_name).is_false()
	var library := AndroidServices.Library.new({"console_names": {"ps2": "Ma PS2"}})
	assert_str(library.console_names.get("ps2", "")).is_equal("Ma PS2")


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
	# Without the plugin: nothing known, and no bolt.
	var none := Android.battery()
	assert_bool(none.has_level or none.plugged).is_false()


## Answers as the Kotlin plugin does, as JSON text.
class FakePlugin extends Object:
	func browse(_platform_id: String, _order: String, _typed: String) -> String:
		return """{"count": 3, "games": [2, 0], "groups": [], "keys": {}}"""

	func titleMarks(_platform_id: String, _position: int, _typed: String) -> String:
		return "[[0, 3], [13, 4]]"
