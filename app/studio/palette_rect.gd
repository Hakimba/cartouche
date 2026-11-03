# SPDX-License-Identifier: GPL-3.0-or-later
class_name PaletteRect
extends ColorRect
## A rectangle in one of the backdrop's colours ([member colour], a field of [Palette]), painted again when another
## backdrop shows.

@export var colour := &"scrim"


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		color = Backdrop.palette.get(colour)
