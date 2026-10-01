# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")


func after_test() -> void:
	TranslationServer.set_locale("en")


func _new_device() -> Fixtures.NewDevice:
	return auto_free(Fixtures.NewDevice.new())


func _form(carousel: Carousel, path: String) -> Control:
	return carousel.get_node("%Screens/AddConsole/" + path)


func _note(carousel: Carousel) -> String:
	return (_form(carousel, "%Note") as Label).text


## The focus is on the form, never nowhere.
func _assert_focus_on_form(carousel: Carousel) -> void:
	assert_object(Fixtures.focus(self)).is_not_null()
	assert_bool(Fixtures.shown_screen(carousel).is_ancestor_of(Fixtures.focus(self))).is_true()


func test_the_form_adds_nothing_until_a_folder_holds_compatible_games() -> void:
	var device := _new_device()
	device.games = 0
	var carousel := await Fixtures.on_form(self, device)
	var add: Button = _form(carousel, "%Add")
	assert_bool(add.disabled).is_true()
	assert_str(_note(carousel)).is_equal("Accepted files: .iso .chd .bin")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.previews.size() == 1)).is_true()
	assert_bool(add.disabled).is_true()
	assert_str(_note(carousel)).is_equal("No compatible game in this folder")
	await Fixtures.action(self, &"form_submit")
	assert_array(device.set_up).is_empty()
	assert_str(Fixtures.focus(self).name).is_equal("Folder")


func test_a_toggle_changed_counts_again_with_it() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.previews.size() == 1)).is_true()
	(_form(carousel, "%Discs") as CheckButton).button_pressed = false
	assert_bool(await Fixtures.until(self, func() -> bool: return device.previews.size() == 2)).is_true()
	assert_str(device.previews[1].disc_grouping).is_equal("separate")
	assert_str(device.previews[1].folder_depth).is_equal("subfolders")


func test_the_emulator_is_chosen_from_the_installed_ones_and_the_count_is_made_with_it() -> void:
	var device := _new_device()
	device.players.append({"player_id": "ps2.other", "player_name": "ps2 - Other", "emulator_name": "Other",
		"extensions": PackedStringArray(["iso"])})
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.action(self, &"ui_up")
	assert_str(Fixtures.focus(self).name).is_equal("Emulator")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, "Other")
	assert_str(_note(carousel)).is_equal("Accepted files: .iso")
	assert_str((_form(carousel, "%Emulator/%Value") as Label).text).is_equal("Other")
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return not device.previews.is_empty())).is_true()
	assert_str(device.previews[-1].player_id).is_equal("ps2.other")
	assert_str(device.previewed_platforms[-1]).is_equal("ps2")


func test_an_emulator_installed_meanwhile_is_there_back_in_the_app() -> void:
	var device := _new_device()
	var installed := device.players.duplicate()
	device.players.clear()
	var carousel := await Fixtures.on_form(self, device, false)
	await Fixtures.choose_type(self, carousel, device)
	assert_str(_note(carousel)).is_equal("Install an emulator for this console, then come back.")
	device.players.assign(installed)
	await Fixtures.resume(self)
	# There to choose now, not chosen for the user.
	assert_str((_form(carousel, "%Emulator/%Value") as Label).text).is_equal("Choose…")
	assert_str(_note(carousel)).is_empty()
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, "ARMSX2 (Refresh/GitHub)")
	assert_str((_form(carousel, "%Emulator/%Value") as Label).text).is_equal("ARMSX2 (Refresh/GitHub)")


func test_a_count_still_coming_for_a_form_given_up_does_not_count_for_the_form_opened_again() -> void:
	var device := _new_device()
	device.slow = [&"preview"]
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.previews.size() == 1)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	device.slow.clear()
	device.released.emit()
	await await_idle_frame()
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_true()
	assert_str(Fixtures.focus(self).name).is_equal("Type")


func test_while_the_console_is_being_added_going_back_does_nothing() -> void:
	var device := _new_device()
	device.slow = [&"scan"]
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.scans == 1)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.action(self, &"form_submit")
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("AddConsole")
	device.slow.clear()
	device.released.emit()
	assert_bool(await Fixtures.on(self, carousel, "Discovery")).is_true()
	assert_int(device.scans).is_equal(1)


func test_a_console_whose_scan_finds_no_game_is_not_shown_as_added_and_the_focus_stays_on_the_form() -> void:
	var device := _new_device()
	device.scanned_games = 0
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.scans == 1)).is_true()
	await await_idle_frame()
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("AddConsole")
	assert_str(_note(carousel)).is_equal("No compatible game in this folder")
	_assert_focus_on_form(carousel)
	assert_bool(carousel._shown).is_false()


func test_a_console_that_could_not_be_added_says_so_and_can_be_added_again() -> void:
	var device := _new_device()
	device.failing = [&"scan"]
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.scans == 1)).is_true()
	await await_idle_frame()
	assert_str(_note(carousel)).is_equal("The console could not be added.")
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_false()
	_assert_focus_on_form(carousel)
	device.failing.clear()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Discovery")).is_true()


func test_a_folder_reads_as_its_volume_then_its_folders_in_the_user_s_language() -> void:
	var on_card := AndroidServices.Folder.new({"uri": "content://t", "name": "ps2",
		"place": {"volume": "card", "folders": PackedStringArray(["ROMs", "ps2"])}})
	var internal := AndroidServices.Folder.new({"uri": "content://t", "name": "ROMs",
		"place": {"volume": "internal", "folders": PackedStringArray(["ROMs"])}})
	var volume := AndroidServices.Folder.new({"uri": "content://t", "name": "1A2B-3C4D",
		"place": {"volume": "card", "folders": PackedStringArray()}})
	var elsewhere := AndroidServices.Folder.new({"uri": "content://t", "name": "Games"})
	assert_str(AddConsole.folder_place(on_card)).is_equal("SD card › ROMs › ps2")
	assert_str(AddConsole.folder_place(elsewhere)).is_equal("Games")
	TranslationServer.set_locale("fr")
	assert_str(AddConsole.folder_place(on_card)).is_equal("Carte SD › ROMs › ps2")
	assert_str(AddConsole.folder_place(internal)).is_equal("Mémoire interne › ROMs")
	assert_str(AddConsole.folder_place(volume)).is_equal("Carte SD")
	assert_str(tr_n("{count} compatible game found", "{count} compatible games found", 55).format({"count": 55})) \
		.is_equal("55 jeux compatibles trouvés")


func test_any_platform_of_the_catalog_can_be_chosen_and_one_with_no_emulator_says_to_install_one() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.action(self, &"ui_up")
	await Fixtures.action(self, &"ui_up")
	assert_str(Fixtures.focus(self).name).is_equal("Type")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var items := _form(carousel, "%Choice/%Items")
	assert_int(items.get_child_count()).is_equal(device.catalog.platforms.size())
	await Fixtures.choose_in_list(self, carousel, "Nintendo - GameCube")
	assert_str(Fixtures.focus(self).name).is_equal("Type")
	assert_str((_form(carousel, "%Type/%Value") as Label).text).is_equal("Nintendo - GameCube")
	assert_str((_form(carousel, "%Emulator/%Value") as Label).text).is_equal("None installed")
	assert_str(_note(carousel)).is_equal("Install an emulator for this console, then come back.")
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_true()
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	assert_str(form.platform_id).is_equal("gc")


func test_the_type_list_given_up_changes_nothing() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.action(self, &"ui_up")
	await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return (_form(carousel, "%Choice") as Control).visible)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool((_form(carousel, "%Choice") as Control).visible).is_false()
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("AddConsole")
	assert_str(Fixtures.focus(self).name).is_equal("Type")
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	assert_str(form.platform_id).is_equal("ps2")


func test_the_type_list_opened_again_still_moves_with_the_controller() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.action(self, &"ui_up")
	await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, "Sony PSP")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return (_form(carousel, "%Choice") as Control).visible)).is_true()
	await await_idle_frame()
	var items := _form(carousel, "%Choice/%Items")
	assert_bool(items.is_ancestor_of(Fixtures.focus(self))).is_true()
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Sony PSP")
	await Fixtures.action(self, &"ui_down")
	assert_bool(items.is_ancestor_of(Fixtures.focus(self))).is_true()
	assert_str((Fixtures.focus(self) as Button).text).is_not_equal("Sony PSP")


func test_a_type_changed_after_a_count_greys_add_until_the_new_one_is_counted() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return not (_form(carousel, "%Add") as Button).disabled)).is_true()
	(_form(carousel, "%Type") as Control).grab_focus()
	await Fixtures.choose_type(self, carousel, device, "gc")
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_true()
	assert_str(_note(carousel)).is_equal("Install an emulator for this console, then come back.")
