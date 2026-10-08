# SPDX-License-Identifier: GPL-3.0-or-later
extends Control
## Developer tool that checks a device can run Cartouche: storage access, launching emulators,
## controller input, 3D performance and installed apps. Not part of the product UI: debug builds
## open it from the carousel, and back from its root returns there.

const _CAROUSEL := "res://carousel/carousel.tscn"

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
	var catalog := Android.catalog
	var names := PackedStringArray(catalog.platforms.map(
			func(platform: AndroidServices.Platform) -> String: return platform.name))
	_log_line("Platforms: %s" % DeviceCheckPage.plain(", ".join(names)))
	for rejection in catalog.rejected:
		var line := DeviceCheckPage.plain(rejection)
		_log_line("[color=salmon]Rejected definition: %s[/color]" % line)
	# Opens on the Library page; tab_changed refreshes it.
	_tabs.current_tab = (%Library as Control).get_index()
	_on_clock_timeout()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_RESUMED:
			_current_page().refresh()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_go_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"tab_next"):
		get_viewport().set_input_as_handled()
		_tabs.select_next_available()
	elif event.is_action_pressed(&"tab_previous"):
		get_viewport().set_input_as_handled()
		_tabs.select_previous_available()
	elif event.is_action_pressed(&"app_back"):
		# Handled first: going back may leave the scene, and its viewport with it.
		get_viewport().set_input_as_handled()
		_go_back()


func _on_tabs_tab_changed(_tab: int) -> void:
	_current_page().refresh()


func _on_clock_timeout() -> void:
	if _ticks % _BATTERY_EVERY_TICKS == 0:
		var battery := Android.battery()
		_battery = ("battery %d %%" % battery.level_percent if battery.has_level else "battery ?") \
				+ (" (plugged in)" if battery.plugged else "")
	_ticks += 1
	var time := Time.get_time_string_from_system().left(5)
	_status.text = "%s   ·   %s   ·   %d fps" % [time, _battery, Engine.get_frames_per_second()]


func _go_back() -> void:
	if not _current_page().go_back():
		get_tree().change_scene_to_file(_CAROUSEL)


func _current_page() -> DeviceCheckPage:
	return _tabs.get_current_tab_control() as DeviceCheckPage


func _log_line(text: String) -> void:
	_log.append_text("[lb]%s] %s\n" % [Time.get_time_string_from_system(), text])
