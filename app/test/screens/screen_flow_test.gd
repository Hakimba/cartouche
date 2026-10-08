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


func test_INV_E6_05_a_fresh_install_goes_from_the_welcome_to_its_console_with_the_controller_alone() -> void:
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
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
	assert_bool(await Fixtures.on(self, carousel, "Discovery")).is_true()
	# It plays without a press: the app does not rest meanwhile.
	assert_bool(carousel._resting.moving.call()).is_true()
	# The discovery stays until "Continue" is there and pressed.
	for frame in 10:
		await await_idle_frame()
	assert_bool(carousel._shown).is_false()
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self) != null and Fixtures.focus(self).name == "Continue")).is_true()
	# Played, it waits for the press: the app may rest again.
	assert_bool(carousel._resting.moving.call()).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	var consoles: ConsoleRow = carousel.get_node("%Consoles")
	assert_bool(await Fixtures.until(self, func() -> bool: return consoles.arrival == 1.0)).is_true()
	var screens: ScreenFlow = carousel.get_node("%Screens")
	assert_bool(await Fixtures.until(self, func() -> bool: return not screens.visible)).is_true()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_bool((carousel.get_node("%Pill") as Control).visible).is_true()
	assert_bool((carousel.get_node("%TopBar") as Control).visible).is_true()
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


func test_INV_E6_05_an_app_already_set_up_opens_on_its_consoles_after_the_welcome() -> void:
	var device := _new_device()
	device.first_launch = false
	device.has_games = true
	var carousel := Fixtures.carousel_for(self, device)
	var seen := _shows(carousel)
	add_child(carousel)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_array(seen).is_empty()
	assert_array(device.saved_styles).is_empty()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


func test_INV_E6_05_past_the_first_launch_with_no_games_it_goes_to_no_console_without_asking_again() -> void:
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
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(seen).is_equal(["ButtonStyle", "NoConsole"])


func test_later_goes_on_without_opening_android_s_setting() -> void:
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
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
	assert_bool(await Fixtures.on(self, carousel, "Permission")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()


func test_coming_back_to_the_app_without_opening_the_setting_keeps_the_permission_screen() -> void:
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
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


func test_INV_E6_01_on_every_screen_where_something_is_chosen_exactly_one_control_of_it_has_the_focus() -> void:
	var random := CarouselFixtures.cases(61)
	var device := _new_device()
	var carousel := Fixtures.fresh_carousel(self, device)
	await Fixtures.wander(self, carousel, "ButtonStyle", random)
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
