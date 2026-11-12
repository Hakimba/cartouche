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
	Sounds.level = SoundEffects.LEVELS
	EdgeSmoothingScreen.smooth(get_viewport(), Viewport.MSAA_4X)


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
	return await Fixtures.until(self, func() -> bool: return Fixtures.shown_screen(carousel) == null and carousel.is_shown())


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
	return (carousel.get_node("%%Screens/Settings/Panel/Items/%s" % line) as FieldButton).shown_value()


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
	assert_str((carousel.get_node("%%Screens/Settings/Panel/Items/%s" % line) as FieldButton).shown_value()).is_equal(shown)
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
	device.answers[Fixtures.NewDevice.save_of(key)] = Fixtures.Answer.FAILS
	var carousel := await _press_line(device, line)
	var named := (carousel.get_node("%%Screens/Settings/Panel/Items/%s" % line) as FieldButton).shown_value()
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
	assert_str((carousel.get_node("%%Screens/Settings/Panel/Items/%s" % line) as FieldButton).shown_value()).is_equal(named)


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
	for step in 8:
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
	await Fixtures.wait(self, func() -> bool: return not menu.held.pending())
	assert_array(device.saves(&"pixel_veil")).contains_exactly([false])
	assert_bool(Backdrop.veil).is_false()
	assert_bool(await _shown_on(menu, &"pixel_veil")).is_false()
	device.answers[Fixtures.Request.SAVE_PIXEL_VEIL] = Fixtures.Answer.FAILS
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return not menu.held.pending())
	assert_bool(Backdrop.veil).is_false()
	assert_bool(await _shown_on(menu, &"pixel_veil")).is_false()


func test_the_card_s_arrows_scroll_under_a_finger_the_focus_kept_on_a_line_shown() -> void:
	var carousel := Fixtures.fresh_carousel(self, Fixtures.past_first_launch(self, {}))
	assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_focused()).is_equal("ButtonStyle")
	assert_vector(menu.arrow_point(-1)).is_equal(Vector2.INF)
	await _tap(menu.arrow_point(1))
	assert_float(menu.row_of(&"region").modulate.a).is_equal(1.0)
	assert_float(menu.row_of(&"button_style").modulate.a).is_zero()
	assert_float((Fixtures.focus(self) as Control).modulate.a).is_equal(1.0)
	await _tap(menu.arrow_point(-1))
	assert_float(menu.row_of(&"button_style").modulate.a).is_equal(1.0)


## A finger down and up at the screen point [param at].
func _tap(at: Vector2) -> void:
	await Fixtures.touch(self, [at])
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


## The 3D models drawn: the consoles shown and the games drawn through their views.
func _drawn_models(carousel: Carousel) -> Array[Node3D]:
	var models: Array[Node3D] = []
	for item: ConsoleRow.Item in carousel._consoles._items:
		if item.model.is_visible_in_tree():
			models.append(item.model)
	for place: ShelfPlace in carousel._row._places:
		if place.media_view and place.media_view.is_visible_in_tree():
			models.append(place.shown)
	return models


## The 2D parts standing around the models that are drawn: the consoles' title with "+" and hints, the rail, the game's
## pill, the console's logo, the games' hints, the search.
func _drawn_parts(carousel: Carousel) -> Array[String]:
	var parts: Array[String] = []
	for part: CanvasItem in [carousel._console_title, carousel._rail, carousel._pill, carousel._games_logo,
			carousel._games_hints, carousel._search]:
		if part.is_visible_in_tree() and part.modulate.a > 0.0:
			parts.append(part.name)
	return parts


## The settings opened and turned back by B half-way, then opened and closed, on either screen: as in the console swap,
## the console and the games are cut with what stands around them as the card starts coming, and drawn again the frame
## it is gone, never under the card, never half transparent, their 2D parts never alone on the backdrop.
func test_no_model_is_drawn_under_the_settings_card_nor_half_transparent(games: bool,
		_test_parameters := [[false], [true]]) -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	if games:
		await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	var card: Control = menu.get_node("Panel")
	var wrong: Array[String] = []
	var watch := func() -> void:
		var models := _drawn_models(carousel)
		for model in models:
			var fade: ModelFade = model.get(&"_fade")
			if fade and fade.amount > 0.0:
				wrong.append("%s see-through" % model.name)
		if not menu.is_visible_in_tree():
			return
		var parts := _drawn_parts(carousel)
		if card.modulate.a > 0.0 and not (models.is_empty() and parts.is_empty()):
			wrong.append("%s %s under the card at %.2f" % [models, parts, card.modulate.a])
		if models.is_empty() and not parts.is_empty():
			wrong.append("%s alone" % [parts])
		if menu.state == SettingsMenu.State.CLOSING and card.modulate.a == 0.0 and models.is_empty():
			wrong.append("nothing back with the card gone")
	get_tree().process_frame.connect(watch)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	for frame in 8:
		await await_idle_frame()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	await Fixtures.settled(self, carousel)
	get_tree().process_frame.disconnect(watch)
	assert_array(wrong).is_empty()
	assert_array(_drawn_models(carousel)).is_not_empty()


func test_the_card_turned_back_open_by_Y_while_it_closes_takes_presses_again_and_says_so() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	for frame in 5:
		await await_idle_frame()
	assert_int(menu.state).is_equal(SettingsMenu.State.CLOSING)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(menu.holds_presses()).is_false()
	assert_bool(Fixtures.alive(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()


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


func test_the_settings_opened_as_the_games_hints_come_fade_them_with_the_rest() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	var hints: Control = carousel.get_node("%GamesHints")
	var over: Array[float] = [0.0]
	var watch := func() -> void:
		over[0] = maxf(over[0], (hints.modulate.a if hints.is_visible_in_tree() else 0.0) - carousel._search.modulate.a)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	get_tree().process_frame.connect(watch)
	assert_bool(await _settings_ready(carousel)).is_true()
	get_tree().process_frame.disconnect(watch)
	assert_float(over[0]).is_less_equal(0.001)


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


func test_a_direction_let_go_while_the_settings_open_is_pressed_again_at_the_first_press_once_they_close() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 5}))
	await Fixtures.press_to(self, carousel, JOY_BUTTON_A, Carousel.Screen.GAMES)
	await Fixtures.hold(self, &"carousel_right")
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	await Fixtures.hold(self, &"carousel_right", false)
	assert_bool(await _settings_ready(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return Fixtures.shown_screen(carousel) == null)
	await Fixtures.settled(self, carousel)
	var selected := carousel._row.selected_index()
	await Fixtures.action(self, &"carousel_right")
	await Fixtures.wait(self, func() -> bool: return carousel._row.selected_index() == selected + 1)


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
	# Each page the card opens, by its line, and back to the card.
	var pages: Dictionary[String, String] = {"ButtonStyle": "ButtonStyle", "Graphics": "EdgeSmoothing", "Backdrop": "Backdrop",
		"Region": "PreferredRegion", "Language": "Language"}
	for line: String in pages:
		for step in 8:
			await Fixtures.action(self, &"ui_up")
		for step in 8:
			if _focused() == line:
				break
			await Fixtures.action(self, &"ui_down")
		assert_str(_focused()).is_equal(line)
		await Fixtures.joypad(self, JOY_BUTTON_A)
		await Fixtures.wander(self, carousel, pages[line], random)
		await Fixtures.joypad(self, JOY_BUTTON_B)
		assert_bool(await _settings_ready(carousel)).is_true()
		await await_idle_frame()


## Whether the switch of [param key] shows on, as a player sees it: its knob at the right of its track once it stopped
## sliding.
func _shown_on(menu: SettingsMenu, key: StringName) -> bool:
	await get_tree().create_timer(0.3).timeout
	var track: Control = menu.row_of(key).get_children().filter(func(child: Node) -> bool:
		return child is ColorRect and child.get_child_count() == 1)[0]
	var knob := track.get_child(0) as Control
	return knob.position.x + knob.size.x / 2.0 > track.size.x / 2.0


func _float_row(carousel: Carousel) -> SettingsMenu:
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	for step in 4:
		await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("GamesFloat")
	return carousel.get_node("%Screens/Settings")


func test_floating_is_off_by_default_saved_on_A_keeps_one_focus_and_stays_on_after_a_restart() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	assert_bool(await _shown_on(menu, &"games_float")).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return device.saves(&"games_float").size() == 1)
	assert_array(device.saves(&"games_float")).is_equal([true])
	assert_bool(await _shown_on(menu, &"games_float")).is_true()
	assert_str(_focused()).is_equal("GamesFloat")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saves(&"games_float")).is_equal([true, false])
	assert_bool(await _shown_on(menu, &"games_float")).is_false()
	assert_str(_focused()).is_equal("GamesFloat")
	# Left on, it is read by the row as the settings close and still on in a new carousel.
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(device.games_float).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return carousel.is_shown())
	assert_bool(carousel._row.games_float).is_true()
	remove_child(carousel)
	carousel.queue_free()
	await await_idle_frame()
	var restarted := Fixtures.fresh_carousel(self, device)
	await Fixtures.wait(self, func() -> bool: return restarted.is_shown())
	assert_bool(await _shown_on(await _float_row(restarted), &"games_float")).is_true()


## The height of the game [param places] places right of the middle of the games row, at rest.
func _height_of(carousel: Carousel, places: int) -> float:
	return carousel._row._placed[carousel._row.selected_index() + places].position.y


func test_games_in_a_line_is_off_by_default_and_once_on_stands_the_games_past_the_neighbours_at_their_height() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 5})
	var carousel := await Fixtures.shown(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return carousel._screen == Carousel.Screen.GAMES and carousel._row.is_settling() == false)
	await get_tree().create_timer(0.5).timeout
	assert_float(_height_of(carousel, 2)).is_less(_height_of(carousel, 1))
	var menu := await _float_row(carousel)
	await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("GamesInLine")
	assert_bool(await _shown_on(menu, &"games_in_line")).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return device.saves(&"games_in_line").size() == 1)
	assert_array(device.saves(&"games_in_line")).is_equal([true])
	assert_bool(await _shown_on(menu, &"games_in_line")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return carousel.is_shown())
	await get_tree().create_timer(0.5).timeout
	assert_float(_height_of(carousel, 2)).is_equal_approx(_height_of(carousel, 1), 0.001)


func test_the_card_open_as_the_window_turns_wide_and_back_drops_the_games_in_a_line_and_takes_it_back() -> void:
	var window := get_window().size
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	var menu := await _float_row(carousel)
	await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("GamesInLine")
	get_window().size = Vector2i(1536, 960)
	await await_idle_frame()
	assert_bool(menu.row_of(&"games_in_line").visible).is_false()
	assert_str(_focused()).is_equal("GamesFloat")
	assert_bool(Fixtures.alive(carousel)).is_true()
	await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Region")
	get_window().size = window
	await await_idle_frame()
	assert_bool(menu.row_of(&"games_in_line").visible).is_true()
	assert_str(_focused()).is_equal("Region")
	assert_bool(Fixtures.alive(carousel)).is_true()
	await Fixtures.action(self, &"ui_up")
	assert_str(_focused()).is_equal("GamesInLine")


func test_the_shelf_follows_the_window_turning_wide_and_back_and_the_card_opened_then_shows_the_row_or_not() -> void:
	var window := get_window().size
	var device := Fixtures.past_first_launch(self, {"ps2": 5})
	var carousel := await Fixtures.shown(self, device)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return carousel._screen == Carousel.Screen.GAMES)
	await get_tree().create_timer(0.5).timeout
	get_window().size = Vector2i(1536, 960)
	await get_tree().create_timer(0.3).timeout
	assert_float(_height_of(carousel, 2)).is_equal_approx(_height_of(carousel, 1), 0.001)
	var menu := await _float_row(carousel)
	assert_bool(menu.row_of(&"games_in_line").visible).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await Fixtures.wait(self, func() -> bool: return carousel.is_shown())
	get_window().size = window
	await get_tree().create_timer(0.3).timeout
	assert_float(_height_of(carousel, 2)).is_less(_height_of(carousel, 1))
	await _float_row(carousel)
	assert_bool(menu.row_of(&"games_in_line").visible).is_true()


func test_on_a_screen_whose_games_already_stand_in_a_line_the_card_leaves_the_switch_out() -> void:
	var window := get_window().size
	get_window().size = Vector2i(1536, 960)
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	var menu := await _float_row(carousel)
	await Fixtures.action(self, &"ui_down")
	assert_str(_focused()).is_equal("Region")
	assert_bool(menu.row_of(&"games_in_line").visible).is_false()
	get_window().size = window


## The focus left without its row goes to the nearest row shown above it, or to the first shown when none is above.
func test_a_row_left_out_gives_the_focus_to_the_nearest_shown_above_else_to_the_first() -> void:
	assert_str(SettingsMenu.nearest_shown(&"region", [&"button_style", &"region", &"sounds"])).is_equal("region")
	assert_str(SettingsMenu.nearest_shown(&"button_style", [&"graphics", &"backdrop", &"language"])).is_equal("graphics")
	assert_str(SettingsMenu.nearest_shown(&"games_in_line", [&"button_style", &"pixel_veil", &"region"])) \
		.is_equal("pixel_veil")
	assert_str(SettingsMenu.nearest_shown(&"", [&"graphics", &"sounds"])).is_equal("graphics")


func test_a_failed_float_save_restores_the_stored_switch_and_focus() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.answers[Fixtures.Request.SAVE_GAMES_FLOAT] = Fixtures.Answer.FAILS
	device.games_float = true
	var menu := await _float_row(await Fixtures.shown(self, device))
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saves(&"games_float")).is_equal([false])
	assert_bool(await _shown_on(menu, &"games_float")).is_true()
	assert_bool(device.games_float).is_true()
	assert_str(_focused()).is_equal("GamesFloat")


## A device whose floating switch is saved only once [signal Fixtures.NewDevice.released].
func _slow_float() -> Fixtures.NewDevice:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.answers[Fixtures.Request.SAVE_GAMES_FLOAT] = Fixtures.Answer.HELD
	return device


## [param device]'s pending saves answered.
func _release(device: Fixtures.NewDevice) -> void:
	device.release()


func test_while_a_float_save_is_pending_presses_do_not_start_another_save_or_leave() -> void:
	var device := _slow_float()
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _shown_on(menu, &"games_float")).is_true()
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_B]:
		await Fixtures.joypad(self, button)
	await Fixtures.action(self, &"ui_down")
	assert_array(device.saves(&"games_float")).is_equal([true])
	assert_bool(menu.is_visible_in_tree()).is_true()
	assert_int(menu.state).is_equal(SettingsMenu.State.OPEN)
	assert_str(_focused()).is_equal("GamesFloat")
	_release(device)
	await Fixtures.wait(self, func() -> bool: return not menu.held.pending())
	assert_bool(await _shown_on(menu, &"games_float")).is_true()
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


## B closes the card two seconds into a save that does not answer; opened again, the card shows the switch as asked
## and holds its presses until the answer, B still letting it go: the two seconds are the save's, not the card's.
func test_B_closes_after_two_seconds_even_when_the_save_never_answers() -> void:
	var device := _slow_float()
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	Fixtures.clock.ms += ScreenFlow.HeldSave.ESCAPE_MS
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(await _shown_on(menu, &"games_float")).is_false()
	assert_bool(carousel._row.games_float).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(await _shown_on(menu, &"games_float")).is_true()
	assert_bool(menu.held.pending()).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saves(&"games_float")).is_equal([true])
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()


## A settings' save let go by B holds only its own page: the form, busy adding a console meanwhile, still takes no B.
func test_a_settings_save_let_go_by_B_lets_no_other_page_go_with_B() -> void:
	var device := _slow_float()
	device.answers[Fixtures.Request.SCAN] = Fixtures.Answer.HELD
	device.players_everywhere = true
	var carousel := await Fixtures.shown(self, device)
	await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	Fixtures.clock.ms += ScreenFlow.HeldSave.ESCAPE_MS
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	await Fixtures.open_add_console(self, carousel)
	assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
	await Fixtures.choose_console(self, carousel, device, "psx")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return Fixtures.focus(self).name == "Add")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	await Fixtures.wait(self, func() -> bool: return device.scans == 1)
	var form: AddConsole = carousel.get_node("%Screens/AddConsole")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_int(form.phase).is_equal(Page.Phase.BUSY)
	_release(device)
	await Fixtures.wait(self, func() -> bool: return carousel.is_shown())
	await Fixtures.settled(self, carousel)


func test_a_switch_pressed_by_touch_while_its_save_is_pending_starts_no_other_save() -> void:
	var device := _slow_float()
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(menu.held.pending()).is_true()
	menu.row_of(&"games_float").pressed.emit()
	assert_array(device.saves(&"games_float")).is_equal([true])
	_release(device)
	await Fixtures.wait(self, func() -> bool: return not menu.held.pending())
	assert_array(device.saves(&"games_float")).is_equal([true])


## A switch whose save answers after B closed the card is used once kept (INV-15): the games float from then on, and
## the card shows it on; a refusal leaves everything as it was.
func test_a_switch_saved_after_B_closed_the_card_is_used_as_soon_as_the_plugin_keeps_it(fails: bool,
		_test_parameters := [[false], [true]]) -> void:
	var device := _slow_float()
	if fails:
		device.failures[Fixtures.Request.SAVE_GAMES_FLOAT] = &"unwritable"
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	Fixtures.clock.ms += ScreenFlow.HeldSave.ESCAPE_MS
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	_release(device)
	await await_idle_frame()
	assert_bool(device.games_float).is_equal(not fails)
	assert_bool(carousel._screens._stored.games_float).is_equal(not fails)
	assert_bool(carousel._row.games_float).is_equal(not fails)
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(await _shown_on(menu, &"games_float")).is_equal(not fails)
	assert_bool(menu.held.pending()).is_false()


## The card opened again while a switch is still being saved shows it as asked and holds its presses; the answer
## frees it, the switch where the plugin left it.
func test_the_card_opened_again_during_a_switch_s_save_shows_it_asked_until_it_is_kept() -> void:
	var device := _slow_float()
	var carousel := await Fixtures.shown(self, device)
	var menu := await _float_row(carousel)
	await Fixtures.joypad(self, JOY_BUTTON_A)
	Fixtures.clock.ms += ScreenFlow.HeldSave.ESCAPE_MS
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(menu.holds_presses()).is_true()
	_release(device)
	await await_idle_frame()
	assert_bool(menu.holds_presses()).is_false()
	assert_bool(await _shown_on(menu, &"games_float")).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _closed(carousel)).is_true()
	assert_bool(carousel._row.games_float).is_true()


## A choice page whose save lasts holds its presses, and two seconds on B goes back to the card, which holds its own
## until the answer; the answer, whenever it comes, is applied: the backdrop kept, or put back when refused.
func test_a_page_whose_save_lasts_is_left_with_B_after_two_seconds_and_its_answer_applied_when_it_comes(fails: bool,
		_test_parameters := [[false], [true]]) -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.answers[Fixtures.Request.SAVE_BACKDROP] = Fixtures.Answer.HELD
	if fails:
		device.failures[Fixtures.Request.SAVE_BACKDROP] = &"unwritable"
	var carousel := await _press_line(device, "Backdrop")
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	assert_bool(await Fixtures.on(self, carousel, "Backdrop")).is_true()
	await await_idle_frame()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_array(device.saves(&"backdrop")).is_equal([&"dark"])
	assert_str(Backdrop.choice).is_equal("dark")
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_str(Fixtures.shown_screen(carousel).name).is_equal("Backdrop")
	Fixtures.clock.ms += ScreenFlow.HeldSave.ESCAPE_MS
	await Fixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_bool(menu.holds_presses()).is_true()
	_release(device)
	await await_idle_frame()
	assert_bool(menu.holds_presses()).is_false()
	assert_str(Backdrop.choice).is_equal("light" if fails else "dark")
	assert_str(menu.row_of(&"backdrop").shown_value()).is_equal("Light" if fails else "Dark")


## A sounds' level or an edges' smoothing the plugin does not keep is not used either (INV-15).
func test_a_sounds_level_or_a_smoothing_the_plugin_refuses_is_put_back() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.answers[Fixtures.Request.SAVE_SOUND_LEVEL] = Fixtures.Answer.FAILS
	device.answers[Fixtures.Request.SAVE_EDGE_SMOOTHING] = Fixtures.Answer.FAILS
	var carousel := await Fixtures.shown(self, device)
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	var level := Sounds.level
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	while _focused() != "Sounds":
		await Fixtures.action(self, &"ui_down")
	await Fixtures.action(self, &"ui_left")
	assert_array(device.saves(&"sound_level")).is_equal([level - 1])
	assert_int(Sounds.level).is_equal(level)
	assert_int(menu.sound_level).is_equal(level)
	while _focused() != "Graphics":
		await Fixtures.action(self, &"ui_up")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await Fixtures.on(self, carousel, "EdgeSmoothing")).is_true()
	await await_idle_frame()
	await Fixtures.action(self, &"ui_right")
	await Fixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_array(device.saves(&"edge_smoothing")).is_equal([&"2x"])
	assert_int(get_viewport().msaa_3d).is_equal(Viewport.MSAA_4X)


func test_one_push_of_the_stick_on_the_sounds_line_moves_the_level_by_one_step() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await Fixtures.shown(self, device)
	var level := Sounds.level
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	while _focused() != "Sounds":
		await Fixtures.action(self, &"ui_down")
	for value: float in [-0.6, -1.0, 0.0]:
		var stick := InputEventJoypadMotion.new()
		stick.axis = JOY_AXIS_LEFT_X
		stick.axis_value = value
		Input.parse_input_event(stick)
		Input.flush_buffered_events()
		await await_idle_frame()
	assert_array(device.saves(&"sound_level")).is_equal([level - 1])
	assert_str(_focused()).is_equal("Sounds")


func test_a_tap_on_the_sounds_level_moves_it_one_step_that_way_and_saves_each_step() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	var carousel := await Fixtures.shown(self, device)
	var menu: SettingsMenu = carousel.get_node("%Screens/Settings")
	var level := Sounds.level
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await _tap(menu.arrow_point(1))
	await _tap(menu.arrow_point(1))
	await _tap(menu.level_point(-1))
	await _tap(menu.level_point(-1))
	assert_str(_focused()).is_equal("Sounds")
	assert_int(menu.sound_level).is_equal(level - 2)
	await _tap(menu.level_point(1))
	assert_array(device.saves(&"sound_level")).is_equal([level - 1, level - 2, level - 1])
	assert_int(Sounds.level).is_equal(level - 1)


func _card_texts(page: CardChoiceScreen) -> PackedStringArray:
	var texts := PackedStringArray()
	for card: Button in page._cards.get_children():
		texts.append(card.text)
	return texts


## The settings close as the stick is let go: the card takes its release, and the next push steps the consoles.
func test_a_stick_let_go_as_the_settings_close_steps_the_consoles_at_its_next_push() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3, "gc": 1}))
	var shelf := carousel._shelf
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	await _stick_x(0.8)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _stick_x(0.0)
	assert_bool(await _closed(carousel)).is_true()
	await _stick_x(0.8)
	await _stick_x(0.0)
	assert_int(carousel._shelf).is_not_equal(shelf)


## The left stick's horizontal axis at [param value], through the whole input path.
func _stick_x(value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = value
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	await await_idle_frame()


func test_a_stick_pushed_once_moves_the_focus_one_line_its_strength_wavering_about_the_dead_zone() -> void:
	var carousel := await Fixtures.shown(self, Fixtures.past_first_launch(self, {"ps2": 3}))
	await Fixtures.joypad(self, JOY_BUTTON_Y)
	assert_bool(await _settings_ready(carousel)).is_true()
	assert_str(_focused()).is_equal("ButtonStyle")
	for value: float in [0.1, 0.3, 0.49, 0.51, 0.49, 0.52, 1.0, 0.52, 0.49, 0.51, 0.3, 0.0]:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_Y
		motion.axis_value = value
		Input.parse_input_event(motion)
		Input.flush_buffered_events()
		await await_idle_frame()
	assert_str(_focused()).is_equal("Graphics")
