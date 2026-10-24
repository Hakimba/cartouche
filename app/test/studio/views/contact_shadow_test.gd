# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

## The frame's size over 3.72, the size each console's ground is baked at.
const _SIZE := Vector2i(344, 258)


func test_every_console_has_its_baked_shadow_and_reflection_and_draws_them_as_they_are() -> void:
	var consoles := ConsoleManifest.found()
	assert_int(consoles.size()).is_equal(14)
	for manifest in consoles:
		var folder := ConsoleManifest.folder_of(manifest)
		var shown: ContactShadow = auto_free(ContactShadow.new())
		shown.show_ground(folder)
		var layers := shown.layers()
		for i in layers.size():
			var path := ContactShadow.FOLDER + "%s-%s.png" % [folder, ["shadow", "reflection"][i]]
			assert_object(layers[i].texture).override_failure_message(path).is_equal(load(path))
			assert_vector(layers[i].texture.get_size()).is_equal(Vector2(_SIZE))
			# Plain pictures: the softness is baked in.
			assert_object(layers[i].material).is_null()
		# The reflection lies over the shadow.
		assert_int(layers[1].get_index()).is_greater(layers[0].get_index())
		var shadow := layers[0].texture.get_image()
		assert_float(shadow.get_used_rect().size.length()).override_failure_message(folder).is_greater(10.0)


func test_the_ring_shows_the_shadow_alone_the_consoles_screen_the_reflection_alone_and_a_console_without_a_ground_nothing() -> void:
	var shown: ContactShadow = auto_free(ContactShadow.new())
	shown.show_ground("nes", true, false)
	assert_object(shown.layers()[1].texture).is_null()
	assert_object(shown.layers()[0].texture).is_equal(load(ContactShadow.FOLDER + "nes-shadow.png"))
	shown.show_ground("nes", false)
	assert_object(shown.layers()[0].texture).is_null()
	assert_object(shown.layers()[1].texture).is_equal(load(ContactShadow.FOLDER + "nes-reflection.png"))
	shown.show_ground("no_such_console")
	for layer in shown.layers():
		assert_vector(layer.texture.get_size()).is_equal(Vector2.ZERO)
