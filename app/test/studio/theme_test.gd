# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const ScreenFixtures := preload("res://test/screens/fixtures.gd")
var _focus: SatinStyle = preload("res://studio/focus.tres")


func after_test() -> void:
	_focus.gel = StudioTokens.NEUTRAL


func test_the_labels_keep_their_own_font_and_size() -> void:
	var theme := ThemeDB.get_project_theme()
	for role: StringName in [&"LabelTitle", &"LabelPlatform"]:
		assert_str(theme.get_font(&"font", role).resource_path).is_equal("res://fonts/fredoka_medium.tres")
	assert_int(theme.get_font_size(&"font_size", &"LabelTitle")).is_equal(48)
	assert_int(theme.get_font_size(&"font_size", &"LabelPlatform")).is_equal(28)


func test_the_theme_writes_in_the_design_s_fonts_and_ink() -> void:
	var theme := ThemeDB.get_project_theme()
	assert_str(theme.default_font.resource_path).is_equal("res://fonts/plus-jakarta-sans/PlusJakartaSans-Bold.ttf")
	for role: StringName in [&"Label", &"Button"]:
		assert_str(theme.get_color(&"font_color", role).to_html()).is_equal(StudioTokens.INK.to_html())


func test_each_tracked_role_has_its_variation_the_tracking_times_its_size() -> void:
	var theme := ThemeDB.get_project_theme()
	# Role, face, the reference's tracking in em.
	for told: Array in [[&"ScreenTitle", "ExtraBold", -0.04], [&"PanelTitle", "ExtraBold", -0.04], [&"NameButton", "ExtraBold", -0.035],
			[&"SearchCount", "IBMPlexMono-SemiBold", 0.08]]:
		var role: StringName = told[0]
		var variation := theme.get_font(&"font", role) as FontVariation
		assert_object(variation).override_failure_message(role).is_not_null()
		var face: String = told[1]
		assert_str(variation.base_font.resource_path).contains(face)
		var tracking: float = told[2]
		assert_int(variation.spacing_glyph).override_failure_message(role) \
			.is_equal(roundi(tracking * theme.get_font_size(&"font_size", role)))


func test_lines_are_spaced_as_the_css_line_box_less_the_face_s_own_height() -> void:
	var theme := ThemeDB.get_project_theme()
	# Plus Jakarta Sans is 1.26 em tall, IBM Plex Mono 1.3 em; the line box 1.5 em.
	assert_int(theme.get_constant(&"line_spacing", &"Label")).is_equal(roundi(0.24 * theme.default_font_size))
	assert_int(theme.get_constant(&"line_spacing", &"ScreenText")).is_equal(roundi(0.24 * theme.get_font_size(&"font_size", &"ScreenText")))


func test_buttons_fields_and_cards_are_satin_and_every_focus_is_the_one_focus_card() -> void:
	var theme := ThemeDB.get_project_theme()
	for type: StringName in [&"Button", &"Field", &"Card", &"Key", &"Ribbon", &"BigLetter"]:
		var style := theme.get_stylebox(&"panel" if type in [&"Ribbon", &"BigLetter"] else &"normal", type) as SatinStyle
		assert_object(style).override_failure_message(type).is_not_null()
		assert_int(style.look).is_equal(StudioTokens.Look.SATIN)
	for type: StringName in [&"Chip", &"SearchChip"]:
		var pill := theme.get_stylebox(&"normal" if type == &"Chip" else &"panel", type) as SatinStyle
		assert_int(pill.look).override_failure_message(type).is_equal(StudioTokens.Look.FROST)
	for type: StringName in [&"Button", &"Field", &"NameButton", &"Card"]:
		assert_object(theme.get_stylebox(&"focus", type)).override_failure_message(type).is_same(_focus)
	assert_int(_focus.look).is_equal(StudioTokens.Look.FOCUS)


func test_a_screen_in_front_takes_the_focus_ring_in_the_gel_of_the_console_it_opens_from() -> void:
	var carousel := await _two_consoles()
	var gels: Dictionary[String, Color] = {"ps2": Color("#2f6fc6"), "gc": Color("#7a5bd0")}
	for press in 2:
		var platform := carousel._shelves[carousel._shelf].platform_id
		await ScreenFixtures.joypad(self, JOY_BUTTON_Y)
		assert_bool(await ScreenFixtures.on(self, carousel, "Settings")).is_true()
		assert_that(_focus.gel).override_failure_message(platform).is_equal(gels[platform])
		await ScreenFixtures.joypad(self, JOY_BUTTON_B)
		assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._shown)).is_true()
		Fixtures.press(carousel, &"carousel_right")
		Fixtures.step_frames(carousel, 60)


func test_a_game_s_properties_take_the_focus_ring_in_the_gel_of_its_console() -> void:
	var carousel := await _two_consoles()
	while carousel._shelves[carousel._shelf].platform_id != "ps2":
		Fixtures.press(carousel, &"carousel_right")
		Fixtures.step_frames(carousel, 60)
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	await ScreenFixtures.joypad(self, JOY_BUTTON_X)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.PROPERTIES)
	assert_that(_focus.gel).is_equal(Color("#2f6fc6"))


func test_the_focus_card_drawn_again_in_a_new_gel_takes_it() -> void:
	var style := SatinStyle.new()
	style.look = StudioTokens.Look.FOCUS
	var size := Vector2(200, 60)
	var item := RenderingServer.canvas_item_create()
	style._draw(item, Rect2(Vector2.ZERO, size))
	RenderingServer.free_rid(item)
	assert_bool(style._built.has(size)).is_true()
	style.gel = Color.RED
	assert_bool(style._built.is_empty()).is_true()
	var ring := Array(style.build(size).colors).filter(func(color: Color) -> bool: return color.r == 1.0 and color.g == 0.0)
	assert_array(ring).is_not_empty()


func test_a_satin_style_draws_its_outer_shadows_outside_the_box_only_fading_to_nothing() -> void:
	var style := SatinStyle.new()
	style.look = StudioTokens.Look.FOCUS
	var box := Rect2(0, 0, 200, 60)
	var material := StudioMaterial.new(StudioTokens.Look.FOCUS)
	for shadow in material.shadows:
		if shadow.inset:
			continue
		var mesh := SatinStyle.Mesh2D.new()
		style.outer_shadow(mesh, box, shadow)
		var points := mesh.points
		var colors := mesh.colors
		assert_int(points.size()).is_greater(0)
		var faintest := 1.0
		for i in points.size():
			assert_float(_outside(points[i], box, material.radius)).override_failure_message("a shadow under the box").is_greater(-1e-3)
			faintest = minf(faintest, colors[i].a)
		assert_float(faintest).is_less(0.01)


func test_a_satin_style_fills_its_box_from_the_top_colour_to_the_bottom_one() -> void:
	var style := SatinStyle.new()
	var mesh := style.build(Vector2(200, 60))
	var points := mesh.points
	var colors := mesh.colors
	var top := Color("#fffdf9")
	var bottom := Color("#f4efe7")
	var checked := 0
	for i in points.size():
		if Rect2(0, 2, 200, 56).has_point(points[i]) and colors[i].a == 1.0 and colors[i] != Color.WHITE:
			assert_str(colors[i].to_html()).is_equal(top.lerp(bottom, points[i].y / 60.0).to_html())
			checked += 1
	assert_int(checked).is_greater(10)


func test_the_satin_s_shadows_fall_off_as_its_recipe_says() -> void:
	var material := StudioMaterial.new(StudioTokens.Look.SATIN)
	var outer := material.shadows.filter(func(shadow: StudioMaterial.Shadow) -> bool: return not shadow.inset)
	assert_array(outer.map(func(shadow: StudioMaterial.Shadow) -> String: return shadow.color.to_html())).is_equal(
		[Color8(70, 52, 34, roundi(0.14 * 255)).to_html(), Color8(70, 52, 34, roundi(0.28 * 255)).to_html()])
	var style := SatinStyle.new()
	var box := Rect2(0, 0, 200, 60)
	for shadow: StudioMaterial.Shadow in outer:
		var mesh := SatinStyle.Mesh2D.new()
		style.outer_shadow(mesh, box, shadow)
		var sigma := shadow.blur / 2.0
		var checked := 0
		for i in mesh.points.size():
			var point := mesh.points[i]
			# The points facing straight down or up, past the right corner's start, where the offset counts whole.
			if absf(point.x - (200.0 - material.radius)) > 1e-3 or (point.y > 0.0 and point.y < 60.0):
				continue
			var normal := 1.0 if point.y > 30.0 else -1.0
			var past := point.y - 60.0 if normal > 0.0 else -point.y
			var expected := shadow.color.a * _phi((shadow.spread + shadow.offset.y * normal - past) / sigma)
			assert_float(mesh.colors[i].a).is_equal_approx(expected, 1e-3)
			checked += 1
		assert_int(checked).is_greater(4)


func test_the_satin_s_highlight_lies_along_its_top_only() -> void:
	var mesh := SatinStyle.new().build(Vector2(200, 60))
	var lit := 0.0
	for k in range(0, mesh.indices.size(), 3):
		var corners: Array[int] = [mesh.indices[k], mesh.indices[k + 1], mesh.indices[k + 2]]
		if not corners.all(func(i: int) -> bool: return mesh.colors[i] == Color.WHITE):
			continue
		var a := mesh.points[corners[0]]
		var area := absf((mesh.points[corners[1]] - a).cross(mesh.points[corners[2]] - a)) / 2.0
		if area < 1e-6:
			continue
		lit += area
		for i in corners:
			# The top edge and the top corners' curve, the highlight's 1.28 px under them.
			assert_float(mesh.points[i].y).is_less_equal(StudioTokens.SATIN_RADIUS + 1.28 + 1e-3)
	# About the top edge's length times the offset.
	assert_float(lit).is_between(200.0 * 1.28 * 0.8, 200.0 * 1.28 * 1.1)


func _two_consoles() -> Carousel:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 2, "gc": 1})
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return carousel


## The standard normal distribution's cumulative function, from its series (independent of the style's).
func _phi(x: float) -> float:
	var sum := x
	var term := x
	for n in range(1, 200):
		term *= x * x / (2.0 * n + 1.0)
		sum += term
	return 0.5 + sum * exp(-x * x / 2.0) / sqrt(TAU)


## How far [param point] lies outside the box rounded by [param radius] (less than 0 inside it).
func _outside(point: Vector2, box: Rect2, radius: float) -> float:
	var q := (point - box.get_center()).abs() - box.size / 2.0 + Vector2.ONE * radius
	return q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - radius


func test_native_satin_buttons_share_the_four_states_and_keep_the_given_focus_gel() -> void:
	var button: Button = auto_free(Button.new())
	SatinStyle.apply_to(button, Color.CORAL)
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style := button.get_theme_stylebox(state) as SatinStyle
		assert_object(style).is_not_null()
		assert_int(style.look).is_equal(StudioTokens.Look.FOCUS if state == &"focus" else StudioTokens.Look.SATIN)
		assert_bool(style.gel == Color.CORAL).is_true()
