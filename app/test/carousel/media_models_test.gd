# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const APPEARANCE := "res://data/carousel/appearance.json"
const PROFILES := "res://data/platforms/profiles.json"


func test_INV_E2_06_every_media_of_the_platforms_has_a_model() -> void:
	var models: Dictionary = _json(APPEARANCE)["models"]
	var profiles: Dictionary = _json(PROFILES)
	for platform: String in profiles:
		var profile: Dictionary = profiles[platform]
		assert_bool(models.has(profile["media"])).override_failure_message("no model for %s" % platform).is_true()


func test_INV_E2_06_every_model_loads_with_a_label_the_carousel_draws_on() -> void:
	var models: Dictionary = _json(APPEARANCE)["models"]
	for media: String in models:
		var path: String = models[media]
		var scene: PackedScene = load(path)
		var model: ShelfRow.LabelledModel = auto_free(ShelfRow.LabelledModel.new(scene))
		add_child(model)
		model.draw_label("Title", ShelfRow.LabelLook.new())
		var uniforms := model._materials[0].shader.get_shader_uniform_list().map(func(uniform: Dictionary) -> String: return uniform["name"])
		assert_array(uniforms).override_failure_message("%s: its label cannot be drawn" % path).contains(["label_texture", "has_label"])


func test_INV_E2_5_04_every_model_is_built_from_dimensions_that_fit_and_every_part_has_faces() -> void:
	var models: Dictionary = _json(APPEARANCE)["models"]
	for path: String in models.values():
		var scene: PackedScene = load(path)
		var model: Node3D = auto_free(scene.instantiate())
		var parts := model.find_children("*", "MeshInstance3D", true, false)
		assert_array(parts).is_not_empty()
		for part: MeshInstance3D in parts:
			assert_bool(part.mesh is ShapedMesh).override_failure_message("%s: %s is not built from dimensions" % [path, part.name]).is_true()
			var shaped := part.mesh as ShapedMesh
			assert_array(shaped.shape.problems()).override_failure_message("%s: %s" % [path, shaped.shape.problems()]).is_empty()
			var faces: PackedInt32Array = shaped.get_mesh_arrays()[Mesh.ARRAY_INDEX]
			assert_int(faces.size()).is_greater(0)


func test_INV_E2_5_05_a_game_without_a_label_image_shows_its_title_in_ink_that_stands_out() -> void:
	var random := Fixtures.cases(60)
	var models: Dictionary = _json(APPEARANCE)["models"]
	for path: String in models.values():
		var scene: PackedScene = load(path)
		var model: ShelfRow.LabelledModel = auto_free(ShelfRow.LabelledModel.new(scene))
		add_child(model)
		var title: Label = model.find_child("Title", true, false)
		var material := _label_material(model)
		for i in 200:
			var look := ShelfRow.LabelLook.new()
			look.color = Color(random.randf(), random.randf(), random.randf())
			look.demo_art = random.randf() < 0.25
			model.draw_label("Some Game: A Long Title II", look)
			assert_str(title.text).is_equal("Some Game: A Long Title II")
			assert_bool(material.get_shader_parameter(&"has_label")).is_true()
			var ink: Color = title.get_theme_color(&"font_color")
			if look.demo_art:
				# Artwork is bright and dark in places: white ink, outlined.
				assert_that(ink).is_equal(Color.WHITE)
				assert_int(title.get_theme_constant(&"outline_size")).is_greater(0)
			else:
				assert_float(absf(ink.get_luminance() - look.color.get_luminance())).is_greater_equal(0.43)


func test_a_game_without_a_scan_is_drawn_as_a_blank_of_its_console_its_band_reading_the_console_s_mark() -> void:
	var model: ShelfRow.LabelledModel = auto_free(ShelfRow.LabelledModel.new(Fixtures.DVD))
	add_child(model)
	var look := ShelfRow.LabelLook.new()
	look.platform_name = "Sony PlayStation 2"
	model.draw_label("Konjiki no Gashbell!!", look)
	var band: ColorRect = model.find_child("Band", true, false)
	var platform: Label = model.find_child("Platform", true, false)
	assert_bool(band.visible).is_false()
	assert_str(platform.text).is_equal("Sony PlayStation 2")
	look.band = Color(0.09, 0.09, 0.11)
	look.band_text = "PlayStation 2"
	model.draw_label("Konjiki no Gashbell!!", look)
	assert_bool(band.visible).is_true()
	assert_that(band.color).is_equal(look.band)
	assert_str(platform.text).is_equal("PlayStation 2")
	assert_that(platform.get_theme_color(&"font_color")).is_equal(Color.WHITE)
	# Under the platform's name, down to the label's edge.
	assert_float(band.position.y).is_less(platform.position.y)
	var view: SubViewport = model.find_child("LabelView", true, false)
	assert_float(band.position.y + band.size.y).is_equal_approx(view.size.y, 0.01)


func test_INV_E2_5_05_a_game_with_a_label_image_shows_it_and_the_others_their_title() -> void:
	var games := Fixtures.games(3)
	var image := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var images: Dictionary[String, Texture2D] = {games[1].title: image}
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = auto_free(Fixtures.FakeArt.new(images))
	add_child(row)
	row.show_shelf(games, 0, Fixtures.DVD, ShelfRow.LabelLook.new())
	row.set_process(false)
	for frame in 10:
		row._process(Fixtures.FRAME_S)
	var seen := 0
	for place: ShelfRow.Place in row.get_children():
		if place.visible:
			var material := _label_material(place.shown)
			var title := games[place.game].title
			var title_drawn: Label = place.shown.find_child("Title", true, false)
			if title in images:
				seen += 1
				assert_object(material.get_shader_parameter(&"label_texture")).is_equal(image)
				assert_bool(material.get_shader_parameter(&"scanned")).is_true()
			else:
				assert_str(title_drawn.text).is_equal(title)
				assert_bool(material.get_shader_parameter(&"scanned")).is_false()
	assert_int(seen).is_equal(1)


func test_INV_E4_07_a_scan_that_arrives_replaces_the_title_of_its_game_in_view_and_nothing_else() -> void:
	var games := Fixtures.games(3)
	var art: Fixtures.FakeArt = auto_free(Fixtures.FakeArt.new())
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = art
	add_child(row)
	row.show_shelf(games, 1, Fixtures.DVD, ShelfRow.LabelLook.new())
	row.set_process(false)
	for frame in 10:
		row._process(Fixtures.FRAME_S)
	var earlier: Dictionary[int, Array] = {}
	for place: ShelfRow.Place in row.get_children():
		if place.visible:
			earlier[place.game] = [_label_material(place.shown).get_shader_parameter(&"label_texture"), place.transform]
	var scan := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	art.arrive(games[1], scan)
	assert_array(earlier.keys()).contains_exactly_in_any_order([0, 1, 2])
	for place: ShelfRow.Place in row.get_children():
		if place.visible:
			var material := _label_material(place.shown)
			var shown: Texture2D = material.get_shader_parameter(&"label_texture")
			assert_that(place.transform).is_equal(earlier[place.game][1])
			if place.game == 1:
				assert_object(shown).is_equal(scan)
				assert_bool(material.get_shader_parameter(&"scanned")).is_true()
			else:
				assert_object(shown).is_equal(earlier[place.game][0])
				assert_bool(material.get_shader_parameter(&"scanned")).is_false()
	assert_str(row.selected_game().id).is_equal(games[1].id)


## The material of [param model]'s label.
func _label_material(model: Node3D) -> ShaderMaterial:
	var label: MeshInstance3D = model.find_child("Label", true, false)
	return label.get_surface_override_material(0)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))


func test_a_model_fades_through_transparent_copies_of_its_materials_and_is_opaque_again_once_not_faded() -> void:
	var random := Fixtures.cases(60)
	for scene: PackedScene in [preload("res://carousel/models/dvd.tscn"), preload("res://carousel/models/cartridge.tscn"),
			preload("res://carousel/consoles/ps2_slim.tscn")]:
		var model: Node3D = auto_free(scene.instantiate())
		add_child(model)
		var own: Dictionary[MeshInstance3D, Array] = {}
		for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			var materials: Array[Material] = []
			for surface in geometry.mesh.get_surface_count():
				materials.append(geometry.get_active_material(surface))
			own[geometry] = materials
		var fade := ModelFade.new(model)
		for i in 30:
			var amounts: Array[float] = [0.0, 1.0, random.randf_range(0.01, 0.99)]
			var amount := amounts[i % 3]
			fade.apply(amount)
			for geometry: MeshInstance3D in own:
				assert_bool(geometry.visible).is_equal(amount < 0.999)
				for surface in geometry.mesh.get_surface_count():
					var drawn := geometry.get_active_material(surface)
					var original: Material = own[geometry][surface]
					if amount == 0.0:
						assert_object(drawn).is_same(original)
					elif drawn is BaseMaterial3D:
						var standard: BaseMaterial3D = drawn
						assert_float(standard.albedo_color.a).is_equal_approx(1.0 - amount, 0.0001)
						assert_int(standard.transparency).is_equal(BaseMaterial3D.TRANSPARENCY_ALPHA)
						assert_int(standard.depth_draw_mode).is_equal(BaseMaterial3D.DEPTH_DRAW_ALWAYS)
					else:
						var faded: float = geometry.get_instance_shader_parameter(&"fade")
						assert_float(faded).is_equal_approx(amount, 0.0001)


func test_a_faded_game_shows_the_label_drawn_on_it_as_it_would_opaque() -> void:
	for scene: PackedScene in [preload("res://carousel/models/dvd.tscn"), preload("res://carousel/models/cartridge.tscn")]:
		var model: ShelfRow.LabelledModel = auto_free(ShelfRow.LabelledModel.new(scene))
		add_child(model)
		var label: MeshInstance3D = model.find_child("Label", true, false)
		var image := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGB8))
		for amount: float in [0.5, 0.0, 0.3]:
			model.fade(amount)
			model.show_label(image, amount > 0.0)
			var drawn: ShaderMaterial = label.get_active_material(0)
			assert_bool(drawn.get_shader_parameter(&"has_label")).is_true()
			assert_object(drawn.get_shader_parameter(&"label_texture")).is_same(image)
			assert_bool(drawn.get_shader_parameter(&"scanned")).is_equal(amount > 0.0)
			model.clear_label()
			assert_bool(drawn.get_shader_parameter(&"has_label")).is_false()
