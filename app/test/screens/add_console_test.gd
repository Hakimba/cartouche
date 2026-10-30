# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const StillStandIn := preload("res://test/studio/views/still_stand_in.gd")


func before_test() -> void:
	StillStandIn.install()


func after_test() -> void:
	StillStandIn.restore()
	TranslationServer.set_locale("en")


func _new_device() -> Fixtures.NewDevice:
	return auto_free(Fixtures.NewDevice.new())


func _form(carousel: Carousel, path: String) -> Control:
	return carousel.get_node("%Screens/AddConsole/" + path)


func _chooser(carousel: Carousel) -> StudioChooser:
	return _form(carousel, "%Choice") as StudioChooser


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
	(_form(carousel, "%Discs") as FormToggle).button_pressed = false
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
	await Fixtures.choose_in_list(self, carousel, "ps2.other")
	assert_str(_note(carousel)).is_equal("Accepted files: .iso")
	assert_str((_form(carousel, "%Emulator") as StepField).text).is_equal("Other")
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
	await Fixtures.choose_type(self, carousel)
	assert_str(_note(carousel)).is_equal("Install an emulator for this console, then come back.")
	device.players.assign(installed)
	await Fixtures.resume(self)
	# There to choose now, not chosen for the user.
	assert_str((_form(carousel, "%Emulator") as StepField).text).is_equal("Choose…")
	assert_str(_note(carousel)).is_empty()
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, "ps2.armsx2")
	assert_str((_form(carousel, "%Emulator") as StepField).text).is_equal("ARMSX2 (Refresh/GitHub)")


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
	assert_bool(_the_form(carousel)._leaving).is_false()
	assert_bool((carousel.get_node("%Screens/Saving") as Label).visible).is_true()
	device.slow.clear()
	device.released.emit()
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
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
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()


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
	assert_array(Array(_chooser(carousel).ids())).is_equal(device.catalog.offered.map(
		func(console: AndroidServices.OfferedConsole) -> String: return console.id))
	await Fixtures.choose_in_list(self, carousel, "gc")
	assert_str(Fixtures.focus(self).name).is_equal("Type")
	assert_str((_form(carousel, "%Type") as StepField).text).is_equal("Nintendo - GameCube")
	assert_str((_form(carousel, "%Emulator") as StepField).text).is_equal("None installed")
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
	await Fixtures.choose_in_list(self, carousel, "gb")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return (_form(carousel, "%Choice") as Control).visible)).is_true()
	await await_idle_frame()
	var chooser := _chooser(carousel)
	assert_str(chooser.ids()[chooser.focused()]).is_equal("gb")
	assert_bool(chooser.rows()[chooser.focused()].has_focus()).is_true()
	await Fixtures.action(self, &"ui_down")
	assert_str(chooser.ids()[chooser.focused()]).is_not_equal("gb")
	assert_bool(chooser.rows()[chooser.focused()].has_focus()).is_true()


func test_a_type_changed_after_a_count_greys_add_until_the_new_one_is_counted() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return not (_form(carousel, "%Add") as Button).disabled)).is_true()
	(_form(carousel, "%Type") as Control).grab_focus()
	await Fixtures.choose_type(self, carousel, "gc")
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_true()
	assert_str(_note(carousel)).is_equal("Install an emulator for this console, then come back.")


func _supported_platforms() -> Array[String]:
	var platforms: Array[String] = []
	for platform: String in Appearance.defaults(ConsoleManifest.found()):
		platforms.append(platform)
	platforms.sort()
	return platforms


func _listed_sorted(carousel: Carousel) -> Array:
	var listed := Array(_chooser(carousel).ids())
	listed.sort()
	return listed


func test_the_type_list_is_exactly_the_supported_consoles_not_yet_set_up() -> void:
	var first := _new_device()
	var carousel := await Fixtures.on_form(self, first, false)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _chooser(carousel).visible)).is_true()
	assert_array(_listed_sorted(carousel)).is_equal(_supported_platforms())
	assert_int(_chooser(carousel).rows().size()).is_equal(12)


func test_a_console_set_up_is_not_offered_again_and_the_others_keep_the_catalog_order() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2, "xbox": 1})
	device.players_everywhere = true
	var more := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return more._shown)).is_true()
	await Fixtures.open_add_console(self, more)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _chooser(more).visible)).is_true()
	var expected := _supported_platforms().filter(func(id: String) -> bool: return id not in ["ps2", "gba", "xbox"])
	assert_array(_listed_sorted(more)).is_equal(expected)
	var in_order := device.catalog.offered.map(func(console: AndroidServices.OfferedConsole) -> String: return console.id) \
		.filter(func(id: String) -> bool: return id in expected)
	assert_array(Array(_chooser(more).ids())).is_equal(in_order)
	assert_str(_chooser(more).counter()).is_equal("01 / 9")


func _the_form(carousel: Carousel) -> AddConsole:
	return carousel.get_node("%Screens/AddConsole")


## The form with the PS2, its first emulator and the folder chosen, the focus on Add.
func _filled(device: Fixtures.NewDevice) -> Carousel:
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	return carousel


func test_start_never_submits_the_form_but_A_does() -> void:
	var device := _new_device()
	var carousel := await _filled(device)
	await Fixtures.action(self, &"form_submit")
	assert_int(device.scans).is_equal(0)
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("AddConsole")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_int(device.scans).is_equal(1)

func test_while_the_form_leaves_nothing_on_it_acts_and_it_closes_once() -> void:
	var device := _new_device()
	var carousel := await _filled(device)
	var form := _the_form(carousel)
	var closed: Array[AddConsole.Outcome] = []
	form.closed.connect(func(outcome: AddConsole.Outcome) -> void: closed.append(outcome))
	await Fixtures.joypad(self, JOY_BUTTON_B)
	device.slow = [&"preview"]
	await Fixtures.resume(self)
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_false()
	device.slow.clear()
	device.released.emit()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	(_form(carousel, "%Type") as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(_chooser(carousel).visible).is_false()
	await Fixtures.action(self, &"form_submit")
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_bool(await Fixtures.until(self, func() -> bool: return not form.visible)).is_true()
	await await_idle_frame()
	assert_array(closed).contains_exactly([AddConsole.Outcome.GIVEN_UP])
	assert_int(device.scans).is_equal(0)
	assert_array(device.set_up).is_empty()


func test_remove_pressed_while_the_edit_form_leaves_asks_nothing() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var form := _the_form(carousel)
	form.edit("ps2", AndroidServices.PlatformSetup.new({}), null, PackedStringArray())
	var closed: Array[AddConsole.Outcome] = []
	form.closed.connect(func(outcome: AddConsole.Outcome) -> void: closed.append(outcome))
	await Fixtures.joypad(self, JOY_BUTTON_B)
	(_form(carousel, "%Cancel") as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return not form.visible)).is_true()
	await await_idle_frame()
	assert_array(closed).contains_exactly([AddConsole.Outcome.GIVEN_UP])
	assert_str(Fixtures.shown_screen(carousel).name).is_not_equal("Confirm")


func test_a_toggle_greys_add_until_its_count_comes() -> void:
	var device := _new_device()
	var carousel := await _filled(device)
	device.slow = [&"preview"]
	(_form(carousel, "%Discs") as FormToggle).button_pressed = false
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_true()
	device.slow.clear()
	device.released.emit()
	assert_bool(await Fixtures.until(self, func() -> bool: return not (_form(carousel, "%Add") as Button).disabled)).is_true()


func test_a_type_changed_while_a_count_is_pending_is_not_counted_for_the_new_one() -> void:
	var device := _new_device()
	device.slow = [&"preview"]
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return device.previews.size() == 1)).is_true()
	(_form(carousel, "%Type") as Control).grab_focus()
	await Fixtures.choose_type(self, carousel, "gc")
	device.slow.clear()
	device.released.emit()
	await await_idle_frame()
	await await_idle_frame()
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_true()
	assert_str(_note(carousel)).is_equal("Install an emulator for this console, then come back.")


func test_inv_20_a_seeded_walk_over_the_filled_form_keeps_one_focus_and_B_leaves_it() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1203
	var device := _new_device()
	var carousel := await _filled(device)
	var form := _the_form(carousel)
	var visited_add := false
	for move in 80:
		var pick := random.randi() % 6
		var focused := Fixtures.focus(self)
		if _chooser(carousel).visible:
			await Fixtures.joypad(self, JOY_BUTTON_A if pick < 3 else JOY_BUTTON_B)
		elif pick < 4:
			await Fixtures.action(self, Fixtures.NAVIGATION[pick])
		elif focused.name not in ["Add", "Cancel"]:
			await Fixtures.joypad(self, JOY_BUTTON_A)
		await await_idle_frame()
		focused = Fixtures.focus(self)
		assert_object(focused).is_not_null()
		assert_bool(focused.is_visible_in_tree()).is_true()
		assert_bool((_chooser(carousel) if _chooser(carousel).visible else form).is_ancestor_of(focused)).is_true()
		assert_bool(form.steps() >= 0 and form.steps() <= 3).is_true()
		visited_add = visited_add or focused.name == "Add"
	assert_bool(visited_add).is_true()
	if _chooser(carousel).visible:
		await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_array(device.set_up).is_empty()


func test_the_form_previews_variants_saves_the_choice_and_keeps_it_in_both_choosers() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	var form := _the_form(carousel)
	await Fixtures.action(self, &"ui_right")
	assert_str(form.plinth().console()).is_equal("ps2_fat")
	assert_str(form.setup().variant_id).is_equal("ps2_fat")
	assert_dict(device.console_variants).is_empty()
	await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _chooser(carousel).visible)).is_true()
	assert_str(_chooser(carousel)._plinth.console()).is_equal("ps2_fat")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return Fixtures.focus(self).name == "Add")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_str(device.console_variants["ps2"]).is_equal("ps2_fat")
	assert_str(device.set_up[-1].variant_id).is_equal("ps2_fat")


func test_a_form_given_up_does_not_keep_the_previewed_variant() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device)
	await Fixtures.action(self, &"ui_left")
	assert_str(_the_form(carousel).plinth().console()).is_equal("ps2_fat")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	assert_dict(device.console_variants).is_empty()
	assert_array(device.set_up).is_empty()
