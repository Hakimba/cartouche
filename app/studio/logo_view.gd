# SPDX-License-Identifier: GPL-3.0-or-later
class_name LogoView
extends TextureRect
## A console's logo in one of the fixed slots, at its pixel size: each slot's pictures are made ready
## for it, so the app fits nothing. A backdrop with [member Palette.dark_logos] shows the picture made for a dark
## ground (`<console>.dark.png`) where the slot has one.

enum Slot { RAIL_TILE, GAMES_TOP, PLINTH_PLATE, RING_MIDDLE, BETWEEN_MINI }

## Each slot's folder under res://studio/logos.
const FOLDERS: Array[String] = ["rail-tile", "games-top", "plinth-plate", "ring-middle", "between-mini"]
## What shows for a console without a logo in the slot: nothing, no room taken.
const _NONE := preload("res://studio/no_logo.tres")
## The logos read so far, by path (null for none): Godot drops a picture nobody shows, and a list moving
## through the consoles shows a new one at every step.
static var _read: Dictionary[String, Texture2D] = {}

var _slot := Slot.RAIL_TILE
var _console := ""


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	stretch_mode = STRETCH_KEEP
	texture = _NONE


## Shows the logo of [param console] (its folder under res://carousel/consoles, `ps2_slim`) made for
## [param slot]; nothing, and false, when the slot has none for it.
func show_logo(slot: Slot, console: String) -> bool:
	_slot = slot
	_console = console
	var path := "res://studio/logos/%s/%s.png" % [FOLDERS[slot], console]
	var dark := path.replace(".png", ".dark.png")
	if Backdrop.palette.dark_logos and ResourceLoader.exists(dark):
		path = dark
	if path not in _read:
		_read[path] = load(path) if ResourceLoader.exists(path) else null
	if not _read[path]:
		Diagnostics.trace("studio", "no %s logo for %s" % [FOLDERS[slot], console])
		texture = _NONE
		return false
	texture = _read[path]
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _console:
		show_logo(_slot, _console)
