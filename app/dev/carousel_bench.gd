# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselBench
extends Node
## Measures the carousel in debug builds, driven like a user would: `scroll` holds right for
## [constant _DURATION_S], `switch` changes platform every [constant _SWITCH_EVERY_S], `turn` holds
## the right stick, so that the selected game keeps turning, underside and clear parts shown,
## `scrape` holds right as `scroll` does but from the start, while the disc scans download. Then
## traces one `bench` line of `key=value` frame statistics, read by `dev/bench.sh`. `launch`
## presses A once: [GameLaunch] traces its own `bench: launch:` line, with the insertion's frames
## and the times to check and to start the game. Each but `scrape` starts once the app's start
## has settled, which is measured on its own.

const _SETTLE_S := 5.0
const _DURATION_S := 30.0
const _SWITCH_EVERY_S := 0.6

var _scenario: String
var _row: ShelfRow
var _frames_ms := PackedFloat32Array()
var _elapsed_s := 0.0
var _next_switch_s := 0.0
var _steps := 0


func _init(scenario: String, row: ShelfRow) -> void:
	_scenario = scenario
	_row = row


func _ready() -> void:
	if _scenario != "scrape":
		set_process(false)
		await get_tree().create_timer(_SETTLE_S).timeout
		set_process(true)
	_row.selection_changed.connect(func(_game: AndroidServices.Game) -> void: _steps += 1)
	if _scenario in ["scroll", "scrape"]:
		_act(&"carousel_right", true)
	elif _scenario == "turn":
		_act(&"inspect_right", true)
	elif _scenario == "launch":
		_act(&"ui_accept", true)
		_act(&"ui_accept", false)
		queue_free()
	Diagnostics.trace("bench", "%s started" % _scenario)


func _process(delta: float) -> void:
	_elapsed_s += delta
	_frames_ms.append(delta * 1000.0)
	if _scenario == "switch" and _elapsed_s >= _next_switch_s:
		_next_switch_s += _SWITCH_EVERY_S
		_act(&"tab_next", true)
		_act(&"tab_next", false)
	if _elapsed_s >= _DURATION_S:
		if _scenario in ["scroll", "scrape"]:
			_act(&"carousel_right", false)
		elif _scenario == "turn":
			_act(&"inspect_right", false)
		_report()
		queue_free()


func _act(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _report() -> void:
	var frames := Diagnostics.frame_statistics(_frames_ms, _elapsed_s)
	Diagnostics.trace("bench", "%s: %s steps=%d" % [_scenario, frames, _steps])
