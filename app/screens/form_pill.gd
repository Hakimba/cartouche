# SPDX-License-Identifier: GPL-3.0-or-later
class_name FormPill
extends Button
## A pill button of the add-console form. The secondary one (Cancel, Remove) is satin, the controller's B on its
## key before its name when it gives up. The primary one (Add, Save) takes the gel's colour once it can act, greyed
## until then. The pill draws its own text; the button's holds the name
## for the tests and the screen readers.

const _HEIGHT := 5.6 * FormPaint.CQW
const _WIDTH := 15.6 * FormPaint.CQW
const _PRIMARY_WIDTH := 18.6 * FormPaint.CQW
const _GAP := 0.9 * FormPaint.CQW
const _RADIUS := 2.8 * FormPaint.CQW
## The Cancel button is a satin card: its corners are the card's, not the pill's.
const _CARD_RADIUS := 1.1 * FormPaint.CQW
const _NAME_PX := 2.1 * FormPaint.CQW
const _OFF := Color(1.0, 0.988235, 0.968627, 0.5)
## The name goes from muted to white over this long when the pill starts to act.
const _LIT_S := 0.3
## How much higher than centred the name is drawn, in px.
const _INK_RAISE := 1.0

## Whether it is the primary pill, the one that adds.
@export var primary := false
## Whether the secondary pill shows the B key: it does where B does what it says (Cancel), not on Remove.
var keyed := true:
	set(value):
		keyed = value
		queue_redraw()

## The gel's colour now.
var rim := StudioTokens.NEUTRAL:
	set(value):
		rim = value
		_recolor()
		queue_redraw()

var _body := FormPaint.Layer.new(self, StudioMaterial.new(StudioTokens.Look.SATIN))
var _key := SatinPanel.Backing.new(self, StudioTokens.Look.KEY)
## What the pill was last dressed as: acting or not.
var _acting := false
## How far the name is lit, 0 (muted) to 1 (white).
var _lit := 0.0
var _lighting: Tween


func _init() -> void:
	FormPaint.plain(self)


func _ready() -> void:
	custom_minimum_size = Vector2(_PRIMARY_WIDTH if primary else _WIDTH, _HEIGHT)
	add_to_group(ButtonGlyph.GROUP)
	_dress()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


func _draw() -> void:
	if primary and _acting == disabled:
		_dress()
	var label := FormPaint.line(tr(text), StudioTokens.Face.JAKARTA_800, _NAME_PX)
	var lead := _lead_size()
	var gap := _GAP if lead.x > 0.0 else 0.0
	var left := (size.x - lead.x - gap - label.width) / 2.0
	_body.place(Rect2(Vector2.ZERO, size), _RADIUS if primary else _CARD_RADIUS)
	var lead_box := Rect2(Vector2(left, (size.y - lead.y) / 2.0 - _INK_RAISE), lead)
	if not primary and keyed:
		ButtonGlyph.draw_key(self, _key, lead_box, &"b")
	else:
		_key.place(Rect2(), 0.0)
	var ink := StudioTokens.INK if not primary else StudioTokens.MUTE.lerp(Color.WHITE, _lit)
	label.draw(self, Vector2(left + lead.x + gap, (size.y - label.height) / 2.0 - _INK_RAISE), ink)


## The key's or the cap's box; none on a secondary pill without its key.
func _lead_size() -> Vector2:
	return ButtonGlyph.key_size(&"b") if not primary and keyed else Vector2.ZERO


## The materials of the state now: the primary pill acts when it is not greyed.
func _dress() -> void:
	var was := _acting
	_acting = primary and not disabled
	if _acting != was:
		_light(1.0 if _acting else 0.0)
	if not primary:
		return
	if _acting:
		var colors: Array[Color] = [Color.WHITE, Color.WHITE]
		var glow := [Vector4(0.0, 10.24, 20.48, -6.4), Color.WHITE, false, false]
		_body.shown = FormPaint.material(colors, _RADIUS, [[Vector4(0.0, 1.28, 0.0, 0.0), Color(1, 1, 1, 0.5), true, false], glow])
	else:
		var colors: Array[Color] = [_OFF, _OFF]
		_body.shown = FormPaint.material(colors, _RADIUS, [[Vector4(0.0, 0.0, 0.0, 1.79), StudioTokens.LINE, true, false]])
	_recolor()


## The acting body in the gel now, its colours changed where they stand.
func _recolor() -> void:
	if not _acting:
		return
	_body.shown.colors.assign([StudioMaterial.whitened(rim, 0.78), rim])
	_body.shown.shadows[1].color = StudioMaterial.shaded(rim, 0.7)
	_body.repaint()


func _light(to: float) -> void:
	var from := _lit
	_lighting = Motion.restart(self, _lighting)
	_lighting.tween_method(func(t: float) -> void:
		_lit = lerpf(from, to, Motion.eased(Motion.Easing.EASE, t))
		queue_redraw(), 0.0, 1.0, _LIT_S)
