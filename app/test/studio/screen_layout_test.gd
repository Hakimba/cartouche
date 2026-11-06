# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

## Screens of every family: as the stretch shows them (960 high when wider than 4:3, 1280 wide when narrower).
const _SCREENS: Array[Vector2] = [Vector2(1280, 1956), Vector2(1280, 1115), Vector2(1280, 960), Vector2(1536, 960),
	Vector2(1707, 960), Vector2(2133, 960), Vector2(2293, 960), Vector2(3413, 960)]
const _FRAME := CarouselLayout.FRAME
const _POINTS: Array[Vector3] = [Vector3(0, 0, 0), Vector3(0.8, -0.5, -0.4), Vector3(-1.4, 0.6, 1.2), Vector3(2.5, -1.1, -2.0)]


func test_on_a_4_3_screen_every_part_stands_where_it_is_drawn() -> void:
	var layout := ScreenLayout.of(_FRAME)
	for point: Vector2 in [Vector2.ZERO, Vector2(640, 480), Vector2(1100, 900)]:
		assert_vector(layout.on_stage(point)).is_equal(point)
		for side: ScreenLayout.Side in [ScreenLayout.Side.LEFT, ScreenLayout.Side.MIDDLE, ScreenLayout.Side.RIGHT]:
			assert_vector(layout.top(point, side)).is_equal(point)
			assert_vector(layout.bottom(point, side)).is_equal(point)


func test_on_every_screen_the_stage_is_whole_and_the_bands_keep_to_their_edges() -> void:
	for shown in _SCREENS:
		var layout := ScreenLayout.of(shown)
		var stage := Rect2(layout.on_stage(Vector2.ZERO), _FRAME)
		assert_bool(Rect2(Vector2.ZERO, shown).grow(0.01).encloses(stage)).override_failure_message(str(shown)).is_true()
		assert_float(layout.from_stage(layout.on_stage(Vector2(321, 654))).distance_to(Vector2(321, 654))).is_less(0.001)
		assert_float(layout.bottom(_FRAME, ScreenLayout.Side.RIGHT).distance_to(shown)).is_less(0.001)
		assert_vector(layout.top(Vector2.ZERO, ScreenLayout.Side.LEFT)).is_equal(Vector2.ZERO)
		assert_float(layout.top(_FRAME / 2.0).x).is_equal_approx(shown.x / 2.0, 0.001)


func test_each_screen_shape_falls_in_one_family_from_the_narrowest() -> void:
	var names: Array[String] = []
	for shown in _SCREENS:
		names.append(ScreenLayout.of(shown).format.name)
	assert_array(names).is_equal(["portrait", "square", "4:3", "16:10", "16:9", "20:9", "21:9", "32:9"] as Array[String])


func test_an_aimed_camera_draws_the_frame_on_the_stage_at_every_depth() -> void:
	var reference := _camera(_FRAME)
	for shown in _SCREENS:
		var layout := ScreenLayout.of(shown)
		var camera := _camera(shown)
		StageLens.aim(camera, 32.0, layout)
		for point in _POINTS:
			var wanted := layout.on_stage(reference.unproject_position(point))
			assert_float(camera.unproject_position(point).distance_to(wanted)).override_failure_message("%s %s" % [shown, point]).is_less(0.05)


func test_a_narrowed_lens_draws_its_part_of_the_picture_whole() -> void:
	var shown := Vector2(1707, 960)
	var camera := _camera(shown)
	StageLens.aim(camera, 32.0, ScreenLayout.of(shown))
	var part := Rect2(900, 300, 240, 180)
	var lens := _camera(part.size)
	StageLens.narrow(camera, lens, part)
	for point in _POINTS:
		var on_screen := camera.unproject_position(point)
		assert_float(lens.unproject_position(point).distance_to(on_screen - part.position)).is_less(0.05)


func _camera(shown: Vector2) -> Camera3D:
	var view: SubViewport = auto_free(SubViewport.new())
	view.size = Vector2i(shown)
	view.own_world_3d = true
	add_child(view)
	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0, 0.1, 3.7)
	view.add_child(camera)
	return camera
