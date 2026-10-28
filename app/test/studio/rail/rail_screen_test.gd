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
	Controls.style = &"xbox"
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


func test_every_console_shows_the_games_logo_only_once_its_games_screen_is_shown_at_native_size() -> void:
	var carousel := await _carousel()
	var openings := 0
	for i in FOLDERS.size():
		carousel._consoles.select(i)
		var folder := carousel._consoles.selected().folder
		Fixtures.press(carousel, &"ui_accept")
		for frame in 600:
			if carousel.screen() == Carousel.Screen.GAMES:
				break
			Fixtures.step_frame(carousel)
			if carousel.screen() != Carousel.Screen.GAMES:
				openings += 1
				assert_bool(carousel._games_logo.visible).override_failure_message("logo over %s opening" % folder).is_false()
		assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
		var logo := carousel._games_logo
		assert_str(logo.texture.resource_path).ends_with("games-top/%s.png" % folder)
		assert_vector(logo.texture.get_size()).is_equal(Vector2(416, 101))
		assert_vector(logo.size).is_equal(Vector2(416, 101))
		assert_vector(logo.scale).is_equal(Vector2.ONE)
		assert_vector(logo.get_global_rect().size).is_equal(Vector2(416, 101))
		assert_vector(logo.get_global_rect().get_center()).is_equal_approx(Vector2(640, 97.28), Vector2.ONE * 0.01)
		Fixtures.press(carousel, &"screen_back")
		assert_bool(carousel._games_logo.visible).override_failure_message("logo over %s closing" % folder).is_false()
		for frame in 600:
			if carousel.screen() == Carousel.Screen.CONSOLES:
				break
			Fixtures.step_frame(carousel)
			assert_bool(carousel._games_logo.visible).override_failure_message("logo over %s closing" % folder).is_false()
	assert_int(openings).is_greater(12)


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
	for press in 120:
		carousel._consoles.step(-1 if press < 30 or random.randf() < 0.5 else 1)
		for frame in random.randi_range(0, 8):
			carousel._rail._process(1.0 / 60.0)
		_logos_match(carousel)
	for frame in 600:
		carousel._rail._process(1.0 / 60.0)
	assert_vector(carousel._rail.tile_at(carousel._consoles.selected_index())) \
		.is_equal_approx(Vector2(564.48, 711.68), Vector2.ONE * 0.01)


func test_every_pointed_and_held_console_keeps_the_ring_arrow_and_middle_inside_the_frame() -> void:
	var carousel := await _carousel()
	Fixtures.press(carousel, &"ui_down")
	var order := carousel._order
	assert_bool(await Screens.until(self, func() -> bool: return not order._busy)).is_true()
	for i in FOLDERS.size():
		order._wheel.point(i)
		for holding: bool in [false, true]:
			if holding:
				order._wheel.take()
			order._show()
			carousel._consoles.peel = 1.0 if holding else 0.0
			carousel._consoles._process(1.0)
			order._arrow_angle = order._arrow_to
			order._arrow_out = order._arrow_out_to
			order._place_marks()
			var arrow := order._arrow
			var bounds := Rect2(0, 0, 1280, 960)
			var head := order._arrow_shape([Vector2(0, 0), Vector2(12, 28), Vector2(0, 21), Vector2(-12, 28)])
			for point in head:
				var drawn := Rect2(arrow.get_global_transform() * point, Vector2.ZERO).grow(17.92)
				assert_bool(bounds.encloses(drawn)).override_failure_message("arrow outside on %s held=%s: %s" % [
					order._wheel.selected(), holding, drawn]).is_true()
			for k in carousel._shelves.size():
				var row := carousel._consoles
				var stand := row.ring_stand(k)
				var half := row.silhouette(k).size * CarouselLayout.FRAME * stand.size / 2.0
				assert_bool(bounds.encloses(Rect2(stand.centre - half, half * 2.0))).is_true()
			assert_bool(bounds.encloses(order._middle.get_global_rect())).is_true()
			if holding:
				order._wheel.let_go()
