# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const FOLDERS: Array[String] = ["ps2_slim", "psx", "nes", "snes", "n64", "gc", "wii", "xbox", "xbox360", "gb", "gbc", "gba"]


## The slots of tile [param index] a rail at [param along] shows it at, among every way round the ring: the
## nearest to the middle, the one on the left when two are as near.
func _nearest(index: int, along: int, count: int, right := false) -> float:
	var best := INF
	for turns in range(-4, 5):
		var candidate := float(index - along + turns * count)
		if absf(candidate) < absf(best) - 1e-9 or (absf(absf(candidate) - absf(best)) < 1e-9 and (candidate > best) == right):
			best = candidate
	return best


func _rail(count: int, selected := 0) -> ConsoleRail:
	var rail: ConsoleRail = auto_free((load("res://studio/rail/console_rail.tscn") as PackedScene).instantiate())
	add_child(rail)
	var folders: Array[String] = []
	folders.assign(FOLDERS.slice(0, count))
	rail.show_consoles(folders, selected)
	return rail


func _settle(rail: ConsoleRail) -> void:
	for frame in 600:
		if not rail.is_processing():
			return
		rail._process(1.0 / 60.0)


func test_every_tile_stands_at_its_slot_for_every_target_and_count() -> void:
	var checked := 0
	for count in range(1, 13):
		for along in range(-2 * count, 2 * count + 1):
			var place := posmod(along, count) if ConsoleRail.is_strip(count) else along
			for index in count:
				var slots := ConsoleRail.slot(index, float(place), count)
				var near := float(index - place) if ConsoleRail.is_strip(count) else _nearest(index, along, count)
				assert_float(slots).override_failure_message("n=%d target=%d tile=%d" % [count, along, index]).is_equal_approx(near, 1e-6)
				assert_bool(ConsoleRail.shown(slots)).is_equal(absf(near) <= 3.6)
				checked += 1
			assert_float(ConsoleRail.slot(posmod(along, count), float(place), count)).is_equal_approx(0.0, 1e-6)
	assert_int(checked).is_greater(2000)


func test_the_live_rail_places_its_tiles_where_the_slots_say() -> void:
	for count: int in [1, 2, 5, 12]:
		var rail := _rail(count, 0)
		for target: int in [1, 2, -1, -5, 13, -13]:
			rail.go_to(target)
			_settle(rail)
			for index in count:
				var slots := ConsoleRail.slot(index, rail.spring().target, count)
				assert_bool(rail.is_shown(index)).is_equal(ConsoleRail.shown(slots))
				if rail.is_shown(index):
					assert_vector(rail.tile_at(index)).is_equal_approx(
						Vector2(564.48 + slots * 174.08, 711.68), Vector2(0.01, 0.01))


func test_the_rail_wraps_both_ways() -> void:
	var rail := _rail(12, 0)
	rail.go_to(-1)
	_settle(rail)
	assert_vector(rail.tile_at(11)).is_equal_approx(Vector2(564.48, 711.68), Vector2(0.01, 0.01))
	rail.go_to(11)
	_settle(rail)
	rail.go_to(12)
	_settle(rail)
	assert_vector(rail.tile_at(0)).is_equal_approx(Vector2(564.48, 711.68), Vector2(0.01, 0.01))


func test_tiles_past_three_places_and_a_half_are_hidden_and_a_short_ring_shows_all() -> void:
	var rail := _rail(12, 0)
	var shown := 0
	for index in 12:
		shown += 1 if rail.is_shown(index) else 0
	assert_int(shown).is_equal(7)
	# Mid-slide, a tile 3.3 places away still shows and one 4.3 away does not.
	rail.spring().position = -0.3
	rail._place()
	assert_bool(rail.is_shown(3)).is_true()
	assert_bool(rail.is_shown(4)).is_false()
	for count: int in [1, 2, 3, 4]:
		var short := _rail(count, 0)
		for index in count:
			assert_bool(short.is_shown(index)).is_true()


func test_a_single_console_has_one_tile_in_the_middle() -> void:
	var rail := _rail(1, 0)
	assert_int(rail.tiles().size()).is_equal(1)
	assert_vector(rail.tile_at(0)).is_equal_approx(Vector2(564.48, 711.68), Vector2(0.01, 0.01))


func test_a_walk_of_200_presses_with_random_frames_ends_on_the_right_console() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 12
	for count: int in [2, 5, 12]:
		var rail := _rail(count, 0)
		var target := 0
		for press in 200:
			target += 1 if random.randf() < 0.5 else -1
			rail.go_to(target)
			for frame in random.randi_range(0, 12):
				rail._process(random.randf_range(0.005, 0.05))
		_settle(rail)
		var place := posmod(target, count) if ConsoleRail.is_strip(count) else target
		assert_float(rail.spring().position).is_equal(float(place))
		for index in count:
			var slots := float(index - place) if ConsoleRail.is_strip(count) else _nearest(index, target, count)
			assert_bool(rail.is_shown(index)).is_equal(absf(slots) <= 3.6)
			if absf(slots) <= 3.6:
				assert_float(rail.tile_at(index).x).is_equal_approx(564.48 + slots * 174.08, 0.01)
		assert_vector(rail.tile_at(posmod(target, count))).is_equal_approx(
			Vector2(564.48, 711.68), Vector2(0.01, 0.01))


func test_fast_presses_only_move_the_target_and_the_spring_follows_with_its_constants() -> void:
	var rail := _rail(12, 0)
	assert_float(rail.spring().stiffness).is_equal(280.0)
	assert_float(rail.spring().damping).is_equal(25.0)
	for press in 10:
		rail.go_to(press + 1)
		rail._process(0.03)
	assert_float(rail.spring().target).is_equal(10.0)
	assert_float(rail.spring().position).is_less(10.0)
	assert_bool(rail.is_processing()).is_true()
	_settle(rail)
	assert_float(rail.spring().position).is_equal(10.0)
	# Still at rest: nothing is drawn again.
	assert_bool(rail.is_processing()).is_false()


func test_the_frame_pops_by_the_keyframes_over_320_ms() -> void:
	assert_float(ConsoleRail.pop_scale(0.0)).is_equal(1.0)
	assert_float(ConsoleRail.pop_scale(ConsoleRail.POP_S)).is_equal(1.0)
	var low := 2.0
	var high := 0.0
	for step in 101:
		var scale := ConsoleRail.pop_scale(ConsoleRail.POP_S * step / 100.0)
		low = minf(low, scale)
		high = maxf(high, scale)
	assert_float(low).is_equal_approx(0.95, 0.01)
	assert_float(high).is_equal_approx(1.025, 0.005)


func test_the_gel_follows_the_selected_console() -> void:
	var rail := _rail(12, 0)
	assert_object(rail.shown_gel()).is_equal(StudioTokens.GEL[&"ps2_slim"])
	rail.go_to(2)
	assert_object(rail.shown_gel()).is_not_equal(StudioTokens.GEL[&"nes"])
	await get_tree().create_timer(StudioTokens.GEL_FADE_S + 0.2).timeout
	assert_bool(rail.shown_gel().is_equal_approx(StudioTokens.GEL[&"nes"])).is_true()


func test_sinking_then_rising_turns_round_from_where_the_rail_is() -> void:
	var rail := _rail(5, 0)
	rail.sink(0.3)
	await get_tree().create_timer(0.15).timeout
	var halfway := rail.sunk
	assert_float(halfway).is_between(0.05, 0.95)
	rail.rise(0.31)
	await get_tree().create_timer(0.05).timeout
	assert_float(rail.sunk).is_less(halfway + 0.2)
	await get_tree().create_timer(0.5).timeout
	assert_float(rail.sunk).is_equal(0.0)


func test_a_tap_under_a_tile_names_its_place_along_the_ring() -> void:
	var rail := _rail(12, 0)
	var middle := Vector2(564.48 + RailTile.SIZE.x / 2.0, 711.68 + 20.0)
	assert_int(rail.slot_under(middle)).is_equal(0)
	assert_int(rail.slot_under(middle + Vector2(174.08, 0.0))).is_equal(1)
	assert_int(rail.slot_under(middle - Vector2(2.0 * 174.08, 0.0))).is_equal(-2)
	assert_int(rail.slot_under(middle - Vector2(0.4 * 174.08, 0.0))).is_equal(0)
	assert_int(rail.slot_under(Vector2(middle.x, 300.0))).is_equal(ConsoleRail.NO_TILE)


func test_a_tap_on_a_strip_steps_as_many_places_as_the_tile_is_away() -> void:
	var rail := _rail(3, 0)
	var middle := Vector2(564.48 + RailTile.SIZE.x / 2.0, 711.68 + 20.0)
	assert_int(rail.slot_under(middle + Vector2(2.0 * 174.08, 0.0))).is_equal(2)
	assert_int(rail.slot_under(middle - Vector2(174.08, 0.0))).is_equal(ConsoleRail.NO_TILE)
	rail.go_to(2)
	_settle(rail)
	assert_int(rail.slot_under(middle - Vector2(2.0 * 174.08, 0.0))).is_equal(-2)


func test_a_sunk_rail_is_4_cqw_lower_and_clear() -> void:
	var rail := _rail(5, 0)
	rail.sunk = 1.0
	assert_float(rail._cloth.position.y).is_equal_approx(51.2, 0.001)
	assert_float(rail._cloth.modulate.a).is_equal(0.0)
	rail.sunk = 0.0
	assert_float(rail._cloth.position.y).is_equal(0.0)
	assert_float(rail._cloth.modulate.a).is_equal(1.0)


## Every tile shown, as (console, x), sorted, for a rail at its spring's position.
func _stood(rail: ConsoleRail) -> Array[Vector2]:
	var all: Array[Vector2] = []
	for tile in rail.tiles():
		if tile.visible:
			all.append(Vector2(FOLDERS.find(tile.console()), tile.position.x))
	all.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return all


func test_no_tile_ever_pops_or_crosses_the_rail_with_two_three_or_more_consoles() -> void:
	for count: int in [2, 3, 4, 7, 12]:
		for presses: Array in [[1, -1, 1], [1, 1, 1], [-1, -1, -1], [-1, 1, 1, -1]]:
			var rail := _rail(count, 0)
			var target := 0
			for press: int in presses:
				target += press
				rail.go_to(target)
				# A strip going round from its last console to its first slides back, against the press.
				var heading := -signf(rail.spring().target - rail.spring().position)
				# Each console is on a strip once: it may slide several places a frame, never jump elsewhere.
				var reach: float = (count if ConsoleRail.is_strip(count) else 0.5) * ConsoleRail.PITCH
				var band: float = (1.0 if ConsoleRail.is_strip(count) else 0.5) * ConsoleRail.PITCH
				var was := _stood(rail)
				# A frame later, every tile shown stands where one stood earlier, at most half a slot on, and
				# on the pressed side, and a tile new to the rail comes in at its far edge.
				for frame in 240:
					rail._process(1.0 / 60.0)
					var now := _stood(rail)
					for tile in now:
						var near := was.filter(func(earlier: Vector2) -> bool: return earlier.x == tile.x and absf(earlier.y - tile.y) < reach)
						var from_edge := absf(tile.y - ConsoleRail.TILE_LEFT) > ConsoleRail.HIDDEN_BEYOND * ConsoleRail.PITCH - band
						assert_bool(not near.is_empty() or from_edge).override_failure_message(
							"n=%d presses %s: console %d pops to x=%.1f" % [count, presses, tile.x, tile.y]).is_true()
						for earlier: Vector2 in near:
							if absf(earlier.y - tile.y) > 2.0:
								assert_bool(signf(tile.y - earlier.y) == heading or from_edge).override_failure_message(
									"n=%d presses %s: console %d goes against the press" % [count, presses, tile.x]).is_true()
					was = now
				_settle(rail)


func test_a_short_ring_is_a_strip_of_its_consoles_each_shown_once() -> void:
	assert_bool(ConsoleRail.is_strip(7)).is_true()
	assert_bool(ConsoleRail.is_strip(8)).is_false()
	for count in range(1, 8):
		var rail := _rail(count, 0)
		for target: int in [0, 1, -1, 3, 2 * count - 1]:
			rail.go_to(target)
			_settle(rail)
			var selected := posmod(target, count)
			var consoles: Array[int] = []
			for tile in _stood(rail):
				consoles.append(roundi(tile.x))
				assert_float(tile.y).is_equal_approx(ConsoleRail.TILE_LEFT + (tile.x - selected) * ConsoleRail.PITCH, 0.01)
			var wanted: Array[int] = []
			for index in count:
				if absi(index - selected) <= 3:
					wanted.append(index)
			assert_array(consoles).override_failure_message("n=%d target=%d" % [count, target]).is_equal(wanted)


func test_an_empty_ring_shows_no_rail_and_a_platform_without_a_model_no_tile() -> void:
	var rail := _rail(3, 0)
	rail.show_consoles([] as Array[String], 0)
	assert_bool(rail.visible).is_false()
	rail.go_to(1)
	assert_int(rail.tiles().size()).is_equal(0)
	var folders: Array[String] = ["ps2_slim", "", "nes"]
	rail.show_consoles(folders, 0)
	assert_bool(rail.is_shown(1)).is_false()
	assert_bool(rail.is_shown(0)).is_true()
	assert_int(rail.slot_under(Vector2(564.48 + 174.08 + 75.0, 760.0))).is_equal(ConsoleRail.NO_TILE)


func test_a_tap_during_a_slide_counts_from_the_target_not_the_lagging_tiles() -> void:
	var rail := _rail(12)
	rail.go_to(1)
	assert_float(rail.spring().position).is_equal(0.0)
	var point := rail.tile_at(2) + RailTile.SIZE / 2.0
	assert_int(rail.slot_under(point)).is_equal(1)


func test_a_sunk_or_hidden_rail_answers_no_tile() -> void:
	var rail := _rail(5)
	var point := rail.tile_at(0) + RailTile.SIZE / 2.0
	rail.sunk = 1.0
	assert_int(rail.slot_under(point)).is_equal(ConsoleRail.NO_TILE)
	rail.sunk = 0.0
	rail.hide()
	assert_int(rail.slot_under(point)).is_equal(ConsoleRail.NO_TILE)
