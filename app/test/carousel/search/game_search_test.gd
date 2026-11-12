# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const Recorded := preload("res://test/carousel/search/recorded.gd")
## One push of a stick, its strength wavering about the dead zone on the way out and back.
const _PUSH: Array[float] = [0.1, 0.3, 0.45, 0.51, 0.49, 0.52, 0.7, 1.0, 1.0, 0.7, 0.52, 0.48, 0.51, 0.3, 0.0]


func _titles(shelf_name := "main") -> Array:
	return Recorded.shelf(shelf_name)["titles"]


## The games screen of the recorded shelf [param shelf_name], and the next console's shelf [param next], searched as the core
## answered.
func _games_screen(shelf_name := "main", next := "next") -> Carousel:
	var carousel := await Fixtures.shown_carousel(self)
	var search: RecordedSearch = auto_free(RecordedSearch.new())
	carousel._search.android = search
	for at: int in [carousel._shelf, (carousel._shelf + 1) % carousel._shelves.size()]:
		var shelf := carousel._shelves[at]
		var recorded := Recorded.shelf(shelf_name if at == carousel._shelf else next)
		var shown: Array = recorded["titles"]
		# On the medium the library showed the shelf's games in.
		var medium := shelf.games[0].medium
		shelf.games.clear()
		for i in shown.size():
			shelf.games.append(AndroidServices.Game.new({
				"id": "%s/%d" % [shelf.platform_id, i], "platform_id": shelf.platform_id, "title": shown[i],
				"regions": [recorded["regions"][i]], "medium": medium, "last_disc": 0,
			}))
		search.shelves[shelf.platform_id] = recorded
		carousel._positions[shelf.platform_id] = 0
	carousel._show_platform()
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_until(carousel, Carousel.Screen.GAMES)
	return carousel


func _shown(carousel: Carousel) -> String:
	return carousel._row.selected_game().title


func _shown_titles(carousel: Carousel) -> Array[String]:
	var titles: Array[String] = []
	for game in carousel._row._games:
		titles.append(game.title)
	return titles


## Moves the ribbon's cursor to [param key] with left and right, then types it with A.
func _type(carousel: Carousel, typed: String) -> void:
	for key in typed:
		var at := SearchModel.KEYS.find(key)
		for i in SearchModel.KEYS.length():
			if carousel._search._model.cursor == at:
				break
			_press_direction(carousel, &"carousel_right" if at > carousel._search._model.cursor else &"carousel_left")
		assert_int(carousel._search._model.cursor).is_equal(at)
		Fixtures.press(carousel, &"open_settings" if key == SearchModel.SPACE else &"ui_accept")


func _press_direction(carousel: Carousel, action: StringName) -> void:
	carousel._unhandled_input(Fixtures.button(action, true))
	carousel._unhandled_input(Fixtures.button(action, false))


func test_down_opens_the_ribbon_on_the_letter_shown_and_left_and_right_jump_the_carousel_letter_by_letter() -> void:
	var carousel := await _games_screen()
	assert_str(_shown(carousel)).is_equal("Ace Combat Distant Thunder")
	Fixtures.press(carousel, &"ui_down")
	assert_bool(carousel._search.is_open()).is_true()
	assert_str(SearchModel.KEYS[carousel._search._model.cursor]).is_equal("a")
	_press_direction(carousel, &"carousel_right")
	assert_str(SearchModel.KEYS[carousel._search._model.cursor]).is_equal("b")
	assert_str(_shown(carousel)).is_equal("Bouncer")
	# "E" has no title but "Enders" starts with it: its key is lit and goes on to the next letter.
	_press_direction(carousel, &"carousel_right")
	_press_direction(carousel, &"carousel_right")
	_press_direction(carousel, &"carousel_right")
	assert_str(SearchModel.KEYS[carousel._search._model.cursor]).is_equal("e")
	assert_str(_shown(carousel)).is_equal("Ico")
	# Down again, by region: the carousel keeps the games of the shown game's region only, still on it,
	# and each region's alone as the cursor moves.
	Fixtures.press(carousel, &"ui_down")
	assert_bool(carousel._search._model.by_region).is_true()
	assert_str(_shown(carousel)).is_equal("Ico")
	assert_str(carousel._row.selected_game().regions[0]).is_equal("USA")
	assert_array(_regions_shown(carousel)).is_equal(["USA"])
	_press_direction(carousel, &"carousel_right")
	assert_array(_regions_shown(carousel)).is_equal(["Europe"])
	assert_int(carousel._search.shown_position()).is_equal(carousel._search._shelf.find(carousel._row.selected_game()))
	# Within a region, the carousel turns among its games only.
	for step in carousel._row._games.size() + 1:
		carousel._row.step(1)
		assert_str(carousel._row.selected_game().regions[0]).is_equal("Europe")
	# B closes it, back on the game shown before it opened, the shelf in title order.
	Fixtures.press(carousel, &"screen_back")
	assert_bool(carousel._search.is_open()).is_false()
	assert_str(_shown(carousel)).is_equal("Ace Combat Distant Thunder")
	assert_int(carousel._row._games.size()).is_equal(_titles().size())
	assert_bool(carousel._search.is_filtered()).is_false()


## The first region of each game the carousel shows, each once.
func _regions_shown(carousel: Carousel) -> Array[String]:
	var regions: Array[String] = []
	for game in carousel._row._games:
		if game.regions[0] not in regions:
			regions.append(game.regions[0])
	return regions


func test_typing_keeps_only_the_games_found_any_word_in_any_order_the_chip_telling_how_many() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	_type(carousel, "dist ace")
	assert_array(_shown_titles(carousel)).is_equal(["Ace Combat Distant Thunder"])
	var chip: Label = carousel._search.get_node("%Count")
	assert_str(chip.text).is_equal("1 game")
	assert_str((carousel._search.get_node("%Typed") as Label).text).is_equal("dist ace")
	assert_array(carousel._title_marks.marks).is_equal([Vector2i(0, 3), Vector2i(11, 4)])
	# Erasing a key brings the cursor back on it.
	Fixtures.press(carousel, &"screen_back")
	assert_str(SearchModel.KEYS[carousel._search._model.cursor]).is_equal("e")
	for i in 7:
		Fixtures.press(carousel, &"screen_back")
	_type(carousel, "c")
	assert_array(_shown_titles(carousel)).is_equal(["Ace Combat Distant Thunder", "Ace Combat Zero", "Combat Ace", "Dark Cloud"])
	assert_str(chip.text).is_equal("4 games")
	# Keys that would find nothing are skipped: the cursor went to the nearest that does, "l"
	# ("Cloud"), and right goes on to "o" ("Combat").
	assert_str(SearchModel.KEYS[carousel._search._model.cursor]).is_equal("l")
	_press_direction(carousel, &"carousel_right")
	assert_str(SearchModel.KEYS[carousel._search._model.cursor]).is_equal("o")


func test_once_keys_are_typed_l1_and_r1_go_from_one_key_that_still_finds_a_game_to_the_next() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	_type(carousel, "n")
	assert_array(_shown_titles(carousel)).is_equal(["Nights into Dreams", "Nuages", "Nuit Blanche"])
	var seen: Array[String] = []
	for i in 3:
		Fixtures.press(carousel, &"next_letter")
		seen.append((carousel._search.get_node("%BigText") as Label).text)
		assert_str(_shown(carousel).to_upper()).starts_with(seen[-1])
	assert_array(seen).is_equal(["NU", "NI", "NU"])
	Fixtures.press(carousel, &"previous_letter")
	assert_str((carousel._search.get_node("%BigText") as Label).text).is_equal("NI")
	# A types the key L1 and R1 led to.
	Fixtures.press(carousel, &"ui_accept")
	assert_array(_shown_titles(carousel)).is_equal(["Nights into Dreams"])


func test_up_keeps_what_is_found_told_at_the_top_and_b_clears_it_back_on_the_game_shown_when_typing_began() -> void:
	var carousel := await _games_screen()
	_press_direction(carousel, &"carousel_right")
	_press_direction(carousel, &"carousel_right")
	assert_str(_shown(carousel)).is_equal("Bouncer")
	Fixtures.press(carousel, &"ui_down")
	# Going to "a" on the index brings the carousel back to the first A.
	_type(carousel, "ace")
	assert_array(_shown_titles(carousel)).is_equal(["Ace Combat Distant Thunder", "Ace Combat Zero", "Combat Ace"])
	assert_str(_shown(carousel)).is_equal("Ace Combat Distant Thunder")
	Fixtures.press(carousel, &"ui_up")
	assert_bool(carousel._search.is_open()).is_false()
	assert_bool((carousel._search.get_node("%Filter") as Control).visible).is_true()
	assert_str((carousel._search.get_node("%FilterText") as Label).text).is_equal("“ace” — 3 of %d" % _titles().size())
	_press_direction(carousel, &"carousel_right")
	assert_str(_shown(carousel)).is_equal("Ace Combat Zero")
	assert_bool(carousel._clear_hint.visible).is_true()
	# Remembered at its place on the shelf, not in what is found.
	carousel._remember()
	assert_int(carousel._positions[carousel._shelves[carousel._shelf].platform_id]).is_equal(_titles().find("Ace Combat Zero"))
	# Down opens the ribbon again as it was left.
	Fixtures.press(carousel, &"ui_down")
	assert_str((carousel._search.get_node("%Typed") as Label).text).is_equal("ace")
	Fixtures.press(carousel, &"form_submit")
	assert_str(_shown(carousel)).is_equal("Ace Combat Zero")
	Fixtures.press(carousel, &"screen_back")
	assert_int(carousel._screen).is_equal(Carousel.Screen.GAMES)
	assert_bool(carousel._search.is_filtered()).is_false()
	assert_int(carousel._row._games.size()).is_equal(_titles().size())
	assert_str(_shown(carousel)).is_equal("Ace Combat Distant Thunder")
	assert_bool(carousel._clear_hint.visible).is_false()


func test_l1_and_r1_are_left_free_on_the_games_screen() -> void:
	var carousel := await _games_screen()
	var shown := _shown(carousel)
	for action: StringName in [&"next_letter", &"previous_letter"]:
		Fixtures.press(carousel, action)
		assert_str(_shown(carousel)).is_equal(shown)
	assert_bool(carousel._search.is_open()).is_false()


func test_a_key_tapped_is_typed_once_and_the_carousel_behind_does_not_take_the_touch() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	var key: Control = carousel._search.get_node("%Strip").get_child(SearchModel.KEYS.find("s"))
	var shown := _shown(carousel)
	# A tap comes as a touch, then as the click emulated from it, pressed then let go: only the
	# click let go types.
	var touch := InputEventScreenTouch.new()
	key._gui_input(touch)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	key._gui_input(click)
	var typed: Label = carousel._search.get_node("%Typed")
	assert_str(typed.text).is_empty()
	assert_str(_shown(carousel)).is_equal(shown)
	click.pressed = false
	key._gui_input(click)
	assert_str(typed.text).is_equal("s")
	assert_array(_shown_titles(carousel)).is_equal(["Shadow Hearts", "Silent Hill"])
	assert_bool(carousel._touchable()).is_false()


func test_the_ribbon_searches_the_console_shown_and_a_new_shelf_closes_it() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	_type(carousel, "s")
	for i in 3:
		Fixtures.press(carousel, &"screen_back")
	Fixtures.step_until(carousel, Carousel.Screen.CONSOLES)
	_press_direction(carousel, &"carousel_right")
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_until(carousel, Carousel.Screen.GAMES)
	assert_str(_shown(carousel)).is_equal("Rez")
	Fixtures.press(carousel, &"ui_down")
	_press_direction(carousel, &"carousel_right")
	assert_str(_shown(carousel)).is_equal("Wild Arms")
	# A shelf shown again (a library sent anew) closes the ribbon, the games coming back down.
	var closed: Array[bool] = []
	carousel._search.opened.connect(func(open: bool) -> void: closed.append(not open))
	carousel._show_platform()
	assert_bool(carousel._search.is_open()).is_false()
	assert_array(closed).is_equal([true])


func test_inv_04_whatever_is_pressed_a_launches_the_game_shown_and_b_out_of_the_ribbon_goes_back_where_it_opened() -> void:
	for shelf_name: String in ["main", "small"]:
		await _walk(shelf_name)


func _walk(shelf_name: String) -> void:
	var carousel := await _games_screen(shelf_name)
	var launches: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	launches.failures[Fixtures.Request.CHECK_LAUNCH] = &"not_installed"
	var launched: Array[String] = []
	launches.on_check = func(game: AndroidServices.Game) -> void: launched.append(game.title)
	carousel._game_launch.android = launches
	var random := Fixtures.cases(93)
	var buttons: Array[StringName] = [&"carousel_left", &"carousel_right", &"ui_accept", &"screen_back", &"ui_up", &"ui_down",
		&"form_submit", &"previous_letter", &"next_letter", &"open_settings"]
	var opened_on := ""
	var backs := 0
	var launches_checked := 0
	var filtered_launches := 0
	for i in 1500:
		if carousel._screen != Carousel.Screen.GAMES:
			Fixtures.step_until(carousel, Carousel.Screen.CONSOLES)
			Fixtures.press(carousel, &"ui_accept")
			Fixtures.step_until(carousel, Carousel.Screen.GAMES)
		var was_open := carousel._search.is_open()
		var was_filtered := carousel._search.is_filtered()
		var shown := _shown(carousel)
		var button := buttons[random.randi_range(0, buttons.size() - 1)]
		# Y out of the ribbon opens the settings, over the carousel: not this test's.
		if button == &"open_settings" and not was_open:
			continue
		if button in [&"carousel_left", &"carousel_right"]:
			_press_direction(carousel, button)
		else:
			Fixtures.press(carousel, button)
		Fixtures.step_frame(carousel)
		# Up out of the ribbon tosses the game: the walk goes on once it lands.
		while carousel._toss.is_busy():
			Fixtures.step_frame(carousel)
		# The pill names the game in the middle, one of the shelf's.
		assert_str((carousel._title as Label).text).is_equal(_shown(carousel))
		assert_bool(carousel._row.selected_game() in carousel._shelves[carousel._shelf].games).is_true()
		if carousel._search.is_open() and not was_open and not was_filtered:
			opened_on = shown
		if button == &"screen_back" and was_open and not carousel._search.is_open() and opened_on:
			assert_str(_shown(carousel)).is_equal(opened_on)
			backs += 1
		if button == &"ui_accept" and not was_open and carousel._screen == Carousel.Screen.GAMES:
			assert_int(launched.size()).is_equal(launches_checked + 1)
			assert_str(launched[-1]).is_equal(shown)
			launches_checked += 1
			filtered_launches += 1 if was_filtered else 0
	assert_int(backs).is_greater(10)
	assert_int(launches_checked).is_greater(10)
	assert_int(filtered_launches).is_greater(4)

## The left stick moved to [param value] along [param axis], through the whole input path.
func _stick(carousel: Carousel, axis: JoyAxis, value: float) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	Fixtures.step_frames(carousel, 1)


func test_a_stick_pushed_once_opens_the_ribbon_then_moves_its_cursor_one_letter_like_the_d_pad() -> void:
	var carousel := await _games_screen()
	for value in _PUSH:
		_stick(carousel, JOY_AXIS_LEFT_Y, value)
	assert_bool(carousel._search.is_open()).is_true()
	assert_bool(carousel._search._model.by_region).is_false()
	var cursor := carousel._search._model.cursor
	for value in _PUSH:
		_stick(carousel, JOY_AXIS_LEFT_X, value)
	assert_int(carousel._search._model.cursor).is_equal(cursor + 1)


## What the core answered for each query, by platform: [method browse] and [method title_marks] read them from the
## recording, and a query it never made stops the test.
class RecordedSearch extends AndroidServices:
	## Each platform's recorded shelf.
	var shelves: Dictionary[String, Dictionary] = {}

	func browse(platform_id: String, order: StringName, typed: String) -> AndroidServices.Browse:
		return Recorded.browse(shelves[platform_id], order, typed)

	func title_marks(platform_id: String, position: int, typed: String) -> Array[Vector2i]:
		var marks: Array[Vector2i] = []
		var by_query: Dictionary = shelves[platform_id]["marks"]
		var by_position: Dictionary = by_query.get(typed, {})
		assert(typed.is_empty() or by_position.has(str(position)),
			"the core was never asked for marks of '%s' at %d: record it in RecordedSearchesTest" % [typed, position])
		var found: Dictionary = by_position.get(str(position), {})
		for mark in AndroidWire.Marks.new(found).marks:
			marks.append(Vector2i(mark.start, mark.length))
		return marks
