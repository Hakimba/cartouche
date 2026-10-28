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


func test_a_console_taken_and_moved_shows_the_order_at_once_and_A_keeps_it_after_a_restart_too() -> void:
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
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._consoles.peel == 0.0)).is_true()
	await await_idle_frame()
	for i in 3:
		assert_float(absf(wrapf(carousel._consoles._slid[i] - i, -1.5, 1.5))).is_less(0.01)
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


func test_consoles_put_in_a_new_order_keep_where_they_stand_and_how_they_are_turned() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	var row := carousel._consoles
	var items := row._items.duplicate()
	row._turn.index = 1
	row.pointed = 1
	row._slid.assign([0.0, 1.5, 2.0])
	row.reorder([2, 0, 1] as Array[int])
	assert_array(row._items).is_equal([items[2], items[0], items[1]])
	assert_array(row._slid).is_equal([2.0, 0.0, 1.5])
	assert_int(row.selected_index()).is_equal(1)
	assert_int(row._turn.index).is_equal(2)
	assert_int(row.pointed).is_equal(2)
	assert_int(row.held).is_equal(-1)


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


func test_by_touch_one_console_for_every_160_pixels_dragged_and_nothing_while_the_ring_is_busy() -> void:
	var setup := await _on_consoles(Fixtures.past_first_launch(self, {"ps2": 1, "gc": 1, "gba": 1, "psx": 1, "n64": 1}))
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var wheel := func() -> ConsoleWheel: return carousel._order._wheel
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	var start := Vector2(300.0, 880.0)
	await Fixtures.touch(self, [start, start + Vector2(100.0, 0.0), start + Vector2(300.0, 0.0), start + Vector2(500.0, 0.0), start])
	assert_int(wheel.call().cursor).is_equal(0)
	await Fixtures.touch(self, [start, start + Vector2(500.0, 0.0)])
	assert_int(wheel.call().cursor).is_equal(3)
	await _press(carousel, JOY_BUTTON_B)
	# Dragged as the ring opens: nothing, then one more stretch once open, one step.
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_DOWN)
	await Fixtures.finger(self, start, true)
	await Fixtures.finger_to(self, start + Vector2(170.0, 0.0))
	await Fixtures.settled_consoles(self, carousel)
	assert_int(wheel.call().cursor).is_equal(carousel._consoles.selected_index())
	await Fixtures.finger_to(self, start + Vector2(340.0, 0.0))
	await Fixtures.finger(self, start + Vector2(340.0, 0.0), false)
	assert_int(wheel.call().cursor).is_equal(carousel._consoles.selected_index() + 1)
	# A tap while the plugin keeps an order takes nothing.
	device.slow.append(&"order_consoles")
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_DPAD_RIGHT]:
		await _press(carousel, button)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.touch(self, [_on_screen(carousel, 0)])
	device.slow.clear()
	device.released.emit()
	await Fixtures.settled_consoles(self, carousel)
	assert_int(carousel._consoles.held).is_equal(-1)
	assert_int(device.orders.size()).is_equal(1)


func test_INV_E7_09_whatever_is_pressed_the_ring_shows_every_console_once_where_the_order_has_it() -> void:
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


## The ring open on [param ids]' consoles, every move done.
func _weight(row: ConsoleRow, index: int) -> float:
	return RingFit.weight_of(row.console_at(index).folder)


func _ring_of(ids: Dictionary[String, int]) -> Carousel:
	# The design's own frame: a headless window is 64 x 64, whose square view shows the 3D scene larger.
	get_window().size = Vector2i(1280, 960)
	await await_idle_frame()
	var carousel: Carousel = (await _on_consoles(Fixtures.past_first_launch(self, ids)))[0]
	await _press(carousel, JOY_BUTTON_DPAD_DOWN)
	assert_bool(await Fixtures.until(self, func() -> bool:
		return carousel._consoles.wheel == 1.0 and carousel._consoles.others_wheel == 1.0 and carousel._consoles.ring_scale == carousel._consoles.ring_target)).is_true()
	return carousel


func test_INV_E12_S4_01_the_ring_stands_every_console_at_even_angles_at_its_real_size_on_the_one_scale() -> void:
	var ids: Dictionary[String, int] = {"ps2": 1, "psx": 1, "nes": 1, "gc": 1, "wii": 1, "gba": 1, "xbox360": 1}
	var carousel := await _ring_of(ids)
	var row := carousel._consoles
	var count := row._items.size()
	var boxes: Array[Rect2] = []
	var weights := PackedFloat64Array()
	var angles := PackedFloat64Array()
	for k in count:
		boxes.append(row.silhouette(k))
		weights.append(RingFit.weight_of(row.console_at(k).folder))
		angles.append(k * TAU / count)
	var scale := RingFit.scale(boxes, weights, angles, 12.5 / 0.552)
	assert_float(row.ring_scale).is_equal_approx(scale, 1e-3)
	for k in count:
		var stand := row.ring_stand(k)
		var grown := 1.0 + (0.06 if k == row.pointed else 0.0)
		assert_vector(stand.centre).override_failure_message("centre of %d" % k).is_equal_approx(
			Vector2(640.0 + 390.4 * sin(angles[k]), 471.04 + 325.12 * cos(angles[k])), Vector2.ONE * 0.01)
		assert_vector(row.ring_point(k)).is_equal_approx(row.to_view(stand.centre), Vector2.ONE * 0.01)
		assert_float(stand.size).override_failure_message("size of %d" % k).is_equal_approx(
			scale * weights[k] * (1.0 + 0.045 * cos(angles[k])) * grown / 100.0, 1e-3)
		assert_float(stand.opacity).is_equal(1.0)


func test_the_fit_follows_the_order_and_the_arrow_stands_beyond_the_console_pointed_at() -> void:
	var ids: Dictionary[String, int] = {"ps2": 1, "psx": 1, "nes": 1, "snes": 1, "n64": 1, "gc": 1, "wii": 1, "xbox": 1, "xbox360": 1}
	var carousel := await _ring_of(ids)
	var order := carousel._order
	var row := carousel._consoles
	var angle := 0.0
	var reach := RingFit.ext(row.silhouette(0), _weight(row, 0), row.ring_target, angle)
	assert_float(order._arrow_out_to).is_equal_approx(reach + 14.08, 1e-3)
	assert_float(order._arrow_to).is_equal(0.0)
	await _press(carousel, JOY_BUTTON_DPAD_RIGHT)
	var count := row._items.size()
	angle = TAU / count
	reach = RingFit.ext(row.silhouette(1), _weight(row, 1), row.ring_target, angle)
	assert_float(order._arrow_to).is_equal_approx(angle, 1e-6)
	assert_float(order._arrow_angle).override_failure_message("the arrow jumps to the next choice").is_equal_approx(angle, 1e-6)
	assert_float(order._arrow_out_to).is_equal_approx(reach + 14.08, 1e-3)
	# Held, it stands further out, and the held console's stand is 23.04 px above its place.
	await _press(carousel, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return row.peel == 1.0)).is_true()
	reach = RingFit.ext(row.silhouette(1), _weight(row, 1), row.ring_target, angle)
	assert_float(order._arrow_out_to).is_equal_approx(reach + 20.48, 1e-3)
	assert_vector(row.ring_stand(1).centre).is_equal_approx(RingFit.place(angle) - Vector2(0.0, 23.04), Vector2.ONE * 0.01)
	# The order changed, the scale is fitted again to the boxes where they now stand.
	await _press(carousel, JOY_BUTTON_DPAD_RIGHT)
	var boxes: Array[Rect2] = []
	var weights := PackedFloat64Array()
	var angles := PackedFloat64Array()
	for slot in count:
		var index := carousel._platform_ids().find(order._wheel.order[slot])
		boxes.append(row.silhouette(index))
		weights.append(_weight(row, index))
		angles.append(slot * TAU / count)
	assert_float(row.ring_target).is_equal_approx(RingFit.scale(boxes, weights, angles, 12.5 / 0.552), 1e-6)


## The seconds the game's clock runs, as the tweens count them, until [param done] (at most 5).
func _clock_until(done: Callable) -> float:
	var seconds := 0.0
	while not done.call() and seconds < 5.0:
		await get_tree().process_frame
		seconds += get_tree().root.get_process_delta_time()
	return seconds


func test_the_ring_opens_in_0_4_s_and_closes_in_0_62_s_the_rail_rising_half_way() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	var order := carousel._order
	var rail := carousel._rail
	CarouselFixtures.press(carousel, &"ui_down")
	var opening := await _clock_until(func() -> bool: return order._open and not order._busy)
	assert_float(opening).is_between(0.3, 0.5)
	assert_float(rail.sunk).is_equal(1.0)
	var done: Array[bool] = [false]
	order.closed.connect(func() -> void: done[0] = true)
	order._unhandled_input(CarouselFixtures.button(&"screen_back", true))
	var early := await _clock_until(func() -> bool: return rail.sunk < 1.0)
	# The rail waits half the close to rise.
	assert_float(early).is_between(0.3, 0.45)
	# And the console pointed at is still on its way to the hero's place, on the 620 ms glide.
	assert_float(carousel._consoles.wheel).is_between(0.03, 0.6)
	var closing := early + await _clock_until(func() -> bool: return done[0])
	assert_float(closing).is_between(0.58, 0.72)
	assert_bool(await Fixtures.until(self, func() -> bool: return rail.sunk == 0.0)).is_true()


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


func test_INV_E12_S4_01_the_console_pointed_at_keeps_the_room_grown_as_the_ring_grows_it() -> void:
	var ids: Dictionary[String, int] = {"ps2": 1, "psx": 1, "nes": 1, "snes": 1, "n64": 1, "gc": 1, "wii": 1, "xbox": 1, "xbox360": 1}
	var carousel := await _ring_of(ids)
	var row := carousel._consoles
	for step in row._items.size():
		assert_bool(await Fixtures.until(self, func() -> bool: return row.ring_scale == row.ring_target)).is_true()
		var rects: Array[Rect2] = []
		for k in row._items.size():
			var stand := row.ring_stand(k)
			var box := row.silhouette(k)
			var frame := box.size * Vector2(1280.0, 960.0) * stand.size
			# The pointed console is drawn at its grown size, the others as the fit assumes them grown.
			var grown := frame * (1.06 / (1.06 if k == row.pointed else 1.0))
			rects.append(Rect2(stand.centre - grown / 2.0, grown))
		for i in rects.size():
			for j in range(i + 1, rects.size()):
				var gap := maxf(maxf(rects[j].position.x - rects[i].end.x, rects[i].position.x - rects[j].end.x),
					maxf(rects[j].position.y - rects[i].end.y, rects[i].position.y - rects[j].end.y))
				assert_float(gap).override_failure_message("%d and %d" % [i, j]).is_greater(15.36 - 0.5)
		await _press(carousel, JOY_BUTTON_DPAD_RIGHT)


func test_two_consoles_stand_at_the_cap_whatever_their_boxes() -> void:
	var ids: Dictionary[String, int] = {"ps2": 1, "xbox360": 1}
	var carousel := await _ring_of(ids)
	assert_float(carousel._consoles.ring_target).is_equal_approx(12.5 / 0.552, 1e-4)


func test_B_during_opening_rewinds_the_ring_from_its_current_position_when_enabled() -> void:
	StudioTokens.TR_REVERSE = 1
	var carousel: Carousel = (await _on_consoles())[0]
	var order := carousel._order
	var closed: Array[int] = []
	order.closed.connect(func() -> void: closed.append(1))
	CarouselFixtures.press(carousel, &"ui_down")
	order._transition.custom_step(0.14)
	var wheel := carousel._consoles.wheel
	var others := carousel._consoles.others_wheel
	order._unhandled_input(CarouselFixtures.button(&"screen_back", true))
	assert_float(carousel._consoles.wheel).is_equal(wheel)
	assert_float(carousel._consoles.others_wheel).is_equal(others)
	assert_bool(await Fixtures.until(self, func() -> bool: return not order._busy)).is_true()
	assert_float(carousel._consoles.wheel).is_equal(0.0)
	assert_float(carousel._consoles.others_wheel).is_equal(0.0)
	assert_int(closed.size()).is_equal(1)
	assert_bool(order.visible).is_false()


func test_rewind_after_50_ms_restores_the_rail_before_the_short_close_finishes() -> void:
	StudioTokens.TR_REVERSE = 1
	var carousel: Carousel = (await _on_consoles())[0]
	CarouselFixtures.press(carousel, &"ui_down")
	carousel._order._transition.custom_step(0.05)
	carousel._rail.sunk = 1.0
	carousel._order._unhandled_input(CarouselFixtures.button(&"screen_back", true))
	await get_tree().create_timer(0.2).timeout
	assert_float(carousel._rail.sunk).is_equal_approx(0.0, 0.01)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
