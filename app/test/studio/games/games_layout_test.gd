# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_INV_E12_03_neighbours_stand_parallel_to_the_screen_for_every_medium_and_distance() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 120603
	var media := MediumManifest.found()
	assert_int(media.size()).is_equal(15)
	for medium in media:
		var layout := GamesLayout.new(medium)
		for case in 100:
			var d := random.randf_range(1.0, 2.19) * (-1.0 if case % 2 else 1.0)
			var stand := layout.standing(d, random.randf(), random.randf_range(0.0, 100.0), true)
			assert_bool(stand.basis.orthonormalized().is_equal_approx(Basis.IDENTITY)).is_true()
			assert_vector(stand.basis.get_scale()).is_equal_approx(Vector3.ONE * layout.side_size, Vector3.ONE * 1e-5)


func test_discs_and_cartridges_follow_the_validated_parabola_and_pose() -> void:
	for medium: String in ["ps2_dvd", "gba_cart", "nes_cart", "snes_pal_cart"]:
		var layout := GamesLayout.new(medium)
		var cart := medium.ends_with("cart")
		var centre := Vector3(0.0, 0.15, 0.0)
		var angles := Vector3(-13.4, 21.0, 0.2)
		if cart:
			centre = Vector3(0.028, 0.243, -0.015)
			angles = Vector3(-12.1, 18.5, 0.0)
		if medium == "nes_cart":
			centre = Vector3(0.046, 0.257, -0.03)
			angles = Vector3(-17.3, 20.4, 0.0)
		elif medium == "snes_pal_cart":
			centre = Vector3(0.028, 0.319, -0.042)
			angles = Vector3(-16.0, 22.3, 0.0)
		for d: float in [-2.1, -1.0, -0.7, -0.25, 0.0, 0.25, 0.7, 1.0, 2.1]:
			var at := layout.standing(d)
			var a := minf(absf(d), 1.0)
			var expected := Vector3(centre.x * (1.0 - a) + (1.25 if cart else 0.96) * d,
				centre.y + ((0.02 if cart else -0.25) - centre.y) * d * d, centre.z * (1.0 - a))
			assert_vector(at.origin).is_equal_approx(expected, Vector3.ONE * 1e-5)
			var posed := Quaternion.from_euler(angles * PI / 180.0).slerp(Quaternion.IDENTITY, a)
			assert_bool(at.basis.orthonormalized().is_equal_approx(Basis(posed))).is_true()
			assert_float(at.basis.get_scale().x).is_equal_approx(lerpf(0.85 if cart else 0.78, 0.66 if cart else 0.56, a), 1e-5)


func test_family_siblings_keep_their_decided_pose() -> void:
	for pair: Array in [["famicom_cart", "nes_cart"], ["sfc_cart", "snes_pal_cart"], ["snes_us_cart", "snes_pal_cart"],
			["n64_cart", "snes_pal_cart"], ["gbc_cart", "gb_cart"], ["gba_cart", "gb_cart"], ["ps1_cd", "ps2_dvd"]]:
		var sibling: String = pair[0]
		var original: String = pair[1]
		assert_bool(GamesLayout.new(sibling).chosen == GamesLayout.new(original).chosen).is_true()


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


func test_floating_only_rises_and_sways_the_chosen_game_and_stops_at_zero_pace() -> void:
	var layout := GamesLayout.new("gba_cart")
	for frame in 200:
		var seconds := frame * 0.05
		var still := layout.standing(0.0)
		var floating := layout.standing(0.0, 1.0, seconds, true)
		assert_float(floating.origin.y - still.origin.y).is_between(-1e-6, 0.050001)
		assert_bool(layout.standing(1.0, 1.0, seconds, true) == layout.standing(1.0)).is_true()
		assert_bool(layout.standing(-1.0, 1.0, seconds, true) == layout.standing(-1.0)).is_true()
	var high := layout.standing(0.0, 1.0, PI / 1.6, true)
	assert_float(high.origin.y).is_equal_approx(layout.chosen.origin.y + 0.05, 1e-5)
	var sway := high.basis * layout.chosen.basis.inverse()
	assert_float(sway.get_euler().y).is_equal_approx(deg_to_rad(7.0), 1e-5)


func test_the_poses_read_from_the_data_are_the_ones_the_layout_had_before_they_moved_there() -> void:
	var disc := [Vector3(0.0, 0.15, 0.0), Vector3(-13.4, 21.0, 0.2)]
	var handheld := [Vector3(0.028, 0.243, -0.015), Vector3(-12.1, 18.5, 0.0)]
	var home := [Vector3(0.028, 0.319, -0.042), Vector3(-16.0, 22.3, 0.0)]
	var nes := [Vector3(0.046, 0.257, -0.03), Vector3(-17.3, 20.4, 0.0)]
	var carts := {"nes_cart": nes, "famicom_cart": nes, "snes_pal_cart": home, "snes_us_cart": home, "sfc_cart": home,
		"n64_cart": home, "gb_cart": handheld, "gbc_cart": handheld, "gba_cart": handheld}
	var media := MediumManifest.found()
	assert_int(media.size()).is_equal(15)
	for medium in media:
		var pose: Array = carts.get(medium, disc)
		var angles: Vector3 = pose[1]
		var origin: Vector3 = pose[0]
		var expected := Transform3D(Basis.from_euler(angles * PI / 180.0).scaled(Vector3.ONE * (0.85 if medium in carts else 0.78)), origin)
		var layout := GamesLayout.new(medium)
		assert_bool(layout.chosen == expected).override_failure_message(medium).is_true()
		assert_vector(layout.side).is_equal(Vector2(1.25, 0.02) if medium in carts else Vector2(0.96, -0.25))
		assert_float(layout.side_size).is_equal(0.66 if medium in carts else 0.56)


func test_a_medium_without_an_entry_stands_as_the_disc() -> void:
	assert_bool(GamesLayout.new("unlisted_medium").chosen == GamesLayout.new("ps2_dvd").chosen).is_true()
