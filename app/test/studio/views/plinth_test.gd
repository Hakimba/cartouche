# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const StillStandIn := preload("res://test/studio/views/still_stand_in.gd")
## The design's POSED table: [start yaw, roll] in degrees per console folder.
const _POSED: Dictionary[String, Vector2] = {"ps2_slim": Vector2(43.6, 1.3), "psx": Vector2(49.1, 0.0),
	"nes": Vector2(16.6, 1.6), "snes": Vector2(24.9, 0.0), "n64": Vector2(33.8, 0.0), "gc": Vector2(54.9, 0.0),
	"wii": Vector2(-3.2, 0.3), "xbox": Vector2(46.6, 0.0), "xbox360": Vector2(-5.7, -89.5),
	"gb": Vector2(-20.3, 0.0), "gbc": Vector2(-25.4, 0.0), "gba": Vector2(-28.1, 0.0), "ps2_fat": Vector2(16.6, 1.6), "gba_sp": Vector2(24.0, 0.0)}


func before_test() -> void:
	Plinth._stills.clear()
	StillStandIn.install()


func after_test() -> void:
	StillStandIn.restore()


# GdUnit reads the skip from these arguments.
@warning_ignore("unused_parameter")
func test_a_console_s_picture_is_rendered_once_at_the_size_shown_and_kept(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	var drawn := await _picture("nes")
	var size := Vector2i((StudioTokens.TURNTABLE.size * StudioTokens.window_scale(get_window())).ceil())
	assert_vector(drawn.get_size()).is_equal(Vector2(size))
	assert_object(Plinth.still_of("nes")).is_same(drawn)
	assert_object(await _picture("nes")).is_same(drawn)


# GdUnit reads the skip from these arguments.
@warning_ignore("unused_parameter")
func test_the_view_a_picture_is_drawn_in_is_freed_once_it_is_rendered(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	await _picture("snes")
	await await_idle_frame()
	assert_array(get_tree().root.find_children("*", "SubViewport", false, false)).is_empty()


# GdUnit reads the skip from these arguments.
@warning_ignore("unused_parameter")
func test_each_console_s_picture_is_upright_whole_and_inside_its_frame(
		do_skip := DisplayServer.get_name() == "headless", skip_reason := "draws in a window: needs a renderer") -> void:
	for folder in _POSED:
		var image := (await _picture(folder)).get_image()
		var used := image.get_used_rect()
		assert_bool(used.has_area()).override_failure_message(folder).is_true()
		assert_bool(Rect2i(Vector2i.ONE, image.get_size() - Vector2i(2, 2)).encloses(used)) \
			.override_failure_message("%s touches the frame's edge: %s" % [folder, used]).is_true()
		# On its base: the lowest pixels stand in the lower half, the picture's centre line close to the frame's.
		assert_float(float(used.get_center().x)).override_failure_message(folder) \
			.is_equal_approx(image.get_width() / 2.0, image.get_width() * 0.2)
		assert_int(used.end.y).override_failure_message(folder).is_greater(roundi(image.get_height() / 2.0))


func test_the_plinth_shows_nothing_until_the_picture_exists_then_it_rises_in() -> void:
	var plinth := _plinth("xbox")
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_object(turntable.texture).is_null()
	assert_bool(await Fixtures.until(self, func() -> bool: return turntable.texture != null)).is_true()
	assert_object(turntable.texture).is_same(Plinth.still_of("xbox"))
	assert_str(plinth.console()).is_equal("xbox")
	var plate: TextureRect = plinth.get_node("Plate")
	assert_object(plate.texture).is_equal(load("res://studio/logos/plinth-plate/xbox.png"))


func test_a_console_asked_for_while_another_renders_is_the_one_shown() -> void:
	var plinth := _plinth("snes")
	plinth.show_console("gb")
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("gb") != null)).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("snes") != null)).is_true()
	await await_idle_frame()
	assert_object(turntable.texture).is_same(Plinth.still_of("gb"))
	assert_object(Plinth.still_of("gb")).is_not_same(Plinth.still_of("snes"))


func test_scrolling_past_consoles_draws_only_the_one_left_under_the_cursor() -> void:
	var drawn: Array[String] = []
	var stand_in := Plinth._drawer
	Plinth._drawer = func(folder: String) -> ImageTexture:
		drawn.append(folder)
		return await stand_in.call(folder)
	var plinth: Plinth = auto_free(Plinth.create())
	add_child(plinth)
	var folders: Array[String] = []
	folders.assign(_POSED.keys().slice(0, 12))
	for folder: String in folders:
		plinth.show_console(folder)
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of(folders[-1]) != null)).is_true()
	await await_idle_frame()
	# The first asked was already drawing when the scroll began.
	assert_array(drawn).is_equal([folders[0], folders[-1]])
	assert_object((plinth.get_node("Turntable") as TextureRect).texture).is_same(Plinth.still_of(folders[-1]))


func test_asking_again_for_a_folder_waiting_moves_it_to_the_front() -> void:
	var drawn: Array[String] = []
	var stand_in := Plinth._drawer
	Plinth._drawer = func(folder: String) -> ImageTexture:
		drawn.append(folder)
		return await stand_in.call(folder)
	for folder: String in ["gb", "gbc", "gba", "gbc"]:
		Plinth.request_still(folder, func(_drawn: Texture2D) -> void: pass)
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("gba") != null)).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("gb") != null)).is_true()
	assert_array(drawn).is_equal(["gb", "gbc", "gba"])


func test_another_edge_smoothing_is_another_still() -> void:
	var root := get_tree().root
	var before_smoothing := root.msaa_3d
	var first := await _picture("gb")
	root.msaa_3d = Viewport.MSAA_DISABLED if before_smoothing != Viewport.MSAA_DISABLED else Viewport.MSAA_4X
	assert_object(Plinth.still_of("gb")).is_null()
	var second := await _picture("gb")
	root.msaa_3d = before_smoothing
	assert_object(second).is_not_same(first)
	assert_object(Plinth.still_of("gb")).is_same(first)


func test_a_plinth_freed_before_its_picture_is_ready_leaves_the_picture_for_the_next() -> void:
	var plinth := Plinth.create()
	add_child(plinth)
	plinth.show_console("gba")
	plinth.free()
	assert_bool(await Fixtures.until(self, func() -> bool: return Plinth.still_of("gba") != null)).is_true()


func test_a_cleared_plinth_shows_no_picture_and_a_cached_one_is_shown_at_once() -> void:
	var plinth := _plinth("gb")
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_bool(await Fixtures.until(self, func() -> bool: return turntable.texture != null)).is_true()
	plinth.clear()
	assert_object(turntable.texture).is_null()
	assert_str(plinth.console()).is_empty()
	plinth.show_console("gb")
	assert_object(turntable.texture).is_same(Plinth.still_of("gb"))


func test_every_console_starts_at_its_pose_s_yaw_and_roll() -> void:
	var folders: Array[String] = []
	for manifest in ConsoleManifest.found():
		folders.append(ConsoleManifest.folder_of(manifest))
	assert_array(folders).contains_exactly_in_any_order(_POSED.keys())
	for folder in _POSED:
		var start := Plinth.start_of(folder)
		var posed: Vector2 = _POSED[folder]
		assert_vector(start.rotation).override_failure_message(folder).is_equal(Vector3(0.0, posed.x, posed.y))
		assert_vector(start.position).override_failure_message(folder).is_equal(Vector3.ZERO)
		assert_float(start.size).override_failure_message(folder).is_equal(1.0)


func test_INV_EX_04_a_start_of_a_yaw_and_a_roll_stands_every_console_as_before_the_full_pose() -> void:
	for folder in _POSED:
		var posed: Vector2 = _POSED[folder]
		var now := _stood(folder, Plinth.start_of(folder))
		# Before the full pose: rolled, fitted as the roll left it, then turned by the yaw.
		var spin := Node3D.new()
		var stand := Node3D.new()
		var model := (load(ConsoleManifest.of(folder).scene) as PackedScene).instantiate() as Node3D
		spin.add_child(stand)
		stand.add_child(model)
		stand.transform = Transform3D(Basis(Vector3.BACK, deg_to_rad(posed.y)), Vector3.ZERO)
		var box := Plinth.bounds(model, spin)
		stand.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z)
		spin.scale = Vector3.ONE * minf(Plinth._FIT_DIAMETER / Vector2(box.size.x, box.size.z).length(), Plinth._HEIGHT / box.size.y)
		spin.rotation.y = deg_to_rad(posed.x)
		var was := spin.transform * stand.transform
		assert_bool(now.is_equal_approx(was)).override_failure_message("%s: %s, was %s" % [folder, now, was]).is_true()
		spin.free()


func test_INV_EX_04_a_full_start_turns_the_model_as_its_three_angles_say_then_moves_and_sizes_it() -> void:
	var plain := _stood("ps2_fat", Plinth.Start.new(Vector3(12.0, 30.0, -8.0)))
	var turn := Vector3(12.0, 30.0, -8.0) * PI / 180.0
	assert_bool(plain.basis.orthonormalized().is_equal_approx(Basis.from_euler(turn))).is_true()
	var posed := _stood("ps2_fat", Plinth.Start.new(Vector3(12.0, 30.0, -8.0), Vector3(0.1, -0.2, 0.3), 1.5))
	assert_bool(posed.basis.is_equal_approx(plain.basis * 1.5)).is_true()
	assert_vector(posed.origin).is_equal_approx(plain.origin * 1.5 + Vector3(0.1, -0.2, 0.3), Vector3.ONE * 1e-5)


## The transform of [param folder]'s model's parent in its view's world once stood at [param start].
func _stood(folder: String, start: Plinth.Start) -> Transform3D:
	var spin := Node3D.new()
	var stand := Node3D.new()
	var model := (load(ConsoleManifest.of(folder).scene) as PackedScene).instantiate() as Node3D
	spin.add_child(stand)
	stand.add_child(model)
	Plinth.stand_at(spin, stand, model, start)
	var at := spin.transform * stand.transform
	spin.free()
	return at


func test_the_plinth_takes_the_design_s_face_and_places_in_the_console_s_colour() -> void:
	var plinth := _plinth("gbc")
	var base: SatinPanel = plinth.get_node("Base")
	assert_int(base.look).is_equal(StudioTokens.Look.PLINTH)
	assert_that(base.gel).is_equal(Cyclorama.gel_of(ConsoleManifest.of("gbc")))
	var turntable: Control = plinth.get_node("Turntable")
	assert_float(turntable.position.x + plinth.position.x).is_equal_approx(StudioTokens.TURNTABLE.position.x, 1e-3)
	assert_vector(turntable.size).is_equal_approx(StudioTokens.TURNTABLE.size, Vector2.ONE * 1e-3)
	var plate: Control = plinth.get_node("Plate")
	assert_vector(plate.get_global_rect().get_center()) \
		.is_equal_approx(StudioTokens.PLINTH.position + StudioTokens.PLINTH_PLATE.get_center(), Vector2.ONE * 0.5)
	assert_vector(plate.global_position).is_equal(plate.global_position.round())
	# The rim: the gel mixed with white in OKLab, 70 % of it.
	var rim := StudioMaterial.new(StudioTokens.Look.PLINTH).shadows[1].shown(base.gel)
	assert_that(rim).is_equal(Color(StudioMaterial.whitened(base.gel, 0.7), 1.0))
	assert_that(StudioMaterial.whitened(Color("#ff0000"), 1.0)).is_equal(Color("#ff0000"))
	# color-mix(in oklab, <colour> 70%, #fff) as Chromium draws it.
	var drawn: Dictionary[Color, Vector3] = {Color("#ff0000"): Vector3(255.0, 119.0, 101.0), Color("#e2408a"): Vector3(241.0, 129.0, 172.0)}
	for colour in drawn:
		var mixed := StudioMaterial.whitened(colour, 0.7)
		assert_vector(Vector3(mixed.r, mixed.g, mixed.b) * 255.0).is_equal_approx(drawn[colour], Vector3.ONE)


func test_a_new_console_rises_into_place_by_the_rise_curve_in_300_ms() -> void:
	var plinth := _plinth("gb")
	var turntable: TextureRect = plinth.get_node("Turntable")
	await Fixtures.until(self, func() -> bool: return turntable.texture != null)
	var rest_y := StudioTokens.TURNTABLE.position.y - StudioTokens.PLINTH.position.y
	var rises := get_tree().get_processed_tweens()
	for tween in rises:
		tween.pause()
	assert_float(turntable.position.y).is_equal_approx(rest_y + 20.48, 1e-3)
	assert_float(turntable.modulate.a).is_equal_approx(0.0, 1e-6)
	rises[-1].custom_step(0.1)
	var risen := Motion.eased(Motion.Easing.RISE, 0.1 / 0.3)
	assert_float(turntable.position.y).is_equal_approx(rest_y + 20.48 * (1.0 - risen), 1e-3)
	assert_float(turntable.modulate.a).is_equal_approx(risen, 1e-4)
	rises[-1].custom_step(0.2)
	assert_float(turntable.position.y).is_equal_approx(rest_y, 1e-3)
	assert_float(turntable.modulate.a).is_equal_approx(1.0, 1e-4)


## A plinth showing [param folder] where the Console chooser has it, on the frame it appears.
func _plinth(folder: String) -> Plinth:
	var plinth: Plinth = auto_free(Plinth.create())
	plinth.position = StudioTokens.PLINTH.position
	add_child(plinth)
	plinth.show_console(folder)
	return plinth


## The picture of [param folder], once rendered.
func _picture(folder: String) -> Texture2D:
	var asked: Array[Texture2D] = []
	Plinth.request_still(folder, func(picture: Texture2D) -> void: asked.append(picture))
	await Fixtures.until(self, func() -> bool: return not asked.is_empty())
	return asked[0]
