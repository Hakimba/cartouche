# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_a_logo_shows_in_every_slot_and_nothing_where_there_is_none() -> void:
	var logo: LogoView = auto_free(LogoView.new())
	for slot: LogoView.Slot in LogoView.Slot.values():
		assert_bool(logo.show_logo(slot, "ps2_slim")).is_true()
	assert_bool(logo.show_logo(LogoView.Slot.RAIL_TILE, "no_such_logo")).is_false()
	assert_vector(logo.texture.get_size()).is_equal(Vector2.ZERO)


func test_logos_no_view_shows_are_let_go_and_the_one_shown_stays() -> void:
	var logo: LogoView = auto_free(LogoView.new())
	logo.show_logo(LogoView.Slot.RAIL_TILE, "ps2_slim")
	var shown: WeakRef = weakref(logo.texture)
	var passed_by := LogoView.new()
	passed_by.show_logo(LogoView.Slot.RAIL_TILE, "dreamcast")
	var gone: WeakRef = weakref(passed_by.texture)
	passed_by.free()
	LogoView.drop_unseen()
	assert_object(gone.get_ref()).is_null()
	assert_object(shown.get_ref()).is_same(logo.texture)
