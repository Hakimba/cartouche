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
		var uniforms := model._material.shader.get_shader_uniform_list().map(func(uniform: Dictionary) -> String: return uniform["name"])
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


func test_INV_E2_5_05_a_game_with_a_label_image_shows_it_and_the_others_their_title() -> void:
	var games := Fixtures.games(3)
	var image := ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var images: Dictionary[String, Texture2D] = {games[1].title: image}
	var row: ShelfRow = auto_free(ShelfRow.new())
	row.label_images = Fixtures.FakeLabels.new(images)
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


## The material of [param model]'s label.
func _label_material(model: Node3D) -> ShaderMaterial:
	var label: MeshInstance3D = model.find_child("Label", true, false)
	return label.get_surface_override_material(0)


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
