# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const WELCOME := preload("res://screens/welcome.tscn")


## Whether [param welcome] is passed, after [param frames] frames of [param press] being pressed or
## not.
func _passed_after(welcome: Welcome, frames: int, press: bool) -> bool:
	var passed := [false]
	var wait := func() -> void:
		await welcome.passed()
		passed[0] = true
	wait.call()
	if press:
		await Fixtures.joypad(self, JOY_BUTTON_X)
	for frame in frames:
		await await_idle_frame()
	return passed[0]


func test_the_welcome_waits_for_a_button_however_long_it_takes() -> void:
	var welcome: Welcome = auto_free(WELCOME.instantiate())
	add_child(welcome)
	assert_bool(await _passed_after(welcome, 30, false)).is_false()


func test_any_button_passes_the_welcome_at_once() -> void:
	var welcome: Welcome = auto_free(WELCOME.instantiate())
	add_child(welcome)
	assert_bool(await _passed_after(welcome, 1, true)).is_true()
