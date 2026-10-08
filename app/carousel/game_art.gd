# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameArt
extends Node
## The games' disc scans the plugin stored (see `Scraper.kt`), as textures, read by an
## [ImageReader] so that labels arriving never stall the carousel. The latest textures are kept,
## the oldest dropped; an image that cannot be read is not read again.

## [method request]ed art of [param game_id] is ready: [method has_texture] is now true.
signal loaded(game_id: String)

const _KEPT := 24

## The stored art by game id.
var _art: Dictionary[String, AndroidServices.Art] = {}
## Textures made, by game id, the latest last.
var _textures: Dictionary[String, Texture2D] = {}
var _unreadable: Dictionary[String, bool] = {}
var _reader := ImageReader.new()


# The reader is its child from the start: art not in the tree yet is freed with it.
func _init() -> void:
	add_child(_reader)
	_reader.read.connect(_on_read)


## Adds [param art], stored for a game, replacing what it had: an image of what it had, read or
## being read, is dropped. With [param image], the image already read: [signal loaded] tells it is
## ready at once.
func add(art: AndroidServices.Art, image: Texture2D = null) -> void:
	_art[art.game_id] = art
	_textures.erase(art.game_id)
	_reader.cancel(art.game_id)
	_unreadable.erase(art.game_id)
	if image:
		_keep(art.game_id, image)


## Forgets the art of the games not in [param games] (a platform removed or rescanned).
func keep_only(games: Array[AndroidServices.Game]) -> void:
	var kept: Dictionary[String, bool] = {}
	for game in games:
		kept[game.id] = true
	for known: Dictionary in [_art, _textures, _unreadable]:
		for game_id: String in known.keys():
			if game_id not in kept:
				known.erase(game_id)
				_reader.cancel(game_id)


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
	if not has_art(game) or id in _textures or _reader.is_reading(id) or id in _unreadable:
		return
	_reader.request(id, _art[id].path, game.title)


func _on_read(game_id: String, read: Texture2D) -> void:
	if not read:
		_unreadable[game_id] = true
		return
	_keep(game_id, read)


func _keep(game_id: String, kept: Texture2D) -> void:
	if _textures.size() >= _KEPT:
		_textures.erase(_textures.keys()[0])
	_textures[game_id] = kept
	loaded.emit(game_id)
