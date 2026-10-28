# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## The packs the bridge writes: an overlay for what a running app reloads, a start pack for what it reads as it
## starts. Each bridge instance keeps its own folder, named after its port, so that a pack another instance
## has mounted is never touched; and a pack this process has mounted is never removed or renamed over.

const ROOT := "user://dev"
const START := "start.pck"
## What a restart wrote, to become [constant START] at the next start; or [constant NONE], the start pack
## to remove then.
const NEXT := "start_next.pck"
const NONE := "start_none"

static var _directory := ""
static var _purged := false
var _serial := Time.get_ticks_usec()


## The folder of this instance's packs.
static func directory() -> String:
	if _directory.is_empty():
		var port := Diagnostics.argument("bridge-port")
		_directory = ROOT.path_join(port if port.is_valid_int() else "default")
	return _directory


## Puts the packs in [param folder], purged at the next [method purge] if it is not the one in use.
static func use(folder: String) -> void:
	if folder != _directory:
		_directory = folder
		_purged = false


## Removes what a previous run of this instance left, once per run, and the start pack's leftovers: only the
## start pack is read at start, and an overlay this run loaded is read from its file again at each use.
static func purge() -> void:
	if _purged:
		return
	_purged = true
	if not DirAccess.dir_exists_absolute(directory()):
		return
	for file_name: String in DirAccess.get_files_at(directory()):
		if file_name.begins_with("overlay_") or file_name.begins_with("source_") or file_name.ends_with(".tmp"):
			DirAccess.remove_absolute(directory().path_join(file_name))


## At the start, before anything reads the packs: the restart's start pack becomes the start pack (or the
## start pack goes, when the restart had no files), then the start pack is mounted.
static func mount_start() -> void:
	var folder := directory()
	var start := folder.path_join(START)
	if FileAccess.file_exists(folder.path_join(NONE)):
		for file_name: String in [NONE, START, NEXT]:
			DirAccess.remove_absolute(folder.path_join(file_name))
	elif FileAccess.file_exists(folder.path_join(NEXT)):
		DirAccess.rename_absolute(folder.path_join(NEXT), start)
	if FileAccess.file_exists(start):
		Diagnostics.trace("bridge", "start pack loaded=%s" % ProjectSettings.load_resource_pack(start, true))


func write(files: Array, restart := false) -> Dictionary:
	var folder := directory()
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return {"ok": false, "error": "cannot create overlay directory"}
	# A restart without files goes back to the app's own files at the next start.
	if files.is_empty() and restart:
		DirAccess.remove_absolute(folder.path_join(NEXT))
		var marker := FileAccess.open(folder.path_join(NONE), FileAccess.WRITE)
		if marker == null:
			return {"ok": false, "error": "cannot write the start marker"}
		marker.close()
		return {"ok": true, "pack": ""}
	if files.is_empty():
		return {"ok": false, "error": "files must not be empty"}
	var decoded: Dictionary[String, PackedByteArray] = {}
	for item: Variant in files:
		if item is not Dictionary:
			return {"ok": false, "error": "invalid file"}
		var entry: Dictionary = item
		var path: Variant = entry.get("path")
		var encoded: Variant = entry.get("data")
		if path is not String or encoded is not String:
			return {"ok": false, "error": "invalid file"}
		var resource: String = path
		if not resource.begins_with("res://") or resource == "res://" \
				or ".." in resource.trim_prefix("res://").split("/") or "." in resource.trim_prefix("res://").split("/") \
				or resource.simplify_path() != resource or "\\" in resource or resource in decoded:
			return {"ok": false, "error": "invalid resource path"}
		var bytes := Marshalls.base64_to_raw(str(encoded))
		if Marshalls.raw_to_base64(bytes) != encoded:
			return {"ok": false, "error": "invalid base64"}
		decoded[resource] = bytes
	_serial += 1
	var pack := folder.path_join("start_next.pck.tmp" if restart else "overlay_%d.pck" % _serial)
	var failure := _pack(decoded, pack, folder)
	if not failure.is_empty():
		DirAccess.remove_absolute(pack)
		return {"ok": false, "error": failure}
	if restart:
		var next := folder.path_join(NEXT)
		if DirAccess.rename_absolute(pack, next) != OK:
			DirAccess.remove_absolute(pack)
			return {"ok": false, "error": "cannot replace the start pack"}
		DirAccess.remove_absolute(folder.path_join(NONE))
		pack = next
	return {"ok": true, "pack": pack}


## Packs [param decoded] into [param pack] through source files that are removed whatever happens;
## the reason it failed, or an empty text.
func _pack(decoded: Dictionary[String, PackedByteArray], pack: String, folder: String) -> String:
	var packer := PCKPacker.new()
	if packer.pck_start(pack) != OK:
		return "cannot create pack"
	var sources: Array[String] = []
	var failure := ""
	for path: String in decoded:
		var source := folder.path_join("source_%d_%d.bin" % [_serial, sources.size()])
		sources.append(source)
		var file := FileAccess.open(source, FileAccess.WRITE)
		if file == null:
			failure = "cannot write overlay source"
			break
		file.store_buffer(decoded[path])
		file.close()
		if packer.add_file(path, source) != OK:
			failure = "cannot pack resource"
			break
	if failure.is_empty() and packer.flush() != OK:
		failure = "cannot finish pack"
	for source in sources:
		DirAccess.remove_absolute(source)
	return failure
