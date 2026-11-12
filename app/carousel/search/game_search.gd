# SPDX-License-Identifier: GPL-3.0-or-later
class_name GameSearch
extends Control
## The ribbon that searches the games screen's shelf. Down opens it under the carousel: keys A to
## Z, 0 to 9 and a space. Until a key is typed it is an index: left and right go from letter to
## letter, the carousel jumping to its first game behind; down again, from region to region, the
## carousel keeping only the games of the region the cursor is on. A types the key, and the carousel
## keeps only the games found (the core's `Finder`: each word typed starts another word of the title,
## in any order); keys that would find nothing are dimmed and skipped. L1 and R1 go to the previous
## or next letter, or once keys are typed to the previous or next key that still finds a game, the
## carousel on the first game it finds; a big letter tells where. B erases a key, then closes the
## ribbon, back on the game shown before; up or Start close it keeping what is found, told at the
## top, which B on the games screen clears. A key tapped is typed.
##
## The carousel hands its presses over while the ribbon is open ([method take]), and B while what
## is found is kept ([method clear]). What the ribbon is on and what each press does to it is [SearchModel]'s: this
## scene draws it, holds a direction, and plays what the model answers on the row.

## The ribbon opened or closed: the carousel makes room for it.
signal opened(open: bool)
## What the carousel shows changed: its title's marks and the hints follow.
signal changed

## The ribbon rises from this far below in this time.
const RISE_S := 0.18
const _RISE_PX := 140.0
## A jump of the index, or of L1 and R1 once keys are typed, slides the carousel in from this many
## places.
const _INDEX_SLIDE := 0.6
## The big letter shows this long, then fades in this time.
const _BIG_S := 0.7
const _BIG_FADE_S := 0.12
## The size of the big letter, against its theme's: it tells the start of the words a leap among the keys typed
## reaches, small, at the right above the keys, clear of the title in the middle and of the keys typed at the left.
const _BIG_SCALE := 0.25

var android: AndroidServices = Android
## The carousel's row, which shows what is found.
var row: ShelfRow

var _platform_id := ""
var _shelf: Array[AndroidServices.Game] = []
var _model := SearchModel.new(_browse)
var _held := 0
var _repeat := CarouselLayout.Repeat.new()
var _rise: Tween
## How far below its place the ribbon stands while it rises.
var _lowered := 0.0:
	set(value):
		_lowered = value
		_ribbon.offset_top = _ribbon_place.x + value
		_ribbon.offset_bottom = _ribbon_place.y + value
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
## The ribbon's place, kept to the screen's bottom.
@onready var _ribbon_place := Vector2(_ribbon.offset_top, _ribbon.offset_bottom)


func _ready() -> void:
	_strip.sort_children.connect(_centre_strip)
	_ribbon.hide()
	_lowered = _RISE_PX
	_ribbon.modulate.a = 0.0
	_big.modulate.a = 0.0
	_big_text.add_theme_font_size_override(&"font_size", roundi(_big_text.get_theme_font_size(&"font_size") * _BIG_SCALE))
	set_process(false)


# Runs while a direction is held on the ribbon: its cursor goes on, faster and faster.
func _process(delta: float) -> void:
	if _repeat.due(delta):
		_act(_model.move(_held))


## Searches [param games], [param platform_id]'s shelf in its order, from now on: nothing typed,
## the ribbon closed.
func use_shelf(platform_id: String, games: Array[AndroidServices.Game]) -> void:
	_platform_id = platform_id
	_shelf = games
	var was_open := _model.open
	_model.use_shelf(games.size())
	if was_open:
		opened.emit(false)
	let_go()
	_ribbon.hide()
	_refresh()


func is_open() -> bool:
	return _model.open


## Whether what the row shows is not the whole shelf in title order, the ribbon open or not.
func is_filtered() -> bool:
	return _model.is_filtered()


## The shelf position of the game the row shows, whatever it shows.
func shown_position() -> int:
	return _model.shown_position(row.selected_index())


## Where the words typed are in the shown game's title, as (start, length) in characters.
func marks() -> Array[Vector2i]:
	if _model.typed.is_empty():
		return []
	return android.title_marks(_platform_id, shown_position(), _model.typed)


## Forgets a direction held on the ribbon: a screen opening over it leaves nothing pending.
func let_go() -> void:
	_held = 0
	set_process(false)


## Opens the ribbon: on the letter of the game shown, or as it was left with what is typed.
func open() -> void:
	_model.open_at(row.selected_index())
	_ribbon.show()
	_animate_ribbon(true)
	Diagnostics.trace("search", "opened on '%s'" % _model.typed)
	opened.emit(true)
	_refresh()


## Closes the ribbon; keeping what it found and where the carousel is when [param keep], else back on
## the whole shelf, on the game shown when it opened.
func close(keep: bool) -> void:
	_act(_model.close(keep))


## Back to the whole shelf in title order, on the game shown when the first key was typed (or, by
## region, the one shown).
func clear() -> void:
	_play(_model.clear(row.selected_index()))
	_refresh()


## Takes [param event] while the ribbon is open; [param held] is the carousel's direction, which
## the event pressed or released when [param moved].
func take(event: InputEvent, held: HeldDirection, moved: bool) -> void:
	if moved:
		if held.held:
			_hold(held.direction)
		elif _held == held.direction:
			let_go()
		return
	for action in SearchModel.PRESSES:
		if event.is_action_pressed(action):
			# Read before the press: the search it traces is timed from here.
			var started := Time.get_ticks_usec()
			_act(_model.press(action, row.selected_index()), started)
			return


func _hold(direction: int) -> void:
	_act(_model.move(direction))
	_held = direction
	_repeat.start()
	set_process(true)


## The shelf's view the model asks for (see [method AndroidServices.browse]).
func _browse(order: StringName, typed: String) -> AndroidServices.Browse:
	return android.browse(_platform_id, order, typed)


## Plays what a press did, then shows the ribbon as the model now is; nothing for a press that led nowhere. A search
## is traced with the time since [param started], in microseconds.
func _act(effects: Array[SearchModel.Effect], started := 0) -> void:
	if effects.is_empty():
		return
	_play(effects, started)
	_refresh()


func _play(effects: Array[SearchModel.Effect], started := 0) -> void:
	for effect in effects:
		match effect.kind:
			SearchModel.Kind.SOUND:
				Sounds.play(effect.cue)
			SearchModel.Kind.NARROWING:
				Sounds.play_narrowing(effect.cue, effect.before, effect.found, _shelf.size())
			SearchModel.Kind.SHOW:
				var games: Array[AndroidServices.Game] = []
				for shelf_position in effect.games:
					games.append(_shelf[shelf_position])
				row.show_games(games, effect.at)
				if Diagnostics.enabled and not effect.text.is_empty():
					Diagnostics.trace("search", "'%s': %d games, shown in %.1f ms" % [effect.text, games.size(),
						(Time.get_ticks_usec() - started) / 1000.0])
			SearchModel.Kind.JUMP:
				row.jump(effect.at, effect.direction, _INDEX_SLIDE)
				if not effect.text.is_empty():
					_show_big(effect.text)
			SearchModel.Kind.CLOSED:
				let_go()
				_animate_ribbon(false)
				Diagnostics.trace("search", "closed, %s '%s'" % ["keeping" if effect.keep else "leaving", _model.typed])
				opened.emit(false)


func _show_big(label: String) -> void:
	_big_text.text = label
	# As wide as what it now tells, its right edge where the scene puts it, across from the keys typed.
	_big.offset_left = _big.offset_right
	_big.reset_size()
	_big.modulate.a = 1.0
	_big_fade = Motion.restart(self, _big_fade)
	_big_fade.tween_interval(_BIG_S)
	_big_fade.tween_property(_big, ^"modulate:a", 0.0, _BIG_FADE_S)


func _animate_ribbon(up: bool) -> void:
	_rise = Motion.restart(self, _rise).set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_rise.tween_property(self, ^"_lowered", 0.0 if up else _RISE_PX, RISE_S)
	_rise.tween_property(_ribbon, ^"modulate:a", 1.0 if up else 0.0, RISE_S)
	if not up:
		_rise.chain().tween_callback(_ribbon.hide)


func _refresh() -> void:
	var found := _model.found()
	_chip.visible = _model.open and is_filtered()
	# By region, the ribbon names the region: the count alone.
	(_typed_text.get_parent() as Control).visible = not _model.by_region
	_typed_text.text = _model.typed
	_count.text = tr_n("{count} game", "{count} games", found).format({"count": found})
	_filter.visible = not _model.open and is_filtered()
	_filter_text.text = tr("By region") if _model.by_region else tr("“{typed}” — {found} of {total}").format(
		{"typed": _model.typed.strip_edges(), "found": found, "total": _shelf.size()})
	_hints.visible = _model.open
	if _model.open:
		_draw_keys()
		_show_hints()
	changed.emit()


func _draw_keys() -> void:
	var by_region := _model.by_region
	var labels := PackedStringArray()
	if by_region:
		for group in _model.view.groups:
			labels.append(tr(group.label))
	else:
		for i in SearchModel.KEYS.length():
			labels.append(SearchModel.KEYS[i].to_upper())
	if _strip.get_child_count() != labels.size() or _strip.get_meta(&"regions", false) != by_region:
		for key in _strip.get_children():
			key.free()
		for i in labels.size():
			_strip.add_child(RibbonKey.new(labels[i], _tap.bind(i)))
		_strip.set_meta(&"regions", by_region)
	for i in labels.size():
		var key: RibbonKey = _strip.get_child(i)
		key.show_as(i == _model.cursor, by_region or _model.is_lit(SearchModel.KEYS[i]))
	_centre_strip()


## The strip under the ribbon's middle, the key with the cursor as near it as the strip's ends allow.
func _centre_strip() -> void:
	if _model.cursor >= _strip.get_child_count():
		return
	var room := _window.size.x
	var width := _strip.get_combined_minimum_size().x
	var key: Control = _strip.get_child(_model.cursor)
	_strip.position.x = (room - width) / 2.0 if width <= room \
		else clampf(room / 2.0 - key.position.x - key.size.x / 2.0, room - width, 0.0)


func _show_hints() -> void:
	var by_region := _model.by_region
	var shown: Array[PackedStringArray] = []
	if by_region or _model.typed.is_empty():
		shown.append(PackedStringArray(["← →", tr("Region") if by_region else tr("Letter")]))
		shown.append(PackedStringArray(["a", tr("Enter") if by_region else tr("Type the key")]))
		shown.append(PackedStringArray(["↓", tr("Other index")]))
		shown.append(PackedStringArray(["b", tr("Go back")]))
	else:
		shown.append(PackedStringArray(["a", tr("Type the key")]))
		if _model.is_lit(SearchModel.SPACE):
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
	if not _model.open:
		return
	Diagnostics.trace("touch", "ribbon key %d" % key)
	var started := Time.get_ticks_usec()
	_act(_model.tap(key, row.selected_index()), started)


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
		_space.visible = label == SearchModel.SPACE
		add_child(_space)

	func show_as(current: bool, lit: bool) -> void:
		theme_type_variation = &"RibbonKeyOn" if current else &"RibbonKey"
		_text.theme_type_variation = &"RibbonTextOn" if current else &"RibbonText"
		_space.on_key = current
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
	## Whether it is drawn over the current key's fill, in the ink that reads on it.
	var on_key := false

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var middle := size / 2.0
		var half := Vector2(9.0, 5.0)
		draw_polyline([middle + Vector2(-half.x, -half.y), middle + Vector2(-half.x, half.y),
			middle + Vector2(half.x, half.y), middle + Vector2(half.x, -half.y)],
			Backdrop.palette.ribbon_key_ink if on_key else Backdrop.palette.ink, 2.5, true)
