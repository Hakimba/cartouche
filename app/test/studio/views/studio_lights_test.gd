# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/studio/views/views_fixtures.gd")

const _CENTRE := Vector3(0.1, 0.2, -0.3)


func test_each_source_of_each_designed_light_is_built_as_its_kind_with_its_values() -> void:
	var data := _data()
	var built := 0
	for listing: String in ["lights", "blank"]:
		var models: Dictionary = data[listing]
		for model: String in models:
			var screens: Dictionary = models[model]
			for screen: String in screens:
				var told: Dictionary = screens[screen]
				var room: float = told["room"]
				var listed: Array = told["sources"]
				var sources: Array[Dictionary] = []
				sources.assign(listed)
				var parent: Node3D = auto_free(Node3D.new())
				var environment := Environment.new()
				var lights := StudioLights.new(parent, StudioLights.rig_of(model, StringName(screen), listing == "blank"),
					_CENTRE, environment).lights()
				assert_int(lights.size()).is_equal(sources.size())
				assert_float(environment.ambient_light_energy).is_equal_approx(room, 1e-6)
				for i in sources.size():
					_assert_built(lights[i], sources[i], "%s %s %s #%d" % [listing, model, screen, i])
					built += 1
	assert_int(built).is_greater(100)


func test_a_screen_without_a_designed_light_keeps_the_carousel_s_sun_and_room() -> void:
	var sun: Transform3D = Fixtures.property("res://carousel/carousel.tscn", &"Sun", &"transform")
	var environment := Fixtures.app_environment()
	for unlisted: Array in [["ps2_slim", &"consoles"], ["xbox", &"plinth"], ["no_such_model", &"games"]]:
		var model: String = unlisted[0]
		var screen: StringName = unlisted[1]
		var rig := StudioLights.rig_of(model, screen)
		assert_float(rig.room).is_equal_approx(environment.ambient_light_energy, 1e-6)
		assert_int(rig.sources.size()).is_equal(1)
		assert_str(rig.sources[0].kind).is_equal("sun")
		assert_float(rig.sources[0].energy).is_equal(1.0)
		# The sun's rays go along its -Z: from where it comes, its basis's Z.
		assert_vector(-rig.sources[0].target.normalized()).is_equal_approx(sun.basis.z.normalized(), Vector3.ONE * 1e-3)


func test_the_lights_designed_are_the_ones_listed() -> void:
	var lights: Dictionary = _data()["lights"]
	assert_array(lights.keys()).contains(["nes", "gbc", "ps2_dvd", "n64_cart", "gba_cart", "snes_pal_cart"])
	var nes: Dictionary = lights["nes"]
	assert_array(nes.keys()).contains_exactly_in_any_order(["consoles", "plinth"])
	assert_float(StudioLights.rig_of("ps2_dvd", &"games").room).is_equal(0.95)
	assert_float(StudioLights.rig_of("ps2_dvd", &"properties").room).is_equal(1.35)
	assert_str(StudioLights.rig_of("nes_cart", &"games").sources[0].kind).is_equal("lamp")


func test_only_the_games_screen_s_sources_light_the_chosen_medium_or_its_neighbours() -> void:
	var checked := 0
	for listing: String in ["lights", "blank"]:
		var models: Dictionary = _data()[listing]
		for model: String in models:
			var screens: Dictionary = models[model]
			for screen: String in screens:
				for source in StudioLights.rig_of(model, StringName(screen), listing == "blank").sources:
					var where := "%s %s %s" % [listing, model, screen]
					checked += 1
					if screen == "games":
						assert_array([StudioLights.CHOSEN, StudioLights.SIDES]).override_failure_message(where).contains([source.on])
					else:
						assert_str(source.on).override_failure_message(where).is_empty()
	assert_int(checked).is_greater(50)


func test_a_kind_s_light_without_a_picture_is_its_own_but_for_the_ps2_s_and_the_ps1_s() -> void:
	var blank: Dictionary = _data()["blank"]
	var lights: Dictionary = _data()["lights"]
	assert_array(blank.keys()).contains_exactly_in_any_order(lights.keys().filter(func(m: String) -> bool:
		return m not in ["nes", "gbc"]))
	for medium: String in blank:
		var same := JSON.stringify(blank[medium]) == JSON.stringify(lights[medium])
		assert_bool(same).override_failure_message(medium).is_equal(medium not in ["ps2_dvd", "ps1_cd"])


func _assert_built(light: Light3D, told: Dictionary, where: String) -> void:
	var kind: String = told["kind"]
	var at: PackedFloat32Array = told["position"]
	var aim: PackedFloat32Array = told["target"]
	var rgb: PackedFloat32Array = told["colour"]
	var energy: float = told["energy"]
	var reach: float = told["range"]
	var angle: float = told["angle"]
	var softness: float = told["softness"]
	var shadow: bool = told["shadow"]
	var position := Vector3(at[0], at[1], at[2])
	var target := Vector3(aim[0], aim[1], aim[2])
	var classes: Dictionary[String, String] = {"sun": "DirectionalLight3D", "lamp": "OmniLight3D", "spot": "SpotLight3D"}
	assert_str(light.get_class()).override_failure_message(where).is_equal(classes[kind])
	assert_float(light.light_energy).override_failure_message(where).is_equal_approx(energy, 1e-6)
	assert_that(light.light_color).override_failure_message(where).is_equal(Color(rgb[0], rgb[1], rgb[2]))
	assert_float(light.light_specular).is_equal(0.0)
	assert_bool(light.shadow_enabled).is_equal(shadow)
	var shines := -light.basis.z
	if light is DirectionalLight3D:
		assert_vector(shines).override_failure_message(where).is_equal_approx(target.normalized(), Vector3.ONE * 1e-5)
		return
	assert_vector(light.position).override_failure_message(where).is_equal_approx(_CENTRE + position, Vector3.ONE * 1e-5)
	if light is OmniLight3D:
		assert_float((light as OmniLight3D).omni_range).is_equal_approx(reach, 1e-6)
		assert_float((light as OmniLight3D).omni_attenuation).is_equal(1.0)
	else:
		var spot := light as SpotLight3D
		assert_float(spot.spot_range).is_equal_approx(reach, 1e-6)
		assert_float(spot.spot_angle).is_equal_approx(angle, 1e-6)
		assert_float(spot.spot_angle_attenuation).is_equal_approx(softness, 1e-6)
		assert_float(spot.spot_attenuation).is_equal(1.0)
		assert_vector(shines).override_failure_message(where).is_equal_approx((target - position).normalized(), Vector3.ONE * 1e-5)


static func _data() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(StudioLights.FILE))


func test_a_light_with_no_place_of_its_own_lights_every_medium_whole() -> void:
	var rig := StudioLights.rig_of("nes_cart", &"properties")
	assert_int(rig.sources.size()).is_greater(0)
	for s: float in [0.0, 0.4, 1.0]:
		var shared := StudioLights.shared(rig, s)
		for i in rig.sources.size():
			assert_str(rig.sources[i].on).is_empty()
			assert_float(shared.sources[i].energy).is_equal(rig.sources[i].energy)


func test_a_spot_casting_a_shadow_is_aimed_from_its_place_and_casts_it() -> void:
	var rig := StudioLights.Rig.read({"room": 0.3, "sources": [{"kind": "spot", "position": [1.0, 2.0, 3.0],
		"target": [0.0, 0.5, 0.0], "energy": 2.0, "colour": [1.0, 0.8, 0.6], "range": 6.0, "angle": 22.0, "softness": 0.4,
		"shadow": true}]})
	var parent: Node3D = auto_free(Node3D.new())
	var environment := Environment.new()
	var spot := StudioLights.new(parent, rig, Vector3(0.5, 0.0, 0.0), environment).lights()[0] as SpotLight3D
	assert_bool(spot.shadow_enabled).is_true()
	assert_vector(spot.position).is_equal_approx(Vector3(1.5, 2.0, 3.0), Vector3.ONE * 1e-6)
	assert_vector(-spot.basis.z).is_equal_approx(Vector3(-1.0, -1.5, -3.0).normalized(), Vector3.ONE * 1e-5)
	assert_float(spot.spot_angle).is_equal(22.0)
	assert_float(spot.spot_angle_attenuation).is_equal_approx(0.4, 1e-6)
	assert_float(environment.ambient_light_energy).is_equal_approx(0.3, 1e-6)
