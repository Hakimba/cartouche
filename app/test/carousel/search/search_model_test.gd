# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## [SearchModel] on the shelves the core recorded: no scene, no node. A walk keeps what the model tells the row to
## show; the recording says what must be found.

const Recorded := preload("res://test/carousel/search/recorded.gd")
const Kind := SearchModel.Kind
## How many keys from nothing typed the recording follows a ribbon for (`DEPTH` of RecordedSearchesTest): the walk
## types no further.
const DEPTH := 3
const SHELVES: Array[String] = ["main", "small", "next"]
const STEPS := 4000
## Each state the walk must stand in, and each sound it must hear, at least this many times of [constant STEPS].
const REACHED := 100

var _recorded: Dictionary
## Added to the count of every answer: as if the plugin answered for another library.
var _count_offset := 0
## How many times the index by title was asked for.
var _indexes_asked := 0


func _asks(order: StringName, typed: String) -> AndroidServices.Browse:
	_indexes_asked += int(order == &"title" and typed.is_empty())
	return Recorded.browse(_recorded, order, typed, _count_offset)


## A walk of the recorded shelf [param shelf_name], drawn by [param walk_seed].
func _walk(shelf_name: String, walk_seed: int) -> Walk:
	_recorded = Recorded.shelf(shelf_name)
	_count_offset = 0
	var titles: Array = _recorded["titles"]
	return Walk.new(SearchModel.new(_asks), titles.size(), walk_seed)


## The shelf positions the row must show for what [param model] is on, in the shelf's order, as the recording has
## them: the games found for what is typed, by region those of the region of [param shown]'s first game, else all.
func _found(model: SearchModel, shown: PackedInt32Array) -> PackedInt32Array:
	if not model.typed.is_empty():
		var found := Recorded.browse(_recorded, &"title", model.typed).games
		found.sort()
		return found
	var regions: Array = _recorded["regions"]
	var positions := PackedInt32Array()
	for position in regions.size():
		if not model.by_region or regions[position] == regions[shown[0]]:
			positions.append(position)
	return positions


func test_whatever_is_pressed_the_row_shows_the_games_found_and_the_place_of_each_on_the_shelf_is_told() -> void:
	for shelf_name in SHELVES:
		var walk := _walk(shelf_name, 41)
		var model := walk.model
		var titles: Array = _recorded["titles"]
		var seen: Dictionary[String, int] = {"typed": 0, "by region": 0, "kept": 0}
		var tapped_regions := 0
		for i in STEPS:
			walk.step()
			var wrong := ""
			var in_order := walk.shown.duplicate()
			in_order.sort()
			if in_order != _found(model, walk.shown):
				wrong = "the row shows %s" % walk.shown
			for at in walk.shown.size():
				if model.shown_position(at) != walk.shown[at]:
					wrong = "the game at %d is told at %d, shown from %d" % [at, model.shown_position(at), walk.shown[at]]
			if model.by_region and not model.typed.is_empty():
				wrong = "keys typed by region"
			# A region tapped shows that region's games, as the core grouped them.
			if walk.done == "tap" and model.by_region:
				tapped_regions += 1
				var regions := Recorded.browse(_recorded, &"region", "")
				var region := walk.tapped
				var end := regions.groups[region + 1].start if region + 1 < regions.groups.size() else regions.games.size()
				if walk.shown != regions.games.slice(regions.groups[region].start, end):
					wrong = "the region %d tapped shows %s" % [region, walk.shown]
			# Keys that would find nothing are skipped: the cursor is on one that leads somewhere while any does.
			var lit := Recorded.browse(_recorded, &"title", model.typed).keys
			if model.open and not model.by_region and not lit.is_empty() and SearchModel.KEYS[model.cursor] not in lit:
				wrong = "the cursor is on '%s', which finds nothing" % SearchModel.KEYS[model.cursor]
			# Opened on the whole shelf, or back from the regions, it is on the letter of the game shown.
			var title: String = titles[walk.shown[walk.index]]
			if (walk.done == "open" or walk.done == "ui_down") and not model.is_filtered() \
					and SearchModel.KEYS[model.cursor] != title.left(1).to_lower():
				wrong = "the cursor is on '%s', the game shown is %s" % [SearchModel.KEYS[model.cursor], title]
			assert_str(wrong).override_failure_message("%s, step %d, %s: %s" % [shelf_name, i, walk.done, wrong]).is_empty()
			seen["typed"] += int(not model.typed.is_empty())
			seen["by region"] += int(model.by_region)
			seen["kept"] += int(model.is_filtered() and not model.open)
		for state in seen:
			assert_int(seen[state]).override_failure_message("%s: %s for %d steps" % [shelf_name, state, seen[state]]) \
				.is_greater(REACHED)
		assert_int(tapped_regions).override_failure_message("%s: no region tapped" % shelf_name).is_greater(0)


func test_b_out_of_the_ribbon_goes_back_where_it_opened_and_up_start_and_a_by_region_keep_what_is_found() -> void:
	for shelf_name in SHELVES:
		var walk := _walk(shelf_name, 67)
		var model := walk.model
		var opened_on := 0
		var checked: Dictionary[String, int] = {"back": 0, "kept": 0}
		for i in STEPS:
			walk.step()
			var on := walk.shown[walk.index]
			var wrong := ""
			if walk.done == "open" and not walk.was_filtered:
				opened_on = walk.was_on
			if walk.was_open and not model.open and walk.done == "screen_back":
				checked["back"] += 1
				if on != opened_on or model.is_filtered() or walk.shown.size() != walk.size:
					wrong = "B left the ribbon on %d of %d games, opened on %d" % [on, walk.shown.size(), opened_on]
			elif walk.was_open and (walk.done in ["ui_up", "form_submit"] or (walk.done == "ui_accept" and model.by_region)):
				checked["kept"] += 1
				if model.open or on != walk.was_on or walk.shown.size() != walk.was_showing \
						or model.is_filtered() != walk.was_filtered:
					wrong = "left on %d of %d games, was on %d of %d" % [on, walk.shown.size(), walk.was_on, walk.was_showing]
			assert_str(wrong).override_failure_message("%s, step %d, %s: %s" % [shelf_name, i, walk.done, wrong]).is_empty()
		for case in checked:
			assert_int(checked[case]).override_failure_message("%s: %s %d times" % [shelf_name, case, checked[case]]) \
				.is_greater(REACHED)


func test_the_game_shown_stays_while_it_is_found_else_the_next_on_the_shelf_and_no_key_left_goes_back_where_typing_began() -> void:
	for shelf_name in SHELVES:
		var walk := _walk(shelf_name, 73)
		var model := walk.model
		var home := 0
		var checked: Dictionary[String, int] = {"typed": 0, "erased": 0, "cleared": 0, "region": 0, "region cleared": 0}
		for i in STEPS:
			var effects := walk.step()
			var on := walk.shown[walk.index]
			var whole := not model.is_filtered() and walk.shown.size() == walk.size
			var wrong := ""
			if walk.was_typed.is_empty() and not model.typed.is_empty():
				home = walk.was_on
			if model.typed != walk.was_typed and not model.typed.is_empty():
				checked["typed"] += 1
				if on != _kept(walk.was_on, walk.shown):
					wrong = "on %d of %s, was on %d" % [on, walk.shown, walk.was_on]
			elif model.typed != walk.was_typed:
				checked["cleared" if walk.done == "clear" else "erased"] += 1
				if on != home or not whole:
					wrong = "on %d of %d games, typing began on %d" % [on, walk.shown.size(), home]
			elif walk.done == "clear":
				checked["region cleared"] += 1
				if on != walk.was_on or not whole:
					wrong = "on %d of %d games, the region was left on %d" % [on, walk.shown.size(), walk.was_on]
			elif walk.done == "ui_down" and not effects.is_empty():
				checked["region"] += 1
				if on != walk.was_on:
					wrong = "on %d under the other index, was on %d" % [on, walk.was_on]
			assert_str(wrong).override_failure_message("%s, step %d, %s: %s" % [shelf_name, i, walk.done, wrong]).is_empty()
		for case in checked:
			assert_int(checked[case]).override_failure_message("%s: %s %d times" % [shelf_name, case, checked[case]]) \
				.is_greater(10)


## The shelf position the row must be on once it shows [param shown] (in the shelf's order), having been on
## [param was_on]: that game if it is still shown, else the first one after it on the shelf, else the last.
func _kept(was_on: int, shown: PackedInt32Array) -> int:
	for position in shown:
		if position >= was_on:
			return position
	return shown[-1]


func test_a_press_is_heard_first_moves_the_row_once_and_a_search_s_sound_tells_the_games_before_and_found() -> void:
	for shelf_name in SHELVES:
		var walk := _walk(shelf_name, 89)
		var narrowed := 0
		for i in STEPS:
			var effects := walk.step()
			var wrong := ""
			var row_moved := -1
			for at in effects.size():
				var effect := effects[at]
				if effect.kind in [Kind.SOUND, Kind.NARROWING]:
					if at > 0:
						wrong = "a sound after something else"
				elif effect.kind in [Kind.SHOW, Kind.JUMP]:
					if row_moved >= 0:
						wrong = "the row moved twice"
					row_moved = at
				if effect.kind == Kind.NARROWING:
					narrowed += 1
					if effect.before != walk.was_showing or effect.found != walk.shown.size():
						wrong = "heard from %d games to %d, shown from %d to %d" % [effect.before, effect.found,
							walk.was_showing, walk.shown.size()]
			assert_str(wrong).override_failure_message("%s, step %d, %s: %s" % [shelf_name, i, walk.done, wrong]).is_empty()
		assert_int(narrowed).is_greater(REACHED)


func test_a_view_of_another_library_is_set_aside_and_the_index_by_title_is_asked_for_once_per_shelf() -> void:
	var walk := _walk("main", 0)
	var model := walk.model
	_indexes_asked = 0
	model.open_at(0)
	_count_offset = 1
	assert_array(model.press(&"ui_accept", 0)).is_empty()
	assert_str(model.typed).is_empty()
	assert_array(model.press(&"ui_down", 0)).is_empty()
	assert_bool(model.by_region).is_false()
	model.press(&"screen_back", 0)
	assert_int(_indexes_asked).is_equal(1)
	# Once the answers are for the shelf again, the index is asked for again.
	_count_offset = 0
	model.use_shelf(walk.size)
	model.open_at(0)
	assert_int(_indexes_asked).is_equal(2)
	var effects := model.move(1)
	var titles: Array = _recorded["titles"]
	assert_str(titles[effects[-1].at]).is_equal("Bouncer")


func test_opened_while_the_answers_are_for_another_library_no_key_is_lit_and_left_and_right_jump_nowhere() -> void:
	var walk := _walk("main", 0)
	var model := walk.model
	_count_offset = 1
	model.open_at(0)
	for key in SearchModel.KEYS:
		assert_bool(model.is_lit(key)).override_failure_message("'%s' lit" % key).is_false()
	for effect in model.move(1):
		assert_int(effect.kind).is_not_equal(Kind.JUMP)


func test_an_erased_key_answered_for_another_library_leaves_the_cursor_where_it_was() -> void:
	var walk := _walk("main", 0)
	var model := walk.model
	model.open_at(0)
	model.press(&"ui_accept", 0)
	model.press(&"ui_accept", 0)
	model.move(1)
	var cursor := model.cursor
	assert_int(cursor).is_not_equal(SearchModel.KEYS.find(model.typed[-1]))
	_count_offset = 1
	assert_array(model.press(&"screen_back", 0)).is_empty()
	assert_int(model.cursor).is_equal(cursor)


## A seeded walk of one shelf: every press, a held direction and a tap while the ribbon is open; down, B to clear and
## steps of the row while it is closed. It keeps what the model tells the row to show.
class Walk:
	var model: SearchModel
	var random := RandomNumberGenerator.new()
	var size: int
	## Shelf positions of the games the row shows, and its selected index.
	var shown: PackedInt32Array
	var index := 0
	## What the last step did, and how things stood before it: the ribbon open, a part of the shelf shown, what was
	## typed, how many games the row showed, the shelf position of the one in its middle.
	var done := ""
	var was_open := false
	var was_filtered := false
	var was_typed := ""
	var was_showing := 0
	var was_on := 0
	## The key (or, by region, the group) the last tap was on.
	var tapped := -1

	func _init(searched: SearchModel, games: int, walk_seed: int) -> void:
		model = searched
		size = games
		random.seed = walk_seed
		shown = PackedInt32Array(range(games))
		model.use_shelf(games)

	## One step, drawn; returns what the model answered.
	func step() -> Array[SearchModel.Effect]:
		done = "nothing"
		was_open = model.open
		was_filtered = model.is_filtered()
		was_typed = model.typed
		was_showing = shown.size()
		was_on = shown[index]
		var effects: Array[SearchModel.Effect] = []
		var drawn := random.randf()
		var may_type := model.by_region or model.typed.length() < DEPTH
		if not model.open:
			if drawn < 0.5:
				done = "open"
				model.open_at(index)
			elif drawn < 0.7 and model.is_filtered():
				done = "clear"
				effects = model.clear(index)
			else:
				done = "step"
				index = posmod(index + (1 if drawn < 0.85 else -1), shown.size())
		elif drawn < 0.25:
			done = "move"
			effects = model.move(-1 if drawn < 0.1 else 1)
		elif drawn < 0.35:
			if may_type:
				done = "tap"
				var keys := model.view.groups.size() if model.by_region else SearchModel.KEYS.length()
				tapped = random.randi_range(0, keys - 1)
				effects = model.tap(tapped, index)
		else:
			var action := SearchModel.PRESSES[random.randi_range(0, SearchModel.PRESSES.size() - 1)]
			if may_type or action not in [&"ui_accept", &"open_settings"]:
				done = String(action)
				effects = model.press(action, index)
		for effect in effects:
			if effect.kind == Kind.SHOW:
				shown = effect.games
				index = effect.at
			elif effect.kind == Kind.JUMP:
				index = effect.at
		return effects
