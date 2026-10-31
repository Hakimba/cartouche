# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The settings over the consoles screen: the platforms set up, each to change or remove, and the
## button style.

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func after_test() -> void:
	Controls.style = &"xbox"
	Locale.apply("en")


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


func test_inv_13_removing_the_last_console_asks_first_then_leads_to_no_console_and_adding_one_again() -> void:
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


func test_inv_13_removing_one_of_two_consoles_lists_the_other_and_the_carousel_shows_it_alone() -> void:
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
	var page: CardChoiceScreen = carousel.get_node("%Screens/PreferredRegion")
	assert_bool(await Fixtures.on(self, carousel, "PreferredRegion")).is_true()
	assert_array(_card_texts(page)).is_equal(PackedStringArray(["None", "Europe", "North America", "Japan"]))
	await await_idle_frame()
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Japan")
	# The region chosen now is the one ticked.
	assert_int(page.find_children("*", "Control", true, false).filter(
		func(node: Node) -> bool: return node is CardChoiceScreen.Tick).size()).is_equal(1)
	assert_object(Fixtures.focus(self).get_child(0)).is_instanceof(CardChoiceScreen.Tick)
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


func test_the_language_line_scrolls_into_the_card_its_page_applies_a_choice_at_once_and_B_there_keeps_it() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _shown(device)
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	# Six lines show; the seventh scrolls in, and the first out of sight, unseen and untouchable.
	assert_float(menu._language.modulate.a).is_zero()
	for step in 6:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Language")
	assert_float(menu._language.modulate.a).is_equal(1.0)
	assert_float(menu._platforms.modulate.a).is_zero()
	assert_int(menu._platforms.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_str(_text(carousel, "Settings/%Language/%Value")).is_equal("Device language")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var page: CardChoiceScreen = carousel.get_node("%Screens/Language")
	assert_bool(await Fixtures.on(self, carousel, "Language")).is_true()
	assert_array(_card_texts(page)).is_equal(PackedStringArray(["Device language"] + Locale.NAMES.values()))
	await await_idle_frame()
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Device language")
	# B gives the page up: nothing saved, the settings open again on the line.
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_focused()).is_equal("Language")
	assert_array(device.saved_languages).is_empty()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await await_idle_frame()
	for step in 3:
		await Fixtures.action(self, &"ui_right")
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Deutsch")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.saved_languages.size() == 1)).is_true()
	assert_array(device.saved_languages).is_equal(["de"])
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(TranslationServer.get_locale()).is_equal("de")
	assert_str(_text(carousel, "Settings/%Language/%Value")).is_equal("Deutsch")
	assert_str(_focused()).is_equal("Language")


func test_with_no_console_the_card_shows_its_platforms_line_again_and_its_arrows_scroll_under_a_finger() -> void:
	var carousel := Fixtures.fresh_carousel(self, Fixtures.past_first_launch(self, {}))
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	for step in 5:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Language")
	assert_float(menu._platforms.modulate.a).is_zero()
	for step in 5:
		await Fixtures.action(self, &"ui_up")
	assert_str(_focused()).is_equal("ButtonStyle")
	# The platforms line cannot take the focus, yet shows with the line under it: no arrow leads nowhere.
	assert_float(menu._platforms.modulate.a).is_equal(1.0)
	assert_bool(menu._more(-1)).is_false()
	# A finger on the arrow below scrolls a line, the focus kept on a line shown.
	await _tap(menu, Vector2(menu._panel.size.x / 2.0, SettingsMenu._MORE_DOWN_Y))
	assert_float(menu._language.modulate.a).is_equal(1.0)
	assert_float(menu._platforms.modulate.a).is_zero()
	assert_float((Fixtures.focus(self) as Control).modulate.a).is_equal(1.0)
	await _tap(menu, Vector2(menu._panel.size.x / 2.0, SettingsMenu._MORE_UP_Y))
	assert_float(menu._platforms.modulate.a).is_equal(1.0)


## A finger down and up at [param at], in [param menu]'s card.
func _tap(menu: SettingsMenu, at: Vector2) -> void:
	await Fixtures.touch(self, [menu._panel.get_global_transform() * at])
	await await_idle_frame()


func test_a_language_the_plugin_does_not_save_is_not_applied() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.failing = [&"save_language"]
	var carousel := await _shown(device)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	for step in 6:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Language")).is_true()
	await await_idle_frame()
	var shown_in := TranslationServer.get_locale()
	for step in 2:
		await Fixtures.action(self, &"ui_right")
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Français")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.saved_languages.size() == 1)).is_true()
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(TranslationServer.get_locale()).is_equal(shown_in)
	assert_str(_text(carousel, "Settings/%Language/%Value")).is_equal("Device language")


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
	assert_array(_card_texts(carousel.get_node("%Screens/PreferredRegion") as CardChoiceScreen)).is_equal(PackedStringArray(["None",
		"Japan", "Korea"]))
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


func test_inv_20_on_every_settings_screen_exactly_one_control_of_it_has_the_focus() -> void:
	var random := CarouselFixtures.cases(62)
	var carousel := await _shown(Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2}))
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.wander(self, carousel, "Settings", random)
	for step in 6:
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


func test_B_closes_after_two_seconds_even_when_the_save_never_answers() -> void:
	var device: SlowFloatDevice = auto_free(SlowFloatDevice.new())
	device.first_launch = false
	device.curtain = true
	device.consoles = {"ps2": 3}
	var carousel := await _shown(device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	menu._save_started_ms -= SettingsMenu.SAVE_ESCAPE_MS
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
	menu._save_started_ms -= SettingsMenu.SAVE_ESCAPE_MS
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


func _card_texts(page: CardChoiceScreen) -> PackedStringArray:
	var texts := PackedStringArray()
	for card: Button in page._cards.get_children():
		texts.append(card.text)
	return texts
