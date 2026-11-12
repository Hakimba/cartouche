# SPDX-License-Identifier: GPL-3.0-or-later
class_name CurtainPermission
extends Page
## Asks for "display over other apps", which the black curtain hiding an emulator while it starts
## needs (see [GameLaunch]): one sentence why, a button opening Android's setting, one to go on
## without. Back from the setting, the screen is done, whatever the user chose there: it answers once the user went
## on, with or without the permission (no value).

var android: AndroidServices = Android
## Whether Android's setting was opened and the app has not come back to the front yet.
var _in_setting := false

@onready var _open_setting: Button = %Open


func _ready() -> void:
	add_to_group(SoundEffects.MOVES)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and _in_setting:
		_in_setting = false
		Diagnostics.trace("first launch", "back from the overlay setting: allowed %s" % android.curtain_allowed())
		done.emit(null)


func _open(_request: Variant) -> void:
	_open_setting.grab_focus()


func _on_open_pressed() -> void:
	Sounds.play(SoundEffects.Cue.SELECT)
	# Set first: the app may be back before the answer is.
	_in_setting = true
	var result := await android.request_curtain_permission()
	if not result.ok:
		_in_setting = false
		Diagnostics.trace("first launch", "overlay setting not opened (%s): %s" % [result.code, result.detail])
		done.emit(null)


func _on_later_pressed() -> void:
	Diagnostics.trace("first launch", "overlay permission left for later")
	Sounds.play(SoundEffects.Cue.BACK)
	done.emit(null)
