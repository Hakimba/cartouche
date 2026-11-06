# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The settings over the consoles screen and the games screen: the button style, the edges' smoothing, the
## background, the region, the language and the switches.

const Fixtures := preload("res://test/screens/fixtures.gd")
const CarouselFixtures := preload("res://test/carousel/fixtures.gd")


func after_test() -> void:
	Controls.style = &"xbox"
	Locale.apply("en")
	Backdrop.show(&"light", true)


func _settings_ready(carousel: Carousel) -> bool:
	return await Fixtures.until(self, func() -> bool:
		var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
		return menu.is_visible_in_tree() and menu.state == SettingsMenu.State.OPEN)


func _focused() -> String:
	return Fixtures.focus(self).name


func _text(carousel: Carousel, path: String) -> String:
	return carousel.get_node("%Screens/" + path).get(&"text")


## Whether the screens closed, the carousel taking the controller again.
func _closed(carousel: Carousel) -> bool:
	return await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel._shown)


## The current setting shown on [param line] or applied: the style the buttons are drawn in, the language the text
## is written in, the background drawn; the region only shows on its line.
func _state(carousel: Carousel, line: String, key: StringName) -> String:
	match key:
		&"button_style":
			return Controls.style
		&"language":
			return TranslationServer.get_locale()
		&"backdrop":
			return Backdrop.choice
	return _text(carousel, "Settings/Panel/Items/%s/%%Value" % line)


## Each choice of the settings opens its page on the [param kept] choice (by node name), over the hidden carousel;
## B there saves nothing and the settings come back on the line; another choice, [param moves] to the right, is
## saved once as [param value], applied, and named [param shown] on its line; on a page that [param stays] open, at once.
func test_a_choice_opens_its_page_on_the_one_kept_B_keeps_it_and_another_is_saved_once_and_applied(line: String,
		page: String, key: StringName, kept: String, moves: int, value: String, shown: String, stays: bool,
		_test_parameters := [
			["ButtonStyle", "ButtonStyle", &"button_style", "Xbox", 1, "nintendo", "Nintendo", false],
			["Region", "PreferredRegion", &"preferred_region", "None", 1, "Europe", "Europe", false],
			["Language", "Language", &"language", "None", 2, "fr", "Français", false],
			["Backdrop", "Backdrop", &"backdrop", "Light", 1, "dark", "Dark", true],
		]) -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await _press_line(device, line)
	assert_bool(await Fixtures.on(self, carousel, page)).is_true()
	await await_idle_frame()
	assert_str(_focused()).is_equal(kept)
	# A screen of its own, as the settings: the carousel stays hidden under both (the screens in front cover it).
	assert_bool((carousel.get_node("%Consoles") as Node3D).visible).is_false()
	assert_bool((carousel.get_node("%ConsoleTitle") as Control).visible).is_false()
	var was := _state(carousel, line, key)
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_focused()).is_equal(line)
	assert_array(device.saves(key)).is_empty()
	assert_str(_state(carousel, line, key)).is_equal(was)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, page)).is_true()
	for step in moves:
		await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return device.saves(key).size() == 1)
	assert_str(str(device.saves(key)[0])).is_equal(value)
	if stays:
		assert_str(Fixtures.shown_screen(carousel).name).is_equal(page)
		assert_str(_focused()).is_equal(shown)
		assert_str(_state(carousel, line, key)).is_equal(value)
		await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_text(carousel, "Settings/Panel/Items/%s/%%Value" % line)).is_equal(shown)
	assert_str(_state(carousel, line, key)).is_equal(value)
	assert_str(_focused()).is_equal(line)


## A choice the plugin does not save is not applied: the line and what it sets stay as they were, the focus on the
## line, or on the [param kept] choice of a page that [param stays] open.
func test_a_choice_the_plugin_does_not_save_is_not_applied(line: String, page: String, key: StringName, kept: String,
		moves: int, stays: bool, _test_parameters := [
			["ButtonStyle", "ButtonStyle", &"button_style", "Xbox", 1, false],
			["Region", "PreferredRegion", &"preferred_region", "None", 1, false],
			["Language", "Language", &"language", "None", 2, false],
			["Backdrop", "Backdrop", &"backdrop", "Light", 1, true],
		]) -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.failing.append(&"save_" + key)
	var carousel := await _press_line(device, line)
	var named := _text(carousel, "Settings/Panel/Items/%s/%%Value" % line)
	var was := _state(carousel, line, key)
	assert_bool(await Fixtures.on(self, carousel, page)).is_true()
	await await_idle_frame()
	for step in moves:
		await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return device.saves(key).size() == 1)
	if stays:
		await await_idle_frame()
		assert_str(_focused()).is_equal(kept)
	else:
		assert_bool(await _settings_ready(carousel)).is_true()
		assert_str(_focused()).is_equal(line)
	assert_str(_state(carousel, line, key)).is_equal(was)
	assert_str(_text(carousel, "Settings/Panel/Items/%s/%%Value" % line)).is_equal(named)


func test_the_regions_offered_are_those_the_plugin_takes_the_one_kept_ticked_and_choosing_it_again_saves_nothing() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.preferred_regions = PackedStringArray(["Japan", "Korea"])
	device.preferred_region = "Japan"
	var carousel := await _press_line(device, "Region")
	var page: CardChoiceScreen = carousel.get_node("%Screens/PreferredRegion")
	assert_bool(await Fixtures.on(self, carousel, "PreferredRegion")).is_true()
	assert_array(_card_texts(page)).is_equal(PackedStringArray(["None", "Japan", "Korea"]))
	await await_idle_frame()
	assert_str(_focused()).is_equal("Japan")
	assert_int(page.find_children("*", "Control", true, false).filter(
		func(node: Node) -> bool: return node is CardChoiceScreen.Tick).size()).is_equal(1)
	assert_object(Fixtures.focus(self).get_child(0)).is_instanceof(CardChoiceScreen.Tick)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_array(device.saves(&"preferred_region")).is_empty()


func test_the_language_line_scrolls_into_the_card_and_its_page_offers_every_language() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	# Six lines show; the last scrolls in, and the first out of sight, unseen and untouchable.
	assert_float(menu.row_of(&"language").modulate.a).is_zero()
	for step in 7:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Language")
	assert_float(menu.row_of(&"language").modulate.a).is_equal(1.0)
	assert_float(menu.row_of(&"button_style").modulate.a).is_zero()
	assert_int(menu.row_of(&"button_style").mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "Language")).is_true()
	assert_array(_card_texts(carousel.get_node("%Screens/Language") as CardChoiceScreen)).is_equal(
		PackedStringArray([Locale.name_of("")] + Locale.NAMES.values()))


## [param device]'s settings, opened and the line called [param line] pressed.
func _press_line(device: Fixtures.NewDevice, line: String) -> Carousel:
	var carousel := await Fixtures.shown(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	while _focused() != line:
		await Fixtures.action(self, &"ui_down")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	return carousel


func test_the_veil_switches_once_saved_and_a_veil_not_kept_slides_back() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	assert_bool(Backdrop.veil).is_true()
	var menu: SettingsMenu = (await _press_line(device, "PixelVeil")).get_node("%Screens/Settings")
	await Fixtures.wait(self, func() -> bool: return not menu.saving)
	assert_array(device.saves(&"pixel_veil")).contains_exactly([false])
	assert_bool(Backdrop.veil).is_false()
	assert_bool(menu.switch_on(&"pixel_veil")).is_false()
	device.failing.append(&"save_pixel_veil")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return not menu.saving)
	assert_bool(Backdrop.veil).is_false()
	assert_bool(menu.switch_on(&"pixel_veil")).is_false()


func test_the_card_s_arrows_scroll_under_a_finger_the_focus_kept_on_a_line_shown() -> void:
	var carousel := Fixtures.fresh_carousel(self, Fixtures.past_first_launch(self, {}))
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_focused()).is_equal("ButtonStyle")
	assert_bool(menu._more(-1)).is_false()
	await _tap(menu, Vector2(menu._panel.size.x / 2.0, SettingsMenu._MORE_DOWN_Y))
	assert_float(menu.row_of(&"region").modulate.a).is_equal(1.0)
	assert_float(menu.row_of(&"button_style").modulate.a).is_zero()
	assert_float((Fixtures.focus(self) as Control).modulate.a).is_equal(1.0)
	await _tap(menu, Vector2(menu._panel.size.x / 2.0, SettingsMenu._MORE_UP_Y))
	assert_float(menu.row_of(&"button_style").modulate.a).is_equal(1.0)


## A finger down and up at [param at], in [param menu]'s card.
func _tap(menu: SettingsMenu, at: Vector2) -> void:
	await Fixtures.touch(self, [menu._panel.get_global_transform() * at])
	await await_idle_frame()


func test_Y_opens_the_settings_from_the_games_screen_too_and_B_goes_back_to_it() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	# The games screen whole again: the pill over the game, no console name.
	await Fixtures.wait(self, func() -> bool: return carousel._pill.modulate.a == 1.0)
	assert_float(carousel._console_title.modulate.a if carousel._console_title.visible else 0.0).is_equal(0.0)


func test_the_games_hints_stay_hidden_on_the_consoles_screen_while_the_settings_open_and_close() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	var hints: Control = carousel.get_node("%GamesHints")
	var seen: Array[float] = [0.0]
	var watch := func() -> void: seen[0] = maxf(seen[0], hints.modulate.a if hints.visible else 0.0)
	get_tree().process_frame.connect(watch)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null)
	await get_tree().process_frame
	get_tree().process_frame.disconnect(watch)
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_float(seen[0]).is_equal(0.0)


func test_a_direction_held_as_the_settings_open_on_the_games_screen_moves_nothing_once_they_close() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 5}))
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	await Fixtures.hold(self, &"carousel_right")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.hold(self, &"carousel_right", false)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null)
	var selected := carousel._row.selected_index()
	for frame in 60:
		await await_idle_frame()
	assert_int(carousel._row.selected_index()).is_equal(selected)


func test_a_library_changed_in_the_settings_opened_on_the_games_screen_comes_back_on_the_consoles() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2})
	var carousel := await Fixtures.shown(self, device)
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	device.consoles.erase("gba")
	carousel._on_screens_library_edited(AndroidServices.Library.new(device._library()))
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)
	assert_float(carousel._sequence._at_s).is_equal(0.0)
	assert_bool(carousel._sequence.is_processing()).is_false()
	await Fixtures.wait(self, func() -> bool: return carousel._console_title.modulate.a == 1.0)
	# The consoles the library replaced are freed at the end of the frame.
	await await_idle_frame()


func test_inv_20_on_every_settings_screen_exactly_one_control_of_it_has_the_focus() -> void:
	var random := CarouselFixtures.cases(62)
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2}))
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.wander(self, carousel, "Settings", random)
	for step in 7:
		await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wander(self, carousel, "ButtonStyle", random)


func _float_row(carousel: Carousel) -> SettingsMenu:
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	for step in 4:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("GamesFloat")
	return carousel.get_node("%Screens/Settings")


func test_floating_is_off_by_default_saved_on_A_and_keeps_one_focus() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	assert_bool(menu.switch_on(&"games_float")).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return device.saves(&"games_float").size() == 1)
	assert_array(device.saves(&"games_float")).is_equal([true])
	assert_bool(menu.switch_on(&"games_float")).is_true()
	assert_str(_focused()).is_equal("GamesFloat")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saves(&"games_float")).is_equal([true, false])
	assert_bool(menu.switch_on(&"games_float")).is_false()
	assert_str(_focused()).is_equal("GamesFloat")


func test_a_failed_float_save_restores_the_stored_switch_and_focus() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.failing.append(&"save_games_float")
	device.games_float = true
	var menu := await _float_row(await Fixtures.shown(self, device))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saves(&"games_float")).is_equal([false])
	assert_bool(menu.switch_on(&"games_float")).is_true()
	assert_bool(device.games_float).is_true()
	assert_str(_focused()).is_equal("GamesFloat")


## A device whose floating switch is saved only once [signal Fixtures.NewDevice.released].
func _slow_float() -> Fixtures.NewDevice:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.slow.append(&"save_games_float")
	return device


## [param device]'s pending saves answered.
func _release(device: Fixtures.NewDevice) -> void:
	device.slow.clear()
	device.released.emit()


func test_while_a_float_save_is_pending_presses_do_not_start_another_save_or_leave() -> void:
	var device := _slow_float()
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(menu.switch_on(&"games_float")).is_true()
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B]:
		await Fixtures.joypad(self, button)
	await Fixtures.action(self, &"ui_down")
	assert_array(device.saves(&"games_float")).is_equal([true])
	assert_bool(menu.is_visible_in_tree()).is_true()
	assert_int(menu.state).is_equal(SettingsMenu.State.OPEN)
	assert_str(_focused()).is_equal("GamesFloat")
	_release(device)
	await Fixtures.wait(self, func() -> bool: return not menu.saving)
	assert_bool(menu.switch_on(&"games_float")).is_true()
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
	var device := _slow_float()
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	menu._save_started_ms -= SettingsMenu.SAVE_ESCAPE_MS
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(menu.switch_on(&"games_float")).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(menu.switch_on(&"games_float")).is_false()
	assert_bool(menu.saving).is_false()


func test_a_late_success_after_closing_does_not_change_the_hidden_switch_or_its_confirmed_value() -> void:
	var device := _slow_float()
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	menu._save_started_ms -= SettingsMenu.SAVE_ESCAPE_MS
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	var knob := menu._switches[&"games_float"]._knob_x
	_release(device)
	assert_bool(carousel._screens._stored.games_float).is_false()
	assert_bool(menu.switch_on(&"games_float")).is_false()
	assert_float(menu._switches[&"games_float"]._knob_x).is_equal(knob)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(menu.switch_on(&"games_float")).is_false()
	assert_bool(device.games_float).is_true()


func _card_texts(page: CardChoiceScreen) -> PackedStringArray:
	var texts := PackedStringArray()
	for card: Button in page._cards.get_children():
		texts.append(card.text)
	return texts
