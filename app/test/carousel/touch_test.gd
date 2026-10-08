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
	device.variants = [{"region": "Europe", "path": ProjectSettings.globalize_path(EUROPE)}, {"region": "USA"}]
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


func test_on_the_consoles_screen_a_swipe_anywhere_moves_one_console_even_on_the_console_which_does_not_turn() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	var start := carousel._selected_point() + Vector2(0.0, 300.0)
	await Fixtures.touch(self, [start, start - Vector2(330.0, 0.0), start - Vector2(660.0, 0.0)])
	assert_int(carousel._consoles.selected_index()).is_equal(1)
	await Fixtures.touch(self, [start, start - Vector2(90.0, 0.0)])
	assert_int(carousel._consoles.selected_index()).is_equal(2)
	# Once the console has come to the middle: a swipe on it moves one back, and it never turns.
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(carousel._consoles._scroll, 2.0))).is_true()
	var centre := carousel._selected_point()
	await Fixtures.finger(self, centre, true)
	await Fixtures.finger_to(self, centre + Vector2(150.0, 0.0))
	await await_idle_frame()
	assert_bool(carousel._consoles._turn.of(2).is_equal_approx(Basis.IDENTITY)).is_true()
	assert_int(carousel._consoles.selected_index()).is_equal(1)
	await Fixtures.finger(self, centre + Vector2(150.0, 0.0), false)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


func test_a_long_press_on_the_console_opens_its_properties() -> void:
	var carousel: Carousel = (await _on_consoles())[0]
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)


func test_on_the_games_screen_a_tap_beside_moves_one_game_and_one_on_the_disc_launches_nothing() -> void:
	var setup := await _on_games()
	var carousel: Carousel = setup[0]
	var device: Fixtures.NewDevice = setup[1]
	await Fixtures.touch(self, [carousel._selected_point() + BESIDE])
	assert_int(carousel._row.selected_index()).is_equal(1)
	await Fixtures.touch(self, [carousel._selected_point() - BESIDE])
	assert_int(carousel._row.selected_index()).is_equal(0)
	await Fixtures.touch(self, [carousel._selected_point()])
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	assert_int(device.launches).is_equal(0)


func test_on_the_games_screen_a_swipe_beside_moves_one_game_however_long_or_fast() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var start := carousel._selected_point() + Vector2(400.0, 250.0)
	# Too short to be a swipe: past the slop, not 80 pixels.
	await Fixtures.touch(self, [start, start - Vector2(70.0, 0.0)])
	assert_int(carousel._row._position).is_equal(0)
	await Fixtures.touch(self, [start, start - Vector2(90.0, 0.0)])
	assert_int(carousel._row._position).is_equal(1)
	# Long: one game.
	await Fixtures.touch(self, [start, start - Vector2(330.0, 0.0), start - Vector2(660.0, 0.0), start - Vector2(400.0, 0.0)])
	assert_int(carousel._row._position).is_equal(2)
	# Back and further the other way: still the one game it first went to.
	await Fixtures.touch(self, [start, start - Vector2(330.0, 0.0), start, start + Vector2(400.0, 0.0)])
	assert_int(carousel._row._position).is_equal(3)
	# Fast: 400 pixels in one frame, then lifted while moving; the shelf comes to rest one further.
	await Fixtures.touch(self, [start, start - Vector2(400.0, 0.0)])
	assert_int(carousel._row._position).is_equal(4)
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(carousel._row._scroll, 4.0))).is_true()
	assert_int(carousel._row._position).is_equal(4)
	# Held still beside before it moves: a pause, not a long press.
	await Fixtures.finger(self, start, true)
	Fixtures.clock.ms += int(HELD_S * 1000.0)
	await await_idle_frame()
	await Fixtures.finger_to(self, start - Vector2(200.0, 0.0))
	await Fixtures.finger(self, start - Vector2(200.0, 0.0), false)
	assert_int(carousel._row._position).is_equal(5)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)


func test_INV_E7_11_whatever_a_swipe_beside_does_it_moves_one_game_the_way_it_first_went_far() -> void:
	var carousel: Carousel = (await _on_games())[0]
	var random := CarouselFixtures.cases(111)
	var moved := {-1: 0, 0: 0, 1: 0}
	for case in 30:
		# Beside on either side; first past the slop, so that it is never a tap.
		var side := CarouselFixtures.direction(random)
		var start := carousel._selected_point() + Vector2(400.0 * side, 250.0)
		var path: Array[Vector2] = [start, start + Vector2(0.0, Finger.SLOP)]
		# Short or long moves, fast or slow, back and forth, staying on the screen.
		for move in random.randi_range(1, 5):
			path.append(start + Vector2(random.randf_range(-900.0, 200.0) * side * random.randf(), random.randf_range(-60.0, 60.0)))
		# The way the finger first went 80 pixels from where it came down, worked out here.
		var way := 0
		for point in path:
			if way == 0 and absf(point.x - start.x) >= 80.0:
				way = 1 if point.x < start.x else -1
		var was := carousel._row._position
		await Fixtures.touch(self, path)
		assert_int(carousel._row._position - was).is_equal(way)
		moved[way] += 1
		if is_failure():
			return
	for way: int in moved:
		assert_int(moved[way]).override_failure_message(str(way)).is_greater(2)


func test_a_long_press_beside_does_nothing_and_on_the_disc_reaches_270_pixels() -> void:
	var setup := await _on_consoles()
	var carousel: Carousel = setup[0]
	await Fixtures.touch(self, [carousel._selected_point() + BESIDE], HELD_S)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_int(carousel._consoles.selected_index()).is_equal(0)
	await Fixtures.touch(self, [carousel._selected_point() + Vector2(290.0, 0.0)])
	assert_int(carousel._consoles.selected_index()).is_equal(1)
	await Fixtures.touch(self, [carousel._selected_point() - Vector2(290.0, 0.0)])
	await Fixtures.touch(self, [carousel._selected_point() + Vector2(0.0, 250.0)])
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)


func test_A_still_launches_the_game_which_the_fake_device_counts() -> void:
	var device: Fixtures.NewDevice = (await _on_games())[1]
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.launches == 1)).is_true()


func test_a_drag_over_a_game_s_or_a_console_s_properties_turns_what_they_stage() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	var start := Vector2(200.0, 300.0)
	await Fixtures.finger(self, start, true)
	await Fixtures.finger_to(self, start + Vector2(150.0, 0.0))
	await await_idle_frame()
	assert_bool(carousel._row._turn.of(carousel._row.selected_index()).is_equal_approx(Basis.IDENTITY)).is_false()
	await Fixtures.finger(self, start + Vector2(150.0, 0.0), false)
	for press in 2:
		await _back(carousel)
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)
	await Fixtures.finger(self, start, true)
	await Fixtures.finger_to(self, start + Vector2(0.0, 150.0))
	await await_idle_frame()
	var selected := carousel._consoles.selected_index()
	assert_bool(carousel._consoles._turn.of(selected).is_equal_approx(Basis.IDENTITY)).is_false()
	await Fixtures.finger(self, start + Vector2(0.0, 150.0), false)


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
	for card in properties._cards.get_children():
		if card is LabelCard and (card as LabelCard).region == "Europe":
			europe = card
	await Fixtures.touch(self, [europe.get_global_rect().get_center()])
	await _settled(carousel)
	assert_array(device.chosen_labels).is_equal(["Europe"])
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
	assert_str(properties._naming.typed()).is_equal(typed + key.text)


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


func test_the_system_s_back_is_B_on_the_games_the_ring_the_properties_and_the_keyboard() -> void:
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
	await Fixtures.touch(self, [carousel._console_properties._name.get_global_rect().get_center()])
	await _settled(carousel)
	assert_int(carousel._console_properties._step).is_equal(ConsoleProperties.Step.NAMING)
	await _back(carousel)
	assert_int(carousel._console_properties._step).is_equal(ConsoleProperties.Step.PROPERTIES)
	await _back(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


func test_after_a_tap_on_the_label_and_back_to_the_consoles_a_tap_beside_moves_the_selection() -> void:
	var carousel: Carousel = (await _on_games())[0]
	await Fixtures.touch(self, [carousel._selected_point()], HELD_S)
	await _settled(carousel)
	await Fixtures.touch(self, [carousel._properties._zone.get_global_rect().get_center()])
	await _settled(carousel)
	assert_int(carousel._properties._step).is_equal(DiscProperties.Step.LABELS)
	for press in 3:
		await _back(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	await Fixtures.touch(self, [carousel._selected_point() + BESIDE])
	await _settled(carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_int(carousel._consoles.selected_index()).is_equal(1)


func test_INV_E7_10_whatever_a_finger_does_nothing_is_launched_and_the_screens_settle() -> void:
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
