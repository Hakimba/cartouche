# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## X on the ring: the console selected edited in the form adding one, its type locked, its model chosen among its
## swatches, saved, given up or removed.

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func _text(carousel: Carousel, path: String) -> String:
	return carousel.get_node("%Screens/" + path).get(&"text")


func _focused() -> String:
	return Fixtures.focus(self).name


## [param device]'s carousel once it can be used, its selected console edited.
func _edit(device: Fixtures.NewDevice) -> Carousel:
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(_text(carousel, "AddConsole/%Title")).is_equal("Edit")
	return carousel


## The platform the ring shows.
func _selected(carousel: Carousel) -> String:
	return carousel._shelves[carousel._shelf].platform_id


## From the form to the confirmation, through "Remove", alone at the left of the pills.
func _ask_removal(carousel: Carousel) -> void:
	for step in 8:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.action(self, &"ui_left")
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Remove")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Confirm")).is_true()


## The confirmation answered "Remove".
func _confirm(carousel: Carousel) -> void:
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.until(self, func() -> bool:
		return Fixtures.shown_screen(carousel) == null or Fixtures.shown_screen(carousel).name != "Confirm")


## Saves the form once it can.
func _save(carousel: Carousel) -> void:
	assert_bool(await Fixtures.until(self, func() -> bool:
		return not (carousel.get_node("%Screens/AddConsole/%Add") as Button).disabled)).is_true()
	(carousel.get_node("%Screens/AddConsole/%Add") as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)


## From the emulator to the model line, then into its swatches.
func _open_models(carousel: Carousel) -> ModelSwatches:
	for step in 2:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Model")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	var swatches: ModelSwatches = carousel.get_node("%Screens/AddConsole/%Models")
	assert_bool(swatches.is_open()).is_true()
	return swatches


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
	var carousel := await _edit(device)
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
	# Adding a console again uses the same form, as new, and arrives directly on the carousel.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(_text(carousel, "AddConsole/%Title")).is_equal("Add a console")
	assert_str(_text(carousel, "AddConsole/%Cancel")).is_equal("Cancel")
	assert_str(_text(carousel, "AddConsole/%Type")).is_equal("Choose…")
	await Fixtures.choose_console(self, carousel, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _focused() == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(await _usable(carousel)).is_true()


func test_inv_13_removing_one_of_two_consoles_leaves_the_ring_on_the_other_alone() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	var carousel := await _edit(device)
	var edited := _selected(carousel)
	await _ask_removal(carousel)
	await _confirm(carousel)
	assert_bool(await _closed(carousel)).is_true()
	assert_array(device.removed).is_equal([edited])
	assert_int(carousel._shelves.size()).is_equal(1)
	assert_str(_selected(carousel)).is_not_equal(edited)
	assert_bool(await _usable(carousel)).is_true()


func test_a_console_that_could_not_be_removed_says_so_and_stays() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.failing = [&"remove"]
	var carousel := await _edit(device)
	await _ask_removal(carousel)
	await _confirm(carousel)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(_text(carousel, "AddConsole/%Note")).is_equal("The console could not be removed.")
	assert_str((Fixtures.focus(self) as Button).text).is_equal("Remove")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_int(carousel._shelves.size()).is_equal(1)


func test_B_goes_back_one_screen_at_a_time_and_saves_nothing() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	var carousel := await _edit(device)
	await _ask_removal(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_array(device.removed).is_empty()
	assert_array(device.set_up).is_empty()
	assert_int(device.scans).is_equal(0)


func test_the_console_line_is_locked_and_a_console_with_one_model_has_its_model_line_skipped() -> void:
	var carousel := await _edit(Fixtures.past_first_launch(self, {"gc": 2}))
	var model: ModelField = carousel.get_node("%Screens/AddConsole/%Model")
	assert_bool(model.disabled).is_true()
	await Fixtures.action(self, &"ui_up")
	assert_str(_focused()).is_equal("Emulator")
	for step in 2:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Subfolders")
	await Fixtures.action(self, &"ui_up")
	assert_str(_focused()).is_equal("Folder")


func test_the_swatches_show_each_model_on_the_ring_B_there_puts_back_the_one_it_had_and_B_on_the_form_too() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _edit(device)
	var swatches := await _open_models(carousel)
	await Fixtures.action(self, &"ui_right")
	assert_str(carousel._consoles.selected().folder).is_equal("ps2_fat")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(swatches.is_open()).is_false()
	assert_str(_focused()).is_equal("Model")
	assert_str(carousel._consoles.selected().folder).is_equal("ps2_slim")
	assert_str(_text(carousel, "AddConsole/%Model")).is_equal("Slim")
	# Kept in the swatches, the model is given up with the form.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_str(_text(carousel, "AddConsole/%Model")).is_equal("Fat")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_str(carousel._consoles.selected().folder).is_equal("ps2_slim")
	assert_array(device.set_up).is_empty()


func test_the_form_shows_the_choices_stored_and_saving_keeps_the_new_ones_and_the_model_the_ring_staying_on_it() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	device.players.append({"player_id": "ps2.other", "player_name": "ps2 - Other", "emulator_name": "Other",
		"extensions": PackedStringArray(["iso"])})
	device.setups["ps2"] = {"folder_uri": "content://tree/card%3AROMs%2Fps2", "player_id": "ps2.other",
		"disc_grouping": "separate", "folder_depth": "top_level"}
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	if _selected(carousel) != "ps2":
		await Fixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
		await Fixtures.settled_consoles(self, carousel)
	await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	assert_str(_text(carousel, "AddConsole/%Emulator")).is_equal("Other")
	assert_bool((carousel.get_node("%Screens/AddConsole/%Subfolders") as Button).button_pressed).is_false()
	assert_bool((carousel.get_node("%Screens/AddConsole/%Discs") as Button).button_pressed).is_false()
	# Back to the front, the emulator chosen stays.
	await Fixtures.resume(self)
	assert_str(_text(carousel, "AddConsole/%Emulator")).is_equal("Other")
	assert_str(_text(carousel, "AddConsole/%Add")).is_equal("Save")
	await _open_models(carousel)
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Subfolders")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _save(carousel)
	assert_bool(await _closed(carousel)).is_true()
	assert_str(device.set_up[-1].folder_depth).is_equal("subfolders")
	assert_str(device.set_up[-1].disc_grouping).is_equal("separate")
	assert_str(device.set_up[-1].player_id).is_equal("ps2.other")
	assert_str(device.set_up[-1].folder_uri).is_equal("content://tree/card%3AROMs%2Fps2")
	assert_str(device.set_up[-1].variant_id).is_equal("ps2_fat")
	assert_int(device.scans).is_equal(1)
	assert_array(device.removed).is_empty()
	assert_str(_selected(carousel)).is_equal("ps2")
	assert_str(carousel._consoles.selected().folder).is_equal("ps2_fat")


func test_a_folder_whose_access_is_gone_still_shows_by_name_and_its_place_is_not_claimed() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.lost_folders = ["ps2"]
	var carousel := await _edit(device)
	assert_str(_text(carousel, "AddConsole/%Folder")).is_equal("ps2")
	await _ask_removal(carousel)
	assert_str(_text(carousel, "Confirm/%Text")).contains("stay where they are")


func test_a_console_set_up_without_games_is_offered_again_by_the_form_and_brings_the_carousel() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 0})
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await Fixtures.choose_console(self, carousel, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _focused() == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(await _usable(carousel)).is_true()


func test_inv_20_on_the_edit_form_its_swatches_and_the_confirmation_exactly_one_control_has_the_focus() -> void:
	var random := CarouselFixtures.cases(63)
	var carousel := await _edit(Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2}))
	await Fixtures.wander(self, carousel, "AddConsole", random)
	(carousel.get_node("%Screens/AddConsole/%Emulator") as Control).grab_focus()
	await _open_models(carousel)
	await Fixtures.wander(self, carousel, "AddConsole", random)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _ask_removal(carousel)
	await Fixtures.wander(self, carousel, "Confirm", random)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wander(self, carousel, "AddConsole", random)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()


func test_a_new_model_alone_is_saved_with_the_choices_stored_without_scanning_even_with_their_emulator_gone() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.setups["ps2"] = {"folder_uri": "content://tree/card%3AROMs%2Fps2", "player_id": "ps2.gone",
		"disc_grouping": "separate", "folder_depth": "top_level"}
	var carousel := await _edit(device)
	assert_bool((carousel.get_node("%Screens/AddConsole/%Add") as Button).disabled).is_true()
	await _open_models(carousel)
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await _save(carousel)
	assert_bool(await _closed(carousel)).is_true()
	assert_str(device.set_up[-1].player_id).is_equal("ps2.gone")
	assert_str(device.set_up[-1].folder_depth).is_equal("top_level")
	assert_str(device.set_up[-1].variant_id).is_equal("ps2_fat")
	assert_int(device.scans).is_equal(0)
	assert_str(carousel._consoles.selected().folder).is_equal("ps2_fat")


func test_presses_while_an_edit_is_saved_change_nothing_and_leave_nothing_open() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _edit(device)
	var discs: Button = carousel.get_node("%Screens/AddConsole/%Discs")
	var grouped := discs.button_pressed
	for step in 3:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Subfolders")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	device.slow.append(&"scan")
	await _save(carousel)
	await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(discs.button_pressed).is_equal(grouped)
	device.slow.clear()
	device.released.emit()
	assert_bool(await _closed(carousel)).is_true()
	assert_bool((carousel.get_node("%Screens/AddConsole/%Models") as ModelSwatches).is_open()).is_false()
	assert_int(device.scans).is_equal(1)
	assert_array(device.removed).is_empty()
