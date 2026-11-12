# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const ScreenFixtures := preload("res://test/screens/fixtures.gd")
const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_the_art_bar_follows_a_run_greys_while_it_waits_and_fades_once_it_is_over() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var progress: ArtBar = carousel.get_node("%ArtProgress")
	var bar: ProgressBar = carousel.get_node("%Bar")
	var content: Control = carousel.get_node("%Content")
	var tell := func(payload: Dictionary) -> void:
		carousel._on_art_changed(AndroidServices.ArtChange.new({"progress": payload}))
		# The bar moves on its tween: moved to its end here, rather than waited for.
		if progress._tween:
			progress._tween.custom_step(ArtBar._STEP_S + 0.01)
	tell.call({"done": 0, "total": 0})
	assert_bool(progress.visible).is_false()
	tell.call({"done": 12, "total": 55})
	assert_bool(progress.visible).is_true()
	assert_float(bar.value).is_equal(12.0)
	assert_float(bar.max_value).is_equal(55.0)
	assert_str(bar.theme_type_variation).is_equal("ArtBar")
	for stall: String in ["offline", "refused", "storage"]:
		tell.call({"done": 12, "total": 55, "stall": stall})
		assert_float(bar.value).is_equal(12.0)
		assert_str(bar.theme_type_variation).is_equal("ArtBarStalled")
	# A launch failure's message shows where the bar is: the bar hides for it.
	carousel._show_message("No emulator.")
	assert_bool(content.visible).is_false()
	carousel._on_message_timer_timeout()
	assert_bool(content.visible).is_true()
	tell.call({"done": 55, "total": 55})
	assert_float(bar.value).is_equal(55.0)
	assert_bool(progress.visible).is_true()
	progress._tween.custom_step(ArtBar._FULL_S + ArtBar._FADE_S + 0.1)
	assert_bool(progress.visible).is_false()
	# A later run with nothing to look for shows nothing.
	tell.call({"done": 0, "total": 0})
	assert_bool(progress.visible).is_false()


func test_the_battery_shows_its_level_and_the_bolt_exactly_while_plugged_in_as_soon_as_told() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var chip: BatteryChip = carousel.get_node("%Battery")
	var tell := func(payload: Dictionary) -> void: carousel.android.battery_changed.emit(AndroidServices.Battery.new(payload))
	tell.call({"level_percent": 57, "plugged": false})
	assert_str(chip.text).is_equal("57 %")
	assert_array(chip.bolt()).is_empty()
	tell.call({"level_percent": 57, "plugged": true})
	assert_str(chip.text).is_equal("57 %")
	assert_array(chip.bolt()).is_not_empty()
	tell.call({"plugged": true})
	assert_str(chip.text).is_empty()
	assert_array(chip.bolt()).is_not_empty()
	tell.call({"level_percent": 57, "plugged": false})
	assert_str(chip.text).is_equal("57 %")
	assert_array(chip.bolt()).is_empty()


func test_while_labels_download_the_app_does_not_rest_once_they_wait_or_are_over_it_does() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var tell := func(payload: Dictionary) -> void:
		carousel._on_art_changed(AndroidServices.ArtChange.new({"progress": payload}))
	assert_bool(carousel._resting.moving.call()).is_false()
	for stall: String in ["offline", "refused", "storage"]:
		tell.call({"done": 3, "total": 50})
		assert_bool(carousel._resting.moving.call()).is_true()
		tell.call({"done": 3, "total": 50, "stall": stall})
		assert_bool(carousel._resting.moving.call()).is_false()
	tell.call({"done": 4, "total": 50})
	assert_bool(carousel._resting.moving.call()).is_true()
	tell.call({"done": 50, "total": 50})
	assert_bool(carousel._resting.moving.call()).is_false()


func test_the_carousel_coming_in_wakes_the_app() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	carousel._resting._process(7.0)
	assert_float(carousel._resting.pace).is_equal(0.0)
	carousel._come_in()
	assert_float(carousel._resting.pace).is_equal(1.0)
	assert_bool(OS.low_processor_usage_mode).is_false()


func test_selection_priority_waits_for_the_last_selection_and_follows_a_shelf_change() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 6, "gc": 1})
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	await ScreenFixtures.wait(self, func() -> bool: return carousel.is_shown())
	await ScreenFixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	await ScreenFixtures.wait(self, func() -> bool: return carousel._art_focus.is_stopped())
	device.art_focus_calls.clear()
	await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	assert_array(device.art_focus_calls).is_empty()
	await ScreenFixtures.wait(self, func() -> bool: return device.art_focus_calls.size() == 1)
	assert_array(device.art_focus_calls).is_equal([PackedStringArray(["ps2/2", "ps2/3", "ps2/1"])])
	await ScreenFixtures.press_to(self, carousel, JOY_BUTTON_B, Carousel.Screen.CONSOLES)
	device.art_focus_calls.clear()
	await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await ScreenFixtures.wait(self, func() -> bool: return device.art_focus_calls.size() == 1)
	assert_array(device.art_focus_calls).is_equal([PackedStringArray(["gc/0"])])


func test_the_selection_priority_timer_sends_nothing_for_an_empty_row() -> void:
	var device := ScreenFixtures.past_first_launch(self, {})
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	await await_idle_frame()
	device.art_focus_calls.clear()
	assert_bool(carousel._row.has_games()).is_false()
	carousel._art_focus.start()
	await ScreenFixtures.wait(self, func() -> bool: return carousel._art_focus.is_stopped())
	assert_array(device.art_focus_calls).is_empty()


func test_the_games_told_absent_are_known_so_and_a_download_told_rings_until_it_is_over() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var games: Array[AndroidServices.Game] = carousel._row._games
	# A game of another shelf too.
	var absent := PackedStringArray([games[0].id, "gba/other"])
	carousel._on_art_changed(AndroidServices.ArtChange.new({"progress": {"done": 1, "total": 3}, "absent": absent}))
	assert_bool(carousel._art.is_absent(games[0])).is_true()
	assert_bool(carousel._art.is_absent(games[1])).is_false()
	carousel._on_art_progress(AndroidServices.LabelDownload.new({"game_id": games[1].id, "running": true, "fraction": 0.5}))
	assert_dict(carousel._row._downloads).is_equal({games[1].id: 0.5})
	carousel._on_art_progress(AndroidServices.LabelDownload.new({"game_id": games[1].id}))
	assert_dict(carousel._row._downloads).is_empty()
