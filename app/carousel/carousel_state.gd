# SPDX-License-Identifier: GPL-3.0-or-later
class_name CarouselState
extends RefCounted
## What the carousel does on each of its screens, as tables and pure functions: nothing here reads a node.
## [Carousel] keeps its screen and who holds the presses, reads what is under way from the parts that own it
## ([method busy]) and asks here what it takes now ([method takes]), what stands in front on its screen
## ([method front]), which screen may follow ([method follows]) and what a press means ([method command]).

## What stands in front on a screen: the consoles, the games (the consoles behind them), neither while the animation
## into or out of a console plays, or the ring putting the consoles in order.
enum Front { CONSOLES, GAMES, MOVING, RING }
## What is under way, each told by the part that owns it. Several can be at once (a row still gliding under a
## launch): flags, added up.
enum Busy { LAUNCHING = 1, TOSSING = 2, SEARCHING = 4, ROW_GLIDING = 8, CONSOLES_GLIDING = 16 }
## What the carousel takes: the pad's presses, a finger, a library read again, the right stick turning the selected
## console, the pick's labels to read as the games row rests, the shelf of the console stepped to, a rest.
enum Take { PRESS = 1, FINGER = 2, LIBRARY = 4, CONSOLE_STICK = 8, PICK = 16, SHELF = 32, REST = 64 }
## What [method command] needs to know besides the screen and the event: the row has games, the search ribbon is
## open, the row shows a part of its shelf, the event pressed or released a direction, that direction is held, up is
## held (the stick or the D-pad), the "+" ball is open, there are several consoles.
enum Fact { HAS_GAMES = 1, RIBBON_OPEN = 2, FILTERED = 4, MOVED = 8, HELD = 16, UP_HELD = 32, BALL_OPEN = 64, SEVERAL = 128 }
## What a press means on the carousel.
enum Command {
	NONE, TO_SEARCH, SETTINGS, STEP_CONSOLE, OPEN_BALL, CLOSE_BALL, EDIT_CONSOLE, ORDER, ADD_CONSOLE, ENTER,
	HOLD_ROW, RELEASE_ROW, LAUNCH, TOSS, OPEN_SEARCH, CLEAR_FILTER, LEAVE, PROPERTIES,
}

## A game launched or in the air.
const FLYING := Busy.LAUNCHING | Busy.TOSSING
const _FRONT: Dictionary[Carousel.Screen, Front] = {
	Carousel.Screen.CONSOLES: Front.CONSOLES,
	Carousel.Screen.ENTERING: Front.MOVING,
	Carousel.Screen.GAMES: Front.GAMES,
	Carousel.Screen.LEAVING: Front.MOVING,
	Carousel.Screen.PROPERTIES: Front.GAMES,
	Carousel.Screen.CONSOLE_EDIT: Front.CONSOLES,
	Carousel.Screen.ORDER: Front.RING,
}
## Per screen, what the carousel takes itself. Elsewhere the properties (but for the finger turning the game), the edit
## form or the ring read the presses, or the animation into or out of a console plays.
const _TAKES: Dictionary[Carousel.Screen, int] = {
	Carousel.Screen.CONSOLES: Take.PRESS | Take.FINGER | Take.LIBRARY | Take.CONSOLE_STICK | Take.SHELF | Take.REST,
	Carousel.Screen.ENTERING: 0,
	Carousel.Screen.GAMES: Take.PRESS | Take.FINGER | Take.LIBRARY | Take.PICK | Take.REST,
	Carousel.Screen.LEAVING: 0,
	Carousel.Screen.PROPERTIES: Take.FINGER | Take.REST,
	Carousel.Screen.CONSOLE_EDIT: Take.CONSOLE_STICK | Take.REST,
	Carousel.Screen.ORDER: Take.REST,
}
## What is taken whoever holds the presses, and what also is while the carousel holds them.
const _WHOEVER := Take.SHELF | Take.REST
const _HOLDING := _WHOEVER | Take.CONSOLE_STICK | Take.PICK | Take.PRESS | Take.FINGER | Take.LIBRARY
const _LETS: Dictionary[Carousel.Holder, int] = {
	Carousel.Holder.FLOW: _WHOEVER,
	Carousel.Holder.CAROUSEL: _HOLDING,
	Carousel.Holder.FORM_ASKED: _WHOEVER,
	Carousel.Holder.FORM_COMING: _WHOEVER,
	Carousel.Holder.FORM_COVERING: _WHOEVER,
	Carousel.Holder.FORM_GIVEN_UP: _WHOEVER,
}
## What stops each take while it is under way.
const _STOPPED_BY: Dictionary[Take, int] = {
	Take.PRESS: FLYING,
	Take.FINGER: FLYING | Busy.SEARCHING,
	Take.LIBRARY: FLYING | Busy.SEARCHING | Busy.ROW_GLIDING | Busy.CONSOLES_GLIDING,
	Take.CONSOLE_STICK: 0,
	Take.PICK: Busy.TOSSING | Busy.SEARCHING | Busy.ROW_GLIDING,
	Take.SHELF: Busy.CONSOLES_GLIDING,
	Take.REST: FLYING,
}
## The screens that may follow each screen: [method Carousel._go] goes nowhere else.
const _NEXT: Dictionary[Carousel.Screen, Array] = {
	Carousel.Screen.CONSOLES: [Carousel.Screen.ENTERING, Carousel.Screen.CONSOLE_EDIT, Carousel.Screen.ORDER],
	Carousel.Screen.ENTERING: [Carousel.Screen.GAMES],
	Carousel.Screen.GAMES: [Carousel.Screen.LEAVING, Carousel.Screen.PROPERTIES, Carousel.Screen.CONSOLES],
	Carousel.Screen.LEAVING: [Carousel.Screen.CONSOLES],
	Carousel.Screen.PROPERTIES: [Carousel.Screen.GAMES],
	Carousel.Screen.CONSOLE_EDIT: [Carousel.Screen.CONSOLES],
	Carousel.Screen.ORDER: [Carousel.Screen.CONSOLES],
}


## What is under way, as flags of [enum Busy]: a launch, a toss, the search ribbon open, the games row gliding, the
## consoles gliding.
static func busy(launching: bool, tossing: bool, searching: bool, row_gliding: bool, consoles_gliding: bool) -> int:
	return int(launching) * Busy.LAUNCHING | int(tossing) * Busy.TOSSING | int(searching) * Busy.SEARCHING \
		| int(row_gliding) * Busy.ROW_GLIDING | int(consoles_gliding) * Busy.CONSOLES_GLIDING


## What [method command] needs to know, as flags of [enum Fact], in its order.
static func facts(has_games: bool, ribbon_open: bool, filtered: bool, moved: bool, held: bool, up_held: bool,
		ball_open: bool, several: bool) -> int:
	return int(has_games) * Fact.HAS_GAMES | int(ribbon_open) * Fact.RIBBON_OPEN | int(filtered) * Fact.FILTERED \
		| int(moved) * Fact.MOVED | int(held) * Fact.HELD | int(up_held) * Fact.UP_HELD \
		| int(ball_open) * Fact.BALL_OPEN | int(several) * Fact.SEVERAL


## What the carousel takes on [param screen] while [param holder] holds the presses and [param under_way] goes on, as
## flags of [enum Take].
static func takes(screen: Carousel.Screen, holder: Carousel.Holder, under_way: int) -> int:
	var taken := _TAKES[screen] & _LETS[holder]
	if under_way != 0:
		for take: Take in _STOPPED_BY:
			if (under_way & _STOPPED_BY[take]) != 0:
				taken &= ~take
	return taken


## What stands in front on [param screen].
static func front(screen: Carousel.Screen) -> Front:
	return _FRONT[screen]


## Whether the carousel shows under [param holder], nothing of the screens flow in front of it.
static func shows(holder: Carousel.Holder) -> bool:
	return holder == Carousel.Holder.CAROUSEL


## Whether [param screen_to] may follow [param screen_from].
static func follows(screen_from: Carousel.Screen, screen_to: Carousel.Screen) -> bool:
	return screen_to in _NEXT[screen_from]


## What [param event] means on [param screen], the carousel taking [param taken] ([method takes]) and knowing
## [param known] ([method facts]). Nothing for an echo, nor while the carousel takes no press (the screens in front,
## a launch until the carousel shows again after the game, the animation into or out of a console, the properties,
## which take their own), nor with no game; every event is the search ribbon's while it is open; then the first
## that matches, in the order written.
static func command(screen: Carousel.Screen, taken: int, known: int, event: InputEvent) -> Command:
	if event.is_echo() or (taken & Take.PRESS) == 0 or (known & Fact.HAS_GAMES) == 0:
		return Command.NONE
	if screen == Carousel.Screen.GAMES and (known & Fact.RIBBON_OPEN) != 0:
		return Command.TO_SEARCH
	if screen in [Carousel.Screen.CONSOLES, Carousel.Screen.GAMES] and event.is_action_pressed(&"open_settings"):
		return Command.SETTINGS
	if screen == Carousel.Screen.CONSOLES:
		return _on_consoles(known, event)
	if screen == Carousel.Screen.GAMES:
		return _on_games(known, event)
	return Command.NONE


static func _on_consoles(known: int, event: InputEvent) -> Command:
	if (known & Fact.MOVED) != 0 and (known & Fact.HELD) != 0:
		return Command.STEP_CONSOLE
	# Up as the stick and the D-pad hold it together: either one held keeps the button.
	if event.is_action(&"ui_up"):
		return Command.OPEN_BALL if (known & Fact.UP_HELD) != 0 else Command.CLOSE_BALL
	if event.is_action_pressed(&"open_properties"):
		return Command.EDIT_CONSOLE
	if event.is_action_pressed(&"ui_down") and (known & Fact.SEVERAL) != 0:
		return Command.ORDER
	if event.is_action_pressed(&"ui_accept"):
		return Command.ADD_CONSOLE if (known & Fact.BALL_OPEN) != 0 else Command.ENTER
	return Command.NONE


static func _on_games(known: int, event: InputEvent) -> Command:
	if (known & Fact.MOVED) != 0:
		return Command.HOLD_ROW if (known & Fact.HELD) != 0 else Command.RELEASE_ROW
	if event.is_action_pressed(&"ui_accept"):
		return Command.LAUNCH
	if event.is_action_pressed(&"ui_up"):
		return Command.TOSS
	if event.is_action_pressed(&"ui_down"):
		return Command.OPEN_SEARCH
	if event.is_action_pressed(&"screen_back"):
		return Command.CLEAR_FILTER if (known & Fact.FILTERED) != 0 else Command.LEAVE
	if event.is_action_pressed(&"open_properties"):
		return Command.PROPERTIES
	return Command.NONE
