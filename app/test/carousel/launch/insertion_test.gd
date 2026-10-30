# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
func test_a_game_starts_from_where_it_stood_and_ends_on_the_spindle_facing_the_drive() -> void:
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
