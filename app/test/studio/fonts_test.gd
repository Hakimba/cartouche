# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_a_line_too_wide_ends_with_an_ellipsis_within_its_room_and_shows_whole_once_it_fits() -> void:
	var line := StudioText.of(StudioTokens.Role.PILL, "Super Nintendo Entertainment System")
	var whole := line.width
	line.fit(200.0)
	assert_float(line.width).is_less_equal(200.0)
	assert_float(line.width).is_greater(200.0 - StudioText.of(StudioTokens.Role.PILL, "W…").width)
	line.fit(whole)
	assert_float(line.width).is_equal(whole)


func test_a_room_narrower_than_the_ellipsis_shows_the_ellipsis_alone() -> void:
	var line := StudioText.of(StudioTokens.Role.HINT, "Réglages")
	line.fit(2.0)
	assert_int(line._shown).is_equal(0)
	assert_float(line.width).is_equal(line._ellipsis.x[-1])
	assert_int(line.placements(Vector2.ZERO).size()).is_equal(line._ellipsis.glyphs.size())
