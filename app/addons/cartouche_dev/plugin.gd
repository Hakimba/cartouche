# SPDX-License-Identifier: GPL-3.0-or-later
@tool
extends EditorPlugin

var _filter := preload("res://addons/cartouche_dev/export_filter.gd").new()


func _enter_tree() -> void:
	add_export_plugin(_filter)


func _exit_tree() -> void:
	remove_export_plugin(_filter)
