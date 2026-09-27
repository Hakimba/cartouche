# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/carousel/fixtures.gd")


func test_however_many_events_a_held_stick_sends_holding_is_one_press_and_one_release() -> void:
	var random := Fixtures.cases(9)
	for i in 200:
		var direction := HeldDirection.new()
		var way := Fixtures.direction(random)
		var changes: Array[Vector2i] = []
		for event in random.randi_range(1, 30):
			_stick(direction, way * random.randf_range(0.55, 1.0), changes)
		for event in random.randi_range(1, 5):
			_stick(direction, way * random.randf_range(0.0, 0.3), changes)
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


## Moves the left stick along its horizontal axis to [param value], recording any change.
func _stick(direction: HeldDirection, value: float, changes: Array[Vector2i]) -> void:
	var motion := InputEventJoypadMotion.new()
	motion.axis = JOY_AXIS_LEFT_X
	motion.axis_value = value
	if direction.update(motion):
		changes.append(Vector2i(direction.direction, 1 if direction.held else 0))
