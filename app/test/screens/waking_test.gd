# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The app at rest wakes with the first press, push or tap, which acts as it always does (INV-E8-01).

const Fixtures := preload("res://test/screens/fixtures.gd")
## A finger this far beside the console in the middle moves one console that way.
const BESIDE := Vector2(420.0, 0.0)

func after_test() -> void:
	OS.low_processor_usage_mode = false


## A carousel of two consoles, still, its first console selected.
func _still() -> Carousel:
	var carousel := Fixtures.fresh_carousel(self, Fixtures.past_first_launch(self, {"ps2": 3, "gba": 2}))
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	while carousel._consoles.selected_index() > 0:
		await Fixtures.action(self, &"carousel_left")
	carousel._resting.stays_awake = false
	carousel._resting._process(Resting.STILL_AFTER_S + Resting.STOPPING_S + 0.1)
	assert_float(carousel._resting.pace).is_equal(0.0)
	return carousel


func _assert_woken_on_the_next(carousel: Carousel) -> void:
	assert_float(carousel._resting.pace).is_equal(1.0)
	assert_bool(OS.low_processor_usage_mode).is_false()
	assert_int(carousel._consoles.selected_index()).is_equal(1)


func test_INV_E8_01_the_first_press_wakes_the_app_and_acts() -> void:
	var carousel := await _still()
	await Fixtures.action(self, &"carousel_right")
	_assert_woken_on_the_next(carousel)


func test_INV_E8_01_the_first_push_of_the_stick_wakes_the_app_and_acts() -> void:
	var carousel := await _still()
	for value: float in [1.0, 0.0]:
		var push := InputEventJoypadMotion.new()
		push.axis = JOY_AXIS_LEFT_X
		push.axis_value = value
		Input.parse_input_event(push)
		await await_idle_frame()
	_assert_woken_on_the_next(carousel)


func test_INV_E8_01_the_first_tap_wakes_the_app_and_acts() -> void:
	var carousel := await _still()
	await Fixtures.touch(self, [carousel._selected_point() + BESIDE])
	_assert_woken_on_the_next(carousel)
