# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const FAILURES: Array[StringName] = [&"not_installed", &"no_player", &"game_missing", &"activity_not_found", &"unexpected"]
const BUTTONS: Array[StringName] = [&"carousel_left", &"carousel_right", &"screen_back", &"ui_accept", &"app_back"]
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
## Frames of launches into the console, and the most the disc turned on its spindle there.
var _console_frames := 0
var _spun := 0.0


func test_INV_E3_04_INV_E3_05_whatever_the_launch_comes_to_the_carousel_shows_again_as_it_was_and_nothing_acted_meanwhile() -> void:
	# A game put into its console, and one inserted by its medium.
	for platform: String in ["ps2", "gba"]:
		var carousel := await _carousel(platform)
		var random := Fixtures.cases(80)
		var outcomes: Dictionary[Outcome, int] = {}
		for i in 80:
			if is_failure():
				return
			var outcome: Outcome = random.randi_range(0, Outcome.size() - 1) as Outcome
			outcomes[outcome] = outcomes.get(outcome, 0) + 1
			_check_launch(carousel, outcome, random)
		assert_int(outcomes.size()).is_equal(Outcome.size())
	assert_int(_console_frames).is_greater(500)
	assert_float(_spun).is_greater(TAU)


func test_a_game_that_cannot_start_plays_nothing_while_it_is_checked_nor_after() -> void:
	var carousel := await _carousel()
	var launch := carousel._game_launch
	var android: Fixtures.FakeAndroid = auto_free(Fixtures.FakeAndroid.new())
	android.check_code = &"game_missing"
	android.late = true
	launch.android = android
	var codes := _codes(launch)
	var as_it_was := _presence(launch)
	carousel._unhandled_input(Fixtures.button(&"ui_accept", true))
	for frame in 20:
		if frame == 10:
			android.replied.emit()
		Fixtures.step_frame(carousel)
		_assert_nothing_shown(carousel, as_it_was)
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
	var as_it_was := _presence(launch)
	carousel._unhandled_input(Fixtures.button(&"ui_accept", true))
	var game := row.selected_game().id
	var shelf: int = carousel._shelf
	var turned := row._turn.turned
	var stood := row._placed[row.selected_index()].transform
	var frames := 0
	# The longest a waiting stage has lasted.
	var waited_s := 0.0
	var stages: Array[GameLaunch.Stage] = []
	while launch.is_busy() and frames < 5000:
		if launch._stage not in stages:
			stages.append(launch._stage)
			if launch._stage == GameLaunch.Stage.INSERTING:
				# From where the game stood as the insertion started, as_it_was its first frame.
				assert_bool(launch._start.is_equal_approx(stood)).is_true()
				# Into the console for the platform that has a launch animation.
				assert_bool(launch._into_console).is_equal(carousel._shelves[shelf].platform_id == "ps2")
		_leave_or_come_back(launch, outcome, random)
		if random.randf() < 0.3:
			carousel._unhandled_input(Fixtures.button(BUTTONS[random.randi_range(0, BUTTONS.size() - 1)], random.randf() < 0.5))
		assert_str(row.selected_game().id).is_equal(game)
		assert_int(carousel._shelf).is_equal(shelf)
		assert_bool(row._turn.turned.is_equal_approx(turned)).is_true()
		assert_bool(carousel._hold_select.is_stopped()).is_true()
		if launch._stage == GameLaunch.Stage.CHECKING:
			_assert_nothing_shown(carousel, as_it_was)
		if launch._stage == GameLaunch.Stage.INSERTING and launch._into_console:
			if launch._clock_s >= launch.sequence.seated_s():
				_assert_on_the_console_spindle(carousel)
			# INV-E5-08: the whole screen black 2.4 s after the start at most.
			assert_float(launch._clock_s).is_less_equal(2.4 + LONGEST_FRAME_S)
			_assert_into_the_console(carousel)
			_console_frames += 1
		elif launch._stage == GameLaunch.Stage.INSERTING and launch._clock_s >= launch._insertion.seated_s() + launch._insertion.bounce_s:
			_assert_on_the_spindle(launch, row)
		var delta := random.randf_range(1.0 / 120.0, LONGEST_FRAME_S)
		if launch._stage in WAITING:
			_assert_black(launch)
			waited_s = maxf(waited_s, launch._stage_s)
		# Answers come between frames, the launch may end with them: nothing is pressed after.
		if random.randf() < 0.3:
			android.replied.emit()
		stood = row._placed[row.selected_index()].transform
		Fixtures.step_frame(carousel, delta)
		frames += 1
	if outcome in [Outcome.CHECK_ANSWERED_TOO_LATE, Outcome.START_REFUSED_TOO_LATE]:
		android.silent.clear()
		android.replied.emit()
	Fixtures.step_frame(carousel)
	var case: String = Outcome.keys()[outcome]
	assert_bool(launch.is_busy()).override_failure_message("%s: still busy" % case).is_false()
	assert_int(android.checks).is_equal(1)
	var checked := outcome not in [Outcome.CHECK_REFUSED, Outcome.CHECK_NEVER_ANSWERED, Outcome.CHECK_ANSWERED_TOO_LATE]
	assert_int(android.starts).is_equal(1 if checked else 0)
	assert_str(row.selected_game().id).is_equal(game)
	assert_array(codes).override_failure_message("%s: %s" % [case, codes]).is_equal(_failures(outcome, android))
	assert_bool(carousel._message.visible).is_equal(not codes.is_empty())
	_assert_waited(outcome, stages, waited_s)
	_assert_as_before_the_launch(carousel, as_it_was)
	_let_go(carousel)


## A direction held, the stick pushed or Select held as A is pressed, some frames already under way.
func _press(carousel: Carousel, press: Press, random: RandomNumberGenerator) -> void:
	match press:
		Press.DIRECTION:
			carousel._unhandled_input(Fixtures.button(BUTTONS[random.randi_range(0, 1)], true))
		Press.STICK:
			Input.action_press(&"inspect_right", random.randf_range(0.3, 1.0))
		Press.SELECT:
			carousel._unhandled_input(Fixtures.button(&"app_back", true))
	for frame in random.randi_range(0, 30):
		Fixtures.step_frame(carousel)


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
	# Some time away, the screen still black, as_it_was coming back.
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


## The carousel on the games screen of [param platform].
func _carousel(platform := "gba") -> Carousel:
	var carousel: Carousel = await Fixtures.shown_carousel(self)
	while carousel._shelves[carousel._shelf].platform_id != platform:
		Fixtures.press(carousel, &"carousel_right")
	Fixtures.press(carousel, &"ui_accept")
	Fixtures.step_until(carousel, Carousel.Screen.GAMES)
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


func _leave_and_come_back(launch: GameLaunch) -> void:
	launch.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	launch.notification(Node.NOTIFICATION_APPLICATION_RESUMED)


## How present each control of [param launch] is now.
func _presence(launch: GameLaunch) -> Dictionary[CanvasItem, float]:
	var presence: Dictionary[CanvasItem, float] = {}
	for control in launch.controls:
		presence[control] = control.modulate.a
	return presence


## While a game is checked, nothing of a launch shows: the controls are as [param as_it_was].
func _assert_nothing_shown(carousel: Carousel, as_it_was: Dictionary[CanvasItem, float]) -> void:
	var launch := carousel._game_launch
	assert_bool(launch.blackout.visible).is_false()
	assert_bool(launch.spindle.visible).is_false()
	assert_bool(carousel._row._launched).is_false()
	for control: CanvasItem in launch.controls:
		assert_float(control.modulate.a).is_equal(as_it_was[control])



## Once seated, the game is on its console's spindle.
func _assert_on_the_console_spindle(carousel: Carousel) -> void:
	var row := carousel._row
	var console: ConsoleModel = carousel._consoles.selected().model
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	var seat := row.global_transform.affine_inverse() * console.seat()
	assert_bool(place.transform.origin.is_equal_approx(seat.origin)).is_true()
	assert_float(place.transform.basis.z.normalized().dot(seat.basis.z.normalized())).is_equal_approx(1.0, 0.0001)


## Put into the console: no spindle of its medium, the black growing from the console's spindle,
## the disc turning with it once seated, the sounds after it.
func _assert_into_the_console(carousel: Carousel) -> void:
	var launch := carousel._game_launch
	var sequence := launch.sequence
	var console: ConsoleModel = carousel._consoles.selected().model
	assert_bool(launch.spindle.visible).is_false()
	if launch._clock_s > 0.0:
		var centre: Vector2 = launch._black.get_shader_parameter(&"centre") * launch.blackout.size
		var seat := carousel.get_viewport().get_camera_3d().unproject_position(console.seat().origin)
		assert_vector(centre).is_equal_approx(seat, Vector2.ONE * 0.01)
	var rotor := console.spindle._rotor.basis
	var spin := carousel._row._launch_spin
	if sequence.disc_away >= 1.0:
		assert_bool(rotor.is_equal_approx(Basis(Vector3.BACK, spin))).is_true()
		_spun = maxf(_spun, spin)
	else:
		assert_bool(rotor.is_equal_approx(Basis.IDENTITY)).is_true()
	var cues := launch._insertion.sounds
	if launch._clock_s < sequence.seated_s():
		assert_int(launch._cues_played).is_equal(0)
	elif not cues.is_empty() and launch._clock_s >= sequence.seated_s() + cues[0].delay_s:
		assert_int(launch._cues_played).is_greater(0)


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


## The selected game where the row places it again (it may still be finishing a move begun as_it_was
## A), unturned and faded as laid out; the controls as [param as_it_was]; no spindle, no black.
func _assert_as_before_the_launch(carousel: Carousel, as_it_was: Dictionary[CanvasItem, float]) -> void:
	var row := carousel._row
	assert_bool(row._launched).is_false()
	var place: ShelfRow.Place = row._placed[row.selected_index()]
	var offset: float = CarouselLayout.offsets(row._games.size(), row._scroll)[row.selected_index()]
	var laid_out := CarouselLayout.place(offset)
	assert_bool(place.shown.transform.is_equal_approx(Transform3D.IDENTITY)).is_true()
	assert_float(place.transform.origin.x).is_equal_approx(laid_out.origin.x, 0.0001)
	assert_float(place.transform.origin.z).is_equal_approx(laid_out.origin.z, 0.0001)
	assert_float(place.shown._fade.amount).is_equal_approx(CarouselLayout.fade(offset), 0.0001)
	for control: CanvasItem in carousel._game_launch.controls:
		assert_float(control.modulate.a).is_equal(as_it_was[control])
	assert_bool(carousel._game_launch.blackout.visible).is_false()
	assert_bool(carousel._game_launch.spindle.visible).is_false()
	assert_int(carousel._screen).is_equal(Carousel.Screen.GAMES)
	var sequence := carousel._sequence
	assert_float(sequence._at_s).is_equal_approx(sequence._moment(&"games"), 0.0001)
