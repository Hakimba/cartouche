# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const _FRAME_S := 0.02


func test_the_spring_rests_exactly_on_its_target_and_stops() -> void:
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	var frames := 0
	while not spring.step(_FRAME_S):
		frames += 1
		assert_int(frames).is_less(100)
	assert_float(spring.position).is_equal(1.0)
	assert_float(spring.velocity).is_equal(0.0)


func test_a_press_mid_motion_retargets_without_a_jump_and_presses_stack() -> void:
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	for frame in 5:
		spring.step(_FRAME_S)
	var was := spring.position
	var speed := spring.velocity
	spring.target += 1.0
	assert_float(spring.position).is_equal(was)
	assert_float(spring.velocity).is_equal(speed)
	while not spring.step(_FRAME_S):
		pass
	assert_float(spring.position).is_equal(2.0)


func test_a_frame_longer_than_a_thirtieth_moves_the_spring_as_a_thirtieth() -> void:
	var slow := Motion.Spring.new(0.0)
	var capped := Motion.Spring.new(0.0)
	slow.target = 1.0
	capped.target = 1.0
	slow.step(0.5)
	capped.step(1.0 / 30.0)
	assert_float(slow.position).is_equal(capped.position)


func test_every_curve_starts_where_it_starts_and_ends_on_its_end() -> void:
	for curve: Motion.Easing in Motion.Easing.values():
		var named: String = Motion.Easing.find_key(curve)
		assert_float(Motion.eased(curve, 0.0)).override_failure_message(named).is_equal_approx(0.0, 1e-4)
		assert_float(Motion.eased(curve, 1.0)).override_failure_message(named).is_equal_approx(1.0, 1e-4)
