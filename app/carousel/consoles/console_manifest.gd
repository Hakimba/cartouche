# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleManifest
extends Resource
## What a console's folder tells the app of it, in its `console.tres`: the platform it plays, which
## of its versions it is, its names, its scene, its launch animation and its budget. The app finds
## every console by its folder under [constant FOLDERS], so that adding one touches no shared file.

const FOLDERS := "res://carousel/consoles/"
const FILE := "console.tres"
const _VERSION := "^[a-z0-9]+(-[a-z0-9]+)*$"

## The manifests read so far, by folder (null for none): Godot drops a resource nobody holds, and the form's
## Console list asks for one at every step.
static var _read: Dictionary[String, ConsoleManifest] = {}
## Each platform's colour once found: finding it reads every console's manifest.
static var _gels: Dictionary[String, Color] = {}

## The platform it plays, as `data/platforms/profiles.json` names it; which of its versions it is,
## its model code in lower case, hyphens between its words (`dol-001`, `scph-70004`), and whether the
## one shown unless the user chooses another.
@export var platform: String
@export var version: StringName
@export var is_default := false
## Its short name and its model, as shown above it: "PlayStation 2", "Slim".
@export var name: String
@export var model_name: String
## Its scene, whose root is a [ConsoleModel]: a path, loaded only once the console shows.
@export_file("*.tscn") var scene: String
## Its launch animation's steps; none, and it plays the placeholder.
@export_file("*.json") var launch: String
## The most triangles its model may be drawn with.
@export var triangle_budget := 0
## Its real size over its fitted pose, and the depth its pose pushed it back to, for the ordering ring ([RingFit]);
## zero when not measured, and the ring weighs it as the PS2.
@export var ring_size := Vector2.ZERO
## Other model folders of this platform, in the order shown after its base model.
@export var variants := PackedStringArray()


## The base model and the extra models this console offers, in their display order.
func models() -> Array[ConsoleManifest]:
	var choices: Array[ConsoleManifest] = [self]
	for folder in variants:
		var variant := of(folder)
		if variant and variant.platform == platform:
			choices.append(variant)
	return choices


## The platform's colour, shared by all its models.
func gel() -> Color:
	if platform not in _gels:
		_gels[platform] = StudioTokens.NEUTRAL
		for base in found():
			if base.platform == platform and base.is_default:
				_gels[platform] = gel_of(ConsoleManifest.folder_of(base))
				break
	return _gels[platform]


## The colour of console folder [param folder]; neutral for one without a colour of its own.
static func gel_of(folder: String) -> Color:
	return StudioTokens.GEL.get(StringName(folder), StudioTokens.NEUTRAL)


## The containing model folder, for a manifest or a scene; empty when there is no resource.
static func folder_of(resource: Resource) -> String:
	return resource.resource_path.get_base_dir().get_file() if resource else ""


## The manifest of every console folder under [param folders]. The listing follows the remapped
## resources of an exported game.
static func found(folders := FOLDERS) -> Array[ConsoleManifest]:
	var manifests: Array[ConsoleManifest] = []
	for entry in ResourceLoader.list_directory(folders):
		var path := folders.path_join(entry).path_join(FILE)
		if entry.ends_with("/") and ResourceLoader.exists(path):
			var manifest: ConsoleManifest = load(path)
			manifests.append(manifest)
	return manifests


## The manifest of the console folder [param folder], by its name under [constant FOLDERS]; none
## when there is no such folder.
static func of(folder: String) -> ConsoleManifest:
	if folder not in _read:
		var path := FOLDERS.path_join(folder).path_join(FILE)
		_read[folder] = load(path) if ResourceLoader.exists(path) else null
	return _read[folder]


## The rules this manifest breaks, by name; none when the console can be shown.
func problems() -> Array[StringName]:
	return ModelShape.broken({
		&"platform_named": not platform.is_empty(),
		&"version_a_model_code": RegEx.create_from_string(_VERSION).search(version) != null,
		&"names_given": not name.is_empty() and not model_name.is_empty(),
		&"scene_found": ResourceLoader.exists(scene, "PackedScene"),
		&"launch_found": launch.is_empty() or FileAccess.file_exists(launch),
		&"budget_given": triangle_budget > 0,
	})
