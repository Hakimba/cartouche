# SPDX-License-Identifier: GPL-3.0-or-later
@tool
extends EditorExportPlugin
## Exports every [ShapedMesh] already built ([method ShapedMesh.baked]): the app starts without building its models,
## the code that builds them staying their only source.

## Where the code models are built with lives, their dimensions, and this export's; any change in them builds the
## models again at the next export.
const CODE: Array[String] = ["res://carousel", "res://addons/cartouche_dev"]


## A number that changes with the text of every script, scene and resource under [param folder].
static func code_hash(folder: String) -> int:
	var texts := PackedStringArray()
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() in ["gd", "tscn", "tres"]:
			texts.append(FileAccess.get_file_as_string(folder.path_join(file)))
	for inner in DirAccess.get_directories_at(folder):
		texts.append(str(code_hash(folder.path_join(inner))))
	return hash(texts)


func _get_name() -> String:
	return "CartoucheShapedMeshes"


func _begin_customize_resources(_platform: EditorExportPlatform, _features: PackedStringArray) -> bool:
	return true


func _customize_resource(resource: Resource, _path: String) -> Resource:
	return (resource as ShapedMesh).baked() if resource is ShapedMesh else null


func _get_customization_configuration_hash() -> int:
	return hash(CODE.map(code_hash))
