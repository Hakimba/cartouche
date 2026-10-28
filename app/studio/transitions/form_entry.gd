# SPDX-License-Identifier: GPL-3.0-or-later
class_name FormEntry
extends Control
## The consoles screen's half of the transition between the "+" button and the add-console form. Opening, the
## 330 × 46 px button turns into the form's focus card on its first field (the satin card with its gel ring): the card
## flies there as the form comes in over the consoles, which stay under it. Closing, the card flies back into the closed
## ball and turns into it. The rail, the frame, the pool and the hints are the carousel's: it plays them beside this.

## The button the ball opens into, and the ball it closes into (px of the design's frame): the card's two ends on the
## consoles screen. The form's first field is its other end ([constant FIELD]).
const BUTTON := Vector2(330.0, 46.0)
const BALL := StudioTokens.PLUS
## The form's first field, "01 Type": 41 / 16 cqw, 56 × 6.4 cqw.
const FIELD := Rect2(524.8, 204.8, 716.8, 81.92)
## Opening: the card flies in this time (seconds), fading in over the second and the form coming in at the third.
static var OPEN_S: float:
	get: return StudioTokens.TR_FORM_OPEN_S
const CARD_IN_S := 0.21
static var FORM_AT_S: float:
	get: return StudioTokens.TR_FORM_AT_S
## Closing: the card flies in this time, fading out in the second, the ball coming back after the third.
static var CLOSE_S: float:
	get: return StudioTokens.TR_FORM_BACK_S
static var CARD_OUT_S: float:
	get: return StudioTokens.TR_FORM_OUT_S
const BALL_AT_S := 0.18

var _card := FormPaint.Card.new()
var _flight: Tween
## How far the card has flown from its start to its end, 0 to 1, and where each is.
var _flown := 0.0:
	set(value):
		_flown = value
		_place()
var _from := Rect2()
var _to := Rect2()
var _radii := Vector2.ZERO


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_card.hide()
	add_child(_card)


## The button turns into the form's first field, from the ball [param ball] (open) as it stands; returns the flight.
func open(ball: AddBall) -> Tween:
	var centre := ball.get_global_rect().get_center()
	return _fly(Rect2(centre - BUTTON / 2.0, BUTTON), BUTTON.y / 2.0, FIELD, StudioTokens.FOCUS_RADIUS, OPEN_S, 0.0,
		CARD_IN_S, 0.0, 1.0, StudioTokens.TR_FORM_OPEN_S_CURVE)


## The card leaves the form's first field for the ball [param ball] (closed); returns the flight.
func close(ball: AddBall) -> Tween:
	var centre := ball.get_global_rect().get_center()
	return _fly(FIELD, StudioTokens.FOCUS_RADIUS, Rect2(centre - BALL.size / 2.0, BALL.size), BALL.size.y / 2.0, CLOSE_S,
		0.0, CARD_OUT_S, 1.0, 0.0, StudioTokens.TR_FORM_BACK_S_CURVE)


## The card flies from [param from] to [param to] in [param seconds], its look going from [param alpha_from] to
## [param alpha_to] in [param fade_s]; gone once it has landed.
func _fly(from: Rect2, from_radius: float, to: Rect2, to_radius: float, seconds: float, delay_s: float, fade_s: float,
		alpha_from: float, alpha_to: float, curve: Motion.Easing) -> Tween:
	if _flight:
		if _flight.is_running() and StudioTokens.TR_REVERSE:
			from = Rect2(_card.position, _card.size)
			from_radius = _card.radius
			alpha_from = _card.modulate.a
			seconds *= clampf(_flown, 0.001, 1.0)
		_flight.kill()
	_from = from
	_to = to
	_radii = Vector2(from_radius, to_radius)
	_card.modulate.a = alpha_from
	_flown = 0.0
	_card.show()
	_flight = create_tween().set_parallel()
	_flight.tween_property(self, ^"_flown", 1.0, seconds).set_delay(delay_s).set_custom_interpolator(
		Motion.curve(curve))
	_flight.tween_property(_card, ^"modulate:a", alpha_to, fade_s).set_delay(delay_s)
	_flight.chain().tween_callback(_card.hide)
	return _flight


func _place() -> void:
	_card.position = _from.position.lerp(_to.position, _flown)
	_card.size = _from.size.lerp(_to.size, _flown)
	_card.radius = lerpf(_radii.x, _radii.y, _flown)
