# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/dev/bridge/fixtures.gd")
const Sounds := preload("res://dev/bridge/sounds.gd")
const _RATE := 8000

var _commands: Fixtures.CommandHost
var _screen := "games"


func before_test() -> void:
	_screen = "games"
	_commands = Fixtures.CommandHost.new()
	add_child(_commands)


func after_test() -> void:
	_commands.free()


## A 16-bit mono WAV file of `seconds` of a tone.
func _wav(seconds := 0.05) -> PackedByteArray:
	var samples := int(_RATE * seconds)
	var data := PackedByteArray()
	data.resize(samples * 2)
	for i in samples:
		data.encode_s16(i * 2, int(sin(i * 0.3) * 12000.0))
	var out := PackedByteArray()
	out.append_array("RIFF".to_ascii_buffer())
	out.resize(8)
	out.encode_u32(4, 36 + data.size())
	out.append_array("WAVEfmt ".to_ascii_buffer())
	var format := PackedByteArray()
	format.resize(20)
	format.encode_u32(0, 16)
	format.encode_u16(4, 1)
	format.encode_u16(6, 1)
	format.encode_u32(8, _RATE)
	format.encode_u32(12, _RATE * 2)
	format.encode_u16(16, 2)
	format.encode_u16(18, 16)
	out.append_array(format)
	out.append_array("data".to_ascii_buffer())
	var size := PackedByteArray()
	size.resize(4)
	size.encode_u32(0, data.size())
	out.append_array(size)
	out.append_array(data)
	return out


func _entry(seconds := 0.05, gain := 0.0, screens: Array = []) -> Dictionary:
	return {"data": Marshalls.raw_to_base64(_wav(seconds)), "format": "wav", "gain_db": gain, "screens": screens}


func _sounds() -> Sounds:
	var sounds: Sounds = auto_free(Sounds.new())
	sounds.screen = func() -> String: return _screen
	add_child(sounds)
	return sounds


func _players(sounds: Sounds) -> Array[AudioStreamPlayer]:
	var players: Array[AudioStreamPlayer] = []
	for child in sounds.get_children():
		if child is AudioStreamPlayer:
			players.append(child as AudioStreamPlayer)
	return players


func _press(action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().process_frame


func test_the_wav_decoder_reads_the_samples_and_the_rate() -> void:
	var stream := Sounds.decode(_wav(0.1), "wav") as AudioStreamWAV
	assert_object(stream).is_not_null()
	assert_int(stream.mix_rate).is_equal(_RATE)
	assert_bool(stream.stereo).is_false()
	assert_int(stream.data.size()).is_equal(int(_RATE * 0.1) * 2)
	assert_float(stream.get_length()).is_equal_approx(0.1, 0.001)


func test_the_decoder_refuses_what_is_not_16_bit_pcm_wav_or_a_known_format() -> void:
	var float_wav := _wav()
	float_wav.encode_u16(20, 3)
	for bad: PackedByteArray in [PackedByteArray(), "RIFFxxxxWAVE".to_ascii_buffer(), float_wav, _wav().slice(0, 30)]:
		assert_object(Sounds.decode(bad, "wav")).is_null()
	assert_object(Sounds.decode(_wav(), "mp3")).is_null()


func test_the_sound_command_plays_the_bytes_on_a_temporary_player_that_frees_itself() -> void:
	var answer := await _commands.run({"cmd": "sound", "id": 1, "data": _entry(0.1, -6.0)["data"], "format": "wav", "gain_db": -6.0})
	assert_bool(answer["ok"]).is_true()
	assert_float(answer["length"]).is_equal_approx(0.1, 0.001)
	var sounds: Sounds = _commands._sounds
	assert_int(_players(sounds).size()).is_equal(1)
	assert_float(_players(sounds)[0].volume_db).is_equal(-6.0)
	await await_millis(600)
	assert_int(_players(sounds).size()).is_equal(0)


func test_bad_sounds_are_refused_and_start_no_player() -> void:
	var good := Marshalls.raw_to_base64(_wav())
	for message: Dictionary in [{"cmd": "sound"}, {"cmd": "sound", "data": good, "format": "mp3"},
			{"cmd": "sound", "data": "!!", "format": "wav"}, {"cmd": "sound", "data": good, "format": "wav", "gain_db": "loud"},
			{"cmd": "sounds", "map": 3}, {"cmd": "sounds", "map": {"ui_accept": 3}},
			{"cmd": "sounds", "map": {"ui_accept": [{"data": good, "format": "ogg"}]}}]:
		var answer := await _commands.run(message)
		assert_bool(answer["ok"]).is_false()
		assert_str(answer["error"]).is_not_empty()
	assert_int(_players(_commands._sounds).size()).is_equal(0)


func test_a_mapped_action_plays_its_sound_and_another_action_plays_nothing() -> void:
	var sounds := _sounds()
	assert_bool(sounds.set_map({"map": {"ui_accept": [_entry(0.2, -3.0)]}}).get("ok", true)).is_true()
	await _press(&"ui_accept")
	assert_int(_players(sounds).size()).is_equal(1)
	assert_float(_players(sounds)[0].volume_db).is_equal(-3.0)
	await _press(&"ui_up")
	assert_int(_players(sounds).size()).is_equal(1)


func test_the_entry_made_for_the_screen_shown_wins_over_the_one_for_any_screen() -> void:
	var sounds := _sounds()
	sounds.set_map({"map": {"ui_accept": [_entry(0.2, -9.0, ["games"]), _entry(0.2, -3.0)]}})
	await _press(&"ui_accept")
	assert_float(_players(sounds)[0].volume_db).is_equal(-9.0)
	_screen = "settings"
	await _press(&"ui_accept")
	assert_float(_players(sounds)[1].volume_db).is_equal(-3.0)


func test_an_entry_for_other_screens_only_is_silent_elsewhere() -> void:
	var sounds := _sounds()
	sounds.set_map({"map": {"ui_accept": [_entry(0.2, 0.0, ["order"])]}})
	await _press(&"ui_accept")
	assert_int(_players(sounds).size()).is_equal(0)


func test_a_screen_change_plays_the_screen_key_once_and_the_first_screen_is_not_a_change() -> void:
	var sounds := _sounds()
	sounds.set_map({"map": {"screen:welcome": [_entry(0.2)]}})
	await get_tree().process_frame
	assert_int(_players(sounds).size()).is_equal(0)
	_screen = "welcome"
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(_players(sounds).size()).is_equal(1)


func test_an_empty_map_silences_everything_and_a_refused_map_keeps_the_old_one() -> void:
	var sounds := _sounds()
	sounds.set_map({"map": {"ui_accept": [_entry(0.2)]}})
	assert_bool(sounds.set_map({"map": {"ui_accept": 3}})["ok"]).is_false()
	await _press(&"ui_accept")
	assert_int(_players(sounds).size()).is_equal(1)
	assert_int(sounds.set_map({"map": {}})["keys"]).is_equal(0)
	await _press(&"ui_accept")
	assert_int(_players(sounds).size()).is_equal(1)
	assert_bool(get_tree().root.window_input.is_connected(sounds._on_input)).is_false()


func test_a_silent_entry_keeps_its_screens_quiet_instead_of_the_general_sound() -> void:
	var sounds := _sounds()
	sounds.set_map({"map": {"ui_accept": [{"silent": true, "screens": ["games"]}, _entry(0.2)]}})
	await _press(&"ui_accept")
	assert_int(_players(sounds).size()).is_equal(0)
	_screen = "settings"
	await _press(&"ui_accept")
	assert_int(_players(sounds).size()).is_equal(1)


func test_a_stick_pushed_is_one_press_until_it_comes_back() -> void:
	var sounds := _sounds()
	sounds.set_map({"map": {"carousel_right": [_entry(0.2)]}})
	for value: float in [1.0, 1.0, 0.0, 1.0]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_X
		motion.axis_value = value
		Input.parse_input_event(motion)
		await get_tree().process_frame
	assert_int(_players(sounds).size()).is_equal(2)
	# The stick is let go, so that no later test sees a direction held.
	var released := InputEventJoypadMotion.new()
	released.axis = JOY_AXIS_LEFT_X
	Input.parse_input_event(released)
	await get_tree().process_frame


func test_stopping_an_audition_stops_and_frees_every_temporary_player() -> void:
	var sounds := _sounds()
	sounds.play(_entry(2.0))
	sounds.play(_entry(2.0))
	assert_int(_players(sounds).size()).is_equal(2)
	assert_float(sounds.play({"stop": true})["length"]).is_equal(0.0)
	for player in _players(sounds):
		assert_bool(player.playing).is_false()
	await await_idle_frame()
	assert_int(_players(sounds).size()).is_equal(0)
