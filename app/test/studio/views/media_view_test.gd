# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_each_game_stands_the_shorter_way_round_from_the_centre_and_far_ones_are_not_drawn() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 29
	for case in 60:
		var n := random.randi_range(1, 12)
		var j := random.randi_range(0, n - 1)
		var at := random.randf_range(-30.0, 30.0)
		var d := MediaView.offset(j, at, n)
		assert_float(d).is_between(-n / 2.0, n / 2.0)
		# The same place as j - at, a whole number of turns of the row apart.
		var turns := (j - at - d) / n
		assert_float(turns).is_equal_approx(roundf(turns), 1e-4)
	assert_float(MediaView.offset(3, 3.0, 5)).is_equal(0.0)
	assert_float(MediaView.offset(0, 4.0, 5)).is_equal_approx(1.0, 1e-6)
	assert_bool(MediaView.drawn_at(2.19)).is_true()
	assert_bool(MediaView.drawn_at(-2.2)).is_false()


func test_a_view_without_a_medium_or_placed_again_where_it_stands_is_not_drawn_again() -> void:
	var empty: MediaView = auto_free(MediaView.new())
	empty.camera = _camera()
	add_child(empty)
	empty.place(Transform3D.IDENTITY, 0.0)
	assert_int(empty.view().render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)
	var view := _view(empty.camera)
	view.place(Transform3D.IDENTITY, 0.0)
	view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.place(Transform3D.IDENTITY, 0.0)
	assert_int(view.view().render_target_update_mode).is_equal(SubViewport.UPDATE_DISABLED)


func _camera() -> Camera3D:
	var camera: Camera3D = auto_free(Camera3D.new())
	camera.fov = 32.0
	camera.position = Vector3(0.0, 0.1, 3.7)
	add_child(camera)
	return camera


## A PS2 disc about a unit wide, as the games row fits it.
func _disc() -> Node3D:
	var fitted := Node3D.new()
	fitted.scale = Vector3.ONE * 10.0
	fitted.add_child((load("res://carousel/media/ps2_dvd/ps2_dvd.tscn") as PackedScene).instantiate())
	return fitted


## A view through [param camera] showing a PS2 disc under its games light.
func _view(camera: Camera3D) -> MediaView:
	var view: MediaView = auto_free(MediaView.new())
	view.camera = camera
	add_child(view)
	view.show_medium(_disc(), StudioLights.rig_of("ps2_dvd", &"games"), StudioLights.rig_of("ps2_dvd", &"games", true))
	return view


func test_a_view_moving_on_a_side_keeps_its_size_and_one_off_the_screen_is_not_drawn() -> void:
	var view := _view(_camera())
	view.place(Transform3D(Basis.IDENTITY, Vector3(0.9, 0.0, 0.0)), 1.0)
	var size := view.view().size
	view.place(Transform3D(Basis.IDENTITY, Vector3(0.95, 0.0, 0.0)), 1.0)
	assert_vector(Vector2(view.view().size)).is_equal(Vector2(size))
	view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.place(Transform3D(Basis.IDENTITY, Vector3(9.0, 0.0, 0.0)), 1.0)
	assert_int(view.view().render_target_update_mode).override_failure_message("off the screen, not drawn") \
		.is_equal(SubViewport.UPDATE_DISABLED)
