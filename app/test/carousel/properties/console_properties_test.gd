# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


## A device past its first launch with PS2 and GameCube games, its carousel on the consoles screen.
func _on_consoles(names: Dictionary[String, String] = {}) -> Array:
	var device := Fixtures.past_first_launch(self, {"ps2": 2, "gc": 1})
	device.console_names = names
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return [carousel, device]



func _open(carousel: Carousel) -> void:
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await Fixtures.settled_consoles(self, carousel)


## The keyboard of the selected console's name, open.
func _on_keyboard(carousel: Carousel) -> void:
	await _open(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.settled_consoles(self, carousel)


func test_X_stages_the_console_under_the_light_its_name_with_the_focus_and_B_puts_it_back() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	var properties := carousel._console_properties
	await _open(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)
	assert_float(carousel._consoles.stage).is_equal(1.0)
	assert_bool(carousel._console_title.visible and carousel._console_title.modulate.a > 0.0).is_false()
	assert_object(Fixtures.focus(self)).is_same(properties._name)
	assert_str(properties._name.text).is_equal(carousel._console_name.text)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.settled_consoles(self, carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_float(carousel._consoles.stage).is_equal(0.0)
	assert_bool(properties.visible).is_false()
	assert_bool(await Fixtures.until(self, func() -> bool:
		return carousel._console_title.visible and carousel._console_title.modulate.a == 1.0)).is_true()


func test_the_name_typed_and_kept_shows_on_the_consoles_screen_and_comes_back_with_the_library() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var properties := carousel._console_properties
	var own := carousel._console_name.text
	await _on_keyboard(carousel)
	assert_int(properties._step).is_equal(ConsoleProperties.Step.NAMING)
	assert_float(carousel._consoles.staged_lift).is_equal(ConsoleProperties._on_naming.height)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await Fixtures.settled_consoles(self, carousel)
	var named := own + " A"
	assert_str(device.console_names.get("ps2", "")).is_equal(named)
	assert_str(carousel._console_name.text).is_equal(named)
	assert_str(properties._name.text).is_equal(named)
	assert_object(Fixtures.focus(self)).is_same(properties._name)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.settled_consoles(self, carousel)
	# Read again, the library brings the name back.
	carousel._show_library(AndroidServices.LibraryAnswer.new({"ok": true, "library": device._library()}).library)
	assert_str(carousel._console_name.text).is_equal(named)
	# The consoles replaced are freed at the end of the frame.
	await await_idle_frame()


func test_a_name_erased_whole_gives_the_console_its_own_name() -> void:
	var setup := await _on_consoles({"ps2": "Mine"})
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var own: String = carousel._appearance.console_names["ps2"]
	await _on_keyboard(carousel)
	for letter in "Mine":
		await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_str(carousel._console_properties._naming._field.text).is_equal(own)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await Fixtures.settled_consoles(self, carousel)
	assert_bool(device.console_names.has("ps2")).is_false()
	assert_str(carousel._console_name.text).is_equal(own)


func test_B_on_the_keyboard_and_Start_on_a_name_left_as_it_was_change_nothing() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var own := carousel._console_name.text
	await _on_keyboard(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_X)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.settled_consoles(self, carousel)
	assert_int(carousel._console_properties._step).is_equal(ConsoleProperties.Step.PROPERTIES)
	assert_object(Fixtures.focus(self)).is_same(carousel._console_properties._name)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.settled_consoles(self, carousel)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await Fixtures.settled_consoles(self, carousel)
	assert_bool(device.console_names.is_empty()).is_true()
	assert_str(carousel._console_name.text).is_equal(own)


func test_a_name_that_cannot_be_kept_is_told_and_keys_pressed_meanwhile_count_for_nothing() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var properties := carousel._console_properties
	var told: Array[String] = []
	properties.rename_failed.connect(func() -> void: told.append("failed"))
	device.failing.append(&"rename_console")
	device.slow.append(&"rename_console")
	await _on_keyboard(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var typed := properties._naming.typed()
	await Fixtures.joypad(self, JOY_BUTTON_START)
	for press: JoyButton in [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B, JOY_BUTTON_START]:
		await Fixtures.joypad(self, press)
	assert_str(properties._naming.typed()).is_equal(typed)
	device.slow.clear()
	device.released.emit()
	await Fixtures.settled_consoles(self, carousel)
	assert_int(told.size()).is_equal(1)
	assert_int(properties._step).is_equal(ConsoleProperties.Step.NAMING)
	assert_str(properties._naming.typed()).is_equal(typed)
	assert_bool(Fixtures.focus(self) is Button and properties._naming.is_ancestor_of(Fixtures.focus(self))).is_true()


func test_INV_E7_02_whatever_is_pressed_and_when_the_console_s_properties_settle_on_one_whole_screen() -> void:
	var random := CarouselFixtures.cases(37)
	var carousel: Carousel = (await _on_consoles())[0]
	var properties := carousel._console_properties
	var presses: Array[JoyButton] = [JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_X, JOY_BUTTON_X, JOY_BUTTON_B,
		JOY_BUTTON_Y, JOY_BUTTON_START, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT]
	var seen: Dictionary[int, bool] = {}
	var rings := 0
	for attempt in 24:
		for press in random.randi_range(1, 4):
			await Fixtures.joypad(self, presses[random.randi() % presses.size()])
			for frame in random.randi_range(0, 8):
				await await_idle_frame()
		await Fixtures.settled_consoles(self, carousel)
		assert_bool(await Fixtures.until(self, func() -> bool:
			return carousel.screen() in [Carousel.Screen.CONSOLES, Carousel.Screen.CONSOLE_PROPERTIES, Carousel.Screen.GAMES,
				Carousel.Screen.ORDER])).is_true()
		var step := properties._step
		seen[step] = true
		rings += 1 if carousel.screen() == Carousel.Screen.ORDER else 0
		var staged := carousel.screen() == Carousel.Screen.CONSOLE_PROPERTIES
		assert_bool(staged).is_equal(step != ConsoleProperties.Step.CLOSED)
		assert_float(carousel._consoles.stage).is_equal(1.0 if staged else 0.0)
		assert_bool(properties.visible).is_equal(staged)
		var focused := Fixtures.focus(self)
		match step:
			ConsoleProperties.Step.CLOSED:
				assert_object(properties._staging).is_same(ConsoleProperties._in_row)
				assert_bool((carousel.get_node("%Light") as CanvasItem).visible).is_false()
				if carousel.screen() == Carousel.Screen.CONSOLES:
					# The consoles screen whole again: its title, its hints, no pill, the row.
					assert_bool(await Fixtures.until(self, func() -> bool:
						return carousel._console_title.visible and carousel._console_title.modulate.a == 1.0)).is_true()
					assert_float(carousel._pill.modulate.a).is_equal(0.0)
					assert_float(carousel._consoles.wheel).is_equal(0.0)
				elif carousel.screen() == Carousel.Screen.ORDER:
					# The ring whole, the consoles screen's title gone.
					assert_float(carousel._consoles.wheel).is_equal(1.0)
					assert_float(carousel._order.modulate.a).is_equal(1.0)
					assert_float(carousel._console_title.modulate.a).is_equal(0.0)
			ConsoleProperties.Step.PROPERTIES:
				assert_object(properties._staging).is_same(ConsoleProperties._on_properties)
				assert_bool((carousel.get_node("%Light") as CanvasItem).visible).is_true()
				assert_bool(carousel._console_title.visible).is_false()
				assert_bool(properties._naming.visible).is_false()
				assert_float(properties._properties.modulate.a).is_equal(1.0)
				assert_bool(focused in [properties._name, properties._change_place]).is_true()
			ConsoleProperties.Step.NAMING:
				assert_object(properties._staging).is_same(ConsoleProperties._on_naming)
				assert_bool(carousel._console_title.visible).is_false()
				assert_bool(properties._properties.visible).is_false()
				assert_float(properties._naming.modulate.a).is_equal(1.0)
				assert_bool(focused is Button and properties._naming.is_ancestor_of(focused)).is_true()
		# Out of the settings, the games or the ring, back to the consoles, so that the walk goes on.
		for press in 6:
			if Fixtures.shown_screen(carousel) == null and carousel._shown:
				break
			await Fixtures.joypad(self, JOY_BUTTON_B)
			await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)
		if carousel.screen() == Carousel.Screen.GAMES:
			await Fixtures.joypad(self, JOY_BUTTON_B)
			assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.CONSOLES)).is_true()
		# B lets go of a console held, then closes the ring.
		for press in 2:
			if carousel.screen() == Carousel.Screen.ORDER:
				await Fixtures.joypad(self, JOY_BUTTON_B)
				await Fixtures.settled_consoles(self, carousel)
		assert_int(carousel.screen()).is_not_equal(Carousel.Screen.ORDER)
		if is_failure():
			return
	assert_int(seen.size()).is_equal(3)
	assert_int(rings).is_greater(1)


func test_its_own_name_typed_back_is_no_name() -> void:
	var setup := await _on_consoles({"ps2": "Mine"})
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var own: String = carousel._appearance.console_names["ps2"]
	await _on_keyboard(carousel)
	carousel._console_properties._naming.open(own.replace(" ", "  "), own)
	await Fixtures.joypad(self, JOY_BUTTON_START)
	await Fixtures.settled_consoles(self, carousel)
	assert_bool(device.console_names.has("ps2")).is_false()
	assert_bool(carousel._console_names.has("ps2")).is_false()
	assert_str(carousel._console_name.text).is_equal(own)


func test_stepping_between_consoles_never_shows_the_pill_over_them() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	for press in 3:
		await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
		for frame in 10:
			await await_idle_frame()
		assert_float(carousel._pill.modulate.a).is_equal(0.0)


func test_a_name_given_before_shows_from_the_start_on_its_console_only() -> void:
	var carousel: Carousel = (await _on_consoles({"ps2": "Mine"}))[0]
	var properties := carousel._console_properties
	assert_str(carousel._console_name.text).is_equal("Mine")
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._consoles.selected_index() == 1)).is_true()
	assert_str(carousel._console_name.text).is_equal(carousel._own_console_name("gc"))
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_LEFT)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._console_name.text == "Mine")).is_true()
	await _on_keyboard(carousel)
	assert_str(properties._name.text).is_equal("Mine")
	assert_str(properties._naming.typed()).is_equal("Mine")

