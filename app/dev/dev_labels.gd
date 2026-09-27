# SPDX-License-Identifier: GPL-3.0-or-later
class_name DevLabels
extends RefCounted
## Debug builds only: label images put by hand in [constant FOLDER], to see real labels on the
## models before they are scraped. Each is named after the game's first serial (`SLUS-21050.png`),
## or else its title; a disc's covers its whole face, a cartridge's its label. They are never
## published.
## Images are read on the main thread, the time for a few frames each: fine for trying models, not
## for scraped labels, which will be read in the background.

const FOLDER := "user://dev-labels"
const _EXTENSIONS: Array[String] = ["png", "jpg", "jpeg", "webp"]
## Larger images are scaled down to this size, and this many are kept at once.
const _LARGEST := 1024
const _KEPT := 16

## Labels read, by name, the latest last; and names without one, so that each file is read once.
var _found: Dictionary[String, Texture2D] = {}
var _missing: Dictionary[String, bool] = {}


func has_label(game: AndroidServices.Game) -> bool:
	var name := _name(game)
	if not Diagnostics.enabled or name in _missing:
		return false
	if name not in _found:
		_read(game, name)
	return name in _found


## The label of a game that [method has_label].
func label(game: AndroidServices.Game) -> Texture2D:
	return _found[_name(game)]


func _read(game: AndroidServices.Game, name: String) -> void:
	for extension in _EXTENSIONS:
		var path := FOLDER.path_join("%s.%s" % [name, extension])
		if not FileAccess.file_exists(path):
			continue
		var image := Image.load_from_file(path)
		if not image or image.is_empty():
			Diagnostics.trace("labels", "%s: %s could not be read" % [game.title, path])
			continue
		var longest := maxi(image.get_width(), image.get_height())
		if longest > _LARGEST:
			var size := Vector2i(Vector2(image.get_size()) * _LARGEST / longest)
			image.resize(size.x, size.y)
		image.generate_mipmaps()
		if _found.size() >= _KEPT:
			_found.erase(_found.keys()[0])
		_found[name] = ImageTexture.create_from_image(image)
		Diagnostics.trace("labels", "%s read from %s" % [game.title, path])
		return
	_missing[name] = true


static func _name(game: AndroidServices.Game) -> String:
	return game.serials[0] if not game.serials.is_empty() else game.title.validate_filename()
