# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const SCENE := preload("res://screens/variant_chooser.tscn")

var _closings: Array[bool] = []


func _chooser(platform: String, current: String) -> VariantChooser:
	var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	device.consoles[platform] = 1
	var chooser: VariantChooser = auto_free(SCENE.instantiate())
	chooser.android = device
	add_child(chooser)
	chooser.open(platform, current)
	chooser.closed.connect(func(changed: bool) -> void: _closings.append(changed))
	return chooser


func test_a_previews_then_keeps_the_variant_and_b_changes_nothing() -> void:
	for pair: Array in [["ps2", "ps2_slim", "ps2_fat"], ["gba", "gba", "gba_sp"]]:
		var platform: String = pair[0]
		var base: String = pair[1]
		var chooser := _chooser(platform, base)
		var device := chooser.android as Fixtures.NewDevice
		assert_str(chooser.counter()).is_equal("1 / 2")
		await Fixtures.action(self, &"ui_left")
		assert_str(chooser.variant_id()).is_equal(pair[2])
		assert_str(chooser._plinth.console()).is_equal(pair[2])
		assert_str(chooser.counter()).is_equal("2 / 2")
		assert_array(device.variants_kept).is_empty()
		await Fixtures.action(self, &"screen_back")
		assert_bool(chooser.visible).is_false()
		assert_dict(device.console_variants).is_empty()
		assert_array(_closings).is_equal([false])
		chooser.open(platform, base)
		await Fixtures.action(self, &"ui_accept")
		assert_array(_closings).is_equal([false, false])
		assert_array(device.variants_kept).is_empty()
		chooser.open(platform, base)
		await Fixtures.action(self, &"ui_right")
		await Fixtures.action(self, &"ui_accept")
		assert_bool(await Fixtures.until(self, func() -> bool: return not chooser.visible)).is_true()
		assert_str(chooser.library.console_variants[pair[0]]).is_equal(pair[2])
		assert_array(device.variants_kept).is_equal([[pair[0], pair[2]]])
		assert_array(_closings).is_equal([false, false, true])
		_closings.clear()
		await await_idle_frame()
		chooser.free()


func test_INV_E6_01_a_seeded_walk_has_one_visible_focus_and_lands_on_the_expected_variant() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1201
	for pair: Array in [["ps2", "ps2_slim", 2], ["gba", "gba", 2], ["gc", "gc", 1]]:
		var platform: String = pair[0]
		var base: String = pair[1]
		var chooser := _chooser(platform, base)
		var expected := 0
		var total: int = pair[2]
		for i in 40:
			var right := random.randf() > 0.5
			expected = posmod(expected + (1 if right else -1), total)
			await Fixtures.action(self, &"ui_right" if right else &"ui_left")
			assert_str(chooser.counter()).is_equal("%d / %d" % [expected + 1, pair[2]])
			assert_object(get_viewport().gui_get_focus_owner()).is_equal(chooser._choice)
			assert_bool(chooser._choice.is_visible_in_tree()).is_true()
		await Fixtures.action(self, &"screen_back")
		await await_idle_frame()
		chooser.free()


func test_a_failed_save_can_be_retried_and_b_does_not_race_an_outstanding_save() -> void:
	var chooser := _chooser("ps2", "ps2_slim")
	var device := chooser.android as Fixtures.NewDevice
	device.slow = [&"set_variant"]
	await Fixtures.action(self, &"ui_right")
	await Fixtures.action(self, &"ui_accept")
	await Fixtures.action(self, &"screen_back")
	await Fixtures.action(self, &"ui_left")
	assert_bool(chooser.visible).is_true()
	assert_str(chooser.variant_id()).is_equal("ps2_fat")
	device.failing = [&"set_variant"]
	device.slow.clear()
	device.released.emit()
	assert_bool(await Fixtures.until(self, func() -> bool: return not chooser._saving)).is_true()
	assert_str(chooser._error.text).is_equal("This variant could not be kept.")
	assert_dict(device.console_variants).is_empty()
	assert_object(get_viewport().gui_get_focus_owner()).is_equal(chooser._choice)
	device.failing.clear()
	await Fixtures.action(self, &"ui_accept")
	assert_bool(await Fixtures.until(self, func() -> bool: return not chooser.visible)).is_true()
	assert_str(device.console_variants["ps2"]).is_equal("ps2_fat")
	await await_idle_frame()


func test_the_selected_manifest_supplies_its_scene_and_launch_and_can_return_to_the_base() -> void:
	var appearance := Appearance.read("res://data/carousel/appearance.json")
	var platform: AndroidServices.Platform
	for candidate in Android.catalog.platforms:
		if candidate.id == "ps2":
			platform = candidate
	var old := appearance.animation_of(platform, "ps2_dvd")
	appearance.use_variants({"ps2": "ps2_fat"})
	assert_str(appearance.console_of("ps2").model_name).is_equal("Fat")
	var model := appearance.console("ps2")
	assert_bool(model is Ps2FatModel).is_true()
	model.free()
	var changed := appearance.animation_of(platform, "ps2_dvd")
	assert_object(changed).is_not_equal(old)
	assert_int(changed.find_track(^"Consoles/ps2:tray_mm", Animation.TYPE_VALUE)).is_greater_equal(0)
	appearance.use_variants({})
	model = appearance.console("ps2")
	assert_bool(model is Ps2SlimModel).is_true()
	model.free()
