# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_the_clock_shows_the_time() -> void:
	var carousel := await Fixtures.shown_carousel(self)
	var clock: StudioPill = carousel.get_node("%Clock")
	assert_bool(RegEx.create_from_string("^\\d\\d:\\d\\d$").search(clock.text) != null).is_true()


func test_a_logo_shows_in_every_slot_and_nothing_where_there_is_none() -> void:
	var logo: LogoView = auto_free(LogoView.new())
	for slot: LogoView.Slot in LogoView.Slot.values():
		assert_bool(logo.show_logo(slot, "ps2_slim")).is_true()
	assert_bool(logo.show_logo(LogoView.Slot.RAIL_TILE, "no_such_logo")).is_false()
	assert_vector(logo.texture.get_size()).is_equal(Vector2.ZERO)


func test_every_console_has_its_logo_in_every_slot() -> void:
	assert_int(ConsoleManifest.found().size()).is_greater_equal(12)
	for manifest in ConsoleManifest.found():
		var console := ConsoleManifest.folder_of(manifest)
		for folder in LogoView.FOLDERS:
			var path := "res://studio/logos/%s/%s.png" % [folder, console]
			assert_bool(ResourceLoader.exists(path)).override_failure_message(path).is_true()
