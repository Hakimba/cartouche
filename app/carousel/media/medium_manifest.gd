# SPDX-License-Identifier: GPL-3.0-or-later
class_name MediumManifest
extends Resource
## What a medium's folder tells the app of it, in its `medium.tres`: its kind, its scene and its
## budget. The folder is named after the medium, as `data/platforms/profiles.json` names it
## (`ps2_dvd`); the app finds every medium by its folder under [constant FOLDERS], so that adding one
## touches no shared file.

const FOLDERS := "res://carousel/media/"
const FILE := "medium.tres"

## Its kind, as the platforms declaring it have it: `dvd`, `minidisc` or `cartridge`.
@export var media: String
## Its scene, whose root holds its parts, a `Label` among them: a path, loaded only once a game of
## this medium shows.
@export_file("*.tscn") var scene: String
## The most triangles its model may be drawn with.
@export var triangle_budget := 0


## The manifest of every medium folder under [param folders], by its folder's name. The listing
## follows the remapped resources of an exported game.
static func found(folders := FOLDERS) -> Dictionary[String, MediumManifest]:
	var manifests: Dictionary[String, MediumManifest] = {}
	for entry in ResourceLoader.list_directory(folders):
		var path := folders.path_join(entry).path_join(FILE)
		if entry.ends_with("/") and ResourceLoader.exists(path):
			var manifest: MediumManifest = load(path)
			manifests[entry.trim_suffix("/")] = manifest
	return manifests


## The rules this manifest breaks, by name; none when the medium can be shown.
func problems() -> Array[StringName]:
	return ModelShape.broken({
		&"media_named": not media.is_empty(),
		&"scene_found": ResourceLoader.exists(scene, "PackedScene"),
		&"budget_given": triangle_budget > 0,
	})
