# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Cue := SoundEffects.Cue
## As `dev/audio/sfx.py` makes them: shorter sounds as WAV, the others as OGG.
const WAV_UNDER_S := 0.15

var _now := 0


func test_INV_E13_04_the_cues_are_the_table_s_in_its_order_and_every_sound_file_is_played_by_one() -> void:
	var cues: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SoundEffects.CUES))
	assert_array(cues.keys()).is_equal(Array(Cue.keys()).map(func(cue: String) -> String: return cue.to_lower()))
	var played: Array[String] = []
	for cue: Cue in Cue.values():
		var file := SoundEffects.path_of(cue)
		if file:
			assert_bool(ResourceLoader.exists(file)).override_failure_message(file).is_true()
			if file.get_file() not in played:
				played.append(file.get_file())
	var files := Array(DirAccess.get_files_at("res://audio/sfx")).filter(func(file: String) -> bool:
		return file.get_extension() in ["wav", "ogg"])
	assert_array(files).contains_exactly_in_any_order(played)


func test_every_sound_is_48_khz_mono_wav_when_short_and_ogg_otherwise() -> void:
	for cue: Cue in Cue.values():
		if not SoundEffects.path_of(cue):
			continue
		var stream: AudioStream = load(SoundEffects.path_of(cue))
		var short := stream.get_length() < WAV_UNDER_S
		assert_bool(stream is AudioStreamWAV).override_failure_message(SoundEffects.path_of(cue)).is_equal(short)
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			assert_int(wav.mix_rate).is_equal(48000)
			assert_bool(wav.stereo).is_false()


func test_INV_E13_04_a_silent_cue_plays_nothing() -> void:
	var sounds := _sounds()
	for cue: Cue in Cue.values():
		if not SoundEffects.path_of(cue):
			sounds.play(cue)
			assert_bool(sounds._players[cue].playing).override_failure_message(str(cue)).is_false()


func test_INV_E13_02_a_repeated_cue_plays_at_most_once_per_gap_and_always_once_the_gap_is_over() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 7
	for cue: Cue in SoundEffects.REPEATED:
		if not SoundEffects.path_of(cue):
			continue
		var sounds := _sounds()
		var player := sounds._players[cue]
		var played: Array[int] = []
		for press in 400:
			_now += random.randi_range(1, 90)
			var gap_over: bool = played.is_empty() or _now - played.back() >= SoundEffects.REPEAT_GAP_S * 1000.0
			player.stop()
			sounds.play(cue)
			if player.playing:
				played.append(_now)
			assert_bool(player.playing).override_failure_message("%s at %d" % [cue, _now]).is_equal(gap_over)


func test_a_repeated_cue_strays_in_pitch_within_its_spread_and_the_others_keep_theirs() -> void:
	var sounds := _sounds()
	var pitches: Dictionary[float, bool] = {}
	for press in 100:
		_now += 100
		sounds.play(Cue.CONSOLE)
		var pitch := sounds._players[Cue.CONSOLE].pitch_scale
		assert_float(pitch).is_between(1.0 - SoundEffects.PITCH_SPREAD, 1.0 + SoundEffects.PITCH_SPREAD)
		pitches[pitch] = true
		sounds.play(Cue.SELECT)
		assert_float(sounds._players[Cue.SELECT].pitch_scale).is_equal(1.0)
	assert_int(pitches.size()).is_greater(50)


func test_a_cue_not_repeated_plays_at_every_press_however_close() -> void:
	var sounds := _sounds()
	for cue: Cue in Cue.values():
		if cue in SoundEffects.REPEATED or not SoundEffects.path_of(cue):
			continue
		for press in 3:
			_now += 1
			sounds._players[cue].stop()
			sounds.play(cue)
			assert_bool(sounds._players[cue].playing).override_failure_message(str(cue)).is_true()


func test_INV_E13_03_a_focus_moved_by_a_direction_plays_a_move_only_on_a_screen_of_the_group() -> void:
	var sounds := _sounds()
	var grouped: Control = auto_free(_buttons())
	grouped.add_to_group(SoundEffects.MOVES)
	var other: Control = auto_free(_buttons())
	for case: Array in [[grouped, true, true], [grouped, false, false], [other, true, false]]:
		var screen: Control = case[0]
		sounds._players[Cue.MOVE].stop()
		sounds._directed_frame = -1
		if case[1]:
			var event := InputEventAction.new()
			event.action = &"ui_right"
			event.pressed = true
			sounds._input(event)
		sounds._on_focus_changed(screen.get_child(1) as Control)
		assert_bool(sounds._players[Cue.MOVE].playing).override_failure_message(str(case)).is_equal(case[2])


func _sounds() -> SoundEffects:
	var sounds: SoundEffects = auto_free(SoundEffects.new())
	sounds.clock = func() -> int: return _now
	add_child(sounds)
	return sounds


func _buttons() -> Control:
	var box := HBoxContainer.new()
	for i in 2:
		box.add_child(Button.new())
	add_child(box)
	return box


func test_a_search_climbs_without_steps_from_the_whole_shelf_to_one_game_and_glides_longer_the_farther() -> void:
	var top := pow(2.0, SoundEffects.NARROWING_SEMITONES / 12.0)
	for total: int in [8, 200, 2000]:
		assert_float(SoundEffects.narrowing_pitch(total, total)).is_equal_approx(1.0, 0.0001)
		assert_float(SoundEffects.narrowing_pitch(1, total)).is_equal_approx(top, 0.0001)
		for found in range(2, total):
			assert_float(SoundEffects.narrowing_pitch(found, total)).is_greater(SoundEffects.narrowing_pitch(found + 1, total))
	# Far apart, a key glides longer than close ones, within the bounds.
	assert_float(SoundEffects.glide_s(1.0, 2.0)).is_greater(SoundEffects.glide_s(1.0, 1.1))
	assert_float(SoundEffects.glide_s(2.0, 1.0)).is_equal(SoundEffects.glide_s(1.0, 2.0))
	assert_float(SoundEffects.glide_s(1.0, 1.0)).is_equal(SoundEffects.GLIDE_MIN_S)
	assert_float(SoundEffects.glide_s(1.0, 4.0)).is_equal(SoundEffects.GLIDE_MAX_S)
	var sounds := _sounds()
	sounds.play_narrowing(Cue.TYPE, 200, 100, 200)
	assert_float(sounds._players[Cue.TYPE].pitch_scale).is_equal(1.0)
	sounds._glide.custom_step(1.0)
	assert_float(sounds._players[Cue.TYPE].pitch_scale).is_equal_approx(SoundEffects.narrowing_pitch(100, 200), 0.0001)
