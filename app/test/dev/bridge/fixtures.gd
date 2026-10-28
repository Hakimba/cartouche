# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Commands := preload("res://dev/bridge/commands.gd")
const Packs := preload("res://dev/bridge/packs.gd")
const DiagnosticsScript := preload("res://dev/diagnostics.gd")
## The packs of the bridge tests go to a folder of their own, never an instance's.
const PACKS := "user://dev/test"


class ProbeScene extends Node3D:
	var presses := 0
	var seconds := 0.0
	## How long a direction was held, and the fastest the game ran while it was.
	var held_s := 0.0
	var held_scale := 0.0
	var start: Plinth.Start
	var row := ConsoleRow.new()

	func _ready() -> void:
		process_mode = Node.PROCESS_MODE_PAUSABLE
		start = Plinth.start_of("nes")
		add_child(row)
		var model := Model.new()
		row.add_child(model)
		row._items.append(ConsoleRow.Item.new(model, ConsoleRow.Rest.new(), "nes"))
		row._light_selected()

	func _process(delta: float) -> void:
		seconds += delta
		if Input.is_action_pressed(&"ui_right"):
			held_s += delta
			held_scale = maxf(held_scale, Engine.time_scale)

	func _input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_accept"):
			presses += 1


class CommandHost extends Commands:
	var host: Node
	var reloads := 0

	func _ready() -> void:
		Packs.use(PACKS)
		super()

	func _scene() -> Node:
		return host

	func _reload_scene() -> Dictionary:
		if is_instance_valid(host):
			host.free()
		host = ProbeScene.new()
		add_child(host)
		reloads += 1
		await get_tree().process_frame
		return {"ok": true}

	func capture() -> Image:
		return Image.create_empty(8, 6, false, Image.FORMAT_RGB8)


## Records whether the shown model was visible each time a picture was taken.
class SeeingHost extends CommandHost:
	var seen: Array[bool] = []

	func capture() -> Image:
		seen.append((host as ProbeScene).row.selected().model.visible)
		return super()


class BigPictureHost extends CommandHost:
	func capture() -> Image:
		return Image.create_from_data(3000, 3000, false, Image.FORMAT_RGB8, Crypto.new().generate_random_bytes(27_000_000))


class DiagnosticHost extends DiagnosticsScript:
	var bridge_flag := false

	func _ready() -> void:
		pass

	func flag(option: String) -> bool:
		return bridge_flag and option == "bridge"


class SnapshotServices extends AndroidServices:
	var requests: Array[StringName] = []
	var payload := {"ok": true, "library": "{\"games\":[],\"console_variants\":{\"ps2\":\"ps2_fat\"}}",
		"art": "[{\"game_id\":\"ps2/a\",\"path\":\"/data/user/0/app.cartouche/files/art/a.png\"}]"}
	var choices := {"ok": true, "button_style": "nintendo", "games_float": true}

	func _ready() -> void:
		pass

	func _request(method: StringName, _args: Array = [], _without_plugin := {}) -> Dictionary:
		requests.append(method)
		await get_tree().process_frame
		return payload.duplicate(true) if method == &"library" else choices.duplicate(true)


static func file(path: String, text: String) -> Dictionary:
	return {"path": path, "data": Marshalls.utf8_to_base64(text)}


class Model extends Node3D:
	func fade(_amount: float) -> void:
		pass


## Removes [param path] and everything beneath it.
static func remove_tree(path: String) -> void:
	for file_name: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file_name))
	for file_name: String in DirAccess.get_directories_at(path):
		remove_tree(path.path_join(file_name))
	DirAccess.remove_absolute(path)
