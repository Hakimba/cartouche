# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Runs a tool of scripts/ (`godot --path app -s scripts/godot_tool.gd -- <tool.gd> <its arguments>`) once the app's
## autoloads are registered: a script given to `-s` is compiled before them, and the app's classes that name one
## (`Diagnostics`) would not compile. The tool is a Node that does its work in `_ready` and quits.


func _initialize() -> void:
	await process_frame
	var tool: Node = (load(OS.get_cmdline_user_args()[0]) as GDScript).new()
	root.add_child(tool)
