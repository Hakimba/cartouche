# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Screens := preload("res://test/screens/fixtures.gd")
const Fixtures := preload("res://test/carousel/fixtures.gd")
const FOLDERS: Array[String] = ["ps2_slim", "psx", "nes", "snes", "n64", "gc", "wii", "xbox", "xbox360", "gb", "gbc", "gba"]

var _window := Vector2i.ZERO


func before_test() -> void:
	_window = get_window().size
	get_window().size = Vector2i(1280, 960)


func after_test() -> void:
	get_window().size = _window
	OS.low_processor_usage_mode = false


func _carousel() -> Carousel:
	var counts: Dictionary[String, int] = {}
	for folder in FOLDERS:
		counts[ConsoleManifest.of(folder).platform] = 5
	var carousel := Screens.fresh_carousel(self, Screens.past_first_launch(self, counts))
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	carousel._arrival.custom_step(10.0)
	carousel._resting.set_process(false)
	return carousel


func _no_rail(carousel: Carousel) -> void:
	assert_bool(carousel._rail.is_visible_in_tree()).is_false()
	assert_bool(carousel._rail.frame().is_visible_in_tree()).is_false()
	assert_bool(carousel._rail.pool().is_visible_in_tree()).is_false()
	assert_bool(carousel._rail._mirrors_root.is_visible_in_tree()).is_false()


func test_covering_screens_and_an_empty_library_never_show_the_rail_or_its_ground() -> void:
	var device := Screens.past_first_launch(self, {"ps2": 2})
	var carousel := Screens.carousel_for(self, device)
	(carousel.get_node("%Screens") as ScreenFlow).welcome_waits = true
	add_child(carousel)
	assert_bool(await Screens.until(self, func() -> bool: return not carousel._shelves.is_empty())).is_true()
	for screen_name: String in ["Welcome", "ButtonStyle", "NoConsole", "PreferredRegion"]:
		var screen := carousel._screens.get_node(screen_name) as Control
		carousel._screens._show(screen)
		carousel._show_front(true)
		assert_bool(screen.is_visible_in_tree()).is_true()
		_no_rail(carousel)
	carousel._show_library(AndroidServices.Library.new({}))
	carousel._show_front(false)
	_no_rail(carousel)
	assert_int(carousel._rail.tiles().size()).is_equal(0)


func _logos_match(carousel: Carousel) -> void:
	var rail := carousel._rail
	for i in carousel._shelves.size():
		var folder := carousel._consoles.console_at(i).folder
		var tile := rail.tiles()[i]
		assert_str(tile.console()).is_equal(folder)
		assert_str(tile.logo().texture.resource_path).ends_with("rail-tile/%s.png" % folder)
		assert_str(rail._mirrors[i].logo().texture.resource_path).ends_with("rail-tile/%s.png" % folder)
		if tile.visible:
			var slots := ConsoleRail.slot(i, rail.spring().position, carousel._shelves.size())
			assert_float(absf((tile.position.x - 564.48) / 174.08)).is_equal_approx(absf(slots), 0.001)
	var selected := carousel._consoles.selected().folder
	assert_str(carousel._games_logo.texture.resource_path).ends_with("games-top/%s.png" % selected)
	assert_str(rail.tiles()[carousel._consoles.selected_index()].console()).is_equal(selected)


func test_reordering_and_random_fast_wraps_keep_every_tile_and_the_games_logo_on_their_console() -> void:
	var carousel := await _carousel()
	var ids := carousel._platform_ids()
	ids.reverse()
	carousel._on_consoles_ordered(ids)
	_logos_match(carousel)
	var random := RandomNumberGenerator.new()
	random.seed = 120113
	for press in 60:
		carousel._consoles.step(-1 if press < 15 or random.randf() < 0.5 else 1)
		for frame in random.randi_range(0, 8):
			carousel._rail._process(1.0 / 60.0)
		_logos_match(carousel)
	while carousel._rail.is_processing():
		carousel._rail._process(1.0 / 60.0)
	assert_vector(carousel._rail.tile_at(carousel._consoles.selected_index())) \
		.is_equal_approx(Vector2(564.48, 711.68), Vector2.ONE * 0.01)
