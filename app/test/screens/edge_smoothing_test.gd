# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The edge smoothing chosen is the one the renderer prepares its pipelines for.

const _SETTING := "rendering/anti_aliasing/quality/msaa_3d"


func after_test() -> void:
	EdgeSmoothingScreen.smooth(get_viewport(), Viewport.MSAA_4X)


func test_the_level_drawn_is_the_level_prepared() -> void:
	for choice: StringName in EdgeSmoothingScreen.MSAA:
		var level := EdgeSmoothingScreen.MSAA[choice]
		EdgeSmoothingScreen.smooth(get_viewport(), level)
		var prepared: int = ProjectSettings.get_setting(_SETTING)
		assert_int(get_viewport().msaa_3d).is_equal(level)
		assert_int(prepared).is_equal(level)
