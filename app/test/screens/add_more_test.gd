# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## One more console, from the consoles screen: up turns the "+" ball into "Add a platform", A
## opens the form, and the console added is the one the carousel comes back on.

const Fixtures := preload("res://test/screens/fixtures.gd")


## The carousel shown on a device whose library holds [param consoles] (games by platform id),
## an emulator installed for every platform.
func _shown(consoles: Dictionary[String, int]) -> Array:
	var device := Fixtures.past_first_launch(self, consoles)
	device.players_everywhere = true
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return [device, carousel]


## The ring placing the console added, once the console is in the middle and a gap can be chosen.
func _placing(carousel: Carousel) -> void:
	assert_bool(await Fixtures.until(self, func() -> bool:
		var placing: Placing = carousel._order._placing
		return placing != null and placing.state == Placing.State.CHOOSING)).is_true()


func _ball(carousel: Carousel) -> AddBall:
	return carousel.get_node("%AddBall")


func test_the_button_shows_only_while_up_is_held() -> void:
	var carousel: Carousel = (await _shown({"ps2": 3, "gba": 2}))[1]
	await Fixtures.hold(self, &"ui_up")
	assert_bool(_ball(carousel).is_open).is_true()
	await Fixtures.hold(self, &"ui_up", false)
	assert_bool(_ball(carousel).is_open).is_false()
	# Held, then a move: the ball comes back, the next console shows.
	await Fixtures.hold(self, &"ui_up")
	await Fixtures.action(self, &"carousel_right")
	assert_bool(_ball(carousel).is_open).is_false()
	await Fixtures.hold(self, &"ui_up", false)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	# Not held, A goes into the console as ever.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	assert_object(Fixtures.shown_screen(carousel)).is_null()


func test_INV_E6_07_A_on_the_button_adds_one_more_console_chosen_from_nothing_and_the_carousel_comes_back_on_it() -> void:
	var shown := await _shown({"ps2": 3})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	# Only the media of the library's consoles are loaded: the PS2's disc.
	assert_array(carousel._appearance._models.keys()).contains_exactly(["ps2_dvd"])
	await Fixtures.open_add_console(self, carousel)
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	assert_str((form.get_node("%Title") as Label).text).is_equal("Add a console")
	# Nothing chosen in advance; a console set up already is not offered again.
	assert_str(form.platform_id).is_empty()
	assert_str((form.get_node("%Type") as StepField).text).is_equal("Choose…")
	assert_str((form.get_node("%Emulator") as StepField).text).is_equal("Choose…")
	assert_str(Fixtures.focus(self).name).is_equal("Type")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var list: Control = form.get_node("%Choice")
	assert_bool(await Fixtures.until(self, func() -> bool: return list.visible)).is_true()
	assert_array(Array((list as StudioChooser).ids())).not_contains(["ps2"])
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.choose_console(self, carousel, device, "gba")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	var added := form.platform_id
	device.order = PackedStringArray(["ps2"])
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)).is_true()
	assert_array(device.placed).is_empty()
	assert_bool(carousel._order.is_open()).is_false()
	assert_bool(device.consoles.has(added)).is_true()
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal(added)
	assert_array(carousel._appearance._models.keys()).contains_exactly_in_any_order(["ps2_dvd", "gba_cart"])
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_true()
	assert_bool(_ball(carousel).is_open).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()


func test_INV_E12_07_the_added_console_is_saved_at_the_chosen_gap_and_the_consoles_come_back_in_that_order() -> void:
	var shown := await _shown({"ps2": 3, "gc": 1})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	device.order = PackedStringArray(["ps2", "gc"])
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.choose_console(self, carousel, device, "gba")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _placing(carousel)
	# The first gap is after the last console; one step right is after the first: between the PS2 and the GameCube.
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)).is_true()
	assert_array(device.placed).is_equal([["gba", 1]])
	assert_array(device.order).is_equal(PackedStringArray(["ps2", "gba", "gc"]))
	assert_array(carousel._platform_ids()).is_equal(["ps2", "gba", "gc"])
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("gba")


func test_the_button_turns_into_the_form_s_first_field_as_the_rail_sinks_and_the_card_flies_back_into_the_ball_when_given_up() -> void:
	var carousel: Carousel = (await _shown({"ps2": 3}))[1]
	await Fixtures.hold(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.hold(self, &"ui_up", false)
	var entry: FormEntry = carousel._form_entry
	var card: Control = entry.get_child(0)
	# Flying from the button, 330 x 46 round the ball's place, to the first field.
	assert_bool(card.visible).is_true()
	assert_vector(card.size).is_less(Vector2(FormEntry.FIELD.size.x, 1000.0))
	assert_bool(await Fixtures.until(self, func() -> bool: return not card.visible)).is_true()
	# The design's first field: 41 / 16 cqw, 56 x 6.4 cqw (1 cqw is 12.8 px).
	assert_vector(card.position).is_equal_approx(Vector2(41.0, 16.0) * 12.8, Vector2.ONE * 0.01)
	assert_vector(card.size).is_equal_approx(Vector2(56.0, 6.4) * 12.8, Vector2.ONE * 0.01)
	assert_float(carousel._rail.sunk).is_equal(1.0)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	# Back: the card leaves the field for the ball, the rail rises.
	assert_bool(await Fixtures.until(self, func() -> bool: return card.visible)).is_true()
	# As the form fades: the consoles are already back under it.
	assert_bool((carousel.get_node("%Screens/AddConsole") as Control).is_visible_in_tree()).is_true()
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return not card.visible)).is_true()
	var ball := carousel.get_node("%AddBall") as AddBall
	assert_vector(card.position + card.size / 2.0).is_equal_approx(ball.get_global_rect().get_center(), Vector2.ONE * 0.01)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._rail.sunk == 0.0)).is_true()


func test_the_form_given_up_leaves_the_consoles_as_they_were() -> void:
	var shown := await _shown({"ps2": 3})
	var device: Fixtures.NewDevice = shown[0]
	var carousel: Carousel = shown[1]
	await Fixtures.open_add_console(self, carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)).is_true()
	assert_array(device.set_up).is_empty()
	assert_int(carousel._shelves.size()).is_equal(1)
	assert_bool(_ball(carousel).is_open).is_false()
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_true()


func test_the_button_stays_while_either_the_stick_or_the_d_pad_holds_up_and_goes_on_a_pause() -> void:
	var carousel: Carousel = (await _shown({"ps2": 3}))[1]
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_UP
	pad.pressed = true
	Input.parse_input_event(pad)
	await await_idle_frame()
	assert_bool(_ball(carousel).is_open).is_true()
	# The stick, back to the centre meanwhile, lets nothing go.
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	await await_idle_frame()
	assert_bool(_ball(carousel).is_open).is_true()
	# Paused while held: the release never comes, the ball is back once the app is.
	carousel.propagate_notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_bool(_ball(carousel).is_open).is_false()
	pad.pressed = false
	Input.parse_input_event(pad)
	await await_idle_frame()


func test_INV_E6_07_the_first_form_does_not_offer_a_console_set_up_without_games() -> void:
	var shown := await _shown_with_no_games()
	var carousel: Carousel = shown[1]
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var list: Control = carousel.get_node("%Screens/AddConsole/%Choice")
	assert_bool(await Fixtures.until(self, func() -> bool: return list.visible)).is_true()
	assert_array(Array((list as StudioChooser).ids())).not_contains(["ps2"])


## A device whose PS2 is set up with no game: the carousel stays on "No console".
func _shown_with_no_games() -> Array:
	var device := Fixtures.past_first_launch(self, {"ps2": 0})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	return [device, carousel]
