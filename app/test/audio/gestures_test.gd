# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## What the screens' gestures play, heard through the `Sounds` autoload.

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
	for cue: Cue in Cue.values():
		Sounds._players[cue].stream = _streams[cue]


func test_the_title_screen_is_silent_and_a_button_passing_it_plays_a_choice() -> void:
	_hush()
	var welcome: Welcome = auto_free(WELCOME.instantiate())
	add_child(welcome)
	assert_array(_heard()).is_empty()
	await ScreenFixtures.joypad(self, JOY_BUTTON_X)
	assert_array(_heard()).is_equal([Cue.SELECT])


func test_a_focus_given_by_a_screen_as_it_shows_plays_nothing() -> void:
	var device: ScreenFixtures.NewDevice = auto_free(ScreenFixtures.NewDevice.new())
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	assert_bool(await ScreenFixtures.on(self, carousel, "ButtonStyle")).is_true()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	_hush()
	assert_bool(await ScreenFixtures.on(self, carousel, "PreferredRegion")).is_true()
	assert_array(_heard()).is_empty()


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


func test_a_on_a_settings_row_plays_a_choice_once() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	carousel.set_process(true)
	Fixtures.press(carousel, &"open_settings")
	var settings: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return settings.state == SettingsMenu.State.OPEN)).is_true()
	_hush()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_array(_heard()).is_equal([Cue.SELECT])


func test_left_and_right_on_the_sounds_line_turn_them_down_and_up_heard_at_their_new_level_and_kept() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	carousel.set_process(true)
	Fixtures.press(carousel, &"open_settings")
	var settings: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return settings.state == SettingsMenu.State.OPEN)).is_true()
	settings._sounds.grab_focus()
	var bus := AudioServer.get_bus_index(SoundEffects.BUS)
	for step in SoundEffects.LEVELS + 2:
		_hush()
		await ScreenFixtures.action(self, &"ui_left")
	assert_int(Sounds.level).is_equal(0)
	assert_bool(AudioServer.is_bus_mute(bus)).is_true()
	assert_int((await carousel.android.settings()).sound_level).is_equal(0)
	_hush()
	await ScreenFixtures.action(self, &"ui_right")
	assert_array(_heard()).is_equal([Cue.VOLUME])
	assert_int(Sounds.level).is_equal(1)
	assert_bool(AudioServer.is_bus_mute(bus)).is_false()
	assert_object(ScreenFixtures.focus(self)).is_same(settings._sounds)
	Sounds.level = SoundEffects.LEVELS
