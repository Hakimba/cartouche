# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const REACH := CarouselLayout.REACH
const WHOLE := CarouselLayout.WHOLE_SHELF


func test_a_stopped_row_shows_the_selected_game_and_its_consecutive_neighbours() -> void:
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


func test_a_game_appears_or_leaves_only_where_it_cannot_be_seen_and_never_changes_ends() -> void:
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


func test_a_shelf_of_4_games_is_shown_whole_and_one_of_5_goes_round() -> void:
	# The screen shows the selected game and one on each side, and one more slides in and out.
	assert_array(CarouselLayout.offsets(4, 0.0).keys()).contains_exactly_in_any_order([0, 1, 2])
	assert_int(CarouselLayout.stepped(3, 1, 4)).is_equal(0)
	assert_array(CarouselLayout.offsets(5, 0.0).keys()).contains_exactly_in_any_order([3, 4, 0, 1, 2])
	assert_int(CarouselLayout.stepped(4, 1, 5)).is_equal(5)


func test_the_games_ring_shows_small_shelves_once_and_wraps_both_ways() -> void:
	assert_array(GamesLayout.offsets(1, 0.0).keys()).is_equal([0])
	assert_array(GamesLayout.offsets(2, 0.0).keys()).contains_exactly_in_any_order([0, 1])
	assert_float(GamesLayout.offsets(5, 4.0)[0]).is_equal(1.0)
	assert_float(GamesLayout.offsets(5, 0.0)[4]).is_equal(-1.0)
