# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const REACH := CarouselLayout.REACH
const WHOLE := CarouselLayout.WHOLE_SHELF


func test_INV_E2_02_each_game_shown_stands_at_its_own_place_and_every_game_within_reach_is_shown() -> void:
	var random := Fixtures.cases(1)
	for i in Fixtures.CASES:
		var count := random.randi_range(1, 40)
		var scroll := random.randf_range(-100.0, 100.0) if count > WHOLE else random.randf_range(0.0, count - 1)
		var shown := CarouselLayout.offsets(count, scroll)
		var within := 0
		for position in range(ceili(scroll - REACH - 1), floori(scroll + REACH + 1) + 1):
			if count > WHOLE or (position >= 0 and position < count):
				within += 1
		assert_int(shown.size()).is_equal(within)
		for game: int in shown:
			var at: float = scroll + shown[game]
			assert_float(absf(shown[game])).is_less_equal(REACH + 1)
			assert_float(absf(at - roundi(at))).is_less(0.0001)
			assert_int(posmod(roundi(at), count)).is_equal(game)


func test_INV_E2_02_a_stopped_row_shows_the_selected_game_and_its_consecutive_neighbours() -> void:
	var random := Fixtures.cases(2)
	for i in Fixtures.CASES:
		var count := random.randi_range(1, 40)
		var selected := random.randi_range(-100, 100) if count > WHOLE else random.randi_range(0, count - 1)
		var shown := CarouselLayout.offsets(count, selected)
		assert_float(shown[posmod(selected, count)]).is_equal(0.0)
		var places: Array[int] = []
		for offset: float in shown.values():
			places.append(roundi(offset))
		places.sort()
		assert_int(places[-1] - places[0] + 1).is_equal(places.size())
		if count > WHOLE:
			assert_array(places).is_equal(range(-REACH - 1, REACH + 2))
		else:
			# A short shelf in order: its first game leftmost, its last rightmost, as far as they reach.
			assert_int(places[0]).is_equal(maxi(-selected, -REACH - 1))
			assert_int(places[-1]).is_equal(mini(count - 1 - selected, REACH + 1))


func test_INV_E2_02_a_game_appears_or_leaves_only_where_it_cannot_be_seen_and_never_changes_ends() -> void:
	# A sweep in small steps along each shelf, and a whole turn of endless ones: every such moment is met.
	const STEP := 0.002
	var appears := 0
	for count in range(1, 16):
		for i in roundi((count - 1 if count <= WHOLE else count) / STEP):
			var earlier := CarouselLayout.offsets(count, i * STEP)
			var later := CarouselLayout.offsets(count, (i + 1) * STEP)
			for game in range(count):
				if game in earlier and game in later:
					assert_float(later[game]).is_equal_approx(earlier[game] - STEP, 0.0001)
				elif game in earlier or game in later:
					appears += 1
					var seen: float = earlier[game] if game in earlier else later[game]
					assert_float(CarouselLayout.fade(seen)).is_greater(0.99)
	assert_int(appears).is_greater(0)


func test_the_row_moves_towards_its_target_without_passing_it_and_arrives_within_a_step() -> void:
	var random := Fixtures.cases(4)
	for i in Fixtures.CASES:
		var target := float(random.randi_range(-50, 50))
		var scroll := target + random.randf_range(-1.0, 1.0)
		var frames := 0
		while scroll != target:
			var next := CarouselLayout.scrolled(scroll, target, Fixtures.FRAME_S)
			assert_float(absf(target - next)).is_less_equal(absf(target - scroll))
			assert_bool(signf(target - next) in [0.0, signf(target - scroll)]).is_true()
			scroll = next
			frames += 1
		assert_int(frames).is_less_equal(ceili(CarouselLayout.STEP_S / Fixtures.FRAME_S) + 1)


func test_INV_E2_04_a_held_direction_repeats_faster_and_faster_down_to_48_ms() -> void:
	assert_float(CarouselLayout.repeat_delay(0)).is_equal(CarouselLayout.FIRST_REPEAT_S)
	for steps in 200:
		assert_float(CarouselLayout.repeat_delay(steps + 1)).is_less_equal(CarouselLayout.repeat_delay(steps))
		assert_float(CarouselLayout.repeat_delay(steps)).is_greater_equal(0.048)
	assert_float(CarouselLayout.repeat_delay(200)).is_equal(0.048)


func test_the_selected_game_is_in_front_opaque_and_larger_than_the_others() -> void:
	assert_float(CarouselLayout.fade(0.0)).is_equal(0.0)
	var centre := CarouselLayout.place(0.0)
	for offset: float in [-3.0, -1.0, -0.5, 0.5, 1.0, 2.0]:
		var side := CarouselLayout.place(offset)
		assert_float(side.basis.get_scale().x).is_less(centre.basis.get_scale().x)
		assert_float(side.origin.z).is_less(centre.origin.z)
		assert_float(CarouselLayout.fade(offset)).is_greater(0.0)


func test_INV_E2_02_a_shelf_of_4_games_is_shown_whole_and_one_of_5_goes_round() -> void:
	# The screen shows the selected game and one on each side, and one more slides in and out.
	assert_array(CarouselLayout.offsets(4, 0.0).keys()).contains_exactly_in_any_order([0, 1, 2])
	assert_int(CarouselLayout.stepped(3, 1, 4)).is_equal(0)
	assert_array(CarouselLayout.offsets(5, 0.0).keys()).contains_exactly_in_any_order([3, 4, 0, 1, 2])
	assert_int(CarouselLayout.stepped(4, 1, 5)).is_equal(5)


func test_a_jump_goes_the_shorter_way_round_an_endless_row_and_straight_to_its_game_on_a_short_one() -> void:
	var random := Fixtures.cases(94)
	for i in Fixtures.CASES:
		var count := random.randi_range(1, 40)
		var index := random.randi_range(0, count - 1)
		var position := random.randi_range(-100, 100) if count > WHOLE else random.randi_range(0, count - 1)
		var target := CarouselLayout.nearest(position, index, count)
		if count > WHOLE:
			assert_int(posmod(target, count)).is_equal(index)
			assert_int(absi(target - position) * 2).is_less_equal(count)
		else:
			assert_int(target).is_equal(index)
