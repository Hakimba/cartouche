# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselTouch
extends RefCounted
## The carousel by touch ([Finger]): on the consoles screen, a tap on the console in the middle or on the rail's
## middle tile goes into it, one beside it moves one console that way, another tile moves that many, a long press on
## it opens its properties, and a swipe anywhere moves one console; on the games screen, a tap beside the game in the
## middle moves one game, a long press on it opens its properties, a swipe beside it moves one game, however long or
## fast, a drag on it turns it, and nothing launches but A. A drag over the properties turns what they stage.

## A tap on the console in the middle, or on the middle tile: the carousel goes into it.
signal entered
## A long press on the console or the game in the middle.
signal long_pressed
## The finger was lifted, or taken back by the system: what it turned comes back to the front.
signal lifted

## How near the console or the game in the middle a finger comes down to be on it, and how far it swipes to move
## one, in pixels.
const _ON_SELECTED_PX := 270.0
const _SWIPE_PX := 80.0

var _consoles: ConsoleRow
var _row: ShelfRow
var _rail: ConsoleRail
var _add_ball: AddBall
var _finger := Finger.new()
var _on_selected := false
var _swiped := false


func _init(consoles: ConsoleRow, row: ShelfRow, rail: ConsoleRail, add_ball: AddBall) -> void:
	_consoles = consoles
	_row = row
	_rail = rail
	_add_ball = add_ball


## Acts on [param event], read at [param now_ms] on [param screen], the console or the game in the middle resting at
## [param selected]; only the lift counts while the carousel is not [param touchable].
func read(event: InputEvent, now_ms: int, screen: Carousel.Screen, touchable: bool, selected: Vector2) -> void:
	var gesture := _finger.read(event, now_ms)
	if gesture == Finger.Gesture.DOWN:
		_on_selected = touchable and selected.distance_to(_finger.start) <= _ON_SELECTED_PX
		_swiped = false
	elif not _finger.is_down:
		lifted.emit()
	if not touchable:
		return
	match gesture:
		Finger.Gesture.TAP:
			_tap(screen, selected)
		Finger.Gesture.DRAG:
			_drag(screen)


## A finger held still on the console or the game in the middle becomes a long press, at [param now_ms], while
## [param touchable] says so: asked only with a finger there, as it runs every frame.
func hold(now_ms: int, touchable: Callable) -> void:
	if _on_selected and touchable.call() and _finger.held(now_ms):
		long_pressed.emit()


## Forgets the finger, as if lifted: a screen changing under it leaves nothing pending.
func forget() -> void:
	if _finger.is_down:
		_finger = Finger.new()


func _tap(screen: Carousel.Screen, selected: Vector2) -> void:
	if screen == Carousel.Screen.CONSOLES and _on_selected:
		Diagnostics.trace("touch", "tap on the console")
		_add_ball.close(false)
		entered.emit()
	elif screen == Carousel.Screen.CONSOLES and _rail.slot_under(_finger.at) == 0:
		Diagnostics.trace("touch", "tap on the middle tile")
		_add_ball.close(false)
		entered.emit()
	elif screen == Carousel.Screen.CONSOLES and _rail.slot_under(_finger.at) != ConsoleRail.NO_TILE:
		_add_ball.close()
		var places := _rail.slot_under(_finger.at)
		Diagnostics.trace("touch", "tap on the tile %d places away" % places)
		_consoles.step(signi(places), absi(places))
	elif screen in [Carousel.Screen.CONSOLES, Carousel.Screen.GAMES] and not _on_selected:
		_step_beside(screen, 1 if _finger.at.x > selected.x else -1)


## Over the properties, or on the game in the middle, a drag turns what they stage or that game; anywhere else (on
## the consoles screen, even on the console, so that a swipe there is never mistaken for a turn), once swiped far
## enough, it moves one console or game, the way the finger goes, and no more until it is lifted.
func _drag(screen: Carousel.Screen) -> void:
	if screen == Carousel.Screen.CONSOLE_PROPERTIES:
		_consoles.touch_turn(_finger.moved)
		return
	if screen == Carousel.Screen.PROPERTIES or (screen == Carousel.Screen.GAMES and _on_selected):
		_row.touch_turn(_finger.moved)
		return
	var swipe := _finger.start.x - _finger.at.x
	if _swiped or absf(swipe) < _SWIPE_PX:
		return
	_swiped = true
	var towards := 1 if swipe > 0.0 else -1
	Diagnostics.trace("touch", "swiped %d" % towards)
	_step_beside(screen, towards)


func _step_beside(screen: Carousel.Screen, towards: int) -> void:
	if screen == Carousel.Screen.CONSOLES:
		_add_ball.close()
		_consoles.step(towards)
	else:
		_row.step(towards)
