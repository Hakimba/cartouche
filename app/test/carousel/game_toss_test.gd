# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const BUTTONS: Array[StringName] = [&"carousel_left", &"carousel_right", &"ui_accept", &"screen_back", &"ui_up", &"ui_down",
	&"open_properties", &"open_settings"]


func test_inv_20_up_lands_the_game_as_the_pick_at_rest_whether_it_lands_or_the_app_leaves_and_nothing_pressed_acts() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var launches: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	carousel._game_launch.android = launches
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_until(carousel, Carousel.Screen.GAMES)
	var row := carousel._row
	var random := Fixtures.cases(25)
	for toss in 12:
		var pick := row.pick()
		Fixtures.press(carousel, &"ui_up")
		assert_bool(carousel._toss.is_busy()).is_true()
		# The app left never, at once, in the air before the game turns into the pick, or at any moment.
		var in_air := toss % 4 == 2
		var paused_at: int = [-1, 0, -1, random.randi_range(0, 80)][toss % 4]
		# Two seconds at most, as a person waits.
		for frame in 120:
			if not carousel._toss.is_busy():
				break
			if frame == paused_at or (in_air and row.selected_lift > 0.0):
				if in_air:
					assert_str(row.selected_game().id).is_not_equal(pick.id)
				carousel.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
			else:
				Fixtures.press(carousel, BUTTONS[random.randi_range(0, BUTTONS.size() - 1)])
				Fixtures.step_frame(carousel)
		assert_bool(carousel._toss.is_busy()).is_false()
		assert_str(row.selected_game().id).is_equal(pick.id)
		assert_str((carousel._title as Label).text).is_equal(pick.title)
		assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
		assert_bool(carousel._search.is_open() or carousel._screens.visible or carousel._game_launch.is_busy()).is_false()
		assert_int(launches.checks).is_equal(0)
		assert_array([row.pose_amount, row.neighbours, row.selected_lift, row.selected_flip, row.selected_squash,
			carousel._pill.modulate.a, carousel._games_logo.modulate.a]).is_equal([1.0, 1.0, 0.0, 0.0, 0.0, 1.0, 1.0])
		if is_failure():
			return
	# Landed, the carousel takes presses again.
	var landed := row.selected_index()
	Fixtures.press(carousel, &"carousel_right")
	assert_int(row.selected_index()).is_not_equal(landed)


func test_up_held_on_the_stick_tosses_once() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_until(carousel, Carousel.Screen.GAMES)
	var tosses := 0
	for value: float in [-0.6, -0.8, -1.0, -0.9, -1.0, -0.95]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_Y
		stick.axis_value = value
		carousel._unhandled_input(stick)
		tosses += 1 if carousel._toss.is_busy() else 0
		carousel._toss.finish()
	assert_int(tosses).is_equal(1)


func test_up_held_as_the_app_leaves_tosses_again_at_its_first_press_back() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_until(carousel, Carousel.Screen.GAMES)
	carousel._unhandled_input(Fixtures.button(&"ui_up", true))
	carousel.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_bool(carousel._toss.is_busy()).is_false()
	Fixtures.press(carousel, &"ui_up")
	assert_bool(carousel._toss.is_busy()).is_true()


func test_a_toss_as_the_carousel_comes_in_ends_its_arrival_at_once() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_until(carousel, Carousel.Screen.GAMES)
	carousel._arrive()
	Fixtures.press(carousel, &"ui_up")
	assert_bool(carousel._toss.is_busy()).is_true()
	assert_bool(carousel._arrival.is_running()).is_false()
	assert_float(carousel._consoles.arrival).is_equal(1.0)
