# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")

var _window := Vector2i.ZERO


func before_test() -> void:
	_window = get_window().size
	get_window().size = Vector2i(1280, 960)


func after_test() -> void:
	get_window().size = _window
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



func test_the_platform_grid_shows_every_configured_logo_and_pad_walk_A_and_B_keep_the_existing_actions() -> void:
	var counts: Dictionary[String, int] = {}
	for platform: String in ["ps2", "psx", "nes", "snes", "n64", "gc", "wii", "xbox", "xbox360", "gb", "gbc", "gba"]:
		counts[platform] = 1
	var device := Fixtures.past_first_launch(self, counts)
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._screens._settings.state == SettingsMenu.State.OPEN)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	var screen := carousel._screens._platforms
	assert_int(screen._rows.get_child_count()).is_equal(12)
	var shown: Array[String] = []
	for tile: PlatformList.Tile in screen._rows.get_children():
		shown.append(tile.platform_id)
		assert_bool(tile.logo.texture.resource_path.contains("rail-tile/")).is_true()
		assert_bool(Rect2(0, 0, 1280, 960).encloses(tile.get_global_rect())).is_true()
	assert_array(shown).contains_exactly_in_any_order(counts.keys())
	var random := RandomNumberGenerator.new()
	random.seed = 120206
	var actions: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
	for press in 80:
		await Fixtures.action(self, actions[random.randi() % actions.size()])
		var focused := Fixtures.focus(self)
		assert_bool(focused is PlatformList.Tile and screen.is_ancestor_of(focused) and focused.is_visible_in_tree()).is_true()
	var selected := Fixtures.focus(self) as PlatformList.Tile
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(carousel._screens._add_console.platform_id).is_equal(selected.platform_id)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	var tapped := screen._rows.get_child(5) as PlatformList.Tile
	var tapped_id := tapped.platform_id
	await Fixtures.touch(self, [tapped.get_global_rect().get_center()])
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(carousel._screens._add_console.platform_id).is_equal(tapped_id)


func test_adding_responds_before_a_slow_scan_and_the_first_console_arrives_without_a_ring() -> void:
	var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	device.slow.append(&"scan")
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	var form := carousel._screens._add_console
	assert_vector(form._add._lead_size()).is_equal(Vector2.ZERO)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(form._away).is_true()
	assert_bool(carousel._screens._pending.visible).is_true()
	await get_tree().create_timer(0.35).timeout
	assert_float(form.modulate.a).is_less(0.01)
	assert_bool(carousel._shown).is_false()
	device.slow.clear()
	device.released.emit()
	var row := carousel._consoles
	assert_bool(await Fixtures.until(self, func() -> bool: return row.flier == row.selected_index())).is_true()
	assert_float(row.wheel).is_equal(1.0)
	var start := row.flier_stand.centre
	assert_vector(start).is_equal(Placing.PLINTH)
	var width := row.flier_stand.size
	assert_float(width).is_between(Placing.PLINTH_WIDTH / 100.0, 0.99)
	await get_tree().create_timer(0.15).timeout
	assert_bool(row.flier_stand.centre.is_equal_approx(start)).is_false()
	assert_float(row.flier_stand.size).is_greater(width)
	assert_bool(carousel._shown).is_false()
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_bool(carousel._order.is_open()).is_false()
	assert_array(device.placed).is_empty()
	assert_str(carousel._consoles.selected().folder).is_equal("ps2_slim")
	assert_float(carousel._consoles.wheel).is_equal(0.0)


func test_the_region_setting_draws_its_entire_label_without_an_ellipsis_in_both_languages() -> void:
	var menu: SettingsMenu = auto_free(preload("res://screens/settings_menu.tscn").instantiate())
	add_child(menu)
	var was := TranslationServer.get_locale()
	for language: String in ["en", "fr"]:
		TranslationServer.set_locale(language)
		var line := menu._row_name(menu._region)
		assert_str(line.text).is_equal(tr("Preferred region of images"))
		assert_int(line._shown).is_equal(line._line.glyphs.size())
		assert_float(line.width).is_less_equal(560.01)
	TranslationServer.set_locale(was)


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
