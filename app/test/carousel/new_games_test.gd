# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const ScreenFixtures := preload("res://test/screens/fixtures.gd")
const ScreenAgreement := preload("res://dev/bridge/screen_agreement.gd")


## A carousel on a device holding [param consoles], on its consoles screen once the first re-read is over.
func _carousel(device: ScreenFixtures.NewDevice) -> Carousel:
	var carousel := ScreenFixtures.fresh_carousel(self, device)
	assert_bool(await ScreenFixtures.until(self, func() -> bool:
		return carousel._shown and device.refreshed.size() == device.consoles.size() and not carousel._new_games._reading)) \
		.is_true()
	await ScreenFixtures.settled_consoles(self, carousel)
	return carousel


func _on_games(carousel: Carousel) -> void:
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.GAMES)).is_true()


func _shelf_ids(carousel: Carousel) -> PackedStringArray:
	return PackedStringArray(carousel._row._games.map(func(game: AndroidServices.Game) -> String: return game.id))


func _badges(carousel: Carousel) -> Array[int]:
	var counts: Array[int] = []
	for tile in carousel._rail.tiles():
		counts.append(tile.badge().count())
	return counts


func test_a_library_read_again_shows_once_the_carousel_is_free_never_under_the_ribbon_and_is_never_lost() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 6, "gc": 1})
	var carousel := await _carousel(device)
	await _on_games(carousel)
	await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_DOWN)
	assert_bool(carousel._search.is_open()).is_true()
	device.consoles["ps2"] = 8
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return device.refreshed.size() == 4)).is_true()
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._new_games.has_library())).is_true()
	for frame in 10:
		await await_idle_frame()
	assert_int(carousel._row._games.size()).is_equal(6)
	await ScreenFixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._row._games.size() == 8)).is_true()
	assert_bool(carousel._new_games.has_library()).is_false()
	assert_str(carousel._row.selected_game().id).is_equal("ps2/0")


func test_the_shelf_keeps_its_middle_game_or_shows_the_one_now_at_its_place() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 6, "gc": 1})
	var carousel := await _carousel(device)
	await _on_games(carousel)
	for step in 4:
		await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return not carousel._row.is_settling())).is_true()
	assert_str(carousel._row.selected_game().id).is_equal("ps2/4")
	device.consoles["ps2"] = 9
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._row._games.size() == 9)).is_true()
	assert_str(carousel._row.selected_game().id).is_equal("ps2/4")
	assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES)
	device.consoles["ps2"] = 3
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._row._games.size() == 3)).is_true()
	assert_str(carousel._row.selected_game().id).is_equal("ps2/2")


## On the games screen, the console shown keeps a shelf (more games) or loses it: what shows settles to the games
## screen, or to the consoles screen it goes back to.
func test_a_library_read_again_on_the_games_screen_settles_on_the_screen_it_leaves_the_carousel_on() -> void:
	for kept: bool in [true, false]:
		var device := ScreenFixtures.past_first_launch(self, {"ps2": 6, "gc": 1})
		var carousel := await _carousel(device)
		await _on_games(carousel)
		device.consoles["ps2"] = 8 if kept else 0
		await ScreenFixtures.resume(self)
		assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._shelves.size() == (2 if kept else 1))) \
			.is_true()
		assert_int(carousel.screen()).is_equal(Carousel.Screen.GAMES if kept else Carousel.Screen.CONSOLES)
		assert_bool(await ScreenFixtures.until(self, func() -> bool: return ScreenAgreement.disagreement(carousel).is_empty())) \
			.override_failure_message(ScreenAgreement.disagreement(carousel)).is_true()
		carousel.free()


func test_a_console_announces_its_new_games_until_entered_but_the_one_on_screen_announces_none() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 2, "gc": 2})
	var carousel := await _carousel(device)
	var gc := carousel._platform_ids().find("gc")
	var ps2 := carousel._platform_ids().find("ps2")
	device.consoles["gc"] = 4
	device.arrivals = {"unseen": PackedStringArray(["gc/2", "gc/3"]), "announced": {"gc": PackedStringArray(["gc/2", "gc/3"])}}
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return _badges(carousel)[gc] == 2)).is_true()
	assert_int(_badges(carousel)[ps2]).is_equal(0)
	# On the shelf of the PS2 as its new games come: they are in view, the console announces none.
	await _on_games(carousel)
	assert_str(carousel._shelves[carousel._shelf].platform_id).is_equal("ps2")
	device.consoles["ps2"] = 3
	device.arrivals = {"unseen": PackedStringArray(["gc/2", "gc/3", "ps2/2"]),
		"announced": {"gc": PackedStringArray(["gc/2", "gc/3"]), "ps2": PackedStringArray(["ps2/2"])}}
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return "ps2" in device.entered)).is_true()
	assert_int(_badges(carousel)[ps2]).is_equal(0)
	assert_int(_badges(carousel)[gc]).is_equal(2)
	await ScreenFixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel.screen() == Carousel.Screen.CONSOLES)).is_true()
	await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	await ScreenFixtures.settled_consoles(self, carousel)
	await _on_games(carousel)
	assert_array(device.entered).contains(["gc"])
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return _badges(carousel)[gc] == 0)).is_true()


func test_a_new_game_stays_new_while_in_the_middle_and_is_seen_once_left() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 4})
	device.arrivals = {"unseen": PackedStringArray(["ps2/0", "ps2/1"]), "announced": {}}
	var carousel := await _carousel(device)
	await _on_games(carousel)
	for frame in 10:
		await await_idle_frame()
	assert_bool(carousel._new_games.is_new("ps2/0")).is_true()
	assert_array(device.left).is_empty()
	await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_RIGHT)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return device.left == ["ps2/0"])).is_true()
	assert_bool(carousel._new_games.is_new("ps2/0")).is_false()
	assert_bool(carousel._new_games.is_new("ps2/1")).is_true()
	# Leaving the shelf leaves the game in its middle.
	await ScreenFixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return device.left == ["ps2/0", "ps2/1"])).is_true()


func test_an_answer_sent_before_a_game_was_left_does_not_bring_its_mark_back() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 2})
	device.slow = [&"leave_game"]
	var marks: NewGames = auto_free(NewGames.new())
	marks.android = device
	add_child(marks)
	var told := AndroidServices.Arrivals.new({"unseen": PackedStringArray(["ps2/0"])})
	marks.take(told)
	var game := AndroidServices.Game.new({"id": "ps2/0", "platform_id": "ps2", "title": "ps2 0", "identified": false,
		"discs": [], "last_disc": 0})
	marks.leave(game)
	assert_bool(marks.is_new("ps2/0")).is_false()
	marks.take(told)
	assert_bool(marks.is_new("ps2/0")).is_false()
	device.slow.clear()
	device.released.emit()
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return device.left == ["ps2/0"] and not marks._leaving)) \
		.is_true()
	assert_bool(marks.is_new("ps2/0")).is_false()


func test_a_library_read_again_before_a_form_saved_never_replaces_the_form_s_once_shown() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 6, "gc": 1})
	var carousel := await _carousel(device)
	await _edit(carousel)
	device.consoles["ps2"] = 8
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._new_games.has_library())).is_true()
	device.scanned_games = 9
	await _save_subfolders(carousel)
	assert_bool(await ScreenFixtures.until(self, func() -> bool:
		return not carousel._screens.visible and not carousel._new_games.has_library() and _shelf_size(carousel, "ps2") == 9)) \
		.is_true()
	for frame in 20:
		await await_idle_frame()
		assert_int(_shelf_size(carousel, "ps2")).is_equal(9)


func test_a_library_read_again_while_a_game_is_renamed_keeps_its_new_name() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 3, "gc": 1})
	var carousel := await _carousel(device)
	await _on_games(carousel)
	await ScreenFixtures.joypad(self, JOY_BUTTON_X)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return _properties_still(carousel))).is_true()
	device.consoles["ps2"] = 4
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._new_games.has_library())).is_true()
	await ScreenFixtures.action(self, &"ui_down")
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return _properties_still(carousel))).is_true()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	await ScreenFixtures.joypad(self, JOY_BUTTON_START)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return device.names.has("ps2/0") and _properties_still(carousel))) \
		.is_true()
	var kept := device.names["ps2/0"]
	await ScreenFixtures.joypad(self, JOY_BUTTON_B)
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return carousel._row._games.size() == 4)).is_true()
	assert_str(carousel._row.selected_game().id).is_equal("ps2/0")
	assert_str(carousel._row.selected_game().title).is_equal(kept)


func test_a_library_read_again_waits_for_a_toss_the_order_ring_the_properties_and_the_form() -> void:
	var busy := {
		"toss": [_on_games, func(_on: Carousel) -> void: await ScreenFixtures.action(self, &"ui_up"), _nothing],
		"order": [_nothing, func(_on: Carousel) -> void: await ScreenFixtures.joypad(self, JOY_BUTTON_DPAD_DOWN), _close_order],
		"properties": [_on_games, func(_on: Carousel) -> void: await ScreenFixtures.joypad(self, JOY_BUTTON_X), _back],
		"form": [_nothing, _edit, _back],
	}
	for case: String in busy:
		var steps: Array = busy[case]
		var arrive: Callable = steps[0]
		var open: Callable = steps[1]
		var close: Callable = steps[2]
		var device := ScreenFixtures.past_first_launch(self, {"ps2": 3, "gc": 1})
		var carousel := await _carousel(device)
		await arrive.call(carousel)
		await open.call(carousel)
		assert_bool(carousel._is_free()).override_failure_message(case + " leaves the carousel free").is_false()
		device.consoles["ps2"] = 5
		await ScreenFixtures.resume(self)
		assert_bool(await ScreenFixtures.until(self, func() -> bool:
			return carousel._new_games.has_library() or _shelf_size(carousel, "ps2") == 5)).is_true()
		if case != "toss":
			for frame in 10:
				await await_idle_frame()
		assert_int(_shelf_size(carousel, "ps2")).override_failure_message(case + ": shown while busy").is_equal(3)
		await close.call(carousel)
		assert_bool(await ScreenFixtures.until(self, func() -> bool: return _shelf_size(carousel, "ps2") == 5)) \
			.override_failure_message(case + ": never shown").is_true()
		carousel.queue_free()
		await await_idle_frame()


func test_an_edit_saved_marks_no_game_new() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 2, "gc": 1})
	var carousel := await _carousel(device)
	var refreshed := device.refreshed.size()
	await _edit(carousel)
	device.scanned_games = 5
	await _save_subfolders(carousel)
	assert_bool(await ScreenFixtures.until(self, func() -> bool:
		return not carousel._screens.visible and _shelf_size(carousel, "ps2") == 5)).is_true()
	await ScreenFixtures.settled_consoles(self, carousel)
	assert_int(device.refreshed.size()).is_equal(refreshed)
	assert_array(_badges(carousel)).is_equal([0, 0])
	assert_bool(carousel._new_games.has_new()).is_false()


func test_a_library_read_again_with_no_game_left_shows_no_console() -> void:
	var device := ScreenFixtures.past_first_launch(self, {"ps2": 2})
	var carousel := await _carousel(device)
	await _on_games(carousel)
	device.consoles["ps2"] = 0
	await ScreenFixtures.resume(self)
	assert_bool(await ScreenFixtures.on(self, carousel, "NoConsole")).is_true()
	assert_bool(carousel._new_games.has_library()).is_false()
	assert_int(carousel.screen()).is_equal(Carousel.Screen.CONSOLES)


## The games [param platform_id]'s shelf shows, as the library on screen has them.
func _shelf_size(carousel: Carousel, platform_id: String) -> int:
	for shelf in carousel._shelves:
		if shelf.platform_id == platform_id:
			return shelf.games.size()
	return 0


func _properties_still(carousel: Carousel) -> bool:
	return carousel.screen() == Carousel.Screen.PROPERTIES and not carousel._properties._busy


## The selected console edited in its form.
func _edit(carousel: Carousel) -> void:
	await ScreenFixtures.joypad(self, JOY_BUTTON_X)
	assert_bool(await ScreenFixtures.on(self, carousel, "AddConsole")).is_true()


## The form saved, its games read again in subfolders: its setup stored, then its folder scanned.
func _save_subfolders(carousel: Carousel) -> void:
	for step in 3:
		await ScreenFixtures.action(self, &"ui_down")
	assert_str(ScreenFixtures.focus(self).name).is_equal("Subfolders")
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)
	var save: Button = carousel.get_node("%Screens/AddConsole/%Add")
	assert_bool(await ScreenFixtures.until(self, func() -> bool: return not save.disabled)).is_true()
	save.grab_focus()
	await ScreenFixtures.joypad(self, JOY_BUTTON_A)


## B once the ring stands open.
func _close_order(carousel: Carousel) -> void:
	await ScreenFixtures.settled_consoles(self, carousel)
	await _back(carousel)


func _back(_on: Carousel) -> void:
	await ScreenFixtures.joypad(self, JOY_BUTTON_B)


func _nothing(_on: Carousel) -> void:
	pass
