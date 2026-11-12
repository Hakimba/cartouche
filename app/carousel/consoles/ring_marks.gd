# SPDX-License-Identifier: GPL-3.0-or-later
class_name RingMarks
extends Control
## What the ring shows besides its consoles ([ConsoleOrder], [ConsolePlacing]), in the reference frame this node
## is: the arrow outside the ring, an ink head glowing with a console's gel, and the middle, a logo over a line
## of words and small logos. The two flows say where the arrow goes and what the middle shows.

## The middle's top (px) under the ordering ring.
const MIDDLE_Y := 419.2
## The arrow stands this far (px) beyond the pointed console's box, further while it is held.
const ARROW_OUT_PX := 14.08
const ARROW_HELD_PX := 20.48
## How far lower the middle starts when it comes in.
const _MIDDLE_RISE_PX := 12.8
## A unit of the arrow's drawing in px (it is 28 × 36 units), its shadow's offset.
const _ARROW_UNIT := 1.28
## How far the white edge reaches past the ink: half of a stroke of 3 units shows outside it.
const _ARROW_EDGE_PX := 1.5 * _ARROW_UNIT
const _ARROW_SHADOW := Vector2(0.0, 3.2)
## The coloured glow round the arrow: its layers' alphas, from the nearest
## to the farthest, each reaching 2 px further out than the one before; a Gaussian's edge laid in steps.
const _GLOW_ALPHAS: Array[float] = [0.0856, 0.0668, 0.0472, 0.0302, 0.0173, 0.0089, 0.0041, 0.0025]
const _GLOW_STEP_PX := 2.0

static var _sentence_slots := RegEx.create_from_string("\\{(before|after|name)\\}")

## Where the arrow is round the ring (radians), and where it is going: its angle, and how far (px) beyond the ring.
var arrow_angle := 0.0
var arrow_to := 0.0
var arrow_out_to := 0.0
## The gel of the console pointed at, which the arrow's glow takes.
var rim := Color.WHITE
## How far the middle has risen, from 0 (gone, lower) to 1; how opaque the arrow is.
var middle_in := 0.0:
	set(value):
		middle_in = value
		place_middle()
var arrow_in := 0.0:
	set(value):
		arrow_in = value
		_arrow.modulate.a = arrow_in
## Where the middle's top stands (px): the ordering ring's, or under the console placed.
var middle_y := MIDDLE_Y

var _arrow_out := 0.0
@onready var _arrow: Control = %Arrow
@onready var _middle: Control = %Middle
@onready var _logo: LogoView = %Logo
@onready var _where: Control = %Where
@onready var _before: LogoView = %Before
@onready var _after: LogoView = %After


func _ready() -> void:
	_arrow.draw.connect(_draw_arrow)


## The arrow stands where it is going, at once.
func snap() -> void:
	arrow_angle = arrow_to
	_arrow_out = arrow_out_to


## The arrow follows where it is going by [param share], and stands there.
func follow(share: float) -> void:
	arrow_angle = RingFit.turn_toward(arrow_angle, arrow_to, share)
	_arrow_out = RingFit.toward(_arrow_out, arrow_out_to, share)
	var radial := Vector2(RingFit.RADII.x * sin(arrow_angle), RingFit.RADII.y * cos(arrow_angle)).normalized()
	_arrow.position = RingFit.place(arrow_angle) + radial * _arrow_out - Vector2(_arrow.pivot_offset.x, 0.0)
	_arrow.rotation = atan2(-radial.x, radial.y)


## The arrow drawn again, in the gel [member rim] now is.
func redraw() -> void:
	_arrow.modulate.a = arrow_in
	_arrow.queue_redraw()


## The logo of the console in [param folder] in the middle.
func show_logo(folder: String) -> void:
	_logo.show_logo(LogoView.Slot.RING_MIDDLE, folder)


func place_middle() -> void:
	_middle.modulate.a = middle_in
	_middle.position.y = middle_y + (1.0 - middle_in) * _MIDDLE_RISE_PX


## The line under the logo tells a console stands between two others, by their logos; next to the one when
## [param alone].
func say_between(before_folder: String, after_folder: String, alone: bool) -> void:
	say(tr("next to {name}", "ring") if alone else tr("between {before} and {after}", "ring"), before_folder, after_folder)


## The line under the logo. Logo placeholders follow the complete translated sentence, including languages with a
## different order.
func say(text: String, before_folder := "", after_folder := "") -> void:
	for child in _where.get_children():
		_where.remove_child(child)
		if child is not LogoView:
			child.queue_free()
	_before.hide()
	_after.hide()
	_before.show_logo(LogoView.Slot.BETWEEN_MINI, before_folder)
	_after.show_logo(LogoView.Slot.BETWEEN_MINI, after_folder)
	var logos: Dictionary[String, LogoView] = {"before": _before, "after": _after, "name": _before}
	var at := 0
	for slot in _sentence_slots.search_all(text):
		_word(text.substr(at, slot.get_start() - at))
		var logo := logos[slot.get_string(1)]
		_where.add_child(logo)
		logo.show()
		at = slot.get_end()
	_word(text.substr(at))
	for logo: LogoView in [_before, _after]:
		if not logo.get_parent():
			_where.add_child(logo)


func _word(text: String) -> void:
	var words := text.strip_edges()
	if not words.is_empty():
		_where.add_child(Word.new(words))


## The arrow: an ink head with a white edge and a shine, a shadow and a glow of the pointed
## console's gel.
func _draw_arrow() -> void:
	var head := _arrow_shape([Vector2(0, 0), Vector2(12, 28), Vector2(0, 21), Vector2(-12, 28)])
	var shine := _arrow_shape([Vector2(0, 4), Vector2(7, 22), Vector2(0, 18)])
	for k in range(_GLOW_ALPHAS.size(), 0, -1):
		_stroke_arrow(head, _ARROW_EDGE_PX + k * _GLOW_STEP_PX, Color(rim, _GLOW_ALPHAS[k - 1]), true)
	_arrow.draw_colored_polygon(_shifted(head, _ARROW_SHADOW), Backdrop.palette.arrow_drop)
	_stroke_arrow(head, _ARROW_EDGE_PX, Backdrop.palette.arrow_stroke, false)
	_arrow.draw_colored_polygon(head, Backdrop.palette.ink)
	_arrow.draw_colored_polygon(shine, Backdrop.palette.arrow_shine)


## The head's outline [param reach] px out, with round corners: edge by edge with a disc on each corner (a
## polyline's own corners are mitred), the inside filled when [param filled].
func _stroke_arrow(head: PackedVector2Array, reach: float, colour: Color, filled: bool) -> void:
	if filled:
		_arrow.draw_colored_polygon(head, colour)
	for k in head.size():
		_arrow.draw_line(head[k], head[(k + 1) % head.size()], colour, 2.0 * reach, true)
		_arrow.draw_circle(head[k], reach, colour)


## The points [param units] (in arrow units, tip at the origin) in the arrow control's pixels.
func _arrow_shape(units: Array[Vector2]) -> PackedVector2Array:
	var points := PackedVector2Array()
	for unit in units:
		points.append(Vector2(_arrow.pivot_offset.x + unit.x * _ARROW_UNIT, (unit.y + 3.0) * _ARROW_UNIT))
	return points


func _shifted(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point in points:
		moved.append(point + by)
	return moved


## A word of the line under the logo, in the mono face and the muted ink.
class Word:
	extends Control

	const _PX := 20.48

	var _text: String
	var _line: StudioText

	func _init(text: String) -> void:
		_text = text
		mouse_filter = MOUSE_FILTER_IGNORE
		_line = StudioText.new(text, StudioTokens.Face.PLEX_500, _PX, 0.0, false)

	func shown() -> String:
		return _text

	func _get_minimum_size() -> Vector2:
		return Vector2(_line.width, _line.height)

	func _draw() -> void:
		_line.draw(self, Vector2(0.0, (size.y - _line.height) / 2.0), Backdrop.palette.mute)
