# SPDX-License-Identifier: GPL-3.0-or-later
class_name Appearance
extends RefCounted
## How the carousel shows its platforms, as `data/carousel/appearance.json` has it: a model per
## media, a console per platform that has one (its scene, its launch animation's steps, the name and
## model shown above it), the steps of the platforms shown by their medium, label colours and bands,
## the pose, and each media's insertion. Read once, its launch animations made once each; a medium's
## model is loaded the first time it is asked for.

var consoles: Dictionary[String, PackedScene] = {}
## The short name and the model of each console, as shown above it: "PlayStation 2", "Slim".
var console_names: Dictionary[String, String] = {}
var console_models: Dictionary[String, String] = {}
var colors: Dictionary[String, Color] = {}
var default_color: Color
var bands: Dictionary[String, Dictionary] = {}
var insertions: Dictionary[String, Insertion] = {}
var pose := ShelfRow.Pose.new()

var _animations: Dictionary[String, Animation] = {}
var _media_animation: Animation
## Each medium's model, by media, and where it is, until it is first asked for.
var _models: Dictionary[String, PackedScene] = {}
var _model_paths: Dictionary[String, String] = {}


## The appearance the file at [param path] describes; what cannot be taken as written is reported.
static func read(path: String) -> Appearance:
	var appearance := Appearance.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var models_data: Dictionary = data["models"]
	appearance._model_paths.assign(models_data)
	var consoles_data: Dictionary = data["consoles"]
	for platform_id: String in consoles_data:
		var console: Dictionary = consoles_data[platform_id]
		var model: String = console["model"]
		var steps: String = console["steps"]
		appearance.consoles[platform_id] = load(model)
		appearance.console_names[platform_id] = console["name"]
		appearance.console_models[platform_id] = console["model_name"]
		appearance._animations[platform_id] = LaunchAnimation.read(steps)
	var media_steps: String = data["media_steps"]
	appearance._media_animation = LaunchAnimation.read(media_steps)
	var bands_data: Dictionary = data["bands"]
	appearance.bands.assign(bands_data)
	var colors_data: Dictionary = data["colors"]
	for platform_id: String in colors_data:
		var color: String = colors_data[platform_id]
		appearance.colors[platform_id] = Color(color)
	var default_colour: String = data["default_color"]
	appearance.default_color = Color(default_colour)
	var insertions_data: Dictionary = data["insertions"]
	for media: String in insertions_data:
		var insertion: Dictionary = insertions_data[media]
		var problems := Insertion.problems(insertion)
		for key in problems:
			push_error("%s: insertion of %s: %s: %s" % [path, media, key, Insertion.Problem.keys()[problems[key]]])
		appearance.insertions[media] = Insertion.read(insertion)
	var pose_data: Dictionary = data["pose"]
	appearance.pose.tilt = pose_data["tilt_degrees"]
	appearance.pose.turn = pose_data["turn_degrees"]
	appearance.pose.sway = pose_data["sway_degrees"]
	var period: float = pose_data["sway_period_s"]
	# A sway never takes no time.
	appearance.pose.sway_period_s = maxf(period, 0.5)
	return appearance


## The launch animation of [param platform_id]'s console, or of the platforms shown by their medium.
func animation_of(platform_id: String) -> Animation:
	return _animations.get(platform_id, _media_animation)


## The model of [param media] (`dvd`, `minidisc`, `cartridge`).
func model_of(media: String) -> PackedScene:
	if media not in _models:
		var started := Time.get_ticks_usec()
		_models[media] = load(_model_paths[media])
		Diagnostics.trace("appearance", "%s model loaded in %.1f ms" % [media, (Time.get_ticks_usec() - started) / 1000.0])
	return _models[media]
