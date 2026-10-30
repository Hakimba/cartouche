# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")


func after_test() -> void:
	Controls.style = &"xbox"


func test_first_launch_saves_the_chosen_region_before_no_console_and_never_shows_a_reward() -> void:
	var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	device.curtain = true
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_initial_region(self, carousel, "Japan")
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(device.saved_regions).is_equal(["Japan"])
	assert_str(carousel._screens._preferred_region).is_equal("Japan")
	assert_bool(carousel._screens.get_node_or_null("Discovery") == null).is_true()
	device.first_launch = false
	var next := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, next, "NoConsole")).is_true()
	assert_bool(next._screens._region_screen.visible).is_false()
	assert_array(device.saved_regions).is_equal(["Japan"])


func test_a_failed_initial_region_save_keeps_the_choice_for_this_run_and_continues() -> void:
	var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	device.curtain = true
	device.failing.append(&"save_preferred_region")
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_initial_region(self, carousel, "Europe")
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(device.saved_regions).is_equal(["Europe"])
	assert_str(carousel._screens._preferred_region).is_equal("Europe")
	assert_array(device.saved_styles).is_equal([&"xbox"])


func test_adding_responds_before_a_slow_scan_and_the_first_console_arrives_without_a_ring() -> void:
	var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	device.slow.append(&"scan")
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(carousel._screens._pending.visible).is_true()
	assert_bool(carousel._shown).is_false()
	device.slow.clear()
	device.released.emit()
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_bool(carousel._order.is_open()).is_false()
	assert_array(device.placed).is_empty()
	assert_str(carousel._consoles.selected().folder).is_equal("ps2_slim")


func test_a_single_grid_row_has_no_vertical_neighbour_and_horizontal_moves_stop_at_its_ends() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 1, "gc": 1, "gba": 1})
	var screen: PlatformList = auto_free(preload("res://screens/platform_list.tscn").instantiate())
	add_child(screen)
	var platforms := device.catalog.platforms.filter(func(platform: AndroidServices.Platform) -> bool:
		return platform.id in device.consoles)
	screen.open(platforms, 0)
	for action: StringName in [&"ui_up", &"ui_down", &"ui_left"]:
		await Fixtures.action(self, action)
		assert_object(Fixtures.focus(self)).is_same(screen._rows.get_child(0))
	await Fixtures.action(self, &"ui_right")
	assert_object(Fixtures.focus(self)).is_same(screen._rows.get_child(1))
