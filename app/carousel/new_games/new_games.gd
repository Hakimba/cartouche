# SPDX-License-Identifier: GPL-3.0-or-later
class_name NewGames
extends Node
## The consoles' folders read again, and the games those re-reads brought that the user has not seen yet
## ([AndroidServices.Arrivals]). [method read_again] reads every folder of [member platforms] one console a request, so
## that a launch asked meanwhile waits for one console's read at most. A library a re-read changed waits in
## [method take_library] until the carousel can show it, the latest standing for those before, as each holds every
## console; one the plugin wrote another library after is not shown, the library as it now stands is asked for in its
## place. The marks shown are those the plugin's latest answer told ([signal AndroidServices.arrivals_told]), less the
## consoles entered and the games left that it has not answered yet: an answer it sent before hearing of them must
## not bring a mark back.

## The marks shown changed.
signal changed

var android: AndroidServices = Android
## The platforms whose folders [method read_again] reads, as the library last shown has them.
var platforms := func() -> PackedStringArray: return PackedStringArray()

var _arrivals := AndroidServices.Arrivals.new({})
var _library: AndroidServices.Library
var _reading := false
var _again := false
## The consoles entered and the games left whose answer has not come yet.
var _entering: Dictionary[String, bool] = {}
var _leaving: Dictionary[String, bool] = {}


func _ready() -> void:
	android.arrivals_told.connect(take)


## Shows the marks of [param arrivals], as the plugin last told them.
func take(arrivals: AndroidServices.Arrivals) -> void:
	_arrivals = arrivals
	changed.emit()


## Reads every folder of [member platforms] again, one console after the other; asked while it does, it reads them all
## once more after.
func read_again() -> void:
	_again = true
	if _reading:
		return
	_reading = true
	while _again:
		_again = false
		var started := Time.get_ticks_msec()
		var read: PackedStringArray = platforms.call()
		for platform_id in read:
			var answer := await android.refresh_platform(platform_id)
			if not answer.ok:
				Diagnostics.trace("refresh", "%s not read again (%s): %s" % [platform_id, answer.code, answer.detail])
				continue
			if answer.has_library:
				_library = answer.library
		Diagnostics.trace("refresh", "%d consoles read again in %d ms, a library %s" % [read.size(),
			Time.get_ticks_msec() - started, "waiting" if _library else "unchanged"])
	_reading = false


## Whether a library waits to show since [method take_library] last took it.
func has_library() -> bool:
	return _library != null


## The library waiting, taken once; none when the plugin wrote another since (a name given, a label chosen, the
## consoles put in order, a form saved, each shown already): the library as it now stands waits in its place.
func take_library() -> AndroidServices.Library:
	var library := _library
	_library = null
	if library.revision == android.library_revision:
		return library
	Diagnostics.trace("refresh", "the library read again is %d, the plugin's %d: asked again" % [library.revision,
		android.library_revision])
	_ask_current()
	return null


## Whether some game is not seen yet.
func has_new() -> bool:
	return not _arrivals.unseen.is_empty()


## Whether [param game_id] is a game not seen yet.
func is_new(game_id: String) -> bool:
	return _arrivals.unseen.has(game_id) and not _leaving.has(game_id)


## How many games of [param shelf] its console announces.
func count(shelf: AndroidServices.Shelf) -> int:
	if _entering.has(shelf.platform_id) or not _arrivals.announced.has(shelf.platform_id):
		return 0
	var announced := _arrivals.announced[shelf.platform_id]
	return shelf.games.reduce(func(found: int, game: AndroidServices.Game) -> int:
		return found + int(announced.has(game.id)), 0)


## The user entered [param platform_id]'s console: it announces nothing any more.
func enter(platform_id: String) -> void:
	if _arrivals.announced.has(platform_id) and not _entering.has(platform_id):
		_clear(_entering, platform_id, android.enter_console.bind(platform_id))


## The user left [param game] on its shelf: it is not new any more.
func leave(game: AndroidServices.Game) -> void:
	if is_new(game.id):
		_clear(_leaving, game.id, android.leave_game.bind(game))


func _clear(awaited: Dictionary[String, bool], key: String, request: Callable) -> void:
	awaited[key] = true
	changed.emit()
	var answer: AndroidServices.Result = await request.call()
	awaited.erase(key)
	if not answer.ok:
		Diagnostics.trace("refresh", "%s not marked as seen (%s): %s" % [key, answer.code, answer.detail])
	changed.emit()


func _ask_current() -> void:
	var answer := await android.current_library()
	if answer.ok:
		_library = answer.library
	else:
		Diagnostics.trace("refresh", "the library not read (%s): %s" % [answer.code, answer.detail])
