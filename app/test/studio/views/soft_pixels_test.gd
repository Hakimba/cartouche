# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The softened medium's shader as it draws (a window's renderer): a square as a view would hold it, its
## shadow under its edge against the Gaussian's own, faded by the item's modulate.

const _SIZE := 200
## The square: a long bottom edge, far from its corners at the middle column.
const _SQUARE := Rect2i(40, 40, 120, 60)
const _SHADOW_Y := 8.0
const _SHADOW_BLUR := 14.0
const _SHADOW_ALPHA := 0.28
const _FADED := 0.5


# GdUnit reads the skip from these arguments.
@warning_ignore("unused_parameter")
func test_a_square_casts_the_gaussian_shadow_below_its_edge_and_is_faded_whole(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	var square := Image.create(_SIZE, _SIZE, false, Image.FORMAT_RGBA8)
	square.fill_rect(_SQUARE, Color.WHITE)
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(_SIZE, _SIZE)
	view.transparent_bg = true
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var drawn := TextureRect.new()
	drawn.texture = ImageTexture.create_from_image(square)
	drawn.size = Vector2(_SIZE, _SIZE)
	drawn.modulate.a = _FADED
	var soft := ShaderMaterial.new()
	soft.shader = preload("res://studio/views/media_soft.gdshader")
	soft.set_shader_parameter(&"shadow_y", _SHADOW_Y)
	soft.set_shader_parameter(&"shadow_blur", _SHADOW_BLUR)
	soft.set_shader_parameter(&"shadow_colour", Color(0.27, 0.2, 0.13, _SHADOW_ALPHA))
	drawn.material = soft
	view.add_child(drawn)
	add_child(view)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var picture := view.get_texture().get_image()
	var middle := _SQUARE.get_center().x
	assert_float(picture.get_pixel(middle, _SQUARE.get_center().y).a).is_equal_approx(_FADED, 2.0 / 255.0)
	var bottom := _SQUARE.end.y
	var rows := 0
	for row in range(bottom, bottom + 30):
		# The cast square's coverage below its shifted edge, blurred by a Gaussian of standard deviation
		# blur / 2: half the complementary error function.
		var below := row + 0.5 - (bottom + _SHADOW_Y)
		var cast := 0.5 * (1.0 - _erf(below / (_SHADOW_BLUR / 2.0 * sqrt(2.0))))
		assert_float(picture.get_pixel(middle, row).a).override_failure_message("row %d below the edge" % (row - bottom)) \
			.is_equal_approx(_SHADOW_ALPHA * cast * _FADED, 3.0 / 255.0)
		rows += 1
	assert_int(rows).is_equal(30)


## The error function (Abramowitz and Stegun 7.1.26, within 1.5e-7).
static func _erf(x: float) -> float:
	var t := 1.0 / (1.0 + 0.3275911 * absf(x))
	var y := 1.0 - (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t - 0.284496736) * t + 0.254829592) * t * exp(-x * x)
	return signf(x) * y
