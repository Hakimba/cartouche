# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const ProjectFiles := preload("res://test/studio/project_files.gd")
const ScreenFixtures := preload("res://test/screens/fixtures.gd")


func test_the_pills_and_the_ball_stand_at_the_design_s_places() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var clock: Control = carousel.get_node("%Clock")
	var battery: Control = carousel.get_node("%Battery")
	assert_that(clock.get_global_rect()).is_equal(StudioTokens.CLOCK)
	assert_that(battery.get_global_rect()).is_equal(StudioTokens.BATTERY)
	var ball: AddBall = carousel.get_node("%AddBall")
	# Closed, the ball drawn where the design draws it, a pixel lower (the app's place, C-19).
	var drawn := ball.get_global_transform() * ball.white_box()
	assert_that(drawn).is_equal(Rect2(608, 30, 64, 64))


func test_the_clock_shows_the_time_in_the_pill_s_tabular_figures() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var clock: StudioPill = carousel.get_node("%Clock")
	assert_int(clock.role).is_equal(StudioTokens.Role.PILL)
	assert_bool(RegEx.create_from_string("^\\d\\d:\\d\\d$").search(clock.text) != null).is_true()


func test_a_console_s_gel_is_its_folder_s() -> void:
	var manifests := ConsoleManifest.found()
	var ps2: ConsoleManifest = manifests.filter(func(manifest: ConsoleManifest) -> bool:
		return ConsoleManifest.folder_of(manifest) == "ps2_slim")[0]
	assert_that(Cyclorama.gel_of(ps2)).is_equal(Color("#2f6fc6"))


func test_the_lights_lie_where_the_design_paints_them() -> void:
	var backdrop: Cyclorama = auto_free(Cyclorama.new())
	add_child(backdrop)
	# Paint order: the key light, then the floor's light over it.
	assert_array(backdrop._glows.get_shader_parameter(&"centres")).is_equal([Vector2(640, 288), Vector2(640, 678.4)])
	assert_array(backdrop._glows.get_shader_parameter(&"radii")).is_equal([Vector2(742.4, 409.6), Vector2(563.2, 115.2)])


func test_no_shader_moves_with_the_engine_s_time() -> void:
	var shaders := ProjectFiles.under("res://", ["gdshader", "gdshaderinc"], ["addons", ".godot", "android"])
	assert_array(shaders).is_not_empty()
	for path in shaders:
		var code := FileAccess.get_file_as_string(path)
		assert_bool(RegEx.create_from_string("\\bTIME\\b").search(code) == null).override_failure_message(path + " reads TIME").is_true()


func test_each_material_takes_the_design_s_recipe() -> void:
	var satin := SatinPanel.Backing.recipe(StudioMaterial.new(StudioTokens.Look.SATIN))
	assert_int(satin[&"shadow_count"]).is_equal(3)
	assert_int(satin[&"inset_count"]).is_equal(1)
	assert_array(satin[&"shadow_shapes"]).is_equal([Vector4(0, 1.28, 0, 0), Vector4(0, 1.54, 2.56, 0), Vector4(0, 10.24, 20.48, -6.4)])
	assert_float(satin[&"radius"]).is_equal(14.08)
	var frost := SatinPanel.Backing.recipe(StudioMaterial.new(StudioTokens.Look.FROST))
	var fill: Vector4 = frost[&"colors"][0]
	assert_str(Color(fill.x, fill.y, fill.z, fill.w).to_html()).is_equal(Color(1, 252.0 / 255.0, 247.0 / 255.0, 0.62).to_html())
	var focus := SatinPanel.Backing.recipe(StudioMaterial.new(StudioTokens.Look.FOCUS), Color.RED)
	# The ring and its glow take the gel; the drop shadow keeps its warm colour.
	var shown: Array[String] = []
	for color: Vector4 in focus[&"shadow_colors"]:
		shown.append(Color(color.x, color.y, color.z, color.w).to_html())
	assert_array(shown).is_equal([Color.WHITE.to_html(), Color.RED.to_html(), Color(Color.RED, 0.35).to_html(),
		Color8(70, 52, 34, 89).to_html()])


func test_a_logo_shows_at_its_slot_s_pixel_size_and_nothing_where_there_is_none() -> void:
	var logo: LogoView = auto_free(LogoView.new())
	for slot: LogoView.Slot in LogoView.Slot.values():
		assert_bool(logo.show_logo(slot, "ps2_slim")).is_true()
	logo.show_logo(LogoView.Slot.GAMES_TOP, "ps2_slim")
	assert_vector(logo.get_combined_minimum_size()).is_equal(Vector2(416, 101))
	assert_bool(logo.show_logo(LogoView.Slot.RAIL_TILE, "no_such_logo")).is_false()
	assert_object(logo.texture).is_not_null()
	assert_vector(logo.texture.get_size()).is_equal(Vector2.ZERO)


func test_every_console_has_its_logo_in_every_slot() -> void:
	assert_int(ConsoleManifest.found().size()).is_greater_equal(12)
	for manifest in ConsoleManifest.found():
		var console := ConsoleManifest.folder_of(manifest)
		for folder in LogoView.FOLDERS:
			var path := "res://studio/logos/%s/%s.png" % [folder, console]
			assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()


func test_the_backdrop_shows_no_console_colour_only_the_designs_untinted_lights() -> void:
	var backdrop: Cyclorama = auto_free(Cyclorama.new())
	add_child(backdrop)
	var untinted := StudioTokens.BACKDROP_GLOWS.filter(func(glow: Array) -> bool: return not glow[4])
	assert_int(untinted.size()).is_less(StudioTokens.BACKDROP_GLOWS.size())
	assert_int(backdrop._glows.get_shader_parameter(&"count")).is_equal(untinted.size())
	assert_object(backdrop._glows.get_shader_parameter(&"gel")).is_null()


func test_the_wall_and_floor_are_a_quarter_size_smooth_picture_stretched_by_linear_filtering() -> void:
	var picture := Image.load_from_file("res://studio/cyclorama.png")
	assert_vector(Vector2(picture.get_size())).is_equal(Vector2(320, 240))
	var steepest := 0.0
	for y in picture.get_height():
		for x in picture.get_width():
			var here := picture.get_pixel(x, y)
			for next: Vector2i in [Vector2i(x + 1, y), Vector2i(x, y + 1)]:
				if next.x < picture.get_width() and next.y < picture.get_height():
					var there := picture.get_pixel(next.x, next.y)
					steepest = maxf(steepest, maxf(absf(here.r8 - there.r8), maxf(absf(here.g8 - there.g8), absf(here.b8 - there.b8))))
	assert_float(steepest).is_less_equal(1.0)
	var settings := ConfigFile.new()
	settings.load("res://studio/cyclorama.png.import")
	assert_int(settings.get_value("params", "compress/mode")).is_equal(0)
	assert_bool(settings.get_value("params", "mipmaps/generate")).is_false()
	assert_int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter")).is_equal(1)
	var backdrop: Cyclorama = auto_free(Cyclorama.new())
	add_child(backdrop)
	assert_int((backdrop.get_child(0) as TextureRect).texture_filter).is_equal(CanvasItem.TEXTURE_FILTER_PARENT_NODE)


func test_a_key_is_a_disc_for_a_letter_and_a_capsule_for_a_word_in_every_style() -> void:
	var chosen := Controls.style
	for style: StringName in [&"xbox", &"nintendo", &"playstation"]:
		Controls.style = style
		assert_vector(ButtonGlyph.key_size(&"a")).override_failure_message(style).is_equal(Vector2(32, 32))
		assert_vector(ButtonGlyph.key_size(&"l1")).override_failure_message(style).is_equal(Vector2(32, 32))
		assert_vector(ButtonGlyph.key_size(&"start")).override_failure_message(style).is_equal(Vector2(58.88, 32))
	Controls.style = &"playstation"
	assert_str(Controls.mark(&"a")).is_equal("✕")
	Controls.style = chosen


func test_the_pad_key_draws_the_design_s_two_triangles_not_text() -> void:
	var unit := ButtonMark.PAD_ARROWS_PX / 26.0
	var arrows := ButtonMark.pad_arrows(Vector2(100.0, 50.0), unit)
	assert_int(arrows.size()).is_equal(2)
	# Pointing outwards from the middle, tips 24 units apart, bases at 7 units from their tips, 10 high.
	assert_vector(arrows[0][0]).is_equal_approx(Vector2(100.0 - 12.0 * unit, 50.0), Vector2.ONE * 1e-3)
	assert_vector(arrows[1][0]).is_equal_approx(Vector2(100.0 + 12.0 * unit, 50.0), Vector2.ONE * 1e-3)
	assert_float(arrows[0][1].x - arrows[0][0].x).is_equal_approx(7.0 * unit, 1e-3)
	assert_float(arrows[1][0].x - arrows[1][1].x).is_equal_approx(7.0 * unit, 1e-3)
	assert_float(arrows[0][2].y - arrows[0][1].y).is_equal_approx(10.0 * unit, 1e-3)
	# Inside the pad key (58.88 px wide), and its mark is the arrows, not letters.
	assert_float(arrows[1][0].x - arrows[0][0].x).is_less(ButtonGlyph.key_size(&"← →").x)
	assert_str(Controls.mark(&"← →")).is_equal("← →")
