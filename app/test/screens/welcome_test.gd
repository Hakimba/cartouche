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


func test_at_rest_the_worm_stops_where_it_is_and_crawls_on_from_there() -> void:
	var worm: LogoWorm = auto_free(LogoWorm.new())
	add_child(worm)
	worm._ring = PackedVector2Array([Vector2(0, 0), Vector2(40, 0), Vector2(40, 40), Vector2(0, 40)])
	worm._process(1.0)
	var crawled := worm.points
	# Still, it does not even run: drawn again each frame, it would make every frame drawn.
	worm.pace = 0.0
	assert_bool(worm.is_processing()).is_false()
	worm._process(5.0)
	assert_array(worm.points).is_equal(crawled)
	# Woken, it crawls on from there: as a worm that never stopped, a second later.
	worm.pace = 1.0
	assert_bool(worm.is_processing()).is_true()
	worm._process(1.0)
	assert_array(worm.points).is_not_equal(crawled)
	var twin: LogoWorm = auto_free(LogoWorm.new())
	add_child(twin)
	twin._ring = worm._ring
	twin._process(2.0)
	assert_array(worm.points).is_equal(twin.points)
