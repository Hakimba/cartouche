# SPDX-License-Identifier: GPL-3.0-or-later
@tool
extends EditorExportPlugin

var _debug := false


static func excludes(path: String, debug: bool) -> bool:
	return not debug and path.begins_with("res://dev/bridge/")


func _get_name() -> String:
	return "CartoucheDev"


func _export_begin(_features: PackedStringArray, is_debug: bool, _path: String, _flags: int) -> void:
	_debug = is_debug


func _export_file(path: String, _type: String, _features: PackedStringArray) -> void:
	if excludes(path, _debug):
		skip()
