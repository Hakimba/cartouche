# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The backdrop shown: its palettes as the tokens give them, and the theme it changes and gives back.


func after_test() -> void:
	Backdrop.show(&"light", true)


func test_every_value_of_every_scheme_is_a_field_of_its_palette() -> void:
	for scheme: int in StudioTokens.Scheme.values():
		var palette := Palette.of(scheme as StudioTokens.Scheme)
		var values := StudioTokens.SCHEMES[scheme]
		for key: StringName in values:
			assert_bool(key in palette).override_failure_message("%s has no %s" % [scheme, key]).is_true()
			assert_bool(palette.get(key) == values[key]).override_failure_message("%s.%s" % [scheme, key]).is_true()


func test_the_backgrounds_offered_are_those_the_plugin_stores_each_drawing_its_scheme_and_device_following_the_system() -> void:
	var stored: PackedStringArray = DesktopPlugin.settings_of(DesktopPlugin.demo("settings"))["backdrops"]
	var offered := PackedStringArray(Backdrop.NAMES.keys())
	assert_array(offered).is_equal(stored)
	for key in offered:
		if key != "device":
			assert_str(StudioTokens.Scheme.find_key(Backdrop.scheme_of(key))).is_equal(key.to_upper())
	var drawn := PackedStringArray(StudioTokens.Scheme.keys()).duplicate()
	drawn.append("DEVICE")
	assert_array(drawn).is_equal(PackedStringArray(Array(offered).map(func(key: String) -> String: return key.to_upper())))


func test_a_backdrop_shown_tells_every_control_once_and_light_again_gives_the_theme_back_as_made() -> void:
	var theme := ThemeDB.get_project_theme()
	Backdrop.show(&"light", false)
	var made := theme.get_color(&"font_color", &"Label")
	var told := Probe.new()
	add_child(told)
	await await_idle_frame()
	var at_first := told.told
	Backdrop.show(&"dark", false)
	assert_int(told.told - at_first).is_equal(1)
	assert_that(theme.get_color(&"font_color", &"Label")).is_equal(Palette.of(StudioTokens.Scheme.DARK).ink)
	assert_that(RenderingServer.get_default_clear_color()).is_equal(Color.BLACK)
	Backdrop.show(&"dark", false)
	assert_int(told.told - at_first).is_equal(1)
	Backdrop.show(&"light", false)
	assert_that(theme.get_color(&"font_color", &"Label")).is_equal(made)
	told.free()


class Probe extends Control:
	var told := 0

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			told += 1
