# SPDX-License-Identifier: GPL-3.0-or-later
class_name SearchModel
extends RefCounted
## What the search ribbon ([GameSearch]) is on and what it finds, with no node: the index by letter or by region, the
## keys typed, the cursor, and what each press does to them. A press changes the model at once and answers what the
## ribbon then does, in order ([Effect]); nothing when the press leads nowhere. The shelf's views are asked for
## through the [Callable] it is made with, as a press needs them; the row's selected index is given with each press,
## as it was before it.

## What the ribbon does after a press: plays a sound, or a search's sound gliding from the games shown before to
## those found; shows games on the row; jumps the row to one; closes.
enum Kind { SOUND, NARROWING, SHOW, JUMP, CLOSED }

## The ribbon's keys, as the core reads them.
const KEYS := "abcdefghijklmnopqrstuvwxyz0123456789 "
const SPACE := " "
## The actions the ribbon takes while open, the first one an event presses being the one taken.
const PRESSES: Array[StringName] = [&"ui_accept", &"screen_back", &"ui_up", &"form_submit", &"ui_down",
	&"previous_letter", &"next_letter", &"open_settings"]

var open := false
var by_region := false
## What is typed, as the core reads it: lowercase letters, digits and spaces. Nothing by region.
var typed := ""
## The key (or, by region, the group) the cursor is on.
var cursor := 0
## What the row shows: the index by title, the index by region or the games found.
var view := AndroidServices.Browse.new({})
## Asks for a view of the shelf searched, as [method AndroidServices.browse] takes its order and what is typed.
var _browse: Callable
## The index by title, asked for once per shelf.
var _letters := AndroidServices.Browse.new({})
var _shelf_size := 0
## Shelf positions of the game shown when the ribbon opened, and when the first key was typed.
var _before := 0
var _home := 0


func _init(asks: Callable) -> void:
	_browse = asks


## Searches a shelf of [param size] games from now on: nothing typed, the ribbon closed.
func use_shelf(size: int) -> void:
	_shelf_size = size
	_letters = AndroidServices.Browse.new({})
	view = _letters
	typed = ""
	by_region = false
	open = false


## Whether what the row shows is not the whole shelf in title order, the ribbon open or not.
func is_filtered() -> bool:
	return not typed.is_empty() or by_region


## The shelf position of the game at [param row_index] of what the row shows.
func shown_position(row_index: int) -> int:
	if by_region:
		return view.games[view.groups[cursor].start + row_index]
	return view.games[row_index] if is_filtered() else row_index


## How many games the row shows.
func found() -> int:
	return _region_end() - view.groups[cursor].start if by_region else view.games.size()


## Whether [param key] leads somewhere: typed, it would still find a game.
func is_lit(key: String) -> bool:
	return key in view.keys


## Opens the ribbon: on the letter of the game shown, at [param row_index], or as it was left with what it found.
func open_at(row_index: int) -> void:
	open = true
	if not is_filtered():
		_before = row_index
		var letters := _letters_view()
		# The index of another library (asked for as it was being changed) lights no key.
		view = letters if _usable(letters) else AndroidServices.Browse.new({})
		cursor = _nearest_lit(_letter_key(row_index))


## Closes the ribbon; keeping what it found and where the row is when [param keep], else back on the whole shelf, on
## the game shown when it opened.
func close(keep: bool) -> Array[Effect]:
	var effects: Array[Effect] = [Effect.sound(SoundEffects.Cue.BACK)]
	open = false
	if not keep:
		effects.append_array(_show_shelf(_before))
	effects.append(Effect.closed(keep))
	return effects


## Back to the whole shelf in title order, on the game shown when the first key was typed (or, by region, the one
## shown, at [param row_index]).
func clear(row_index: int) -> Array[Effect]:
	return _show_shelf(_home if not typed.is_empty() else shown_position(row_index))


## What [param action], one of [constant PRESSES], does while the ribbon is open: A types the cursor's key (or, by
## region, closes keeping the region), B erases a key or closes, up and Start close keeping what is found, down
## switches index with nothing typed, L1 and R1 leap, Y types a space.
func press(action: StringName, row_index: int) -> Array[Effect]:
	match action:
		&"ui_accept":
			return close(true) if by_region else _type(KEYS[cursor], row_index)
		&"screen_back":
			return _back(row_index)
		&"ui_up", &"form_submit":
			return close(true)
		&"ui_down" when typed.is_empty():
			return _switch_index(row_index)
		&"previous_letter":
			return _leap(-1)
		&"next_letter":
			return _leap(1)
		&"open_settings" when not by_region:
			return _type(SPACE, row_index)
	return []


## The cursor to the next key (or region) that leads somewhere towards [param direction], heard as [param cue]; with
## nothing typed, the row jumps there.
func move(direction: int, cue := SoundEffects.Cue.MOVE) -> Array[Effect]:
	var effects: Array[Effect] = [Effect.sound(cue)]
	var count := view.groups.size() if by_region else KEYS.length()
	for step in range(1, count + 1):
		var next := posmod(cursor + direction * step, count)
		if by_region or is_lit(KEYS[next]):
			cursor = next
			break
	if by_region:
		effects.append(_region_shown(0))
	elif typed.is_empty() and is_lit(KEYS[cursor]):
		effects.append(Effect.jump(view.keys[KEYS[cursor]], direction))
	return effects


## The [param key]-th key tapped: typed, or on the regions, jumped to.
func tap(key: int, row_index: int) -> Array[Effect]:
	if by_region:
		cursor = key
		return [_region_shown(0)]
	if not is_lit(KEYS[key]):
		return []
	cursor = key
	return _type(KEYS[key], row_index)


func _type(key: String, row_index: int) -> Array[Effect]:
	if not is_lit(key):
		return []
	return _find(typed + key, row_index)


func _back(row_index: int) -> Array[Effect]:
	if by_region or typed.is_empty():
		return close(false)
	# Back on the key erased, as if it were about to be typed again.
	if typed.length() > 1:
		return _find(typed.left(-1), row_index, KEYS.find(typed[-1]))
	cursor = KEYS.find(typed[-1])
	var effects: Array[Effect] = [Effect.narrowing(SoundEffects.Cue.ERASE, view.games.size(), _shelf_size)]
	effects.append_array(_show_shelf(_home))
	return effects


## The games found for [param search], the row on the game shown if it is one of them, else on the first after it on
## the shelf, the cursor on the key nearest [param near] that still leads somewhere. Nothing changes for an answer
## that is not the shelf's.
func _find(search: String, row_index: int, near := cursor) -> Array[Effect]:
	var answer: AndroidServices.Browse = _browse.call(&"title", search)
	if not _usable(answer):
		return []
	var anchor := shown_position(row_index)
	if typed.is_empty():
		_home = anchor
	var effects: Array[Effect] = [Effect.narrowing(
		SoundEffects.Cue.TYPE if search.length() > typed.length() else SoundEffects.Cue.ERASE,
		view.games.size() if not typed.is_empty() else _shelf_size, answer.games.size())]
	typed = search
	effects.append_array(_show(answer, anchor, search))
	cursor = _nearest_lit(near)
	return effects


## Down with nothing typed: from the letters to the regions, and back.
func _switch_index(row_index: int) -> Array[Effect]:
	var index: AndroidServices.Browse = _letters_view() if by_region else _browse.call(&"region", "")
	if not _usable(index):
		return []
	var anchor := shown_position(row_index)
	by_region = not by_region
	var effects: Array[Effect] = [Effect.sound(SoundEffects.Cue.REGIONS if by_region else SoundEffects.Cue.LETTERS)]
	if by_region:
		view = index
		var at := maxi(index.games.find(anchor), 0)
		cursor = _group_at(at, index.groups)
		effects.append(_region_shown(at - index.groups[cursor].start))
	else:
		effects.append_array(_show(index, anchor))
		# The index by title is the shelf in its order: the row's index is the shelf position.
		cursor = _nearest_lit(_letter_key(effects[-1].at))
	return effects


## L1 ([param direction] -1) or R1 (1): to the previous or next letter of the index, or once keys are typed to the
## previous or next key that still finds a game, told by the last word typed and that key.
func _leap(direction: int) -> Array[Effect]:
	if typed.is_empty():
		return move(direction, SoundEffects.Cue.LETTER)
	var word := typed.get_slice(SPACE, typed.get_slice_count(SPACE) - 1)
	# Every key but the space.
	var letters := KEYS.length() - 1
	for step in range(1, letters + 1):
		var key := posmod(cursor + direction * step, letters)
		if is_lit(KEYS[key]):
			var at := view.keys[KEYS[key]]
			if at < 0:
				return []
			cursor = key
			return [Effect.sound(SoundEffects.Cue.LETTER), Effect.jump(at, direction, (word + KEYS[key]).to_upper())]
	return []


## The games of the region the cursor is on alone, on the [param at]-th of them.
func _region_shown(at: int) -> Effect:
	return Effect.show(view.games.slice(view.groups[cursor].start, _region_end()), at)


## Where the region the cursor is on ends in the index by region.
func _region_end() -> int:
	return view.groups[cursor + 1].start if cursor + 1 < view.groups.size() else view.games.size()


## Shows [param shown] on the row, on the game at shelf position [param anchor] if it shows it, else on the first one
## after it, else the last, traced as the games found for [param search] when it is given; nothing for a view that
## is not the shelf's.
func _show(shown: AndroidServices.Browse, anchor: int, search := "") -> Array[Effect]:
	if not _usable(shown):
		return []
	view = shown
	var at := shown.games.find(anchor)
	if at < 0:
		at = mini(shown.games.bsearch(anchor), shown.games.size() - 1)
	return [Effect.show(shown.games, at, search)]


## The whole shelf in title order again, nothing typed, on the game at shelf position [param anchor].
func _show_shelf(anchor: int) -> Array[Effect]:
	typed = ""
	by_region = false
	return _show(_letters_view(), anchor)


## Whether [param shown] is for the shelf searched and shows a game: a view of another library (asked for as it was
## being changed) is set aside.
func _usable(shown: AndroidServices.Browse) -> bool:
	return shown.count == _shelf_size and not shown.games.is_empty()


## The index by title, asked for once per shelf (until the answer is for it).
func _letters_view() -> AndroidServices.Browse:
	if not _usable(_letters):
		_letters = _browse.call(&"title", "")
	return _letters


## The index in [param groups] of the group holding row index [param at].
func _group_at(at: int, groups: Array[AndroidServices.Group]) -> int:
	var holding := 0
	for i in groups.size():
		if groups[i].start <= at:
			holding = i
	return holding


## The key of the letter of the game at shelf position [param position]: its own, or the first digit for `#`.
func _letter_key(position: int) -> int:
	var groups := _letters_view().groups
	if groups.is_empty():
		return 0
	var label := groups[_group_at(position, groups)].label.to_lower()
	return KEYS.find("0") if label == "#" else maxi(0, KEYS.find(label))


## [param key] if it leads somewhere, else the nearest key that does, the next one first.
func _nearest_lit(key: int) -> int:
	for step in KEYS.length():
		for at: int in [key + step, key - step]:
			if at >= 0 and at < KEYS.length() and is_lit(KEYS[at]):
				return at
	return key


## One thing the ribbon does after a press. Each [enum Kind] reads its own members: a sound its [member cue], a
## search's sound also how many games were shown [member before] it and are [member found]; a show the shelf positions
## of [member games], the row on the [member at]-th, and the search they were found for as [member text], to trace; a
## jump the row's index [member at], its [member direction] and what the big letter tells as [member text], if
## anything; the closing whether to [member keep] what was found.
class Effect:
	var kind: Kind
	var cue: SoundEffects.Cue
	var before := 0
	var found := 0
	var games: PackedInt32Array
	var at := 0
	var direction := 0
	var text := ""
	var keep := false

	func _init(of: Kind) -> void:
		kind = of

	static func sound(played: SoundEffects.Cue) -> Effect:
		var effect := Effect.new(Kind.SOUND)
		effect.cue = played
		return effect

	static func narrowing(played: SoundEffects.Cue, shown_before: int, found_now: int) -> Effect:
		var effect := Effect.new(Kind.NARROWING)
		effect.cue = played
		effect.before = shown_before
		effect.found = found_now
		return effect

	static func show(positions: PackedInt32Array, selected: int, search := "") -> Effect:
		var effect := Effect.new(Kind.SHOW)
		effect.games = positions
		effect.at = selected
		effect.text = search
		return effect

	static func jump(index: int, towards: int, told := "") -> Effect:
		var effect := Effect.new(Kind.JUMP)
		effect.at = index
		effect.direction = towards
		effect.text = told
		return effect

	static func closed(keeping: bool) -> Effect:
		var effect := Effect.new(Kind.CLOSED)
		effect.keep = keeping
		return effect
