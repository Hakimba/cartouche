# SPDX-License-Identifier: GPL-3.0-or-later
class_name ModelField
extends Button
## The model line of the form adding or editing a console: its name at the left, the model at the right and a chevron pointing
## down, up while its chooser is open, which also shows where its focus is among the models ("01 / 02"). A console
## with one model shows it greyed, and the line takes no focus.
## The line draws its own text; the button's [member text] holds the model, for the tests and the screen readers.

const _SIZE := Vector2(56.0 * FormPaint.CQW, 5.4 * FormPaint.CQW)
const _PAD_LEFT := 7.2 * FormPaint.CQW
const _GAP := 1.2 * FormPaint.CQW
const _NAME_PX := 2.05 * FormPaint.CQW
const _COUNT_PX := 1.3 * FormPaint.CQW
const _CHEVRON := 1.1 * FormPaint.CQW
const _CHEVRON_STROKE := 0.22 * _CHEVRON

## Whether its chooser is open: the chevron points up and the counter shows.
var open := false:
	set(value):
		open = value
		queue_redraw()
## Where the chooser's focus is among the console's [member models], from 0.
var focused := 0:
	set(value):
		focused = value
		queue_redraw()
var models := 0
## The console's colour: the counter's number.
var rim := StudioTokens.NEUTRAL


func _init() -> void:
	FormPaint.plain(self)
	clip_text = true
	custom_minimum_size = _SIZE


func _notification(what: int) -> void:
	if what in [NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT, NOTIFICATION_TRANSLATION_CHANGED]:
		queue_redraw()


## Shows [param model]; with [param choosable] false (one model only), greyed and out of the focus' way.
func show_model(model: String, choosable: bool) -> void:
	text = model
	disabled = not choosable
	focus_mode = FOCUS_ALL if choosable else FOCUS_NONE
	queue_redraw()


func _draw() -> void:
	var label := FormPaint.line(tr("Model"), StudioTokens.Face.JAKARTA_700, _NAME_PX)
	label.draw(self, Vector2(_PAD_LEFT, (size.y - label.height) / 2.0), Backdrop.palette.ink)
	var right := size.x - FormPaint.PAD_RIGHT - (0.0 if disabled else _CHEVRON * 1.6 + _GAP)
	if open:
		var number := FormPaint.line("%02d" % (focused + 1), StudioTokens.Face.PLEX_600, _COUNT_PX, 0.08)
		var rest := FormPaint.line(" / %02d" % models, StudioTokens.Face.PLEX_600, _COUNT_PX, 0.08)
		right -= number.width + rest.width + _GAP
		var y := (size.y - number.height) / 2.0
		number.draw(self, Vector2(right + _GAP, y), Backdrop.palette.gel(rim))
		rest.draw(self, Vector2(right + _GAP + number.width, y), Backdrop.palette.mute)
		right -= _GAP
	var value := FormPaint.line(text, StudioTokens.Face.JAKARTA_800 if has_focus() else StudioTokens.Face.JAKARTA_700,
		_NAME_PX)
	value.fit(right - _PAD_LEFT - label.width - _GAP)
	value.draw(self, Vector2(right - value.width, (size.y - value.height) / 2.0),
		Backdrop.palette.mute if disabled else Backdrop.palette.ink)
	# The step field's chevron turned a quarter: a 16 × 10 stroke pointing down, or up while open.
	if not disabled:
		var k := _CHEVRON / 10.0
		var way := -1.0 if open else 1.0
		FormPaint.chevron(self, Vector2(size.x - FormPaint.PAD_RIGHT - _CHEVRON * 1.6, size.y / 2.0 - _CHEVRON / 2.0)
			+ Vector2(8.0, 5.0 + 3.0 * way) * k, Vector2(0.0, -6.0 * way) * k, Vector2(6.0, 0.0) * k, Backdrop.palette.mute,
			_CHEVRON_STROKE)
	if not open:
		FormPaint.separator(self)
