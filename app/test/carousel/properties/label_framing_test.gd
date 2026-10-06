# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The framing shown must be the square the plugin cuts: the same cases as LabelFramingTest.

const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func _framing(zoom: float, centre: Vector2) -> LabelFraming:
	var framing := LabelFraming.new()
	framing.zoom = zoom
	framing.centre = centre
	return framing


func test_a_picture_first_framed_shows_the_largest_square_in_its_middle() -> void:
	assert_object(LabelFraming.new().square(Vector2i(1600, 1200))).is_equal(Rect2i(200, 0, 1200, 1200))
	assert_object(LabelFraming.new().square(Vector2i(900, 1600))).is_equal(Rect2i(0, 350, 900, 900))


func test_a_closer_framing_shows_a_smaller_square_round_the_centre_asked() -> void:
	assert_object(_framing(2.0, Vector2(0.25, 0.5)).square(Vector2i(1600, 1200))).is_equal(Rect2i(100, 300, 600, 600))


func test_a_centre_too_close_to_an_edge_is_moved_in_as_little_as_the_square_needs() -> void:
	assert_object(_framing(2.0, Vector2(1.0, 0.0)).square(Vector2i(1600, 1200))).is_equal(Rect2i(1000, 0, 600, 600))


func test_moving_and_zooming_keep_the_square_inside_the_picture_and_the_zoom_in_range() -> void:
	var picture := Vector2i(1600, 1200)
	var framing := LabelFraming.new()
	framing.zoom_by(100.0, picture)
	assert_float(framing.zoom).is_equal(LabelFraming.MAX_ZOOM)
	framing.move(Vector2(-50.0, 50.0), picture)
	var square := framing.square(picture)
	assert_bool(Rect2i(Vector2i.ZERO, picture).encloses(square)).is_true()
	assert_int(square.position.x).is_equal(0)
	framing.zoom_by(0.001, picture)
	assert_float(framing.zoom).is_equal(1.0)
	assert_object(framing.square(picture)).is_equal(Rect2i(0, 0, 1200, 1200))


func test_whatever_the_moves_and_zooms_on_any_picture_the_square_stays_whole_inside_it() -> void:
	var random := CarouselFixtures.cases(29)
	for picture: Vector2i in [Vector2i(1, 1), Vector2i(1, 900), Vector2i(900, 1), Vector2i(1600, 1200), Vector2i(31, 4000)]:
		var framing := LabelFraming.new()
		for step in 200:
			if random.randi() % 2:
				framing.move(Vector2(random.randf_range(-3.0, 3.0), random.randf_range(-3.0, 3.0)), picture)
			else:
				framing.zoom_by(random.randf_range(0.1, 10.0), picture)
			var square := framing.square(picture)
			assert_bool(square.size.x >= 1 and square.size.x == square.size.y).is_true()
			assert_bool(Rect2i(Vector2i.ZERO, picture).encloses(square)).is_true()
			assert_float(framing.zoom).is_between(1.0, LabelFraming.MAX_ZOOM)
