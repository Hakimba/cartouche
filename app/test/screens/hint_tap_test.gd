# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## A finger lifted on a button hint shown whole presses that button, as the pad would: what only a hint offered
## (the settings with Y, Edit with X, B on a page) is in a finger's reach, and every guard of the pad holds for it.

const Fixtures := preload("res://test/screens/fixtures.gd")


func after_test() -> void:
	Controls.style = &"xbox"


## Where [param hint] shows, in the screen's own pixels.
func _centre(hint: Node) -> Vector2:
	var shown := hint as Control
	return shown.get_global_transform_with_canvas() * (shown.size / 2.0)


func test_the_settings_hint_tapped_on_the_games_screen_opens_the_settings() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	await Fixtures.settled(self, carousel)
	var hints: Control = carousel.get_node("%GamesHints")
	await Fixtures.wait(self, func() -> bool: return hints.modulate.a == 1.0)
	await Fixtures.touch(self, [_centre(hints.get_node(^"Settings"))])
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()


func test_a_hint_tapped_while_its_page_holds_its_presses_does_nothing() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.answers[Fixtures.Request.SAVE_GAMES_FLOAT] = Fixtures.Answer.HELD
	var carousel := await Fixtures.shown(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	await Fixtures.wait(self, func() -> bool: return menu.state == SettingsMenu.State.OPEN)
	for step in 4:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(menu.held.pending()).is_true()
	await Fixtures.touch(self, [_centre(menu.get_node(^"Hints/Hint"))])
	for frame in 10:
		await await_idle_frame()
	assert_int(menu.state).is_equal(SettingsMenu.State.OPEN)
	device.release()
	await Fixtures.touch(self, [_centre(menu.get_node(^"Hints/Hint"))])
	await Fixtures.wait(self, func() -> bool: return not menu.is_visible_in_tree())


func test_a_faded_hint_takes_no_tap() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.settled(self, carousel)
	var hints: Control = carousel.get_node("%GamesHints")
	assert_float(hints.modulate.a).is_equal(0.0)
	await Fixtures.touch(self, [_centre(hints.get_node(^"Settings"))])
	for frame in 10:
		await await_idle_frame()
	assert_bool(carousel.is_shown()).is_true()
	assert_object(Fixtures.shown_screen(carousel)).is_null()
