# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelZone
extends Control
## A round part of a staged model the stick can pick, such as a disc's label: nothing shows until it
## has the focus; then a thin black ring outlines it, as the focus outlines the app's controls. Its
## owner places it over the part, each frame, as the part moves.

const _INK := Color(0.13, 0.14, 0.17)
## The ring's width, and how far out of the part it stands, in pixels.
const _WIDTH := 3.0
const _GAP := 7.0
## Segments of the circle: smooth enough at the size of a disc on screen.
const _SEGMENTS := 128


func _ready() -> void:
	focus_mode = FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	if has_focus():
		draw_arc(size / 2.0, minf(size.x, size.y) / 2.0 + _GAP, 0.0, TAU, _SEGMENTS, _INK, _WIDTH, true)
