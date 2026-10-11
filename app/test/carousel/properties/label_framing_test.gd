# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The framing shown must be the rectangle the plugin cuts: the same cases as LabelFramingTest.

const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func _framing(zoom: float, centre: Vector2, proportion := 1.0) -> LabelFraming:
	var framing := LabelFraming.new(proportion)
	framing.zoom = zoom
	framing.centre = centre
	return framing


func test_a_picture_first_framed_shows_the_largest_square_in_its_middle() -> void:
	assert_object(LabelFraming.new().framed(Vector2i(1600, 1200))).is_equal(Rect2i(200, 0, 1200, 1200))
	assert_object(LabelFraming.new().framed(Vector2i(900, 1600))).is_equal(Rect2i(0, 350, 900, 900))


func test_a_picture_first_framed_on_a_cartridge_shows_the_largest_rectangle_of_its_label_s_proportions() -> void:
	assert_object(LabelFraming.new(2.0).framed(Vector2i(1600, 1200))).is_equal(Rect2i(0, 200, 1600, 800))
	assert_object(LabelFraming.new(0.5).framed(Vector2i(1600, 1200))).is_equal(Rect2i(500, 0, 600, 1200))


func test_a_closer_framing_shows_a_smaller_rectangle_round_the_centre_asked() -> void:
	assert_object(_framing(2.0, Vector2(0.25, 0.5)).framed(Vector2i(1600, 1200))).is_equal(Rect2i(100, 300, 600, 600))
	assert_object(_framing(2.0, Vector2(0.25, 0.5), 2.0).framed(Vector2i(1600, 1200))).is_equal(Rect2i(0, 400, 800, 400))


func test_a_centre_too_close_to_an_edge_is_moved_in_as_little_as_the_rectangle_needs() -> void:
	assert_object(_framing(2.0, Vector2(1.0, 0.0)).framed(Vector2i(1600, 1200))).is_equal(Rect2i(1000, 0, 600, 600))


func test_moving_and_zooming_keep_the_rectangle_inside_the_picture_and_the_zoom_in_range() -> void:
	var picture := Vector2i(1600, 1200)
	var framing := LabelFraming.new()
	framing.zoom_by(100.0, picture)
	assert_float(framing.zoom).is_equal(LabelFraming.MAX_ZOOM)
	framing.move(Vector2(-50.0, 50.0), picture)
	var shown := framing.framed(picture)
	assert_bool(Rect2i(Vector2i.ZERO, picture).encloses(shown)).is_true()
	assert_int(shown.position.x).is_equal(0)
	framing.zoom_by(0.001, picture)
	assert_float(framing.zoom).is_equal(1.0)
	assert_object(framing.framed(picture)).is_equal(Rect2i(0, 0, 1200, 1200))


func test_whatever_the_moves_and_zooms_on_any_picture_the_rectangle_stays_whole_inside_it_of_the_label_s_shape() -> void:
	var random := CarouselFixtures.cases(29)
	for picture: Vector2i in [Vector2i(1, 1), Vector2i(1, 900), Vector2i(900, 1), Vector2i(1600, 1200), Vector2i(31, 4000)]:
		var shapes: Array[float] = [1.0, 0.62, 2.89]
		var framing := LabelFraming.new(shapes[random.randi() % shapes.size()])
		for step in 200:
			if random.randi() % 2:
				framing.move(Vector2(random.randf_range(-3.0, 3.0), random.randf_range(-3.0, 3.0)), picture)
			else:
				framing.zoom_by(random.randf_range(0.1, 10.0), picture)
			var shown := framing.framed(picture)
			assert_bool(shown.size.x >= 1 and shown.size.y >= 1).is_true()
			assert_bool(Rect2i(Vector2i.ZERO, picture).encloses(shown)).is_true()
			# Each side cut to whole pixels on its own: of the label's shape within a pixel of either.
			if mini(shown.size.x, shown.size.y) >= 8:
				assert_float(absf(shown.size.x - shown.size.y * framing.proportion)).is_less_equal(1.0 + framing.proportion)
			assert_float(framing.zoom).is_between(1.0, LabelFraming.MAX_ZOOM)
