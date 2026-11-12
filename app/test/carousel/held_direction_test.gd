# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_however_many_events_a_held_stick_sends_wavering_about_its_dead_zone_holding_is_one_press_and_one_release() -> void:
	var random := Fixtures.cases(9)
	for i in 200:
		var direction := HeldDirection.new()
		var way := Fixtures.direction(random)
		var changes: Array[Vector2i] = []
		_stick(direction, way * random.randf_range(0.55, 1.0), changes)
		for event in random.randi_range(0, 30):
			_stick(direction, way * random.randf_range(0.3, 1.0), changes)
		for event in random.randi_range(1, 5):
			_stick(direction, way * random.randf_range(0.0, 0.2), changes)
		assert_array(changes).is_equal([Vector2i(way, 1), Vector2i(way, 0)])


func test_keys_press_and_release_their_direction() -> void:
	var direction := HeldDirection.new()
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	assert_bool(direction.update(right)).is_true()
	assert_bool(direction.update(right)).is_false()
	assert_array([direction.direction, direction.held]).is_equal([1, true])
	right.pressed = false
	assert_bool(direction.update(right)).is_true()
	assert_array([direction.direction, direction.held]).is_equal([1, false])


func test_a_stick_resting_in_its_dead_zone_does_not_let_go_of_the_d_pad() -> void:
	var direction := HeldDirection.new()
	var pad := InputEventJoypadButton.new()
	pad.button_index = JOY_BUTTON_DPAD_RIGHT
	pad.pressed = true
	assert_bool(_sent(direction, pad)).is_true()
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_X
	stick.axis_value = 0.05
	assert_bool(_sent(direction, stick)).is_false()
	assert_array([direction.direction, direction.held]).is_equal([1, true])
	pad.pressed = false
	assert_bool(_sent(direction, pad)).is_true()
	assert_bool(direction.held).is_false()


## Sends [param event] as the device would, the engine's input state first; whether it changed [param direction].
func _sent(direction: HeldDirection, event: InputEvent) -> bool:
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return direction.update(event)


## Moves the left stick along its horizontal axis to [param value], recording any change.
func _stick(direction: HeldDirection, value: float, changes: Array[Vector2i]) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = value
	if _sent(direction, motion):
		changes.append(Vector2i(direction.direction, 1 if direction.held else 0))
