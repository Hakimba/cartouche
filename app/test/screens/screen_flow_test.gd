# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func after_test() -> void:
	Controls.style = &"xbox"


func _new_device() -> Fixtures.NewDevice:
	return auto_free(Fixtures.NewDevice.new())


## Names of the screens [param carousel] shows after the welcome, in order, as they come.
func _shows(carousel: Carousel) -> Array[String]:
	var seen: Array[String] = []
	for screen: Control in carousel.get_node("%Screens").get_children():
		if screen.name != "Welcome":
			screen.visibility_changed.connect(func() -> void:
				if screen.visible:
					seen.append(screen.name))
	return seen


func test_a_fresh_install_goes_from_the_welcome_to_its_console_with_the_controller_alone() -> void:
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_initial_region(self, carousel)
	assert_bool(await Fixtures.on(self, carousel, "Permission")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(device.setting_opened).is_true()
	await Fixtures.resume(self)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_int(device.titles_prepared).is_equal(0)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	# What counting a folder's games needs is prepared as the form opens.
	assert_int(device.titles_prepared).is_equal(1)
	await Fixtures.choose_console(self, carousel, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_bool(carousel._consoles.visible).is_true()
	assert_bool(carousel.get_node("%Screens").get_node_or_null("Discovery") == null).is_true()
	assert_int(device.scans).is_equal(1)
	var added: AndroidServices.PlatformSetup = device.set_up[0]
	assert_str(added.folder_uri).is_equal("content://tree/card%3AROMs%2Fps2")
	assert_str(added.player_id).is_equal("ps2.armsx2")
	assert_str(added.folder_depth).is_equal("subfolders")
	assert_str(added.disc_grouping).is_equal("grouped")


func test_the_battery_shows_as_the_carousel_starts() -> void:
	var carousel := Fixtures.fresh_carousel(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	var chip: BatteryChip = carousel.get_node("%Battery")
	assert_str(chip.text).is_equal("99 %")
	assert_array(chip.bolt()).is_empty()


func test_an_app_already_set_up_opens_straight_on_its_consoles_the_welcome_never_shown() -> void:
	var device := _new_device()
	device.first_launch = false
	device.has_games = true
	var carousel := Fixtures.carousel_for(self, device)
	(carousel.get_node("%Screens") as ScreenFlow).welcome_waits = true
	var seen := _shows(carousel)
	add_child(carousel)
	var welcome: Welcome = carousel.get_node("%Screens/Welcome")
	var welcome_seen := [false]
	assert_bool(await Fixtures.until(self, func() -> bool:
		welcome_seen[0] = welcome_seen[0] or (is_instance_valid(welcome) and welcome.is_visible_in_tree())
		return carousel._shown)).is_true()
	assert_bool(welcome_seen[0]).is_false()
	assert_array(seen).is_empty()
	assert_array(device.saved_styles).is_empty()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


func test_past_the_first_launch_with_no_games_it_goes_to_no_console_without_asking_again() -> void:
	var device := _new_device()
	device.first_launch = false
	var carousel := Fixtures.carousel_for(self, device)
	var seen := _shows(carousel)
	add_child(carousel)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(seen).is_equal(["NoConsole"])


func test_the_curtain_permission_is_not_asked_when_android_already_allows_it() -> void:
	var device := _new_device()
	device.curtain = true
	var carousel := Fixtures.carousel_for(self, device)
	var seen := _shows(carousel)
	add_child(carousel)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_initial_region(self, carousel)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(seen).is_equal(["ButtonStyle", "PreferredRegion", "NoConsole"])


func test_later_goes_on_without_opening_android_s_setting() -> void:
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_initial_region(self, carousel)
	assert_bool(await Fixtures.on(self, carousel, "Permission")).is_true()
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_bool(device.setting_opened).is_false()


func test_a_setting_android_cannot_open_lets_the_user_go_on() -> void:
	var device := _new_device()
	device.failing = [&"curtain"]
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_initial_region(self, carousel)
	assert_bool(await Fixtures.on(self, carousel, "Permission")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()


func test_coming_back_to_the_app_without_opening_the_setting_keeps_the_permission_screen() -> void:
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_initial_region(self, carousel)
	assert_bool(await Fixtures.on(self, carousel, "Permission")).is_true()
	await Fixtures.resume(self)
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("Permission")


func test_the_welcome_stays_until_a_button_and_that_press_chooses_no_style() -> void:
	var device := _new_device()
	var carousel: Carousel = auto_free(Fixtures.CAROUSEL.instantiate())
	carousel.android = device
	add_child(carousel)
	for frame in 30:
		await await_idle_frame()
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("Welcome")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	assert_array(device.saved_styles).is_empty()


func test_inv_20_on_every_screen_where_something_is_chosen_exactly_one_control_of_it_has_the_focus() -> void:
	var random := CarouselFixtures.cases(61)
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	await Fixtures.wander(self, carousel, "ButtonStyle", random)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "PreferredRegion", random)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "Permission", random)
	await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.resume(self)
	await Fixtures.wander(self, carousel, "NoConsole", random)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "AddConsole", random)
	# Back from the form, the focus is on the button that opened it.
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_str(Fixtures.focus(self).name).is_equal("Add")


func test_the_floating_setting_survives_closing_and_a_new_carousel() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await Fixtures.until(self,
		func() -> bool: return menu.is_visible_in_tree() and menu.state == SettingsMenu.State.OPEN)).is_true()
	for step in 3:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(device.games_float).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_bool(carousel._row.games_float).is_true()
	remove_child(carousel)
	carousel.queue_free()
	await await_idle_frame()
	var restarted := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return restarted._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	var reopened: SettingsMenu = restarted.get_node("%Screens/Settings")
	assert_bool(await Fixtures.until(self,
		func() -> bool: return reopened.is_visible_in_tree() and reopened.state == SettingsMenu.State.OPEN)).is_true()
	assert_bool(reopened.games_float).is_true()
	assert_array(device.saved_floats).is_equal([true])


func test_the_region_cards_follow_the_focus_whole_in_view_to_the_last_and_back() -> void:
	var device := _new_device()
	device.preferred_regions = PackedStringArray(["Europe", "North America", "Japan", "France", "Germany", "United Kingdom",
		"Spain", "Italy", "Netherlands", "Australia", "Brazil", "Korea", "China", "Taiwan", "World"])
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "PreferredRegion")).is_true()
	var cards: Array[Node] = (carousel.get_node("%Screens/PreferredRegion") as PreferredRegionScreen)._cards.get_children()
	for move: StringName in [&"ui_right", &"ui_left"]:
		for step in cards.size() - 1:
			await Fixtures.action(self, move)
			assert_bool(Fixtures.in_view(Fixtures.focus(self))).is_true()
		assert_object(Fixtures.focus(self)).is_same(cards[-1] if move == &"ui_right" else cards[0])
