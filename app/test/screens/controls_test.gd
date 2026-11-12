# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixtures := preload("res://test/screens/fixtures.gd")
const STYLES: Array[StringName] = [&"xbox", &"nintendo", &"playstation"]


func after_test() -> void:
	Controls.style = &"xbox"


## Every action's events, as text: what the input map does.
func _input_map() -> Dictionary:
	var map := {}
	for action in InputMap.get_actions():
		map[action] = str(InputMap.action_get_events(action))
	return map


func test_the_device_s_a_confirms_and_its_b_goes_back_whatever_style_is_chosen() -> void:
	var standard := _input_map()
	# One more pass confirms the first style with the keyboard's Enter instead of the pad.
	for pass_index in STYLES.size() + 1:
		var by_keyboard := pass_index == STYLES.size()
		var style_index := 0 if by_keyboard else pass_index
		Controls.style = &"xbox"
		var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
		device.curtain = true
		var carousel := Fixtures.fresh_carousel(self, device)
		assert_bool(await Fixtures.on(self, carousel, "ButtonStyle")).is_true()
		for step in style_index:
			await Fixtures.action(self, &"ui_right")
		# B chooses nothing: it is the device's going back.
		await Fixtures.joypad(self, JOY_BUTTON_B)
		assert_array(device.saves(&"button_style")).is_empty()
		if by_keyboard:
			await Fixtures.enter(self)
		else:
			await Fixtures.joypad(self, JOY_BUTTON_A)
		await Fixtures.choose_initial_region(self, carousel)
		assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
		assert_array(device.saves(&"button_style")).is_equal([STYLES[style_index]])
		assert_str(Controls.style).is_equal(STYLES[style_index])
		assert_dict(_input_map()).is_equal(standard)
		await Fixtures.joypad(self, JOY_BUTTON_A)
		assert_bool(await Fixtures.on(self, carousel, "AddConsole")).is_true()
		await Fixtures.joypad(self, JOY_BUTTON_B)
		assert_bool(await Fixtures.on(self, carousel, "NoConsole")).is_true()
		carousel.queue_free()


func test_the_style_stored_is_the_one_drawn_from_the_start() -> void:
	var device: Fixtures.NewDevice = auto_free(Fixtures.NewDevice.new())
	device.first_launch = false
	device.has_games = true
	device.button_style = "playstation"
	var carousel := Fixtures.fresh_carousel(self, device)
	await Fixtures.wait(self, func() -> bool: return carousel.is_shown())
	assert_str(Controls.style).is_equal("playstation")
