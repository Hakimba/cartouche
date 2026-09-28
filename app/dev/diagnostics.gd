# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Traces what the app receives to the log in debug builds, registered as the `Diagnostics`
## autoload: input events with the actions they match, focus changes, lifecycle notifications,
## frames that miss 60 fps, and whatever other code passes to [method trace] (plugin traffic, for
## instance). On a device, `dev/logs.sh` follows them together with the Kotlin plugin's traces.
## Release builds trace nothing.

const _MAX_DETAIL := 500
## Longer frames are traced: at 60 fps, a frame takes 16.7 ms.
const SLOW_FRAME_MS := 20.0
const _NOTIFICATIONS: Dictionary[int, String] = {
	NOTIFICATION_WM_GO_BACK_REQUEST: "back request",
	NOTIFICATION_APPLICATION_RESUMED: "resumed",
	NOTIFICATION_APPLICATION_PAUSED: "paused",
	NOTIFICATION_APPLICATION_FOCUS_IN: "focus in",
	NOTIFICATION_APPLICATION_FOCUS_OUT: "focus out",
	NOTIFICATION_WM_CLOSE_REQUEST: "close request",
}

## Rendering pipelines compiled while drawing, which stall the frame they are needed in.
const _PIPELINE_MONITORS: Dictionary[String, Performance.Monitor] = {
	"canvas": Performance.PIPELINE_COMPILATIONS_CANVAS,
	"mesh": Performance.PIPELINE_COMPILATIONS_MESH,
	"surface": Performance.PIPELINE_COMPILATIONS_SURFACE,
	"draw": Performance.PIPELINE_COMPILATIONS_DRAW,
	"specialization": Performance.PIPELINE_COMPILATIONS_SPECIALIZATION,
}

## Whether traces are written; check it before building an expensive detail.
var enabled := OS.is_debug_build()
## Pipelines compiled so far, by monitor name.
var _pipelines: Dictionary[String, int] = {}
## Whether each joypad axis (keyed by device * 100 + axis) is past half-way.
var _axes_past_half: Dictionary[int, bool] = {}


func _ready() -> void:
	set_process(enabled)
	if enabled:
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		get_tree().root.window_input.connect(_on_window_input)
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _process(delta: float) -> void:
	var compiled := PackedStringArray()
	for monitor in _PIPELINE_MONITORS:
		var count := int(Performance.get_monitor(_PIPELINE_MONITORS[monitor]))
		var before: int = _pipelines.get(monitor, 0)
		if count != before:
			compiled.append("%s %d" % [monitor, count - before])
			_pipelines[monitor] = count
	if delta * 1000.0 > SLOW_FRAME_MS:
		# Where the time went in the previous frame: scripts and engine on the main thread, drawing
		# on the CPU and the GPU.
		var viewport := get_viewport().get_viewport_rid()
		var pipelines := ", pipelines compiled: " + ", ".join(compiled) if compiled else ""
		trace("frame", "slow frame: %.1f ms (process %.1f ms, draw %.1f ms, gpu %.1f ms)%s" % [
			delta * 1000.0, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(viewport),
			RenderingServer.viewport_get_measured_render_time_gpu(viewport), pipelines])


func _notification(what: int) -> void:
	if what in _NOTIFICATIONS:
		trace("app", _NOTIFICATIONS[what])


## Writes one `area: detail` line to the log, in debug builds only; long details are cut.
func trace(area: String, detail: String) -> void:
	if enabled:
		var shown := detail if detail.length() <= _MAX_DETAIL else detail.left(_MAX_DETAIL) + "…"
		print("Cartouche %s: %s" % [area, shown])


## `key=value` statistics of frames lasting [param frames_ms] over [param seconds], as the
## `bench` lines `dev/bench.sh` reads write them.
func frame_statistics(frames_ms: PackedFloat32Array, seconds: float) -> String:
	if frames_ms.is_empty() or seconds <= 0.0:
		return "frames=0"
	var sorted := frames_ms.duplicate()
	sorted.sort()
	var slow := sorted.size() - sorted.bsearch(SLOW_FRAME_MS, false)
	return "frames=%d seconds=%.1f fps=%.1f worst_ms=%.1f p95_ms=%.1f slow_frames=%d" % [
		sorted.size(), seconds, sorted.size() / seconds, sorted[-1], sorted[int(sorted.size() * 0.95)], slow]


## The value of `--[param option]=value` among the arguments the app was started with, in debug
## builds; empty otherwise. On Android they come from the launch intent (see
## [method AndroidServices.launch_arguments]).
func argument(option: String) -> String:
	if not enabled:
		return ""
	var prefix := "--%s=" % option
	var arguments := OS.get_cmdline_user_args()
	arguments.append_array(Android.launch_arguments())
	for given in arguments:
		if given.begins_with(prefix):
			return given.trim_prefix(prefix)
	return ""


# Every event reaches this signal before any node handles it, including those a page consumes.
func _on_window_input(event: InputEvent) -> void:
	if event.is_echo() or not _is_change(event):
		return
	var actions := PackedStringArray()
	for action in InputMap.get_actions():
		if event.is_action(action, true):
			actions.append(action)
	var state := "pressed" if event.is_pressed() else "released"
	var matched := " → " + ", ".join(actions) if actions else ""
	trace("input", "%s %s, device %d%s" % [event.as_text(), state, event.device, matched])


## Buttons, keys and touches, and sticks crossing half-way: not every tiny motion.
func _is_change(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		var motion := event as InputEventJoypadMotion
		var key := motion.device * 100 + motion.axis
		var was_past: bool = _axes_past_half.get(key, false)
		_axes_past_half[key] = absf(motion.axis_value) > 0.5
		return _axes_past_half[key] != was_past
	return event is InputEventKey or event is InputEventJoypadButton \
			or event is InputEventScreenTouch or event is InputEventMouseButton


func _on_focus_changed(control: Control) -> void:
	trace("focus", str(control.get_path()))
