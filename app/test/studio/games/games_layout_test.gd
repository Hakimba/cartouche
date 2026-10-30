# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_neighbours_stand_parallel_to_the_screen_for_every_medium_and_distance() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 120603
	var media := MediumManifest.found()
	assert_dict(media).is_not_empty()
	for medium in media:
		var layout := GamesLayout.new(medium)
		for case in 20:
			var d := random.randf_range(1.0, 2.19) * (-1.0 if case % 2 else 1.0)
			var stand := layout.standing(d, random.randf(), random.randf_range(0.0, 100.0), true)
			assert_bool(stand.basis.orthonormalized().is_equal_approx(Basis.IDENTITY)).is_true()
			assert_vector(stand.basis.get_scale()).is_equal_approx(Vector3.ONE * layout.side_size, Vector3.ONE * 1e-5)


func test_the_bounded_pool_matches_the_whole_ring_including_small_shelves_and_large_wraps() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 120604
	for n: int in [1, 2, 3, 4, 5, 6, 7, 8, 50, 1000, 5000]:
		for case in 30:
			var scroll := random.randf_range(-20000.0, 20000.0)
			var shown := GamesLayout.offsets(n, scroll)
			var expected: Array[int] = []
			for game in n:
				var d := fposmod(game - scroll + n / 2.0, n) - n / 2.0
				if absf(d) < 2.2:
					expected.append(game)
			assert_array(shown.keys()).contains_exactly_in_any_order(expected)
			assert_int(shown.size()).is_less_equal(5)
			var farther := INF
			for game: int in shown:
				var d: float = shown[game]
				assert_float(absf(d)).is_less_equal(farther + 1e-5)
				assert_float(d).is_equal_approx(fposmod(game - scroll + n / 2.0, n) - n / 2.0, 1e-5)
				farther = absf(d)


func test_a_medium_without_an_entry_stands_as_the_disc() -> void:
	assert_bool(GamesLayout.new("unlisted_medium").chosen == GamesLayout.new("ps2_dvd").chosen).is_true()
