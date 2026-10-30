# SPDX-License-Identifier: GPL-3.0-or-later
class_name Appearance
extends RefCounted
## How the carousel shows its platforms, as `data/carousel/appearance.json` has it: the medium each
## kind of media falls back to, the steps of the platforms shown by their medium, label colours and
## bands, the pose, and each media's insertion; and the media and the consoles found in their folders
## ([MediumManifest], [ConsoleManifest]). Read once; a medium's model is loaded the first time it is
## asked for (or ahead, in the background), a console's scene the first time its console or its launch animation is. What is loaded
## or made stays: a library edit seldom drops a medium, and scenes and animations weigh little next to
## the labels' viewports, which [ShelfRow] frees.

var colors: Dictionary[String, Color] = {}
var default_color: Color
var bands: Dictionary[String, Dictionary] = {}
var insertions: Dictionary[String, Insertion] = {}
var pose := ShelfRow.Pose.new()

var _media_animation: Animation
var _media: Dictionary[String, MediumManifest] = {}
var _kind_media: Dictionary[String, String] = {}
var _models: Dictionary[String, PackedScene] = {}
## The media whose models load in the background ([method load_models_of]).
var _loading: Dictionary[String, bool] = {}
var _consoles: Dictionary[String, ConsoleManifest] = {}
var _scenes: Dictionary[String, PackedScene] = {}
var _animations: Dictionary[String, Animation] = {}


## The appearance the file at [param path] describes; what cannot be taken as written is reported.
static func read(path: String) -> Appearance:
	var appearance := Appearance.new()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	var kind_media: Dictionary = data["kind_media"]
	appearance._kind_media.assign(kind_media)
	appearance._media = shown_media(MediumManifest.found())
	appearance._consoles = defaults(ConsoleManifest.found())
	Diagnostics.trace("appearance", "consoles found: %s" % [appearance._consoles.keys()])
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
	appearance.pose.bob = pose_data["bob_height"]
	var period: float = pose_data["sway_period_s"]
	appearance.pose.sway_period_s = maxf(period, 0.5)
	return appearance


## The console shown for each platform of [param manifests], by platform: its default version. A
## manifest with problems, or a platform's second default, is traced and left out.
static func defaults(manifests: Array[ConsoleManifest]) -> Dictionary[String, ConsoleManifest]:
	var shown: Dictionary[String, ConsoleManifest] = {}
	for manifest in manifests:
		var broken := manifest.problems()
		if not broken.is_empty():
			Diagnostics.trace("appearance", "%s left out: %s" % [manifest.resource_path, broken])
		elif manifest.is_default and manifest.platform in shown:
			Diagnostics.trace("appearance", "%s left out: %s has a default already" % [
				manifest.resource_path, manifest.platform])
		elif manifest.is_default:
			shown[manifest.platform] = manifest
	return shown


## The media of [param manifests] that can be shown, by medium; one with problems is traced and left
## out.
static func shown_media(manifests: Dictionary[String, MediumManifest]) -> Dictionary[String, MediumManifest]:
	var shown: Dictionary[String, MediumManifest] = {}
	for medium in manifests:
		var broken := manifests[medium].problems()
		if broken.is_empty():
			shown[medium] = manifests[medium]
		else:
			Diagnostics.trace("appearance", "medium %s left out: %s" % [medium, broken])
	return shown


## The console of [param platform_id], as shown unless the user chooses another version; none when
## the platform is shown by its medium.
func console_of(platform_id: String) -> ConsoleManifest:
	return _consoles.get(platform_id)


## The colour [param platform_id]'s console lights the screens with; neutral when it is shown by its medium.
func gel(platform_id: String) -> Color:
	var manifest := console_of(platform_id)
	return manifest.gel() if manifest else StudioTokens.NEUTRAL


## How [param platform]'s labels look: its colour and band, its name; drawn as demo art when [param demo].
func look(platform: AndroidServices.Platform, demo: bool) -> ShelfRow.LabelLook:
	var label := ShelfRow.LabelLook.new()
	label.color = colors.get(platform.id, default_color)
	label.platform_name = platform.name
	label.demo_art = demo
	if platform.id in bands:
		var band: Dictionary = bands[platform.id]
		var color: String = band["color"]
		label.band = Color(color)
		label.band_text = band["text"]
	return label


## [param platform] as the consoles screen shows it, resting as the launch animation of a game of [param medium]
## starts: its console, or else its medium labelled with its name, the labels looking as [method look] has them.
func console_item(platform: AndroidServices.Platform, medium: String, demo: bool) -> ConsoleRow.Item:
	var animation := animation_of(platform, medium)
	var manifest := console_of(platform.id)
	var shown: Node3D
	if manifest:
		shown = console(platform.id)
	else:
		var labelled := ShelfRow.LabelledModel.new(model_of("", platform.media))
		labelled.draw_label(platform.name, look(platform, demo))
		shown = labelled
	return ConsoleRow.Item.new(shown, ConsoleRow.Rest.of(animation), ConsoleManifest.folder_of(manifest), manifest != null)


## The models of [param games]' media on [param platform], by medium (see [method model_of]).
func models_of(platform: AndroidServices.Platform, games: Array[AndroidServices.Game]) -> Dictionary[String, PackedScene]:
	var models: Dictionary[String, PackedScene] = {}
	for game in games:
		if game.medium not in models:
			models[game.medium] = model_of(game.medium, platform.media)
	return models


## Loads the models of [param games]' media on [param platform] not loaded yet in the background: [method model_of]
## then takes them, waiting for the end of their load if it has to.
func load_models_of(platform: AndroidServices.Platform, games: Array[AndroidServices.Game]) -> void:
	for game in games:
		var shown := _shown(game.medium, platform.media)
		if shown not in _models and shown not in _loading:
			ResourceLoader.load_threaded_request(_media[shown].scene)
			_loading[shown] = true


## Applies the library's model choices; omitted choices restore the base models.
func use_variants(variants: Dictionary[String, String]) -> void:
	var bases := defaults(ConsoleManifest.found())
	for platform in bases:
		var chosen := bases[platform]
		var wanted: String = variants.get(platform, "")
		for model in chosen.models():
			if ConsoleManifest.folder_of(model) == wanted:
				chosen = model
		if _consoles.get(platform) == chosen:
			continue
		_consoles[platform] = chosen
		_scenes.erase(platform)
		for key: String in _animations.keys():
			if key == platform or key.begins_with(platform + " "):
				_animations.erase(key)


## A new model of [param platform_id]'s console ([method console_of]), named after the platform: its
## launch animation moves its parts by that name. The console's scene is loaded the first time.
func console(platform_id: String) -> ConsoleModel:
	if platform_id not in _scenes:
		var started := Time.get_ticks_usec()
		_scenes[platform_id] = load(_consoles[platform_id].scene)
		Diagnostics.trace("appearance", "%s console loaded in %.1f ms" % [
			platform_id, (Time.get_ticks_usec() - started) / 1000.0])
	var model: ConsoleModel = _scenes[platform_id].instantiate()
	model.name = platform_id
	return model


## The launch animation of [param platform] for a game of [param medium] (see [method model_of]): its
## console's (from its steps, the same for every medium, else the placeholder, whose medium comes from
## its own length away), made the first time it is asked for, or the one of the platforms shown by
## their medium.
func animation_of(platform: AndroidServices.Platform, medium: String) -> Animation:
	var manifest := console_of(platform.id)
	if not manifest:
		return _media_animation
	var key := platform.id if manifest.launch else "%s %s" % [platform.id, _shown(medium, platform.media)]
	if key not in _animations:
		# Never in the tree: what an animation needs of a console depends on its shape alone.
		var model := console(platform.id)
		var started := Time.get_ticks_usec()
		_animations[key] = LaunchAnimation.read(manifest.launch, model) if manifest.launch \
			else LaunchAnimation.placeholder(model, medium_box(medium, platform.media))
		model.free()
		Diagnostics.trace("appearance", "%s launch animation made in %.1f ms" % [
			key, (Time.get_ticks_usec() - started) / 1000.0])
	return _animations[key]


## The model of [param medium] (a game's, `sfc_cart`), a medium of the kind [param media] (`dvd`,
## `minidisc`, `cartridge`): its folder's, or without one of that kind (or no medium given), the one
## its kind falls back to.
func model_of(medium: String, media: String) -> PackedScene:
	var shown := _shown(medium, media)
	if shown not in _models:
		var started := Time.get_ticks_usec()
		var path := _media[shown].scene
		_models[shown] = ResourceLoader.load_threaded_get(path) if _loading.erase(shown) else load(path)
		Diagnostics.trace("appearance", "%s model loaded in %.1f ms" % [shown, (Time.get_ticks_usec() - started) / 1000.0])
	return _models[shown]


## The box the model of [param medium] (see [method model_of]) fills, as it stands on a seat: in the
## seat's frame, at its real size (its root's scale is its size in the row only). Its parts are its
## root's children, as [ShelfRow.LabelledModel] has them.
func medium_box(medium: String, media: String) -> AABB:
	var shown: Node3D = model_of(medium, media).instantiate()
	var box := AABB()
	for part: VisualInstance3D in shown.find_children("*", "VisualInstance3D", false, false):
		var filled := part.transform * part.get_aabb()
		box = filled if box.size == Vector3.ZERO else box.merge(filled)
	shown.free()
	return box


## The medium whose folder shows [param medium], of the kind [param media].
func _shown(medium: String, media: String) -> String:
	return medium if medium in _media and _media[medium].media == media else _kind_media[media]
