# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Commands := preload("res://dev/bridge/commands.gd")
const Packs := preload("res://dev/bridge/packs.gd")
const DiagnosticsScript := preload("res://dev/diagnostics.gd")
## The packs of the bridge tests go to a folder of their own, never an instance's.
const PACKS := "user://dev/test"


class ProbeScene extends Node3D:
	var row := ConsoleRow.new()

	func _ready() -> void:
		add_child(row)
		var model := Model.new()
		row.add_child(model)
		row._items.append(ConsoleRow.Item.new(model, ConsoleRow.Rest.new(), "nes"))
		row._light_selected()


class CommandHost extends Commands:
	var host: Node

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
		await get_tree().process_frame
		return {"ok": true}

	func capture() -> Image:
		return Image.create_empty(8, 6, false, Image.FORMAT_RGB8)


class DiagnosticHost extends DiagnosticsScript:
	var bridge_flag := false

	func _ready() -> void:
		pass

	func flag(option: String) -> bool:
		return bridge_flag and option == "bridge"


static func file(path: String, text: String) -> Dictionary:
	return {"path": path, "data": Marshalls.utf8_to_base64(text)}


class Model extends Node3D:
	func fade(_amount: float) -> void:
		pass
