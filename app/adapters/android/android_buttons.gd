# SPDX-License-Identifier: GPL-3.0-or-later
class_name AndroidButtons
extends RefCounted
## Makes the controller's buttons mean what Android says they mean. Android names each button as
## the device's settings do (some devices let the user swap A and B), and confirms with A and goes
## back with B. Godot's bundled controller database maps some devices by position instead (A is the
## bottom button, whatever its label), which would swap A and B in Cartouche alone: their mapping
## is dropped, so the buttons arrive as Android sends them.


## Drops the mapping of every controller, connected now or later.
static func follow_android() -> void:
	for device in Input.get_connected_joypads():
		_drop_mapping(device)
	Input.joy_connection_changed.connect(func(device: int, connected: bool) -> void:
		if connected:
			_drop_mapping(device))


static func _drop_mapping(device: int) -> void:
	var guid := Input.get_joy_guid(device)
	Input.remove_joy_mapping(guid)
	Diagnostics.trace("input", "%s (%s): buttons as Android sends them" % [Input.get_joy_name(device), guid])
