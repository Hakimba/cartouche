# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The background as the app starts and runs: the first frame already on the stored one, and "Like the device"
## following the system's theme.

const Fixtures := preload("res://test/screens/fixtures.gd")

var _system_dark := Backdrop.system_dark


func after_test() -> void:
	Backdrop.system_dark = _system_dark
	Backdrop.show(&"light", true)


func _shown(device: Fixtures.NewDevice) -> Carousel:
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(await Fixtures.until(self, func() -> bool: return carousel._shown)).is_true()
	return carousel


func test_the_first_frame_is_drawn_on_the_stored_background_before_the_library_is_read() -> void:
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.chosen_backdrop = &"dark"
	var carousel := Fixtures.fresh_carousel(self, device)
	assert_bool(carousel._shown).is_false()
	assert_int(Backdrop.palette.scheme).is_equal(StudioTokens.Scheme.DARK)
	assert_that(RenderingServer.get_default_clear_color()).is_equal(Color.BLACK)
	assert_bool((carousel.get_node("Backdrop") as CanvasLayer).visible).is_true()


func test_like_the_device_follows_the_system_s_theme_when_the_app_comes_back() -> void:
	# A lambda keeps a copy of a local: the system's theme is held in an array the test changes.
	var dark := [false]
	Backdrop.system_dark = func() -> bool: return dark[0]
	var device := Fixtures.past_first_launch(self, {"ps2": 3})
	device.chosen_backdrop = &"device"
	var carousel := await _shown(device)
	assert_int(Backdrop.palette.scheme).is_equal(StudioTokens.Scheme.LIGHT)
	dark[0] = true
	carousel.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_int(Backdrop.palette.scheme).is_equal(StudioTokens.Scheme.DARK)
	assert_str(Backdrop.choice).is_equal("device")
	dark[0] = false
	carousel.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	assert_int(Backdrop.palette.scheme).is_equal(StudioTokens.Scheme.LIGHT)
