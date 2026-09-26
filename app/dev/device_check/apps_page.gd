# SPDX-License-Identifier: GPL-3.0-or-later
extends DeviceCheckPage
## Installed apps with a launcher entry; proves the app can see (and start) emulators.

@onready var _apps: ItemList = %Apps


func refresh() -> void:
	_apps.grab_focus()
	var listing := await Android.list_apps()
	_apps.clear()
	for app in listing.apps:
		var label := "%s   (%s)" % [app.label, app.package_name]
		_apps.set_item_metadata(_apps.add_item(label), app.package_name)
	if not listing.ok:
		logged.emit("Cannot list apps (%s)" % listing.code)


func _on_apps_item_activated(index: int) -> void:
	var package_name: String = _apps.get_item_metadata(index)
	var result := await Android.launch_app(package_name)
	var outcome := "launched" if result.ok else String(result.code)
	logged.emit("%s: %s" % [plain(_apps.get_item_text(index)), outcome])
