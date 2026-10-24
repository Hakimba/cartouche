# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameSearch
extends Control
## The ribbon that searches the games screen's shelf. Down opens it under the carousel: keys A to
## Z, 0 to 9 and a space. Until a key is typed it is an index: left and right go from letter to
## letter, the carousel jumping to its first game behind; down again, from region to region, the
## shelf by region. A types the key, and the carousel keeps only the games found (the core's
## `Finder`: each word typed starts another word of the title, in any order); keys that would find
## nothing are dimmed and skipped. L1 and R1 go to the previous or next letter, or once keys are
## typed to the previous or next key that still finds a game, the carousel on the first game it
## finds; a big letter tells where. B erases a key, then closes the ribbon, back on the game shown
## before; up or Start close it keeping what is found, told at the top, which B on the games screen
## clears. A key tapped is typed.
##
## The carousel hands its presses over while the ribbon is open ([method take]), and L1, R1 and B
## while what is found is kept ([method leap], [method clear]).

## The ribbon opened or closed: the carousel makes room for it.
signal opened(open: bool)
## What the carousel shows changed: its title's marks and the hints follow.
signal changed

## The ribbon's keys, as the core reads them.
const KEYS := "abcdefghijklmnopqrstuvwxyz0123456789 "
const SPACE := " "
## The ribbon rises from this far below in this time.
const RISE_S := 0.18
const _RISE_PX := 140.0
## A jump of the index, or of L1 and R1 once keys are typed, slides the carousel in from this many
## places; a jump of L1 or R1 from letter to letter, from these.
const _INDEX_SLIDE := 0.6
const _LEAP_SLIDE := 0.5
## The big letter shows this long, then fades in this time; longer than two characters, it is smaller.
const _BIG_S := 0.7
const _BIG_FADE_S := 0.12
const _BIG_LONG_SCALE := 0.42

var android: AndroidServices = Android
## The carousel's row, which shows what is found.
var row: ShelfRow

var _platform_id := ""
var _shelf: Array[AndroidServices.Game] = []
## What the row shows, and the index by title, asked for once per shelf.
var _view := AndroidServices.Browse.new({})
var _letters := AndroidServices.Browse.new({})
var _open := false
var _by_region := false
var _typed := ""
## The key (or, by region, the group) the ribbon's cursor is on.
var _cursor := 0
## Shelf positions of the game shown when the ribbon opened, and when the first key was typed.
var _before := 0
var _home := 0
var _held := 0
var _held_steps := 0
var _next_repeat_s := 0.0
var _clock_s := 0.0
var _rise: Tween
var _big_fade: Tween
## The ribbon's hints shown, as (button, text).
var _hints_shown: Array[PackedStringArray] = []

@onready var _ribbon: Control = %Ribbon
@onready var _window: Control = %Window
@onready var _strip: HBoxContainer = %Strip
@onready var _chip: Control = %Chip
@onready var _typed_text: Label = %Typed
@onready var _count: Label = %Count
@onready var _big: Control = %Big
@onready var _big_text: Label = %BigText
@onready var _filter: Control = %Filter
@onready var _filter_text: Label = %FilterText
@onready var _hints: HintRow = %Hints
@onready var _ribbon_y := _ribbon.position.y
@onready var _big_size := _big_text.get_theme_font_size(&"font_size")


func _ready() -> void:
	_strip.sort_children.connect(_centre_strip)
	_ribbon.hide()
	_ribbon.position.y = _ribbon_y + _RISE_PX
	_ribbon.modulate.a = 0.0
	_big.modulate.a = 0.0
	set_process(false)


# Runs while a direction is held on the ribbon: its cursor goes on, faster and faster.
func _process(delta: float) -> void:
	_clock_s += delta
	if _clock_s >= _next_repeat_s:
		_move(_held)
		_held_steps += 1
		_next_repeat_s = _clock_s + CarouselLayout.repeat_delay(_held_steps)


## Searches [param games], [param platform_id]'s shelf in its order, from now on: nothing typed,
## the ribbon closed.
func use_shelf(platform_id: String, games: Array[AndroidServices.Game]) -> void:
	_platform_id = platform_id
	_shelf = games
	_letters = AndroidServices.Browse.new({})
	_view = _letters
	_typed = ""
	_by_region = false
	if _open:
		_open = false
		opened.emit(false)
	let_go()
	_ribbon.hide()
	_refresh()


func is_open() -> bool:
	return _open


## Whether what the row shows is not the whole shelf in title order, the ribbon open or not.
func is_filtered() -> bool:
	return not _typed.is_empty() or _by_region


## What is typed, as the core reads it: lowercase letters, digits and spaces.
func typed() -> String:
	return _typed


## The shelf position of the game the row shows, whatever it shows.
func shown_position() -> int:
	return _view.games[row.selected_index()] if is_filtered() else row.selected_index()


## Where the words typed are in the shown game's title, as (start, length) in characters.
func marks() -> Array[Vector2i]:
	if _typed.is_empty():
		return []
	return android.title_marks(_platform_id, shown_position(), _typed)


## Forgets a direction held on the ribbon: a screen opening over it leaves nothing pending.
func let_go() -> void:
	_held = 0
	set_process(false)


## Opens the ribbon: on the letter of the game shown, or as it was left with what is typed.
func open() -> void:
	_open = true
	if not is_filtered():
		_before = row.selected_index()
		_view = _letters_view()
		_cursor = _nearest_lit(_letter_key())
	elif _by_region:
		_cursor = _group_at(row.selected_index(), _view.groups)
	_ribbon.show()
	_animate_ribbon(true)
	Diagnostics.trace("search", "opened on '%s'" % _typed)
	opened.emit(true)
	_refresh()


## Closes the ribbon; keeping what it found and where the carousel is when [param keep], else back on
## the whole shelf, on the game shown when it opened.
func close(keep: bool) -> void:
	_open = false
	let_go()
	if not keep:
		_show_shelf(_before)
	_animate_ribbon(false)
	Diagnostics.trace("search", "closed, %s '%s'" % ["keeping" if keep else "leaving", _typed])
	opened.emit(false)
	_refresh()


## Back to the whole shelf in title order, on the game shown when the first key was typed (or, by
## region, the one shown).
func clear() -> void:
	_show_shelf(_home if not _typed.is_empty() else shown_position())
	_refresh()


## L1 or R1 on the games screen, the ribbon open or not: to the previous or next group of the
## index, or once keys are typed to the previous or next key that still finds a game.
func leap(direction: int) -> void:
	if _open and _typed.is_empty():
		_move(direction)
		return
	var leap_to := _leap(direction)
	if leap_to.at < 0:
		return
	if not _typed.is_empty():
		_cursor = leap_to.key
	row.jump(leap_to.at, direction, _INDEX_SLIDE if not _typed.is_empty() else _LEAP_SLIDE)
	_show_big(leap_to.label)
	_refresh()


## Where L1 ([param direction] -1) or R1 (1) leads, for the hints; empty for nowhere, or when the
## ribbon's index has them move its cursor.
func leap_label(direction: int) -> String:
	if _open and _typed.is_empty():
		return ""
	var leap_to := _leap(direction)
	return leap_to.label if leap_to.at >= 0 else ""


## Takes [param event] while the ribbon is open; [param held] is the carousel's direction, which
## the event pressed or released when [param moved].
func take(event: InputEvent, held: HeldDirection, moved: bool) -> void:
	if moved:
		if held.held:
			_hold(held.direction)
		elif _held == held.direction:
			let_go()
	elif event.is_action_pressed(&"ui_accept"):
		if _by_region:
			close(true)
		else:
			_type(KEYS[_cursor])
	elif event.is_action_pressed(&"screen_back"):
		_back()
	elif event.is_action_pressed(&"ui_up") or event.is_action_pressed(&"form_submit"):
		close(true)
	elif event.is_action_pressed(&"ui_down") and _typed.is_empty():
		_switch_index()
	elif event.is_action_pressed(&"previous_letter"):
		leap(-1)
	elif event.is_action_pressed(&"next_letter"):
		leap(1)
	elif event.is_action_pressed(&"open_settings") and not _by_region:
		_type(SPACE)


func _hold(direction: int) -> void:
	_move(direction)
	_held = direction
	_held_steps = 0
	_clock_s = 0.0
	_next_repeat_s = CarouselLayout.repeat_delay(0)
	set_process(true)


## The cursor to the next key (or region) that leads somewhere towards [param direction]; with
## nothing typed, the carousel jumps there.
func _move(direction: int) -> void:
	var count := _view.groups.size() if _by_region else KEYS.length()
	for step in range(1, count + 1):
		var next := posmod(_cursor + direction * step, count)
		if _by_region or _is_lit(KEYS[next]):
			_cursor = next
			break
	if _by_region:
		row.jump(_view.groups[_cursor].start, direction, _INDEX_SLIDE)
	elif _typed.is_empty() and _is_lit(KEYS[_cursor]):
		row.jump(_view.keys[KEYS[_cursor]], direction, _INDEX_SLIDE)
	_refresh()


func _type(key: String) -> void:
	if not _is_lit(key):
		return
	if _typed.is_empty():
		_home = shown_position()
	_find(_typed + key)


func _back() -> void:
	if _by_region or _typed.is_empty():
		close(false)
	elif _typed.length() == 1:
		_show_shelf(_home)
		_cursor = _nearest_lit(_cursor)
		_refresh()
	else:
		_find(_typed.left(-1))


## The games found for [param search], the row on the game shown if it is one of them, else on the
## first after it on the shelf.
func _find(search: String) -> void:
	var started := Time.get_ticks_usec()
	var found := android.browse(_platform_id, &"title", search)
	if not _usable(found):
		return
	var anchor := shown_position()
	_typed = search
	_show(found, anchor)
	_cursor = _nearest_lit(_cursor)
	if Diagnostics.enabled:
		Diagnostics.trace("search", "'%s': %d games, shown in %.1f ms" % [search, found.games.size(),
			(Time.get_ticks_usec() - started) / 1000.0])
	_refresh()


## Down with nothing typed: from the letters to the regions, and back.
func _switch_index() -> void:
	var index := _letters_view() if _by_region else android.browse(_platform_id, &"region", "")
	if not _usable(index):
		return
	var anchor := shown_position()
	_by_region = not _by_region
	_show(index, anchor)
	_cursor = _group_at(row.selected_index(), _view.groups) if _by_region else _nearest_lit(_letter_key())
	_refresh()


## Shows [param view] on the row, on the game at shelf position [param anchor] if it shows it, else
## on the first one after it, else the last.
func _show(view: AndroidServices.Browse, anchor: int) -> void:
	if not _usable(view):
		return
	_view = view
	var games: Array[AndroidServices.Game] = []
	for shelf_position in view.games:
		games.append(_shelf[shelf_position])
	var at := view.games.find(anchor)
	if at < 0:
		at = mini(view.games.bsearch(anchor), games.size() - 1)
	row.show_games(games, at)


## The whole shelf in title order again, nothing typed, on the game at shelf position [param anchor].
func _show_shelf(anchor: int) -> void:
	_typed = ""
	_by_region = false
	_show(_letters_view(), anchor)


## Whether [param view] is for the shelf shown and shows a game: a view of another library (asked
## for as it was being changed) is set aside.
func _usable(view: AndroidServices.Browse) -> bool:
	return view.count == _shelf.size() and not view.games.is_empty()


## The index by title, asked for once per shelf (until the plugin's answer is for it).
func _letters_view() -> AndroidServices.Browse:
	if not _usable(_letters):
		_letters = android.browse(_platform_id, &"title", "")
	return _letters


## Where L1 or R1 lead from the game shown.
func _leap(direction: int) -> Leap:
	if not _typed.is_empty():
		var word := _typed.get_slice(SPACE, _typed.get_slice_count(SPACE) - 1)
		# Every key but the space.
		var letters := KEYS.length() - 1
		for step in range(1, letters + 1):
			var key := posmod(_cursor + direction * step, letters)
			if _is_lit(KEYS[key]):
				return Leap.new(_view.keys[KEYS[key]], (word + KEYS[key]).to_upper(), key)
		return Leap.new()
	var groups := _view.groups if is_filtered() or _open else _letters_view().groups
	if groups.size() < 2:
		return Leap.new()
	var next := groups[posmod(_group_at(row.selected_index(), groups) + direction, groups.size())]
	return Leap.new(next.start, tr(next.label))


## The index in [param groups] of the group holding row index [param at].
func _group_at(at: int, groups: Array[AndroidServices.Group]) -> int:
	var found := 0
	for i in groups.size():
		if groups[i].start <= at:
			found = i
	return found


## The key of the shown game's letter: its own, or the first digit for `#`.
func _letter_key() -> int:
	var groups := _letters_view().groups
	if groups.is_empty():
		return 0
	var label := groups[_group_at(shown_position(), groups)].label.to_lower()
	return KEYS.find("0") if label == "#" else maxi(0, KEYS.find(label))


## [param key] if it leads somewhere, else the nearest key that does, the next one first.
func _nearest_lit(key: int) -> int:
	for step in KEYS.length():
		for at: int in [key + step, key - step]:
			if at >= 0 and at < KEYS.length() and _is_lit(KEYS[at]):
				return at
	return key


func _is_lit(key: String) -> bool:
	return key in _view.keys


func _show_big(label: String) -> void:
	_big_text.text = label
	_big_text.add_theme_font_size_override(&"font_size",
		roundi(_big_size * (_BIG_LONG_SCALE if label.length() > 2 else 1.0)))
	if _big_fade:
		_big_fade.kill()
	_big.modulate.a = 1.0
	_big_fade = create_tween()
	_big_fade.tween_interval(_BIG_S)
	_big_fade.tween_property(_big, ^"modulate:a", 0.0, _BIG_FADE_S)


func _animate_ribbon(up: bool) -> void:
	if _rise:
		_rise.kill()
	_rise = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rise.tween_property(_ribbon, ^"position:y", _ribbon_y if up else _ribbon_y + _RISE_PX, RISE_S)
	_rise.tween_property(_ribbon, ^"modulate:a", 1.0 if up else 0.0, RISE_S)
	if not up:
		_rise.chain().tween_callback(_ribbon.hide)


## The ribbon's keys, the chip, the filter kept, the hints: as things are.
func _refresh() -> void:
	var found := _view.games.size()
	_chip.visible = _open and not _typed.is_empty()
	_typed_text.text = _typed
	_count.text = tr_n("{count} game", "{count} games", found).format({"count": found})
	_filter.visible = not _open and is_filtered()
	_filter_text.text = tr("By region") if _by_region else tr("“{typed}” — {found} of {total}").format(
		{"typed": _typed.strip_edges(), "found": found, "total": _shelf.size()})
	_hints.visible = _open
	if _open:
		_draw_keys()
		_show_hints()
	changed.emit()


func _draw_keys() -> void:
	var labels := PackedStringArray()
	if _by_region:
		for group in _view.groups:
			labels.append(tr(group.label))
	else:
		for i in KEYS.length():
			labels.append(KEYS[i].to_upper())
	if _strip.get_child_count() != labels.size() or _strip.get_meta(&"regions", false) != _by_region:
		for key in _strip.get_children():
			key.free()
		for i in labels.size():
			_strip.add_child(RibbonKey.new(labels[i], _tap.bind(i)))
		_strip.set_meta(&"regions", _by_region)
	for i in labels.size():
		var key: RibbonKey = _strip.get_child(i)
		key.show_as(i == _cursor, _by_region or _is_lit(KEYS[i]))
	_centre_strip()


## The strip under the ribbon's middle, the key with the cursor as near it as the strip's ends allow.
func _centre_strip() -> void:
	if _cursor >= _strip.get_child_count():
		return
	var room := _window.size.x
	var width := _strip.get_combined_minimum_size().x
	var key: Control = _strip.get_child(_cursor)
	_strip.position.x = (room - width) / 2.0 if width <= room \
		else clampf(room / 2.0 - key.position.x - key.size.x / 2.0, room - width, 0.0)


func _show_hints() -> void:
	var shown: Array[PackedStringArray] = []
	if _by_region or _typed.is_empty():
		shown.append(PackedStringArray(["← →", tr("Region") if _by_region else tr("Letter")]))
		shown.append(PackedStringArray(["a", tr("Enter") if _by_region else tr("Type the key")]))
		shown.append(PackedStringArray(["↓", tr("Other index")]))
		shown.append(PackedStringArray(["b", tr("Go back")]))
	else:
		shown.append(PackedStringArray(["a", tr("Type the key")]))
		shown.append(PackedStringArray(["l1", leap_label(-1)]))
		shown.append(PackedStringArray(["r1", leap_label(1)]))
		if _is_lit(SPACE):
			shown.append(PackedStringArray(["y", tr("Space")]))
		shown.append(PackedStringArray(["b", tr("Erase")]))
		shown.append(PackedStringArray(["↑", tr("Enter")]))
	# Made again only when they change: the cursor runs over many keys a second.
	if shown == _hints_shown:
		return
	_hints_shown = shown
	for hint in _hints.get_children():
		hint.free()
	for told in shown:
		if told[1].is_empty():
			continue
		var hint := ButtonHint.new()
		hint.button = StringName(told[0])
		hint.text = told[1]
		_hints.add_child(hint)


## A key tapped: typed, or on the regions, jumped to.
func _tap(key: int) -> void:
	if not _open:
		return
	Diagnostics.trace("touch", "ribbon key %d" % key)
	if _by_region:
		_cursor = key
		row.jump(_view.groups[key].start, 1, _INDEX_SLIDE)
		_refresh()
	elif _is_lit(KEYS[key]):
		_cursor = key
		_type(KEYS[key])


## Where L1 or R1 lead: the row's index [member at], told by [member label], on the ribbon's key
## [member key] once keys are typed; nowhere for an index below 0.
class Leap:
	var at := -1
	var label := ""
	var key := 0

	func _init(row_index := -1, told := "", ribbon_key := 0) -> void:
		at = row_index
		label = told
		key = ribbon_key


## One key of the ribbon: its letter (a space drawn as a bracket), lit or dimmed, the cursor on it or
## not; a tap on it calls [member tapped].
class RibbonKey extends PanelContainer:
	const _DIMMED := 0.2

	var tapped: Callable
	var _text := Label.new()
	var _space := SpaceMark.new()

	func _init(label: String, on_tap: Callable) -> void:
		tapped = on_tap
		theme_type_variation = &"RibbonKey"
		custom_minimum_size = Vector2(34.0, 44.0)
		size_flags_vertical = SIZE_SHRINK_CENTER
		_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		_text.text = label.strip_edges()
		add_child(_text)
		_space.visible = label == SPACE
		add_child(_space)

	func show_as(current: bool, lit: bool) -> void:
		theme_type_variation = &"RibbonKeyOn" if current else &"RibbonKey"
		_text.theme_type_variation = &"RibbonTextOn" if current else &"RibbonText"
		_space.ink = Color.WHITE if current else StudioTokens.INK
		_space.queue_redraw()
		modulate.a = 1.0 if lit or current else _DIMMED

	# A tap reaches a control twice, as a touch and as the click emulated from it: the click alone
	# types, the touch is only kept from the carousel behind.
	func _gui_input(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if event is InputEventScreenTouch or event is InputEventScreenDrag or click:
			accept_event()
		if click and click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			tapped.call()


## A space, drawn as a bracket open upwards: fonts rarely have the sign for it.
class SpaceMark extends Control:
	var ink := StudioTokens.INK

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var middle := size / 2.0
		var half := Vector2(9.0, 5.0)
		draw_polyline([middle + Vector2(-half.x, -half.y), middle + Vector2(-half.x, half.y),
			middle + Vector2(half.x, half.y), middle + Vector2(half.x, -half.y)], ink, 2.5, true)
