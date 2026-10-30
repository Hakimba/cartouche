# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")

## The window the suites share is put back as it was: some tests of other folders measure in its size.
var _window := Vector2i.ZERO


func before_test() -> void:
	_window = get_window().size


func after_test() -> void:
	get_window().size = _window
	StudioTokens.TR_REVERSE = 0


## A device past its first launch with PS2, GameCube and Game Boy Advance games, in that order, its
## carousel on the consoles screen, on the PS2.
func _on_consoles(device: Fixtures.NewDevice = null) -> Array:
	if device == null:
		device = Fixtures.past_first_launch(self, {"ps2": 2, "gc": 1, "gba": 1})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return [carousel, device]


func _press(carousel: Carousel, button: JoyButton) -> void:
	await Fixtures.joypad(self, button)
	await Fixtures.settled_consoles(self, carousel)


## The console of each platform on the consoles screen, by platform id.
func _consoles_of(carousel: Carousel) -> Dictionary[String, ConsoleRow.Item]:
	var consoles: Dictionary[String, ConsoleRow.Item] = {}
	for i in carousel._shelves.size():
		consoles[carousel._shelves[i].platform_id] = carousel._consoles._items[i]
	return consoles


## The consoles screen as it should be: each shelf's console at its place in the row, the one
## selected the shelf shown, its games behind.
func _assert_row(carousel: Carousel, consoles: Dictionary[String, ConsoleRow.Item]) -> void:
	assert_dict(_consoles_of(carousel)).is_equal(consoles)
	var shown := carousel._shelves[carousel._shelf].platform_id
	assert_str(carousel._platform_ids()[carousel._consoles.selected_index()]).is_equal(shown)
	assert_str(carousel._row.selected_game().platform_id).is_equal(shown)


## Where console [param slot] of the ring shows on the screen.
func _on_screen(carousel: Carousel, slot: int) -> Vector2:
	return carousel._consoles.ring_point(slot)


## The logo picture of [param slot] ("ring-middle", "between-mini") for the console of [param platform_id].
func _logo_of(carousel: Carousel, slot: String, platform_id: String) -> Texture2D:
	return load("res://studio/logos/%s/%s.png" % [slot, carousel._consoles.console_at(carousel._platform_ids().find(platform_id)).folder])


## The texts the ring's middle shows now.
func _words(order: ConsoleOrder) -> Array[String]:
	var words: Array[String] = []
	for word: Control in order._middle.find_children("*", "Control", true, false):
		if word is ConsoleOrder.Word and word.is_visible_in_tree():
			words.append((word as ConsoleOrder.Word).shown())
	return words


func test_down_opens_the_ring_on_the_selected_console_and_B_closes_it_on_the_one_the_cursor_is_on() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	var order := carousel._order
	assert_bool(carousel._arrange_hint.visible).is_true()
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.ORDER)
	assert_float(carousel._consoles.wheel).is_equal(1.0)
	assert_float(carousel._console_title.modulate.a).is_equal(0.0)
	assert_object(order._logo.texture).is_same(_logo_of(carousel, "ring-middle", "ps2"))
	assert_array(_words(order)).is_empty()
	assert_bool(order._choosing.visible and not order._moving.visible).is_true()
	assert_int(carousel._consoles.pointed).is_equal(0)
	# The cursor jumps at once: no slide, no move of the consoles.
	await _press(carousel, JOY_BUTTON_DPAD_RIGHT)
	assert_int(carousel._consoles.pointed).is_equal(1)
	assert_object(order._logo.texture).is_same(_logo_of(carousel, "ring-middle", "gc"))
	assert_array(carousel._consoles.wheel_slots).is_equal([0, 1, 2])
	await _press(carousel, JOY_BUTTON_B)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_float(carousel._consoles.wheel).is_equal(0.0)
	assert_bool(order.visible).is_false()
	assert_int(carousel._consoles.selected_index()).is_equal(1)
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("gc")
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._console_title.modulate.a == 1.0)).is_true()
	# And the consoles screen works as before.
	await _press(carousel, JOY_BUTTON_X)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)


func test_inv_15_a_console_taken_and_moved_shows_the_order_at_once_and_A_keeps_it_after_a_restart_too() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var order := carousel._order
	var consoles := _consoles_of(carousel)
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	await _press(carousel, JOY_BUTTON_DPAD_RIGHT)
	await _press(carousel, JOY_BUTTON_DPAD_RIGHT)
	await _press(carousel, JOY_BUTTON_A)
	assert_int(carousel._consoles.held).is_equal(2)
	assert_bool(order._moving.visible and not order._choosing.visible).is_true()
	assert_array(_words(order)).is_equal([tr("in its place", &"ring")])
	# It peels off: drawn as a sticker only, apart from the others.
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._consoles.peel == 1.0)).is_true()
	await await_idle_frame()
	for part in carousel._consoles.peeled_geometry():
		assert_int(part.layers).is_equal(ConsoleLayer.STICKER)
	assert_array(order._sticker._drawn).is_not_empty()
	# It passes the GameCube, then the PS2: each slides into its place at once.
	await _press(carousel, JOY_BUTTON_DPAD_LEFT)
	assert_array(carousel._consoles.wheel_slots).is_equal([0, 2, 1])
	assert_array(_words(order)).is_equal(["entre", "et"] if TranslationServer.get_locale().begins_with("fr") else ["between", "and"])
	assert_object(order._before.texture).is_same(_logo_of(carousel, "between-mini", "ps2"))
	assert_object(order._after.texture).is_same(_logo_of(carousel, "between-mini", "gc"))
	await _press(carousel, JOY_BUTTON_DPAD_LEFT)
	assert_array(carousel._consoles.wheel_slots).is_equal([1, 2, 0])
	assert_array(device.orders).is_empty()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	# Put down, it lies flat again before it is drawn with the others.
	assert_bool(carousel._consoles.peel > 0.0 and not carousel._consoles.peeled_geometry().is_empty()).is_true()
	await Fixtures.settled_consoles(self, carousel)
	assert_array(device.orders).is_equal([PackedStringArray(["gba", "ps2", "gc"])])
	assert_array(carousel._platform_ids()).is_equal(["gba", "ps2", "gc"])
	# Each console went with its shelf, standing where it was round the ring.
	assert_dict(_consoles_of(carousel)).is_equal(consoles)
	assert_array(carousel._consoles.wheel_slots).is_equal([0, 1, 2])
	assert_bool(await Fixtures.until(self, func() -> bool:
		return carousel._consoles.peel == 0.0 and range(3).all(func(i: int) -> bool:
			return absf(wrapf(carousel._consoles._slid[i] - i, -1.5, 1.5)) < 0.01))).is_true()
	for part in carousel._consoles._items[0].geometry:
		assert_int(part.layers).is_equal(ConsoleLayer.FRONT)
	await _press(carousel, JOY_BUTTON_B)
	_assert_row(carousel, consoles)
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("gba")
	# Read again, the library has the consoles in that order.
	carousel.queue_free()
	await await_idle_frame()
	var restarted: Carousel = (await _on_consoles(device))[0]
	assert_array(restarted._platform_ids()).is_equal(["gba", "ps2", "gc"])


func test_closed_on_another_console_than_the_one_moved_the_consoles_screen_is_on_it() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	var consoles := _consoles_of(carousel)
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	for button: JoyButton in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_A,
			JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_B]:
		await _press(carousel, button)
	assert_array(carousel._platform_ids()).is_equal(["gc", "ps2", "gba"])
	_assert_row(carousel, consoles)
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("ps2")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	assert_str(carousel._row.selected_game().platform_id).is_equal("ps2")


func test_a_console_taken_then_put_down_where_it_was_changes_nothing() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	for button: JoyButton in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, JOY_BUTTON_A, JOY_BUTTON_B]:
		await _press(carousel, button)
	assert_array(device.orders).is_empty()
	assert_array(carousel._platform_ids()).is_equal(["ps2", "gc", "gba"])
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("gba")


func test_B_on_a_console_held_gives_back_the_order_as_it_was_the_cursor_on_it() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT]:
		await _press(carousel, button)
	assert_array(carousel._consoles.wheel_slots).is_equal([2, 0, 1])
	await _press(carousel, JOY_BUTTON_B)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.ORDER)
	assert_array(carousel._consoles.wheel_slots).is_equal([0, 1, 2])
	assert_int(carousel._order._wheel.cursor).is_equal(0)
	assert_int(carousel._consoles.held).is_equal(-1)
	assert_array(device.orders).is_empty()


func test_an_order_that_cannot_be_kept_is_told_and_the_ring_goes_back_to_the_order_before() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var told: Array[bool] = []
	carousel._order.order_failed.connect(func() -> void: told.append(true))
	device.failing.append(&"order_consoles")
	device.slow.append(&"order_consoles")
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	await _press(carousel, JOY_BUTTON_A)
	await _press(carousel, JOY_BUTTON_DPAD_RIGHT)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	# Nothing counts while the plugin keeps it.
	for button: JoyButton in [JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A, JOY_BUTTON_B]:
		await Fixtures.joypad(self, button)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.ORDER)
	device.slow.clear()
	device.released.emit()
	await Fixtures.settled_consoles(self, carousel)
	assert_int(told.size()).is_equal(1)
	assert_bool(carousel._message.visible).is_true()
	assert_array(carousel._consoles.wheel_slots).is_equal([0, 1, 2])
	assert_array(carousel._platform_ids()).is_equal(["ps2", "gc", "gba"])
	assert_str(carousel._order._wheel.selected()).is_equal("ps2")


func test_change_place_in_a_console_s_properties_opens_the_ring_on_it_and_y_does_not() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	await _press(carousel, JOY_BUTTON_DPAD_RIGHT)
	await _press(carousel, JOY_BUTTON_X)
	await _press(carousel, JOY_BUTTON_Y)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)
	assert_object(Fixtures.focus(self)).is_same(carousel._console_properties._change_place)
	await _press(carousel, JOY_BUTTON_A)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.ORDER)
	assert_str(carousel._order._wheel.selected()).is_equal("gc")
	assert_int(carousel._console_properties._step).is_equal(ConsoleProperties.Step.CLOSED)
	assert_bool(carousel._console_properties.visible).is_false()
	assert_float(carousel._consoles.stage).is_equal(0.0)
	assert_float(carousel._console_title.modulate.a).is_equal(0.0)
	await _press(carousel, JOY_BUTTON_B)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	# The consoles screen whole again, though the properties had hidden its title.
	assert_bool(await Fixtures.until(self, func() -> bool:
		return carousel._console_title.visible and carousel._console_title.modulate.a == 1.0)).is_true()
	await _press(carousel, JOY_BUTTON_X)
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	assert_object(Fixtures.focus(self)).is_same(carousel._console_properties._change_place)
	await _press(carousel, JOY_BUTTON_A)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.ORDER)


func test_a_console_alone_has_no_order_to_be_put_in() -> void:
	var carousel: Carousel = (await _on_consoles(Fixtures.past_first_launch(self, {"gc": 2})))[0]
	assert_bool(carousel._arrange_hint.visible).is_false()
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	await _press(carousel, JOY_BUTTON_X)
	assert_bool(carousel._console_properties._change_place.visible).is_false()
	for button: JoyButton in [JOY_BUTTON_Y, JOY_BUTTON_DPAD_DOWN]:
		await _press(carousel, button)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)
	assert_object(Fixtures.focus(self)).is_same(carousel._console_properties._properties)


func test_by_touch_a_drag_moves_the_cursor_a_tap_takes_a_console_and_another_puts_it_down() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	var start := Vector2(640.0, 880.0)
	await Fixtures.touch(self, [start, start + Vector2(170.0, 0.0)])
	assert_int(carousel._order._wheel.cursor).is_equal(1)
	assert_int(carousel._consoles.held).is_equal(-1)
	# A tap off the consoles takes none.
	await Fixtures.touch(self, [Vector2(40.0, 140.0)])
	assert_int(carousel._consoles.held).is_equal(-1)
	await Fixtures.touch(self, [_on_screen(carousel, 2)])
	assert_int(carousel._order._wheel.cursor).is_equal(2)
	assert_int(carousel._consoles.held).is_equal(2)
	await Fixtures.touch(self, [start, start - Vector2(170.0, 0.0)])
	await Fixtures.touch(self, [Vector2(40.0, 140.0)])
	await Fixtures.settled_consoles(self, carousel)
	assert_array(device.orders).is_equal([PackedStringArray(["ps2", "gba", "gc"])])


func test_whatever_is_pressed_the_ring_shows_every_console_once_where_the_order_has_it() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var random := CarouselFixtures.cases(93)
	var presses: Array[JoyButton] = [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A,
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN]
	var consoles_by_id := _consoles_of(carousel)
	var told: Array[bool] = []
	carousel._order.order_failed.connect(func() -> void: told.append(true))
	var held := 0
	for attempt in 40:
		# For a while, no order can be kept.
		if attempt == 15:
			device.failing.append(&"order_consoles")
		elif attempt == 25:
			device.failing.clear()
		for press in random.randi_range(1, 5):
			var button := presses[random.randi() % presses.size()]
			# A on the consoles screen goes into the games: the ring is what this walk is for.
			var on_consoles := carousel.screen() == Carousel.Screen.CONSOLES
			await Fixtures.joypad(self, JOY_BUTTON_DPAD_DOWN if button == JOY_BUTTON_A and on_consoles else button)
			for frame in random.randi_range(0, 6):
				await await_idle_frame()
		await Fixtures.settled_consoles(self, carousel)
		var consoles := carousel._consoles
		assert_array(carousel._platform_ids()).is_equal(Array(device.consoles.keys(), TYPE_STRING, &"", null))
		assert_dict(_consoles_of(carousel)).is_equal(consoles_by_id)
		if carousel.screen() != Carousel.Screen.ORDER:
			assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
			assert_float(consoles.wheel).is_equal(0.0)
			assert_int(consoles.held).is_equal(-1)
			_assert_row(carousel, consoles_by_id)
			continue
		var wheel := carousel._order._wheel
		var slots: Array[int] = []
		for platform_id in carousel._platform_ids():
			slots.append(wheel.order.find(platform_id))
		assert_array(slots).contains_exactly_in_any_order(range(slots.size()))
		assert_array(consoles.wheel_slots).is_equal(slots)
		if not wheel.is_holding():
			assert_array(wheel.order).is_equal(carousel._platform_ids())
		assert_float(consoles.wheel).is_equal(1.0)
		assert_int(consoles.pointed).is_equal(carousel._platform_ids().find(wheel.selected()))
		assert_int(consoles.held).is_equal(consoles.pointed if wheel.is_holding() else -1)
		assert_bool(carousel._order._moving.visible).is_equal(wheel.is_holding())
		held += 1 if wheel.is_holding() else 0
		if is_failure():
			return
	assert_int(held).is_greater(5)
	assert_int(device.orders.size()).is_greater(2)
	assert_int(told.size()).is_greater(0)


func test_a_platform_without_a_model_has_no_place_on_the_ring_and_keeps_its_place_in_the_order() -> void:
	var unmodelled_device := Fixtures.past_first_launch(self, {"ps2": 1, "psp": 1, "gc": 1, "dreamcast": 1, "gba": 1})
	for id: String in ["psp", "dreamcast"]:
		unmodelled_device.catalog.platforms.append(AndroidServices.Platform.new({"id": id, "name": id, "media": "dvd"}))
	var setup := await _on_consoles(unmodelled_device)
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var ids := carousel._platform_ids()
	var unmodelled: Array[String] = []
	for k in ids.size():
		if not carousel._consoles.console_at(k).modelled:
			unmodelled.append(ids[k])
	assert_array(unmodelled).is_not_empty()
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	var wheel := carousel._order._wheel
	assert_int(wheel.order.size()).is_equal(ids.size() - unmodelled.size())
	for k in ids.size():
		assert_bool(carousel._consoles.wheel_slots[k] >= 0).is_equal(ids[k] not in unmodelled)
		assert_bool(carousel._consoles.console_at(k).model.visible).is_equal(ids[k] not in unmodelled)
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_A]:
		await _press(carousel, button)
	var kept: Array[String] = []
	kept.assign(device.orders[0])
	for platform_id in unmodelled:
		assert_int(kept.find(platform_id)).is_equal(ids.find(platform_id))
	assert_array(kept).contains_exactly_in_any_order(ids)
	assert_array(kept).is_not_equal(ids)


func test_presses_during_the_glides_in_and_out_change_nothing_and_the_ring_closes_once() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	var order := carousel._order
	var closings: Array[int] = []
	order.closed.connect(func() -> void: closings.append(1))
	CarouselFixtures.press(carousel, &"ui_down")
	# During the way in: A takes nothing, B closes nothing.
	for action: StringName in [&"ui_accept", &"screen_back", &"ui_accept"]:
		order._unhandled_input(CarouselFixtures.button(action, true))
	assert_int(carousel._consoles.held).is_equal(-1)
	assert_bool(await Fixtures.until(self, func() -> bool: return order._open and not order._busy)).is_true()
	assert_bool(order._wheel.is_holding()).is_false()
	order._unhandled_input(CarouselFixtures.button(&"screen_back", true))
	# During the way out: A and B again and again.
	for action: StringName in [&"ui_accept", &"screen_back", &"ui_accept", &"screen_back", &"carousel_right"]:
		order._unhandled_input(CarouselFixtures.button(action, true))
		await await_idle_frame()
		assert_int(carousel._consoles.held).is_equal(-1)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.CONSOLES)).is_true()
	await get_tree().create_timer(0.3).timeout
	assert_int(closings.size()).is_equal(1)
	assert_int(carousel._consoles.held).is_equal(-1)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
