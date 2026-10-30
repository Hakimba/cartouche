# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Screens := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


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


func test_floating_games_keep_the_app_awake_until_still_then_let_it_rest() -> void:
	var device := Screens.past_first_launch(self, {"ps2": 5})
	device.games_float = true
	var carousel := Screens.fresh_carousel(self, device)
	assert_bool(await Screens.until(self, func() -> bool: return carousel._shown)).is_true()
	CarouselFixtures.press(carousel, &"ui_accept")
	CarouselFixtures.step_until(carousel, Carousel.Screen.GAMES)
	var resting := carousel._resting
	resting.set_process(false)
	resting.stays_awake = false
	resting.wake()
	var frames := 0
	while not OS.low_processor_usage_mode:
		assert_int(frames).is_less(1000)
		resting._process(1.0 / 60.0)
		frames += 1
		if resting.pace > 0.0:
			assert_bool(OS.low_processor_usage_mode).is_false()
	assert_float(resting.pace).is_equal(0.0)
	resting.wake()
	assert_float(carousel._row.pace).is_equal(1.0)
	assert_bool(OS.low_processor_usage_mode).is_false()
	carousel._row.games_float = false
	for frame in 130:
		resting._process(1.0 / 60.0)
	assert_bool(OS.low_processor_usage_mode).is_true()
	resting.wake()
