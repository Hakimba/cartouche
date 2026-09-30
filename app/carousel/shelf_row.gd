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
## How much a fast-moving row stretches its games.
const _STRETCH := 0.012
const _MAX_STRETCH := 0.1

## Debug builds: turns per second of the selected game around its vertical axis, to see every side.
var turntable := 0.0
## Where label images come from; a game gets its title drawn until its image is ready, or for good
## without one.
var label_images: GameArt:
	set(art):
		label_images = art
		art.loaded.connect(refresh_label)
var pose := Pose.new()
## How much of its pose and float the selected game has, from 0 (none) to 1.
var pose_amount := 1.0
## How present the games beside the selected one are, and the selected one itself, from 0 (gone) to
## 1 (as the layout fades them).
var neighbours := 1.0
var selected_presence := 1.0

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
var _stick := Vector2.ZERO
var _turn := StickTurn.new()
var _places: Array[Place] = []
var _placed: Dictionary[int, Place] = {}
## Places waiting for their label, drawn one per frame so that a fast move never stalls.
var _unlabelled: Array[Place] = []
## While the selected game is launched, how it stands instead of posed, and how its drive has turned
## it (see [method stand_selected]).
var _launched := false
var _launch_stand := Transform3D.IDENTITY
var _launch_spin := 0.0
var _launch_blur := 0.0


func _ready() -> void:
	for i in _PLACES:
		var place := Place.new()
		add_child(place)
		_places.append(place)
	# Nothing moves before a shelf is shown.
	set_process(false)


# Runs every frame: the selected game floats. Arranging five places is negligible next to drawing
# them.
func _process(delta: float) -> void:
	_clock_s += delta
	if _held != 0 and _clock_s >= _next_repeat_s:
		_step(_held)
		_held_steps += 1
		_next_repeat_s = _clock_s + CarouselLayout.repeat_delay(_held_steps)
	var before := _scroll
	_scroll = CarouselLayout.scrolled(_scroll, _position, delta)
	_speed = (_scroll - before) / delta if delta > 0.0 else 0.0
	if not _games.is_empty():
		_turn.follow(_stick, selected_index(), delta)
	_arrange()
	if not _unlabelled.is_empty():
		var place: Place = _unlabelled.pop_front()
		if place.game >= 0:
			var game := _games[place.game]
			if not _show_image(place, game):
				place.shown.draw_label(game.title, _look)


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
	_turn = StickTurn.new()
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


## Turns the selected game while [param stick] (each axis from -1 to 1) is pushed (see
## [StickTurn]).
func inspect(stick: Vector2) -> void:
	_stick = stick


## Stops every move under way: a held direction, the stick. The selection stays where it is.
func freeze() -> void:
	_held = 0
	_stick = Vector2.ZERO


## Stands the selected game as [param stand] says (in the row's space) instead of posed, turned
## [param spin] radians about its own axis with its label blurred over [param blur] radians, until
## [method pose_selected].
func stand_selected(stand: Transform3D, spin: float, blur: float) -> void:
	_launched = true
	_launch_stand = stand
	_launch_spin = spin
	_launch_blur = blur


## Poses the selected game again, as it was before [method stand_selected].
func pose_selected() -> void:
	_launched = false
	var place: Place = _placed.get(selected_index())
	if place:
		place.shown.spin(0.0, 0.0)


## How the selected game stands now, in the row's space.
func selected_stand() -> Transform3D:
	var place: Place = _placed.get(selected_index())
	return place.transform if place else Transform3D.IDENTITY


## Shows [param game_id]'s image on its place, once read, if the game is in view: it replaces the
## title drawn there.
func refresh_label(game_id: String) -> void:
	for place: Place in _placed.values():
		if _games[place.game].id == game_id and place not in _unlabelled:
			_show_image(place, _games[place.game])


## Shows [param game]'s image on [param place] when it is read; otherwise asks for it and is false.
func _show_image(place: Place, game: AndroidServices.Game) -> bool:
	if label_images.has_texture(game):
		place.shown.show_label(label_images.texture(game), true)
		return true
	label_images.request(game)
	return false


func _step(direction: int) -> void:
	if _games.size() < 2:
		return
	_position = CarouselLayout.stepped(_position, direction, _games.size())
	_turn.release()
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
		if place.visible and _launched and place.game == selected_index():
			place.transform = _launch_stand
			place.shown.spin(_launch_spin, _launch_blur)
			place.shown.fade(0.0)
		elif place.visible:
			var offset: float = shown[place.game]
			var centred := CarouselLayout.centred(offset)
			var posed_part := centred * pose_amount
			var stand := CarouselLayout.place(offset)
			stand.origin.y += CarouselLayout.float_height(_clock_s, CarouselLayout.BOB_HEIGHT, posed_part)
			var spun := Basis(Vector3.UP, TAU * turntable * _clock_s * centred)
			var turn := spun * _turn.of(place.game)
			var stretched := Basis.from_scale(Vector3(1.0 + stretch, 1.0 - stretch * 0.6, 1.0))
			var posed := stand.basis * pose.at(_clock_s, posed_part) * turn * stretched
			place.transform = Transform3D(posed, stand.origin)
			var presence := selected_presence if place.game == selected_index() else neighbours
			place.shown.fade(CarouselLayout.faded(offset, presence))


func _free_place() -> Place:
	for place in _places:
		if place.game < 0:
			return place
	# Unreachable: there are as many places as games shown at once.
	push_error("ShelfRow: no free place")
	return _places[0]


## How the selected game is shown: leaning back and turned a little, it sways slowly so that the
## light moves over it. Angles in degrees.
class Pose:
	var tilt := 0.0
	var turn := 0.0
	var sway := 0.0
	var sway_period_s := 6.0

	## The pose at [param clock_s], [param centred] from 0 (beside the centre, not posed) to 1.
	func at(clock_s: float, centred: float) -> Basis:
		var phase := TAU * clock_s / sway_period_s
		var angles := Vector3(-tilt - sway * sin(phase), turn + sway * sin(phase * 0.71 + 1.0), 0.0)
		return Basis.from_euler(angles * (PI / 180.0) * centred)


## How labels look on one shelf; a game without a scan is drawn so, like a blank of its console.
class LabelLook:
	var color := Color(0.35, 0.37, 0.42)
	var platform_name := ""
	## A band along the bottom, as printed on the discs of some consoles, and what it reads
	## instead of the platform's name; none when transparent.
	var band := Color.TRANSPARENT
	var band_text := ""
	## Made-up artwork instead of a plain colour, for demo libraries.
	var demo_art := false


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
	const _DEMO_ART := preload("res://carousel/demo_label.gdshader")
	const _LABEL_WIDTH := 512
	## A title area at least this tall, as a fraction of the label, takes the theme's font size;
	## a smaller one shrinks it.
	const _FULL_TITLE_HEIGHT := 0.22
	const _DARK_INK := Color(0.12, 0.13, 0.15)
	## How far above the platform's name the band starts, as a fraction of the label.
	const _BAND_ABOVE := 0.02

	var _fade: ModelFade
	## The label's material, and the copy it fades through: both drawn the same label.
	var _materials: Array[ShaderMaterial] = []
	var _view: SubViewport = _LABEL_VIEW.instantiate()
	var _background: ColorRect = _view.get_node("Background")
	var _title: Label = _view.get_node("Title")
	var _platform: Label = _view.get_node("Platform")
	var _band: ColorRect = _view.get_node("Band")
	var _demo_art := ShaderMaterial.new()

	func _init(model: PackedScene) -> void:
		var instance: Node3D = model.instantiate()
		add_child(instance)
		add_child(_view)
		var label: MeshInstance3D = instance.get_node("Label")
		var material: ShaderMaterial = label.get_surface_override_material(0).duplicate()
		label.set_surface_override_material(0, material)
		_fade = ModelFade.new(instance)
		_materials.assign([material, _fade.copy_of(material)])
		var face := label.get_aabb().size
		_view.size = Vector2i(_LABEL_WIDTH, roundi(_LABEL_WIDTH * face.y / face.x))
		# Where the title and the platform go is the shape's: round a disc's hub, for one.
		var title := ModelShape.TITLE_AREA
		var platform := ModelShape.PLATFORM_AREA
		if label.mesh is ShapedMesh:
			var shape := (label.mesh as ShapedMesh).shape
			title = shape.title_area()
			platform = shape.platform_area()
		var size := Vector2(_view.size)
		_title.position = size * title.position
		_title.size = size * title.size
		var font_size := ThemeDB.get_project_theme().get_font_size(&"font_size", &"LabelTitle")
		var shrink := minf(1.0, title.size.y / _FULL_TITLE_HEIGHT)
		_title.add_theme_font_size_override(&"font_size", roundi(font_size * shrink))
		_platform.position = size * platform.position
		_platform.size = size * platform.size
		# From just above the platform's name to the bottom, where the label's edge rounds it.
		_band.position = Vector2(0.0, _platform.position.y - size.y * _BAND_ABOVE)
		_band.size = Vector2(size.x, size.y - _band.position.y)
		_demo_art.shader = _DEMO_ART

	func clear_label() -> void:
		_label(&"has_label", false)

	func draw_label(title: String, look: LabelLook) -> void:
		_background.color = look.color
		_background.material = _demo_art if look.demo_art else null
		_demo_art.set_shader_parameter(&"seed", fposmod(title.hash() / 1000.0, 1.0))
		# The ink that stands out most from the label, and white with a dark outline on artwork.
		var shade := look.color.get_luminance()
		var dark := absf(shade - _DARK_INK.get_luminance()) > absf(shade - 1.0)
		var ink := _DARK_INK if dark and not look.demo_art else Color.WHITE
		for text: Label in [_title, _platform]:
			text.add_theme_color_override(&"font_color", Color(ink, 1.0 if text == _title else 0.7))
			text.add_theme_constant_override(&"outline_size", 10 if look.demo_art else 0)
		_band.visible = look.band.a > 0.0 and not look.demo_art
		_band.color = look.band
		if _band.visible:
			_platform.add_theme_color_override(&"font_color", Color.WHITE)
		_title.text = title
		_platform.text = look.band_text if _band.visible else look.platform_name
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		show_label(_view.get_texture(), false)

	## Shows [param label] as the model's label, an image of a real one when [param scanned].
	func show_label(label: Texture2D, scanned: bool) -> void:
		_label(&"label_texture", label)
		_label(&"scanned", scanned)
		_label(&"has_label", true)

	## Turns the model [param angle] radians about its own axis, its label blurred over
	## [param blur] radians as when it spins fast.
	func spin(angle: float, blur: float) -> void:
		transform = Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
		_label(&"spin_blur", blur)

	## Fades the model [param amount], from 0 (opaque) to 1 (gone).
	func fade(amount: float) -> void:
		_fade.apply(amount)

	func _label(parameter: StringName, value: Variant) -> void:
		for material in _materials:
			material.set_shader_parameter(parameter, value)
