# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

## The design's strings: text, face, size in px, tracking in em, tabular figures; then what Chromium makes of
## each (the design's own fonts, hinting off), drawn white on black with its box's top left at (40, 40): its
## box's width, its ink's left and right (where a column's coverage crosses one half) and the ink's centroid.
const _BROWSER := [
	["22:26", StudioTokens.Face.JAKARTA_700, 23.68, 0.0, true, 65.765625, 40.63, 104.2, 72.85, 56.36],
	["100 %", StudioTokens.Face.JAKARTA_700, 23.68, 0.0, true, 71.59375, 40.35, 109.36, 74.06, 55.89],
	["Réglages", StudioTokens.Face.JAKARTA_700, 23.04, 0.0, false, 103.765625, 41.16, 142.44, 89.02, 57.15],
	["Propriétés", StudioTokens.Face.JAKARTA_700, 23.04, 0.0, false, 117.875, 41.16, 156.44, 98.95, 56.11],
	["Y", StudioTokens.Face.JAKARTA_800, 17.28, 0.0, false, 11.609375, 40.0, 50.48, 45.3, 49.87],
	["Type", StudioTokens.Face.JAKARTA_800, 58.88, -0.04, false, 131.765625, 40.13, 171.75, 106.26, 83.88],
	["Ajouter une console", StudioTokens.Face.JAKARTA_800, 58.88, -0.04, false, 527.9375, 40.34, 567.75, 299.34, 83.67],
	["Émulateur", StudioTokens.Face.JAKARTA_800, 58.88, -0.04, false, 271.25, 43.41, 312.42, 169.26, 82.0],
	["01 / 12", StudioTokens.Face.PLEX_600, 21.76, 0.08, false, 103.546875, 40.33, 140.34, 88.64, 54.3],
	["MICROSOFT", StudioTokens.Face.PLEX_600, 19.84, 0.14, false, 132.078125, 40.46, 168.46, 101.08, 52.23],
	["NINTENDO", StudioTokens.Face.PLEX_600, 17.28, 0.14, false, 102.234375, 40.57, 138.65, 89.82, 51.37],
	["Nintendo Entertainment System", StudioTokens.Face.JAKARTA_700, 30.08, 0.0, false, 467.578125, 41.58, 505.53, 268.81, 61.18],
	["Super Nintendo Entertainment System", StudioTokens.Face.JAKARTA_800, 30.08, 0.0, false, 565.0625, 40.62, 603.26, 318.3, 61.25],
	["07", StudioTokens.Face.PLEX_500, 17.92, 0.0, false, 21.5, 40.33, 59.97, 49.37, 50.49],
	["07", StudioTokens.Face.PLEX_600, 17.92, 0.0, false, 21.5, 40.16, 60.15, 49.42, 50.51],
	["entre", StudioTokens.Face.PLEX_600, 20.48, 0.04, false, 65.515625, 40.57, 103.28, 71.36, 54.74],
	["Fichiers acceptés : .iso .chd", StudioTokens.Face.PLEX_600, 18.56, 0.03, false, 338.875, 40.97, 376.58, 197.68, 53.3],
	["59 jeux trouvés", StudioTokens.Face.JAKARTA_800, 24.32, -0.01, false, 175.90625, 40.55, 214.58, 125.53, 57.08],
	["Sous-dossiers", StudioTokens.Face.JAKARTA_700, 26.24, 0.0, false, 186.53125, 40.63, 224.87, 133.05, 58.88],
	["START", StudioTokens.Face.PLEX_600, 16, 0.06, false, 52.8125, 40.32, 91.03, 65.22, 49.4],
	["Ajouter", StudioTokens.Face.JAKARTA_800, 26.88, 0.0, false, 98.375, 39.85, 137.57, 85.89, 59.66],
	["ARMSX2", StudioTokens.Face.JAKARTA_800, 33.28, -0.02, false, 136.921875, 39.94, 175.48, 107.24, 62.08],
	[".iso .chd .gz .mdf .bin", StudioTokens.Face.PLEX_600, 17.92, 0.06, false, 271.84375, 43.18, 309.08, 183.02, 52.63],
	["Crystal Knights", StudioTokens.Face.JAKARTA_800, 29.44, -0.01, false, 214.84375, 40.69, 253.55, 150.62, 61.59],
	["Moss Kingdom", StudioTokens.Face.JAKARTA_800, 53.76, -0.035, false, 365.5, 42.97, 404.55, 222.62, 79.12],
	["Modifier l’image", StudioTokens.Face.JAKARTA_700, 23.04, 0.0, false, 181.625, 41.16, 220.32, 129.35, 56.29],
	["Réglages", StudioTokens.Face.JAKARTA_800, 53.76, -0.04, false, 225.375, 42.97, 265.13, 148.22, 80.62],
	["Les jeux flottent", StudioTokens.Face.JAKARTA_700, 30.08, 0.0, false, 233.984375, 41.58, 272.37, 157.8, 61.56],
	["Les jeux se balancent doucement sur l’écran", StudioTokens.Face.JAKARTA_500, 21.76, 0.0, false, 454.9375, 41.34, 493.15, 263.65, 56.28],
	["Désactivé", StudioTokens.Face.JAKARTA_700, 26.88, 0.0, false, 131.34375, 41.45, 169.94, 103.36, 58.96],
]
## Where the browser puts the box: the line box of its `normal` line height, the baseline an ascent below.
const _AT := Vector2(40.0, 40.0)
## The browser's picture of one string: 1280 by this.
const _BAND := 160


func test_each_string_is_as_wide_as_in_the_browser_within_a_pixel() -> void:
	for row: Array in _BROWSER:
		var line := _line(row)
		var browser: float = row[5]
		assert_float(line.width).override_failure_message("%s: %.2f px, the browser %.2f" % [line.text, line.width, browser]) \
			.is_equal_approx(browser, 1.0)


# GdUnit reads the skip from these arguments.
@warning_ignore("unused_parameter")
func test_each_string_draws_its_ink_where_the_browser_does_within_half_a_pixel(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	# Every string at once, each on its own band as tall as the browser's picture.
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(1280, _BAND * _BROWSER.size())
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var page := _Page.new()
	page.size = Vector2(view.size)
	for k in _BROWSER.size():
		var row: Array = _BROWSER[k]
		var line := _line(row)
		var index: int = row[1]
		var face: Font = load(StudioText._FILES[index])
		var px: float = row[2]
		# The browser's box is its font's own height; the drawer's line box is 1.5 times the size.
		var content := (face.get_ascent(4096) + face.get_descent(4096)) * px / 4096.0
		page.lines.append(line)
		page.places.append(_AT + Vector2(0.0, k * _BAND - (line.height - content) / 2.0))
	view.add_child(page)
	add_child(view)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var picture := view.get_texture().get_image()
	for k in _BROWSER.size():
		var row: Array = _BROWSER[k]
		var ink := _ink(picture.get_region(Rect2i(0, k * _BAND, 1280, _BAND)))
		for i in 4:
			var browser: float = row[6 + i]
			assert_float(ink[i]).override_failure_message("%s: %s %.2f, the browser %.2f" % [row[0], ["left", "right",
				"centroid x", "centroid y"][i], ink[i], browser]).is_equal_approx(browser, 0.5)


func test_a_line_too_wide_ends_with_an_ellipsis_within_its_room_and_shows_whole_once_it_fits() -> void:
	var line := StudioText.of(StudioTokens.Role.PILL, "Super Nintendo Entertainment System")
	var whole := line.width
	line.fit(200.0)
	assert_float(line.width).is_less_equal(200.0)
	assert_float(line.width).is_greater(200.0 - StudioText.of(StudioTokens.Role.PILL, "W…").width)
	line.fit(whole)
	assert_float(line.width).is_equal(whole)


func test_the_line_box_is_one_and_a_half_times_the_size() -> void:
	assert_float(StudioText.of(StudioTokens.Role.HINT, "Réglages").height).is_equal_approx(23.04 * 1.5, 1e-4)


func test_the_baseline_sits_half_the_leading_below_the_line_top_plus_the_font_s_own_ascent() -> void:
	# Plus Jakarta Sans: ascent 1.038 em, descent 0.222 em (its hhea and typo metrics, which the browser reads).
	var line := StudioText.of(StudioTokens.Role.HINT, "Réglages")
	assert_float(line.baseline).is_equal_approx((23.04 * 1.5 - 23.04 * 1.26) / 2.0 + 23.04 * 1.038, 0.05)


func test_each_glyph_goes_at_its_exact_x_on_a_whole_pixel_baseline_from_the_raster_face() -> void:
	var line := StudioText.of(StudioTokens.Role.HINT, "Réglages")
	var at := Vector2(40.25, 10.3)
	var placed := line.placements(at)
	assert_int(placed.size()).is_equal(line._line.glyphs.size())
	var display: RID = (load("res://fonts/plus-jakarta-sans/PlusJakartaSans-Bold.ttf") as Font).get_rids()[0]
	for i in placed.size():
		assert_float(placed[i].at.x).is_equal_approx(at.x + line._line.x[i], 1e-3)
		assert_float(placed[i].at.y).is_equal(roundf(at.y + line.baseline))
		assert_bool(placed[i].font == display).is_true()
	# Cut, the ellipsis follows the last glyph kept.
	line.fit(60.0)
	placed = line.placements(at)
	var kept := line._shown
	assert_int(placed.size()).is_equal(kept + line._ellipsis.glyphs.size())
	assert_float(placed[kept].at.x).is_equal_approx(at.x + line._line.x[kept], 1e-3)


func test_an_accent_typed_apart_stays_with_its_letter_where_the_line_is_cut() -> void:
	# A "q" and a combining tilde, which no letter of the face composes: one cluster of two glyphs.
	var line := StudioText.of(StudioTokens.Role.HINT, "q\u0303q\u0303q\u0303q\u0303q\u0303q\u0303")
	assert_int(line._line.glyphs.size()).is_equal(12)
	var whole := line.width
	var room := 0.0
	while room < whole:
		line.fit(room)
		var kept := line._shown
		assert_bool(kept == 0 or kept == line._line.glyphs.size() or line._line.glyphs[kept].count > 0) \
			.override_failure_message("cut inside a cluster at %.1f px" % room).is_true()
		room += 0.5


func test_a_room_narrower_than_the_ellipsis_shows_the_ellipsis_alone() -> void:
	var line := StudioText.of(StudioTokens.Role.HINT, "Réglages")
	line.fit(2.0)
	assert_int(line._shown).is_equal(0)
	assert_float(line.width).is_equal(line._ellipsis.x[-1])
	assert_int(line.placements(Vector2.ZERO).size()).is_equal(line._ellipsis.glyphs.size())


func _line(row: Array) -> StudioText:
	var text: String = row[0]
	var face: StudioTokens.Face = row[1]
	var px: float = row[2]
	var tracking: float = row[3]
	var tabular: bool = row[4]
	return StudioText.new(text, face, px, tracking, tabular)


## The ink's left and right edges (a column's coverage crossing one half, between pixels) and its centroid.
func _ink(picture: Image) -> Array[float]:
	picture.convert(Image.FORMAT_L8)
	var width := picture.get_width()
	var bytes := picture.get_data()
	var columns := PackedFloat64Array()
	columns.resize(width)
	var total := 0.0
	var weighted := Vector2.ZERO
	for i in bytes.size():
		var value := bytes[i] / 255.0
		if value > 0.0:
			var x := i % width
			columns[x] = maxf(columns[x], value)
			total += value
			weighted += Vector2(x, floori(float(i) / width)) * value
	var left := 0
	while columns[left] < 0.5:
		left += 1
	var right := width - 1
	while columns[right] < 0.5:
		right -= 1
	var centroid := weighted / total
	return [left - _crossing(columns[left], columns[left - 1]), right + _crossing(columns[right], columns[right + 1]),
		centroid.x, centroid.y]


## How far past the inked pixel (coverage [param inked]) the half coverage lies toward its neighbour.
func _crossing(inked: float, neighbour: float) -> float:
	return 0.0 if inked == neighbour else (inked - 0.5) / (inked - neighbour)


## Black, and lines in white on it.
class _Page:
	extends Control

	var lines: Array[StudioText] = []
	var places: Array[Vector2] = []

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		for i in lines.size():
			lines[i].draw(self, places[i], Color.WHITE)
