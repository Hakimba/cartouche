# SPDX-License-Identifier: GPL-3.0-or-later
extends DeviceCheckPage
## "All files access", "display over other apps" (which the curtain hiding an emulator until its
## game shows needs) and the folders whose access survives restarts.

@onready var _access: Label = %Access
@onready var _folders: ItemList = %Folders
@onready var _grant: Button = %Grant


func refresh() -> void:
	_access.text = "All files access: %s. Display over other apps: %s." % [
		_granted(Android.has_all_files_access()), _granted(Android.curtain_allowed())]
	_grant.grab_focus()
	var listed := await Android.persisted_folders()
	_folders.clear()
	for folder in listed.folders:
		var where := folder.path if folder.has_path else "(no filesystem path)"
		_folders.add_item("%s  —  %s" % [folder.name, where])


func _on_grant_pressed() -> void:
	_log_opened(await Android.request_all_files_access())


func _on_grant_overlay_pressed() -> void:
	_log_opened(await Android.request_curtain_permission())


func _log_opened(opened: AndroidServices.Result) -> void:
	if not opened.ok:
		logged.emit("Cannot open the setting (%s)" % opened.code)


static func _granted(granted: bool) -> String:
	return "granted" if granted else "NOT granted"


func _on_add_folder_pressed() -> void:
	var pick := await Android.pick_folder()
	logged.emit("Folder granted: %s" % plain(pick.folder.name) if pick.ok
			else "No folder added (%s)" % pick.code)
	refresh()
