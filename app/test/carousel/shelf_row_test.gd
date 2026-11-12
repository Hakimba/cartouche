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
		# Left alone, the row comes to rest on the game the last press reached.
		_frames(row, 120, Fixtures.FRAME_S)
		assert_bool(row.is_settling()).is_false()
		assert_int(row.selected_index()).is_equal(expected)


func test_two_games_stand_side_by_side_and_neither_jumps_across_the_screen_as_the_row_moves() -> void:
	for start in 2:
		var row := _row(2, start)
		_frames(row, 1, Fixtures.FRAME_S)
		for direction: int in [1, 1, -1, 1, -1, -1]:
			row.hold(direction)
			row.release(direction)
			for frame in 90:
				var stood: Array[float] = [row._placed[0].transform.origin.x, row._placed[1].transform.origin.x]
				row._process(Fixtures.FRAME_S)
				for game in 2:
					# A place apart is about one unit: a jump to the other side would be two.
					assert_float(absf(row._placed[game].transform.origin.x - stood[game])).is_less(0.5)
			assert_float(row._placed[0].transform.origin.x).is_less(row._placed[1].transform.origin.x)


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
			for place: ShelfPlace in row.get_children():
				if not place.visible:
					continue
				var medium := games[row.game_at(place)].medium
				seen[medium] = true
				assert_object(place._models.get(models[medium])).is_same(place.shown)
				for made: LabelledModel in place._models.values():
					assert_bool(made.visible).is_equal(made == place.shown)
	assert_int(seen.size()).is_equal(models.size())


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
	_frames(row, row._places.size(), 0.016)
	var titles := func() -> Dictionary:
		var shown := {}
		for place: ShelfPlace in row.get_children():
			if place.visible:
				shown[row._games[row.game_at(place)].id] = [place.shown._title.text, place.shown._platform.text]
		return shown
	assert_dict(titles.call()).is_equal({"test/0": ["", ""], "test/1": ["", ""], "test/2": ["", ""]})
	# A game with an image shows it and no title, whatever the others found.
	var scan := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	(row.label_images as Fixtures.FakeArt).arrive(row._games[1], scan)
	var material: ShaderMaterial = (row._placed[1] as ShelfPlace).shown._label_mesh.get_active_material(0)
	assert_object(material.get_shader_parameter(&"label_texture")).is_equal(scan)
	assert_bool(material.get_shader_parameter(&"scanned")).is_true()
	assert_dict(titles.call()).is_equal({"test/0": ["", ""], "test/1": ["", ""], "test/2": ["", ""]})
	row.label_images.mark_absent("test/2")
	row.refresh_label("test/2")
	assert_dict(titles.call()).is_equal({"test/0": ["", ""], "test/1": ["", ""], "test/2": [row._games[2].title, "PlayStation 2"]})
	# Shown again, a game found to have none is titled at once, the others plain.
	row.label_images.mark_absent("test/0")
	row.show_shelf(row._games, 1, Fixtures.DVDS, row._look)
	_frames(row, row._places.size(), 0.016)
	assert_str(titles.call()["test/0"][0]).is_equal(row._games[0].title)
	assert_str(titles.call()["test/1"][0]).is_empty()


func test_the_pick_is_never_the_selected_game_and_every_other_one_can_be_drawn() -> void:
	var random := Fixtures.cases(27)
	for count: int in [1, 2, 3, 7]:
		var row := _row(count, 0)
		assert_bool(row.has_pick()).is_equal(count > 1)
		var drawn: Dictionary[Vector2i, bool] = {}
		for draw in 100 * count if count > 1 else 0:
			row.show_games(row._games, draw % count)
			var pick := row._games.find(row.pick())
			assert_int(pick).is_not_equal(row.selected_index())
			drawn[Vector2i(row.selected_index(), pick)] = true
		assert_int(drawn.size()).is_equal(count * (count - 1))
		# Stepped or jumped onto, the pick is replaced.
		for move in 10 if count > 1 else 0:
			var target := row._games.find(row.pick())
			if random.randf() < 0.5:
				row.jump(target, Fixtures.direction(random), random.randf_range(0.0, 2.0))
			else:
				var way := Fixtures.direction(random)
				while row.selected_index() != target:
					row.step(way)
			assert_int(row._games.find(row.pick())).is_not_equal(row.selected_index())


func test_the_pick_selected_stands_in_the_middle_at_once_among_its_own_neighbours_its_label_drawn() -> void:
	var random := Fixtures.cases(26)
	for i in 40:
		var count := random.randi_range(2, 12)
		var row := _row(count, random.randi_range(0, count - 1))
		_frames(row, random.randi_range(0, 2 * row._places.size()), Fixtures.FRAME_S)
		for toss in random.randi_range(1, 4):
			var pick := row.pick()
			row.select_pick()
			assert_str(row.selected_game().id).is_equal(pick.id)
			assert_str(row.pick().id).is_not_equal(pick.id)
			assert_bool(row.is_settling()).is_false()
			assert_bool(row._placed[row.selected_index()] in row._unlabelled).is_false()
			_assert_places(row, count)
			if is_failure():
				return


## A row showing [param count] test games from [param selected], moved only by the test, its picks the same at every
## run, with no label images whatever the developer's own folder holds.
func _row(count: int, selected: int) -> ShelfRow:
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = auto_free(Fixtures.FakeArt.new())
	row.random = Fixtures.cases(count * 100 + selected)
	add_child(row)
	row.show_shelf(Fixtures.games(count), selected, Fixtures.DVDS, ShelfRow.LabelLook.new())
	row.set_process(false)
	return row


func _frames(row: ShelfRow, frames: int, frame_s: float) -> void:
	for frame in frames:
		row._process(frame_s)


## How present [param place]'s picture is drawn: -1 with no view yet.
static func _presence(place: ShelfPlace) -> float:
	return place.media_view.modulate.a if place.media_view else -1.0


## [param row]'s places show, stand and fade as [param twin]'s; a place not shown is not drawn.
func _assert_twins(row: ShelfRow, twin: ShelfRow) -> void:
	for place: ShelfPlace in row.get_children():
		var other: ShelfPlace = twin.get_child(place.get_index())
		assert_bool(place.visible).is_equal(other.visible)
		if place.visible:
			assert_bool(place.transform == other.transform).is_true()
			assert_float(_presence(place)).is_equal(_presence(other))


## The visible places show each game in view once, where the layout puts it, with its own label
## once drawn.
func _assert_places(row: ShelfRow, count: int) -> void:
	var offsets := GamesLayout.offsets(count, row._scroll)
	var shown := []
	for place: ShelfPlace in row.get_children():
		if place.visible:
			shown.append(row.game_at(place))
			assert_float(place.transform.origin.x).is_equal_approx(GamesLayout.new("ps2_dvd").standing(offsets[row.game_at(place)]).origin.x, 0.0001)
			var label: ShaderMaterial = place.shown._label_mesh.get_active_material(0)
			if label.get_shader_parameter(&"has_label"):
				var game := row._games[row.game_at(place)]
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
		for place: ShelfPlace in gone.get_children():
			stood.append(place.transform)
		var away := random.randi_range(1, 200)
		_frames(gone, away, Fixtures.FRAME_S)
		_frames(shown, away, Fixtures.FRAME_S)
		for place: ShelfPlace in gone.get_children():
			assert_bool(place.transform == stood[place.get_index()]).is_true()
			assert_bool(place.media_view != null and place.media_view.visible).is_false()
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
		for place: ShelfPlace in gone.get_children():
			var twin: ShelfPlace = shown.get_child(place.get_index())
			assert_int(gone.game_at(place)).is_equal(shown.game_at(twin))
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
func _centre(row: ShelfRow) -> ShelfPlace:
	for place: ShelfPlace in row.get_children():
		if row.game_at(place) == row.selected_index():
			return place
	return null


func test_fast_selection_keeps_the_title_available_and_launching_brings_that_game_into_view() -> void:
	var row := _row(50, 0)
	for press in 20:
		row.step(1)
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
		row.stand(SelectedStand.outside(stand, 0.4, 0.1))
		_frames(row, 2, Fixtures.FRAME_S)
		assert_bool(place.transform.is_equal_approx(stand)).is_true()
		assert_object(place.shown.get_parent()).is_same(place)
		assert_bool(place.media_view.visible).is_false()
		assert_int(row._placed.size()).is_equal(count)
		row.stand(SelectedStand.new())
		_frames(row, 2, Fixtures.FRAME_S)
		assert_object(place.shown.get_parent()).is_same(place.media_view.holder())
		assert_bool(place.media_view.visible).is_true()


func test_a_filter_change_keeps_every_view_bound_to_its_own_model_and_makes_no_new_ones() -> void:
	var row := _row(5, 2)
	_with_camera(row)
	var all := Fixtures.games(5)
	var views := row.find_children("*", "MediaView", true, false).size()
	assert_int(views).is_equal(5)
	var models := LabelledModel.alive
	for kept: Array in [[1, 2], [0, 3, 4], [4], [0, 1, 2, 3, 4]]:
		var games: Array[AndroidServices.Game] = []
		for index: int in kept:
			games.append(all[index])
		row.show_games(games, 0)
		_frames(row, 3, Fixtures.FRAME_S)
		assert_int(row.find_children("*", "MediaView", true, false).size()).is_equal(views)
		for place: ShelfPlace in row._places:
			if row.game_at(place) >= 0:
				assert_object(place.media_view).is_not_null()
				assert_object(place.shown.get_parent()).is_same(place.media_view.holder())
		assert_int(LabelledModel.alive).is_equal(models)


## A place left free while the row moves keeps its view's pictures for the game coming in; once the row rests (a
## search leaving fewer games) or the app is paused, a place with no game holds none.
func test_a_free_place_keeps_its_view_s_pictures_only_while_the_row_moves() -> void:
	var row := _row(10, 2)
	_with_camera(row)
	var kept := func() -> int:
		return row._places.filter(func(place: ShelfPlace) -> bool:
			return row.game_at(place) < 0 and place.media_view != null and place.media_view._holds).size()
	row.step(1)
	_frames(row, 3, Fixtures.FRAME_S)
	assert_int(kept.call()).override_failure_message("moving").is_equal(1)
	row.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_int(kept.call()).override_failure_message("paused").is_equal(0)
	row.show_games(Fixtures.games(2), 0)
	_frames(row, 3, Fixtures.FRAME_S)
	assert_int(kept.call()).override_failure_message("at rest").is_equal(0)


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


func test_the_label_reads_of_games_left_far_behind_stop_and_those_left_near_go_on() -> void:
	var path := ProjectSettings.globalize_path("user://far-reads.png")
	Image.create(8, 8, false, Image.FORMAT_RGBA8).save_png(path)
	var art: GameArt = auto_free(GameArt.new())
	add_child(art)
	var games := Fixtures.games(60)
	for game in games:
		art.add(AndroidServices.Art.new({"game_id": game.id, "path": path}))
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = art
	row.random = Fixtures.cases(1)
	add_child(row)
	row.show_shelf(games, 0, Fixtures.DVDS, ShelfRow.LabelLook.new())
	row.set_process(false)
	_frames(row, row._places.size(), Fixtures.FRAME_S)
	var reading := func(game: AndroidServices.Game) -> bool: return art._reader.is_reading(game.id)
	var asked := games.filter(reading)
	assert_array(asked).contains([games[0], games[59], games[1]])
	row.jump(5, 1, 0.0)
	_frames(row, 1, Fixtures.FRAME_S)
	assert_array(asked.filter(reading)).is_equal(asked)
	# A pick among the labels being read, far from where the row goes.
	row._pick = 59
	row.jump(30, 1, 0.0)
	_frames(row, 1, Fixtures.FRAME_S)
	# The pick and its neighbours are read still: the row may come to rest on them.
	var near_pick := func(game: AndroidServices.Game) -> bool: return posmod(games.find(game) - row._pick + 1, 60) <= 2
	assert_array(asked.filter(near_pick)).is_not_empty()
	assert_array(asked.filter(reading)).is_equal(asked.filter(near_pick))
	DirAccess.remove_absolute(path)
