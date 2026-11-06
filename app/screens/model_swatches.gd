# SPDX-License-Identifier: GPL-3.0-or-later
class_name ModelSwatches
extends Control
## A console's models, chosen in the form itself, under its model line: a grid of swatches, [constant COLUMNS] to a
## row, each the model's picture posed as on the ring ([RingView], drawn once each time the chooser opens) over its
## name, the one the console has marked. ← → go through them in order, ↑ ↓ to the row above or below; a held
## direction repeats as on the shelves, and each model in focus shows at once on the console ([signal looked]). A
## keeps it, unless it is not fully supported yet ([method ConsoleManifest.is_coming], greyed); B, which the form
## takes, puts back the one it had ([method cancel]). A grid taller than
## [constant ROOM_Y] scrolls, the focus' row in view.

## The console is shown as model [param index], for a look.
signal looked(index: int)
## The chooser closed on model [param index]: the one kept, or the one it had.
signal closed(index: int)

const COLUMNS := 4
const ROOM_Y := 504.0
const _MOVES: Array[StringName] = [&"ui_left", &"ui_right", &"ui_up", &"ui_down"]
const _INSET := 2.2 * FormPaint.CQW
const _CELL_H := 150.0
const _PICTURE_INSET := Vector2(14.0, 10.0)
const _PICTURE_H := 98.0
const _NAME_Y := 126.0
const _NAME_PX := 1.45 * FormPaint.CQW
const _BADGE := 0.75 * FormPaint.CQW
const _CARD_INSET := 4.0
## How much of its ink a model not fully supported yet keeps.
const _COMING_INK := 0.5
## How fast the focus card and the scroll close on where they go, per second.
const _CLOSING := 18.0

var models: Array[ConsoleManifest] = []
## The model in focus, and the one the console had as the chooser opened.
var focused := 0
var had := 0
## The console's colour: the focus card and the badge.
var rim := StudioTokens.NEUTRAL
## The carousel's consoles and sun, which the pictures are drawn as ([RingView]).
var ring: ConsoleRow
var sun: DirectionalLight3D
## Whether each model is not fully supported yet, read as the chooser opens.
var _coming: Array[bool] = []
var _card: FormPaint.Layer
var _card_at := Vector2.ZERO
var _scroll := 0.0
## Each model's picture once drawn, by its folder; the openings so far, so that the pictures still drawn for a
## chooser closed meanwhile are let go.
var _pictures: Dictionary[String, Texture2D] = {}
var _openings := 0
## The directions held, along a row and across them, and the one repeating.
var _along := HeldDirection.new({&"ui_left": -1, &"ui_right": 1})
var _across := HeldDirection.new({&"ui_up": -1, &"ui_down": 1})
var _held := Vector2i.ZERO
var _repeat := CarouselLayout.Repeat.new()


func _init() -> void:
	focus_mode = FOCUS_ALL
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP
	hide()


func _ready() -> void:
	_card = FormPaint.Layer.new(self, FormPaint.card_material(true))


func _notification(what: int) -> void:
	# A direction let go meanwhile never reaches the app.
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_let_go()


func is_open() -> bool:
	return visible


## Opens on [param shown], the models of [param platform_id]'s console, the focus on model [param kept], the one it
## has.
func open(platform_id: String, shown: Array[ConsoleManifest], kept: int) -> void:
	models = shown
	_coming.assign(shown.map(func(model: ConsoleManifest) -> bool: return model.is_coming()))
	had = kept
	focused = kept
	size.y = minf(ROOM_Y, ceilf(models.size() / float(COLUMNS)) * _CELL_H)
	_card.tint = rim
	_scroll = _scroll_for(focused, 0.0)
	_card_at = _cell(focused).position
	show()
	grab_focus()
	_glide(0.0)
	_paint(platform_id)


## Puts back the model it had and closes.
func cancel() -> void:
	looked.emit(had)
	_close(had)


func _gui_input(event: InputEvent) -> void:
	for action in _MOVES:
		if event.is_action(action):
			accept_event()
			if not event.is_echo():
				_follow(event)
			return
	if event.is_action_pressed(&"ui_accept"):
		accept_event()
		_keep(focused)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		var at := _index_at((event as InputEventMouseButton).position)
		if at == focused:
			_keep(at)
		elif at >= 0:
			_go(at)


func _process(delta: float) -> void:
	if not visible:
		return
	if _held != Vector2i.ZERO and _repeat.due(delta):
		_go(_target(_held, true))
	_glide(delta)


func _draw() -> void:
	for i in models.size():
		var cell := _cell(i)
		cell.position.y -= _scroll
		if cell.end.y < 0.0 or cell.position.y > size.y:
			continue
		var folder := ConsoleManifest.folder_of(models[i])
		var box := _picture_box(i)
		box.position.y -= _scroll
		var greyed := _COMING_INK if _coming[i] else 1.0
		if folder in _pictures:
			var picture := _pictures[folder]
			var fitted := picture.get_size() * minf(box.size.x / picture.get_size().x, box.size.y / picture.get_size().y)
			draw_texture_rect(picture, Rect2(box.get_center() - fitted / 2.0, fitted), false, Color(1.0, 1.0, 1.0, greyed))
		var chosen := i == focused
		var named := FormPaint.line(models[i].model_name,
			StudioTokens.Face.JAKARTA_800 if chosen else StudioTokens.Face.JAKARTA_700, _NAME_PX)
		named.fit(cell.size.x - 8.0)
		named.draw(self, Vector2(cell.get_center().x - named.width / 2.0, cell.position.y + _NAME_Y - named.height / 2.0),
			Color(Backdrop.palette.ink if chosen and greyed == 1.0 else Backdrop.palette.mute, greyed))
		if i == had:
			var badge := box.position + Vector2(box.size.x - _BADGE, _BADGE)
			draw_circle(badge, _BADGE, Backdrop.palette.gel(rim))
			var k := _BADGE / 14.0
			var tick := badge - Vector2(_BADGE * 0.5, 0.0)
			draw_polyline(PackedVector2Array([tick, tick + Vector2(5.0, 5.0) * k, tick + Vector2(14.0, -6.0) * k]),
				Color.WHITE, 2.6, true)


## A direction pressed or let go by [param event]: a press moves at once, then again while it is held.
func _follow(event: InputEvent) -> void:
	for held: HeldDirection in [_along, _across]:
		if held.update(event):
			var way := (Vector2i.RIGHT if held == _along else Vector2i.DOWN) * held.direction
			if held.held:
				_press(way)
			elif _held == way:
				_held = Vector2i.ZERO


func _let_go() -> void:
	_along.let_go()
	_across.let_go()
	_held = Vector2i.ZERO


func _press(direction: Vector2i) -> void:
	_held = direction
	_repeat.start()
	_go(_target(direction, false))


func _go(index: int) -> void:
	if index == focused:
		return
	focused = index
	Sounds.play(SoundEffects.Cue.MODEL)
	looked.emit(index)
	queue_redraw()


## Model [param index] kept, unless it is not fully supported yet and not the one the console has.
func _keep(index: int) -> void:
	if _coming[index] and index != had:
		Diagnostics.trace("console form", "model %s refused: not fully supported yet" % ConsoleManifest.folder_of(models[index]))
		Sounds.play(SoundEffects.Cue.ERROR)
		return
	Sounds.play(SoundEffects.Cue.SELECT)
	_close(index)


func _close(index: int) -> void:
	_let_go()
	_openings += 1
	_pictures.clear()
	hide()
	closed.emit(index)


## Each model's picture drawn in turn, in one view freed once they are, or once the chooser closed.
func _paint(platform_id: String) -> void:
	var opening := _openings
	var painter := RingView.new()
	painter.ring = ring
	painter.sun = sun
	painter.size = _picture_box(0).size
	painter.hide()
	add_child(painter)
	for model in models:
		var folder := ConsoleManifest.folder_of(model)
		painter.show_console(platform_id, folder, true)
		var picture := await painter.still()
		if opening != _openings:
			break
		if picture:
			_pictures[folder] = picture
			queue_redraw()
	painter.queue_free()


## The model a press of [param direction] goes to, [param repeated] when held: along the grid's order, round from
## its ends on a new press only; up and down to the same column of the row there, the last model of a shorter row.
func _target(direction: Vector2i, repeated: bool) -> int:
	if direction.x != 0:
		var along := focused + direction.x
		if along >= 0 and along < models.size():
			return along
		return focused if repeated else posmod(along, models.size())
	var row := floori(focused / float(COLUMNS)) + direction.y
	if row < 0 or row * COLUMNS >= models.size():
		return focused
	return mini(row * COLUMNS + focused % COLUMNS, models.size() - 1)


## The swatch of model [param index], in the grid as it would stand unscrolled.
func _cell(index: int) -> Rect2:
	var width := (size.x - 2.0 * _INSET) / COLUMNS
	return Rect2(_INSET + index % COLUMNS * width, floorf(index / float(COLUMNS)) * _CELL_H, width, _CELL_H)


## Where the picture of model [param index] stands in its swatch, unscrolled.
func _picture_box(index: int) -> Rect2:
	var cell := _cell(index)
	return Rect2(cell.position + _PICTURE_INSET, Vector2(cell.size.x - 2.0 * _PICTURE_INSET.x, _PICTURE_H))


## The model under [param at], the chooser's coordinates; -1 for none.
func _index_at(at: Vector2) -> int:
	for i in models.size():
		if _cell(i).has_point(at + Vector2(0.0, _scroll)):
			return i
	return -1


## The scroll that keeps model [param index]'s row in view, from [param scroll], moving as little as it can.
func _scroll_for(index: int, scroll: float) -> float:
	var cell := _cell(index)
	return clampf(clampf(scroll, cell.end.y - size.y, cell.position.y), 0.0,
		maxf(ceilf(models.size() / float(COLUMNS)) * _CELL_H - size.y, 0.0))


## The scroll and the focus card closing on the focus' row and swatch; still once there.
func _glide(delta: float) -> void:
	var scroll := _scroll_for(focused, _scroll)
	var cell := _cell(focused)
	if delta > 0.0 and _scroll == scroll and _card_at == cell.position:
		return
	var closing := 1.0 - exp(-_CLOSING * delta) if delta > 0.0 else 1.0
	# Within a tenth of a px, there.
	_scroll = scroll if absf(_scroll - scroll) < 0.1 else lerpf(_scroll, scroll, closing)
	_card_at = cell.position if _card_at.distance_to(cell.position) < 0.1 else _card_at.lerp(cell.position, closing)
	_card.place(Rect2(_card_at - Vector2(0.0, _scroll), cell.size).grow(-_CARD_INSET), StudioTokens.FOCUS_RADIUS)
	queue_redraw()
