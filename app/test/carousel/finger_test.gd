# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func _down(at: Vector2, index := 0) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.pressed = true
	event.index = index
	return event


func _up(at: Vector2, index := 0) -> InputEventScreenTouch:
	var event := _down(at, index)
	event.pressed = false
	return event


func _move(to: Vector2, index := 0) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.position = to
	event.index = index
	return event


func test_a_short_press_that_barely_moves_is_a_tap_and_a_slow_one_is_nothing() -> void:
	var finger := Finger.new()
	assert_int(finger.read(_down(Vector2(100, 100)), 0)).is_equal(Finger.Gesture.DOWN)
	assert_int(finger.read(_move(Vector2(110, 105)), 50)).is_equal(Finger.Gesture.NONE)
	assert_int(finger.read(_up(Vector2(110, 105)), Finger.TAP_MS - 1)).is_equal(Finger.Gesture.TAP)
	finger.read(_down(Vector2(100, 100)), 1000)
	assert_int(finger.read(_up(Vector2(100, 100)), 1000 + Finger.TAP_MS + 1)).is_equal(Finger.Gesture.NONE)


func test_a_finger_moved_past_the_slop_drags_until_released_and_is_never_a_tap() -> void:
	var finger := Finger.new()
	finger.read(_down(Vector2(100, 100)), 0)
	assert_int(finger.read(_move(Vector2(100 + Finger.SLOP, 100)), 20)).is_equal(Finger.Gesture.DRAG)
	# Back where it came down, still a drag.
	assert_int(finger.read(_move(Vector2(100, 100)), 40)).is_equal(Finger.Gesture.DRAG)
	assert_int(finger.read(_up(Vector2(100, 100)), 60)).is_equal(Finger.Gesture.NONE)
	assert_bool(finger.is_down).is_false()


func test_a_touch_the_system_takes_back_ends_as_nothing() -> void:
	var finger := Finger.new()
	finger.read(_down(Vector2(100, 100)), 0)
	var cancelled := _up(Vector2(100, 100))
	cancelled.canceled = true
	assert_int(finger.read(cancelled, 50)).is_equal(Finger.Gesture.NONE)
	assert_bool(finger.is_down).is_false()
	finger.read(_down(Vector2(100, 100)), 100)
	finger.read(_move(Vector2(300, 100)), 120)
	assert_int(finger.read(cancelled, 140)).is_equal(Finger.Gesture.NONE)


func test_a_finger_held_still_is_a_long_press_once_and_then_neither_a_tap_nor_a_drag() -> void:
	var finger := Finger.new()
	finger.read(_down(Vector2(100, 100)), 0)
	assert_bool(finger.held(Finger.LONG_MS - 1)).is_false()
	assert_bool(finger.held(Finger.LONG_MS)).is_true()
	assert_bool(finger.held(Finger.LONG_MS + 100)).is_false()
	assert_int(finger.read(_move(Vector2(300, 100)), Finger.LONG_MS + 200)).is_equal(Finger.Gesture.NONE)
	assert_int(finger.read(_up(Vector2(300, 100)), Finger.LONG_MS + 300)).is_equal(Finger.Gesture.NONE)


func test_a_dragging_finger_is_no_long_press_and_a_second_finger_counts_for_nothing() -> void:
	var finger := Finger.new()
	finger.read(_down(Vector2(100, 100)), 0)
	finger.read(_move(Vector2(200, 100)), 20)
	assert_bool(finger.held(Finger.LONG_MS * 2)).is_false()
	assert_int(finger.read(_down(Vector2(500, 500), 1), 30)).is_equal(Finger.Gesture.NONE)
	assert_int(finger.read(_move(Vector2(900, 500), 1), 40)).is_equal(Finger.Gesture.NONE)
	assert_vector(finger.at).is_equal(Vector2(200, 100))
	assert_int(finger.read(_up(Vector2(500, 500), 1), 50)).is_equal(Finger.Gesture.NONE)
	assert_bool(finger.is_down).is_true()


func test_INV_E7_10_whatever_a_finger_does_a_moved_press_is_never_a_tap_and_a_long_press_comes_once() -> void:
	var random := Fixtures.cases(71)
	var counted: Dictionary[String, int] = {"tap": 0, "drag": 0, "long": 0, "drift": 0}
	for case in 800:
		var finger := Finger.new()
		var now := 0
		var start := Vector2(random.randf_range(0, 1280), random.randf_range(0, 960))
		finger.read(_down(start), now)
		var at := start
		# How far the finger went from where it came down before any long press, worked out here.
		var far := false
		var long_presses := 0
		var dragged := false
		# Still, near the slop, wide, or drifting a few pixels at a time; quick or slow.
		var style := random.randi() % 4
		var reach: float = [2.0, 17.0, 80.0, 8.0][style]
		var pace := 40 if random.randf() < 0.5 else 300
		var drift := Vector2.from_angle(random.randf_range(0.0, TAU)) * reach
		for move in random.randi_range(0, 6):
			now += random.randi_range(1, pace)
			long_presses += 1 if finger.held(now) else 0
			if random.randf() < 0.15:
				# A second finger or two do not change anything.
				var stray := Vector2(random.randf_range(0, 1280), random.randf_range(0, 960))
				assert_int(finger.read(_down(stray, 1), now)).is_equal(Finger.Gesture.NONE)
				assert_int(finger.read(_move(stray, 1), now)).is_equal(Finger.Gesture.NONE)
			at = at + drift if style == 3 else start + Vector2(random.randf_range(-reach, reach), random.randf_range(-reach, reach))
			far = far or (long_presses == 0 and at.distance_to(start) >= Finger.SLOP)
			dragged = finger.read(_move(at), now) == Finger.Gesture.DRAG or dragged
		now += random.randi_range(1, pace)
		long_presses += 1 if finger.held(now) else 0
		var lifted := finger.read(_up(at), now)
		assert_bool(dragged).is_equal(far)
		assert_int(long_presses).is_less_equal(1)
		if lifted == Finger.Gesture.TAP:
			assert_bool(far or long_presses > 0).is_false()
			assert_float(at.distance_to(start)).is_less(Finger.SLOP)
			assert_int(now).is_less(Finger.TAP_MS)
		counted["tap"] += 1 if lifted == Finger.Gesture.TAP else 0
		counted["drag"] += 1 if dragged else 0
		counted["long"] += long_presses
		counted["drift"] += 1 if style == 3 and dragged else 0
		if is_failure():
			return
	# Each kind is reached often.
	for kind in counted:
		assert_int(counted[kind]).override_failure_message(kind).is_greater(30)


func test_a_finger_lifted_far_from_where_it_came_down_is_no_tap_and_a_tap_is_shorter_than_its_limit() -> void:
	var finger := Finger.new()
	finger.read(_down(Vector2(100, 100)), 0)
	assert_int(finger.read(_up(Vector2(300, 100)), 50)).is_equal(Finger.Gesture.NONE)
	finger.read(_down(Vector2(100, 100)), 1000)
	assert_int(finger.read(_up(Vector2(100, 100)), 1000 + Finger.TAP_MS)).is_equal(Finger.Gesture.NONE)
	finger.read(_down(Vector2(100, 100)), 2000)
	assert_int(finger.read(_up(Vector2(100, 100)), 2000 + Finger.TAP_MS - 1)).is_equal(Finger.Gesture.TAP)


func test_a_first_drag_counts_from_where_the_finger_came_down() -> void:
	var finger := Finger.new()
	finger.read(_down(Vector2(100, 100)), 0)
	finger.read(_move(Vector2(110, 100)), 10)
	finger.read(_move(Vector2(120, 100)), 20)
	assert_int(finger.read(_move(Vector2(130, 100)), 30)).is_equal(Finger.Gesture.DRAG)
	assert_vector(finger.moved).is_equal(Vector2(30, 0))
	finger.read(_move(Vector2(140, 100)), 40)
	assert_vector(finger.moved).is_equal(Vector2(10, 0))
