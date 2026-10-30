# SPDX-License-Identifier: GPL-3.0-or-later
class_name StartTrace
extends Node
## Traces the carousel's start in debug builds, once it shows: when each step of the start ended, how long the first
## frames took, how long after it the selected game's label replaced its title (for `scripts/bench.sh`); then starts the
## bench or the frame pictures the arguments ask for ([CarouselBench], [FrameShots]).

var _carousel: Carousel
var _row: ShelfRow
var _art: GameArt
var _games: int
var _shelves: int
## When the scene started, then when the appearance was read, the scene set up, the answers taken, the library shown
## and the screens passed, in milliseconds.
var _marks: PackedInt64Array


func _init(carousel: Carousel, row: ShelfRow, art: GameArt, games: int, shelves: int, marks: PackedInt64Array) -> void:
	_carousel = carousel
	_row = row
	_art = art
	_games = games
	_shelves = shelves
	_marks = marks


func _ready() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	var started := _marks[0]
	var shown_ms := Time.get_ticks_msec()
	Diagnostics.trace("carousel", "shown: %d games on %d shelves, %d ms after the scene started" % [
		_games, _shelves, shown_ms - started])
	Diagnostics.trace("carousel", ("start: scene from %d ms, appearance read in %d ms, set up by %d ms, "
		+ "answers by %d ms, library shown by %d ms, screens passed by %d ms") % [started, _marks[1] - started,
		_marks[2] - started, _marks[3] - started, _marks[4] - started, _marks[5] - started])
	var frames := PackedStringArray()
	for frame in 3:
		var frame_started := Time.get_ticks_usec()
		await get_tree().process_frame
		if not is_inside_tree():
			return
		frames.append("%.1f" % ((Time.get_ticks_usec() - frame_started) / 1000.0))
	Diagnostics.trace("carousel", "first frames: %s ms" % ", ".join(frames))
	_trace_selected_label(shown_ms)
	var bench := Diagnostics.argument("bench")
	if bench:
		_carousel.add_child(CarouselBench.new(bench, _carousel, _row))
	var shots := Diagnostics.argument("shots")
	if shots:
		_carousel.add_child(FrameShots.new(shots))


func _trace_selected_label(shown_ms: int) -> void:
	if not _row.has_games() or not _art.has_art(_row.selected_game()):
		return
	var game := _row.selected_game()
	while not _art.has_texture(game):
		await _art.loaded
	Diagnostics.trace("art", "selected label shown %d ms after the carousel" % (Time.get_ticks_msec() - shown_ms))
