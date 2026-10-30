# SPDX-License-Identifier: GPL-3.0-or-later
class_name FormToggle
extends Button
## An option of the add-console form: its name at the left, a switch in the gel's colour at the right whose knob
## glides over when it is turned. A press turns it. The line draws its own text; the button's holds the name for
## the tests and the screen readers.

const _SIZE := Vector2(56.0 * FormPaint.CQW, 5.4 * FormPaint.CQW)
const _PAD_LEFT := 7.2 * FormPaint.CQW
const _PAD_RIGHT := 1.8 * FormPaint.CQW
const _NAME_PX := 2.05 * FormPaint.CQW
const _TRACK := Vector2(5.6, 3.0) * FormPaint.CQW
const _KNOB := 2.4 * FormPaint.CQW
const _KNOB_INSET := 0.3 * FormPaint.CQW
const _KNOB_TRAVEL := 2.6 * FormPaint.CQW
const _KNOB_S := 0.25
const _SEPARATOR_RIGHT := 1.4 * FormPaint.CQW
const _SEPARATOR_GAP := 0.3 * FormPaint.CQW
const _OFF_TRACK := Color("#e3dbcf")
const _WARM := Color(0.27451, 0.203922, 0.133333)

## The gel's colour now.
var rim := StudioTokens.NEUTRAL:
	set(value):
		rim = value
		_paint_track()
		queue_redraw()

## How far over the knob is, 0 to 1.
var _knob_at := 0.0
var _glide: Tween
var _track := FormPaint.Layer.new(self, _track_material())
var _knob := FormPaint.Layer.new(self, _knob_material())


func _init() -> void:
	FormPaint.plain(self)
	toggle_mode = true
	clip_text = true
	custom_minimum_size = _SIZE
	toggled.connect(_turn)


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED:
		queue_redraw()


## Turned or not at once, the knob already over: a form filled, not turned by the person.
func snap() -> void:
	if _glide:
		_glide.kill()
	_knob_at = 1.0 if button_pressed else 0.0
	_paint_track()
	queue_redraw()


func _draw() -> void:
	var track := Rect2(Vector2(size.x - _PAD_RIGHT - _TRACK.x, (size.y - _TRACK.y) / 2.0), _TRACK)
	_track.place(track, _TRACK.y / 2.0)
	_knob.place(Rect2(track.position + Vector2(_KNOB_INSET + _KNOB_TRAVEL * _knob_at, _KNOB_INSET), Vector2.ONE * _KNOB), _KNOB / 2.0)
	var label := FormPaint.line(tr(text), StudioTokens.Face.JAKARTA_700, _NAME_PX)
	label.fit(track.position.x - _PAD_LEFT)
	label.draw(self, Vector2(_PAD_LEFT, (size.y - label.height) / 2.0), StudioTokens.INK)
	draw_rect(Rect2(2.2 * FormPaint.CQW, size.y + _SEPARATOR_GAP - 1.0, size.x - 2.2 * FormPaint.CQW - _SEPARATOR_RIGHT, 1.0),
		StudioTokens.LINE)


func _turn(_on: bool) -> void:
	if _glide:
		_glide.kill()
	_paint_track()
	var from := _knob_at
	var to := 1.0 if button_pressed else 0.0
	_glide = create_tween()
	_glide.tween_method(func(t: float) -> void:
		_knob_at = lerpf(from, to, Motion.eased(Motion.Easing.FLIP, t))
		queue_redraw(), 0.0, 1.0, _KNOB_S)


## The track off, or in the gel now: its colours changed where they stand.
func _paint_track() -> void:
	_track.shown.colors.assign([StudioMaterial.whitened(rim, 0.8), rim] if button_pressed else [_OFF_TRACK, _OFF_TRACK])
	_track.repaint()


func _track_material() -> StudioMaterial:
	var colors: Array[Color] = [_OFF_TRACK, _OFF_TRACK]
	return FormPaint.material(colors, _TRACK.y / 2.0, [[Vector4(0.0, 0.15, 0.3, 0.0) * FormPaint.CQW, Color(_WARM, 0.25), true, false]])


func _knob_material() -> StudioMaterial:
	var colors: Array[Color] = [Color.WHITE, Color("#f1ebe2")]
	return FormPaint.material(colors, _KNOB / 2.0, [[Vector4(0.0, 0.12, 0.3, 0.0) * FormPaint.CQW, Color(_WARM, 0.35), false, false]],
		Vector2(0.38, 0.3))
