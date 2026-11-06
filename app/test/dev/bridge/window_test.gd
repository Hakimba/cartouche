# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Commands := preload("res://dev/bridge/commands.gd")


func test_a_screen_shape_fits_the_room_whole_and_never_grows() -> void:
	var room := Vector2(3440.0, 1400.0)
	for wanted: Vector2 in [Vector2(1280, 960), Vector2(5120, 1440), Vector2(720, 1100), Vector2(1240, 1080), Vector2(4000, 4000)]:
		var size := Commands.fitted(wanted, room)
		assert_bool(size.x <= room.x and size.y <= room.y).override_failure_message(str(wanted)).is_true()
		assert_float(float(size.x) / size.y).is_equal_approx(wanted.x / wanted.y, 0.01)
		assert_bool(size.x <= wanted.x and size.y <= wanted.y).is_true()
	assert_that(Commands.fitted(Vector2(1280, 960), room)).is_equal(Vector2i(1280, 960))

