# SPDX-License-Identifier: GPL-3.0-or-later
extends Node
## Sounds played on request by the dev bridge: one at once (`sound`), or a map of the app's actions and screens to
## sounds that plays as they happen (`sounds`). The app's own behaviour is untouched: players are temporary children
## of this node, and the map only listens to the input events and to the screen shown.

const _SCREEN_PREFIX := "screen:"

## The screen shown now, by the name `state` reports.
var screen := Callable()
## Entries by key (an input action, or `screen:` and a screen name), each `{stream, gain_db, screens}`.
var _map: Dictionary = {}
var _screen_shown := ""
## Whether each joypad axis (keyed by device * 100 + axis) is past half-way, as [Diagnostics] reads a stick.
var _axes_past_half: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)


func _process(_delta: float) -> void:
	var now := _screen_now()
	if now == _screen_shown:
		return
	_screen_shown = now
	_play_key(_SCREEN_PREFIX + now)


func _exit_tree() -> void:
	_listen(false)


func play(message: Dictionary) -> Dictionary:
	if message.get("stop") == true:
		for child in get_children():
			if child is AudioStreamPlayer:
				(child as AudioStreamPlayer).stop()
				child.queue_free()
		return {"length": 0.0}
	var entry := _entry(message)
	if entry.is_empty():
		return {"ok": false, "error": "invalid sound"}
	return {"length": _start(entry)}


## Replaces the map; an entry that cannot be read refuses the whole map and keeps the old one.
func set_map(message: Dictionary) -> Dictionary:
	var given: Variant = message.get("map")
	if given is not Dictionary:
		return {"ok": false, "error": "invalid map"}
	var map := {}
	var raw: Dictionary = given
	for key: Variant in raw:
		var entries: Variant = raw[key]
		if key is not String or entries is not Array:
			return {"ok": false, "error": "invalid map"}
		var decoded: Array[Dictionary] = []
		var list: Array = entries
		for item: Variant in list:
			var candidate: Dictionary = item if item is Dictionary else {}
			var entry := _entry(candidate)
			if entry.is_empty():
				return {"ok": false, "error": "invalid sound for %s" % key}
			decoded.append(entry)
		map[key] = decoded
	_map = map
	_screen_shown = _screen_now()
	_listen(not _map.is_empty())
	return {"keys": _map.size()}


static func decode(bytes: PackedByteArray, format: String) -> AudioStream:
	match format:
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		"wav":
			return _wav(bytes)
	return null


## 16-bit PCM, the only form the handed-over sounds come in.
static func _wav(bytes: PackedByteArray) -> AudioStream:
	if bytes.size() < 12 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		return null
	var stream := AudioStreamWAV.new()
	var seen_format := false
	var at := 12
	while at + 8 <= bytes.size():
		var id := bytes.slice(at, at + 4).get_string_from_ascii()
		var size := bytes.decode_u32(at + 4)
		var body := at + 8
		if id == "fmt " and size >= 16 and body + 16 <= bytes.size():
			if bytes.decode_u16(body) != 1 or bytes.decode_u16(body + 14) != 16:
				return null
			stream.stereo = bytes.decode_u16(body + 2) == 2
			stream.mix_rate = bytes.decode_u32(body + 4)
			stream.format = AudioStreamWAV.FORMAT_16_BITS
			seen_format = true
		elif id == "data" and seen_format:
			stream.data = bytes.slice(body, mini(body + size, bytes.size()))
			return stream
		at = body + size + (size & 1)
	return null


## `{stream, gain_db, screens}` of a message, empty when it is not a sound; a `silent` entry has no stream and
## keeps the screens' key quiet (a sound switched off must not leave its key to a more general sound).
func _entry(message: Dictionary) -> Dictionary:
	var data: Variant = message.get("data")
	var format: Variant = message.get("format")
	var gain: Variant = message.get("gain_db", 0.0)
	var screens: Variant = message.get("screens", [])
	if message.get("silent") == true and screens is Array:
		var quiet: Array = screens
		return {"stream": null, "gain_db": 0.0, "screens": quiet}
	if data is not String or format is not String or screens is not Array or (gain is not float and gain is not int):
		return {}
	var stream := decode(Marshalls.base64_to_raw(str(data)), str(format))
	if stream == null or stream.get_length() <= 0.0:
		return {}
	var shown: Array = screens
	var gain_db: float = gain
	return {"stream": stream, "gain_db": clampf(gain_db, -60.0, 24.0), "screens": shown}


func _start(entry: Dictionary) -> float:
	if entry["stream"] == null:
		return 0.0
	var player := AudioStreamPlayer.new()
	var stream: AudioStream = entry["stream"]
	player.stream = stream
	var gain_db: float = entry["gain_db"]
	player.volume_db = gain_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return stream.get_length()


func _listen(on: bool) -> void:
	var window := get_tree().root
	if on and not window.window_input.is_connected(_on_input):
		window.window_input.connect(_on_input)
	elif not on and window.window_input.is_connected(_on_input):
		window.window_input.disconnect(_on_input)
	set_process(on)


func _on_input(event: InputEvent) -> void:
	var crossed := _crosses_half(event)
	if event.is_echo() or not event.is_pressed() or not crossed:
		return
	for key: Variant in _map:
		var action := str(key)
		if not action.begins_with(_SCREEN_PREFIX) and InputMap.has_action(action) and event.is_action(action, true):
			_play_key(action)
			return


## False for a stick that was already past half-way: one push of a stick is one press, not a stream of motions.
func _crosses_half(event: InputEvent) -> bool:
	if event is not InputEventJoypadMotion:
		return true
	var motion := event as InputEventJoypadMotion
	var key := motion.device * 100 + motion.axis
	var was: bool = _axes_past_half.get(key, false)
	var past := absf(motion.axis_value) > 0.5
	_axes_past_half[key] = past
	return past and not was


## The entry of the key made for the screen shown, else the one made for any screen.
func _play_key(key: String) -> void:
	var entries: Array = _map.get(key, [])
	var now := _screen_now()
	var chosen := {}
	for item: Variant in entries:
		var entry: Dictionary = item
		var screens: Array = entry["screens"]
		if now in screens:
			chosen = entry
			break
		if screens.is_empty() and chosen.is_empty():
			chosen = entry
	if not chosen.is_empty():
		Diagnostics.trace("sounds", "%s on %s: %s" % [key, now, "silent" if chosen["stream"] == null else "plays"])
		_start(chosen)


func _screen_now() -> String:
	return str(screen.call()) if screen.is_valid() else ""
