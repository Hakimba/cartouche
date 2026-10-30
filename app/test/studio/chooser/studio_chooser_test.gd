# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const StillStandIn := preload("res://test/studio/views/still_stand_in.gd")
## The design's table of the Type chooser (reference 2.2): platform id, kicker, name, in order.
const _TYPES: Array = [
	["xbox", "Microsoft", "Xbox"], ["xbox360", "Microsoft", "Xbox 360"], ["gb", "Nintendo", "Game Boy"],
	["gba", "Nintendo", "Game Boy Advance"], ["gbc", "Nintendo", "Game Boy Color"], ["gc", "Nintendo", "GameCube"],
	["n64", "Nintendo", "Nintendo 64"], ["nes", "Nintendo", "Nintendo Entertainment System"],
	["wii", "Nintendo", "Wii"], ["psx", "Sony", "PlayStation"], ["ps2", "Sony", "PlayStation 2"],
	["snes", "Nintendo", "Super Nintendo Entertainment System"]]


var _opened: StudioChooser


func before_test() -> void:
	StillStandIn.install()


## The models the chooser dropped are freed a frame later: wait for them before the orphans are counted.
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


func _chooser() -> StudioChooser:
	var chooser: StudioChooser = auto_free((load("res://studio/chooser/studio_chooser.tscn") as PackedScene).instantiate())
	add_child(chooser)
	_opened = chooser
	return chooser


## The chooser opened on the Type list; the answer waits for A or B.
func _open_types(chooser: StudioChooser, offered: Array[AndroidServices.OfferedConsole], current := 0) -> void:
	chooser.choose_console(offered, current)
	await await_idle_frame()


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


func test_up_stops_on_the_first_row_and_down_on_the_last() -> void:
	var chooser := _chooser()
	await _open_types(chooser, _offered(), 11)
	await Fixtures.action(self, &"ui_down")
	assert_int(chooser.focused()).is_equal(11)
	assert_bool(chooser.rows()[11].has_focus()).is_true()
	chooser.rows()[0].grab_focus()
	await Fixtures.action(self, &"ui_up")
	assert_int(chooser.focused()).is_equal(0)
	assert_bool(chooser.rows()[0].has_focus()).is_true()


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


func test_a_tap_on_a_row_chooses_it() -> void:
	var chooser := _chooser()
	var answers: Array[int] = []
	chooser.chosen.connect(answers.append)
	await _open_types(chooser, _offered(), 0)
	var tap := chooser.rows()[1].get_global_rect().get_center()
	_mouse(chooser, tap, true)
	_mouse(chooser, tap, false)
	assert_array(answers).is_equal([1])
	assert_bool(chooser.visible).is_false()


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
	chooser._return_tween.custom_step(1.0)
	assert_array(answers).is_empty()
	assert_bool(chooser._returning).is_false()
	StudioTokens.TR_REVERSE = original_reverse
