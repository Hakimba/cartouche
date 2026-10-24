# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Screens := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func test_the_games_screen_takes_the_saved_float_setting_and_lands_the_flying_logo_on_its_exact_box() -> void:
	var device := Screens.past_first_launch(self, {"ps2": 5})
	device.games_float = true
	var carousel := Screens.fresh_carousel(self, device)
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_bool(carousel._row.games_float).is_true()
	assert_bool(carousel._games_logo.visible).is_false()
	CarouselFixtures.press(carousel, &"ui_accept")
	CarouselFixtures.step_until(carousel, Carousel.Screen.GAMES)
	carousel._row._process(0.0)
	assert_bool(carousel._games_logo.visible).is_true()
	assert_bool(carousel._rail.visible).is_false()
	assert_vector(carousel._games_logo.get_rect().get_center()).is_equal_approx(Vector2(640.0, 97.28), Vector2.ONE * 0.01)
	assert_str(carousel._games_logo.texture.resource_path).ends_with("games-top/ps2_slim.png")
	assert_str(carousel._title.text).is_equal(carousel._row.selected_game().title)
	assert_float(carousel._pill._wanted_top).is_equal_approx(carousel._row.title_top(), 0.01)
	assert_bool(carousel._games_hints.visible).is_true()
	carousel._process(0.0)
	assert_float(carousel._room.environment.ambient_light_energy).is_equal_approx(carousel._row.room_energy, 1e-6)
	CarouselFixtures.press(carousel, &"screen_back")
	CarouselFixtures.step_until(carousel, Carousel.Screen.CONSOLES)
	carousel._process(0.0)
	assert_float(carousel._room.environment.ambient_light_energy).is_equal_approx(0.55, 1e-6)
	assert_bool(carousel._games_logo.visible).is_false()
	assert_bool(carousel._rail.visible).is_true()


func test_closing_settings_reads_the_new_float_choice_before_showing_the_games_again() -> void:
	var device := Screens.past_first_launch(self, {"ps2": 5})
	var carousel := Screens.fresh_carousel(self, device)
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_bool(carousel._row.games_float).is_false()
	CarouselFixtures.press(carousel, &"ui_accept")
	CarouselFixtures.step_until(carousel, Carousel.Screen.GAMES)
	CarouselFixtures.press(carousel, &"open_settings")
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await Screens.until(self, func() -> bool:
		return menu.is_visible_in_tree() and menu.state == SettingsMenu.State.OPEN)).is_true()
	for step in 3:
		await Screens.action(self, &"ui_down")
	await Screens.joypad(self, JOY_BUTTON_A)
	assert_bool(await Screens.until(self, func() -> bool: return device.games_float)).is_true()
	await Screens.joypad(self, JOY_BUTTON_B)
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_bool(carousel._row.games_float).is_true()
	assert_int(carousel._screen).is_equal(Carousel.Screen.GAMES)


func test_each_supported_console_places_the_title_under_the_actual_game_seen_by_the_screen_camera() -> void:
	var counts: Dictionary[String, int] = {}
	for manifest in ConsoleManifest.found():
		counts[manifest.platform] = 5
	assert_int(counts.size()).is_equal(12)
	var device := Screens.past_first_launch(self, counts)
	var carousel := Screens.fresh_carousel(self, device)
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	var seen: Array[String] = []
	for console in counts.size():
		var platform := carousel._shelves[carousel._shelf].platform_id
		assert_bool(platform in seen).is_false()
		seen.append(platform)
		CarouselFixtures.press(carousel, &"ui_accept")
		CarouselFixtures.step_until(carousel, Carousel.Screen.GAMES)
		carousel._row._process(0.0)
		var place: ShelfRow.Place = carousel._row._placed[carousel._row.selected_index()]
		var lowest := -INF
		for mesh: MeshInstance3D in place.shown.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					lowest = maxf(lowest, carousel._camera.unproject_position(mesh.global_transform * vertex).y)
		assert_float(carousel._pill._wanted_top).override_failure_message("%s pill=%f mesh=%f viewport=%s row=%s" % [
			platform, carousel._pill._wanted_top, lowest, carousel.get_viewport_rect().size, carousel._row.transform]) \
			.is_equal_approx(lowest + 20.48, 1.0)
		CarouselFixtures.press(carousel, &"screen_back")
		CarouselFixtures.step_until(carousel, Carousel.Screen.CONSOLES)
		CarouselFixtures.press(carousel, &"carousel_right")
		CarouselFixtures.step_frames(carousel, 60)
	assert_array(seen).contains_exactly_in_any_order(counts.keys())


func test_the_games_room_light_stays_on_over_the_properties_where_the_medium_is_in_the_main_world() -> void:
	var device := Screens.past_first_launch(self, {"ps2": 5})
	var carousel := Screens.fresh_carousel(self, device)
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	CarouselFixtures.press(carousel, &"ui_accept")
	CarouselFixtures.step_until(carousel, Carousel.Screen.GAMES)
	CarouselFixtures.press(carousel, &"open_properties")
	assert_int(carousel._screen).is_equal(Carousel.Screen.PROPERTIES)
	CarouselFixtures.step_frames(carousel, 30)
	assert_float(carousel._room.environment.ambient_light_energy).is_equal_approx(carousel._row.room_energy, 1e-6)
	assert_float(carousel._room.environment.ambient_light_energy).is_not_equal(0.55)


func test_optional_floating_keeps_normal_frame_pacing_until_still_and_redraws_only_the_selected_game() -> void:
	var device := Screens.past_first_launch(self, {"ps2": 5})
	device.games_float = true
	var carousel := Screens.fresh_carousel(self, device)
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	CarouselFixtures.press(carousel, &"ui_accept")
	CarouselFixtures.step_until(carousel, Carousel.Screen.GAMES)
	carousel._row.set_process(false)
	for frame in 20:
		carousel._row._process(1.0 / 60.0)
	for frame in 120:
		for place in carousel._row._places:
			if place.media_view:
				place.media_view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
		carousel._row._process(1.0 / 60.0)
		for place in carousel._row._places:
			if place.game < 0 or not place.media_view:
				continue
			assert_int(place.media_view.view().render_target_update_mode).is_equal(
				SubViewport.UPDATE_ONCE if place.game == carousel._row.selected_index() else SubViewport.UPDATE_DISABLED)
	var resting := carousel._resting
	resting.set_process(false)
	resting.stays_awake = false
	resting.wake()
	for frame in 400:
		resting._process(1.0 / 60.0)
		if resting.pace > 0.0:
			assert_bool(OS.low_processor_usage_mode).is_false()
	assert_float(resting.pace).is_equal(0.0)
	assert_bool(OS.low_processor_usage_mode).is_true()
	resting.wake()
	assert_float(carousel._row.pace).is_equal(1.0)
	assert_bool(OS.low_processor_usage_mode).is_false()
	carousel._row.games_float = false
	for frame in 130:
		resting._process(1.0 / 60.0)
	assert_bool(OS.low_processor_usage_mode).is_true()
	resting.wake()
