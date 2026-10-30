# SPDX-License-Identifier: GPL-3.0-or-later
class_name StepField
extends Button
## One numbered line of the add-console form: its step chip (filled with the gel once chosen), its name small
## over what was chosen, a chevron at the right. The line draws its own text; the button's [member text] holds
## what is shown, for the tests and the screen readers. A press asks for the choice.

const _SIZE := Vector2(56.0 * FormPaint.CQW, 6.4 * FormPaint.CQW)
const _PAD_LEFT := 2.2 * FormPaint.CQW
const _PAD_RIGHT := 1.8 * FormPaint.CQW
const _GAP := 1.6 * FormPaint.CQW
const _CHIP := 3.4 * FormPaint.CQW
const _CHIP_RING := 0.14 * FormPaint.CQW
const _CHIP_PX := 1.3 * FormPaint.CQW
const _KICK_PX := 1.35 * FormPaint.CQW
const _NAME_PX := 2.35 * FormPaint.CQW
const _CHEVRON := 1.1 * FormPaint.CQW
const _CHEVRON_STROKE := 2.2 * 1.1 * FormPaint.CQW / 10.0
const _SEPARATOR_RIGHT := 1.4 * FormPaint.CQW
const _SEPARATOR_GAP := 0.3 * FormPaint.CQW
const _UNCHOSEN_ALPHA := 0.82
## The chip's number goes from muted to white over this long when the choice is made.
const _LIT_S := 0.3

## The line's name, over its value (a msgid).
@export var label := ""
## Its number, from 1.
@export var step := 1

## Whether its choice is made: the chip fills with the gel.
var done := false:
	set(value):
		if value == done:
			return
		done = value
		_paint_chip()
		_light(1.0 if value else 0.0)
		queue_redraw()
## The gel's colour now.
var rim := StudioTokens.NEUTRAL:
	set(value):
		rim = value
		_paint_chip()

var _chip := FormPaint.Layer.new(self, _chip_material())
## How far the chip's number is lit, 0 (muted) to 1 (white).
var _lit := 0.0
var _lighting: Tween


func _init() -> void:
	FormPaint.plain(self)
	clip_text = true
	custom_minimum_size = _SIZE
	item_rect_changed.connect(_place_chip)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


## The value shown under the line's name; [param chosen] when it is a choice, not the "Choose…" it starts as.
func show_value(shown: String, chosen := true) -> void:
	text = shown
	done = chosen
	queue_redraw()


## The width the value has: between the chip and the chevron.
func room() -> float:
	return size.x - _PAD_RIGHT - _CHEVRON - _GAP - (_PAD_LEFT + _CHIP + _GAP)


func _draw() -> void:
	var middle := size.y / 2.0
	var chip := Vector2(_PAD_LEFT + _CHIP / 2.0, middle)
	if not done:
		draw_arc(chip, _CHIP / 2.0 - _CHIP_RING / 2.0, 0.0, TAU, 48, StudioTokens.LINE, _CHIP_RING, true)
	var number := FormPaint.line("%02d" % step, StudioTokens.Face.PLEX_600, _CHIP_PX)
	number.draw(self, Vector2(chip.x - number.width / 2.0, middle - FormPaint.PLEX_LINE * _CHIP_PX / 2.0
		+ FormPaint.PLEX_ASCENT * _CHIP_PX - number.baseline), StudioTokens.MUTE.lerp(Color.WHITE, _lit))
	var left := _PAD_LEFT + _CHIP + _GAP
	var kick := FormPaint.line(tr(label).to_upper(), StudioTokens.Face.PLEX_600, _KICK_PX, 0.14)
	var value := FormPaint.line(text, _value_face(), _NAME_PX)
	var kick_line := FormPaint.PLEX_LINE * _KICK_PX
	var top := (size.y - kick_line - value.height) / 2.0
	kick.draw(self, Vector2(left, top + FormPaint.PLEX_ASCENT * _KICK_PX - kick.baseline), StudioTokens.MUTE)
	value.fit(room())
	var ink := StudioTokens.INK if done else StudioTokens.MUTE
	ink.a = 1.0 if has_focus() else _UNCHOSEN_ALPHA
	value.draw(self, Vector2(left, top + kick_line), ink)
	_draw_chevron(Vector2(size.x - _PAD_RIGHT - _CHEVRON, (size.y - _CHEVRON * 1.6) / 2.0))
	draw_rect(Rect2(_PAD_LEFT, size.y + _SEPARATOR_GAP - 1.0, size.x - _PAD_LEFT - _SEPARATOR_RIGHT, 1.0), StudioTokens.LINE)


## The chevron: a 10 × 16 round-capped stroke from (2, 2) to (8, 8) and back to (2, 14).
func _draw_chevron(at: Vector2) -> void:
	var k := _CHEVRON / 10.0
	var points := PackedVector2Array([at + Vector2(2.0, 2.0) * k, at + Vector2(8.0, 8.0) * k, at + Vector2(2.0, 14.0) * k])
	draw_polyline(points, StudioTokens.MUTE, _CHEVRON_STROKE, true)
	for point in points:
		draw_circle(point, _CHEVRON_STROKE / 2.0, StudioTokens.MUTE)


func _value_face() -> StudioTokens.Face:
	return StudioTokens.Face.JAKARTA_800 if done and has_focus() else StudioTokens.Face.JAKARTA_700


func _light(to: float) -> void:
	var from := _lit
	_lighting = Motion.restart(self, _lighting)
	_lighting.tween_method(func(t: float) -> void:
		_lit = lerpf(from, to, Motion.eased(Motion.Easing.EASE, t))
		queue_redraw(), 0.0, 1.0, _LIT_S)


func _place_chip() -> void:
	if done:
		_chip.place(Rect2(Vector2(_PAD_LEFT, (size.y - _CHIP) / 2.0), Vector2.ONE * _CHIP), _CHIP / 2.0)
	else:
		_chip.clear()


## The chip in the gel now, its colours changed where they stand.
func _paint_chip() -> void:
	_chip.shown.colors.assign([StudioMaterial.whitened(rim, 0.7), rim])
	_chip.repaint()
	_place_chip()


func _chip_material() -> StudioMaterial:
	var colors: Array[Color] = [StudioMaterial.whitened(StudioTokens.NEUTRAL, 0.7), StudioTokens.NEUTRAL]
	var stops: Array[float] = [0.0, 0.7]
	return FormPaint.material(colors, _CHIP / 2.0, [], Vector2(0.38, 0.3), stops)
