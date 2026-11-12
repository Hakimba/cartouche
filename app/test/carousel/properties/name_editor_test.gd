# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const NAME_EDITOR := preload("res://carousel/properties/name_editor.tscn")
const Fixtures := preload("res://test/screens/fixtures.gd")
## The limit and the names the core keeps, in the file its own tests read.
const VECTORS := "res://test/vectors/display_name.json"


func _editor(current: String) -> NameEditor:
	var editor: NameEditor = auto_free(NAME_EDITOR.instantiate())
	add_child(editor)
	editor.open(current, "Own title")
	return editor


func test_the_caret_starts_before_the_name_moves_within_it_and_types_and_erases_where_it_stands() -> void:
	var editor := _editor("Gran Turismo")
	assert_str(editor._field.text).is_equal("|Gran Turismo")
	editor.move_caret(-1)
	editor.erase()
	assert_str(editor.typed()).is_equal("Gran Turismo")
	editor.move_caret(4)
	editor._type("d")
	assert_str(editor.typed()).is_equal("Grand Turismo")
	editor.move_caret(1)
	editor.erase()
	assert_str(editor.typed()).is_equal("GrandTurismo")
	editor.move_caret(100)
	editor._type("!")
	assert_str(editor.typed()).is_equal("GrandTurismo!")
	assert_str(editor._field.text).ends_with("!|")
	# No more than the longest name goes in.
	var longest: int = _vectors()["longest"]
	for key in longest + 5:
		editor._type("x")
	assert_int(editor.typed().length()).is_equal(longest)


func test_a_capital_comes_first_and_after_a_space_wherever_the_caret_is() -> void:
	var editor := _editor("ab cd")
	assert_bool(editor._keyboard.capital).is_true()
	editor.move_caret(1)
	assert_bool(editor._keyboard.capital).is_false()
	editor.move_caret(2)
	assert_bool(editor._keyboard.capital).is_true()


func test_a_long_name_keeps_its_caret_in_the_field_wherever_it_moves() -> void:
	var editor := _editor("A very long game title that cannot fit in the field however wide it is drawn")
	await await_idle_frame()
	var font := editor._field.get_theme_font(&"font")
	var font_size := editor._field.get_theme_font_size(&"font_size")
	for by: int in [0, 20, 20, 30, -60, 100]:
		editor.move_caret(by)
		var text := editor._field.text
		var caret_end := text.find("|") + 1
		assert_int(caret_end).is_greater(0)
		assert_float(font.get_string_size(text.left(caret_end), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x) \
			.is_less_equal(editor._field.size.x)


func _vectors() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(VECTORS))


func test_the_longest_name_and_the_names_the_fake_plugin_keeps_are_the_core_s() -> void:
	var vectors := _vectors()
	var longest: int = vectors["longest"]
	assert_int(NameEditor._LONGEST).is_equal(longest)
	assert_array(vectors["cases"]).is_not_empty()
	for each: Dictionary in vectors["cases"]:
		var typed: String = each["typed"]
		var kept: String = each["kept"]
		assert_str(Fixtures.NewDevice._display_name(typed)).override_failure_message(str(each)).is_equal(kept)
