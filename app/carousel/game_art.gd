# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameArt
extends Node
## The games' disc scans the plugin stored (see `Scraper.kt`), as textures. An image is read and
## its mipmaps made on a worker thread, as it takes tens of milliseconds; at most one texture a frame
## is then sent to the GPU, so that labels arriving never stall the carousel. The latest textures
## are kept, the oldest dropped; an image that cannot be read is not read again.

## [method request]ed art of [param game_id] is ready: [method has_texture] is now true.
signal loaded(game_id: String)

const _KEPT := 24

## The stored art by game id.
var _art: Dictionary[String, AndroidServices.Art] = {}
## Textures made, by game id, the latest last.
var _textures: Dictionary[String, Texture2D] = {}
## Worker tasks reading an image, by game id.
var _reading: Dictionary[String, int] = {}
## Images read, by game id, waiting for their texture.
var _read: Dictionary[String, Image] = {}
var _unreadable: Dictionary[String, bool] = {}


func _ready() -> void:
	set_process(false)


# Runs only while images wait for their texture.
func _process(_delta: float) -> void:
	var game_id: String = _read.keys()[0]
	var image := _read[game_id]
	_read.erase(game_id)
	set_process(not _read.is_empty())
	if _textures.size() >= _KEPT:
		_textures.erase(_textures.keys()[0])
	_textures[game_id] = ImageTexture.create_from_image(image)
	loaded.emit(game_id)


func _exit_tree() -> void:
	for task: int in _reading.values():
		WorkerThreadPool.wait_for_task_completion(task)


## Adds [param art], stored for a game, replacing what it had: an image of what it had, read or
## being read, is dropped.
func add(art: AndroidServices.Art) -> void:
	_art[art.game_id] = art
	_textures.erase(art.game_id)
	_read.erase(art.game_id)
	_unreadable.erase(art.game_id)


## Whether [param game] has a stored image.
func has_art(game: AndroidServices.Game) -> bool:
	return game.id in _art


func has_texture(game: AndroidServices.Game) -> bool:
	return game.id in _textures


## The texture of a game that [method has_texture].
func texture(game: AndroidServices.Game) -> Texture2D:
	return _textures[game.id]


## Starts reading [param game]'s image, unless it has no art, has its texture, is being read or
## could not be read; [signal loaded] tells when it is ready.
func request(game: AndroidServices.Game) -> void:
	var id := game.id
	if not has_art(game) or id in _textures or id in _reading or id in _read or id in _unreadable:
		return
	_reading[id] = WorkerThreadPool.add_task(_read_image.bind(id, _art[id].path, game.title))


## Runs on a worker thread; hands the image, or none, to the main thread.
func _read_image(game_id: String, path: String, title: String) -> void:
	var started := Time.get_ticks_usec()
	var image := Image.load_from_file(path)
	if image and not image.is_empty():
		image.generate_mipmaps()
		Diagnostics.trace("art", "%s read in %.1f ms" % [title, (Time.get_ticks_usec() - started) / 1000.0])
	else:
		image = null
		Diagnostics.trace("art", "%s: %s could not be read" % [title, path])
	_on_read.call_deferred(game_id, path, image)


func _on_read(game_id: String, path: String, image: Image) -> void:
	WorkerThreadPool.wait_for_task_completion(_reading[game_id])
	_reading.erase(game_id)
	if path != _art[game_id].path:
		return
	if image:
		_read[game_id] = image
		set_process(true)
	else:
		_unreadable[game_id] = true
