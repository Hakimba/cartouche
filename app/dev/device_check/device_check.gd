# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## Developer tool that checks a device can run Cartouche: storage access, launching emulators,
## controller input, 3D performance and installed apps. Not part of the product UI.

const _BATTERY_EVERY_TICKS := 10

var _ticks := 0
var _battery := ""

@onready var _tabs: TabContainer = %Tabs
@onready var _status: Label = %Status
@onready var _log: RichTextLabel = %Log


func _ready() -> void:
	for page: DeviceCheckPage in _tabs.get_children():
		page.logged.connect(_log_line)
	_log_line("Device: %s · Android plugin %s" % [DeviceCheckPage.plain(Android.device_name()),
			"loaded" if Android.is_available() else "MISSING"])
	var catalog := Android.load_catalog()
	_log_line("Platforms: %s" % DeviceCheckPage.plain(", ".join(catalog.platform_names)))
	for rejection in catalog.rejected:
		_log_line("[color=salmon]Rejected definition: %s[/color]" % DeviceCheckPage.plain(rejection))
	# Opens on the Launch page; tab_changed refreshes it.
	_tabs.current_tab = (%Launch as Control).get_index()
	_on_clock_timeout()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_RESUMED:
			_current_page().refresh()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			# Cartouche is a launcher: at the root, back does nothing rather than quit.
			_current_page().go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tab_next"):
		_tabs.select_next_available()
	elif event.is_action_pressed(&"tab_previous"):
		_tabs.select_previous_available()
	elif not (event.is_action_pressed(&"app_back") and _current_page().go_back()):
		return
	get_viewport().set_input_as_handled()


func _on_tabs_tab_changed(_tab: int) -> void:
	_current_page().refresh()


func _on_clock_timeout() -> void:
	if _ticks % _BATTERY_EVERY_TICKS == 0:
		var battery := Android.battery()
		_battery = ("battery %d %%" % battery.level_percent if battery.has_level else "battery ?") \
				+ (" (charging)" if battery.charging else "")
	_ticks += 1
	var time := Time.get_time_string_from_system().left(5)
	_status.text = "%s   ·   %s   ·   %d fps" % [time, _battery, Engine.get_frames_per_second()]


func _current_page() -> DeviceCheckPage:
	return _tabs.get_current_tab_control() as DeviceCheckPage


func _log_line(text: String) -> void:
	_log.append_text("[lb]%s] %s\n" % [Time.get_time_string_from_system(), text])
