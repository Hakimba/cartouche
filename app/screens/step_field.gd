# SPDX-License-Identifier: GPL-3.0-or-later
class_name StepField
extends Button
## One numbered line of the add-console form: its step chip (filled with the gel once chosen), its name small
## over what was chosen, a chevron at the right unless it is locked ([member disabled]). The line draws its own text;
## the button's [member text] holds what is shown, for the tests and the screen readers. A press asks for the choice.

const _SIZE := Vector2(56.0 * FormPaint.CQW, 6.4 * FormPaint.CQW)
const _PAD_LEFT := 2.2 * FormPaint.CQW
const _GAP := 1.6 * FormPaint.CQW
const _CHIP := 3.4 * FormPaint.CQW
const _CHIP_RING := 0.14 * FormPaint.CQW
const _CHIP_PX := 1.3 * FormPaint.CQW
const _KICK_PX := 1.35 * FormPaint.CQW
const _NAME_PX := 2.35 * FormPaint.CQW
const _CHEVRON := 1.1 * FormPaint.CQW
const _CHEVRON_STROKE := 2.2 * 1.1 * FormPaint.CQW / 10.0
const _UNCHOSEN_ALPHA := 0.82

## The line's name, over its value (a msgid).
@export var label := ""
## Its number, from 1.
@export var step := 1

## Drawn as the focused line although it has no focus: a copy standing in for the line focused ([FormEntry]).
var looks_focused := false

## Whether its choice is made: the chip fills with the gel.
var done := false:
	set(value):
		if value == done:
			return
		done = value
		_paint_chip()
		_lit.light(1.0 if value else 0.0)
		queue_redraw()
## The gel's colour now.
var rim := StudioTokens.NEUTRAL:
	set(value):
		rim = value
		_paint_chip()

var _chip := SatinPanel.Backing.of(self, _chip_material())
## The chip's number, muted until the choice is made.
var _lit := FormPaint.Lit.new(self)


func _init() -> void:
	FormPaint.plain(self)
	clip_text = true
	custom_minimum_size = _SIZE
	item_rect_changed.connect(_place_chip)


func _notification(what: int) -> void:
	if what == NOTIFICATION_FOCUS_ENTER or what == NOTIFICATION_FOCUS_EXIT or what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()
	elif what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_paint_chip()


## The value shown under the line's name; [param chosen] when it is a choice, not the "Choose…" it starts as.
func show_value(shown: String, chosen := true) -> void:
	text = shown
	done = chosen
	queue_redraw()


## The width the value has: between the chip and the chevron.
func room() -> float:
	return size.x - FormPaint.PAD_RIGHT - _CHEVRON - _GAP - (_PAD_LEFT + _CHIP + _GAP)


func _draw() -> void:
	var middle := size.y / 2.0
	var chip := Vector2(_PAD_LEFT + _CHIP / 2.0, middle)
	if not done:
		draw_arc(chip, _CHIP / 2.0 - _CHIP_RING / 2.0, 0.0, TAU, 48, Backdrop.palette.line, _CHIP_RING, true)
	var number := FormPaint.line("%02d" % step, StudioTokens.Face.PLEX_600, _CHIP_PX)
	number.draw(self, Vector2(chip.x - number.width / 2.0, middle - FormPaint.PLEX_LINE * _CHIP_PX / 2.0
		+ FormPaint.PLEX_ASCENT * _CHIP_PX - number.baseline), _lit.ink())
	var left := _PAD_LEFT + _CHIP + _GAP
	var kick := FormPaint.line(tr(label).to_upper(), StudioTokens.Face.PLEX_600, _KICK_PX, 0.14)
	var value := FormPaint.line(text, _value_face(), _NAME_PX)
	var kick_line := FormPaint.PLEX_LINE * _KICK_PX
	var top := (size.y - kick_line - value.height) / 2.0
	kick.draw(self, Vector2(left, top + FormPaint.PLEX_ASCENT * _KICK_PX - kick.baseline), Backdrop.palette.mute)
	value.fit(room())
	var ink := Backdrop.palette.ink if done else Backdrop.palette.mute
	ink.a = 1.0 if _focused() else _UNCHOSEN_ALPHA
	value.draw(self, Vector2(left, top + kick_line), ink)
	# A 10 × 16 stroke from (2, 2) to (8, 8) and back to (2, 14).
	if not disabled:
		var k := _CHEVRON / 10.0
		FormPaint.chevron(self, Vector2(size.x - FormPaint.PAD_RIGHT - _CHEVRON, (size.y - _CHEVRON * 1.6) / 2.0) + Vector2(8.0, 8.0) * k,
			Vector2(-6.0, 0.0) * k, Vector2(0.0, 6.0) * k, Backdrop.palette.mute, _CHEVRON_STROKE)
	FormPaint.separator(self)


func _value_face() -> StudioTokens.Face:
	return StudioTokens.Face.JAKARTA_800 if done and _focused() else StudioTokens.Face.JAKARTA_700


func _focused() -> bool:
	return has_focus() or looks_focused


func _place_chip() -> void:
	if done:
		_chip.place(Rect2(Vector2(_PAD_LEFT, (size.y - _CHIP) / 2.0), Vector2.ONE * _CHIP), _CHIP / 2.0)
	else:
		_chip.clear()


## The chip in the gel now, its colours changed where they stand.
func _paint_chip() -> void:
	var gel := Backdrop.palette.gel(rim)
	_chip.shown.colors.assign([StudioMaterial.whitened(gel, 0.7), gel])
	_chip.repaint()
	_place_chip()


func _chip_material() -> StudioMaterial:
	var colors: Array[Color] = [StudioMaterial.whitened(StudioTokens.NEUTRAL, 0.7), StudioTokens.NEUTRAL]
	var stops: Array[float] = [0.0, 0.7]
	return FormPaint.material(colors, _CHIP / 2.0, [], Vector2(0.38, 0.3), stops)
