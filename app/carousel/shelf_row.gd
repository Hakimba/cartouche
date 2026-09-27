# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShelfRow
extends Node3D
## The row of one shelf's games. A fixed pool of places is recycled as the row moves, so its cost
## does not depend on the number of games; a place keeps its game, and its drawn label, while the
## game stays in view. The mechanics are [CarouselLayout]'s.

## The game at the centre changed.
signal selection_changed(game: AndroidServices.Game)

## Every game [method CarouselLayout.offsets] can show at once.
const _PLACES := 2 * CarouselLayout.REACH + 3
## Largest turn of the selected game with the right stick, in radians.
const _INSPECT_ANGLE := 1.1
const _BOB_HEIGHT := 0.05
const _BOB_SPEED := 1.6
## How much a fast-moving row stretches its games.
const _STRETCH := 0.012
const _MAX_STRETCH := 0.1

var _games: Array[AndroidServices.Game] = []
var _look := LabelLook.new()
## The selected game's position on the endless row (see [CarouselLayout]); the scroll follows it.
var _position := 0
var _scroll := 0.0
var _speed := 0.0
## The direction held (-1 or 1), 0 when none.
var _held := 0
var _held_steps := 0
var _next_repeat_s := 0.0
var _clock_s := 0.0
var _inspect := Vector2.ZERO
var _inspect_target := Vector2.ZERO
var _places: Array[Place] = []
var _placed: Dictionary[int, Place] = {}
## Places waiting for their label, drawn one per frame so that a fast move never stalls.
var _unlabelled: Array[Place] = []


func _ready() -> void:
	for i in _PLACES:
		var place := Place.new()
		add_child(place)
		_places.append(place)
	# Nothing moves before a shelf is shown.
	set_process(false)


# Runs every frame: the selected game floats. Arranging nine places is negligible next to drawing them.
func _process(delta: float) -> void:
	_clock_s += delta
	if _held != 0 and _clock_s >= _next_repeat_s:
		_step(_held)
		_held_steps += 1
		_next_repeat_s = _clock_s + CarouselLayout.repeat_delay(_held_steps)
	var before := _scroll
	_scroll = CarouselLayout.scrolled(_scroll, _position, delta)
	_speed = (_scroll - before) / delta if delta > 0.0 else 0.0
	_inspect = _inspect.lerp(_inspect_target, 1.0 - exp(-10.0 * delta))
	_arrange()
	if not _unlabelled.is_empty():
		var place: Place = _unlabelled.pop_front()
		if place.game >= 0:
			place.shown.draw_label(_games[place.game].title, _look)


## Makes every place's model of each of [param models] now, rather than when a shelf of that media
## is first shown: making one takes about 2 ms on a handheld, its first one 10 to 30 ms.
func prepare(models: Array[PackedScene]) -> void:
	for place in _places:
		for model in models:
			place.use_model(model)
		place.visible = false


## Shows [param games] (in shelf order) from index [param selected], on models of [param model]
## with labels of [param look].
func show_shelf(games: Array[AndroidServices.Game], selected: int, model: PackedScene, look: LabelLook) -> void:
	_games = games
	_look = look
	_position = selected
	_scroll = selected
	_held = 0
	set_process(true)
	_placed.clear()
	_unlabelled.clear()
	for place in _places:
		place.game = -1
		place.use_model(model)
	_arrange()


## Whether the shelf has games; the other methods need one.
func has_games() -> bool:
	return not _games.is_empty()


func selected_game() -> AndroidServices.Game:
	return _games[selected_index()]


func selected_index() -> int:
	return posmod(_position, _games.size())


## Steps once towards [param direction] (-1 or 1), then again and again, faster, until
## [method release].
func hold(direction: int) -> void:
	_step(direction)
	_held = direction
	_held_steps = 0
	_next_repeat_s = _clock_s + CarouselLayout.repeat_delay(0)


## Stops the steps of [param direction] at once: no step is left pending.
func release(direction: int) -> void:
	if _held == direction:
		_held = 0


## Turns the selected game towards [param stick] (each axis from -1 to 1); zero lets it go back.
func inspect(stick: Vector2) -> void:
	_inspect_target = stick


func _step(direction: int) -> void:
	if _games.size() < 2:
		return
	_position = CarouselLayout.stepped(_position, direction, _games.size())
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "step %d to %d (held for %d steps)" % [direction, selected_index(), _held_steps])
	selection_changed.emit(selected_game())


func _arrange() -> void:
	var shown := CarouselLayout.offsets(_games.size(), _scroll)
	for game: int in _placed.keys():
		if game not in shown:
			_placed[game].game = -1
			_placed.erase(game)
	for game: int in shown:
		if game not in _placed:
			var place := _free_place()
			place.game = game
			place.shown.clear_label()
			_placed[game] = place
			if place not in _unlabelled:
				_unlabelled.append(place)
	var stretch := minf(absf(_speed) * _STRETCH, _MAX_STRETCH)
	for place in _places:
		place.visible = place.game >= 0
		if place.visible:
			var offset: float = shown[place.game]
			var centred := clampf(1.0 - 2.0 * absf(offset), 0.0, 1.0)
			var stand := CarouselLayout.place(offset)
			stand.origin.y += sin(_clock_s * _BOB_SPEED) * _BOB_HEIGHT * centred
			var turn := Basis.from_euler(Vector3(_inspect.y, _inspect.x, 0.0) * _INSPECT_ANGLE * centred)
			place.transform = Transform3D(stand.basis * turn * Basis.from_scale(Vector3(1.0 + stretch, 1.0 - stretch * 0.6, 1.0)), stand.origin)
			place.shown.fade(CarouselLayout.fade(offset))


func _free_place() -> Place:
	for place in _places:
		if place.game < 0:
			return place
	# Unreachable: there are as many places as games shown at once.
	push_error("ShelfRow: no free place")
	return _places[0]


## How labels look on one shelf.
class LabelLook:
	var color := Color(0.35, 0.37, 0.42)
	var platform_name := ""


## One game's place in the row, showing the model of the shelf's media. Each media's model is kept
## once made, so that changing shelf only shows another one.
class Place extends Node3D:
	## Index of the game shown here, -1 when the place is free.
	var game := -1
	var shown: LabelledModel
	var _models: Dictionary[PackedScene, LabelledModel] = {}

	## Shows [param model], made the first time it is used here.
	func use_model(model: PackedScene) -> void:
		if shown:
			shown.visible = false
		if model not in _models:
			_models[model] = LabelledModel.new(model)
			add_child(_models[model])
		shown = _models[model]
		shown.visible = true


## A model and the label drawn for it, in its own small viewport shaped like the model's `Label`
## mesh.
class LabelledModel extends Node3D:
	const _LABEL_VIEW := preload("res://carousel/label_view.tscn")
	const _LABEL_WIDTH := 256

	var _geometry: Array[GeometryInstance3D] = []
	var _material: ShaderMaterial
	var _view: SubViewport = _LABEL_VIEW.instantiate()
	var _background: ColorRect = _view.get_node("Background")
	var _title: Label = _view.get_node("Title")
	var _platform: Label = _view.get_node("Platform")

	func _init(model: PackedScene) -> void:
		var instance: Node3D = model.instantiate()
		add_child(instance)
		add_child(_view)
		_geometry.assign(instance.find_children("*", "GeometryInstance3D", true, false))
		var label: MeshInstance3D = instance.get_node("Label")
		_material = label.get_surface_override_material(0).duplicate()
		label.set_surface_override_material(0, _material)
		_material.set_shader_parameter(&"label_texture", _view.get_texture())
		var face := label.get_aabb().size
		_view.size = Vector2i(_LABEL_WIDTH, roundi(_LABEL_WIDTH * face.y / face.x))
		# A round label leaves its centre to the hole: the title goes above it, the platform below.
		# A parameter the material leaves at its default reads as null.
		var round_label: bool = _material.get_shader_parameter(&"round") == true
		var size := Vector2(_view.size)
		if round_label:
			_title.position = size * Vector2(0.2, 0.1)
			_title.size = size * Vector2(0.6, 0.22)
			_platform.position = size * Vector2(0.2, 0.74)
		else:
			_title.position = size * Vector2(0.06, 0.08)
			_title.size = size * Vector2(0.88, 0.6)
			_platform.position = size * Vector2(0.1, 0.72)
		_platform.size = Vector2(size.x - 2.0 * _platform.position.x, size.y * 0.18)

	func clear_label() -> void:
		_material.set_shader_parameter(&"has_label", false)

	func draw_label(title: String, look: LabelLook) -> void:
		_background.color = look.color
		_title.text = title
		_platform.text = look.platform_name
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		_material.set_shader_parameter(&"has_label", true)

	## Sets how transparent the model is, from 0 (opaque) to 1 (gone).
	func fade(amount: float) -> void:
		for geometry in _geometry:
			geometry.transparency = amount
