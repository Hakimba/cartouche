# SPDX-License-Identifier: GPL-3.0-or-later
extends DeviceCheckPage
## Renders a load close to the future carousel and reports frame times over 5-second windows.

const _WINDOW_MS := 5000

var _window_start_ms := 0
var _frames := 0
var _worst_s := 0.0

@onready var _stats: Label = %Stats
@onready var _bench: Node3D = %Bench


func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()


func _process(delta: float) -> void:
	_frames += 1
	_worst_s = maxf(_worst_s, delta)
	var elapsed := Time.get_ticks_msec() - _window_start_ms
	if elapsed >= _WINDOW_MS:
		_stats.text = "%d objects · %.1f fps average · worst frame %.1f ms (last 5 s)" % [
			PerfBench.BOX_COUNT, _frames * 1000.0 / elapsed, _worst_s * 1000.0]
		_restart_window()


func _on_visibility_changed() -> void:
	var shown := is_visible_in_tree()
	set_process(shown)
	_bench.process_mode = Node.PROCESS_MODE_INHERIT if shown else Node.PROCESS_MODE_DISABLED
	_restart_window()


func _restart_window() -> void:
	_window_start_ms = Time.get_ticks_msec()
	_frames = 0
	_worst_s = 0.0
