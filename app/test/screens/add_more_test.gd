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


func test_A_on_the_button_adds_one_more_console_chosen_from_nothing_and_the_carousel_comes_back_on_it() -> void:
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


func test_the_added_console_is_saved_at_the_chosen_gap_and_the_consoles_come_back_in_that_order() -> void:
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


func test_the_first_form_does_not_offer_a_console_set_up_without_games() -> void:
	var shown := await _shown_with_no_games()
	var carousel: Carousel = shown[1]
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var list: Control = carousel.get_node("%Screens/AddConsole/%Choice")
	assert_bool(await Fixtures.until(self, func() -> bool: return list.visible)).is_true()
	assert_array(Array((list as StudioChooser).ids())).not_contains(["ps2"])


## Whether [param carousel]'s consoles show on every frame of the next [param seconds] of the game's time.
func _consoles_shown_for(carousel: Carousel, seconds: float) -> bool:
	var consoles: Node3D = carousel.get_node("%Consoles")
	var shown := true
	var waited := 0.0
	while waited < seconds:
		shown = shown and consoles.visible
		await await_idle_frame()
		waited += get_process_delta_time()
	return shown


## A device whose PS2 is set up with no game: the carousel stays on "No console".
func _shown_with_no_games() -> Array:
	var device := Fixtures.past_first_launch(self, {"ps2": 0})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	return [device, carousel]


## The form's life over the consoles, frame by frame: asked by the "+", it comes in over the consoles still in view,
## then covers them, the "+" closed; given up, they show again at once. Given up while it still comes in, they never
## hide; asked again then, the new form covers them in its turn.
func test_the_form_covers_the_consoles_once_in_and_gives_them_back_whether_given_up_before_or_after() -> void:
	var carousel: Carousel = (await _shown({"ps2": 3}))[1]
	var consoles: Node3D = carousel.get_node("%Consoles")
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	await Fixtures.hold(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_object(Fixtures.shown_screen(carousel)).is_null()
	assert_bool(_ball(carousel).is_open).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == form)).is_true()
	assert_bool(consoles.visible).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return not consoles.visible)).is_true()
	assert_bool(_ball(carousel).is_open).is_false()
	await Fixtures.hold(self, &"ui_up", false)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(consoles.visible).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)).is_true()
	await Fixtures.hold(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.hold(self, &"ui_up", false)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == form)).is_true()
	assert_bool(await _consoles_shown_for(carousel, (StudioTokens.TR_FORM_OPEN_S - StudioTokens.TR_FORM_AT_S) / 2.0)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _consoles_shown_for(carousel, StudioTokens.TR_FORM_OPEN_S + StudioTokens.TR_FORM_BACK_S)).is_true()
	assert_bool(Fixtures.shown_screen(carousel) == null and carousel._shown).is_true()
	await Fixtures.open_add_console(self, carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return not consoles.visible)).is_true()
