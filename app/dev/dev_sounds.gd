# SPDX-License-Identifier: GPL-3.0-or-later
class_name DevSounds
extends RefCounted
## Debug builds only: sounds put by hand in [constant FOLDER], to try a launch's sounds that are not
## freely licensed. Each is named after its [Insertion.Cue] (`ps2-clip.mp3`). They are never
## published; release builds play none.

const FOLDER := "user://dev-sounds"
const _EXTENSIONS: Array[String] = ["mp3", "ogg", "wav"]

## Sounds read, by name; and names without one, so that each file is read once.
var _found: Dictionary[String, AudioStream] = {}
var _missing: Dictionary[String, bool] = {}


func has_sound(name: String) -> bool:
	if not Diagnostics.enabled or name in _missing:
		return false
	if name not in _found:
		_read(name)
	return name in _found


## The sound of a name that [method has_sound].
func sound(name: String) -> AudioStream:
	return _found[name]


func _read(name: String) -> void:
	for extension in _EXTENSIONS:
		var path := FOLDER.path_join("%s.%s" % [name, extension])
		if FileAccess.file_exists(path):
			_found[name] = _load(path, extension)
			Diagnostics.trace("sounds", "%s read from %s" % [name, path])
			return
	_missing[name] = true
	Diagnostics.trace("sounds", "%s: none in %s" % [name, FOLDER])


static func _load(path: String, extension: String) -> AudioStream:
	match extension:
		"mp3":
			return AudioStreamMP3.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
	return AudioStreamWAV.load_from_file(path)
