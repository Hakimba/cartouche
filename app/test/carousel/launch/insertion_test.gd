# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
## The launch budget from A to the emulator's start, less what the check and the start take.
const LONGEST_INSERTION_S := 1.8
const STEP_S := 1.0 / 240.0


func test_INV_E3_07_a_game_starts_from_where_it_stood_and_ends_on_the_spindle_facing_the_drive() -> void:
	var random := Fixtures.cases(70)
	var moved := 0
	for i in Fixtures.CASES:
		if is_failure():
			return
		var insertion := Fixtures.insertion(random)
		var start := Fixtures.stand(random)
		if insertion.face_s > 0.0:
			moved += 1
			assert_bool(insertion.stand_at(0.0, start).is_equal_approx(start)).is_true()
		var still := insertion.seated_s() + insertion.bounce_s
		for t: float in [still, still + random.randf_range(0.0, 100.0)]:
			var stand := insertion.stand_at(t, start)
			assert_bool(stand.is_equal_approx(insertion.spindle_stand())).override_failure_message("at %.3f s: %s" % [t, stand]).is_true()
	assert_int(moved * 2).is_greater(Fixtures.CASES)


func test_INV_E3_07_a_game_never_jumps_it_moves_no_faster_than_its_steps_take_it() -> void:
	var random := Fixtures.cases(71)
	for i in 200:
		if is_failure():
			return
		var insertion := Fixtures.insertion(random)
		# Steps long enough to be seen.
		for step: StringName in [&"face_s", &"grab_s", &"seat_s", &"bounce_s"]:
			var length: float = insertion.get(step)
			insertion.set(step, maxf(length, 0.05))
		var start := Fixtures.stand(random)
		# Each step's fastest: its distance over its time, times its easing's steepest slope.
		var turning := start.basis.get_rotation_quaternion().angle_to(insertion.drive().get_rotation_quaternion())
		var turn_speed := 1.5 * turning / insertion.face_s
		var move_speed := 1.5 * start.origin.length() / insertion.face_s + 2.0 * insertion.grab_distance / insertion.grab_s \
			+ 2.0 * (insertion.grab_distance + insertion.seat_depth) / insertion.seat_s + PI * insertion.bounce / insertion.bounce_s
		var previous := insertion.stand_at(0.0, start)
		for frame in ceili(insertion.duration_s() / STEP_S):
			var now := insertion.stand_at((frame + 1) * STEP_S, start)
			assert_float(now.origin.distance_to(previous.origin)).is_less_equal(move_speed * STEP_S * 1.01 + 0.000001)
			var turned := now.basis.get_rotation_quaternion().angle_to(previous.basis.get_rotation_quaternion())
			assert_float(turned).is_less_equal(turn_speed * STEP_S * 1.01 + 0.0001)
			previous = now


func test_INV_E3_07_the_drive_spins_the_game_up_from_its_seating_never_backwards_and_only_with_a_spindle() -> void:
	var random := Fixtures.cases(72)
	for i in Fixtures.CASES:
		if is_failure():
			return
		var insertion := Fixtures.insertion(random)
		var turned := 0.0
		var t := 0.0
		while t < insertion.duration_s() + 1.0:
			var spin := insertion.spin_at(t)
			assert_float(spin).is_greater_equal(turned - 0.000001)
			if t < insertion.seated_s() or not insertion.spindle:
				assert_float(spin).is_equal(0.0)
			turned = spin
			t += random.randf_range(0.0, 0.05)
		var full := insertion.seated_s() + insertion.spin_up_s
		var expected := TAU * insertion.turns_per_s if insertion.spindle else 0.0
		assert_float(insertion.spin_speed_at(full + 0.01)).is_equal_approx(expected, 0.0001)


func test_INV_E3_07_the_black_grows_from_nothing_to_the_whole_screen_once_the_game_is_seated() -> void:
	var random := Fixtures.cases(73)
	# Each case walks the whole insertion in small steps: fewer cases than the others.
	for i in 300:
		if is_failure():
			return
		var insertion := Fixtures.insertion(random)
		var starts := insertion.seated_s() + insertion.black_after_s
		assert_float(insertion.black_at(random.randf_range(0.0, starts) - 0.0001)).is_equal(0.0)
		var covered := 0.0
		for t in range(0, ceili((insertion.duration_s() + 0.1) / STEP_S)):
			var black := insertion.black_at(t * STEP_S)
			assert_float(black).is_between(covered, 1.0)
			covered = black
		assert_float(insertion.black_at(insertion.duration_s())).is_equal(1.0)
		assert_float(insertion.controls_at(insertion.face_s)).is_equal(0.0)


func test_INV_E3_08_every_medium_has_an_insertion_short_enough_for_the_launch_budget() -> void:
	var appearance: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(APPEARANCE))
	var models: Dictionary = appearance["models"]
	var insertions: Dictionary = appearance["insertions"]
	for media: String in models:
		assert_bool(insertions.has(media)).override_failure_message("no insertion for %s" % media).is_true()
		var data: Dictionary = insertions[media]
		assert_dict(Insertion.problems(data)).override_failure_message("%s: %s" % [media, Insertion.problems(data)]).is_empty()
		var insertion := Insertion.read(data)
		assert_float(insertion.duration_s()).override_failure_message("%s lasts %.2f s" % [media, insertion.duration_s()]).is_less_equal(LONGEST_INSERTION_S)


func test_reading_an_insertion_keeps_defaults_counts_negative_times_as_none_and_orders_its_sounds() -> void:
	var defaults := Insertion.new()
	var data := {"face_s": -1.0, "seat_s": 0.5, "tilt_degrees": -10.0, "spin_speed": 3.0, "sounds": [
		{"name": "late", "delay_s": 0.3}, {"name": "early", "delay_s": 0.1, "volume_db": -6.0}]}
	var read := Insertion.read(data)
	assert_dict(Insertion.problems(data)).is_equal({"face_s": Insertion.Problem.BELOW_ZERO, "spin_speed": Insertion.Problem.UNKNOWN_KEY})
	assert_float(read.face_s).is_equal(0.0)
	assert_float(read.tilt_degrees).is_equal(-10.0)
	assert_float(read.seat_s).is_equal(0.5)
	assert_float(read.grab_s).is_equal(defaults.grab_s)
	assert_bool(read.spindle).is_equal(defaults.spindle)
	assert_array(read.sounds.map(func(cue: Insertion.Cue) -> String: return cue.name)).is_equal(["early", "late"])
	assert_float(read.sounds[0].volume_db).is_equal(-6.0)


func test_data_of_another_type_is_reported_and_its_default_kept() -> void:
	var defaults := Insertion.new()
	var data := {"grab_s": "long", "spindle": 1, "sounds": [{"delay_s": 0.1}, "clip"], "black_s": null}
	var read := Insertion.read(data)
	assert_dict(Insertion.problems(data)).is_equal({"grab_s": Insertion.Problem.NOT_A_NUMBER,
		"spindle": Insertion.Problem.NOT_A_NUMBER, "sounds": Insertion.Problem.NOT_A_SOUND, "black_s": Insertion.Problem.NOT_A_NUMBER})
	assert_float(read.grab_s).is_equal(defaults.grab_s)
	assert_float(read.black_s).is_equal(defaults.black_s)
	assert_bool(read.spindle).is_equal(defaults.spindle)
	assert_array(read.sounds).is_empty()
