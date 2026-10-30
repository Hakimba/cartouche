# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func _on_consoles(counts: Dictionary[String, int] = {"ps2": 2, "gc": 1}) -> Carousel:
	var carousel := Fixtures.fresh_carousel(self, Fixtures.past_first_launch(self, counts))
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return carousel


func _open(carousel: Carousel) -> void:
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await Fixtures.settled_consoles(self, carousel)


func test_console_properties_stage_the_console_with_its_logo_and_order_action_and_B_restores_it() -> void:
	var carousel := await _on_consoles()
	await _open(carousel)
	var properties := carousel._console_properties
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)
	assert_float(carousel._consoles.stage).is_equal(1.0)
	# The PS2 has other models: its model takes the focus first, above the order action.
	assert_object(Fixtures.focus(self)).is_same(properties._model)
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_DOWN)
	assert_object(Fixtures.focus(self)).is_same(properties._change_place)
	assert_bool(properties.get_node_or_null("%Name") == null).is_true()
	assert_bool(properties.get_node_or_null("%Naming") == null).is_true()
	assert_bool(properties.get_node_or_null("%Logo") == null).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.settled_consoles(self, carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_float(carousel._consoles.stage).is_equal(0.0)


func test_a_console_alone_has_no_order_action_and_no_press_opens_a_name_editor() -> void:
	var carousel := await _on_consoles({"gc": 2})
	await _open(carousel)
	var properties := carousel._console_properties
	assert_bool(properties._change_place.visible).is_false()
	assert_bool(properties._model.visible).is_false()
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_START, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_Y]:
		await Fixtures.joypad(self, button)
		assert_int(properties._step).is_equal(ConsoleProperties.Step.PROPERTIES)
	assert_object(Fixtures.focus(self)).is_same(properties._properties)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.settled_consoles(self, carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


func test_inv_20_a_random_console_properties_walk_settles_on_a_whole_screen_without_renaming() -> void:
	var carousel := await _on_consoles()
	var random := CarouselFixtures.cases(37)
	var buttons: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]
	var rings := 0
	for attempt in 24:
		if carousel.screen() == Carousel.Screen.CONSOLES:
			await _open(carousel)
		for press in random.randi_range(1, 4):
			await Fixtures.joypad(self, buttons[random.randi() % buttons.size()])
		await Fixtures.settled_consoles(self, carousel)
		assert_bool(carousel.screen() in [Carousel.Screen.CONSOLE_PROPERTIES, Carousel.Screen.ORDER]).is_true()
		assert_bool(carousel._console_properties.get_node_or_null("%Naming") == null).is_true()
		if carousel.screen() == Carousel.Screen.ORDER:
			rings += 1
			assert_float(carousel._consoles.wheel).is_equal(1.0)
		else:
			assert_float(carousel._consoles.stage).is_equal(1.0)
			var properties := carousel._console_properties
			var focused := Fixtures.focus(self)
			assert_bool(focused in [properties._model, properties._change_place] or focused.get_parent() == properties._variants) \
				.override_failure_message(str(focused)).is_true()
		for press in 3:
			if carousel.screen() == Carousel.Screen.CONSOLES:
				break
			await Fixtures.joypad(self, JOY_BUTTON_B)
			await Fixtures.settled_consoles(self, carousel)
		assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
		assert_float(carousel._consoles.stage).is_equal(0.0)
	assert_int(rings).is_greater(1)
