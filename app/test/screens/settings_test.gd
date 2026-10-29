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


func _settings_ready(carousel: Carousel) -> bool:
	return await Fixtures.until(self, func() -> bool:
		var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
		return menu.is_visible_in_tree() and menu.state == SettingsMenu.State.OPEN)


func _focused() -> String:
	return Fixtures.focus(self).name


func _text(carousel: Carousel, path: String) -> String:
	return carousel.get_node("%Screens/" + path).get(&"text")


## From the consoles screen to the settings, then to the list of platforms.
func _to_list(carousel: Carousel) -> void:
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()


## From the list to the form editing the line [param line].
func _open(carousel: Carousel, line: int) -> void:
	(carousel._screens._platforms._rows.get_child(line) as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()


## From the form to the confirmation, through "Remove".
func _ask_removal(carousel: Carousel) -> void:
	# Down the form to the buttons (to "Save" when games are found), then left to "Remove".
	for step in 6:
		await Fixtures.action(self, &"ui_down")
		if _focused() in ["Cancel", "Add"]:
			break
	await Fixtures.action(self, &"ui_left")
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
	(carousel.get_node("%Screens/AddConsole/%Add") as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)


## The names the list of platforms shows.
func _rows(carousel: Carousel) -> PackedStringArray:
	var names := PackedStringArray()
	for row: Control in carousel.get_node("%Screens/Platforms/%Rows").get_children():
		names.append((row as Button).text)
	return names


func _focused_row() -> String:
	return (Fixtures.focus(self) as Button).text


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
	assert_str(_text(carousel, "AddConsole/%Folder")).is_equal("SD card › ROMs › ps2")
	assert_str(_focused()).is_equal("Emulator")
	await _ask_removal(carousel)
	assert_str(_text(carousel, "Confirm/%Title")).is_equal("Remove %s?" % Fixtures.platform_name(device, "ps2"))
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
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool((carousel.get_node("%Screens/Settings/%Platforms") as Button).disabled).is_true()
	assert_str(_focused()).is_equal("ButtonStyle")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	# Adding a console again uses the form and arrives directly on the carousel.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(_text(carousel, "AddConsole/%Title")).is_equal("Add a console")
	assert_str(_text(carousel, "AddConsole/%Cancel")).is_equal("Cancel")
	assert_str(_text(carousel, "AddConsole/%Folder")).is_equal("Choose…")
	assert_str(_text(carousel, "AddConsole/%Type")).is_equal("Choose…")
	assert_str(_text(carousel, "AddConsole/%Emulator")).is_equal("Choose…")
	await Fixtures.choose_console(self, carousel, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _focused() == "Add")).is_true()
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
	assert_str(_focused_row()).is_equal(Fixtures.platform_name(device, "ps2"))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await _ask_removal(carousel)
	await _confirm(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_array(device.removed).is_equal(["ps2"])
	assert_array(_rows(carousel)).is_equal([Fixtures.platform_name(device, "gba")])
	assert_str(_focused_row()).is_equal(Fixtures.platform_name(device, "gba"))
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
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
	assert_array(_rows(carousel)).is_equal([Fixtures.platform_name(device, "ps2")])
	assert_int(carousel._shelves.size()).is_equal(1)


func test_what_a_form_counts_games_with_is_prepared_as_the_settings_open_never_at_start() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _shown(device)
	assert_int(device.titles_prepared).is_equal(0)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	# Before any form: the one editing a platform counts its games as it opens.
	assert_int(device.titles_prepared).is_equal(1)


func test_the_platforms_list_in_catalog_order_and_B_goes_back_one_screen_at_a_time() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	var carousel := await _shown(device)
	await _to_list(carousel)
	assert_array(_rows(carousel)).is_equal([Fixtures.platform_name(device, "gba"), Fixtures.platform_name(device, "ps2")])
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
	assert_str(_text(carousel, "AddConsole/%Emulator")).is_equal("Other")
	assert_bool((carousel.get_node("%Screens/AddConsole/%Subfolders") as Button).button_pressed).is_false()
	assert_bool((carousel.get_node("%Screens/AddConsole/%Discs") as Button).button_pressed).is_false()
	# Back to the front, the emulator chosen stays.
	await Fixtures.resume(self)
	assert_str(_text(carousel, "AddConsole/%Emulator")).is_equal("Other")
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
	assert_str(_text(carousel, "AddConsole/%Folder")).is_equal("ps2")
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
	var list: StudioChooser = carousel.get_node("%Screens/AddConsole/%Choice")
	assert_bool(await Fixtures.until(self, func() -> bool: return list.visible)).is_true()
	assert_array(Array(list.ids())).not_contains(["gc"])
	await Fixtures.choose_in_list(self, carousel, "gba")
	# Removing now still names the console edited.
	await _ask_removal(carousel)
	assert_str(_text(carousel, "Confirm/%Title")).is_equal("Remove %s?" % Fixtures.platform_name(device, "ps2"))
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	# Another type: its emulator is to choose again.
	assert_str(_text(carousel, "AddConsole/%Emulator")).is_equal("Choose…")
	(carousel.get_node("%Screens/AddConsole/%Emulator") as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, device.installed_players("gba")[0].id)
	await _save(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	assert_array(device.removed).is_equal(["ps2"])
	assert_array(_rows(carousel)).is_equal([Fixtures.platform_name(device, "gba"), Fixtures.platform_name(device, "gc")])


func test_a_console_set_up_without_games_found_again_from_no_console_brings_the_carousel() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 0})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
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
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("ButtonStyle")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	assert_str(_focused()).is_equal("Xbox")
	# A screen of its own, as the settings: the carousel stays hidden under both (the screens in front cover it).
	var consoles: Node3D = carousel.get_node("%Consoles")
	assert_bool(consoles.visible).is_false()
	assert_bool((carousel.get_node("%ConsoleTitle") as Control).visible).is_false()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(Controls.style).is_equal("xbox")
	assert_str(_focused()).is_equal("ButtonStyle")
	assert_bool(consoles.visible).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(Controls.style).is_equal("nintendo")
	assert_array(device.saved_styles).is_equal([&"nintendo"])
	assert_str(_text(carousel, "Settings/%ButtonStyle/%Value")).is_equal("Nintendo")
	assert_str(_focused()).is_equal("ButtonStyle")


func test_the_preferred_region_is_chosen_on_its_page_from_the_settings_saved_once_changed_and_B_there_keeps_it() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.preferred_region = "Japan"
	var carousel := await _shown(device)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_text(carousel, "Settings/%Region/%Value")).is_equal("Japan")
	for step in 4:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Region")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var page: PreferredRegionScreen = carousel.get_node("%Screens/PreferredRegion")
	assert_bool(await Fixtures.on(self, carousel, "PreferredRegion")).is_true()
	assert_array(_card_texts(page)).is_equal(PackedStringArray(["None", "Europe", "North America", "Japan"]))
	await await_idle_frame()
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Japan")
	# The region chosen now is the one ticked.
	assert_int(page.find_children("*", "Control", true, false).filter(
		func(node: Node) -> bool: return node is PreferredRegionScreen.Tick).size()).is_equal(1)
	assert_object(Fixtures.focus(self).get_child(0)).is_instanceof(PreferredRegionScreen.Tick)
	# B gives the page up: nothing saved, the settings open again on the line.
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_focused()).is_equal("Region")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await await_idle_frame()
	for step in 3:
		await Fixtures.action(self, &"ui_left")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.saved_regions.size() == 1)).is_true()
	assert_array(device.saved_regions).is_equal([""])
	assert_str(_text(carousel, "Settings/%Region/%Value")).is_equal("None")
	assert_str(_focused()).is_equal("Region")
	# The same region again saves nothing.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await await_idle_frame()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_array(device.saved_regions).is_equal([""])


func test_the_regions_offered_are_those_the_plugin_takes_and_one_it_refuses_is_not_shown_chosen() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.preferred_regions = PackedStringArray(["Japan", "Korea"])
	device.failing = [&"save_preferred_region"]
	var carousel := await _shown(device)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	for step in 4:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "PreferredRegion")).is_true()
	assert_array(_card_texts(carousel.get_node("%Screens/PreferredRegion") as PreferredRegionScreen)).is_equal(PackedStringArray(["None", "Japan", "Korea"]))
	await await_idle_frame()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.saved_regions.size() == 1)).is_true()
	assert_array(device.saved_regions).is_equal(["Japan"])
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_text(carousel, "Settings/%Region/%Value")).is_equal("None")


func test_Y_opens_the_settings_from_the_games_screen_too_and_B_goes_back_to_it() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
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
	assert_bool(await _settings_ready(carousel)).is_true()
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
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.wander(self, carousel, "Settings", random)
	for step in 4:
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


## What the carousel draws of its own, besides its background and the top bar: its games, its
## consoles, the console's name, the pill, the games' hints, a message, the art's bar, and the
## consoles blurred behind the games.
func _drawn(carousel: Carousel) -> Array[bool]:
	return [carousel._row.visible, carousel._consoles.visible, carousel._console_title.visible, carousel._pill.visible,
		carousel._games_hints.visible, carousel._message.visible, carousel._art_progress.visible, carousel._sequence.layer.visible]


## Under the screens in front: nothing of the carousel's own, its top bar still there, and the app
## free to rest.
func _assert_covered(carousel: Carousel) -> void:
	assert_array(_drawn(carousel)).is_equal([false, false, false, false, false, false, false, false])
	assert_bool(carousel._top_bar.visible).is_true()
	assert_bool(carousel._resting.moving.call()).is_false()


func test_under_the_settings_and_the_forms_the_carousel_draws_only_its_background_then_shows_as_it_was() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2}))
	# Once the consoles and their name have come in.
	assert_bool(await Fixtures.until(self, func() -> bool:
		return not get_tree().get_processed_tweens().any(func(tween: Tween) -> bool: return tween.is_running()))).is_true()
	var whole := _drawn(carousel)
	var title_alpha := carousel._console_title.modulate.a
	# A message about to stay four seconds: it goes with the carousel.
	carousel._show_message("Message")
	await _to_list(carousel)
	assert_bool(await Fixtures.on(self, carousel, "Platforms")).is_true()
	_assert_covered(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	_assert_covered(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_array(_drawn(carousel)).is_equal(whole)
	# As it was: the consoles do not come in again.
	assert_float(carousel._consoles.arrival).is_equal(1.0)
	assert_float(carousel._console_title.modulate.a).is_equal(title_alpha)
	# The form adding one more console, from the "+" above the consoles.
	await Fixtures.open_add_console(self, carousel)
	# The consoles stay under the form as it comes in, then go.
	assert_bool(await Fixtures.until(self, func() -> bool: return not carousel._consoles.visible)).is_true()
	_assert_covered(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_array(_drawn(carousel)).is_equal(whole)
	assert_float(carousel._consoles.arrival).is_equal(1.0)
	# On the PS2's games screen, its consoles shown behind the games: under the settings, gone at once,
	# and still gone once they close.
	for step in 2:
		if carousel._shelves[carousel._shelf].platform_id != "ps2":
			await Fixtures.action(self, &"carousel_right")
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("ps2")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()
	# Held there, rather than left to fade by themselves.
	carousel.set_process(false)
	carousel._sequence.behind_amount = 1.0
	assert_bool(carousel._sequence.layer.visible).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	_assert_covered(carousel)
	carousel.set_process(true)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	assert_array(_drawn(carousel)).is_equal([true, true, true, true, true, false, false, false])


class FailedFloatDevice extends Fixtures.NewDevice:
	func save_games_float(floating: bool) -> AndroidServices.Result:
		saved_floats.append(floating)
		return AndroidServices.Result.new({"ok": false, "code": "write_failed", "detail": "Settings unavailable"})


func _float_row(carousel: Carousel) -> SettingsMenu:
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	for step in 3:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("GamesFloat")
	return carousel.get_node("%Screens/Settings")


func test_floating_is_off_by_default_saved_on_A_and_keeps_one_focus() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _shown(device)
	var menu := await _float_row(carousel)
	assert_bool(menu.games_float).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.saved_floats.size() == 1)).is_true()
	assert_array(device.saved_floats).is_equal([true])
	assert_bool(menu.games_float).is_true()
	assert_str(_focused()).is_equal("GamesFloat")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saved_floats).is_equal([true, false])
	assert_bool(menu.games_float).is_false()
	assert_str(_focused()).is_equal("GamesFloat")


func test_a_failed_float_save_restores_the_stored_switch_and_focus() -> void:
	var device: FailedFloatDevice = auto_free(FailedFloatDevice.new())
	device.first_launch = false
	device.curtain = true
	device.consoles = {"ps2": 3}
	device.games_float = true
	var menu := await _float_row(await _shown(device))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saved_floats).is_equal([false])
	assert_bool(menu.games_float).is_true()
	assert_bool(device.games_float).is_true()
	assert_str(_focused()).is_equal("GamesFloat")


func test_settings_navigation_clamps_at_both_ends_and_ends_on_the_sounds_row() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3}))
	await _float_row(carousel)
	for step in 8:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Sounds")
	for step in 8:
		await Fixtures.action(self, &"ui_up")
	assert_str(_focused()).is_equal("Platforms")


func test_settings_transition_reverses_from_the_current_sample_without_jumping() -> void:
	var menu: SettingsMenu = auto_free(preload("res://screens/settings_menu.tscn").instantiate())
	add_child(menu)
	menu.open(1, &"platforms", "")
	menu.enter()
	menu._process(0.1)
	menu._process(0.08)
	var shown := menu.get_node("Panel") as Control
	var previous_position := shown.position
	var alpha := shown.modulate.a
	menu._reverse(false)
	menu._process(0.0)
	assert_bool(shown.position.is_equal_approx(previous_position)).is_true()
	assert_bool(is_equal_approx(shown.modulate.a, alpha)).is_true()
	menu._process(0.1)
	menu._reverse(true)
	for step in 4:
		menu._process(0.1)
	assert_int(menu.state).is_equal(SettingsMenu.State.OPEN)
	menu._reverse(false)
	menu._process(0.1)
	previous_position = shown.position
	menu._reverse(true)
	menu._process(0.0)
	assert_bool(shown.position.is_equal_approx(previous_position)).is_true()
	menu._process(0.1)
	assert_int(menu.state).is_equal(SettingsMenu.State.OPEN)


class SlowFloatDevice extends Fixtures.NewDevice:
	func save_games_float(floating: bool) -> AndroidServices.Result:
		saved_floats.append(floating)
		await released
		games_float = floating
		return AndroidServices.Result.new({"ok": true})


func test_while_a_float_save_is_pending_presses_do_not_start_another_save_or_leave() -> void:
	var device: SlowFloatDevice = auto_free(SlowFloatDevice.new())
	device.first_launch = false
	device.curtain = true
	device.consoles = {"ps2": 3}
	var carousel := await _shown(device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(menu.games_float).is_true()
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B]:
		await Fixtures.joypad(self, button)
	await Fixtures.action(self, &"ui_down")
	assert_array(device.saved_floats).is_equal([true])
	assert_bool(menu.is_visible_in_tree()).is_true()
	assert_int(menu.state).is_equal(SettingsMenu.State.OPEN)
	assert_str(_focused()).is_equal("GamesFloat")
	device.released.emit()
	assert_bool(await Fixtures.until(self, func() -> bool: return not menu.saving)).is_true()
	assert_bool(menu.games_float).is_true()
	assert_bool(device.games_float).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()


func test_a_slow_frame_stretches_the_settings_transition_to_at_most_100_ms() -> void:
	var menu: SettingsMenu = auto_free(preload("res://screens/settings_menu.tscn").instantiate())
	add_child(menu)
	menu.open(1, &"platforms", "")
	menu.enter()
	menu._process(1.0)
	assert_int(menu.state).is_equal(SettingsMenu.State.OPENING)
	assert_float((menu.get_node("Panel") as Control).modulate.a).is_equal(0.0)
	for step in 3:
		menu._process(0.1)
	assert_int(menu.state).is_equal(SettingsMenu.State.OPEN)
	assert_float((menu.get_node("Panel") as Control).modulate.a).is_equal(1.0)


func test_settings_without_a_platform_clamp_on_button_style_and_can_open_again() -> void:
	var device := Fixtures.past_first_launch(self, {})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	for opening in 2:
		await Fixtures.joypad(self, JOY_BUTTON_Y)
		assert_bool(await _settings_ready(carousel)).is_true()
		assert_str(_focused()).is_equal("ButtonStyle")
		await Fixtures.action(self, &"ui_up")
		assert_str(_focused()).is_equal("ButtonStyle")
		await Fixtures.joypad(self, JOY_BUTTON_B)
		assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()


func test_the_graphics_row_keeps_its_existing_screen_and_four_times_default() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_int(carousel.get_viewport().msaa_3d).is_equal(Viewport.MSAA_4X)
	for step in 2:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "EdgeSmoothing")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_focused()).is_equal("Graphics")
	assert_int(carousel.get_viewport().msaa_3d).is_equal(Viewport.MSAA_4X)


class SlowSettingsDevice extends Fixtures.NewDevice:
	var reads := 0
	var waiting := false

	func settings() -> AndroidServices.SettingsAnswer:
		reads += 1
		if reads > 1:
			waiting = true
			await released
		return await super.settings()


func test_the_settings_clock_starts_on_the_frame_after_the_press_with_a_slow_plugin() -> void:
	var device: SlowSettingsDevice = auto_free(SlowSettingsDevice.new())
	device.first_launch = false
	device.curtain = true
	device.consoles = {"ps2": 3}
	device.games_float = true
	var carousel := await _shown(device)
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_Y
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().process_frame
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(menu.is_visible_in_tree()).is_true()
	assert_bool(menu.is_processing()).is_true()
	assert_int(device.reads).is_equal(1)
	assert_bool(menu.games_float).is_true()
	assert_float(menu._knob_x).is_equal(38.4)
	press.pressed = false
	Input.parse_input_event(press)
	assert_bool(await _settings_ready(carousel)).is_true()


func test_opening_settings_during_arrival_resumes_the_remaining_title_fade_on_return() -> void:
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3}))
	carousel._title_fade.kill()
	carousel._console_title.modulate.a = 0.25
	carousel._title_fade = carousel.create_tween()
	carousel._title_fade.tween_property(carousel._console_title, ^"modulate:a", 1.0, 0.7)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool:
		return is_equal_approx(carousel._console_title.modulate.a, 1.0))).is_true()


func test_B_closes_after_two_seconds_even_when_the_save_never_answers() -> void:
	var device: SlowFloatDevice = auto_free(SlowFloatDevice.new())
	device.first_launch = false
	device.curtain = true
	device.consoles = {"ps2": 3}
	var carousel := await _shown(device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await get_tree().create_timer(2.05).timeout
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(menu.games_float).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(menu.games_float).is_false()
	assert_bool(menu.saving).is_false()


func test_a_late_success_after_closing_does_not_change_the_hidden_switch_or_its_confirmed_value() -> void:
	var device: SlowFloatDevice = auto_free(SlowFloatDevice.new())
	device.first_launch = false
	device.curtain = true
	device.consoles = {"ps2": 3}
	var carousel := await _shown(device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await get_tree().create_timer(2.05).timeout
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	var knob := menu._knob_x
	device.released.emit()
	assert_bool(carousel._screens._games_float).is_false()
	assert_bool(menu.games_float).is_false()
	assert_float(menu._knob_x).is_equal(knob)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(menu.games_float).is_false()
	assert_bool(device.games_float).is_true()


func test_stored_switch_values_snap_but_toggle_and_rollback_animate() -> void:
	var menu: SettingsMenu = auto_free(preload("res://screens/settings_menu.tscn").instantiate())
	add_child(menu)
	menu.games_float = true
	assert_float(menu._knob_x).is_equal(38.4)
	menu.games_float = false
	assert_float(menu._knob_x).is_equal(0.0)
	menu.animate_float(true)
	assert_float(menu._knob_x).is_equal(0.0)
	var moving := menu._switch_tween
	menu.games_float = true
	assert_bool(menu._switch_tween == moving).is_true()
	await get_tree().create_timer(0.25).timeout
	assert_bool(is_equal_approx(menu._knob_x, 38.4)).is_true()
	menu.animate_float(false)
	assert_bool(is_equal_approx(menu._knob_x, 38.4)).is_true()
	await get_tree().create_timer(0.25).timeout
	assert_bool(is_zero_approx(menu._knob_x)).is_true()


func test_card_dim_and_hints_follow_the_specified_intervals_and_curves() -> void:
	var menu: SettingsMenu = auto_free(preload("res://screens/settings_menu.tscn").instantiate())
	add_child(menu)
	# Each interval is sampled independently, including the overshoot of ARRIVE.
	var tracks := [
		[false, "Panel", 0.12, 0.24, Motion.Easing.ARRIVE],
		[false, "Dim", 0.08, 0.2, Motion.Easing.EASE_OUT],
		[false, "Hints", 0.21, 0.15, Motion.Easing.LINEAR],
		[true, "Panel", 0.0, 0.18, Motion.Easing.EASE_IN],
		[true, "Dim", 0.06, 0.2, Motion.Easing.EASE_IN],
		[true, "Hints", 0.0, 0.12, Motion.Easing.LINEAR],
	]
	for track: Array in tracks:
		menu._closing = track[0]
		for fraction: float in [0.25, 0.5, 0.75]:
			menu._time = track[2] + fraction * track[3]
			menu._sample()
			var curve: Motion.Easing = track[4]
			var amount := Motion.eased(curve, fraction)
			var expected := 1.0 - amount if track[0] else amount
			var node := menu.get_node(NodePath(str(track[1]))) as Control
			assert_bool(is_equal_approx(node.modulate.a, expected)).is_true()
			if track[1] == "Panel":
				var hidden := 1.0 - expected
				assert_bool(is_equal_approx(node.position.y, SettingsMenu._CARD_TOP + hidden * (25.6 if track[0] else 38.4))).is_true()
				assert_bool(is_equal_approx(node.scale.x, lerpf(1.0, 0.98 if track[0] else 0.97, hidden))).is_true()


func _card_texts(page: PreferredRegionScreen) -> PackedStringArray:
	var texts := PackedStringArray()
	for card: Button in page._cards.get_children():
		texts.append(card.text)
	return texts
