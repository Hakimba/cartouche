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
