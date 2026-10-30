# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const TITLES := [
	"Ace Combat Distant Thunder", "Ace Combat Zero", "Bouncer", "Burnout Takedown", "Combat Ace", "Dark Cloud",
	"Distant Water", "Ico", "Katamari Damacy", "Nights into Dreams", "Nuages", "Nuit Blanche", "Okami", "Shadow Hearts",
	"Silent Hill", "Zone of the Enders",
]
const REGIONS := ["Europe", "USA", "Japan"]


## The games screen of a shelf of [param titles], and the next console's of [param next_titles],
## searched by [FakeSearch].
func _games_screen(titles: Array = TITLES, next_titles: Array = ["Rez", "Rygar", "Wild Arms"]) -> Carousel:
	var carousel := await Fixtures.shown_carousel(self)
	var search: FakeSearch = auto_free(FakeSearch.new())
	carousel._search.android = search
	for at: int in [carousel._shelf, (carousel._shelf + 1) % carousel._shelves.size()]:
		var shelf := carousel._shelves[at]
		var shown: Array = titles if at == carousel._shelf else next_titles
		# On the medium the library showed the shelf's games in.
		var medium := shelf.games[0].medium
		shelf.games.clear()
		for i in shown.size():
			shelf.games.append(AndroidServices.Game.new({
				"id": "%s/%d" % [shelf.platform_id, i], "platform_id": shelf.platform_id, "title": shown[i], "identified": false,
				"regions": [REGIONS[i % 3]], "medium": medium, "discs": [{"name": "%s.iso" % shown[i]}], "last_disc": 0,
			}))
		search.shelves[shelf.platform_id] = shelf.games
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
		var at := GameSearch.KEYS.find(key)
		for i in GameSearch.KEYS.length():
			if carousel._search._cursor == at:
				break
			_press_direction(carousel, &"carousel_right" if at > carousel._search._cursor else &"carousel_left")
		assert_int(carousel._search._cursor).is_equal(at)
		Fixtures.press(carousel, &"open_settings" if key == GameSearch.SPACE else &"ui_accept")


func _press_direction(carousel: Carousel, action: StringName) -> void:
	carousel._unhandled_input(Fixtures.button(action, true))
	carousel._unhandled_input(Fixtures.button(action, false))


func test_down_opens_the_ribbon_on_the_letter_shown_and_left_and_right_jump_the_carousel_letter_by_letter() -> void:
	var carousel := await _games_screen()
	assert_str(_shown(carousel)).is_equal("Ace Combat Distant Thunder")
	Fixtures.press(carousel, &"ui_down")
	assert_bool(carousel._search.is_open()).is_true()
	assert_str(GameSearch.KEYS[carousel._search._cursor]).is_equal("a")
	_press_direction(carousel, &"carousel_right")
	assert_str(GameSearch.KEYS[carousel._search._cursor]).is_equal("b")
	assert_str(_shown(carousel)).is_equal("Bouncer")
	# "E" has no title but "Enders" starts with it: its key is lit and goes on to the next letter.
	_press_direction(carousel, &"carousel_right")
	_press_direction(carousel, &"carousel_right")
	_press_direction(carousel, &"carousel_right")
	assert_str(GameSearch.KEYS[carousel._search._cursor]).is_equal("e")
	assert_str(_shown(carousel)).is_equal("Ico")
	# Down again, by region: the carousel keeps the games of the shown game's region only, still on it,
	# and each region's alone as the cursor moves.
	Fixtures.press(carousel, &"ui_down")
	assert_bool(carousel._search._by_region).is_true()
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
	assert_int(carousel._row._games.size()).is_equal(TITLES.size())
	assert_bool(carousel._search.is_filtered()).is_false()


## The first region of each game the carousel shows, each once.
func _regions_shown(carousel: Carousel) -> Array[String]:
	var regions: Array[String] = []
	for game in carousel._row._games:
		if game.regions[0] not in regions:
			regions.append(game.regions[0])
	return regions


func test_once_keys_are_typed_no_hint_names_l1_or_r1() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	_type(carousel, "a")
	for hint: ButtonHint in carousel._search._hints.get_children():
		assert_array([hint.button]).not_contains([&"l1", &"r1"])


func test_typing_keeps_only_the_games_found_any_word_in_any_order_the_chip_telling_how_many() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	_type(carousel, "dist ace")
	assert_array(_shown_titles(carousel)).is_equal(["Ace Combat Distant Thunder"])
	var chip: Label = carousel._search.get_node("%Count")
	assert_str(chip.text).is_equal("1 game")
	assert_str((carousel._search.get_node("%Typed") as Label).text).is_equal("dist ace")
	assert_array(carousel._title_marks.marks).is_equal([Vector2i(0, 3), Vector2i(11, 4)])
	for i in 8:
		Fixtures.press(carousel, &"screen_back")
	_type(carousel, "c")
	assert_array(_shown_titles(carousel)).is_equal(["Ace Combat Distant Thunder", "Ace Combat Zero", "Combat Ace", "Dark Cloud"])
	assert_str(chip.text).is_equal("4 games")
	# Keys that would find nothing are skipped: the cursor went to the nearest that does, "l"
	# ("Cloud"), and right goes on to "o" ("Combat").
	assert_str(GameSearch.KEYS[carousel._search._cursor]).is_equal("l")
	_press_direction(carousel, &"carousel_right")
	assert_str(GameSearch.KEYS[carousel._search._cursor]).is_equal("o")


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
	assert_str((carousel._search.get_node("%FilterText") as Label).text).is_equal("“ace” — 3 of %d" % TITLES.size())
	_press_direction(carousel, &"carousel_right")
	assert_str(_shown(carousel)).is_equal("Ace Combat Zero")
	assert_bool(carousel._clear_hint.visible).is_true()
	# Remembered at its place on the shelf, not in what is found.
	carousel._remember()
	assert_int(carousel._positions[carousel._shelves[carousel._shelf].platform_id]).is_equal(TITLES.find("Ace Combat Zero"))
	# Down opens the ribbon again as it was left.
	Fixtures.press(carousel, &"ui_down")
	assert_str((carousel._search.get_node("%Typed") as Label).text).is_equal("ace")
	Fixtures.press(carousel, &"form_submit")
	assert_str(_shown(carousel)).is_equal("Ace Combat Zero")
	Fixtures.press(carousel, &"screen_back")
	assert_int(carousel._screen).is_equal(Carousel.Screen.GAMES)
	assert_bool(carousel._search.is_filtered()).is_false()
	assert_int(carousel._row._games.size()).is_equal(TITLES.size())
	assert_str(_shown(carousel)).is_equal("Ace Combat Distant Thunder")
	assert_bool(carousel._clear_hint.visible).is_false()


func test_l1_and_r1_are_left_free_on_the_games_screen_and_named_by_no_hint() -> void:
	var carousel := await _games_screen()
	var shown := _shown(carousel)
	for action: StringName in [&"next_letter", &"previous_letter"]:
		Fixtures.press(carousel, action)
		assert_str(_shown(carousel)).is_equal(shown)
	assert_bool(carousel._search.is_open()).is_false()
	for hint: ButtonHint in carousel.get_node("GamesHints").get_children():
		assert_array([hint.button]).not_contains([&"l1", &"r1"])


func test_a_key_tapped_is_typed_once_and_the_carousel_behind_does_not_take_the_touch() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	var key: Control = carousel._search.get_node("%Strip").get_child(GameSearch.KEYS.find("s"))
	var shown := _shown(carousel)
	# A tap comes as a touch, then as the click emulated from it, pressed then let go: only the
	# click let go types.
	var touch := InputEventScreenTouch.new()
	key._gui_input(touch)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	key._gui_input(click)
	assert_str(carousel._search.typed()).is_empty()
	assert_str(_shown(carousel)).is_equal(shown)
	click.pressed = false
	key._gui_input(click)
	assert_str(carousel._search.typed()).is_equal("s")
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


func test_a_view_of_another_library_is_set_aside() -> void:
	var carousel := await _games_screen()
	var search: FakeSearch = carousel._search.android
	Fixtures.press(carousel, &"ui_down")
	var shown := _shown(carousel)
	search.count_offset = 1
	Fixtures.press(carousel, &"ui_accept")
	assert_str(carousel._search.typed()).is_empty()
	assert_str(_shown(carousel)).is_equal(shown)
	Fixtures.press(carousel, &"ui_down")
	assert_bool(carousel._search._by_region).is_false()
	Fixtures.press(carousel, &"screen_back")
	# Once the answers are for the shelf again, the index is asked for again.
	search.count_offset = 0
	carousel._show_platform()
	Fixtures.press(carousel, &"ui_down")
	_press_direction(carousel, &"carousel_right")
	assert_str(_shown(carousel)).is_equal("Bouncer")


func test_inv_04_whatever_is_pressed_a_launches_the_game_shown_and_b_out_of_the_ribbon_goes_back_where_it_opened() -> void:
	for titles: Array in [TITLES, ["Ace Combat Zero", "Bouncer", "Combat Ace"]]:
		await _walk(titles)


func _walk(titles: Array) -> void:
	var carousel := await _games_screen(titles)
	var launches: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	launches.check_code = &"not_installed"
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


## Searches a shelf as the core does, plainly: each word typed starts another word of the title,
## in any order; with nothing typed, the index by first letter or by region.
class FakeSearch extends AndroidServices:
	const _ORDER: Array[String] = ["USA", "Europe", "Japan"]

	## Each platform's games, in shelf order.
	var shelves: Dictionary[String, Array] = {}
	## Added to the count of every answer: as if the plugin answered for another library.
	var count_offset := 0
	var _games: Array[AndroidServices.Game] = []
	var _words := RegEx.create_from_string("[a-z0-9]+")

	func browse(platform_id: String, order: StringName, typed: String) -> AndroidServices.Browse:
		_games.assign(shelves[platform_id])
		var by_region := order == &"region" and typed.is_empty()
		var typing := typed.get_slice(" ", typed.get_slice_count(" ") - 1)
		var done: Array[String] = []
		done.assign(Array(typed.split(" ", false)).slice(0, -1 if typing else typed.split(" ", false).size()))
		var prefixes: Array[String] = done.duplicate()
		if typing:
			prefixes.append(typing)
		var order_shown: Array[int] = []
		for i in _games.size():
			order_shown.append(i)
		if by_region:
			order_shown.sort_custom(func(a: int, b: int) -> bool: return _rank(a) < _rank(b))
		var games: Array[int] = []
		var groups: Array[Dictionary] = []
		var keys: Dictionary[String, int] = {}
		for i in order_shown:
			var words := _words_of(_games[i])
			if typed and not _takes(words, prefixes, [] as Array[int]):
				continue
			var first := _games[i].title.left(1).to_upper()
			var label := _games[i].regions[0] if by_region else (first if first >= "A" and first <= "Z" else "#")
			if not typed and (groups.is_empty() or groups[-1]["label"] != label):
				groups.append({"label": label, "start": games.size()})
			if not by_region:
				for w in words.size():
					var taken: Array[int] = [w]
					if words[w].length() > typing.length() and words[w].begins_with(typing) and _takes(words, done, taken):
						var key := words[w][typing.length()]
						if key not in keys:
							keys[key] = games.size()
				if typing and words.size() > done.size() + 1 and " " not in keys:
					keys[" "] = games.size()
			games.append(i)
		if not typed:
			# The index sends each key to its letter's first game, or the next letter's.
			for key in keys:
				keys[key] = groups[0]["start"]
				for group in groups:
					var label: String = group["label"]
					if (label.to_lower() if label != "#" else "~") >= (key if key >= "a" else "~"):
						keys[key] = group["start"]
						break
		return AndroidServices.Browse.new({"count": _games.size() + count_offset, "games": games, "groups": groups, "keys": keys})

	func title_marks(platform_id: String, position: int, typed: String) -> Array[Vector2i]:
		_games.assign(shelves[platform_id])
		var found := _words.search_all(_games[position].title.to_lower())
		var marks: Array[Vector2i] = []
		var taken: Array[int] = []
		for prefix in typed.split(" ", false):
			for w in found.size():
				if w not in taken and found[w].get_string().begins_with(prefix):
					taken.append(w)
					marks.append(Vector2i(found[w].get_start(), prefix.length()))
					break
		marks.sort()
		return marks

	func _rank(game: int) -> int:
		return _ORDER.find(_games[game].regions[0]) * _games.size() + game

	func _words_of(game: AndroidServices.Game) -> Array[String]:
		var words: Array[String] = []
		for found in _words.search_all(game.title.to_lower()):
			if found.get_string() != "the":
				words.append(found.get_string())
		return words

	func _takes(words: Array[String], prefixes: Array[String], taken: Array[int]) -> bool:
		if prefixes.is_empty():
			return true
		for w in words.size():
			var more: Array[int] = taken.duplicate()
			more.append(w)
			if w not in taken and words[w].begins_with(prefixes[0]) and _takes(words, prefixes.slice(1), more):
				return true
		return false


func test_erasing_a_key_brings_the_cursor_back_on_it() -> void:
	var carousel := await _games_screen()
	Fixtures.press(carousel, &"ui_down")
	_type(carousel, "di")
	Fixtures.press(carousel, &"screen_back")
	assert_str(GameSearch.KEYS[carousel._search._cursor]).is_equal("i")
	Fixtures.press(carousel, &"screen_back")
	assert_str(GameSearch.KEYS[carousel._search._cursor]).is_equal("d")
