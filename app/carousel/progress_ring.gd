# SPDX-License-Identifier: GPL-3.0-or-later
class_name ProgressRing
extends Control
## A thin ring with rounded ends, drawn on a blank label while its image downloads: it fills
## clockwise from the top as [member fraction] goes from 0 to 1; a quarter of it turns while the
## image's size is unknown ([member fraction] below 0), [member turn] radians from the top.

## The line's width, as a fraction of the smaller side.
const _WIDTH := 0.022
const _UNKNOWN_SWEEP := 0.25
const _POINTS := 64

## How much of the download is done, from 0 to 1; below 0 when its size is unknown.
var fraction := 0.0
var turn := 0.0
## Its radius, as a fraction of the smaller side.
var radius := 0.2
var color := Color.WHITE


func _draw() -> void:
	var side := minf(size.x, size.y)
	var width := side * _WIDTH
	var centre := size / 2.0
	var ring := side * radius
	var from := -PI / 2.0 + (turn if fraction < 0.0 else 0.0)
	var to := from + TAU * (_UNKNOWN_SWEEP if fraction < 0.0 else clampf(fraction, 0.0, 1.0))
	draw_arc(centre, ring, from, to, _POINTS, color, width, true)
	for end: float in [from, to]:
		draw_circle(centre + Vector2.from_angle(end) * ring, width / 2.0, color, true, -1.0, true)
