# SPDX-License-Identifier: GPL-3.0-or-later
class_name LogoView
extends TextureRect
## A console's logo in one of the design's slots, at its pixel size: each slot's pictures are made ready
## for it, so the app fits nothing.

enum Slot { RAIL_TILE, GAMES_TOP, PLINTH_PLATE, RING_MIDDLE, BETWEEN_MINI, FORM_PLATE }

## Each slot's folder under res://studio/logos.
const FOLDERS: Array[String] = ["rail-tile", "games-top", "plinth-plate", "ring-middle", "between-mini", "form-plate"]
## What shows for a console without a logo in the slot: nothing, no room taken.
const _NONE := preload("res://studio/no_logo.tres")


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	stretch_mode = STRETCH_KEEP
	texture = _NONE


## Shows the logo of [param console] (its folder under res://carousel/consoles, `ps2_slim`) made for
## [param slot]; nothing, and false, when the slot has none for it.
func show_logo(slot: Slot, console: String) -> bool:
	var path := "res://studio/logos/%s/%s.png" % [FOLDERS[slot], console]
	if not ResourceLoader.exists(path):
		Diagnostics.trace("studio", "no %s logo for %s" % [FOLDERS[slot], console])
		texture = _NONE
		return false
	texture = load(path)
	return true
