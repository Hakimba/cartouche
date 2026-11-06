# SPDX-License-Identifier: GPL-3.0-or-later
class_name FrameShots
extends Node
## Saves pictures of the carousel at set frames, to check that a change keeps every pixel: started
## with `--shots=DIR` (debug builds) and Godot's `--fixed-fps 60`, each frame lasts exactly 1/60 s,
## so whatever moves with time (the float, the sway) is at the same place in the same
## frame of every run. Presses are sent at set frames too: the consoles screen, a step to the next
## console and back, the ring, a console's properties, the console turned by the stick, going into
## it, the games screen, a game turned, a game's properties, the settings, the "+" form, a console's
## Edit form, the row scrolled fast, a launch (run with `--launch=rehearse`) and a toss, many of them
## half-way through their animations. The app is kept awake all along ([member Resting.stays_awake]).
## Then it quits. Two runs of the same code give the same pictures; compare a run before a change with
## one after it.

## The presses, by frame.
const _PRESSES: Dictionary[int, StringName] = {
	150: &"carousel_right", 190: &"carousel_left", 241: &"ui_down", 331: &"screen_back",
	420: &"open_properties", 511: &"screen_back", 600: &"ui_accept", 781: &"carousel_right",
	901: &"open_properties", 991: &"screen_back", 1080: &"open_settings", 1171: &"screen_back",
	1260: &"screen_back", 1490: &"ui_accept", 1610: &"screen_back", 1700: &"open_properties",
	1850: &"screen_back", 1940: &"ui_accept", 2300: &"ui_accept",
}
## Actions held, by frame, then let go: the right stick turning a console, which turns back as it is
## gone into, then a game; up opening the "+" ball; right scrolling the row fast; up tossing a game.
const _HELD: Dictionary[int, StringName] = {
	540: &"inspect_right", 800: &"inspect_right", 1440: &"ui_up", 2110: &"carousel_right", 2800: &"ui_up",
}
const _LET_GO: Dictionary[int, StringName] = {
	570: &"inspect_right", 830: &"inspect_right", 1500: &"ui_up", 2170: &"carousel_right", 2830: &"ui_up",
}
## The pictures saved, by frame, under these names.
const _SHOTS: Dictionary[int, String] = {
	160: "console_stepping", 200: "console_back", 240: "consoles", 256: "ring_opening", 330: "ring",
	434: "console_properties_opening", 510: "console_properties", 603: "entering_3", 606: "entering_6",
	609: "entering_9", 612: "entering_12", 630: "entering", 660: "entering_late", 675: "entering_75",
	690: "entering_90", 705: "entering_105", 780: "games", 790: "scrolling", 840: "game_turned",
	900: "games_next", 915: "properties_opening", 990: "properties", 1170: "settings", 1263: "leaving_3",
	1266: "leaving_6", 1269: "leaving_9", 1272: "leaving_12", 1290: "leaving", 1420: "consoles_back",
	1480: "plus_held", 1600: "add", 1715: "edit_opening", 1800: "edit", 1830: "edit_swaying",
	2100: "games_again", 2120: "fast_1", 2125: "fast_2", 2130: "fast_3", 2140: "fast_4", 2150: "fast_5",
	2165: "fast_6", 2180: "fast_slowing", 2290: "fast_settled", 2310: "launch_10", 2330: "launch_30",
	2360: "launch_60", 2400: "launch_100", 2450: "launch_150", 2520: "launch_220", 2600: "launch_300",
	2700: "launch_back", 2810: "toss_10", 2830: "toss_30", 2860: "toss_60", 2950: "tossed",
}

var _folder: String
var _frame := 0


func _init(folder: String) -> void:
	_folder = folder


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_folder)
	var carousel := get_parent() as Carousel
	carousel._resting.stays_awake = true
	# The toss lands on the same game in every run: the shelf shown before drew its pick unseeded.
	carousel._row.random.seed = 1
	if carousel._row.has_games():
		carousel._row._draw_pick()


func _process(_delta: float) -> void:
	_frame += 1
	if _frame in _PRESSES:
		CarouselBench.press(_PRESSES[_frame])
	if _frame in _HELD:
		CarouselBench.act(_HELD[_frame], true)
	if _frame in _LET_GO:
		CarouselBench.act(_LET_GO[_frame], false)
	if _frame in _SHOTS:
		var shot := _SHOTS[_frame]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_folder.path_join(shot + ".png"))
		if _frame == _SHOTS.keys().max():
			get_tree().quit()

