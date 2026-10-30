# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_each_step_moves_exactly_one_game_whatever_the_row_is_doing() -> void:
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


func test_n_steps_one_way_then_n_the_other_come_back_to_the_same_game() -> void:
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


func test_however_the_row_moves_each_game_in_view_has_a_place_of_its_own_at_its_offset() -> void:
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
		row.show_shelf(Fixtures.games(count), 0, Fixtures.DVDS, ShelfRow.LabelLook.new())
		_frames(row, 1, Fixtures.FRAME_S)
		_assert_places(row, count)


func test_every_game_in_view_shows_on_the_model_of_its_own_medium_alone_whatever_the_moves() -> void:
	var random := Fixtures.cases(64)
	var models: Dictionary[String, PackedScene] = {"ps2_dvd": Fixtures.DVD, "": Fixtures.DVD,
		"gba_cart": load("res://carousel/media/gba_cart/gba_cart.tscn"),
		"gc_mini_dvd": load("res://carousel/media/gc_mini_dvd/gc_mini_dvd.tscn")}
	var row := _row(1, 0)
	var seen: Dictionary[String, bool] = {}
	for i in 20:
		var games := Fixtures.games(random.randi_range(1, 12))
		for game in games:
			game.medium = models.keys()[random.randi_range(0, models.size() - 1)]
		row.show_shelf(games, random.randi_range(0, games.size() - 1), models, ShelfRow.LabelLook.new())
		for move in random.randi_range(1, 8):
			row.step(Fixtures.direction(random))
			_frames(row, random.randi_range(1, 20), Fixtures.FRAME_S)
			for place: ShelfRow.Place in row.get_children():
				if not place.visible:
					continue
				var medium := games[place.game].medium
				seen[medium] = true
				assert_object(place._models.get(models[medium])).is_same(place.shown)
				for made: ShelfRow.LabelledModel in place._models.values():
					assert_bool(made.visible).is_equal(made == place.shown)
	assert_int(seen.size()).is_equal(models.size())


func test_a_shelf_of_one_game_does_not_move() -> void:
	var row := _row(1, 0)
	row.hold(1)
	_frames(row, 120, Fixtures.FRAME_S)
	assert_str(row.selected_game().id).is_equal("test/0")


func test_the_games_around_the_selected_one_are_it_then_its_neighbours_nearest_first_each_once() -> void:
	var ids := func(games: Array[AndroidServices.Game]) -> Array:
		return games.map(func(game: AndroidServices.Game) -> String: return game.id)
	assert_array(ids.call(_row(5, 2).games_around(1))).is_equal(["test/2", "test/3", "test/1"])
	assert_array(ids.call(_row(5, 0).games_around(2))).is_equal(["test/0", "test/1", "test/4", "test/2", "test/3"])
	assert_array(ids.call(_row(2, 1).games_around(1))).is_equal(["test/1", "test/0"])
	assert_array(ids.call(_row(1, 0).games_around(2))).is_equal(["test/0"])


func test_a_blank_shows_no_title_nor_platform_until_a_try_found_no_image_then_both() -> void:
	var row := _row(3, 1)
	row._look.platform_name = "PlayStation 2"
	_frames(row, ShelfRow._PLACES, 0.016)
	var titles := func() -> Dictionary:
		var shown := {}
		for place: ShelfRow.Place in row.get_children():
			if place.visible:
				shown[row._games[place.game].id] = [place.shown._title.text, place.shown._platform.text]
		return shown
	assert_dict(titles.call()).is_equal({"test/0": ["", ""], "test/1": ["", ""], "test/2": ["", ""]})
	row.label_images.mark_absent("test/2")
	row.refresh_label("test/2")
	assert_dict(titles.call()).is_equal({"test/0": ["", ""], "test/1": ["", ""], "test/2": [row._games[2].title, "PlayStation 2"]})
	# Shown again, a game found to have none is titled at once, the others plain.
	row.label_images.mark_absent("test/0")
	row.show_shelf(row._games, 1, Fixtures.DVDS, row._look)
	_frames(row, ShelfRow._PLACES, 0.016)
	assert_str(titles.call()["test/0"][0]).is_equal(row._games[0].title)
	assert_str(titles.call()["test/1"][0]).is_empty()


## A row showing [param count] test games from [param selected], moved only by the test, with no
## label images whatever the developer's own folder holds.
func _row(count: int, selected: int, floating := false) -> ShelfRow:
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = auto_free(Fixtures.FakeArt.new())
	if floating:
		row.games_float = true
	add_child(row)
	row.show_shelf(Fixtures.games(count), selected, Fixtures.DVDS, ShelfRow.LabelLook.new())
	row.set_process(false)
	return row


func _frames(row: ShelfRow, frames: int, frame_s: float) -> void:
	for frame in frames:
		row._process(frame_s)


## [param row]'s places show, stand and fade as [param twin]'s; a place not shown is not drawn.
func _assert_twins(row: ShelfRow, twin: ShelfRow) -> void:
	for place: ShelfRow.Place in row.get_children():
		var other: ShelfRow.Place = twin.get_child(place.get_index())
		assert_bool(place.visible).is_equal(other.visible)
		if place.visible:
			assert_bool(place.transform == other.transform).is_true()
			assert_float(place.shown._fade.amount).is_equal(other.shown._fade.amount)


## The visible places show each game in view once, where the layout puts it, with its own label
## once drawn.
func _assert_places(row: ShelfRow, count: int) -> void:
	var offsets := GamesLayout.offsets(count, row._scroll)
	var shown := []
	for place: ShelfRow.Place in row.get_children():
		if place.visible:
			shown.append(place.game)
			assert_float(place.transform.origin.x).is_equal_approx(GamesLayout.new("ps2_dvd").standing(offsets[place.game]).origin.x, 0.0001)
			var label: ShaderMaterial = place.shown._label_mesh.get_active_material(0)
			if label.get_shader_parameter(&"has_label"):
				var game := row._games[place.game]
				assert_str(place.shown._title.text).is_equal(game.title if row.label_images.is_absent(game) else "")
	shown.sort()
	var in_view := offsets.keys()
	in_view.sort()
	assert_array(shown).is_equal(in_view)


func test_gone_the_games_stand_still_wholly_faded_and_come_back_where_a_row_never_gone_stands() -> void:
	var random := Fixtures.cases(61)
	for i in 30:
		var count := random.randi_range(1, 12)
		var gone := _row(count, 0)
		var shown := _row(count, 0)
		var frames := random.randi_range(1, 120)
		_frames(gone, frames, Fixtures.FRAME_S)
		_frames(shown, frames, Fixtures.FRAME_S)
		gone.selected_presence = 0.0
		gone.neighbours = 0.0
		_frames(gone, 1, Fixtures.FRAME_S)
		_frames(shown, 1, Fixtures.FRAME_S)
		var stood: Array[Transform3D] = []
		for place: ShelfRow.Place in gone.get_children():
			stood.append(place.transform)
		var away := random.randi_range(1, 200)
		_frames(gone, away, Fixtures.FRAME_S)
		_frames(shown, away, Fixtures.FRAME_S)
		for place: ShelfRow.Place in gone.get_children():
			assert_bool(place.transform == stood[place.get_index()]).is_true()
			if place.visible:
				assert_float(place.shown._fade.amount).is_equal(1.0)
		gone.selected_presence = 1.0
		gone.neighbours = 1.0
		_frames(gone, 1, Fixtures.FRAME_S)
		_frames(shown, 1, Fixtures.FRAME_S)
		_assert_twins(gone, shown)
		if is_failure():
			return


func test_gone_the_row_still_takes_its_shelves_and_steps_and_comes_back_on_them_as_a_row_never_gone() -> void:
	var random := Fixtures.cases(63)
	for i in 20:
		var count := random.randi_range(1, 12)
		var gone := _row(count, 0)
		var shown := _row(count, 0)
		gone.selected_presence = 0.0
		gone.neighbours = 0.0
		# Gone, as on the consoles screen, where each console chosen shows its shelf.
		var games := Fixtures.games(random.randi_range(1, 12))
		var selected := random.randi_range(0, games.size() - 1)
		var direction := Fixtures.direction(random)
		var frames := random.randi_range(1, 30)
		for row: ShelfRow in [gone, shown]:
			_frames(row, 2, Fixtures.FRAME_S)
			row.show_shelf(games, selected, Fixtures.DVDS, ShelfRow.LabelLook.new())
			row.step(direction)
			_frames(row, frames, Fixtures.FRAME_S)
		for place: ShelfRow.Place in gone.get_children():
			var twin: ShelfRow.Place = shown.get_child(place.get_index())
			assert_int(place.game).is_equal(twin.game)
			assert_bool(place.visible).is_equal(twin.visible)
			if place.visible:
				assert_str(place.shown._title.text).is_equal(twin.shown._title.text)
		gone.selected_presence = 1.0
		gone.neighbours = 1.0
		_frames(gone, 1, Fixtures.FRAME_S)
		_frames(shown, 1, Fixtures.FRAME_S)
		_assert_twins(gone, shown)
		if is_failure():
			return


## The place of the selected game.
func _centre(row: ShelfRow) -> ShelfRow.Place:
	for place: ShelfRow.Place in row.get_children():
		if place.game == row.selected_index():
			return place
	return null


func test_twenty_fast_presses_keep_their_target_and_settle_on_the_twentieth_game() -> void:
	var row := _row(50, 0)
	for press in 20:
		row.hold(1)
		row.release(1)
		row._process(0.03)
	assert_int(row.selected_index()).is_equal(20)
	_frames(row, 120, Fixtures.FRAME_S)
	assert_float(row._scroll).is_equal(20.0)
	assert_float(row._spring.velocity).is_equal(0.0)
	_assert_places(row, 50)


func test_fast_selection_keeps_the_title_available_and_launching_brings_that_game_into_view() -> void:
	var row := _row(50, 0)
	for press in 20:
		row.step(1)
		assert_float(row.title_top()).is_between(680.0, 700.0)
	row.freeze()
	assert_int(row.selected_index()).is_equal(20)
	assert_bool(row._placed.has(20)).is_true()
	assert_bool(row.selected_stand().is_equal_approx(GamesLayout.new("ps2_dvd").chosen)).is_true()


## [param row] drawn through a screen camera, as in the app.
func _with_camera(row: ShelfRow) -> Camera3D:
	var camera: Camera3D = auto_free(Camera3D.new())
	add_child(camera)
	camera.position = Vector3(0.0, 0.1, 3.7)
	camera.fov = 32.0
	row.camera = camera
	_frames(row, 8, Fixtures.FRAME_S)
	return camera


func test_a_launch_of_a_shelf_of_one_or_two_games_takes_the_selected_one_out_and_brings_it_back() -> void:
	for count: int in [1, 2]:
		var row := _row(count, 0)
		_with_camera(row)
		var place := _centre(row)
		var stand := Transform3D(Basis.IDENTITY, Vector3(0.1, 0.2, 0.3))
		row.stand_selected(stand, 0.4, 0.1)
		_frames(row, 2, Fixtures.FRAME_S)
		assert_bool(place.transform.is_equal_approx(stand)).is_true()
		assert_object(place.shown.get_parent()).is_same(place)
		assert_bool(place.media_view.visible).is_false()
		assert_int(row._placed.size()).is_equal(count)
		row.pose_selected()
		_frames(row, 2, Fixtures.FRAME_S)
		assert_object(place.shown.get_parent()).is_same(place.media_view.holder())
		assert_bool(place.media_view.visible).is_true()


func test_a_filter_change_keeps_every_view_bound_to_its_own_model_and_makes_no_new_ones() -> void:
	var row := _row(5, 2)
	_with_camera(row)
	var all := Fixtures.games(5)
	var views := row.find_children("*", "MediaView", true, false).size()
	assert_int(views).is_equal(5)
	var models := ShelfRow.LabelledModel.alive
	for kept: Array in [[1, 2], [0, 3, 4], [4], [0, 1, 2, 3, 4]]:
		var games: Array[AndroidServices.Game] = []
		for index: int in kept:
			games.append(all[index])
		row.show_games(games, 0)
		_frames(row, 3, Fixtures.FRAME_S)
		assert_int(row.find_children("*", "MediaView", true, false).size()).is_equal(views)
		for place: ShelfRow.Place in row._places:
			if place.game >= 0:
				assert_object(place.media_view).is_not_null()
				assert_object(place.shown.get_parent()).is_same(place.media_view.holder())
		assert_int(ShelfRow.LabelledModel.alive).is_equal(models)


func test_a_shelf_without_its_model_shown_yet_gives_a_pill_top_without_failing() -> void:
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = auto_free(Fixtures.FakeArt.new())
	add_child(row)
	row.show_shelf(Fixtures.games(3), 0, Fixtures.DVDS, ShelfRow.LabelLook.new())
	row._placed.clear()
	assert_float(row.title_top()).is_equal(0.0)


func test_a_jump_takes_the_shorter_way_round_the_ring_and_the_forward_one_at_half() -> void:
	var row := _row(10, 0)
	row.jump(9, 1, 0.0)
	assert_int(row._position).is_equal(-1)
	row.jump(2, 1, 0.0)
	assert_int(row._position).is_equal(2)
	row.jump(7, 1, 0.0)
	assert_int(row._position).is_equal(7)
	assert_int(row.selected_index()).is_equal(7)
