# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/dev/bridge/fixtures.gd")
var _commands: Fixtures.CommandHost


func before_test() -> void:
	_commands = Fixtures.CommandHost.new()
	add_child(_commands)


func after_test() -> void:
	_commands.free()


func test_tune_changes_the_shown_light_live_and_keeps_it_after_the_view_places_it_again() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var light := scene.row.lights().lights()[0]
	var original_text := FileAccess.get_file_as_string(StudioLights.FILE)
	var result := await _commands.run({"cmd": "tune", "target": "light", "index": 0,
		"values": {"energy": 3.25, "colour": [0.25, 0.5, 0.75], "target": [0, -1, 0], "shadow": false}})
	assert_bool(result["ok"]).is_true()
	assert_float(light.light_energy).is_equal(3.25)
	assert_that(light.light_color).is_equal(Color(0.25, 0.5, 0.75))
	scene.row.lights().tune(StudioLights.rig_of("nes", &"consoles"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(light.light_energy).is_equal(3.25)
	assert_str(FileAccess.get_file_as_string(StudioLights.FILE)).is_equal(original_text)


func test_a_console_without_a_rig_is_tuned_through_the_scene_sun_and_its_environment() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	scene.add_child(sun)
	var world := WorldEnvironment.new()
	world.name = "Environment"
	world.environment = Environment.new()
	scene.add_child(world)
	scene.row._items[0].folder = "no_rig_here"
	scene.row._light_selected()
	assert_object(scene.row.lights()).is_null()
	var result := await _commands.run({"cmd": "tune", "target": "light", "index": 0, "values": {"energy": 2.5, "target": [0, -1, 0]}})
	assert_bool(result["ok"]).is_true()
	assert_float(sun.light_energy).is_equal(2.5)
	assert_vector(-sun.global_basis.z).is_equal_approx(Vector3.DOWN, Vector3.ONE * 1e-5)
	assert_bool((await _commands.run({"cmd": "tune", "target": "room", "values": {"energy": 0.9}}))["ok"]).is_true()
	assert_float(world.environment.ambient_light_energy).is_equal_approx(0.9, 1e-5)
	await get_tree().process_frame
	assert_float(sun.light_energy).is_equal(2.5)
	assert_bool((await _commands.run({"cmd": "tune", "target": "light", "index": 1, "values": {"energy": 1}}))["ok"]).is_false()


func test_tune_room_sets_the_ambient_light_and_keeps_it_after_the_view_places_it_again() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var rig := scene.row.lights()
	var result := await _commands.run({"cmd": "tune", "target": "room", "values": {"energy": 1.25}})
	assert_bool(result["ok"]).is_true()
	assert_float(rig._environment.ambient_light_energy).is_equal(1.25)
	rig.tune(StudioLights.rig_of("nes", &"consoles"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_float(rig._environment.ambient_light_energy).is_equal(1.25)
	assert_bool((await _commands.run({"cmd": "tune", "target": "room", "values": {"energy": "x"}}))["ok"]).is_false()


func test_state_names_the_rig_of_the_shown_lights() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var answer := await _commands.run({"cmd": "state"})
	assert_dict(answer["rig"]).is_equal({"model": "nes", "screen": "consoles", "blank": false})
	scene.row.hide()
	assert_dict((await _commands.run({"cmd": "state"}))["rig"]).is_empty()


func test_tune_pose_moves_rotates_and_sizes_only_the_shown_model() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var model := scene.row.selected().model
	var result := await _commands.run({"cmd": "tune", "target": "pose",
		"values": {"position": [1, 2, 3], "rotation": [0.1, 0.2, 0.3], "scale": [2, 2, 2]}})
	assert_bool(result["ok"]).is_true()
	assert_array(result["pose"]["position"]).is_equal([1.0, 2.0, 3.0])
	assert_array(result["pose"]["scale"]).is_equal([2.0, 2.0, 2.0])
	assert_vector(model.position).is_equal(Vector3(1, 2, 3))
	assert_vector(model.rotation).is_equal_approx(Vector3(0.1, 0.2, 0.3), Vector3.ONE * 1e-5)
	assert_vector(model.scale).is_equal_approx(Vector3(2, 2, 2), Vector3.ONE * 1e-5)
	model.position = Vector3.ZERO
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(model.position).is_equal(Vector3(1, 2, 3))
	var read := await _commands.run({"cmd": "tune", "target": "pose", "values": {}})
	assert_array(read["pose"]["rotation"]).has_size(3)
	assert_vector(model.position).is_equal(Vector3(1, 2, 3))


func test_tune_control_changes_its_box_font_colour_and_corners_without_changing_its_shared_style() -> void:
	var scene := Control.new()
	_commands.host = scene
	_commands.add_child(scene)
	var panel := Panel.new()
	panel.name = "Panel"
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override(&"panel", style)
	scene.add_child(panel)
	var result := await _commands.run({"cmd": "tune", "target": "control", "path": "Panel",
		"values": {"position": [15, 20], "size": [100, 60], "font_size": 23,
			"colour": [0.2, 0.3, 0.4, 1], "corner_radius": 12}})
	assert_bool(result["ok"]).is_true()
	assert_vector(panel.position).is_equal(Vector2(15, 20))
	assert_vector(panel.size).is_equal(Vector2(100, 60))
	assert_int(panel.get_theme_font_size(&"font_size")).is_equal(23)
	assert_float((panel.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color.r).is_equal_approx(0.2, 1e-5)
	assert_int((panel.get_theme_stylebox(&"panel") as StyleBoxFlat).corner_radius_top_left).is_equal(12)
	assert_int(style.corner_radius_top_left).is_equal(3)
	panel.position = Vector2.ZERO
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(panel.position).is_equal(Vector2(15, 20))
	assert_bool((await _commands.run({"cmd": "tune", "target": "control", "path": str(_commands.get_path()),
		"values": {"position": [0, 0]}}))["ok"]).is_false()


func test_a_control_tune_with_a_corner_radius_it_cannot_take_changes_nothing() -> void:
	var scene := Control.new()
	var label := Control.new()
	label.position = Vector2(4, 5)
	label.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	scene.add_child(label)
	_commands.host = scene
	_commands.add_child(scene)
	var answer := await _commands.run({"cmd": "tune", "target": "control", "path": str(scene.get_path_to(label)),
		"values": {"position": [50, 60], "corner_radius": 8}})
	assert_bool(answer["ok"]).is_false()
	assert_vector(label.position).is_equal(Vector2(4, 5))


func test_tune_motion_tries_a_design_timing_live_and_refuses_any_other_value() -> void:
	var arrive: float = StudioTokens.ARRIVE_S
	var fade: float = StudioTokens.GEL_FADE_S
	var scene := Control.new()
	_commands.host = scene
	_commands.add_child(scene)
	var answer := await _commands.run({"cmd": "tune", "target": "motion", "values": {"ARRIVE_S": 0.9, "GEL_FADE_S": 2.0}})
	assert_bool(answer["ok"]).is_true()
	assert_float(StudioTokens.ARRIVE_S).is_equal(0.9)
	assert_float(StudioTokens.GEL_FADE_S).is_equal(2.0)
	for refused: Dictionary in [{"ARRIVE_S": -1}, {"SPRING_STIFFNESS": 1.0}, {"ARRIVE_S": "x"}, {"BACK_S": 1.0}, {"MORPH_S": 1.0}]:
		assert_bool((await _commands.run({"cmd": "tune", "target": "motion", "values": refused}))["ok"]).is_false()
	assert_float(StudioTokens.ARRIVE_S).is_equal(0.9)
	await _commands.run({"cmd": "tune", "target": "motion", "values": {"ARRIVE_S": arrive, "GEL_FADE_S": fade}})
	assert_float(StudioTokens.ARRIVE_S).is_equal(arrive)
	assert_float(StudioTokens.GEL_FADE_S).is_equal(fade)


func test_pick_returns_the_topmost_visible_control_its_editable_values_and_respects_clipping() -> void:
	var scene := Control.new()
	scene.size = Vector2(300, 300)
	_commands.host = scene
	_commands.add_child(scene)
	var back := ColorRect.new()
	back.name = "Back"
	back.position = Vector2(10, 20)
	back.size = Vector2(100, 80)
	back.color = Color(0.2, 0.4, 0.6, 1)
	scene.add_child(back)
	var front := Button.new()
	front.name = "Front"
	front.position = Vector2(20, 30)
	front.size = Vector2(80, 40)
	front.z_index = 2
	front.add_theme_font_size_override(&"font_size", 31)
	scene.add_child(front)
	var result := await _commands.run({"cmd": "pick", "x": 30, "y": 40})
	var picked: Dictionary = result["control"]
	assert_str(picked["path"]).is_equal(str(front.get_path()))
	assert_str(picked["class"]).is_equal("Button")
	assert_array(picked["rect"]).is_equal([20.0, 30.0, 80.0, 40.0])
	assert_int(picked["font_size"]).is_equal(31)
	var stack: Array = result["stack"]
	assert_array(stack.map(func(entry: Dictionary) -> String: return entry["path"])).is_equal([str(front.get_path()), str(back.get_path()), str(scene.get_path())])
	front.modulate.a = 0
	result = await _commands.run({"cmd": "pick", "x": 30, "y": 40})
	picked = result["control"]
	assert_str(picked["path"]).is_equal(str(back.get_path()))
	var colour: Array = picked["colour"]
	assert_float(colour[1]).is_equal_approx(0.4, 1e-5)
	scene.clip_contents = true
	scene.size = Vector2(15, 15)
	result = await _commands.run({"cmd": "pick", "x": 30, "y": 40})
	assert_dict(result["control"]).is_empty()
	assert_array(result["stack"]).is_empty()


func test_pick_returns_the_console_under_the_point_and_none_beside_it() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 5)
	scene.add_child(camera)
	camera.make_current()
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	scene.row.selected().model.add_child(mesh)
	var centre := camera.unproject_position(scene.row.selected().model.global_position)
	var result := await _commands.run({"cmd": "pick", "x": centre.x, "y": centre.y})
	assert_dict(result["model"]).is_equal({"folder": "nes"})
	result = await _commands.run({"cmd": "pick", "x": -1000, "y": -1000})
	assert_dict(result["model"]).is_empty()


func test_tune_on_a_plinth_keeps_its_real_model_and_light_alive_only_under_the_bridge_preview() -> void:
	var scene := Control.new()
	_commands.host = scene
	_commands.add_child(scene)
	var plinth := Plinth.create()
	scene.add_child(plinth)
	plinth.show_console("nes")
	var result := await _commands.run({"cmd": "tune", "target": "pose", "values": {"rotation": [0.1, 0.2, 0.3]}})
	assert_bool(result["ok"]).is_true()
	var rect: Array = result["rect"]
	assert_array(rect).has_size(4)
	assert_float(rect[2]).is_greater(0.0)
	var preview := plinth.get_node("BridgePreview")
	var model: Node3D = preview.get("model")
	assert_vector(model.rotation).is_equal_approx(Vector3(0.1, 0.2, 0.3), Vector3.ONE * 1e-5)
	var camera: Camera3D = preview.get("camera")
	var turntable := plinth.get_node("Turntable") as Control
	var seen := camera.unproject_position(model.global_transform * Plinth.bounds(model, model).get_center())
	var on_screen := turntable.get_global_rect().position + seen * turntable.size / camera.get_viewport().get_visible_rect().size
	var space: Dictionary = result["space"]
	assert_vector(_projected(space)).is_equal_approx(on_screen, Vector2.ONE * 0.01)
	result = await _commands.run({"cmd": "tune", "target": "light", "index": 0, "values": {"energy": 4.5}})
	assert_bool(result["ok"]).is_true()
	var lights: StudioLights = preview.get("lights")
	assert_float(lights.lights()[0].light_energy).is_equal(4.5)
	assert_bool((plinth.get_node("Turntable") as TextureRect).texture is ViewportTexture).is_true()
	plinth.show_console("gb")
	result = await _commands.run({"cmd": "tune", "target": "pose", "values": {"position": [0.1, 0.2, 0.3]}})
	assert_bool(result["ok"]).is_true()
	preview = plinth.get_node("BridgePreview")
	assert_str(preview.get("folder")).is_equal("gb")
	await get_tree().process_frame
	await get_tree().process_frame


func test_INV_EX_04_a_turntable_tune_stands_the_live_model_as_the_plinth_s_picture_would_and_answers_where() -> void:
	var scene := Control.new()
	_commands.host = scene
	_commands.add_child(scene)
	var plinth := Plinth.create()
	scene.add_child(plinth)
	plinth.show_console("ps2_fat")
	var level: Dictionary = (await _commands.run({"cmd": "tune", "target": "pose", "values": {}}))["space"]
	var result := await _commands.run({"cmd": "tune", "target": "turntable",
		"values": {"rotation": [12.0, 30.0, -8.0], "position": [0.1, -0.2, 0.3], "size": 1.5}})
	assert_bool(result["ok"]).is_true()
	var preview := plinth.get_node("BridgePreview")
	var model: Node3D = preview.get("model")
	var start := Plinth.Start.new(Vector3(12.0, 30.0, -8.0), Vector3(0.1, -0.2, 0.3), 1.5)
	var spin := Node3D.new()
	var stand := Node3D.new()
	var still := (load(ConsoleManifest.of("ps2_fat").scene) as PackedScene).instantiate() as Node3D
	spin.add_child(stand)
	stand.add_child(still)
	Plinth.stand_at(spin, stand, still, start)
	assert_bool(model.global_transform.is_equal_approx(spin.transform * stand.transform * still.transform)).is_true()
	spin.free()
	var space: Dictionary = result["space"]
	assert_bool(_read(space["model"]).is_equal_approx(model.global_transform)).is_true()
	assert_bool(_read(level["model"]).is_equal_approx(model.global_transform)).is_false()
	await _commands.run({"cmd": "tune", "target": "turntable", "values": {"size": 1.0}})
	var now: Plinth.Start = preview.get("start")
	assert_vector(now.rotation).is_equal(Vector3(12.0, 30.0, -8.0))
	assert_float(now.size).is_equal(1.0)
	for values: Dictionary in [{"size": [1.0]}, {"rotation": [1.0, 2.0]}, {"pitch": 3.0}]:
		assert_bool((await _commands.run({"cmd": "tune", "target": "turntable", "values": values}))["ok"]).is_false()


func test_a_turntable_tune_is_refused_where_no_plinth_shows_a_console() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	var result := await _commands.run({"cmd": "tune", "target": "turntable", "values": {"size": 2.0}})
	assert_bool(result["ok"]).is_false()
	assert_vector(scene.row.selected().model.scale).is_equal(Vector3.ONE)


func test_tune_rejects_bad_values_without_changing_the_shown_model() -> void:
	var scene := Fixtures.ProbeScene.new()
	_commands.host = scene
	_commands.add_child(scene)
	for message: Dictionary in [
		{"target": "pose", "values": {"position": [1, 2]}},
		{"target": "pose", "values": {"position": [1, 2, "x"]}},
		{"target": "light", "index": -1, "values": {"energy": 9}},
		{"target": "light", "index": 0, "values": {"not_a_property": 9}}]:
		message["cmd"] = "tune"
		assert_bool((await _commands.run(message))["ok"]).is_false()
	assert_vector(scene.row.selected().model.position).is_equal(Vector3.ZERO)


func test_a_pose_tune_of_a_medium_answers_where_the_app_s_camera_shows_it_whatever_turn_its_holder_has() -> void:
	var scene := Control.new()
	_commands.host = scene
	_commands.add_child(scene)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 5)
	scene.add_child(camera)
	camera.make_current()
	var view := MediaView.new()
	view.camera = camera
	scene.add_child(view)
	var fitted := Node3D.new()
	fitted.add_child(MeshInstance3D.new())
	(fitted.get_child(0) as MeshInstance3D).mesh = BoxMesh.new()
	view.show_medium(fitted, StudioLights.rig_of("ps2_dvd", &"games"), StudioLights.rig_of("ps2_dvd", &"games", true))
	view.place(Transform3D(Basis(Vector3.UP, PI / 2.0).scaled(Vector3.ONE * 2.0), Vector3(0.5, 0.25, 0.0)), 0.0)
	var turned := await _commands.run({"cmd": "tune", "target": "pose", "values": {}})
	assert_bool(turned["ok"]).is_true()
	var space: Dictionary = turned["space"]
	assert_vector(_projected(space)).is_equal_approx(camera.unproject_position(fitted.global_position), Vector2.ONE * 0.01)
	assert_bool(_read(space["parent"]).is_equal_approx(view.holder().global_transform)).is_true()
	view.free()


## Where the answer's numbers alone put the shown model's box centre on the screen.
static func _projected(space: Dictionary) -> Vector2:
	var n: PackedFloat32Array = space["projection"]
	var projection := Projection(Vector4(n[0], n[1], n[2], n[3]), Vector4(n[4], n[5], n[6], n[7]),
		Vector4(n[8], n[9], n[10], n[11]), Vector4(n[12], n[13], n[14], n[15]))
	var centre: PackedFloat32Array = space["centre"]
	var local := _read(space["camera"]).affine_inverse() * _read(space["model"]) * Vector3(centre[0], centre[1], centre[2])
	var clip := projection * Vector4(local.x, local.y, local.z, 1.0)
	var view: PackedFloat32Array = space["view"]
	return Vector2(view[0] + (clip.x / clip.w * 0.5 + 0.5) * view[2], view[1] + (0.5 - clip.y / clip.w * 0.5) * view[3])


## A transform as the bridge answers it: the basis columns, then the origin.
static func _read(numbers: Variant) -> Transform3D:
	var n: PackedFloat32Array = numbers
	return Transform3D(Vector3(n[0], n[1], n[2]), Vector3(n[3], n[4], n[5]), Vector3(n[6], n[7], n[8]), Vector3(n[9], n[10], n[11]))


func test_plain_inherited_text_can_be_edited_and_survives_the_screen_setting_it_again() -> void:
	var scene := Control.new()
	_commands.host = scene
	_commands.add_child(scene)
	var label := Label.new()
	label.name = "PlainLabel"
	label.text = "A plain value"
	scene.add_child(label)
	var answer := await _commands.run({"cmd": "tune", "target": "control", "path": "PlainLabel", "values": {"text": "Chosen value"}})
	assert_bool(answer["ok"]).is_true()
	label.text = "A later value"
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert_str(label.text).is_equal("Chosen value")


func test_a_translation_key_is_reported_and_refused() -> void:
	var locale := TranslationServer.get_locale()
	var translation := Translation.new()
	translation.locale = "fr"
	translation.add_message("TEST_TRANSLATION_KEY", "Un texte traduit")
	TranslationServer.add_translation(translation)
	TranslationServer.set_locale("fr")
	var scene := Control.new()
	_commands.host = scene
	_commands.add_child(scene)
	var label := Label.new()
	label.name = "TranslatedLabel"
	label.text = "TEST_TRANSLATION_KEY"
	scene.add_child(label)
	var answer := await _commands.run({"cmd": "tune", "target": "control", "path": "TranslatedLabel", "values": {"text": "Choice"}})
	assert_bool(answer["ok"]).is_false()
	assert_str(answer["error"]).contains("traductions")
	TranslationServer.remove_translation(translation)
	TranslationServer.set_locale(locale)
