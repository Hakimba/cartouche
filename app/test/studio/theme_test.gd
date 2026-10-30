# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_every_focus_is_the_one_focus_card() -> void:
	var theme := ThemeDB.get_project_theme()
	var focus: SatinStyle = preload("res://studio/focus.tres")
	assert_int(focus.look).is_equal(StudioTokens.Look.FOCUS)
	for type: StringName in [&"Button", &"Field", &"NameButton", &"Card"]:
		assert_object(theme.get_stylebox(&"focus", type)).override_failure_message(type).is_same(focus)
	var button: Button = auto_free(Button.new())
	SatinStyle.apply_to(button, Color.CORAL)
	var native := button.get_theme_stylebox(&"focus") as SatinStyle
	assert_int(native.look).is_equal(StudioTokens.Look.FOCUS)
	assert_bool(native.gel == Color.CORAL).is_true()
