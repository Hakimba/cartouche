# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const StillStandIn := preload("res://test/studio/views/still_stand_in.gd")
const _CQW := 12.8
## The design's table of the Type chooser (reference 2.2): platform id, kicker, name, in order.
const _TYPES: Array = [
	["xbox", "Microsoft", "Xbox"], ["xbox360", "Microsoft", "Xbox 360"], ["gb", "Nintendo", "Game Boy"],
	["gba", "Nintendo", "Game Boy Advance"], ["gbc", "Nintendo", "Game Boy Color"], ["gc", "Nintendo", "GameCube"],
	["n64", "Nintendo", "Nintendo 64"], ["nes", "Nintendo", "Nintendo Entertainment System"],
	["wii", "Nintendo", "Wii"], ["psx", "Sony", "PlayStation"], ["ps2", "Sony", "PlayStation 2"],
	["snes", "Nintendo", "Super Nintendo Entertainment System"]]
## The design's emulators of the PS2: player id, definition name, accepted files.
const _PLAYERS: Array = [
	["ps2.aethersx2", "Aethersx2", "iso chd gz mdf bin"], ["ps2.nethersx2", "NetherSX2 Turnip", "iso chd gz mdf bin"],
	["ps2.armsx2n", "ARMSX2 (Nightly)", "iso chd gz mdf bin ciso img"],
	["ps2.armsx2r", "ARMSX2 (Refresh/GitHub)", "iso chd gz mdf bin ciso img"],
	["ps2.lrps2", "RetroArch 64 - LRPS2", "iso chd cso zso gz bin mdf nrg elf irx"],
	["ps2.play", "RetroArch 64 - play", "bin cso elf iso isz"]]


var _opened: StudioChooser


## The models the chooser dropped are freed a frame later: wait for them before the orphans are counted.
func before_test() -> void:
	StillStandIn.install()


func after_test() -> void:
	StillStandIn.restore()
	if is_instance_valid(_opened):
		_opened._answer(-1)
	await await_idle_frame()
	await await_idle_frame()


func _offered(taken: Array[String] = []) -> Array[AndroidServices.OfferedConsole]:
	var offered: Array[AndroidServices.OfferedConsole] = []
	for row: Array in _TYPES:
		if row[0] not in taken:
			offered.append(AndroidServices.OfferedConsole.new({"id": row[0], "maker": row[1], "model": row[2]}))
	return offered


func _players(count := _PLAYERS.size()) -> Array[AndroidServices.Player]:
	var players: Array[AndroidServices.Player] = []
	for i in count:
		var row: Array = _PLAYERS[i % _PLAYERS.size()]
		var files: String = row[2]
		players.append(AndroidServices.Player.new({"player_id": "%s.%d" % [row[0], i], "player_name": "ps2 - " + row[1],
			"emulator_name": row[1], "extensions": PackedStringArray(files.split(" "))}))
	return players


func _chooser() -> StudioChooser:
	var chooser: StudioChooser = auto_free((load("res://studio/chooser/studio_chooser.tscn") as PackedScene).instantiate())
	add_child(chooser)
	_opened = chooser
	return chooser


## The chooser opened on the Type list; the answer waits for A or B.
func _open_types(chooser: StudioChooser, offered: Array[AndroidServices.OfferedConsole], current := 0) -> void:
	chooser.choose_console(offered, current)
	await await_idle_frame()


func _focus_row(chooser: StudioChooser, i: int) -> void:
	chooser.rows()[i].grab_focus()
	assert_int(chooser.focused()).is_equal(i)


## The scroll of the design: the row in the middle of the window, held to its two ends (reference 2.2), in px.
func _design_scroll(i: int, n: int) -> float:
	return clampf(i * 7.0 - (58.4 - 7.0) / 2.0, 0.0, maxf(0.0, n * 7.0 - 0.6 + 4.4 - 58.4)) * _CQW


func test_the_type_list_shows_the_given_consoles_in_order_with_maker_name_and_number() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered())
	assert_int(chooser.rows().size()).is_equal(12)
	assert_array(Array(chooser.ids())).is_equal(_TYPES.map(func(row: Array) -> String: return row[0]))
	assert_array(chooser.rows().map(func(row: Button) -> String: return row.text)).is_equal(
		_TYPES.map(func(row: Array) -> String: return row[2]))
	assert_str(chooser.counter()).is_equal("01 / 12")
	assert_int(chooser.focused()).is_equal(0)


func test_the_list_opens_on_the_current_choice_or_the_first_row() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered(), 7)
	assert_int(chooser.focused()).is_equal(7)
	assert_bool(chooser.rows()[7].has_focus()).is_true()
	assert_str(chooser.counter()).is_equal("08 / 12")
	chooser._answer(-1)
	await _open_types(chooser, _offered(), -1)
	assert_int(chooser.focused()).is_equal(0)


func test_the_list_rests_where_the_design_scrolls_it_for_every_focus() -> void:
	var chooser := _chooser()
	for n: int in [1, 3, 8, 9, 12, 30]:
		var offered := _offered()
		while offered.size() < n:
			offered.append(offered[offered.size() % 12])
		offered = offered.slice(0, n)
		for i in n:
			assert_float(StudioChooser.scroll_of(i, n)).override_failure_message("scroll_of(%d, %d)" % [i, n]) \
				.is_equal_approx(_design_scroll(i, n), 0.01)
	await _open_types(chooser, _offered())
	for i in 12:
		_focus_row(chooser, i)
		assert_bool(await Fixtures.until(self, func() -> bool:
			return is_equal_approx(chooser.list_offset(), 2.2 * _CQW - _design_scroll(i, 12)))).override_failure_message(
			"list at focus %d" % i).is_true()


func test_the_list_stays_in_view_with_more_than_eight_players() -> void:
	var chooser := _chooser()
	chooser.choose_player("ps2", _players(12), 0)
	await await_idle_frame()
	assert_str(chooser.counter()).is_equal("01 / 12")
	for i in 12:
		_focus_row(chooser, i)
		await Fixtures.until(self, func() -> bool:
			return is_equal_approx(chooser.list_offset(), 2.2 * _CQW - _design_scroll(i, 12)))
		var top := chooser.rows()[i].position.y + chooser.list_offset()
		assert_bool(top >= 0.0 and top + chooser.rows()[i].size.y <= 58.4 * _CQW).override_failure_message(
			"row %d in view" % i).is_true()


func test_up_stops_on_the_first_row_and_down_on_the_last() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered(), 11)
	await Fixtures.action(self, &"ui_down")
	assert_int(chooser.focused()).is_equal(11)
	assert_bool(chooser.rows()[11].has_focus()).is_true()
	_focus_row(chooser, 0)
	await Fixtures.action(self, &"ui_up")
	assert_int(chooser.focused()).is_equal(0)
	assert_bool(chooser.rows()[0].has_focus()).is_true()


func test_the_count_follows_the_cursor() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered(["gb", "gba"]))
	for i in 9:
		await Fixtures.action(self, &"ui_down")
		assert_str(chooser.counter()).is_equal("%02d / 10" % (i + 2))
	for i in 9:
		await Fixtures.action(self, &"ui_up")
		assert_str(chooser.counter()).is_equal("%02d / 10" % (9 - i))


func test_the_cursor_card_follows_the_focus_in_the_row_colours_and_the_rim_of_each_console() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered())
	var list: Control = chooser.get_node("List")
	for i in 12:
		if i > 0:
			await Fixtures.action(self, &"ui_down")
		var id: String = _TYPES[i][0]
		var gel: Color = StudioTokens.GEL[StringName("ps2_slim" if id == "ps2" else id)]
		assert_bool(await Fixtures.until(self, func() -> bool:
			var want := list.global_position.y + 2.2 * _CQW - _design_scroll(i, 12) + i * 7.0 * _CQW
			return is_equal_approx(chooser.cursor_rect().position.y, want) and chooser.rows()[i].rim.is_equal_approx(gel))) \
			.override_failure_message("card and rim at focus %d" % i).is_true()
		assert_vector(chooser.cursor_rect().size).is_equal_approx(Vector2(56.0 * _CQW, 6.4 * _CQW), Vector2(0.01, 0.01))


func test_five_quick_presses_leave_the_plate_at_its_rest() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered())
	for press in 5:
		await Fixtures.action(self, &"ui_down")
	var plate: LogoView = chooser.get_node("Plinth/Plate")
	var base: Control = chooser.get_node("Plinth")
	var want: float = (base.global_position.y + StudioTokens.PLINTH_PLATE.get_center().y - plate.texture.get_size().y / 2.0)
	assert_bool(await Fixtures.until(self, func() -> bool: return is_equal_approx(plate.modulate.a, 1.0))).is_true()
	assert_float(plate.global_position.y).is_equal_approx(roundf(want), 0.01)


func test_a_choice_answered_in_the_first_instants_leaves_the_lines_at_rest_for_the_next_opening() -> void:
	var chooser := _chooser()
	var rests: Dictionary[String, Vector2] = {}
	for node: String in ["Title", "Count", "List"]:
		rests[node] = (chooser.get_node(node) as Control).position
	for opening in 3:
		await _open_types(chooser, _offered(), 2)
		await get_tree().create_timer(0.1).timeout
		await Fixtures.joypad(self, JOY_BUTTON_A)
		assert_bool(chooser.visible).is_false()
		for node: String in rests:
			var line: Control = chooser.get_node(node)
			assert_vector(line.position).override_failure_message("%s after opening %d" % [node, opening]).is_equal(rests[node])
			assert_float(line.modulate.a).is_equal(1.0)
		assert_float(chooser.modulate.a).is_equal(1.0)
	await _open_types(chooser, _offered(), 2)
	await get_tree().create_timer(0.6).timeout
	for node: String in rests:
		assert_vector((chooser.get_node(node) as Control).position).is_equal(rests[node])


func test_a_second_choice_asked_while_one_is_pending_is_refused() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered(), 4)
	assert_int(await chooser.choose_console(_offered(), 0)).is_equal(-1)
	assert_int(chooser.focused()).is_equal(4)
	assert_bool(chooser.visible).is_true()


func _mouse(chooser: StudioChooser, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	chooser._input(event)


func _drag(chooser: StudioChooser, at: Vector2, by: float) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.relative = Vector2(0.0, by)
	chooser._input(event)


func test_a_finger_dragging_the_list_scrolls_it_held_to_its_ends_and_takes_the_cursor_along() -> void:
	var chooser := _chooser()
	var answers: Array[int] = []
	chooser.chosen.connect(answers.append)
	await _open_types(chooser, _offered(), 0)
	var window: Rect2 = (chooser.get_node("List") as Control).get_global_rect()
	var at := window.get_center()
	_mouse(chooser, at, true)
	for step in 6:
		at.y -= 40.0
		_drag(chooser, at, -40.0)
	assert_float(chooser.list_offset()).is_equal_approx(2.2 * _CQW - 240.0, 0.01)
	var middle := roundi((240.0 + window.size.y / 2.0 - 2.2 * _CQW) / (7.0 * _CQW) - 0.5)
	assert_int(chooser.focused()).is_equal(middle)
	for step in 40:
		at.y -= 40.0
		_drag(chooser, at, -40.0)
	assert_float(chooser.list_offset()).is_equal_approx(2.2 * _CQW - _design_scroll(11, 12), 0.01)
	assert_int(chooser.focused()).is_equal(roundi((_design_scroll(11, 12) + window.size.y / 2.0 - 2.2 * _CQW) / (7.0 * _CQW) - 0.5))
	_mouse(chooser, at, false)
	assert_array(answers).is_empty()
	for step in 40:
		_drag(chooser, at, 0.0)
	assert_bool(await Fixtures.until(self, func() -> bool:
		return is_equal_approx(chooser.list_offset(), 2.2 * _CQW - _design_scroll(11, 12)))).is_true()


func test_a_tap_on_a_row_chooses_it_and_a_wheel_turn_moves_the_list() -> void:
	var chooser := _chooser()
	var answers: Array[int] = []
	chooser.chosen.connect(answers.append)
	await _open_types(chooser, _offered(), 0)
	var window: Rect2 = (chooser.get_node("List") as Control).get_global_rect()
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.position = window.get_center()
	chooser._input(wheel)
	# One row's pitch down: the middle of the window is a row and a half further on.
	assert_int(chooser.focused()).is_equal(roundi((7.0 * _CQW + 58.4 * _CQW / 2.0 - 2.2 * _CQW) / (7.0 * _CQW) - 0.5))
	var focused := chooser.focused()
	assert_bool(await Fixtures.until(self, func() -> bool:
		return is_equal_approx(chooser.list_offset(), 2.2 * _CQW - _design_scroll(focused, 12)))).is_true()
	var row := chooser.rows()[focused]
	var tap := row.get_global_rect().get_center()
	_mouse(chooser, tap, true)
	_mouse(chooser, tap, false)
	assert_array(answers).is_equal([focused])
	assert_bool(chooser.visible).is_false()


func test_the_console_plinth_shows_the_focused_console_still() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered())
	var plinth: Plinth = chooser.get_node("Plinth")
	assert_str(plinth.console()).is_equal("xbox")
	for i in 12:
		_focus_row(chooser, i)
		var id: String = _TYPES[i][0]
		var folder := "ps2_slim" if id == "ps2" else id
		assert_str(plinth.console()).override_failure_message("plinth at focus %d" % i).is_equal(folder)


func test_the_emulator_rows_split_the_name_into_kicker_and_name() -> void:
	var chooser := _chooser()
	chooser.choose_player("ps2", _players(), 0)
	await await_idle_frame()
	assert_array(chooser.rows().map(func(row: Button) -> String: return row.text)).is_equal(
		["Aethersx2", "NetherSX2 Turnip", "ARMSX2", "ARMSX2", "LRPS2", "play"])
	var kickers := chooser.rows().map(func(row: StudioChooser.Row) -> String: return row.kicker())
	assert_array(kickers).is_equal(["", "", "NIGHTLY", "REFRESH/GITHUB", "RETROARCH 64", "RETROARCH 64"])


func test_the_emulator_plate_follows_the_focus_and_the_console_stays_unchanged() -> void:
	var chooser := _chooser()
	chooser.choose_player("ps2", _players(), 3)
	await await_idle_frame()
	var plinth: Plinth = chooser.get_node("Plinth")
	assert_str(chooser.counter()).is_equal("04 / 06")
	assert_array(Array(chooser.plate_lines())).is_equal(["ARMSX2", "REFRESH/GITHUB", ".ISO .CHD .GZ .MDF .BIN", ".CISO .IMG"])
	assert_str(plinth.console()).is_equal("ps2_slim")
	_focus_row(chooser, 0)
	assert_array(Array(chooser.plate_lines())).is_equal(["Aethersx2", "", ".ISO .CHD .GZ .MDF .BIN"])
	_focus_row(chooser, 5)
	assert_array(Array(chooser.plate_lines())).is_equal(["play", "RETROARCH 64", ".BIN .CSO .ELF .ISO .ISZ"])
	assert_str(plinth.console()).is_equal("ps2_slim")


func test_a_long_list_of_files_wraps_on_the_plate() -> void:
	var chooser := _chooser()
	chooser.choose_player("ps2", _players(), 4)
	await await_idle_frame()
	var lines := chooser.plate_lines().slice(2)
	assert_int(lines.size()).is_greater(1)
	assert_str(" ".join(lines)).is_equal(".ISO .CHD .CSO .ZSO .GZ .BIN .MDF .NRG .ELF .IRX")


func test_a_random_walk_of_up_down_a_and_b_keeps_the_cursor_and_the_answer_in_step() -> void:
	var chooser := _chooser()
	var random := RandomNumberGenerator.new()
	random.seed = 12
	var answers: Array[int] = []
	chooser.chosen.connect(answers.append)
	var at := 3
	await _open_types(chooser, _offered(), at)
	for step in 80:
		match random.randi() % 4:
			0:
				await Fixtures.action(self, &"ui_up")
				at = maxi(at - 1, 0)
			1:
				await Fixtures.action(self, &"ui_down")
				at = mini(at + 1, 11)
			2:
				await Fixtures.joypad(self, JOY_BUTTON_A)
				assert_int(answers.back()).is_equal(at)
				await _open_types(chooser, _offered(), at)
			_:
				await Fixtures.joypad(self, JOY_BUTTON_B)
				assert_int(answers.back()).is_equal(-1)
				await _open_types(chooser, _offered(), at)
		assert_int(chooser.focused()).override_failure_message("step %d" % step).is_equal(at)
		assert_bool(chooser.rows()[at].has_focus()).is_true()
		assert_str(chooser.counter()).is_equal("%02d / 12" % (at + 1))
	assert_bool(chooser.visible).is_true()


func test_reopening_the_type_chooser_keeps_its_plinth_and_its_cached_picture() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered())
	var plinth := chooser._plinth
	var turntable: TextureRect = plinth.get_node("Turntable")
	assert_bool(await Fixtures.until(self, func() -> bool: return turntable.texture != null)).is_true()
	var picture := turntable.texture
	chooser._answer(-1)
	await _open_types(chooser, _offered())
	assert_object(chooser._plinth).is_same(plinth)
	assert_object(turntable.texture).is_same(picture)


func test_back_during_opening_cancels_immediately_when_rewind_is_disabled() -> void:
	var original_reverse := StudioTokens.TR_REVERSE
	StudioTokens.TR_REVERSE = 0
	var chooser := _chooser()
	var answers: Array[int] = []
	chooser.chosen.connect(answers.append)
	await _open_types(chooser, _offered())
	var back := InputEventAction.new()
	back.action = &"screen_back"
	back.pressed = true
	chooser._unhandled_input(back)
	assert_array(answers).is_equal([-1])
	assert_bool(chooser.visible).is_false()
	StudioTokens.TR_REVERSE = original_reverse


func test_rewind_after_50_ms_never_answers_after_the_chooser_is_hidden() -> void:
	var original_reverse := StudioTokens.TR_REVERSE
	StudioTokens.TR_REVERSE = 1
	var chooser := _chooser()
	var answers: Array[int] = []
	chooser.chosen.connect(answers.append)
	await _open_types(chooser, _offered())
	chooser._opening.custom_step(0.05)
	var back := InputEventAction.new()
	back.action = &"screen_back"
	back.pressed = true
	chooser._unhandled_input(back)
	chooser.hide()
	await get_tree().create_timer(0.2).timeout
	assert_array(answers).is_empty()
	assert_bool(chooser._returning).is_false()
	StudioTokens.TR_REVERSE = original_reverse
