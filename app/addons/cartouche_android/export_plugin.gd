# SPDX-License-Identifier: GPL-3.0-or-later
@tool
extends EditorPlugin
## Bundles the Kotlin plugin into Android exports. Build it first with
## `./gradlew :android:assemble` in `kotlin/`, which fills `bin/`.

var _export_plugin := AndroidExportPlugin.new()


func _enter_tree() -> void:
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)


class AndroidExportPlugin extends EditorExportPlugin:
	## Relative to `res://addons/`, as Godot expects for plugin binaries.
	const BIN := "cartouche_android/bin/"

	func _get_name() -> String:
		return "CartoucheAndroid"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) \
			-> PackedStringArray:
		var aar := BIN + "cartouche-android-%s.aar" % ("debug" if debug else "release")
		return PackedStringArray([aar, BIN + "cartouche-core.jar"])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) \
			-> PackedStringArray:
		# Written by the Gradle build, so dependency versions live only in its version catalog.
		var listed := FileAccess.get_file_as_string("res://addons/" + BIN + "dependencies.txt")
		# Export plugins cannot stop an export: the Gradle build fails on the missing AARs,
		# and this says why.
		if listed.is_empty():
			push_error("CartoucheAndroid: no bin/dependencies.txt; build kotlin/ first")
		return listed.strip_edges().split("\n", false)
