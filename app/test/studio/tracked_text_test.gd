# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const _TEXT := "Ajouter une console"


func test_each_role_is_its_face_tracked_by_its_em_to_the_fraction_of_a_pixel() -> void:
	for role: StringName in TrackedText.ROLES:
		var told: Array = TrackedText.ROLES[role]
		var face: StudioTokens.Face = told[0]
		var em: float = told[1]
		var plain := StudioText.new(_TEXT, face, 40.0)
		assert_float(TrackedText.line(role, _TEXT, 40.0).width - plain.width) \
			.override_failure_message(role).is_equal_approx(em * 40.0 * _TEXT.length(), 0.001)


func test_a_wrapped_role_breaks_at_spaces_into_lines_that_fit_and_keep_every_word() -> void:
	var room := 300.0
	var lines := TrackedText.lines(&"PanelTitle", "Remove the platform Crystal Knights and its games", 40.0, room)
	assert_int(lines.size()).is_greater(1)
	var words := PackedStringArray()
	for line in lines:
		assert_float(line.width).is_less_equal(room)
		words.append(line.text)
	assert_str(" ".join(words)).is_equal("Remove the platform Crystal Knights and its games")


func test_a_word_longer_than_the_room_stands_alone_on_its_line() -> void:
	var lines := TrackedText.lines(&"PanelTitle", "a Supercalifragilistic b", 40.0, 100.0)
	assert_array(lines.map(func(line: StudioText) -> String: return line.text)) \
		.is_equal(["a", "Supercalifragilistic", "b"])


func test_the_label_keeps_the_size_the_engine_gives_its_text() -> void:
	var plain := Label.new()
	var studio := StudioLabel.new()
	for label: Label in [plain, studio]:
		label.theme_type_variation = &"ScreenTitle"
		label.text = _TEXT
		add_child(label)
	await get_tree().process_frame
	assert_vector(studio.get_minimum_size()).is_equal(plain.get_minimum_size())
	plain.free()
	studio.free()
