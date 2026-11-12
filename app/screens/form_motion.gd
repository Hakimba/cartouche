# SPDX-License-Identifier: GPL-3.0-or-later
class_name FormMotion
extends RefCounted
## How the form adding a console ([AddConsole]) moves: in and out, aside for a chooser and back, its lines making
## way for the models' chooser, its focus card gliding with the focus. Each motion is a tween of the form, the one
## it replaces killed first.

const _CQW := FormPaint.CQW
## How far past a pill button its ring stands.
const _PILL_RING := 0.7 * _CQW
## The corners of that ring, whatever the pill's height.
const _PILL_RING_RADIUS := 3.5 * _CQW
const _CARD_S := 0.24
const _CARD_MOTIONS: Array[StringName] = [&"card_position", &"card_size"]
## The lines' motions, which a chooser takes over; `arrival` is the form's own fade and its console's lift as it comes
## in: a chooser opened meanwhile ends it at once, or the form would stay see-through while it takes presses.
const _LINE_MOTIONS: Array[StringName] = [&"enter", &"lines", &"leave"]
const _FORM_MOTIONS: Array[StringName] = [&"arrival", &"enter", &"lines", &"leave"]
## The form's own motion, in seconds and px: the "+" ball to form transition (its form half), and the form to
## chooser transition (its form half).
const _ENTER_S := 0.32
const _LEAVE_FADE_S := 0.3
const _COME_BACK_S := 0.23
## The console coming back after a chooser, in this time, rising as it does when the form comes in.
const _MODEL_RISE_S := 0.3
## Where the model line goes while its chooser fills the column under it, and how long the lines take to make way.
const _HEADER_Y := 0.0
const _MAKE_WAY_S := 0.2

## The gel of the console chosen: the card's ring takes it, but round Remove.
var rim := StudioTokens.NEUTRAL
var _form: Control
## What fades as the form comes and goes: all of it but its console, a 3D model whose picture, faded, shows as a pale
## ghost. The console stays opaque, there or not.
var _faded: Array[Control] = []
var _title: Control
var _list: Control
var _console: Control
var _model: Control
var _models: Control
var _card: FormPaint.Card
var _choice: StudioChooser
## The lines that make way for the models' chooser, and the controls the card rests on.
var _lines: Array[Control]
var _fields: Array[Control]
## Where each moving part rests, and each motion running.
var _rests: Rests
var _motions: Dictionary[StringName, Tween] = {}


func _init(form: Control, title: Control, list: Control, console: Control, model: Control, models: Control,
		card: FormPaint.Card, choice: StudioChooser, lines: Array[Control], fields: Array[Control]) -> void:
	_form = form
	_title = title
	_list = list
	_console = console
	_model = model
	_models = models
	_card = card
	_choice = choice
	_lines = lines
	_fields = fields
	for part: Control in form.get_children():
		if part != console and part != choice:
			_faded.append(part)
	_rests = Rests.new([_title, _list, _console, _model])


## Where the card goes for the control that has the focus: its box, grown to a ring round a pill.
func aim(control: Control, animated: bool) -> void:
	var pill := control is FormPill
	var rect := Rect2(control.position, control.size).grow(_PILL_RING if pill else 0.0)
	var radius := _PILL_RING_RADIUS if pill else StudioTokens.FOCUS_RADIUS
	_card.bare = pill
	# Round Remove, the ring is red.
	_card.rim = FormPill.red() if pill and (control as FormPill).destructive else rim
	if not animated:
		for key in _CARD_MOTIONS:
			if key in _motions:
				_motions[key].kill()
		_card.position = rect.position
		_card.size = rect.size
		_card.radius = radius
		return
	_glide_card(rect, radius, _CARD_S, Motion.Easing.FOCUS, Motion.Easing.EASE)


## The form half of the "+" ball to form transition: the screen fades in, the console comes up, opaque, the list in
## from the right, the title up from a little lower.
func enter() -> void:
	_settle_lines()
	var arrival := _form.create_tween().set_parallel()
	_motions[&"arrival"] = arrival
	for part in _faded:
		part.modulate.a = 0.0
		arrival.tween_property(part, ^"modulate:a", 1.0, StudioTokens.TR_FORM_FADE_S).set_delay(StudioTokens.TR_FORM_AT_S) \
			.set_custom_interpolator(Motion.curve(Motion.Easing.EASE_OUT))
	var arrive := Motion.curve(Motion.Easing.ARRIVE)
	_console.position.y += StudioTokens.TR_FORM_LIFT_PX
	arrival.tween_property(_console, ^"position:y", _rests.of(_console).y,
		_ENTER_S).set_delay(StudioTokens.TR_FORM_AT_S).set_custom_interpolator(arrive)
	var motion := _form.create_tween().set_parallel()
	_motions[&"enter"] = motion
	_list.position.x += StudioTokens.TR_FORM_SLIDE_PX
	motion.tween_property(_list, ^"position:x", _rests.of(_list).x, _ENTER_S).set_delay(StudioTokens.TR_FORM_AT_S) \
		.set_custom_interpolator(arrive)
	_title.position.y += StudioTokens.TR_FORM_CHOOSER_TITLE_PX
	motion.tween_property(_title, ^"position:y", _rests.of(_title).y, _ENTER_S).set_delay(StudioTokens.TR_FORM_AT_S) \
		.set_custom_interpolator(arrive)


## The form half of the form to "+" ball transition: the console is gone at once, then the screen fades out as the
## list slides off to the right; what the form leaves for comes once it is gone, never moving under it. Returns the
## motion, finished when the form is gone.
func leave() -> Tween:
	_stop(_FORM_MOTIONS)
	var motion := _form.create_tween().set_parallel()
	_motions[&"leave"] = motion
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	_console.self_modulate.a = 0.0
	for part in _faded:
		motion.tween_property(part, ^"modulate:a", 0.0, _LEAVE_FADE_S).set_custom_interpolator(ease_in)
	motion.tween_property(_list, ^"position:x", _rests.of(_list).x + StudioTokens.TR_FORM_SLIDE_PX,
		StudioTokens.TR_FORM_LEAVE_S).set_custom_interpolator(ease_in)
	return motion


## The going under way is stopped: what it chained cannot hide a form shown again.
func stop_leaving() -> void:
	if &"leave" in _motions:
		_motions[&"leave"].kill()


## The form half of the form to chooser transition: the lines leave to the left, the title goes up, the console is
## gone at once, and the card glides to the chooser's cursor.
func step_aside() -> void:
	_stop(_LINE_MOTIONS)
	if &"arrival" in _motions and _motions[&"arrival"].is_valid():
		_motions[&"arrival"].custom_step(StudioTokens.TR_FORM_AT_S + maxf(_ENTER_S, StudioTokens.TR_FORM_FADE_S))
	var motion := _form.create_tween().set_parallel()
	_motions[&"lines"] = motion
	var ease_in := Motion.curve(Motion.Easing.EASE_IN)
	motion.tween_property(_list, ^"position:x", _rests.of(_list).x - StudioTokens.TR_CHOOSER_SHIFT_PX,
		StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(_list, ^"modulate:a", 0.0, StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(_title, ^"position:y", _rests.of(_title).y - StudioTokens.TR_FORM_CHOOSER_TITLE_PX,
		StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	motion.tween_property(_title, ^"modulate:a", 0.0, StudioTokens.TR_CHOOSER_OUT_S).set_custom_interpolator(ease_in)
	_console.self_modulate.a = 0.0
	var from := Rect2(_card.position, _card.size)
	var from_radius := _card.radius
	Motion.animate(_form, _motions, &"card_position", StudioTokens.TR_CHOOSER_CARD_S, StudioTokens.TR_CHOOSER_CARD_S_CURVE,
		func(p: float) -> void:
		var to := _choice.cursor_rect()
		_card.position = from.position.lerp(to.position - _list.global_position, p)
		_card.size = from.size.lerp(to.size, p)
		_card.radius = lerpf(from_radius, StudioTokens.FOCUS_RADIUS, p))


## The way back of [method step_aside], from wherever it was: the lines come back, the console whole at once, rising,
## and the card glides from the chooser's cursor, [param cursor], to the field.
func come_back(cursor: Rect2) -> void:
	_stop(_LINE_MOTIONS)
	var motion := _form.create_tween().set_parallel()
	_motions[&"lines"] = motion
	var arrive := Motion.curve(Motion.Easing.ARRIVE)
	motion.tween_property(_list, ^"position:x", _rests.of(_list).x, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_list, ^"modulate:a", 1.0, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_title, ^"position:y", _rests.of(_title).y, _COME_BACK_S).set_custom_interpolator(arrive)
	motion.tween_property(_title, ^"modulate:a", 1.0, _COME_BACK_S).set_custom_interpolator(arrive)
	_console.self_modulate.a = 1.0
	_console.position.y = _rests.of(_console).y + StudioTokens.TR_FORM_LIFT_PX
	motion.tween_property(_console, ^"position:y", _rests.of(_console).y, _MODEL_RISE_S) \
		.set_custom_interpolator(Motion.curve(Motion.Easing.RISE))
	_card.position = cursor.position - _rests.of(_list)
	_card.size = cursor.size
	_card.radius = StudioTokens.FOCUS_RADIUS
	var field := _form.get_viewport().gui_get_focus_owner()
	if field in _fields:
		_glide_card(Rect2(field.position, field.size), StudioTokens.FOCUS_RADIUS, StudioTokens.TR_CHOOSER_CARD_S,
			StudioTokens.TR_CHOOSER_CARD_S_CURVE, StudioTokens.TR_CHOOSER_CARD_S_CURVE)


## The lines make way while the models' chooser is open ([param away]), and come back: they fade, the model line
## going up to head the column (the focus card fading with it).
func make_way(away: bool) -> void:
	var way: Tween = _motions.get(&"way")
	var motion := Motion.restart(_form, way).set_parallel()
	_motions[&"way"] = motion
	var easing := Motion.curve(Motion.Easing.EASE)
	for line in _lines:
		# Faded, a line takes no finger: a tap on Cancel there would give the form up under the open swatches.
		line.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED if away else Control.MOUSE_BEHAVIOR_INHERITED
		motion.tween_property(line, ^"modulate:a", 0.0 if away else 1.0, _MAKE_WAY_S).set_custom_interpolator(easing)
	motion.tween_property(_model, ^"position:y", _HEADER_Y if away else _rests.of(_model).y, _MAKE_WAY_S) \
		.set_custom_interpolator(easing)
	if away:
		motion.tween_property(_card, ^"modulate:a", 0.0, _MAKE_WAY_S * 0.6)
		_models.modulate.a = 0.0
		motion.tween_property(_models, ^"modulate:a", 1.0, _MAKE_WAY_S).set_delay(_MAKE_WAY_S * 0.5)
	else:
		# Back on the line once it is back in its place.
		motion.tween_callback(aim.bind(_model, false)).set_delay(_MAKE_WAY_S)
		motion.tween_property(_card, ^"modulate:a", 1.0, _MAKE_WAY_S * 0.6).set_delay(_MAKE_WAY_S)


## The card from where it is to [param rect] over [param seconds]: its place by [param moving], its size and
## radius by [param growing].
func _glide_card(rect: Rect2, radius: float, seconds: float, moving: Motion.Easing, growing: Motion.Easing) -> void:
	var from := Rect2(_card.position, _card.size)
	var from_radius := _card.radius
	Motion.animate(_form, _motions, &"card_position", seconds, moving,
		func(p: float) -> void: _card.position = from.position.lerp(rect.position, p))
	Motion.animate(_form, _motions, &"card_size", seconds, growing, func(p: float) -> void:
		_card.size = from.size.lerp(rect.size, p)
		_card.radius = lerpf(from_radius, radius, p))


## Every part of the form where it rests, whole.
func _settle_lines() -> void:
	_stop(_FORM_MOTIONS)
	for part in _faded:
		part.modulate.a = 1.0
	_console.self_modulate.a = 1.0
	_rests.restore()
	for line in _lines:
		line.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED


## The motions [param keys] stopped where they are: the next one starts from there, nothing jumps.
func _stop(keys: Array[StringName]) -> void:
	for key in keys:
		if key in _motions:
			_motions[key].kill()
