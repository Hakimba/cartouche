# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

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


func _json(path: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))
