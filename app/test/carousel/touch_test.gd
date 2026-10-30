# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")
## Beside the console or game in the middle, by touch; held this long, a finger long-presses.
const BESIDE := Vector2(420.0, 0.0)
const HELD_S := 0.7
## Where the image of a region found for the games is.
const EUROPE := "user://touch-test-europe.png"
## The screens a finger reaches.
const REACHABLE: Array[Carousel.Screen] = [Carousel.Screen.CONSOLES, Carousel.Screen.GAMES, Carousel.Screen.PROPERTIES,
	Carousel.Screen.CONSOLE_PROPERTIES]


func before() -> void:
	var image := Image.create_empty(32, 32, false, Image.FORMAT_RGB8)
	image.fill(Color.RED)
	image.save_png(EUROPE)


func after() -> void:
	DirAccess.remove_absolute(EUROPE)


## A device past its first launch with PS2, GameCube and Game Boy Advance games, its carousel on
## the consoles screen.
func _on_consoles() -> Array:
	var device := Fixtures.past_first_launch(self, {"ps2": 6, "gc": 1, "gba": 1})
	device.variants = [
		{"region": "Europe", "source": "launchbox", "source_name": "LaunchBox", "path": ProjectSettings.globalize_path(EUROPE)},
		{"region": "USA", "source": "launchbox", "source_name": "LaunchBox"},
	]
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return [carousel, device]


func _settled(carousel: Carousel) -> void:
	assert_bool(await Fixtures.until(self, func() -> bool:
		return (carousel.screen() not in [Carousel.Screen.ENTERING, Carousel.Screen.LEAVING]
			and not carousel._properties._busy and not carousel._console_properties._busy))).is_true()
	await await_idle_frame()


## The carousel on the PS2's games, by touch.
func _on_games() -> Array:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	await Fixtures.touch(self, [carousel._selected_point()])
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	return setup


func test_on_the_consoles_screen_a_tap_beside_moves_to_a_console_and_one_on_it_goes_in() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	await Fixtures.touch(self, [carousel._selected_point() + BESIDE])
	assert_int(carousel._consoles.selected_index()).is_equal(1)
	await Fixtures.touch(self, [carousel._selected_point() - BESIDE])
	assert_int(carousel._consoles.selected_index()).is_equal(0)
	await Fixtures.touch(self, [carousel._selected_point()])
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	assert_str(carousel._row.selected_game().platform_id).is_equal("ps2")


func test_on_the_games_screen_a_tap_beside_moves_one_game_and_one_on_the_disc_launches_nothing() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await Fixtures.touch(self, [carousel._selected_point() + BESIDE])
	assert_int(carousel._row.selected_index()).is_equal(1)
	await Fixtures.touch(self, [carousel._selected_point() - BESIDE])
	assert_int(carousel._row.selected_index()).is_equal(0)
	var screens: Array[Carousel.Screen] = []
	carousel.screen_changed.connect(screens.append)
	await Fixtures.touch(self, [carousel._selected_point()])
	await _settled(carousel)
	assert_array(screens).is_empty()
	assert_int(device.launches).is_equal(0)


func test_A_still_launches_the_game_which_the_fake_device_counts() -> void:
	var device: Fixtures.NewDevice = (await _on_games())[1]
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.launches == 1)).is_true()


func test_a_finger_down_as_the_app_pauses_is_forgotten() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	await Fixtures.finger(self, carousel._selected_point(), true)
	carousel.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	Fixtures.clock.ms += 1000
	for frame in 3:
		await await_idle_frame()
	await Fixtures.finger(self, carousel._selected_point(), false)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


func test_a_drag_on_the_disc_turns_it_and_a_long_press_opens_its_properties() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var centre := carousel._selected_point()
	await Fixtures.finger(self, centre, true)
	await Fixtures.finger_to(self, centre + Vector2(0.0, 120.0))
	await await_idle_frame()
	assert_bool(carousel._row._turn.of(0).is_equal_approx(Basis.IDENTITY)).is_false()
	assert_int(carousel._row.selected_index()).is_equal(0)
	await Fixtures.finger(self, centre + Vector2(0.0, 120.0), false)
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.PROPERTIES)


func test_in_a_game_s_properties_a_tap_on_the_label_lists_its_images_and_one_on_an_image_keeps_it() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	var properties := carousel._properties
	await Fixtures.touch(self, [properties._zone.get_global_rect().get_center()])
	await _settled(carousel)
	assert_int(properties._step).is_equal(DiscProperties.Step.LABELS)
	var europe: LabelCard
	for card in properties._chooser._cards.get_children():
		if card is LabelCard and (card as LabelCard).region == "Europe":
			europe = card
	await Fixtures.touch(self, [europe.get_global_rect().get_center()])
	await _settled(carousel)
	assert_array(device.chosen_labels).is_equal(["launchbox/Europe"])
	assert_int(properties._step).is_equal(DiscProperties.Step.PROPERTIES)


func test_a_tap_on_the_name_opens_its_keyboard_and_one_on_a_key_types_it() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	var properties := carousel._properties
	await Fixtures.touch(self, [properties._name.get_global_rect().get_center()])
	await _settled(carousel)
	assert_int(properties._step).is_equal(DiscProperties.Step.NAMING)
	var typed := properties._naming.typed()
	var key := properties._naming._keyboard.find_children("*", "Button", true, false)[0] as Button
	await Fixtures.touch(self, [key.get_global_rect().get_center()])
	# The caret starts before the name: the key goes first.
	assert_str(properties._naming.typed()).is_equal(key.text + typed)


## The system's back, asked once, and the screens settled after it.
func _back(carousel: Carousel) -> void:
	carousel.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	for frame in 3:
		await await_idle_frame()
	await _settled(carousel)


## A second finger, or a touch the system takes back, at [param at]: neither counts.
func _stray_touch(at: Vector2, canceled: bool) -> void:
	await Fixtures.finger(self, at, true, 0 if canceled else 1)
	await Fixtures.finger(self, at, false, 0 if canceled else 1, canceled)


func test_the_system_s_back_is_B_on_the_games_the_ring_and_both_properties_screens() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	await Fixtures.touch(self, [carousel._properties._zone.get_global_rect().get_center()])
	await _settled(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	await _back(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.PROPERTIES)
	await _back(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	await _back(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) != null)).is_true()
	await _back(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool:
		return Fixtures.shown_screen(carousel) == null and carousel._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_DPAD_DOWN)
	await Fixtures.settled_consoles(self, carousel)
	await _back(carousel)
	await Fixtures.settled_consoles(self, carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)
	# A tap beside the console and its action does nothing.
	await Fixtures.touch(self, [Vector2(120.0, 300.0)])
	await _settled(carousel)
	assert_int(carousel._console_properties._step).is_equal(ConsoleProperties.Step.PROPERTIES)
	await _back(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


func test_inv_20_inv_22_whatever_a_finger_does_nothing_is_launched_and_every_screen_takes_the_next_press() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	var random := CarouselFixtures.cases(77)
	var touched: Dictionary[int, bool] = {}
	var taps_on_disc := 0
	for gesture in 90:
		var at := Vector2(random.randf_range(0.0, 1280.0), random.randf_range(0.0, 960.0))
		if random.randf() < 0.4:
			at = carousel._selected_point() + Vector2(random.randf_range(-200.0, 200.0), random.randf_range(-200.0, 200.0))
		if random.randf() < 0.1:
			await _stray_touch(at, random.randf() < 0.5)
		elif carousel.screen() == Carousel.Screen.GAMES and random.randf() < 0.3:
			# The tap that must never launch: right on the disc.
			await Fixtures.touch(self, [carousel._selected_point()])
			taps_on_disc += 1
		else:
			var path: Array[Vector2] = [at]
			for move in random.randi_range(0, 3):
				path.append(path[-1] + Vector2(random.randf_range(-400.0, 400.0), random.randf_range(-150.0, 150.0)))
			await Fixtures.touch(self, path, HELD_S if random.randf() < 0.15 else 0.0)
		await _settled(carousel)
		assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.alive(carousel))).is_true()
		touched[carousel.screen()] = true
		assert_int(device.launches).is_equal(0)
		# Back from the screens a finger does not reach (the ring, the settings), and now and then
		# from any, so that the walk goes on.
		if carousel.screen() not in REACHABLE or Fixtures.shown_screen(carousel) != null or random.randf() < 0.15:
			await Fixtures.joypad(self, JOY_BUTTON_B)
			await _settled(carousel)
		if is_failure():
			return
	for screen in REACHABLE:
		assert_bool(touched.has(screen)).override_failure_message(str(Carousel.Screen.keys()[screen])).is_true()
	assert_int(taps_on_disc).is_greater(5)
