# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselBench
extends Node
## Measures the carousel in debug builds, driven like a user would: `scroll` holds right for
## [constant _DURATION_S], `switch` changes platform every [constant _SWITCH_EVERY_S]. Then traces
## one `bench` line of `key=value` frame statistics, read by `dev/bench.sh`. It starts once the
## start has settled, which is measured on its own.

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
	set_process(false)
	await get_tree().create_timer(_SETTLE_S).timeout
	set_process(true)
	_row.selection_changed.connect(func(_game: AndroidServices.Game) -> void: _steps += 1)
	if _scenario == "scroll":
		_act(&"carousel_right", true)
	Diagnostics.trace("bench", "%s started" % _scenario)


func _process(delta: float) -> void:
	_elapsed_s += delta
	_frames_ms.append(delta * 1000.0)
	if _scenario == "switch" and _elapsed_s >= _next_switch_s:
		_next_switch_s += _SWITCH_EVERY_S
		_act(&"tab_next", true)
		_act(&"tab_next", false)
	if _elapsed_s >= _DURATION_S:
		if _scenario == "scroll":
			_act(&"carousel_right", false)
		_report()
		queue_free()


func _act(action: StringName, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _report() -> void:
	var sorted := _frames_ms.duplicate()
	sorted.sort()
	var slow := sorted.size() - sorted.bsearch(Diagnostics.SLOW_FRAME_MS, false)
	Diagnostics.trace("bench", "%s: frames=%d seconds=%.1f fps=%.1f worst_ms=%.1f p95_ms=%.1f slow_frames=%d steps=%d" % [
		_scenario, sorted.size(), _elapsed_s, sorted.size() / _elapsed_s, sorted[-1],
		sorted[int(sorted.size() * 0.95)], slow, _steps])
