# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

## The design's clock: a frame every 20 ms.
const _FRAME_S := 0.02
## The rail's pitch, 13.6 cqw.
const _PITCH := 174.08
## Where the rail stands (px from its target) in the design's strip of a press to the right, frames
## 00000 to 00360 of consoles/rest.motion/press-right, one every 40 ms.
const _RAIL_STRIP: Array[float] = [-174.0, -128.0, -75.0, -37.0, -16.0, -5.0, -1.0, 0.0, 1.0, 0.0]
## Each named curve's control points as the design writes them, to compute the oracle apart from the code.
const _CURVES: Dictionary[Motion.Easing, Vector4] = {
	Motion.Easing.GLIDE: Vector4(0.2, 0.8, 0.2, 1.0), Motion.Easing.SNAP: Vector4(0.3, 1.3, 0.5, 1.0), Motion.Easing.ARRIVE: Vector4(0.2, 0.9, 0.25, 1.04),
	Motion.Easing.RISE: Vector4(0.2, 0.9, 0.25, 1.05), Motion.Easing.POP: Vector4(0.3, 1.5, 0.5, 1.0), Motion.Easing.FOCUS: Vector4(0.3, 1.2, 0.5, 1.0),
	Motion.Easing.FLIP: Vector4(0.3, 1.4, 0.5, 1.0), Motion.Easing.APPEAR: Vector4(0.2, 0.9, 0.25, 1.1), Motion.Easing.SINK: Vector4(0.5, 0.0, 0.7, 0.4),
	Motion.Easing.EASE: Vector4(0.25, 0.1, 0.25, 1.0), Motion.Easing.EASE_IN: Vector4(0.42, 0.0, 1.0, 1.0), Motion.Easing.EASE_OUT: Vector4(0.0, 0.0, 0.58, 1.0),
}


func test_the_spring_follows_the_rail_of_the_design_strip_within_a_pixel() -> void:
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	spring.step(0.0)
	for sample in _RAIL_STRIP.size():
		assert_float((spring.position - 1.0) * _PITCH).override_failure_message("at %d ms" % (sample * 40)) \
			.is_equal_approx(_RAIL_STRIP[sample], 1.0)
		spring.step(_FRAME_S)
		spring.step(_FRAME_S)


func test_the_spring_matches_the_design_formula_step_by_step() -> void:
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	var position := 0.0
	var velocity := 0.0
	for frame in 15:
		velocity += (280.0 * (1.0 - position) - 25.0 * velocity) * _FRAME_S
		position += velocity * _FRAME_S
		spring.step(_FRAME_S)
		assert_float(spring.position).is_equal_approx(position, 1e-9)


func test_the_spring_rests_on_the_frame_the_design_s_thresholds_say() -> void:
	var position := 0.0
	var velocity := 0.0
	var expected := 0
	while not (absf(1.0 - position) < 1e-3 and absf(velocity) < 1e-3):
		velocity += (280.0 * (1.0 - position) - 25.0 * velocity) * _FRAME_S
		position += velocity * _FRAME_S
		expected += 1
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	var frames := 1
	while not spring.step(_FRAME_S):
		frames += 1
	assert_int(frames).is_equal(expected)


func test_the_spring_overshoots_once_then_rests_exactly_on_its_target_in_about_350_ms() -> void:
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	var highest := 0.0
	var frames := 0
	while not spring.step(_FRAME_S):
		highest = maxf(highest, spring.position)
		frames += 1
		assert_int(frames).is_less(100)
	assert_float(highest).is_between(1.001, 1.01)
	assert_float(spring.position).is_equal(1.0)
	assert_float(spring.velocity).is_equal(0.0)
	assert_float(frames * _FRAME_S).is_between(0.3, 0.9)


func test_the_spring_matches_the_formula_at_sixty_frames_a_second_too() -> void:
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	var position := 0.0
	var velocity := 0.0
	for frame in 30:
		velocity += (280.0 * (1.0 - position) - 25.0 * velocity) / 60.0
		position += velocity / 60.0
		spring.step(1.0 / 60.0)
		assert_float(spring.position).is_equal_approx(position, 1e-9)


func test_the_spring_passes_its_target_once_only() -> void:
	var spring := Motion.Spring.new(0.0)
	spring.target = 1.0
	var passes := 0
	var beyond := false
	while not spring.step(_FRAME_S):
		if (spring.position > 1.0) != beyond:
			beyond = not beyond
			passes += int(beyond)
	assert_int(passes).is_equal(1)


func test_a_frame_longer_than_a_thirtieth_moves_the_spring_as_a_thirtieth() -> void:
	var slow := Motion.Spring.new(0.0)
	var capped := Motion.Spring.new(0.0)
	slow.target = 1.0
	capped.target = 1.0
	slow.step(0.5)
	capped.step(1.0 / 30.0)
	assert_float(slow.position).is_equal(capped.position)


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


func test_each_named_curve_is_within_a_level_of_its_formula() -> void:
	for curve: Motion.Easing in _CURVES:
		for t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
			assert_float(Motion.eased(curve, t)).override_failure_message("%s at %.2f" % [Motion.Easing.find_key(curve), t]) \
				.is_equal_approx(_bezier_by_bisection(_CURVES[curve], t), 1.0 / 255.0)


func test_every_curve_but_the_ring_s_and_linear_is_a_bezier_of_the_design() -> void:
	var others: Array[Motion.Easing] = [Motion.Easing.LINEAR, Motion.Easing.IN_OUT, Motion.Easing.OUT_BACK]
	for curve: Motion.Easing in Motion.Easing.values():
		assert_bool(curve in _CURVES or curve in others).override_failure_message(str(Motion.Easing.find_key(curve))).is_true()


func test_each_curve_holds_across_a_dense_sweep() -> void:
	for curve: Motion.Easing in _CURVES:
		for k in 101:
			var t := k / 100.0
			assert_float(Motion.eased(curve, t)).override_failure_message("%s at %.2f" % [Motion.Easing.find_key(curve), t]) \
				.is_equal_approx(_bezier_by_bisection(_CURVES[curve], t), 1.0 / 255.0)


func test_a_curve_flat_at_its_ends_is_solved_where_newton_stalls() -> void:
	# x'(0) = x'(1) = 0: Newton's slope vanishes near the ends, bisection takes over.
	var flat := Vector4(0.0, 0.3, 1.0, 0.7)
	for t: float in [0.0001, 0.001, 0.01, 0.5, 0.99, 0.999, 0.9999]:
		assert_float(Motion._bezier(flat, t)).is_equal_approx(_bezier_by_bisection(flat, t), 1e-4)


func test_the_ring_curves_follow_their_formulas() -> void:
	for t: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		var in_out := 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
		assert_float(Motion.eased(Motion.Easing.IN_OUT, t)).is_equal_approx(in_out, 1.0 / 255.0)
		assert_float(Motion.eased(Motion.Easing.OUT_BACK, t)).is_equal_approx(1.0 + 2.2 * pow(t - 1.0, 3.0) + 1.2 * pow(t - 1.0, 2.0), 1.0 / 255.0)
	assert_float(Motion.eased(Motion.Easing.LINEAR, 0.3)).is_equal(0.3)


func test_a_curve_eases_a_tween() -> void:
	var node: Node2D = auto_free(Node2D.new())
	add_child(node)
	var tween := create_tween()
	tween.tween_property(node, ^"position:x", 100.0, 1.0).set_custom_interpolator(Motion.curve(Motion.Easing.EASE_OUT))
	tween.custom_step(0.5)
	assert_float(node.position.x).is_equal_approx(100.0 * _bezier_by_bisection(_CURVES[Motion.Easing.EASE_OUT], 0.5), 1e-3)
	tween.kill()


## The y of the curve where x is [param t], found by bisection on its parameter alone (no Newton step).
func _bezier_by_bisection(points: Vector4, t: float) -> float:
	var low := 0.0
	var high := 1.0
	for i in 60:
		var u := (low + high) / 2.0
		if _cubic(points.x, points.z, u) < t:
			low = u
		else:
			high = u
	return _cubic(points.y, points.w, (low + high) / 2.0)


func _cubic(a: float, b: float, u: float) -> float:
	return 3.0 * a * u * (1.0 - u) * (1.0 - u) + 3.0 * b * u * u * (1.0 - u) + u * u * u
