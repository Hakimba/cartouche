# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The framing shown must be the rectangle the plugin cuts: the cases are the file the core's tests read.

const CarouselFixtures := preload("res://test/carousel/fixtures.gd")
const VECTORS := "res://test/vectors/label_framing.json"


func _framing(zoom: float, centre: Vector2, proportion := 1.0) -> LabelFraming:
	var framing := LabelFraming.new(proportion)
	framing.zoom = zoom
	framing.centre = centre
	return framing


func test_the_rectangle_framed_is_the_one_the_plugin_cuts_for_each_picture_proportion_zoom_and_centre() -> void:
	var vectors: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VECTORS))
	assert_array(vectors["cases"]).is_not_empty()
	for each: Dictionary in vectors["cases"]:
		var picture_sides: Array = each["picture"]
		var centre_at: Array = each["centre"]
		var picture := _pair(picture_sides)
		var centre := _pair(centre_at)
		var rect: Array = each["framed"]
		var zoom: float = each["zoom"]
		var proportion: float = each["proportion"]
		var left: int = rect[0]
		var top: int = rect[1]
		var width: int = rect[2]
		var height: int = rect[3]
		assert_object(_framing(zoom, centre, proportion).framed(Vector2i(picture))).override_failure_message(str(each)) \
			.is_equal(Rect2i(left, top, width, height))


func _pair(values: Array) -> Vector2:
	var first: float = values[0]
	var second: float = values[1]
	return Vector2(first, second)


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
