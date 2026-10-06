# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The settings over the consoles screen: the platforms set up, each to change or remove, and the
## button style.

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func after_test() -> void:
	Controls.style = &"xbox"


## [param device]'s carousel, once it can be used.
func _shown(device: Fixtures.NewDevice) -> Carousel:
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return carousel


func _focused() -> String:
	return Fixtures.focus(self).name


func _text(carousel: Carousel, path: String) -> String:
	return carousel.get_node("%Screens/" + path).get(&"text")


func _name(device: Fixtures.NewDevice, platform_id: String) -> String:
	for platform in device.catalog.platforms:
		if platform.id == platform_id:
			return platform.name
	return ""


## From the consoles screen to the settings, then to the list of platforms.
func _to_list(carousel: Carousel) -> void:
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()


## From the list to the form editing the line [param line].
func _open(carousel: Carousel, line: int) -> void:
	for step in line:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()


## From the form to the confirmation, through "Remove".
func _ask_removal(carousel: Carousel) -> void:
	# Down the form: the last toggle leads to "Remove".
	for step in 6:
		await Fixtures.action(self, &"ui_down")
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Remove")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Confirm")).is_true()


## The confirmation answered "Remove".
func _confirm(carousel: Carousel) -> void:
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel).name != "Confirm")


## Saves the form once it can.
func _save(carousel: Carousel) -> void:
	assert_bool(await Fixtures.until(self, func() -> bool:
		return not (carousel.get_node("%Screens/AddConsole/%Add") as Button).disabled)).is_true()
	await Fixtures.action(self, &"form_submit")


## The names the list of platforms shows.
func _rows(carousel: Carousel) -> PackedStringArray:
	var names := PackedStringArray()
	for row: Control in carousel.get_node("%Screens/Platforms/%Rows").get_children():
		names.append((row.get_node("%Name") as Label).text)
	return names


func _focused_row() -> String:
	return (Fixtures.focus(self).get_node("%Name") as Label).text


## Whether the screens closed, the carousel taking the controller again.
func _closed(carousel: Carousel) -> bool:
	return await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)


## Whether the consoles show, and A opens the games.
func _usable(carousel: Carousel) -> bool:
	if not (carousel.get_node("%Consoles") as Node3D).visible:
		return false
	await Fixtures.joypad(self, JOY_BUTTON_A)
	return await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)


func test_INV_E6_03_removing_the_last_console_asks_first_then_leads_to_no_console_and_adding_one_again() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _shown(device)
	await _to_list(carousel)
	await _open(carousel, 0)
	assert_str(_text(carousel, "AddConsole/%Title")).is_equal("Edit the platform")
	assert_str(_text(carousel, "AddConsole/%Folder/%Value")).is_equal("SD card › ROMs › ps2")
	assert_str(_focused()).is_equal("Emulator")
	await _ask_removal(carousel)
	assert_str(_text(carousel, "Confirm/%Title")).is_equal("Remove %s?" % _name(device, "ps2"))
	assert_str(_text(carousel, "Confirm/%Text")).contains("Its 3 games").contains("SD card")
	# The focus starts on "Cancel": a second A does not remove.
	assert_str(_focused()).is_equal("Cancel")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Remove")
	assert_array(device.removed).is_empty()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Confirm")).is_true()
	await _confirm(carousel)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(device.removed).is_equal(["ps2"])
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_false()
	# Y still opens the settings, with no platform to open.
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	assert_bool((carousel.get_node("%Screens/Settings/%Platforms") as Button).disabled).is_true()
	assert_str(_focused()).is_equal("ButtonStyle")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	# Adding a console again: the form is new, then the console's discovery, then the carousel.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(_text(carousel, "AddConsole/%Title")).is_equal("Add a console")
	assert_str(_text(carousel, "AddConsole/%Cancel")).is_equal("Cancel")
	assert_str(_text(carousel, "AddConsole/%Folder/%Value")).is_equal("Choose…")
	assert_str(_text(carousel, "AddConsole/%Type/%Value")).is_equal("Choose…")
	assert_str(_text(carousel, "AddConsole/%Emulator/%Value")).is_equal("Choose…")
	await Fixtures.choose_console(self, carousel, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _focused() == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Discovery")).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool:
		return Fixtures.focus(self) != null and _focused() == "Continue")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(await _usable(carousel)).is_true()


func test_INV_E6_03_removing_one_of_two_consoles_lists_the_other_and_the_carousel_shows_it_alone() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	var carousel := await _shown(device)
	await _to_list(carousel)
	# Back from a line, the focus is on it.
	await _open(carousel, 1)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_str(_focused_row()).is_equal(_name(device, "ps2"))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await _ask_removal(carousel)
	await _confirm(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_array(device.removed).is_equal(["ps2"])
	assert_array(_rows(carousel)).is_equal([_name(device, "gba")])
	assert_str(_focused_row()).is_equal(_name(device, "gba"))
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	assert_str(_focused()).is_equal("Platforms")
	assert_str(_text(carousel, "Settings/%Platforms/%Value")).is_equal("1")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_int(carousel._shelves.size()).is_equal(1)
	assert_str(carousel._shelves[0].platform_id).is_equal("gba")
	assert_bool(await _usable(carousel)).is_true()


func test_a_console_that_could_not_be_removed_says_so_and_stays() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.failing = [&"remove"]
	var carousel := await _shown(device)
	await _to_list(carousel)
	await _open(carousel, 0)
	await _ask_removal(carousel)
	await _confirm(carousel)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(_text(carousel, "AddConsole/%Note")).is_equal("The console could not be removed.")
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Remove")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_array(_rows(carousel)).is_equal([_name(device, "ps2")])
	assert_int(carousel._shelves.size()).is_equal(1)


func test_the_platforms_list_in_catalog_order_and_B_goes_back_one_screen_at_a_time() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	var carousel := await _shown(device)
	await _to_list(carousel)
	assert_array(_rows(carousel)).is_equal([_name(device, "gba"), _name(device, "ps2")])
	await _open(carousel, 0)
	await _ask_removal(carousel)
	for screen: String in ["AddConsole", "Platforms", "Settings"]:
		await Fixtures.joypad(self, JOY_BUTTON_B)
		assert_bool(await Fixtures.on(self, carousel, screen)).is_true()
		assert_object(Fixtures.focus(self)).is_not_null()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_array(device.removed).is_empty()
	assert_int(device.scans).is_equal(0)


func test_the_form_shows_the_choices_stored_and_saving_stores_the_new_ones_and_scans_again() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.players.append({"player_id": "ps2.other", "player_name": "ps2 - Other", "emulator_name": "Other",
		"extensions": PackedStringArray(["iso"])})
	device.setups["ps2"] = {"folder_uri": "content://tree/card%3AROMs%2Fps2", "player_id": "ps2.other",
		"disc_grouping": "separate", "folder_depth": "top_level"}
	var carousel := await _shown(device)
	await _to_list(carousel)
	await _open(carousel, 0)
	assert_str(_text(carousel, "AddConsole/%Emulator/%Value")).is_equal("Other")
	assert_bool((carousel.get_node("%Screens/AddConsole/%Subfolders") as Button).button_pressed).is_false()
	assert_bool((carousel.get_node("%Screens/AddConsole/%Discs") as Button).button_pressed).is_false()
	# Back to the front, the emulator chosen stays.
	await Fixtures.resume(self)
	assert_str(_text(carousel, "AddConsole/%Emulator/%Value")).is_equal("Other")
	assert_str(_text(carousel, "AddConsole/%Add")).is_equal("Save")
	for step in 2:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Subfolders")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _save(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_str(device.set_up[-1].folder_depth).is_equal("subfolders")
	assert_str(device.set_up[-1].disc_grouping).is_equal("separate")
	assert_str(device.set_up[-1].player_id).is_equal("ps2.other")
	assert_str(device.set_up[-1].folder_uri).is_equal("content://tree/card%3AROMs%2Fps2")
	assert_int(device.scans).is_equal(1)
	assert_array(device.removed).is_empty()


func test_a_folder_whose_access_is_gone_still_shows_by_name_and_its_place_is_not_claimed() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.lost_folders = ["ps2"]
	var carousel := await _shown(device)
	await _to_list(carousel)
	await _open(carousel, 0)
	assert_str(_text(carousel, "AddConsole/%Folder/%Value")).is_equal("ps2")
	await _ask_removal(carousel)
	assert_str(_text(carousel, "Confirm/%Text")).contains("stay where they are")


func test_saving_another_type_adds_that_console_and_removes_the_one_edited_which_removing_names() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gc": 1})
	device.players_everywhere = true
	var carousel := await _shown(device)
	await _to_list(carousel)
	await _open(carousel, 1)
	await Fixtures.action(self, &"ui_up")
	assert_str(_focused()).is_equal("Type")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	# Another console set up cannot be taken over.
	var list: Control = carousel.get_node("%Screens/AddConsole/%Choice")
	assert_bool(await Fixtures.until(self, func() -> bool: return list.visible)).is_true()
	for item: Button in list.get_node("%Items").get_children():
		assert_str(item.text).is_not_equal(_name(device, "gc"))
	await Fixtures.choose_in_list(self, carousel, _name(device, "gba"))
	# Removing now still names the console edited.
	await _ask_removal(carousel)
	assert_str(_text(carousel, "Confirm/%Title")).is_equal("Remove %s?" % _name(device, "ps2"))
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	# Another type: its emulator is to choose again.
	assert_str(_text(carousel, "AddConsole/%Emulator/%Value")).is_equal("Choose…")
	(carousel.get_node("%Screens/AddConsole/%Emulator") as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, device.installed_players("gba")[0].emulator_name)
	await _save(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_array(device.removed).is_equal(["ps2"])
	assert_array(_rows(carousel)).is_equal([_name(device, "gba"), _name(device, "gc")])


func test_a_console_set_up_without_games_found_again_from_no_console_brings_the_carousel() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 0})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	assert_str(_text(carousel, "Settings/%Platforms/%Value")).is_equal("1")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	await _open(carousel, 0)
	await _save(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(await _usable(carousel)).is_true()


func test_emptied_then_given_games_again_in_the_same_settings_the_carousel_comes_back() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 0})
	device.players_everywhere = true
	var carousel := await _shown(device)
	await _to_list(carousel)
	await _open(carousel, 1)
	await _ask_removal(carousel)
	await _confirm(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_false()
	await _open(carousel, 0)
	await _save(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(await _usable(carousel)).is_true()


func test_the_button_style_changes_from_the_settings_and_B_there_keeps_it() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _shown(device)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("ButtonStyle")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	assert_str(_focused()).is_equal("Xbox")
	# A screen of its own: the carousel hides behind it, and shows again under the settings.
	var consoles: Node3D = carousel.get_node("%Consoles")
	assert_bool(consoles.visible).is_false()
	assert_bool((carousel.get_node("%ConsoleTitle") as Control).visible).is_false()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	assert_str(Controls.style).is_equal("xbox")
	assert_str(_focused()).is_equal("ButtonStyle")
	assert_bool(consoles.visible).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	assert_str(Controls.style).is_equal("nintendo")
	assert_array(device.saved_styles).is_equal([&"nintendo"])
	assert_str(_text(carousel, "Settings/%ButtonStyle/%Value")).is_equal("Nintendo")
	assert_str(_focused()).is_equal("ButtonStyle")


func test_Y_opens_the_settings_from_the_games_screen_too_and_B_goes_back_to_it() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null)).is_true()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	# The games screen whole again: the pill over the game, no console name.
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._pill.modulate.a == 1.0)).is_true()
	assert_float(carousel._console_title.modulate.a if carousel._console_title.visible else 0.0).is_equal(0.0)


func test_a_direction_held_as_the_settings_open_on_the_games_screen_moves_nothing_once_they_close() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 5}))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	await Fixtures.hold(self, &"carousel_right")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.hold(self, &"carousel_right", false)
	assert_bool(await Fixtures.on(self, carousel, "Settings")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null)).is_true()
	var selected := carousel._row.selected_index()
	for frame in 60:
		await await_idle_frame()
	assert_int(carousel._row.selected_index()).is_equal(selected)


func test_a_library_changed_in_the_settings_opened_on_the_games_screen_comes_back_on_the_consoles() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	var carousel := await _shown(device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	device.consoles.erase("gba")
	var library: Dictionary = JSON.parse_string(device._library())
	carousel._on_screens_library_edited(AndroidServices.Library.new(library))
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_float(carousel._sequence._at_s).is_equal(0.0)
	assert_bool(carousel._sequence.is_processing()).is_false()
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._console_title.modulate.a == 1.0)).is_true()
	# The consoles the library replaced are freed at the end of the frame.
	await await_idle_frame()


func test_INV_E6_01_on_every_settings_screen_exactly_one_control_of_it_has_the_focus() -> void:
	var random := CarouselFixtures.cases(62)
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2}))
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.wander(self, carousel, "Settings", random)
	for step in 2:
		await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "Platforms", random)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "AddConsole", random)
	for step in 8:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.action(self, &"ui_left")
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Remove")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "Confirm", random)
	for screen: String in ["AddConsole", "Platforms", "Settings"]:
		await Fixtures.joypad(self, JOY_BUTTON_B)
		assert_bool(await Fixtures.on(self, carousel, screen)).is_true()
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "ButtonStyle", random)
