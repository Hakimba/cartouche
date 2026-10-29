# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The gestures of the screens before the games' shelf, each heard as `dev/audio/sounds.json`
## `screens` has it, and one sound for one press.

const Cue := SoundEffects.Cue
const Fixtures := preload("res://test/carousel/fixtures.gd")
const ScreenFixtures := preload("res://test/screens/fixtures.gd")
const WELCOME := preload("res://screens/welcome.tscn")

## The sounds as the app has them, while the tests play a long silence in their place: a sound
## of some tens of milliseconds ends before a test frame does.
var _streams: Dictionary[Cue, AudioStream] = {}


func before_test() -> void:
	var silence := AudioStreamWAV.new()
	silence.mix_rate = 48000
	var data := PackedByteArray()
	data.resize(48000 * 2 * 10)
	silence.data = data
	for cue: Cue in Cue.values():
		_streams[cue] = Sounds._players[cue].stream
		if _streams[cue]:
			Sounds._players[cue].stream = silence


func after_test() -> void:
	Input.action_release(&"ui_up")
	for cue: Cue in Cue.values():
		Sounds._players[cue].stream = _streams[cue]


func test_INV_E13_01_the_title_screen_is_silent_and_a_button_passing_it_plays_a_choice() -> void:
	_hush()
	var welcome: Welcome = auto_free(WELCOME.instantiate())
	add_child(welcome)
	assert_array(_heard()).is_empty()
	await ScreenFixtures.joypad(self, JOY_BUTTON_X)
	assert_array(_heard()).is_equal([Cue.SELECT])


func test_INV_E13_01_the_first_launch_screens_play_a_move_a_choice_and_later() -> void:
	var device: ScreenFixtures.NewDevice = auto_free(ScreenFixtures.NewDevice.new())
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	assert_bool(await ScreenFixtures.on(self, carousel, "ButtonStyle")).is_true()
	_hush()
	await ScreenFixtures.action(self, &"ui_right")
	assert_array(_heard()).is_equal([Cue.MOVE])
	_hush()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_array(_heard()).is_equal([Cue.SELECT])
	assert_bool(await ScreenFixtures.on(self, carousel, "PreferredRegion")).is_true()
	_hush()
	await ScreenFixtures.action(self, &"ui_right")
	assert_array(_heard()).is_equal([Cue.MOVE])
	_hush()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_array(_heard()).is_equal([Cue.SELECT])
	assert_bool(await ScreenFixtures.on(self, carousel, "Permission")).is_true()
	_hush()
	await ScreenFixtures.action(self, &"ui_down")
	assert_array(_heard()).is_equal([Cue.MOVE])
	assert_str(ScreenFixtures.focus(self).name).is_equal("Later")
	_hush()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_array(_heard()).is_equal([Cue.BACK])
	assert_bool(await ScreenFixtures.on(self, carousel, "NoConsole")).is_true()
	_hush()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_array(_heard()).is_equal([Cue.SELECT])


func test_INV_E13_03_a_focus_given_by_a_screen_as_it_shows_plays_nothing() -> void:
	var device: ScreenFixtures.NewDevice = auto_free(ScreenFixtures.NewDevice.new())
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	assert_bool(await ScreenFixtures.on(self, carousel, "ButtonStyle")).is_true()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	_hush()
	assert_bool(await ScreenFixtures.on(self, carousel, "PreferredRegion")).is_true()
	assert_array(_heard()).is_empty()


func test_INV_E13_01_y_on_no_console_plays_the_settings() -> void:
	var device: ScreenFixtures.NewDevice = auto_free(ScreenFixtures.NewDevice.new())
	device.first_launch = false
	device.curtain = true
	var carousel := ScreenFixtures.carousel_for(self, device)
	add_child(carousel)
	assert_bool(await ScreenFixtures.on(self, carousel, "NoConsole")).is_true()
	_hush()
	await ScreenFixtures.joypad(self, JOY_BUTTON_Y)
	assert_array(_heard()).is_equal([Cue.SETTINGS])


func test_INV_E13_01_each_press_on_the_consoles_screen_plays_its_one_sound() -> void:
	for case: Array in [[&"carousel_right", Cue.CONSOLE], [&"carousel_left", Cue.CONSOLE], [&"ui_accept", Cue.SELECT],
			[&"open_properties", Cue.PROPERTIES], [&"open_settings", Cue.SETTINGS], [&"ui_down", Cue.RING_OPEN]]:
		var action: StringName = case[0]
		var carousel := await Fixtures.shown_carousel(self)
		_hush()
		Fixtures.press(carousel, action)
		assert_array(_heard()).override_failure_message(action).is_equal([case[1]])
		carousel.free()


func test_INV_E13_01_up_held_turns_the_ball_into_the_button_with_its_sound_and_a_opens_the_form_with_a_choice() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	_hush()
	Input.action_press(&"ui_up")
	carousel._unhandled_input(Fixtures.button(&"ui_up", true))
	assert_array(_heard()).is_equal([Cue.ADD_BALL])
	_hush()
	Fixtures.press(carousel, &"ui_accept")
	assert_array(_heard()).is_equal([Cue.SELECT])
	Input.action_release(&"ui_up")


func test_INV_E13_01_a_console_reached_by_a_tap_on_its_tile_plays_one_step() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	_hush()
	carousel._consoles.step(1, 2)
	assert_array(_heard()).is_equal([Cue.CONSOLE])


## Every cue the `Sounds` autoload plays now.
func _heard() -> Array[Cue]:
	var heard: Array[Cue] = []
	for cue: Cue in Cue.values():
		if Sounds._players[cue].playing:
			heard.append(cue)
	return heard


func _hush() -> void:
	for cue: Cue in Cue.values():
		Sounds._players[cue].stop()
	# A repeated cue played just before must not be held back by its gap.
	Sounds._played_ms.clear()


func test_INV_E13_01_a_on_a_settings_row_plays_a_choice_once() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	carousel.set_process(true)
	Fixtures.press(carousel, &"open_settings")
	var settings: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return settings.state == SettingsMenu.State.OPEN)).is_true()
	_hush()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_array(_heard()).is_equal([Cue.SELECT])


func test_INV_E13_01_each_press_on_the_games_shelf_plays_its_one_sound() -> void:
	for case: Array in [[&"carousel_right", Cue.GAME], [&"ui_down", Cue.OPEN], [&"open_properties", Cue.PROPERTIES],
			[&"screen_back", Cue.BACK]]:
		var action: StringName = case[0]
		var carousel := await Fixtures.shown_carousel(self)
		Fixtures.press(carousel, &"ui_accept")
		Fixtures.step_until(carousel, Carousel.Screen.GAMES)
		_hush()
		Fixtures.press(carousel, action)
		assert_array(_heard()).override_failure_message(action).is_equal([case[1]])
		carousel.free()


func test_each_press_in_the_ring_plays_its_one_sound() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	Fixtures.press(carousel, &"ui_down")
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return not carousel._order._busy)).is_true()
	# Carried there and back, the console is put down where it was: the order, shared by the run's other tests, stays.
	for case: Array in [[&"carousel_right", Cue.CONSOLE], [&"ui_accept", Cue.PEEL], [&"carousel_right", Cue.CARRY],
			[&"carousel_left", Cue.CARRY], [&"ui_accept", Cue.PLACE], [&"ui_accept", Cue.PEEL], [&"screen_back", Cue.PLACE],
			[&"screen_back", Cue.RING_CLOSE]]:
		var action: StringName = case[0]
		assert_bool(await ScreenFixtures.until(self, func() -> bool: return not carousel._order._busy)).is_true()
		_hush()
		await ScreenFixtures.action(self, action)
		assert_array(_heard()).override_failure_message(action).is_equal([case[1]])
