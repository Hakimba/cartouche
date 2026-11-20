# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## Godot draws an anti-aliased StyleBoxFlat bordered on some sides only with points far off its box at some screen
## sizes (bars across the screen at 1280 x 720): no StyleBoxFlat of the app is bordered on some sides only.

const ProjectFiles := preload("res://test/studio/project_files.gd")


func test_no_stylebox_is_bordered_on_some_sides_only() -> void:
	var width := RegEx.create_from_string("border_width_(left|top|right|bottom)\\s*=\\s*([1-9]\\d*)")
	var partial: Array[String] = []
	for path in ProjectFiles.under("res://", ["gd", "tres", "tscn"], ["addons", ".godot", "android", "test"]):
		# A resource file's boxes one by one; a script as a whole.
		for block in FileAccess.get_file_as_string(path).split("\n["):
			var bordered := {}
			for found in width.search_all(block):
				bordered[found.get_string(1)] = true
			if bordered.size() in range(1, 4):
				partial.append("%s: %s" % [path, bordered.keys()])
	assert_array(partial).is_empty()
