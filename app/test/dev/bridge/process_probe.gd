# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

const Commands := preload("res://dev/bridge/commands.gd")
const Packs := preload("res://dev/bridge/packs.gd")


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	if not Diagnostics.argument("snapshot").is_empty():
		var answer := await Android.library()
		var settings := await Android.settings()
		print("snapshot probe ", JSON.stringify({"games": answer.library.games.size(),
			"variants": answer.library.console_variants, "style": settings.button_style,
			"art": answer.art[0].path if not answer.art.is_empty() else ""}))
		get_tree().quit(0 if Android.has_snapshot() else 1)
		return
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://carousel/carousel.tscn")
	await get_tree().scene_changed
	# The probe is a process of its own: its packs stay out of any bridge instance's folder.
	Packs.use("user://dev/test_process")
	var commands := Commands.new()
	get_tree().root.add_child(commands)
	var result := await commands.run({"cmd": "go", "route": [{"press": "ui_accept", "wait": 120}]})
	if not result["ok"]:
		get_tree().quit(1)
		return
	var before := await commands.run({"cmd": "state"})
	var file := {"path": "res://data/studio_lights.json",
		"data": Marshalls.utf8_to_base64(FileAccess.get_file_as_string(StudioLights.FILE))}
	result = await commands.run({"cmd": "reload", "files": [file]})
	var after := await commands.run({"cmd": "state"})
	var matching: bool = before["screen"] == "games" and after["screen"] == "games" \
		and before["console"] == after["console"] and before["game"] == after["game"] and result["ok"]
	commands._act(&"open_settings", true)
	commands._act(&"open_settings", false)
	for frame in 40:
		await get_tree().process_frame
	var settings_state := await commands.run({"cmd": "state"})
	matching = matching and settings_state["screen"] == "settings"
	print("scene probe ", JSON.stringify({"matching": matching, "before": before, "after": after}))
	get_tree().quit(0 if matching else 1)
