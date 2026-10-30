# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

const Packs := preload("res://dev/bridge/packs.gd")
const LaunchView := preload("res://dev/bridge/launch_view.gd")
const Views := preload("res://dev/bridge/views.gd")
const BridgeSounds := preload("res://dev/bridge/sounds.gd")
const RouteFixture := preload("res://dev/bridge/route_fixture.gd")
const _PLINTH := preload("res://studio/views/plinth.gd")
const CACHE_FILES := {
	"res://data/studio_lights.json":
		[preload("res://studio/views/studio_lights.gd"), preload("res://carousel/consoles/console_row.gd"), _PLINTH],
	"res://data/turntable.json": [_PLINTH],
	"res://data/media_poses.json": [preload("res://studio/games/games_layout.gd")],
}
## Files read once as the app starts: a change reaches the app only by a restart.
const START_FILES: Array[String] = ["res://data/platforms/", "res://data/titles/", "res://data/scan/", "res://data/launch/",
	"res://data/art/", "res://data/prints/", "res://data/screenscraper/"]
## A route replays this many times faster than it was recorded, so a reload is seen in about a second; while a
## direction is held it plays at the recorded speed, as a held direction repeats at most once a frame.
const _REPLAY_SPEED := 8.0
## A route's `wait` counts frames of this many seconds of game time.
const _WAIT_UNIT_S := 0.02
## Fonts keep their shapes in caches a reload does not reach.
const _FONT_EXTENSIONS: Array[String] = ["ttf", "otf"]

var android: AndroidServices = Android
var route: Array = []
var paused := false
var _packs := Packs.new()
var _views := Views.new()
var _sounds := BridgeSounds.new()
var _held: Array[StringName] = []
var _previous_scale := 1.0
var _previous_pause := false
var _previous_input := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Packs.purge()
	add_child(_views)
	_sounds.screen = _screen_name
	add_child(_sounds)


func _exit_tree() -> void:
	if paused:
		_resume()
	_release_actions()


func run(message: Dictionary) -> Dictionary:
	var command: String = str(message.get("cmd", ""))
	var answer := {"id": message.get("id"), "cmd": command, "ok": true}
	var result: Dictionary
	match command:
		"state": result = _state()
		"shot": result = _shot(message)
		"go":
			var steps: Variant = message.get("route")
			if not _valid_route(steps):
				result = _error("invalid route")
			else:
				var validated_steps: Array = steps
				route = validated_steps.duplicate(true)
				result = await _go()
		"reload", "restart": result = await _overlay(message, command == "restart")
		"tune": result = _tune(message)
		"pause": _pause()
		"resume": _resume()
		"step": result = await _step(message)
		"scrub": result = _scrub(message)
		"pick":
			if message.get("all", false) == true:
				result = {"controls": _views.controls(_scene())}
			elif not _number(message.get("x")) or not _number(message.get("y")):
				result = _error("invalid point")
			else:
				result = _views.pick(_scene(), _point(message))
		"sound": result = _sounds.play(message)
		"sounds": result = _sounds.set_map(message)
		"snapshot": result = await _snapshot()
		_: result = _error("unknown command")
	answer.merge(result, true)
	Diagnostics.trace("bridge", "%s %s" % [command, "ok" if answer["ok"] else answer.get("error", "failed")])
	return answer


## A tune of the launch animation holds the engine, as a scrub does; any other goes to the views.
func _tune(message: Dictionary) -> Dictionary:
	if message.get("target") == "input":
		var raw_input: Variant = message.get("values")
		if raw_input is not Dictionary:
			return _error("invalid input")
		var input: Dictionary = raw_input
		if input.get("action") is not String or input.get("pressed") is not bool or not InputMap.has_action(str(input["action"])):
			return _error("invalid input")
		var pressed: bool = input["pressed"]
		_act(StringName(str(input["action"])), pressed)
		return {"ok": true}
	if message.get("target") == "speed":
		var speed: Variant = message.get("value")
		if not _number(speed) or speed <= 0.0 or speed > 20.0:
			return _error("invalid speed")
		if paused:
			_previous_scale = _float(speed)
		else:
			Engine.time_scale = _float(speed)
		return {"speed": speed}
	if message.get("target") != "launch":
		return _views.tune(_scene(), message)
	var values: Variant = message.get("values")
	if values is not Dictionary:
		return _error("invalid values")
	var launch_values: Dictionary = values
	var carousel := _scene() as Carousel
	if launch_values.get("stop") == true:
		_resume()
		Engine.time_scale = 1.0
		return LaunchView.stop(carousel)
	var result := LaunchView.tune(carousel, launch_values)
	if result.get("ok", true):
		_pause()
		if launch_values.get("handles", false):
			result["handles"] = LaunchView.handles(carousel)
	return result


func _state() -> Dictionary:
	var scene := _scene()
	var focus := get_viewport().gui_get_focus_owner()
	var result := {"route": route.duplicate(true), "screen": scene.scene_file_path if scene else "",
		"focus": str(focus.get_path()) if focus else "", "console": "", "game": "",
		"fps": Engine.get_frames_per_second(), "frame_ms": Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		"paused": paused, "rig": _views.light_rig(scene)}
	if scene is Carousel:
		var carousel := scene as Carousel
		result["screen"] = _carousel_screen(carousel)
		if carousel._shown and not carousel._shelves.is_empty():
			result["console"] = carousel._consoles.selected().folder
		if carousel._row.has_games():
			result["game"] = carousel._row.selected_game().id
	return result


## The screen the carousel shows: its own, or the page of the screens flow over it.
func _carousel_screen(carousel: Carousel) -> String:
	var own: String = Carousel.Screen.keys()[carousel._screen]
	var shown := own.to_lower()
	if carousel._screens.is_visible_in_tree():
		for child in carousel._screens.get_children():
			if child is Control and (child as Control).is_visible_in_tree():
				shown = str(child.name).to_snake_case()
	return shown


func _screen_name() -> String:
	var scene := _scene()
	return _carousel_screen(scene as Carousel) if scene is Carousel else ""


func _shot(message: Dictionary) -> Dictionary:
	var format: Variant = message.get("format", "png")
	var quality: Variant = message.get("quality", 0.85)
	if format not in ["jpg", "png"] or not _number(quality) or quality < 0 or quality > 1:
		return _error("invalid picture format or quality")
	var without_model: Callable = _views.hide_model(_scene()) if message.get("hide") == "model" else Callable()
	var image := capture()
	if without_model.is_valid():
		without_model.call()
	if image == null or image.is_empty():
		return _error("renderer has no picture")
	var bytes := image.save_jpg_to_buffer(_float(quality)) if format == "jpg" else image.save_png_to_buffer()
	return {"size": bytes.size(), "w": image.get_width(), "h": image.get_height(), "_bytes": bytes}


func capture() -> Image:
	if DisplayServer.get_name() == "headless":
		return null
	RenderingServer.force_draw()
	return get_viewport().get_texture().get_image()


func _overlay(message: Dictionary, restart: bool) -> Dictionary:
	var files: Variant = message.get("files")
	if files is not Array:
		return _error("invalid files")
	var started := Time.get_ticks_usec()
	var validated_files: Array = files
	# The engine compiles every named script before the first one runs: no pack can replace a script.
	for item: Variant in validated_files:
		var entry: Dictionary = item if item is Dictionary else {}
		if str(entry.get("path", "")).get_extension() == "gd":
			return _error("a script cannot be replaced while the app runs or as it starts")
	if not restart:
		for item: Variant in validated_files:
			var entry: Dictionary = item if item is Dictionary else {}
			var path := str(entry.get("path", ""))
			if START_FILES.any(func(start: String) -> bool: return path.begins_with(start)) \
					or path.get_extension() in _FONT_EXTENSIONS:
				return _error("%s is read at start or cached with its shapes: use restart" % path)
	var result := _packs.write(validated_files, restart)
	if not result["ok"] or restart:
		return result
	if not ProjectSettings.load_resource_pack(str(result["pack"]), true):
		return _error("cannot load overlay")
	for item: Dictionary in validated_files:
		var path: String = item["path"]
		for script: GDScript in CACHE_FILES.get(path, []):
			script.call(&"forget")
		# LaunchAnimation and Appearance read JSON per scene; they hold no static file cache.
		if ResourceLoader.has_cached(path):
			ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	# A value a client already tuned into the screen shown needs no replay of the route back to it; a light file's
	# rigs are built again where they stand, whatever their number of lights.
	if not message.get("replay", true):
		for item: Dictionary in validated_files:
			if item["path"] == StudioLights.FILE:
				Views.relight(_scene())
	else:
		var replayed := await _go()
		if not replayed.get("ok", true):
			return replayed
	return {"ms": (Time.get_ticks_usec() - started) / 1000.0}


static func _valid_route(value: Variant) -> bool:
	if value is not Array:
		return false
	for item: Variant in value:
		if item is not Dictionary:
			return false
		var step: Dictionary = item
		if step.has("library") and step["library"] not in ["full", "adding"]:
			return false
		if step.has("locale") and step["locale"] not in ["fr", "en"]:
			return false
		for key: String in ["press", "push", "release"]:
			if step.has(key) and (step[key] is not String or not InputMap.has_action(str(step[key]))):
				return false
		if step.has("wait") and (not _number(step["wait"]) or step["wait"] < 0 or step["wait"] > 36000):
			return false
		if step.has("hold") and step["hold"] is not bool:
			return false
		if step.has("keep") and (step["keep"] is not bool or not step.has("push")):
			return false
	return true


func _go() -> Dictionary:
	_release_actions()
	var tree_paused := get_tree().paused
	var input_disabled := get_viewport().is_input_disabled()
	get_tree().paused = false
	Engine.time_scale = _REPLAY_SPEED
	get_viewport().set_disable_input(false)
	var result := await _reload_scene()
	if result.get("ok", true):
		result = await _settle_start()
	if result.get("ok", true):
		for item: Dictionary in route:
			for key: String in ["press", "push", "release"]:
				var action: StringName = StringName(str(item.get(key, "")))
				if action.is_empty():
					continue
				if key == "push":
					# The frame that first sees the direction held must already run at the recorded speed.
					Engine.time_scale = 1.0
					await get_tree().process_frame
				_act(action, key != "release")
				if key == "press":
					_act(action, false)
			if item.has("release"):
				# The frame that still sees the direction held runs at the recorded speed too.
				await get_tree().process_frame
			Engine.time_scale = 1.0 if not _held.is_empty() else _REPLAY_SPEED
			await _wait(_float(item.get("wait", 80)))
		RenderingServer.force_draw()
	# A last step marked `hold` leaves the app paused on the first frame of what it started: the press registers
	# with the clock stopped, then `step` plays on frame by frame.
	var hold := false
	if result.get("ok", true) and not route.is_empty():
		var last: Dictionary = route.back()
		hold = last.get("hold", false)
	if hold:
		Engine.time_scale = 0.0
		await get_tree().process_frame
	var kept_step: Dictionary = route.back() if not route.is_empty() else {}
	var keep: bool = kept_step.get("keep", false) == true
	if not keep:
		_release_actions()
	get_tree().paused = tree_paused
	Engine.time_scale = 1.0
	get_viewport().set_disable_input(input_disabled)
	if hold:
		_pause()
	return result


## Waits [param units] of the route's wait, in game time, which follows the engine's time scale; and, replaying
## fast, at least the frames the speed-up leaves, as a slow machine's few frames would not let the app react.
func _wait(units: float) -> void:
	if units <= 0.0:
		return
	var first := Engine.get_process_frames()
	var frames := ceili(units / Engine.time_scale) if Engine.time_scale > 1.0 else 0
	await get_tree().create_timer(units * _WAIT_UNIT_S, true, false, false).timeout
	while Engine.get_process_frames() - first < frames:
		await get_tree().process_frame


func _settle_start() -> Dictionary:
	await get_tree().process_frame
	var scene := _scene() as Carousel
	if scene == null:
		return {"ok": true}
	for frame in 600:
		var waiting := is_instance_valid(scene._screens._welcome) and scene._screens._welcome.is_visible_in_tree()
		if (scene._shown or waiting) and not scene._screens.is_playing() and (scene._arrival == null or not scene._arrival.is_running()):
			return {"ok": true}
		await get_tree().process_frame
	return _error("the scene did not settle after 600 frames")


func _reload_scene() -> Dictionary:
	var adding := false
	for item: Dictionary in route:
		if item.has("locale"):
			TranslationServer.set_locale(str(item["locale"]))
		if item.get("library") == "adding":
			adding = true
	if adding and _scene() is Carousel:
		var previous := _scene()
		var packed := load(previous.scene_file_path) as PackedScene
		var next := packed.instantiate() as Carousel
		var fixture := RouteFixture.new()
		next.android = fixture
		(next.get_node("%Screens") as ScreenFlow).welcome_waits = false
		next.add_child(fixture)
		var tree := get_tree()
		previous.get_parent().remove_child(previous)
		previous.queue_free()
		tree.root.add_child(next)
		tree.current_scene = next
		await tree.process_frame
		return {"ok": true}
	if _scene() == null or get_tree().reload_current_scene() != OK:
		return _error("cannot reload current scene")
	await get_tree().scene_changed
	return {"ok": true}


func _scene() -> Node:
	return get_tree().current_scene


func _act(action: StringName, pressed: bool) -> void:
	if pressed:
		Input.action_press(action)
	else:
		Input.action_release(action)
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)
	if pressed and action not in _held:
		_held.append(action)
	elif not pressed:
		_held.erase(action)


func _release_actions() -> void:
	for action: StringName in _held.duplicate():
		_act(action, false)


func _pause() -> void:
	if not paused:
		_previous_scale = Engine.time_scale
		_previous_pause = get_tree().paused
		_previous_input = get_viewport().is_input_disabled()
	paused = true
	Engine.time_scale = 0.0
	get_tree().paused = true
	get_viewport().set_disable_input(true)


func _resume() -> void:
	if not paused:
		return
	paused = false
	Engine.time_scale = _previous_scale
	get_tree().paused = _previous_pause
	get_viewport().set_disable_input(_previous_input)


func _step(message: Dictionary) -> Dictionary:
	var frames: Variant = message.get("frames")
	if not _number(frames) or frames < 1 or frames > 3600 or frames != int(_float(frames)):
		return _error("invalid frame count")
	_pause()
	# While the tree stays paused, advance the same frame-driven shell and its tweens at a fixed delta. A node
	# that processes while paused also gets the engine's own call that frame, with a delta of 0.
	for frame in int(_float(frames)):
		_step_node(_scene())
		for tween in get_tree().get_processed_tweens():
			if not tween.is_running():
				continue
			tween.custom_step(1.0 / 60.0)
		await get_tree().process_frame
	RenderingServer.force_draw()
	return {"frames": int(_float(frames))}


func _step_node(node: Node) -> void:
	if not is_instance_valid(node) or node.process_mode == Node.PROCESS_MODE_DISABLED:
		return
	if node.is_processing() and node.has_method(&"_process"):
		node.call(&"_process", 1.0 / 60.0)
	if node is AnimationPlayer:
		(node as AnimationPlayer).advance(1.0 / 60.0)
	for child in node.get_children():
		_step_node(child)


func _scrub(message: Dictionary) -> Dictionary:
	var time: Variant = message.get("t")
	if not _number(time) or time < 0:
		return _error("invalid animation time")
	var sequence := _find_sequence(_scene())
	if sequence == null or not sequence.player.has_animation(&"launch"):
		return _error("no launch animation")
	_pause()
	sequence._seek(clampf(_float(time), 0.0, sequence.player.get_animation(&"launch").length))
	var scene := _scene() as Carousel
	if scene:
		var launch := scene._game_launch
		if launch._into_console and launch.is_inserting():
			launch._clock_s = maxf(0.0, sequence._at_s - sequence._moment(&"launch"))
	RenderingServer.force_draw()
	return {"t": sequence._at_s}


func _find_sequence(node: Node) -> ConsoleSequence:
	if node == null or node is ConsoleSequence:
		return node as ConsoleSequence
	for child in node.get_children():
		var found := _find_sequence(child)
		if found:
			return found
	return null


func _snapshot() -> Dictionary:
	var library := await android._request(&"library")
	var settings := await android._request(&"settings")
	if not library.get("ok", false) or not settings.get("ok", false):
		return _error("snapshot request failed")
	var parsed: Variant = JSON.parse_string(str(library.get("library", "{}")))
	var content: Dictionary = parsed if parsed is Dictionary else {}
	# The letters and regions of each shelf as the core orders them: the desktop has no core to ask.
	var browsed := {}
	for game: Dictionary in content.get("games", []):
		var platform_id: String = game.get("platform_id", "")
		if platform_id and platform_id not in browsed:
			browsed[platform_id] = {"title": android.browse_text(platform_id, &"title", ""),
				"region": android.browse_text(platform_id, &"region", "")}
	return {"library": library, "settings": settings, "variants": content.get("console_variants", {}),
		"browse": browsed, "locale": TranslationServer.get_locale()}


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(_float(value))


static func _float(value: Variant) -> float:
	return value


static func _point(message: Dictionary) -> Vector2:
	var x: float = message["x"]
	var y: float = message["y"]
	return Vector2(x, y)


static func _error(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}
