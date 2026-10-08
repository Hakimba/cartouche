# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")
const STEP_S := 0.05
## The engine's rate cap awake, other than none, so that giving it back shows.
const AWAKE_FPS := 75


var _resting: Resting
var _paced: Paced
var _fps_before := 0


func before_test() -> void:
	_fps_before = Engine.max_fps
	Engine.max_fps = AWAKE_FPS
	_resting = auto_free(Resting.new())
	add_child(_resting)
	# Stepped by hand.
	_resting.set_process(false)
	_paced = auto_free(Paced.new())
	_paced.add_to_group(Resting.PACED)
	add_child(_paced)


func after_test() -> void:
	# Freed after this, it would give the engine its own cap back.
	_resting.wake()
	Engine.max_fps = _fps_before
	OS.low_processor_usage_mode = false


func _frames(count: int, step_s := STEP_S) -> void:
	for frame in count:
		_resting._process(step_s)


func _press() -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	_resting._on_window_input(press)


## [param event] through the window, as a device sends it.
func _send(event: InputEvent) -> void:
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## A stick's [param axis] at [param value] of its travel.
func _stick(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var motion := InputEventJoypadMotion.new()
	motion.axis = axis
	motion.axis_value = value
	return motion


## A finger put down or lifted.
func _finger(down: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.pressed = down
	return touch


## What the app is after [param idle_s] seconds left alone, as the invariant has it: in low
## processor mode from 2 s (drawn when something changes, about 30 times a second), its motions
## stopping from 5 s in 1.2 s; the engine's frame rate never capped.
func _assert_rested(idle_s: float) -> void:
	var pace := clampf(1.0 - (idle_s - 5.0) / 1.2, 0.0, 1.0)
	assert_float(_resting.pace).is_equal_approx(pace, 1e-4)
	assert_float(_paced.pace).is_equal(_resting.pace)
	assert_int(Engine.max_fps).is_equal(AWAKE_FPS)
	assert_bool(OS.low_processor_usage_mode).is_equal(idle_s >= 2.0)


func test_INV_E8_01_left_alone_the_app_slows_then_stills_and_the_first_press_wakes_it_all_at_once() -> void:
	var idle_s := 0.0
	while idle_s < 9.0:
		_resting._process(STEP_S)
		idle_s += STEP_S
		_assert_rested(idle_s)
	assert_float(_paced.pace).is_equal(0.0)
	_press()
	_assert_rested(0.0)
	assert_float(_paced.pace).is_equal(1.0)


func test_INV_E8_01_whatever_the_frames_and_presses_the_app_is_as_long_left_alone_has_it() -> void:
	var woken_still := 0
	for test_seed in 40:
		var random := Fixtures.cases(test_seed)
		var idle_s := 0.0
		for event in 200:
			if random.randf() < 0.04:
				woken_still += 1 if _resting.pace == 0.0 else 0
				_press()
				idle_s = 0.0
			else:
				var delta := random.randf_range(0.001, 0.2)
				_resting._process(delta)
				idle_s += delta
			_assert_rested(idle_s)
		_press()
	# The walk does reach still, and wakes from it.
	assert_int(woken_still).is_greater(5)


func test_while_something_goes_on_that_must_not_be_slowed_the_app_stays_awake() -> void:
	# Held in an array: a lambda keeps its own copy of a plain local.
	var moves := [true]
	_resting.moving = func() -> bool: return moves[0]
	_frames(200)
	_assert_rested(0.0)
	moves[0] = false
	_frames(150)
	_assert_rested(150 * STEP_S)
	moves[0] = true
	_resting._process(STEP_S)
	_assert_rested(0.0)


func test_an_animation_no_press_started_plays_without_waking_it() -> void:
	# A message fading: a tween of its own.
	var tween := create_tween()
	tween.tween_interval(10.0)
	var idle_s := 0.0
	while idle_s < 8.0:
		_resting._process(STEP_S)
		idle_s += STEP_S
		_assert_rested(idle_s)
	assert_bool(tween.is_running()).is_true()
	tween.kill()


func test_INV_E8_01_a_stick_resting_on_its_centre_wakes_nothing_a_push_or_a_touch_does() -> void:
	_frames(160)
	for axis: JoyAxis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		for value: float in [0.29, -0.29, 0.0]:
			_send(_stick(axis, value))
	_frames(1)
	_assert_rested(161 * STEP_S)
	_send(_stick(JOY_AXIS_LEFT_Y, -0.31))
	_assert_rested(0.0)
	_send(_stick(JOY_AXIS_LEFT_Y, 0.0))
	_frames(160)
	_send(_finger(true))
	_assert_rested(0.0)
	_send(_finger(false))


func test_held_a_button_a_finger_or_a_stick_that_turns_keep_it_awake() -> void:
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_LEFT_STICK
	button.pressed = true
	var let_go_button := InputEventJoypadButton.new()
	let_go_button.button_index = JOY_BUTTON_LEFT_STICK
	# The right stick turns the selected console or game from 0.2 on: it moves.
	var holds: Array[Array] = [[button, let_go_button], [_finger(true), _finger(false)],
		[_stick(JOY_AXIS_RIGHT_X, 0.25), _stick(JOY_AXIS_RIGHT_X, 0.0)]]
	for held_then_let_go in holds:
		var held: InputEvent = held_then_let_go[0]
		var let_go: InputEvent = held_then_let_go[1]
		_send(held)
		_frames(160)
		_assert_rested(0.0)
		_send(let_go)
		_frames(50)
		_assert_rested(50 * STEP_S)


func test_INV_E8_01_a_return_to_the_app_wakes_it() -> void:
	for back: int in [Node.NOTIFICATION_APPLICATION_RESUMED, Node.NOTIFICATION_APPLICATION_FOCUS_IN]:
		_frames(160)
		_resting.notification(back)
		_assert_rested(0.0)


func test_INV_E8_01_a_press_through_the_window_wakes_it() -> void:
	_frames(160)
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_B
	press.pressed = true
	_send(press)
	_assert_rested(0.0)
	var release := InputEventJoypadButton.new()
	release.button_index = JOY_BUTTON_B
	_send(release)


func test_awake_or_kept_awake_it_writes_nothing_each_frame() -> void:
	_resting.moving = func() -> bool: return true
	_frames(100)
	_resting.moving = func() -> bool: return false
	_frames(30)
	assert_int(_paced.given).is_equal(0)
	assert_int(Engine.max_fps).is_equal(AWAKE_FPS)


func test_measuring_motion_keeps_it_awake_and_leaving_gives_the_engine_back_as_it_was() -> void:
	_resting.stays_awake = true
	_frames(200)
	_assert_rested(0.0)
	_resting.stays_awake = false
	_frames(160)
	assert_bool(OS.low_processor_usage_mode).is_true()
	# Gone, it leaves the engine and what it paced awake; back, it rests again from the start.
	remove_child(_resting)
	assert_int(Engine.max_fps).is_equal(AWAKE_FPS)
	assert_bool(OS.low_processor_usage_mode).is_false()
	assert_float(_paced.pace).is_equal(1.0)
	add_child(_resting)
	_assert_rested(0.0)
	_frames(160)
	_assert_rested(160 * STEP_S)


## A node moving by itself, as the backdrop or the rows are, counting the paces it is given.
class Paced extends Node:
	var given := 0
	var pace := 1.0:
		set(value):
			pace = value
			given += 1
