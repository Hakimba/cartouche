# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_a_line_comes_back_where_the_layout_puts_it_after_the_screen_changed_shape() -> void:
	var screen: Control = auto_free(Control.new())
	add_child(screen)
	screen.size = CarouselLayout.FRAME
	var line := Control.new()
	screen.add_child(line)
	line.set_anchors_preset(Control.PRESET_CENTER)
	line.position = Vector2(100.0, 200.0)
	var rests := Rests.new([line])
	for shape: Vector2 in [Vector2(1920.0, 960.0), Vector2(1280.0, 1480.0), CarouselLayout.FRAME]:
		screen.size = shape
		line.position = Vector2(-500.0, 0.0)
		rests.restore()
		var wanted := ScreenLayout.of(shape).on_stage(Vector2(100.0, 200.0))
		assert_vector(line.position).is_equal_approx(wanted, Vector2(0.01, 0.01))
		assert_vector(rests.of(line)).is_equal_approx(wanted, Vector2(0.01, 0.01))
