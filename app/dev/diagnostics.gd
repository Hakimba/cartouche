# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Traces what the app receives to the log in debug builds, registered as the `Diagnostics`
## autoload: input events with the actions they match, focus changes, lifecycle notifications,
## and whatever other code passes to [method trace] (plugin traffic, for instance). On a device,
## `dev/logs.sh` follows them together with the Kotlin plugin's traces. Release builds trace
## nothing.

const _MAX_DETAIL := 500
const _NOTIFICATIONS: Dictionary[int, String] = {
	NOTIFICATION_WM_GO_BACK_REQUEST: "back request",
	NOTIFICATION_APPLICATION_RESUMED: "resumed",
	NOTIFICATION_APPLICATION_PAUSED: "paused",
	NOTIFICATION_APPLICATION_FOCUS_IN: "focus in",
	NOTIFICATION_APPLICATION_FOCUS_OUT: "focus out",
	NOTIFICATION_WM_CLOSE_REQUEST: "close request",
}

## Whether traces are written; check it before building an expensive detail.
var enabled := OS.is_debug_build()
## Whether each joypad axis (keyed by device * 100 + axis) is past half-way.
var _axes_past_half: Dictionary[int, bool] = {}


func _ready() -> void:
	if enabled:
		get_tree().root.window_input.connect(_on_window_input)
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _notification(what: int) -> void:
	if what in _NOTIFICATIONS:
		trace("app", _NOTIFICATIONS[what])


## Writes one `area: detail` line to the log, in debug builds only; long details are cut.
func trace(area: String, detail: String) -> void:
	if enabled:
		var shown := detail if detail.length() <= _MAX_DETAIL else detail.left(_MAX_DETAIL) + "…"
		print("Cartouche %s: %s" % [area, shown])


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
