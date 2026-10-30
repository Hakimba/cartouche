# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Traces what the app receives to the log in debug builds, registered as the `Diagnostics`
## autoload: input events with the actions they match, focus changes, lifecycle notifications,
## frames that miss their rate (60 a second, 30 at rest), and whatever other code passes to
## [method trace] (plugin traffic, for instance). On a device, `scripts/logs.sh` follows them together
## with the Kotlin plugin's traces. Release builds trace nothing.

const _MAX_DETAIL := 500
## Longer frames are traced: at 60 fps, a frame takes 16.7 ms.
const SLOW_FRAME_MS := 20.0
## Under a rate cap, a frame lands within this of its share of the second.
const _CAPPED_MARGIN_MS := 3.3
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
## How long the last frame took by the clock, in debug builds. A frame's delta is not: the engine keeps it
## near its physics steps (at most about 150 ms) and pays a longer stall back over the next frames.
var frame_ms := 0.0
## Pipelines compiled so far, by monitor name.
var _pipelines: Dictionary[String, int] = {}
## Whether each joypad axis (keyed by device * 100 + axis) is past half-way.
var _axes_past_half: Dictionary[int, bool] = {}
## The rate the last frame ended under (see [method _rate]); 0 for none.
var _rate_cap := 0
var _frame_started_us := 0
## The most the engine placed on the graphics card so far, in bytes: past a few hundred MB, a peak costs a whole
## new block of the driver's memory, kept afterwards.
var _video_peak := 0.0


## A frame's budget under a rate cap of [param fps] frames a second, 0 for none.
static func _budget_ms(fps: int) -> float:
	return SLOW_FRAME_MS if fps == 0 else maxf(SLOW_FRAME_MS, 1000.0 / fps + _CAPPED_MARGIN_MS)


## The frames a second the engine's loop runs at most: its rate in low processor mode, else 0 for none.
static func _rate() -> int:
	return int(1_000_000.0 / OS.low_processor_usage_mode_sleep_usec) if OS.low_processor_usage_mode else 0


func _ready() -> void:
	start_bridge()
	set_process(enabled)
	if enabled:
		trace("app", "engine ready %d ms after it started" % Time.get_ticks_msec())
		RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
		get_tree().root.window_input.connect(_on_window_input)
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _process(delta: float) -> void:
	var now_us := Time.get_ticks_usec()
	frame_ms = (now_us - _frame_started_us) / 1000.0 if _frame_started_us else delta * 1000.0
	_frame_started_us = now_us
	var video := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	if video > _video_peak + 4e6:
		_video_peak = video
		trace("memory", "peak at frame %d: %s" % [Engine.get_process_frames(), memory()])
	var compiled := PackedStringArray()
	for monitor in _PIPELINE_MONITORS:
		var count := int(Performance.get_monitor(_PIPELINE_MONITORS[monitor]))
		var before: int = _pipelines.get(monitor, 0)
		if count != before:
			compiled.append("%s %d" % [monitor, count - before])
			_pipelines[monitor] = count
	# At rest the app's loop runs about 30 times a second ([Resting]): a frame is slow past the budget
	# of the rate it ran under, as it was before a change of rate or after it.
	var budget_ms := maxf(_budget_ms(_rate_cap), _budget_ms(_rate()))
	_rate_cap = _rate()
	if frame_ms > budget_ms:
		# Where the time went in the previous frame: scripts and engine on the main thread, drawing
		# on the CPU and the GPU.
		var viewport := get_viewport().get_viewport_rid()
		var pipelines := ", pipelines compiled: " + ", ".join(compiled) if compiled else ""
		trace("frame", "slow frame: %.1f ms (process %.1f ms, draw %.1f ms, gpu %.1f ms)%s" % [
			frame_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
			RenderingServer.viewport_get_measured_render_time_cpu(viewport),
			RenderingServer.viewport_get_measured_render_time_gpu(viewport), pipelines])


func _notification(what: int) -> void:
	if what in _NOTIFICATIONS:
		trace("app", _NOTIFICATIONS[what])
		trace("memory", memory())


## What the engine holds, in MB: its own allocations and what it placed on the graphics card. The driver's own
## memory (the pipelines compiled, for one) shows only in the system's count: `dumpsys meminfo`, and on Adreno
## `/sys/class/kgsl/kgsl/proc/<pid>/kernel`.
func memory() -> String:
	var pipelines := PackedStringArray()
	for kind in _PIPELINE_MONITORS:
		pipelines.append("%s %d" % [kind, Performance.get_monitor(_PIPELINE_MONITORS[kind])])
	return "static_mb=%.1f video_mb=%.1f texture_mb=%.1f buffer_mb=%.1f objects=%d resources=%d nodes=%d pipelines: %s" % [
		OS.get_static_memory_usage() / 1e6, Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1e6,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1e6,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1e6,
		Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT), ", ".join(pipelines)]


## Writes one `area: detail` line to the log, in debug builds only; long details are cut.
func trace(area: String, detail: String) -> void:
	if enabled:
		var shown := detail if detail.length() <= _MAX_DETAIL else detail.left(_MAX_DETAIL) + "…"
		print("Cartouche %s: %s" % [area, shown])


## `key=value` statistics of frames lasting [param frames_ms] over [param seconds], as the
## `bench` lines `scripts/bench.sh` reads write them.
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


## A debug-only switch without a value, read from desktop or Android launch arguments.
func flag(option: String) -> bool:
	if not enabled:
		return false
	var arguments := OS.get_cmdline_user_args()
	arguments.append_array(Android.launch_arguments())
	return "--%s" % option in arguments


## Mounts the start pack the bridge's last restart prepared, then adds the bridge; nothing without the
## `--bridge` flag, a debug build and the bridge's files (a release build has none).
func start_bridge() -> void:
	var path := "res://dev/bridge/bridge.gd"
	if not enabled or not flag("bridge") or not ResourceLoader.exists(path) or has_node("Bridge"):
		return
	(load("res://dev/bridge/packs.gd") as GDScript).call(&"mount_start")
	var bridge := Node.new()
	bridge.set_script(load(path))
	bridge.name = "Bridge"
	add_child(bridge)


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
