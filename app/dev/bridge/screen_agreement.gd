# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## Whether what the carousel shows agrees with the screen it is on, once it stands still: the consoles in front on the
## consoles' side, behind on the games' side; the rail, on its ground, and the console's name on the consoles screen
## only; the games' logo, title pill and hints (but under the search ribbon) on the games screen only. The INV-20 walk
## asserts it after every step, and the bridge's `state` tells it, so `verify` reads the same rule.

## The parts only the games screen shows; the others of [method shown] only the consoles screen.
const _GAMES_PARTS: Array[String] = ["games_logo", "title_pill", "games_hints"]
const _PARTS: Array[String] = ["rail", "console_title", "games_logo", "title_pill", "games_hints"]


## The parts each screen owns, as the carousel shows them now, and whether it stands still: no screen in front, no
## move, launch or toss under way.
static func shown(carousel: Carousel) -> Dictionary:
	var rail := carousel._rail
	var screen := carousel.screen()
	return {
		"still": not carousel._screens.is_visible_in_tree() and carousel._shown and not (carousel._toss.is_busy()
			or carousel._game_launch.is_busy() or carousel._sequence.is_processing())
			and screen not in [Carousel.Screen.ENTERING, Carousel.Screen.LEAVING],
		"consoles": "behind" if carousel._consoles.behind else "front",
		"consoles_behind_drawn": carousel._sequence.behind_amount,
		"rail": rail.is_visible_in_tree() and rail.sunk == 0.0 and rail.ground_alpha == 1.0,
		"console_title": _shows(carousel._console_title),
		"games_logo": _shows(carousel._games_logo),
		"title_pill": _shows(carousel._pill),
		"games_hints": _shows(carousel._games_hints),
		"ribbon_open": carousel._search.is_open(),
	}


## What [param carousel] shows that its screen does not have, empty when they agree or while it does not stand still.
static func disagreement(carousel: Carousel) -> String:
	var parts := shown(carousel)
	if not parts["still"]:
		return ""
	var screen := carousel.screen()
	var games := screen in [Carousel.Screen.GAMES, Carousel.Screen.PROPERTIES]
	var wrong: Array[String] = []
	if (parts["consoles"] == "behind") != games:
		wrong.append("the consoles %s" % parts["consoles"])
	if screen in [Carousel.Screen.CONSOLES, Carousel.Screen.GAMES]:
		for part in _PARTS:
			var shows: bool = parts[part] or (part == "games_hints" and parts["ribbon_open"])
			if shows != (games == (part in _GAMES_PARTS)):
				wrong.append("the %s %s" % [part.replace("_", " "), "shown" if shows else "hidden"])
	return "" if wrong.is_empty() else "%s: %s" % [Carousel.Screen.keys()[screen], ", ".join(wrong)]


static func _shows(item: CanvasItem) -> bool:
	if not item.is_visible_in_tree():
		return false
	var node: Node = item
	while node is CanvasItem:
		if (node as CanvasItem).modulate.a <= 0.0 or (node as CanvasItem).self_modulate.a <= 0.0:
			return false
		node = node.get_parent()
	return true
