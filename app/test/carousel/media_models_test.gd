# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_an_image_of_another_shape_covers_the_label_its_middle_shown_never_stretched() -> void:
	for path in Fixtures.medium_scenes():
		var scene: PackedScene = load(path)
		var model: LabelledModel = auto_free(LabelledModel.new(scene))
		add_child(model)
		for size: Vector2i in [Vector2i(400, 100), Vector2i(100, 400), Vector2i(300, 300)]:
			var image := ImageTexture.create_from_image(Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8))
			for window: Rect2 in [LabelledModel.WHOLE, Rect2(0.25, 0.0, 0.5, 0.5)]:
				model.show_label(image, window)
				var material: ShaderMaterial = model._label_mesh.get_active_material(0)
				var shown: Vector4 = material.get_shader_parameter(&"label_window")
				var part := Rect2(shown.x, shown.y, shown.z, shown.w)
				# Within the window asked, round its centre, filling it one way, of the label's own shape.
				assert_bool(window.grow(0.0001).encloses(part)).override_failure_message("%s: %s off %s" % [path, part, window]).is_true()
				assert_vector(part.get_center()).is_equal_approx(window.get_center(), Vector2.ONE * 0.0001)
				assert_bool(is_equal_approx(part.size.x, window.size.x) or is_equal_approx(part.size.y, window.size.y)).is_true()
				var pixels := part.size * Vector2(size)
				assert_float(pixels.x / pixels.y).is_equal_approx(model.label_proportion, 0.0001)


func test_a_scan_that_arrives_replaces_the_title_of_its_game_in_view_and_nothing_else() -> void:
	var games := Fixtures.games(3)
	var art: Fixtures.FakeArt = auto_free(Fixtures.FakeArt.new())
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = art
	add_child(row)
	row.show_shelf(games, 1, Fixtures.DVDS, ShelfRow.LabelLook.new())
	row.set_process(false)
	for frame in 10:
		row._process(Fixtures.FRAME_S)
	var earlier: Dictionary[int, Array] = {}
	for place: ShelfPlace in row.get_children():
		if place.visible:
			earlier[row.game_at(place)] = [_label_material(place.shown).get_shader_parameter(&"label_texture"), place.transform]
	var scan := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	art.arrive(games[1], scan)
	assert_array(earlier.keys()).contains_exactly_in_any_order([0, 1, 2])
	for place: ShelfPlace in row.get_children():
		if place.visible:
			var material := _label_material(place.shown)
			var shown: Texture2D = material.get_shader_parameter(&"label_texture")
			assert_that(place.transform).is_equal(earlier[row.game_at(place)][1])
			if row.game_at(place) == 1:
				assert_object(shown).is_equal(scan)
				assert_bool(material.get_shader_parameter(&"scanned")).is_true()
			else:
				assert_object(shown).is_equal(earlier[row.game_at(place)][0])
				assert_bool(material.get_shader_parameter(&"scanned")).is_false()
	assert_str(row.selected_game().id).is_equal(games[1].id)


## The material of [param model]'s label.
func test_a_label_s_view_holds_a_picture_only_while_its_blank_is_shown() -> void:
	var model: LabelledModel = auto_free(LabelledModel.new(Fixtures.DVD))
	add_child(model)
	var held := LabelledModel.held_views
	var view: SubViewport = model.find_child("LabelView", true, false)
	var scan := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var drawn_size := view.size
	for shown: StringName in [&"blank", &"scan", &"blank", &"nothing", &"blank"]:
		match shown:
			&"blank": model.draw_label("Title", ShelfRow.LabelLook.new())
			&"scan": model.show_label(scan)
			&"nothing": model.clear_label()
		if shown == &"blank":
			drawn_size = view.size
		assert_int(LabelledModel.held_views - held).override_failure_message(shown).is_equal(1 if shown == &"blank" else 0)
		assert_bool(view.size.x * view.size.y > 16).override_failure_message(shown).is_equal(shown == &"blank")
	assert_that(drawn_size).is_equal(model._drawn_size)
	model.free()
	assert_int(LabelledModel.held_views).is_equal(held)


func test_as_the_app_leaves_only_the_labels_in_view_and_the_pick_s_keep_their_picture_and_show_unchanged() -> void:
	var games := Fixtures.games(12)
	var art: GameArt = auto_free(GameArt.new())
	for game in games:
		var scan := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
		art.add(AndroidServices.Art.new({"game_id": game.id, "path": ""}), scan)
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = art
	row.random = Fixtures.cases(3)
	add_child(row)
	row.show_shelf(games, 4, Fixtures.DVDS, ShelfRow.LabelLook.new())
	row.set_process(false)
	for frame in 10:
		row._process(Fixtures.FRAME_S)
	var shown := _labels_shown(row)
	var needed: Array[AndroidServices.Game] = []
	for game: int in shown:
		needed.append(games[game])
	for side: int in [0, -1, 1]:
		needed.append(games[posmod(row._pick + side, games.size())])
	row.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_that(_labels_shown(row)).is_equal(shown)
	for game in games:
		assert_bool(art.has_texture(game)).override_failure_message(game.title).is_equal(game in needed)
		assert_bool(art.has_art(game)).is_true()


## The texture each game in view shows, by index.
func _labels_shown(row: ShelfRow) -> Dictionary[int, Texture2D]:
	var shown: Dictionary[int, Texture2D] = {}
	for place: ShelfPlace in row._placed.values():
		shown[row.game_at(place)] = _label_material(place.shown).get_shader_parameter(&"label_texture")
	return shown


func _label_material(model: Node3D) -> ShaderMaterial:
	var label: MeshInstance3D = model.find_child("Label", true, false)
	return label.get_surface_override_material(0)
