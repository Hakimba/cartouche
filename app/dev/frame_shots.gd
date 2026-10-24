# SPDX-License-Identifier: GPL-3.0-or-later
class_name FrameShots
extends Node
## Saves pictures of the carousel at set frames, to check that a change keeps every pixel: started
## with `--shots=DIR` (debug builds) and Godot's `--fixed-fps 60`, each frame lasts exactly 1/60 s,
## so whatever moves with time (the float, the sway) is at the same place in the same
## frame of every run. Presses are sent at set frames too: the consoles screen, a step to the next
## console and back, the ring, a console's properties, the console turned by the stick, going into
## it, the games screen, a game turned, a game's properties, the settings, many of them half-way
## through their animations. The app is kept awake all along ([member Resting.stays_awake]). Then it
## quits. Two runs of the same code give the same pictures; compare a run before a change with one
## after it.

## The presses, by frame.
const _PRESSES: Dictionary[int, StringName] = {
	150: &"carousel_right", 190: &"carousel_left", 241: &"ui_down", 331: &"screen_back",
	420: &"open_properties", 511: &"screen_back", 600: &"ui_accept", 781: &"carousel_right",
	901: &"open_properties", 991: &"screen_back", 1080: &"open_settings", 1171: &"screen_back",
	1260: &"screen_back",
}
## The right stick pushed right (true) and let go, by frame: a console turned, which turns back as
## it is gone into, then a game.
const _PUSHED: Dictionary[int, bool] = {540: true, 570: false, 800: true, 830: false}
## The pictures saved, by frame, under these names.
const _SHOTS: Dictionary[int, String] = {
	160: "console_stepping", 200: "console_back", 240: "consoles", 256: "ring_opening", 330: "ring",
	434: "console_properties_opening", 510: "console_properties", 603: "entering_3", 606: "entering_6",
	609: "entering_9", 612: "entering_12", 630: "entering", 660: "entering_late", 675: "entering_75",
	690: "entering_90", 705: "entering_105", 780: "games", 790: "scrolling", 840: "game_turned",
	900: "games_next", 915: "properties_opening", 990: "properties", 1170: "settings", 1263: "leaving_3",
	1266: "leaving_6", 1269: "leaving_9", 1272: "leaving_12", 1290: "leaving", 1420: "consoles_back",
}

var _folder: String
var _frame := 0


func _init(folder: String) -> void:
	_folder = folder


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	(get_parent() as Carousel)._resting.stays_awake = true


func _process(_delta: float) -> void:
	_frame += 1
	if _frame in _PRESSES:
		CarouselBench.press(_PRESSES[_frame])
	if _frame in _PUSHED:
		CarouselBench.act(&"inspect_right", _PUSHED[_frame])
	if _frame in _SHOTS:
		var shot := _SHOTS[_frame]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_folder.path_join(shot + ".png"))
		if _frame == _SHOTS.keys().max():
			get_tree().quit()

