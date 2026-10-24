# SPDX-License-Identifier: GPL-3.0-or-later
class_name Resting
extends Node
## Lets the app rest while nothing happens. With nothing pressed, touched or moving for
## [constant SLOW_AFTER_S], Godot's low processor mode takes over: it draws only when something
## changes, its loop running at the rate of `application/run/low_processor_mode_sleep_usec`, rather
## than capping the engine's frame rate, which kept frames slow for a while after waking. After
## [constant STILL_AFTER_S], the motions that go on by themselves (the nodes of the group
## [constant PACED]: the games' and consoles' float and sway, the welcome's worm)
## slow to a stop in [constant STOPPING_S], and from then on the screen is drawn only when something
## on it changes (the clock, the battery). The first press, touch or return to the app wakes
## everything at once, and acts as it always does. Animations no press started (a message) play
## without waking it.

## Nodes moving by themselves, at their `pace`: 1 awake, down to 0, still.
const PACED := &"paced"
const SLOW_AFTER_S := 2.0
const STILL_AFTER_S := 5.0
const STOPPING_S := 1.2
## A stick pushed less than this rests on its centre.
const _STICK_DEAD := 0.3

## Whether something goes on that must not be slowed (labels downloading, a launch, the way into or
## out of a console, the order ring moving or placing, a console arriving): no rest meanwhile.
var moving := func() -> bool: return false
## Debug runs measuring motion keep the app awake.
var stays_awake := false
## Optional visible motion keeps full frame pacing until it has stopped, without postponing rest.
var smooth_motion := func() -> bool: return false
## The pace of what moves by itself, given to the group [constant PACED]; at 0, only what changes
## is drawn.
var pace := 1.0:
	set(value):
		pace = value
		get_tree().set_group(PACED, &"pace", pace)
		if pace == 0.0:
			Diagnostics.trace("rest", "still")

var _idle_s := 0.0


func _enter_tree() -> void:
	get_tree().root.window_input.connect(_on_window_input)


func _exit_tree() -> void:
	wake()
	get_tree().root.window_input.disconnect(_on_window_input)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		wake()


func _process(delta: float) -> void:
	if stays_awake or Input.is_anything_pressed() or moving.call():
		wake()
		return
	_idle_s += delta
	if _idle_s >= SLOW_AFTER_S and not smooth_motion.call() and not OS.low_processor_usage_mode:
		OS.low_processor_usage_mode = true
		Diagnostics.trace("rest", "drawn when something changes")
	var paced := clampf(1.0 - (_idle_s - STILL_AFTER_S) / STOPPING_S, 0.0, 1.0)
	if paced != pace:
		pace = paced


## Everything as when awake: the screen drawn at every frame, the motions at full pace; also
## for what comes in without a press, such as the carousel after a long start.
func wake() -> void:
	_idle_s = 0.0
	if not OS.low_processor_usage_mode and pace == 1.0:
		return
	OS.low_processor_usage_mode = false
	pace = 1.0
	Diagnostics.trace("rest", "awake")


func _on_window_input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) < _STICK_DEAD:
		return
	wake()
