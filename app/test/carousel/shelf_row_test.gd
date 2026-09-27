# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_INV_E2_03_each_step_moves_exactly_one_game_whatever_the_row_is_doing() -> void:
	var random := Fixtures.cases(5)
	for i in 200:
		var count := random.randi_range(1, 30)
		var start := random.randi_range(0, count - 1)
		var row := _row(count, start)
		var expected := start
		for step in random.randi_range(1, 40):
			var direction := Fixtures.direction(random)
			row.hold(direction)
			row.release(direction)
			# Between steps, the row may be at rest or still moving.
			_frames(row, random.randi_range(0, 12), Fixtures.FRAME_S)
			expected = posmod(expected + direction, count) if count > 1 else start
			assert_int(row.selected_index()).is_equal(expected)


func test_INV_E2_03_n_steps_one_way_then_n_the_other_come_back_to_the_same_game() -> void:
	var random := Fixtures.cases(6)
	for i in 200:
		var count := random.randi_range(1, 30)
		var row := _row(count, random.randi_range(0, count - 1))
		var start := row.selected_game()
		var steps := random.randi_range(0, 3 * count)
		var direction := Fixtures.direction(random)
		for way: int in [direction, -direction]:
			for step in steps:
				row.hold(way)
				row.release(way)
				_frames(row, random.randi_range(0, 3), Fixtures.FRAME_S)
		assert_str(row.selected_game().id).is_equal(start.id)


func test_INV_E2_04_a_held_direction_repeats_faster_and_faster_down_to_48_ms_and_stops_on_release() -> void:
	var random := Fixtures.cases(7)
	for i in 50:
		var row := _row(50, 0)
		var clock := [0.0]
		var steps: Array[float] = []
		row.selection_changed.connect(func(_game: AndroidServices.Game) -> void: steps.append(clock[0]))
		var held_s := random.randf_range(0.0, 6.0)
		var frame_s := random.randf_range(1.0 / 120.0, 1.0 / 20.0)
		row.hold(1)
		for frame in ceili(held_s / frame_s):
			clock[0] += frame_s
			row._process(frame_s)
		row.release(1)
		var held_steps := steps.size()
		_frames(row, 120, frame_s)
		assert_int(steps.size()).is_equal(held_steps)
		if held_s > CarouselLayout.FIRST_REPEAT_S + frame_s:
			assert_int(steps.size()).is_greater(1)
		for step in range(1, steps.size()):
			var gap := steps[step] - steps[step - 1]
			assert_float(gap).is_greater_equal(0.048 - 0.0001)
			# Never slower than the gap before, give or take the frame it lands on.
			if step >= 2:
				assert_float(gap).is_less_equal(steps[step - 1] - steps[step - 2] + frame_s)


func test_INV_E2_04_held_long_enough_the_row_steps_20_times_a_second_at_60_fps() -> void:
	var row := _row(50, 0)
	var steps := [0]
	row.selection_changed.connect(func(_game: AndroidServices.Game) -> void: steps[0] += 1)
	row.hold(1)
	_frames(row, 300, Fixtures.FRAME_S)
	var so_far: int = steps[0]
	_frames(row, 60, Fixtures.FRAME_S)
	assert_int(steps[0] - so_far).is_equal(20)


func test_INV_E2_02_however_the_row_moves_each_game_in_view_has_a_place_of_its_own_at_its_offset() -> void:
	var random := Fixtures.cases(8)
	for i in 100:
		var count := random.randi_range(1, 20)
		var row := _row(count, random.randi_range(0, count - 1))
		for move in random.randi_range(1, 10):
			var direction := Fixtures.direction(random)
			row.hold(direction)
			for frame in random.randi_range(0, 40):
				row._process(Fixtures.FRAME_S)
				_assert_places(row, count)
			row.release(direction)
		_frames(row, 60, Fixtures.FRAME_S)
		_assert_places(row, count)


func test_after_a_change_of_shelf_every_game_in_view_has_a_place_of_its_own() -> void:
	var row := _row(30, 0)
	for count: int in [30, 3, 12, 1]:
		row.show_shelf(Fixtures.games(count), 0, Fixtures.DVD, ShelfRow.LabelLook.new())
		_frames(row, 1, Fixtures.FRAME_S)
		_assert_places(row, count)


func test_holding_again_starts_slow_again_and_releasing_the_other_way_changes_nothing() -> void:
	var row := _row(50, 0)
	row.hold(1)
	_frames(row, 300, Fixtures.FRAME_S)
	row.release(-1)
	var moving := row.selected_index()
	_frames(row, 30, Fixtures.FRAME_S)
	assert_int(row.selected_index()).is_not_equal(moving)
	row.release(1)
	row.hold(1)
	# The first repeat, then the second, each waiting as long as on a first hold.
	for delay: float in [CarouselLayout.repeat_delay(0), CarouselLayout.repeat_delay(1)]:
		var started := row.selected_index()
		_frames(row, floori(delay / Fixtures.FRAME_S) - 1, Fixtures.FRAME_S)
		assert_int(row.selected_index()).is_equal(started)
		_frames(row, 2, Fixtures.FRAME_S)
		assert_int(row.selected_index()).is_equal(started + 1)


func test_a_shelf_of_one_game_does_not_move() -> void:
	var row := _row(1, 0)
	row.hold(1)
	_frames(row, 120, Fixtures.FRAME_S)
	assert_str(row.selected_game().id).is_equal("test/0")


## A row showing [param count] test games from [param selected], moved only by the test.
func _row(count: int, selected: int) -> ShelfRow:
	var row: ShelfRow = auto_free(ShelfRow.new())
	add_child(row)
	row.show_shelf(Fixtures.games(count), selected, Fixtures.DVD, ShelfRow.LabelLook.new())
	row.set_process(false)
	return row


func _frames(row: ShelfRow, frames: int, frame_s: float) -> void:
	for frame in frames:
		row._process(frame_s)


## The visible places show each game in view once, where the layout puts it, with its own label
## once drawn.
func _assert_places(row: ShelfRow, count: int) -> void:
	var offsets := CarouselLayout.offsets(count, row._scroll)
	var shown := []
	for place: ShelfRow.Place in row.get_children():
		if place.visible:
			shown.append(place.game)
			assert_float(place.transform.origin.x).is_equal_approx(CarouselLayout.place(offsets[place.game]).origin.x, 0.0001)
			if place.shown._material.get_shader_parameter(&"has_label"):
				assert_str(place.shown._title.text).is_equal(row._games[place.game].title)
	shown.sort()
	var in_view := offsets.keys()
	in_view.sort()
	assert_array(shown).is_equal(in_view)
