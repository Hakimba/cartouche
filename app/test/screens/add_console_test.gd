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
	await get_tree().create_timer(0.6).timeout
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


func test_INV_E12_06_the_type_list_is_exactly_the_supported_consoles_not_yet_set_up() -> void:
	var first := _new_device()
	var carousel := await Fixtures.on_form(self, first, false)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return _chooser(carousel).visible)).is_true()
	assert_array(_listed_sorted(carousel)).is_equal(_supported_platforms())
	assert_int(_chooser(carousel).rows().size()).is_equal(12)


func test_INV_E12_06_a_console_set_up_is_not_offered_again_and_the_others_keep_the_catalog_order() -> void:
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


func test_the_step_chips_fill_with_each_field_chosen_and_the_count_follows() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device, false)
	var form := _the_form(carousel)
	var chips: Array[StepField] = [_form(carousel, "%Type"), _form(carousel, "%Emulator"), _form(carousel, "%Folder")]
	assert_array(chips.map(func(chip: StepField) -> bool: return chip.done)).contains_exactly([false, false, false])
	assert_int(form.steps()).is_equal(0)
	await Fixtures.choose_type(self, carousel)
	assert_array(chips.map(func(chip: StepField) -> bool: return chip.done)).contains_exactly([true, false, false])
	assert_int(form.steps()).is_equal(1)
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, device.installed_players("ps2")[0].id)
	assert_array(chips.map(func(chip: StepField) -> bool: return chip.done)).contains_exactly([true, true, false])
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return chips[2].done)).is_true()
	assert_int(form.steps()).is_equal(3)
	var gel := StudioTokens.GEL[&"ps2_slim"]
	for chip in chips:
		assert_bool(await Fixtures.until(self, func() -> bool: return chip.chip_color().is_equal_approx(gel))).is_true()


func test_a_chip_not_chosen_is_not_filled() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	for field: String in ["%Type", "%Emulator", "%Folder"]:
		assert_that((_form(carousel, field) as StepField).chip_color()).is_equal(Color.TRANSPARENT)


func test_the_plinth_turns_the_type_chosen_and_its_plate_names_the_emulator() -> void:
	var device := _new_device()
	var carousel := await Fixtures.on_form(self, device, false)
	var form := _the_form(carousel)
	assert_str(form.plinth().console()).is_empty()
	assert_str(form.plate_name()).is_equal("No console")
	await Fixtures.choose_type(self, carousel)
	assert_str(form.plinth().console()).is_equal("ps2_slim")
	assert_str(form.plate_name()).is_empty()
	await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.choose_in_list(self, carousel, device.installed_players("ps2")[0].id)
	assert_str(form.plate_name()).is_equal(device.installed_players("ps2")[0].emulator_name)
	assert_str(form.plinth().console()).is_equal("ps2_slim")
	await Fixtures.action(self, &"ui_up")
	await Fixtures.choose_type(self, carousel, "gba")
	assert_str(form.plinth().console()).is_equal("gba")


func test_the_focus_jumps_to_add_once_games_are_found_and_down_from_the_discs_reaches_it() -> void:
	var carousel := await _filled(_new_device())
	assert_bool((_form(carousel, "%Add") as Button).disabled).is_false()
	(_form(carousel, "%Discs") as Control).grab_focus()
	await Fixtures.action(self, &"ui_down")
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	await Fixtures.action(self, &"ui_left")
	assert_str(Fixtures.focus(self).name).is_equal("Cancel")
	await Fixtures.action(self, &"ui_right")
	assert_str(Fixtures.focus(self).name).is_equal("Add")
	await Fixtures.action(self, &"ui_up")
	assert_str(Fixtures.focus(self).name).is_equal("Discs")


func test_down_from_the_discs_reaches_cancel_while_no_game_is_found() -> void:
	var device := _new_device()
	device.games = 0
	var carousel := await Fixtures.on_form(self, device)
	(_form(carousel, "%Discs") as Control).grab_focus()
	await Fixtures.action(self, &"ui_down")
	assert_str(Fixtures.focus(self).name).is_equal("Cancel")
	await Fixtures.action(self, &"ui_right")
	assert_str(Fixtures.focus(self).name).is_equal("Cancel")


func test_start_never_submits_the_form_but_A_does() -> void:
	var device := _new_device()
	var carousel := await _filled(device)
	await Fixtures.action(self, &"form_submit")
	assert_int(device.scans).is_equal(0)
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("AddConsole")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	assert_int(device.scans).is_equal(1)

func test_the_card_rests_on_the_focused_line_and_rings_a_pill_button() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var card := _the_form(carousel).card()
	var rests_on := func(control: Control, grown: float) -> bool:
		var box := Rect2(control.position, control.size).grow(grown)
		return card.position.is_equal_approx(box.position) and card.size.is_equal_approx(box.size)
	var type: Control = _form(carousel, "%Type")
	assert_bool(card.bare).is_false()
	assert_bool(rests_on.call(type, 0.0)).is_true()
	for _i in 5:
		await Fixtures.action(self, &"ui_down")
	var cancel: Control = _form(carousel, "%Cancel")
	assert_str(Fixtures.focus(self).name).is_equal("Cancel")
	assert_bool(await Fixtures.until(self, func() -> bool: return rests_on.call(cancel, 8.96))).is_true()
	assert_bool(card.bare).is_true()
	# The design's table: 3.5 cqw, whatever the pill's height.
	assert_float(card.radius).is_equal_approx(3.5 * FormPaint.CQW, 0.01)
	await Fixtures.action(self, &"ui_up")
	assert_bool(card.bare).is_false()
	assert_bool(await Fixtures.until(self, func() -> bool: return rests_on.call(_form(carousel, "%Discs"), 0.0))).is_true()


func test_the_hint_row_shows_only_a_choose_where_the_design_puts_it() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var hints := _form(carousel, "Hints") as HintRow
	assert_int(hints.get_child_count()).is_equal(1)
	var hint := hints.get_child(0) as ButtonHint
	assert_str(hint.text).is_equal("Choose")
	assert_bool(hints.is_visible_in_tree() and hint.is_visible_in_tree()).is_true()
	assert_that(hints.global_position).is_equal(StudioTokens.HINTS.position)
	assert_float(hint.size.x).is_greater(0.0)


func test_a_value_too_long_for_its_line_ends_with_an_ellipsis_on_one_line() -> void:
	var field: StepField = auto_free(preload("res://screens/step_field.tscn").instantiate())
	add_child(field)
	var long := "Carte SD › ROMs › " + "un dossier au nom très long ".repeat(6) + "ps2"
	field.show_value(long)
	await await_idle_frame()
	var whole := StudioText.new(long, StudioTokens.Face.JAKARTA_700, 2.35 * 12.8, 0.0)
	assert_float(whole.width).is_greater(field.room())
	assert_float(field.shown_width()).is_less_equal(field.room())
	assert_float(field.shown_width()).is_greater(field.room() - 60.0)
	field.show_value("Carte SD › ROMs › ps2")
	await await_idle_frame()
	assert_float(field.shown_width()).is_less(field.room())


func test_the_form_comes_in_over_a_motion_and_leaves_over_one_before_it_closes() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var form := _the_form(carousel)
	assert_float(form.modulate.a).is_less(1.0)
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(form.modulate.a, 1.0))).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("AddConsole")
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()


func test_the_lines_come_back_to_rest_when_a_chooser_is_given_up() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var list: Control = _form(carousel, "List")
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(_the_form(carousel).modulate.a, 1.0))).is_true()
	await Fixtures.until(self, func() -> bool: return list.position.is_equal_approx(Vector2(524.8, 204.8)))
	var rest := list.position
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return not list.position.is_equal_approx(rest))).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await Fixtures.until(self, func() -> bool:
		return list.position.is_equal_approx(rest) and is_equal_approx(list.modulate.a, 1.0))).is_true()


func test_the_model_rises_again_on_the_same_plinth_when_a_chooser_is_given_up() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var form := _the_form(carousel)
	await Fixtures.choose_type(self, carousel)
	var plinth := form.plinth()
	var model := plinth.get_node("Turntable") as Control
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(model.modulate.a, 1.0))).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.until(self, func() -> bool: return model.modulate.a < 0.05)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_object(form.plinth()).is_same(plinth)
	assert_float(model.modulate.a).is_less(1.0)
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(model.modulate.a, 1.0))).is_true()
	assert_str(plinth.console()).is_equal("ps2_slim")


func test_the_edit_form_s_remove_pill_shows_no_b_key_and_the_add_form_s_cancel_pill_does() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var form := _the_form(carousel)
	var cancel := _form(carousel, "%Cancel") as FormPill
	var add := _form(carousel, "%Add") as FormPill
	assert_bool(cancel.keyed).is_true()
	assert_bool(add.primary).is_true()
	form.edit("ps2", AndroidServices.PlatformSetup.new({}), null, PackedStringArray())
	assert_str(cancel.text).is_equal("Remove")
	assert_bool(cancel.keyed).is_false()
	assert_str(add.text).is_equal("Save")
	form.open()
	assert_str(cancel.text).is_equal("Cancel")
	assert_bool(cancel.keyed).is_true()
	await await_idle_frame()
	await await_idle_frame()


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
	await get_tree().create_timer(0.3).timeout
	assert_array(closed).contains_exactly([AddConsole.Outcome.GIVEN_UP])
	assert_int(device.scans).is_equal(0)
	assert_array(device.set_up).is_empty()


func test_a_form_given_up_early_only_fades_out() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var form := _the_form(carousel)
	await get_tree().create_timer(0.1).timeout
	await Fixtures.joypad(self, JOY_BUTTON_B)
	var peak := form.modulate.a
	# Still on its way in when B came: it never jumps to whole before it fades.
	assert_float(peak).is_less(0.7)
	var shown := true
	while shown:
		assert_float(form.modulate.a).is_less_equal(peak + 0.0001)
		await await_idle_frame()
		var screen := Fixtures.shown_screen(carousel)
		shown = screen != null and screen.name == "AddConsole"
	assert_float(form.modulate.a).is_less(peak)


func test_remove_pressed_while_the_edit_form_leaves_asks_nothing() -> void:
	var carousel := await Fixtures.on_form(self, _new_device(), false)
	var form := _the_form(carousel)
	form.edit("ps2", AndroidServices.PlatformSetup.new({}), null, PackedStringArray())
	var closed: Array[AddConsole.Outcome] = []
	form.closed.connect(func(outcome: AddConsole.Outcome) -> void: closed.append(outcome))
	await Fixtures.joypad(self, JOY_BUTTON_B)
	(_form(carousel, "%Cancel") as Control).grab_focus()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await get_tree().create_timer(0.5).timeout
	assert_array(closed).contains_exactly([AddConsole.Outcome.GIVEN_UP])


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


func test_INV_E6_01_a_seeded_walk_over_the_filled_form_keeps_one_focus_and_B_leaves_it() -> void:
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
