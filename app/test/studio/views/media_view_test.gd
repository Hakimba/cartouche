# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite


func test_softness_is_none_at_the_centre_whole_from_one_place_on_and_rises_between() -> void:
	assert_float(MediaView.softness(0.0)).is_equal(0.0)
	var random := RandomNumberGenerator.new()
	random.seed = 23
	var between := 0
	for case in 500:
		var d := random.randf_range(-4.0, 4.0)
		var e := random.randf_range(-4.0, 4.0)
		var s := MediaView.softness(d)
		assert_float(s).is_between(0.0, 1.0)
		assert_float(s).is_equal(MediaView.softness(-d))
		if absf(d) >= 1.0:
			assert_float(s).is_equal(1.0)
		else:
			between += 1
			assert_float(s).is_equal(absf(d))
		if absf(d) <= absf(e):
			assert_float(s).is_less_equal(MediaView.softness(e))
	assert_int(between).is_greater(50)


func test_each_game_stands_the_shorter_way_round_from_the_centre_and_far_ones_are_not_drawn() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 29
	for case in 500:
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


func test_the_look_goes_from_the_chosen_medium_s_to_a_neighbour_s_as_the_design_has_them() -> void:
	var chosen := MediaView.look(0.0)
	var values := Vector4(chosen.shadow_y, chosen.shadow_blur, chosen.shadow_alpha, chosen.saturation)
	assert_vector(values).is_equal_approx(Vector4(12.0, 22.0, 0.2, 1.0), Vector4.ONE * 1e-6)
	assert_float(chosen.blur).is_equal(0.0)
	var side := MediaView.look(1.0)
	assert_float(side.blur).is_equal_approx(1.1, 1e-6)
	assert_float(side.shadow_y).is_equal(8.0)
	assert_float(side.shadow_blur).is_equal(14.0)
	assert_float(side.shadow_alpha).is_equal_approx(0.28, 1e-6)
	assert_float(side.saturation).is_equal_approx(0.92, 1e-6)
	var half := MediaView.look(0.5)
	assert_float(half.shadow_blur).is_equal(18.0)
	assert_float(half.saturation).is_equal_approx(0.96, 1e-6)
	# Three standard deviations (a CSS shadow's blur is two) of the widest shadow, past its offset below.
	assert_vector(MediaView.reach()).is_equal_approx(Vector4(33.0, 21.0, 33.0, 45.0), Vector4.ONE * 1e-5)


func test_a_medium_is_lit_by_the_chosen_and_the_sides_sources_by_its_share_of_each_place() -> void:
	var rig := StudioLights.rig_of("gba_cart", &"games")
	var random := RandomNumberGenerator.new()
	random.seed = 31
	for case in 100:
		var s := random.randf()
		var shared := StudioLights.shared(rig, s)
		assert_float(shared.room).is_equal(rig.room)
		assert_int(shared.sources.size()).is_equal(rig.sources.size())
		for i in rig.sources.size():
			var share := 1.0 - s if rig.sources[i].on == StudioLights.CHOSEN else s
			assert_float(shared.sources[i].energy).is_equal_approx(rig.sources[i].energy * share, 1e-6)
			assert_vector(shared.sources[i].target).is_equal(rig.sources[i].target)
	var ons := rig.sources.map(func(source: StudioLights.Source) -> StringName: return source.on)
	assert_array(ons).contains([StudioLights.CHOSEN, StudioLights.SIDES])
	# At rest exactly one set lights each medium.
	for source in StudioLights.shared(rig, 0.0).sources:
		assert_float(source.energy).is_equal(0.0 if source.on == StudioLights.SIDES else source.energy)
		assert_bool(source.on == StudioLights.SIDES and source.energy > 0.0).is_false()
	for source in StudioLights.shared(rig, 1.0).sources:
		assert_bool(source.on == StudioLights.CHOSEN and source.energy > 0.0).is_false()


func test_a_game_without_a_picture_crossfades_to_its_own_light_keeping_every_source() -> void:
	var lit := StudioLights.rig_of("ps2_dvd", &"games")
	var blank := StudioLights.rig_of("ps2_dvd", &"games", true)
	assert_float(lit.room).is_not_equal(blank.room)
	for weight: float in [0.0, 0.3, 1.0]:
		var mixed := StudioLights.mixed(lit, blank, weight)
		assert_int(mixed.sources.size()).is_equal(lit.sources.size() + blank.sources.size())
		assert_float(mixed.room).is_equal_approx(lerpf(lit.room, blank.room, weight), 1e-6)
		for i in lit.sources.size():
			assert_float(mixed.sources[i].energy).is_equal_approx(lit.sources[i].energy * (1.0 - weight), 1e-6)
		for i in blank.sources.size():
			assert_float(mixed.sources[lit.sources.size() + i].energy).is_equal_approx(blank.sources[i].energy * weight, 1e-6)


func test_the_view_covers_the_medium_s_part_of_the_screen_and_draws_it_where_the_app_s_camera_does() -> void:
	var view := _view(_camera())
	var model := view.holder().get_child(0) as Node3D
	var random := RandomNumberGenerator.new()
	random.seed = 37
	for case in 20:
		var at := Transform3D(Basis.from_euler(Vector3(random.randf_range(-0.5, 0.5), random.randf_range(-0.5, 0.5), 0.0))
			.scaled(Vector3.ONE * random.randf_range(0.4, 1.0)), Vector3(random.randf_range(-1.0, 1.0), random.randf_range(-0.4, 0.4), 0.0))
		view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
		view.place(at, random.randf())
		assert_int(view.view().render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)
		var inner: Camera3D = view.view().get_camera_3d()
		var shown := view.get_global_rect()
		for corner in 8:
			var point := at * Plinth.bounds(model, model.get_parent_node_3d()).get_endpoint(corner)
			var on_screen := view.camera.unproject_position(point)
			assert_bool(shown.grow(-1.0).has_point(on_screen)).is_true()
			var in_view := inner.unproject_position(point) * view.size / Vector2(view.view().size)
			assert_vector(shown.position + in_view).is_equal_approx(on_screen, Vector2.ONE * 0.05)
	assert_int(view.view().size.x % 32).is_equal(0)


func test_the_view_is_as_large_as_its_medium_grows_while_it_moves_and_shrinks_once_it_settles() -> void:
	var view := _view(_camera())
	var centre := Transform3D(Basis.from_scale(Vector3.ONE * 0.78), Vector3(0.0, 0.15, 0.0))
	var side := Transform3D(Basis.from_scale(Vector3.ONE * 0.56), Vector3(0.96, -0.25, 0.0))
	view.place(centre, 0.0)
	var large := view.view().size
	# Its own size from the first place, not the default view's.
	assert_vector(Vector2(large)).is_not_equal(Vector2(512.0, 512.0))
	view.place(side.interpolate_with(centre, 0.5), 0.5)
	view.place(side, 1.0)
	assert_vector(Vector2(view.view().size)).override_failure_message("moving, it keeps its largest size") \
		.is_equal(Vector2(large))
	view.place(side, 1.0)
	assert_bool(view.view().size.x < large.x and view.view().size.y < large.y) \
		.override_failure_message("settled on a side, %s from %s" % [view.view().size, large]).is_true()


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


func test_a_view_stands_where_the_app_s_camera_sees_its_medium_whatever_its_parent_s_place() -> void:
	var camera := _camera()
	var parent: Control = auto_free(Control.new())
	parent.position = Vector2(200.0, 100.0)
	add_child(parent)
	var view: MediaView = auto_free(MediaView.new())
	view.camera = camera
	parent.add_child(view)
	view.show_medium(_disc(), StudioLights.rig_of("ps2_dvd", &"games"), StudioLights.rig_of("ps2_dvd", &"games", true))
	view.place(Transform3D.IDENTITY, 0.0)
	assert_bool(view.get_global_rect().has_point(camera.unproject_position(Vector3.ZERO))).is_true()
	assert_vector(view.get_global_rect().get_center()).is_equal_approx(camera.unproject_position(Vector3.ZERO), Vector2.ONE * 40.0)


func test_its_lights_follow_its_place_and_the_crossfade_to_the_light_without_a_picture_both_ways() -> void:
	var view := _view(_camera())
	var lit := StudioLights.rig_of("ps2_dvd", &"games")
	var blank := StudioLights.rig_of("ps2_dvd", &"games", true)
	var lights := view.lights()
	assert_int(lights.size()).is_equal(lit.sources.size() + blank.sources.size())
	for weight: float in [0.0, 0.4, 1.0, 0.25, 0.0]:
		view.crossfade(weight)
		for s: float in [0.0, 0.5, 1.0]:
			view.place(Transform3D(Basis.IDENTITY, Vector3(s, 0.0, 0.0)), s)
			var expected := StudioLights.shared(StudioLights.mixed(lit, blank, weight), s)
			for i in lights.size():
				assert_float(lights[i].light_energy).is_equal_approx(expected.sources[i].energy, 1e-6)
			var room := view.environment().ambient_light_energy
			assert_float(room).is_equal_approx(lerpf(lit.room, blank.room, weight), 1e-6)


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


func test_the_view_s_smoothing_follows_the_app_s_even_at_rest() -> void:
	var view := _view(_camera())
	view.place(Transform3D.IDENTITY, 0.0)
	assert_bool(view.is_processing()).is_true()
	get_tree().root.msaa_3d = Viewport.MSAA_2X
	view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
	view._process(0.02)
	assert_int(view.view().msaa_3d).is_equal(Viewport.MSAA_2X)
	assert_int(view.view().render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)
	get_tree().root.msaa_3d = Viewport.MSAA_DISABLED


func test_a_crossfade_at_rest_lights_and_draws_the_medium_again_both_ways() -> void:
	var lit := StudioLights.rig_of("ps2_dvd", &"games")
	var blank := StudioLights.rig_of("ps2_dvd", &"games", true)
	var own := _view(_camera())
	for weight: float in [0.7, 1.0, 0.2, 0.0]:
		own.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
		own.crossfade(weight)
		var expected := StudioLights.shared(StudioLights.mixed(lit, blank, weight), 0.0)
		for i in own.lights().size():
			assert_float(own.lights()[i].light_energy).is_equal_approx(expected.sources[i].energy, 1e-6)
		assert_int(own.view().render_target_update_mode).override_failure_message("drawn again at rest") \
			.is_equal(SubViewport.UPDATE_ONCE)
	assert_int(own.lights().size()).is_equal(lit.sources.size() + blank.sources.size())
	own.place(Transform3D.IDENTITY, 0.7)
	own.place(Transform3D.IDENTITY, 0.7)
	own.crossfade(0.5)
	var settled := StudioLights.shared(StudioLights.mixed(lit, blank, 0.5), 0.7)
	for i in own.lights().size():
		assert_float(own.lights()[i].light_energy).is_equal_approx(settled.sources[i].energy, 1e-6)


func test_the_softness_reaches_the_shader_in_the_window_s_pixels_by_its_five_parameters() -> void:
	var view := _view(_camera())
	var shader := view.material as ShaderMaterial
	var names: Array[String] = []
	for uniform: Dictionary in shader.shader.get_shader_uniform_list():
		var named: String = uniform["name"]
		names.append(named)
	assert_array(names).contains_exactly_in_any_order(["blur", "shadow_y", "shadow_blur", "shadow_colour", "saturation"])
	var random := RandomNumberGenerator.new()
	random.seed = 43
	var scale_by := StudioTokens.window_scale(get_window())
	for case in 20:
		var s := random.randf()
		view.place(Transform3D(Basis.IDENTITY, Vector3(random.randf_range(-0.5, 0.5), 0.0, 0.0)), s)
		var at := MediaView.look(s)
		var expected: Dictionary[StringName, float] = {&"blur": at.blur * scale_by, &"shadow_y": at.shadow_y * scale_by,
			&"shadow_blur": at.shadow_blur * scale_by, &"saturation": at.saturation}
		for parameter in expected:
			var given: float = shader.get_shader_parameter(parameter)
			assert_float(given).override_failure_message(parameter).is_equal_approx(expected[parameter], 1e-5)
		var colour: Color = shader.get_shader_parameter(&"shadow_colour")
		assert_float(colour.a).is_equal_approx(at.shadow_alpha, 1e-6)


func test_the_view_holds_the_medium_s_box_and_the_reach_of_its_look_in_any_window() -> void:
	var window := get_window()
	var was := window.size
	for wide: int in [1280, 1920, 640]:
		window.size = Vector2i(wide, roundi(wide * 0.75))
		var view := _view(_camera())
		var random := RandomNumberGenerator.new()
		random.seed = 47
		for case in 10:
			var at := Transform3D(Basis.from_scale(Vector3.ONE * random.randf_range(0.5, 1.0)),
				Vector3(random.randf_range(-0.8, 0.8), random.randf_range(-0.3, 0.3), 0.0))
			view.place(at, random.randf())
			var model := view.holder().get_child(0) as Node3D
			var box := Plinth.bounds(model, view.holder())
			var seen := Rect2(view.camera.unproject_position(at * box.get_endpoint(0)), Vector2.ZERO)
			for i in 8:
				seen = seen.expand(view.camera.unproject_position(at * box.get_endpoint(i)))
			var margin := MediaView.reach()
			var reached := Rect2(seen.position - Vector2(margin.x, margin.y), seen.size + Vector2(margin.x + margin.z, margin.y + margin.w))
			assert_bool(view.get_global_rect().grow(0.01).encloses(reached)).override_failure_message("%d px wide" % wide).is_true()
			assert_vector(Vector2(view.view().size)).is_equal_approx(view.size * StudioTokens.window_scale(window), Vector2.ONE * 0.01)
	window.size = was


func test_its_lamps_stand_about_the_medium_where_it_stands() -> void:
	var view := _view(_camera())
	var rig := StudioLights.mixed(StudioLights.rig_of("ps2_dvd", &"games"), StudioLights.rig_of("ps2_dvd", &"games", true), 0.0)
	var lamps := 0
	for at: Transform3D in [Transform3D.IDENTITY, Transform3D(Basis.from_scale(Vector3.ONE * 0.6), Vector3(0.9, -0.2, 0.1))]:
		view.place(at, 0.3)
		var model := view.holder().get_child(0) as Node3D
		var centre := at * Plinth.bounds(model, view.holder()).get_center()
		for i in rig.sources.size():
			if rig.sources[i].kind == &"lamp":
				lamps += 1
				assert_vector(view.lights()[i].position).is_equal_approx(centre + rig.sources[i].position, Vector3.ONE * 1e-5)
	assert_int(lamps).is_greater(0)


func test_the_row_draws_the_near_games_farthest_first_and_eases_each_from_the_chosen_to_a_neighbour() -> void:
	var order := MediaView.drawing_order(5, 0.0)
	assert_array(order).contains_exactly_in_any_order([0, 1, 2, 3, 4])
	assert_int(order[-1]).is_equal(0)
	for k in range(1, order.size()):
		assert_float(absf(MediaView.offset(order[k - 1], 0.0, 5))).is_greater_equal(absf(MediaView.offset(order[k], 0.0, 5)))
	assert_array(MediaView.drawing_order(9, 0.0)).not_contains([3, 4, 5, 6])
	var chosen := Transform3D(Basis.from_euler(Vector3(-0.2, 0.4, 0.0)).scaled(Vector3.ONE * 0.78), Vector3(0.0, 0.15, 0.1))
	var side := Vector2(0.96, -0.25)
	assert_that(MediaView.standing(0.0, chosen, side, 0.56).origin).is_equal(chosen.origin)
	var right := MediaView.standing(1.0, chosen, side, 0.56)
	assert_vector(right.origin).is_equal_approx(Vector3(0.96, -0.25, 0.0), Vector3.ONE * 1e-6)
	assert_vector(right.basis.get_scale()).is_equal_approx(Vector3.ONE * 0.56, Vector3.ONE * 1e-5)
	assert_vector(right.basis.get_rotation_quaternion().get_euler()).is_equal_approx(Vector3.ZERO, Vector3.ONE * 1e-5)
	var half := MediaView.standing(-0.5, chosen, side, 0.56)
	assert_float(half.basis.get_scale().x).is_equal_approx(lerpf(0.78, 0.56, 0.5), 1e-5)
	assert_float(half.origin.y).is_equal_approx(0.15 + (-0.25 - 0.15) * 0.25, 1e-6)
	assert_float(half.origin.x).is_equal_approx(-0.48, 1e-6)
	var turned := chosen.basis.get_rotation_quaternion().slerp(Quaternion.IDENTITY, 0.5)
	assert_float(half.basis.get_rotation_quaternion().angle_to(turned)).is_less(2e-3)
	var further := MediaView.standing(2.0, chosen, side, 0.56)
	assert_float(further.origin.x).is_equal_approx(1.92, 1e-6)


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


class WatchedView:
	extends MediaView
	var relights := 0
	var frames := 0

	func _light() -> void:
		relights += 1
		super._light()

	func _frame(settled: bool) -> void:
		frames += 1
		super._frame(settled)


func test_floating_redraws_only_the_selected_view_without_relighting_or_reframing_its_neighbours() -> void:
	var views: Array[WatchedView] = []
	for i in 3:
		var view: WatchedView = auto_free(WatchedView.new())
		view.camera = _camera()
		add_child(view)
		view.show_medium(_disc(), StudioLights.rig_of("ps2_dvd", &"games"), StudioLights.rig_of("ps2_dvd", &"games", true))
		views.append(view)
		var stand := Transform3D(Basis.IDENTITY, Vector3((i - 1) * 0.9, 0.0, 0.0))
		view.place(stand, 0.0 if i == 1 else 1.0)
		view.place(stand, 0.0 if i == 1 else 1.0)
		view.relights = 0
		view.frames = 0
	for frame in 120:
		for i in 3:
			var view := views[i]
			view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
			var stand := Transform3D(Basis.IDENTITY, Vector3((i - 1) * 0.9, 0.01 * sin(frame * 0.1) if i == 1 else 0.0, 0.0))
			view.place(stand, 0.0 if i == 1 else 1.0)
			assert_int(view.view().render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE if i == 1 and frame > 0 else SubViewport.UPDATE_DISABLED)
	for i in 3:
		assert_int(views[i].relights).is_equal(0)
		if i != 1:
			assert_int(views[i].frames).is_equal(0)


func test_a_settled_view_reframes_and_rescales_its_softness_when_the_window_changes() -> void:
	var window := get_window()
	var was := window.size
	window.size = Vector2i(1280, 960)
	var view := _view(_camera())
	view.place(Transform3D.IDENTITY, 1.0)
	view.place(Transform3D.IDENTITY, 1.0)
	window.size = Vector2i(1920, 1440)
	view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED
	view.place(Transform3D.IDENTITY, 1.0)
	assert_int(view.view().render_target_update_mode).is_equal(SubViewport.UPDATE_ONCE)
	assert_vector(Vector2(view.view().size)).is_equal_approx(view.size * StudioTokens.window_scale(window), Vector2.ONE * 0.01)
	var shader := view.material as ShaderMaterial
	assert_float(shader.get_shader_parameter(&"shadow_y")).is_equal_approx(8.0 * StudioTokens.window_scale(window), 0.001)
	window.size = was
