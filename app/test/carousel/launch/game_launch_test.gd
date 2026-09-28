# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const CAROUSEL := preload("res://carousel/carousel.tscn")
const FAILURES: Array[StringName] = [&"not_installed", &"no_player", &"game_missing", &"activity_not_found", &"unexpected"]
const BUTTONS: Array[StringName] = [&"carousel_left", &"carousel_right", &"tab_previous", &"tab_next", &"ui_accept", &"app_back"]
## INV-E3-04's bound on waiting, in seconds, and the longest frame the test draws.
const WAIT_S := 5.0
const LONGEST_FRAME_S := 1.0 / 20.0
const WAITING: Array[GameLaunch.Stage] = [GameLaunch.Stage.STARTING, GameLaunch.Stage.STARTING_LEFT,
	GameLaunch.Stage.STARTING_BACK, GameLaunch.Stage.AWAY, GameLaunch.Stage.AWAY_LEFT]
## Where leaving for another app and coming back must change nothing.
const UNAFFECTED: Array[GameLaunch.Stage] = [GameLaunch.Stage.CHECKING, GameLaunch.Stage.INSERTING, GameLaunch.Stage.SHOWING]

enum Outcome {
	CHECK_REFUSED,
	START_REFUSED,
	AWAY_AND_BACK,
	BACK_BEFORE_THE_ANSWER,
	BACK_BEFORE_NO_ANSWER,
	LEFT_BEFORE_THE_ANSWER,
	NEVER_LEFT,
	CHECK_NEVER_ANSWERED,
	START_NEVER_ANSWERED,
	## Answered only once the launch gave up waiting: the answer must change nothing.
	CHECK_ANSWERED_TOO_LATE,
	START_REFUSED_TOO_LATE,
}

## What is under way as A is pressed.
enum Press { NOTHING, DIRECTION, STICK, SELECT }

## Counts the failures of the launch under test, beside the carousel's own receiver.
var _counting := func(_code: StringName) -> void: pass


func test_INV_E3_04_INV_E3_05_whatever_the_launch_comes_to_the_carousel_shows_again_as_it_was_and_nothing_acted_meanwhile() -> void:
	var carousel := await _carousel()
	var random := Fixtures.cases(80)
	var outcomes: Dictionary[Outcome, int] = {}
	for i in 80:
		if is_failure():
			return
		var outcome: Outcome = random.randi_range(0, Outcome.size() - 1) as Outcome
		outcomes[outcome] = outcomes.get(outcome, 0) + 1
		_check_launch(carousel, outcome, random)
	assert_int(outcomes.size()).is_equal(Outcome.size())


func test_a_game_that_cannot_start_plays_nothing_while_it_is_checked_nor_after() -> void:
	var carousel := await _carousel()
	var launch := carousel._game_launch
	var android: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	android.check_code = &"game_missing"
	android.late = true
	launch.android = android
	var codes := _codes(launch)
	carousel._unhandled_input(_button(&"ui_accept", true))
	for frame in 20:
		if frame == 10:
			android.replied.emit()
		_frame(carousel, Fixtures.FRAME_S)
		_assert_nothing_shown(carousel)
	assert_bool(launch.is_busy()).is_false()
	assert_int(android.starts).is_equal(0)
	assert_array(codes).is_equal([&"game_missing"])


## One launch that comes to [param outcome], with presses under way and random inputs meanwhile.
func _check_launch(carousel: Carousel, outcome: Outcome, random: RandomNumberGenerator) -> void:
	var launch := carousel._game_launch
	var row := carousel._row
	var android := _android(outcome, launch, random)
	var codes := _codes(launch)
	carousel._message.hide()
	var press: Press = random.randi_range(0, Press.size() - 1) as Press
	_press(carousel, press, random)
	carousel._unhandled_input(_button(&"ui_accept", true))
	var game := row.selected_game().id
	var shelf: int = carousel._shelf
	var turned := row._turned
	var stood := row._placed[row.selected_index()].transform
	var frames := 0
	# The longest a waiting stage has lasted.
	var waited_s := 0.0
	var stages: Array[GameLaunch.Stage] = []
	while launch.is_busy() and frames < 5000:
		if launch._stage not in stages:
			stages.append(launch._stage)
			if launch._stage == GameLaunch.Stage.INSERTING:
				# From where the game stood as the insertion started, before its first frame.
				assert_bool(launch._start.is_equal_approx(stood)).is_true()
		_leave_or_come_back(launch, outcome, random)
		if random.randf() < 0.3:
			carousel._unhandled_input(_button(BUTTONS[random.randi_range(0, BUTTONS.size() - 1)], random.randf() < 0.5))
		assert_str(row.selected_game().id).is_equal(game)
		assert_int(carousel._shelf).is_equal(shelf)
		assert_bool(row._turned.is_equal_approx(turned)).is_true()
		assert_bool(carousel._hold_select.is_stopped()).is_true()
		if launch._stage == GameLaunch.Stage.CHECKING:
			_assert_nothing_shown(carousel)
		if launch._stage == GameLaunch.Stage.INSERTING and launch._clock_s >= launch._insertion.seated_s() + launch._insertion.bounce_s:
			_assert_on_the_spindle(launch, row)
		var delta := random.randf_range(1.0 / 120.0, LONGEST_FRAME_S)
		if launch._stage in WAITING:
			_assert_black(launch)
			waited_s = maxf(waited_s, launch._stage_s)
		# Answers come between frames, the launch may end with them: nothing is pressed after.
		if random.randf() < 0.3:
			android.replied.emit()
		stood = row._placed[row.selected_index()].transform
		_frame(carousel, delta)
		frames += 1
	if outcome in [Outcome.CHECK_ANSWERED_TOO_LATE, Outcome.START_REFUSED_TOO_LATE]:
		android.silent.clear()
		android.replied.emit()
	_frame(carousel, Fixtures.FRAME_S)
	var case: String = Outcome.keys()[outcome]
	assert_bool(launch.is_busy()).override_failure_message("%s: still busy" % case).is_false()
	assert_int(android.checks).is_equal(1)
	var checked := outcome not in [Outcome.CHECK_REFUSED, Outcome.CHECK_NEVER_ANSWERED, Outcome.CHECK_ANSWERED_TOO_LATE]
	assert_int(android.starts).is_equal(1 if checked else 0)
	assert_str(row.selected_game().id).is_equal(game)
	assert_array(codes).override_failure_message("%s: %s" % [case, codes]).is_equal(_failures(outcome, android))
	assert_bool(carousel._message.visible).is_equal(not codes.is_empty())
	_assert_waited(outcome, stages, waited_s)
	_assert_as_before_the_launch(carousel)
	_let_go(carousel)


## A direction held, the stick pushed or Select held as A is pressed, some frames already under way.
func _press(carousel: Carousel, press: Press, random: RandomNumberGenerator) -> void:
	match press:
		Press.DIRECTION:
			carousel._unhandled_input(_button(BUTTONS[random.randi_range(0, 1)], true))
		Press.STICK:
			Input.action_press(&"inspect_right", random.randf_range(0.3, 1.0))
		Press.SELECT:
			carousel._unhandled_input(_button(&"app_back", true))
	for frame in random.randi_range(0, 30):
		_frame(carousel, Fixtures.FRAME_S)


## Everything pressed is let go for the next case, where it would act.
func _let_go(carousel: Carousel) -> void:
	Input.action_release(&"inspect_right")
	carousel._direction = HeldDirection.new()
	carousel._hold_select.stop()


## Android leaving for the emulator and coming back, as [param outcome] has it, and at any time where
## it must change nothing.
func _leave_or_come_back(launch: GameLaunch, outcome: Outcome, random: RandomNumberGenerator) -> void:
	if launch._stage in UNAFFECTED and random.randf() < 0.02:
		_leave_and_come_back(launch)
	if outcome == Outcome.AWAY_AND_BACK and launch._stage == GameLaunch.Stage.AWAY and random.randf() < 0.05:
		_leave_and_come_back(launch)
	# Some time away, the screen still black, before coming back.
	if outcome == Outcome.LEFT_BEFORE_THE_ANSWER and launch._stage == GameLaunch.Stage.AWAY_LEFT and random.randf() < 0.1:
		launch.notification(Node.NOTIFICATION_APPLICATION_RESUMED)


## The failures the launch reports when it comes to [param outcome].
func _failures(outcome: Outcome, android: Fixtures.FakeAndroid) -> Array[StringName]:
	match outcome:
		Outcome.CHECK_REFUSED:
			return [android.check_code]
		Outcome.START_REFUSED:
			return [android.start_code]
		Outcome.CHECK_NEVER_ANSWERED, Outcome.CHECK_ANSWERED_TOO_LATE:
			return [&"timeout"]
	return []


## A started game keeps the screen black until the user comes back, or for 5 s while the launch
## waits for an answer or for Android, and no longer.
func _assert_waited(outcome: Outcome, stages: Array[GameLaunch.Stage], waited_s: float) -> void:
	assert_float(waited_s).is_less_equal(WAIT_S + LONGEST_FRAME_S)
	match outcome:
		Outcome.AWAY_AND_BACK:
			assert_array(stages).contains([GameLaunch.Stage.AWAY])
		Outcome.LEFT_BEFORE_THE_ANSWER:
			assert_array(stages).contains([GameLaunch.Stage.AWAY_LEFT])
		Outcome.BACK_BEFORE_THE_ANSWER:
			# Back already: the carousel shows as soon as the start is answered, never waiting for
			# the user to come back.
			assert_array(stages).not_contains([GameLaunch.Stage.AWAY, GameLaunch.Stage.AWAY_LEFT])
		Outcome.NEVER_LEFT, Outcome.START_NEVER_ANSWERED, Outcome.START_REFUSED_TOO_LATE, Outcome.BACK_BEFORE_NO_ANSWER:
			assert_float(waited_s).is_greater_equal(WAIT_S - LONGEST_FRAME_S)


func _carousel() -> Carousel:
	var carousel: Carousel = auto_free(CAROUSEL.instantiate())
	var row: ShelfRow = carousel.get_node("%Row")
	row.label_images = Fixtures.FakeLabels.new()
	add_child(carousel)
	for frame in 100:
		if carousel._shown:
			break
		await await_idle_frame()
	assert_bool(carousel._shown).is_true()
	# The test moves time itself.
	row.set_process(false)
	carousel.set_process(false)
	return carousel


## A fake answering as [param outcome] needs, late now and then.
func _android(outcome: Outcome, launch: GameLaunch, random: RandomNumberGenerator) -> Fixtures.FakeAndroid:
	var android: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	launch.android = android
	android.late = random.randf() < 0.5
	var failure := FAILURES[random.randi_range(0, FAILURES.size() - 1)]
	match outcome:
		Outcome.CHECK_REFUSED:
			android.check_code = failure
		Outcome.START_REFUSED:
			android.start_code = failure
		Outcome.BACK_BEFORE_THE_ANSWER:
			android.on_start = func() -> void: _leave_and_come_back(launch)
		Outcome.BACK_BEFORE_NO_ANSWER:
			android.on_start = func() -> void: _leave_and_come_back(launch)
			android.silent = [&"start"]
		Outcome.LEFT_BEFORE_THE_ANSWER:
			android.on_start = func() -> void: launch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
		Outcome.CHECK_NEVER_ANSWERED, Outcome.CHECK_ANSWERED_TOO_LATE:
			android.silent = [&"check"]
		Outcome.START_NEVER_ANSWERED:
			android.silent = [&"start"]
		Outcome.START_REFUSED_TOO_LATE:
			android.silent = [&"start"]
			android.start_code = failure
	return android


## The codes of the failures [param launch] reports from now on.
func _codes(launch: GameLaunch) -> Array[StringName]:
	var codes: Array[StringName] = []
	if launch.failed.is_connected(_counting):
		launch.failed.disconnect(_counting)
	_counting = func(code: StringName) -> void: codes.append(code)
	launch.failed.connect(_counting)
	return codes


## One frame of [param delta] seconds for the carousel, its launch, then its row.
func _frame(carousel: Carousel, delta: float) -> void:
	carousel._process(delta)
	if carousel._game_launch.is_processing():
		carousel._game_launch._process(delta)
	carousel._row._process(delta)


func _leave_and_come_back(launch: GameLaunch) -> void:
	launch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	launch.notification(Node.NOTIFICATION_APPLICATION_RESUMED)


func _button(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event


## While a game is checked, nothing of a launch shows.
func _assert_nothing_shown(carousel: Carousel) -> void:
	var launch := carousel._game_launch
	assert_bool(launch.blackout.visible).is_false()
	assert_bool(launch.spindle.visible).is_false()
	assert_bool(carousel._row._launched).is_false()
	for control: CanvasItem in launch.controls:
		assert_float(control.modulate.a).is_equal(1.0)



## Once seated and still, the game is on the spindle.
func _assert_on_the_spindle(launch: GameLaunch, row: ShelfRow) -> void:
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	assert_bool(place.transform.is_equal_approx(launch.spindle.transform)).is_true()


## The screen all black, as while the game starts.
func _assert_black(launch: GameLaunch) -> void:
	assert_bool(launch.blackout.visible).is_true()
	assert_float(launch._black.get_shader_parameter(&"opacity")).is_equal(1.0)
	var size := launch.blackout.size
	var centre: Vector2 = launch._black.get_shader_parameter(&"centre") * size
	var radius: float = launch._black.get_shader_parameter(&"radius")
	for corner: Vector2 in [Vector2.ZERO, Vector2(size.x, 0.0), Vector2(0.0, size.y), size]:
		assert_float(radius).is_greater_equal(corner.distance_to(centre) - 0.001)


## The selected game where the row places it again (it may still be finishing a move begun before
## A), unturned and faded as laid out; the controls shown; no spindle, no black.
func _assert_as_before_the_launch(carousel: Carousel) -> void:
	var row := carousel._row
	assert_bool(row._launched).is_false()
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	var offset: float = CarouselLayout.offsets(row._games.size(), row._scroll)[row.selected_index()]
	var laid_out := CarouselLayout.place(offset)
	assert_bool(place.shown.transform.is_equal_approx(Transform3D.IDENTITY)).is_true()
	assert_float(place.transform.origin.x).is_equal_approx(laid_out.origin.x, 0.0001)
	assert_float(place.transform.origin.z).is_equal_approx(laid_out.origin.z, 0.0001)
	assert_float(place.shown._geometry[0].transparency).is_equal_approx(CarouselLayout.fade(offset), 0.0001)
	for control: CanvasItem in carousel._game_launch.controls:
		assert_float(control.modulate.a).is_equal(1.0)
	assert_bool(carousel._game_launch.blackout.visible).is_false()
	assert_bool(carousel._game_launch.spindle.visible).is_false()
