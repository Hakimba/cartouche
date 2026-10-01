# SPDX-License-Identifier: GPL-3.0-or-later
class_name CurtainPermission
extends Control
## Asks for "display over other apps", which the black curtain hiding an emulator while it starts
## needs (see [GameLaunch]): one sentence why, a button opening Android's setting, one to go on
## without. Back from the setting, the screen is done, whatever the user chose there.

## The user went on, with or without the permission.
signal done

var android: AndroidServices = Android
## Whether Android's setting was opened and the app has not come back to the front yet.
var _in_setting := false

@onready var _open: Button = %Open


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _in_setting:
		_in_setting = false
		Diagnostics.trace("first launch", "back from the overlay setting: allowed %s" % android.curtain_allowed())
		done.emit()


func focus() -> void:
	_open.grab_focus()


func _on_open_pressed() -> void:
	# Set first: the app may be back before the answer is.
	_in_setting = true
	var result := await android.request_curtain_permission()
	if not result.ok:
		_in_setting = false
		Diagnostics.trace("first launch", "overlay setting not opened (%s): %s" % [result.code, result.detail])
		done.emit()


func _on_later_pressed() -> void:
	Diagnostics.trace("first launch", "overlay permission left for later")
	done.emit()
