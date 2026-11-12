# SPDX-License-Identifier: GPL-3.0-or-later
class_name EdgeSmoothingScreen
extends ChoiceScreen
## "Which edge smoothing?", a note that the choice only changes the 3D's edges, and three cards: 4× (the default),
## 2× or none. B goes back.

const MSAA: Dictionary[StringName, Viewport.MSAA] = {
	&"4x": Viewport.MSAA_4X,
	&"2x": Viewport.MSAA_2X,
	&"off": Viewport.MSAA_DISABLED,
}
const NAMES: Dictionary[StringName, String] = {&"4x": "Smoothing 4×", &"2x": "Smoothing 2×", &"off": "No smoothing"}


func _init() -> void:
	can_go_back = true


## The smoothing [param viewport]'s 3D is drawn with.
static func of(viewport: Viewport) -> StringName:
	return MSAA.find_key(viewport.msaa_3d)


## Draws [param viewport]'s 3D with [param level] and has the renderer prepare its pipelines for it: it prepares them
## for the project's level alone, so one set apart from it is compiled a second time, late, as each model is first
## drawn, and the ones prepared stay in the driver's memory unused.
static func smooth(viewport: Viewport, level: Viewport.MSAA) -> void:
	viewport.msaa_3d = level
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/msaa_3d", level)


func _current() -> StringName:
	return of(get_viewport())
