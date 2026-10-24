# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const ScreenFixtures := preload("res://test/screens/fixtures.gd")
const ProjectFiles := preload("res://test/studio/project_files.gd")


func test_INV_E12_09_every_hint_row_of_every_screen_stands_at_the_one_place_of_the_design() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var rows: Array[Node] = carousel.find_children("*", "HintRow", true, false)
	var owners: Array[String] = []
	for row: HintRow in rows:
		owners.append(str(carousel.get_path_to(row)))
		assert_vector(row.get_global_rect().position).override_failure_message(owners[-1]) \
			.is_equal_approx(StudioTokens.HINTS.position, Vector2.ONE * 0.01)
		assert_float(row.size.y).is_equal(StudioTokens.HINTS.size.y)
	assert_int(rows.size()).override_failure_message(", ".join(owners)).is_greater_equal(13)


## The scenes' hints, read from their files. The hints made in code are the search's, added to its row
## (`GameSearch._hints`, typed `HintRow`), so none can stand outside one.
func test_INV_E12_09_every_button_hint_of_the_app_stands_in_a_hint_row() -> void:
	var hint_script := preload("res://screens/button_hint.gd")
	var row_scene := preload("res://studio/hint_row.tscn")
	var found := 0
	for path in ProjectFiles.under("res://", ["tscn"], ["addons", ".godot", "android", "test", "dev"]):
		var state := (load(path) as PackedScene).get_state()
		var by_path: Dictionary[NodePath, int] = {}
		for node in state.get_node_count():
			by_path[state.get_node_path(node)] = node
		for node in state.get_node_count():
			if _property(state, node, &"script") != hint_script:
				continue
			found += 1
			var parent := by_path[state.get_node_path(node, true)]
			assert_object(state.get_node_instance(parent)).override_failure_message("%s %s" % [path, state.get_node_path(node)]) \
				.is_equal(row_scene)
	assert_int(found).is_greater(20)


func test_INV_E12_09_the_row_lays_its_hints_at_their_exact_places_with_a_line_between_two_and_shrinks_with_them() -> void:
	var row: HintRow = auto_free((load("res://studio/hint_row.tscn") as PackedScene).instantiate())
	var hints: Array[ButtonHint] = []
	for told: Array in [[&"y", "Settings"], [&"b", "Clear the filter"], [&"↓", "Arrange"]]:
		var hint := ButtonHint.new()
		hint.button = told[0]
		hint.text = told[1]
		row.add_child(hint)
		hints.append(hint)
	add_child(row)
	await await_idle_frame()
	var step := 2.0 * StudioTokens.HINTS_GAP + StudioTokens.HINT_SEPARATOR.x
	var x := StudioTokens.HINTS_PADDING_LEFT
	for hint in hints:
		assert_float(hint.position.x).is_equal_approx(x, 1e-4)
		x += hint.size.x + step
	assert_float(row.size.x).is_equal_approx(x - step + StudioTokens.HINTS_PADDING_RIGHT, 1e-4)
	var lines := row.separators()
	assert_int(lines.size()).is_equal(2)
	assert_float(lines[0].position.x).is_equal_approx(hints[0].position.x + hints[0].size.x + StudioTokens.HINTS_GAP, 1e-4)
	# A filter cleared: the middle hint goes, the next one takes its place, the row stays where it is.
	var placed := row.global_position
	# An ancestor that moves leaves the row where it stands.
	var mover: Control = auto_free(Control.new())
	add_child(mover)
	row.reparent(mover, true)
	mover.position = Vector2(30, -12)
	await await_idle_frame()
	assert_vector(row.global_position).is_equal(placed)
	hints[1].hide()
	await await_idle_frame()
	assert_float(hints[2].position.x).is_equal_approx(hints[0].position.x + hints[0].size.x + step, 1e-4)
	assert_vector(row.global_position).is_equal(placed)
	lines = row.separators()
	assert_int(lines.size()).is_equal(1)
	assert_float(lines[0].position.x).is_equal_approx(hints[0].position.x + hints[0].size.x + StudioTokens.HINTS_GAP, 1e-4)
	assert_float(row.size.x).is_equal_approx(hints[2].position.x + hints[2].size.x + StudioTokens.HINTS_PADDING_RIGHT, 1e-4)


func test_INV_E12_09_a_screen_opened_keeps_its_hints_at_the_one_place() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 2, "gc": 1})
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await ScreenFixtures.joypad(self, JOY_BUTTON_X)
	await ScreenFixtures.settled_consoles(self, carousel)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLE_PROPERTIES)
	var shown := carousel._console_properties.find_children("*", "HintRow", true, false).filter(
		func(row: HintRow) -> bool: return row.is_visible_in_tree())
	assert_array(shown).is_not_empty()
	for row: HintRow in shown:
		assert_vector(row.get_global_rect().position).is_equal_approx(StudioTokens.HINTS.position, Vector2.ONE * 0.01)


func test_a_hint_is_its_key_the_design_s_gap_and_its_label() -> void:
	var hint: ButtonHint = auto_free(ButtonHint.new())
	hint.button = &"y"
	hint.text = "Settings"
	assert_float(hint.get_combined_minimum_size().x).is_equal_approx(StudioTokens.KEY_SIZE + StudioTokens.HINT_GAP
		+ StudioText.of(StudioTokens.Role.HINT, "Settings").width, 1e-4)


func _property(state: SceneState, node: int, named: StringName) -> Variant:
	for i in state.get_node_property_count(node):
		if state.get_node_property_name(node, i) == named:
			return state.get_node_property_value(node, i)
	return null
