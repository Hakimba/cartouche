# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/dev/bridge/fixtures.gd")


func after_test() -> void:
	Fixtures.remove_tree("user://dev/snapshot")
	Fixtures.remove_tree("user://dev/bad")


func test_a_desktop_snapshot_supplies_its_two_consoles_settings_variant_and_mapped_pictures() -> void:
	var folder := "user://dev/snapshot"
	var locale := TranslationServer.get_locale()
	DirAccess.make_dir_recursive_absolute(folder)
	var library := {"games": [
		{"id": "ps2/A", "platform_id": "ps2", "title": "A/files/art/edition", "identified": false, "discs": [{"name": "A"}], "last_disc": 0},
		{"id": "gba/B", "platform_id": "gba", "title": "B", "identified": false, "discs": [{"name": "B"}], "last_disc": 0,
			"label_path": "/device/files/art/own/b.png"}], "console_variants": {"ps2": "ps2_fat"}}
	var snapshot := {"library": {"ok": true, "library": JSON.stringify(library),
		"art": JSON.stringify([{"game_id": "ps2/A", "path": "/device/files/art/a.png"}])},
		"settings": {"ok": true, "first_launch": false, "button_style": "nintendo", "edge_smoothing": "2x",
			"games_float": true, "preferred_region": "Japan"}, "variants": {"ps2": "ps2_fat"},
		"browse": {"ps2": {"title": JSON.stringify({"count": 1, "games": [0], "keys": {"a": 0}})}}, "locale": "fr"}
	var file := FileAccess.open(folder.path_join("snapshot.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	var saved_snapshot := FileAccess.get_sha256(folder.path_join("snapshot.json"))
	var services: AndroidServices = auto_free(AndroidServices.new())
	assert_bool(services.load_snapshot(folder)).is_true()
	var answer := await services.use_demo_library(5000)
	assert_bool(answer.ok).is_true()
	assert_array(answer.library.games.map(func(game: AndroidServices.Game) -> String: return game.id)).is_equal(["ps2/A", "gba/B"])
	assert_str(answer.library.games[0].title).is_equal("A/files/art/edition")
	assert_dict(answer.library.console_variants).is_equal({"ps2": "ps2_fat"})
	assert_int(answer.art.size()).is_equal(1)
	assert_str(answer.art[0].path).is_equal(folder.path_join("files/art/a.png"))
	var raw := services.desktop_library()
	var mapped: Dictionary = JSON.parse_string(str(raw["library"]))
	var games: Array = mapped["games"]
	var second: Dictionary = games[1]
	assert_str(second["label_path"]).is_equal(folder.path_join("files/art/own/b.png"))
	var settings := await services.settings()
	assert_str(settings.button_style).is_equal("nintendo")
	assert_str(settings.edge_smoothing).is_equal("2x")
	assert_str(settings.preferred_region).is_equal("Japan")
	assert_bool(settings.games_float).is_true()
	assert_bool((await services.save_games_float(false)).ok).is_true()
	assert_bool((await services.settings()).games_float).is_false()
	var kept_variants := FileAccess.get_file_as_string("user://console-variants.json") if FileAccess.file_exists("user://console-variants.json") else ""
	assert_bool((await services.set_variant("ps2", "ps2_slim")).ok).is_true()
	assert_dict((await services.library()).library.console_variants).is_equal({"ps2": "ps2_slim"})
	assert_str(FileAccess.get_file_as_string("user://console-variants.json") if FileAccess.file_exists("user://console-variants.json") else "").is_equal(kept_variants)
	assert_dict(services.browse("ps2", &"title", "").keys).is_equal({"a": 0})
	assert_int(services.browse("ps2", &"title", "a").count).is_equal(0)
	assert_int(services.browse("gba", &"title", "").count).is_equal(0)
	assert_str(TranslationServer.get_locale()).is_equal("fr")
	TranslationServer.set_locale(locale)
	assert_str(FileAccess.get_sha256(folder.path_join("snapshot.json"))).is_equal(saved_snapshot)


func test_a_snapshot_is_ignored_when_it_is_missing_or_malformed_and_never_in_release() -> void:
	var services: AndroidServices = auto_free(AndroidServices.new())
	assert_bool(services.load_snapshot("user://dev/missing")).is_false()
	DirAccess.make_dir_recursive_absolute("user://dev/bad")
	var file := FileAccess.open("user://dev/bad/snapshot.json", FileAccess.WRITE)
	file.store_string("{\"library\":3,\"settings\":{}}")
	file.close()
	assert_bool(services.load_snapshot("user://dev/bad")).is_false()
	assert_bool(services._snapshot.is_empty()).is_true()
