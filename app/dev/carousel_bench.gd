# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselBench
extends Node
## Measures the carousel in debug builds, driven like a user would, on the games screen of the
## platform the app opens on: `scroll` holds right for [constant _DURATION_S], `turn` holds the right
## stick, so that the selected game keeps turning, underside and clear parts shown, `scrape` holds
## right as `scroll` does but from the start, while the disc scans download. `enter` goes into the
## console and back out every [constant _ENTER_EVERY_S], from the consoles screen; `step` moves along
## the consoles, right then left, every [constant _STEP_EVERY_S]. `properties` opens the selected game's
## properties and closes them again every [constant _ENTER_EVERY_S]; `order` opens the ring putting
## the consoles in order and, in turn, takes the console under the cursor, moves it right and left
## and lets it go, a press every [constant _STEP_EVERY_S], the console held drawn as a sticker; `swipe`
## swipes the games by touch every [constant _ENTER_EVERY_S], a game each time. Then traces one
## `bench` line of `key=value` frame statistics, read by `dev/bench.sh`. `launch` presses A once:
## [GameLaunch] traces its own `bench: launch:` line, with the launch's frames and the times to
## check and to start the game. Each but `scrape` starts once the app's start has settled, which is
## measured on its own.

const _SETTLE_S := 5.0
const _DURATION_S := 30.0
const _ENTER_EVERY_S := 3.0
const _STEP_EVERY_S := 0.6
## The presses `order` goes round: take, move right twice, back left twice, let go.
const _ORDER_PRESSES: Array[StringName] = [&"ui_accept", &"carousel_right", &"carousel_right",
	&"carousel_left", &"carousel_left", &"screen_back"]
## The action each scenario holds from its start to its end.
const _HELD: Dictionary[String, StringName] = {
	"scroll": &"carousel_right", "scrape": &"carousel_right", "turn": &"inspect_right",
}

var _scenario: String
var _carousel: Carousel
var _row: ShelfRow
var _frames_ms := PackedFloat32Array()
var _elapsed_s := 0.0
var _next_action_s := 0.0
var _steps := 0


func _init(scenario: String, carousel: Carousel, row: ShelfRow) -> void:
	_scenario = scenario
	_carousel = carousel
	_row = row


func _ready() -> void:
	set_process(false)
	if _scenario != "scrape":
		await get_tree().create_timer(_SETTLE_S).timeout
	if _scenario not in ["enter", "step", "order"]:
		_press(&"ui_accept")
		while _carousel.screen() != Carousel.Screen.GAMES:
			await _carousel.screen_changed
	set_process(true)
	_row.selection_changed.connect(func(_game: AndroidServices.Game) -> void: _steps += 1)
	if _scenario in _HELD:
		_act(_HELD[_scenario], true)
	elif _scenario == "launch":
		_press(&"ui_accept")
		queue_free()
	elif _scenario == "order":
		_press(&"ui_down")
	Diagnostics.trace("bench", "%s started" % _scenario)


func _process(delta: float) -> void:
	_elapsed_s += delta
	_frames_ms.append(delta * 1000.0)
	if _scenario == "enter" and _elapsed_s >= _next_action_s:
		_next_action_s += _ENTER_EVERY_S
		_press(&"ui_accept" if _carousel.screen() == Carousel.Screen.CONSOLES else &"screen_back")
	elif _scenario == "step" and _elapsed_s >= _next_action_s:
		_next_action_s += _STEP_EVERY_S
		_steps += 1
		_press(&"carousel_right" if _steps % 2 == 1 else &"carousel_left")
	elif _scenario == "properties" and _elapsed_s >= _next_action_s:
		_next_action_s += _ENTER_EVERY_S
		_press(&"open_properties" if _carousel.screen() == Carousel.Screen.GAMES else &"screen_back")
	elif _scenario == "order" and _elapsed_s >= _next_action_s:
		_next_action_s += _STEP_EVERY_S
		_press(_ORDER_PRESSES[_steps % _ORDER_PRESSES.size()])
		_steps += 1
	elif _scenario == "swipe" and _elapsed_s >= _next_action_s:
		_next_action_s += _ENTER_EVERY_S
		_swipe()
	if _elapsed_s >= _DURATION_S:
		if _scenario in _HELD:
			_act(_HELD[_scenario], false)
		_report()
		queue_free()


## A finger swiped from right to left beside the game in the middle, a few frames long.
func _swipe() -> void:
	var window := get_tree().root.get_final_transform()
	var at := Vector2(1100.0, 760.0)
	var touch := InputEventScreenTouch.new()
	touch.position = window * at
	touch.pressed = true
	Input.parse_input_event(touch)
	for move in 4:
		await get_tree().process_frame
		at.x -= 160.0
		var drag := InputEventScreenDrag.new()
		drag.position = window * at
		Input.parse_input_event(drag)
	touch = touch.duplicate()
	touch.position = window * at
	touch.pressed = false
	Input.parse_input_event(touch)


func _press(action: StringName) -> void:
	_act(action, true)
	_act(action, false)


func _act(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _report() -> void:
	var frames := Diagnostics.frame_statistics(_frames_ms, _elapsed_s)
	# Godot's own memory, apart from what the graphics driver holds.
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1e6
	var video_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6
	Diagnostics.trace("bench", "%s: %s steps=%d static_mb=%.1f video_mb=%.1f" % [_scenario, frames, _steps,
		static_mb, video_mb])
