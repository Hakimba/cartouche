# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShelfRow
extends Node3D
## The row of one shelf's games. A fixed pool of places is recycled as the row moves, so its cost
## does not depend on the number of games; a place keeps its game, and its drawn label, while the
## game stays in view. GamesLayout places its media; Motion.Spring follows each press.

## The game at the centre changed.
signal selection_changed(game: AndroidServices.Game)

## A label texture shown whole (see [method preview_label]).
const WHOLE := Rect2(0.0, 0.0, 1.0, 1.0)
## Every game [method GamesLayout.offsets] can show at once.
const _PLACES := 5

## Debug builds: turns per second of the selected game around its vertical axis, to see every side.
var turntable := 0.0
## Where label images come from; a game shows a plain blank until its image is ready, and its title
## on the blank once no source had one (INV-E11-09).
var label_images: GameArt:
	set(art):
		label_images = art
		art.loaded.connect(refresh_label)
@export var frame_origin := Vector3.ZERO
var camera: Camera3D
var games_float := false
var room_energy := 0.55
## How much of its pose and float the selected game has, from 0 (none) to 1.
var pose_amount := 1.0
## How fast the selected game floats and sways, from 1 down to 0, still ([Resting]).
var pace := 1.0
## How present the games beside the selected one are, and the selected one itself, from 0 (gone) to
## 1 (as the layout fades them).
var neighbours := 1.0
var selected_presence := 1.0
## How far the selected game has left the row to stand as [member staged] has it, from 0 to 1.
## Staged, it is still: the stick turns it, and it turns back to the front once let go.
var stage := 0.0
## Where the selected game stands once staged, in the row's space.
var staged := Transform3D.IDENTITY

var _games: Array[AndroidServices.Game] = []
## The model of each of the shelf's games' media, by medium.
var _models: Dictionary[String, PackedScene] = {}
var _look := LabelLook.new()
## The selected game's position on the endless row (see [CarouselLayout]); the scroll follows it.
var _position := 0
var _scroll := 0.0
var _spring := Motion.Spring.new(0.0)
var _title_tops: Dictionary[PackedScene, Vector3] = {}
## The direction held (-1 or 1), 0 when none.
var _held := 0
var _held_steps := 0
var _next_repeat_s := 0.0
var _clock_s := 0.0
## How far the selected game's float and sway have gone, in seconds at full pace.
var _pose_s := 0.0
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
## Whether the selected game shows another label than its own (see [method preview_label]): its own
## image arriving meanwhile waits.
var _previewing := false
## The games whose label downloads, by id: how much of it is read, from 0 to 1, or below 0 when its
## size is unknown (see [method downloading]).
var _downloads: Dictionary[String, float] = {}


## Stops a row between steps at its selected position before another screen opens.
func is_settling() -> bool:
	return not is_equal_approx(_scroll, float(_position))


func settle() -> void:
	_scroll = float(_position)
	_spring = Motion.Spring.new(_scroll)
	_arrange()


func _ready() -> void:
	for i in _PLACES:
		var place := Place.new()
		add_child(place)
		_places.append(place)
	add_to_group(Resting.PACED)
	# Nothing moves before a shelf is shown.
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		for place in _places:
			place.hide_view()


func _process(delta: float) -> void:
	_clock_s += delta
	_pose_s += delta * pace
	if _held != 0 and _clock_s >= _next_repeat_s:
		step(_held)
		_held_steps += 1
		_next_repeat_s = _clock_s + CarouselLayout.repeat_delay(_held_steps)
	_spring.target = _position
	_spring.step(delta)
	_scroll = _spring.position
	if not _games.is_empty():
		if stage > 0.0 and _stick.is_zero_approx():
			_turn.release()
		_turn.follow(_stick, selected_index(), delta)
	_arrange()
	if not _unlabelled.is_empty():
		var place: Place = _unlabelled.pop_front()
		if place.game >= 0:
			var game := _games[place.game]
			if not _show_image(place, game):
				_draw_blank(place, game)
	if not _downloads.is_empty():
		_turn_rings(delta)


## Frees every place's model of a medium not among [param models]: no game of the library comes in
## it any more.
func keep_models(models: Array[PackedScene]) -> void:
	for model: PackedScene in _title_tops.keys():
		if model not in models:
			_title_tops.erase(model)
	for place in _places:
		place.keep_models(models)


## Shows [param games] (in shelf order) from index [param selected], each on the model of its medium
## in [param models] (by [member AndroidServices.Game.medium]), with labels of [param look]. Every
## place's model of each of them is made now, if not yet, rather than as a game of it comes into
## view: making one takes about 2 ms on a handheld, its first one 10 to 30 ms.
func show_shelf(games: Array[AndroidServices.Game], selected: int, models: Dictionary[String, PackedScene],
		look: LabelLook) -> void:
	_models = models
	_look = look
	for place in _places:
		for model: PackedScene in models.values():
			place.use_model(model)
	# Another shelf, or the same one again after a change: no label is kept, and the downloads under
	# way tell themselves again at their next progress.
	_placed.clear()
	_downloads.clear()
	set_process(true)
	show_games(games, selected)


## Shows [param games] instead, at least one, on the same models: the shelf's games found by a
## search, or all of them again, from index [param selected]. A game still in view keeps its place
## and its label.
func show_games(games: Array[AndroidServices.Game], selected: int) -> void:
	var kept: Dictionary[String, Place] = {}
	for game: int in _placed:
		kept[_games[game].id] = _placed[game]
	_games = games
	_position = selected
	_scroll = selected
	_spring = Motion.Spring.new(selected)
	_turn = StickTurn.new()
	_held = 0
	_placed.clear()
	for place in _places:
		place.game = -1
	for game: int in GamesLayout.offsets(_games.size(), _scroll):
		var place: Place = kept.get(_games[game].id)
		if place:
			place.game = game
			_placed[game] = place
	_unlabelled = _unlabelled.filter(func(place: Place) -> bool: return place.game >= 0)
	_arrange()


## Brings the game at [param index] to the centre at once, the row sliding in from [param slide]
## places before it, towards [param direction] (-1 or 1).
func jump(index: int, direction: int, slide: float) -> void:
	var ahead := posmod(index - _position, _games.size())
	_position += ahead if ahead * 2 <= _games.size() else ahead - _games.size()
	_scroll = _position - direction * slide
	_spring = Motion.Spring.new(_scroll)
	_turn.release()
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "jump to %d" % selected_index())
	selection_changed.emit(selected_game())


## The selected game, then the [param reach] games on each side of it, nearest first, each once.
func games_around(reach: int) -> Array[AndroidServices.Game]:
	var around: Array[AndroidServices.Game] = [selected_game()]
	for offset in range(1, reach + 1):
		for side: int in [offset, -offset]:
			var game := _games[posmod(_position + side, _games.size())]
			if game not in around:
				around.append(game)
	return around


## Whether the shelf has games; the other methods need one.
func has_games() -> bool:
	return not _games.is_empty()


func selected_game() -> AndroidServices.Game:
	return _games[selected_index()]


## The selected game's position on the endless row: its index, plus the laps made.
func selected_position() -> int:
	return _position


func selected_index() -> int:
	return posmod(_position, _games.size())


## Steps once towards [param direction] (-1 or 1), then again and again, faster, until
## [method release].
func hold(direction: int) -> void:
	step(direction)
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


## Turns the selected game with a finger dragged [param pixels] over it; it comes back to the
## front once [method let_go] (see [StickTurn]).
func touch_turn(pixels: Vector2) -> void:
	_turn.touch(pixels)


func let_go() -> void:
	_turn.let_go()


## Stops every move under way: a held direction, the stick. The selection stays where it is.
func freeze() -> void:
	_held = 0
	_stick = Vector2.ZERO
	# A selected game still out of view has no place to launch from: the row lands on it at once. One in
	# view keeps its spring, which finishes under the launch.
	if has_games() and selected_index() not in _placed:
		_scroll = _position
		_spring = Motion.Spring.new(_scroll)
		_arrange()


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


## Shows [param label], an image of a real label, on the selected game instead of its own, until
## [method show_own_label]; only its [param window] when given, as fractions of it.
func preview_label(label: Texture2D, window := WHOLE) -> void:
	var place: Place = _placed.get(selected_index())
	if place:
		_previewing = true
		place.shown.show_label(label, true, window)


## How the selected game's model is brought from its size in the row to its real size, in its own
## frame: as it stands on a console's seat.
func selected_real_size() -> Transform3D:
	var place: Place = _placed.get(selected_index())
	return place.shown.to_real_size if place else Transform3D.IDENTITY


## The width of the selected game's label over its height: of the model of its medium.
func selected_label_proportion() -> float:
	var place: Place = _placed.get(selected_index())
	return place.shown.label_proportion if place else 1.0


## The selected game shows its own label again, after [method preview_label].
func show_own_label() -> void:
	_previewing = false
	var place: Place = _placed.get(selected_index())
	if place and not _show_image(place, selected_game()):
		_draw_blank(place, selected_game())


## [param game_id]'s label downloads, [param fraction] of it read (below 0 when its size is
## unknown): while the game is in view on its blank, a ring fills there, until [method downloaded].
func downloading(game_id: String, fraction: float) -> void:
	_downloads[game_id] = fraction
	_show_ring(game_id)


## [param game_id]'s download is over: its ring goes.
func downloaded(game_id: String) -> void:
	if _downloads.erase(game_id):
		Sounds.play(SoundEffects.Cue.ART_DONE)
		_show_ring(game_id)


## Shows [param game_id]'s image on its place, once read, if the game is in view: it replaces the
## blank drawn there; without one, once no source had one, its title is written on the blank.
func refresh_label(game_id: String) -> void:
	for place: Place in _placed.values():
		if _previewing and place.game == selected_index():
			continue
		var game := _games[place.game]
		if game.id != game_id or place in _unlabelled:
			continue
		if not _show_image(place, game) and label_images.is_absent(game):
			_draw_blank(place, game)


## Shows [param game]'s image on [param place] when it is read; otherwise asks for it and is false.
func _show_image(place: Place, game: AndroidServices.Game) -> bool:
	if label_images.has_texture(game):
		place.shown.show_label(label_images.texture(game), true)
		return true
	label_images.request(game)
	return false


## Draws [param game]'s blank on [param place]: plain until no source had an image of it, then
## with its title; made-up artwork, never looked for, always has it. Its download's ring shows on it.
func _draw_blank(place: Place, game: AndroidServices.Game) -> void:
	place.shown.ring(_download(game.id))
	place.shown.draw_label(game.title if _look.demo_art or label_images.is_absent(game) else "", _look)


## Shows the ring of [param game_id]'s download, or none, on its place once its label is drawn.
func _show_ring(game_id: String) -> void:
	for place: Place in _placed.values():
		if _games[place.game].id == game_id and place not in _unlabelled:
			place.shown.ring(_download(game_id))


## Turns the rings of downloads of unknown size, on the places in view.
func _turn_rings(delta: float) -> void:
	for place: Place in _placed.values():
		if _download(_games[place.game].id) < 0.0 and place not in _unlabelled:
			place.shown.turn_ring(delta)


## How much of [param game_id]'s label is read, as [method downloading] was told; NAN when none
## downloads.
func _download(game_id: String) -> float:
	return _downloads.get(game_id, NAN)


## One step towards [param direction] (-1 or 1); a direction held stays held.
func step(direction: int) -> void:
	if _games.size() < 2:
		return
	Sounds.play(SoundEffects.Cue.GAME)
	_position += direction
	_turn.release()
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "step %d to %d (held for %d steps)" % [direction, selected_index(), _held_steps])
	selection_changed.emit(selected_game())


func _arrange() -> void:
	var shown := GamesLayout.offsets(_games.size(), _scroll)
	for game: int in _placed.keys():
		if game not in shown:
			_placed[game].game = -1
			_placed.erase(game)
	for game: int in shown:
		if game not in _placed:
			var place := _free_place()
			place.game = game
			place.use_model(_models[_games[game].medium])
			place.shown.clear_label()
			_placed[game] = place
			if place not in _unlabelled:
				_unlabelled.append(place)
	var blank_weight := 0.0
	for game: int in shown:
		var place := _placed[game]
		if place.shown.is_blank():
			blank_weight += 1.0 - MediaView.softness(shown[game])
	var focused: Place = _placed.get(selected_index())
	if focused:
		room_energy = lerpf(focused.lit.room, focused.blank.room, blank_weight)
	var gone := selected_presence <= 0.0 and neighbours <= 0.0 and stage <= 0.0 and not _launched
	var order := 0
	for place in _places:
		place.visible = place.game >= 0
		if not place.visible:
			place.hide_view()
	for game: int in shown:
		var place := _placed[game]
		if gone:
			place.shown.fade(1.0)
			place.hide_view()
			continue
		var offset: float = shown[game]
		var centred := 1.0 - MediaView.softness(offset)
		var turn := Basis(Vector3.UP, TAU * turntable * _clock_s * centred) * _turn.of(game)
		var placed := place.layout.standing(offset, pose_amount, _pose_s, games_float)
		placed.origin += frame_origin
		placed.basis *= turn
		var outside := (_launched or stage > 0.0) and game == selected_index()
		if _launched and game == selected_index():
			placed = _launch_stand
			place.shown.spin(_launch_spin, _launch_blur)
		elif stage > 0.0 and game == selected_index():
			placed = placed.interpolate_with(Transform3D(staged.basis * turn, staged.origin), stage)
		if place.transform != placed:
			place.transform = placed
		var presence := selected_presence if game == selected_index() else neighbours
		place.shown.fade(1.0 - presence if not _launched or game != selected_index() else 0.0)
		var mode := Place.Draw.OUTSIDE if outside else Place.Draw.SHOWN if is_visible_in_tree() else Place.Draw.HIDDEN
		place.draw_at(global_transform * placed, MediaView.softness(offset), blank_weight, mode, order - _PLACES)
		order += 1


## The title's resting top through the screen camera, cached per fitted model with the canvas size
## it was measured for (x, y, then the top). While the properties lend the model out it cannot be
## measured again: the last top stands.
func title_top() -> float:
	var frame := camera.get_viewport().get_visible_rect().size if camera else CarouselLayout.FRAME
	var model := _models[selected_game().medium]
	var place: Place = _placed.get(selected_index())
	var kept: Vector3 = _title_tops.get(model, Vector3(NAN, NAN, 0.0))
	var instance := place.shown.get_child(0) as Node3D if place else null
	if Vector2(kept.x, kept.y) != frame and instance:
		var layout := GamesLayout.new(ConsoleManifest.folder_of(model))
		kept = Vector3(frame.x, frame.y, TitlePlace.top(TitlePlace.vertices(instance),
			layout.chosen, camera.global_transform if camera else TitlePlace.CAMERA, frame, camera.fov if camera else 32.0))
		_title_tops[model] = kept
	return kept.z


func _free_place() -> Place:
	for place in _places:
		if place.game < 0:
			return place
	# Unreachable: there are as many places as games shown at once.
	push_error("ShelfRow: no free place")
	return _places[0]


## How the selected game is shown: leaning back and turned as told, it sways slowly so that the
## light moves over it, and floats [member bob] high (world units). Angles in degrees.
class Pose:
	var tilt := 0.0
	var turn := 0.0
	var sway := 0.0
	var sway_period_s := 6.0
	var bob := CarouselLayout.BOB_HEIGHT

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


## One game's place in the row, showing the model of its game's medium. Each medium's model is kept
## once made, until the library has no game of it, so that another game or shelf only shows another
## one.
class Place extends Node3D:
	## Index of the game shown here, -1 when the place is free.
	var game := -1
	var shown: LabelledModel
	var _models: Dictionary[PackedScene, LabelledModel] = {}
	var layout: GamesLayout
	var lit: StudioLights.Rig
	var blank: StudioLights.Rig
	## One view per place, kept while the place lives: a place is reused by the games of the row, not
	## made again at each move.
	var media_view: MediaView
	var _blank_weight := -1.0

	## Frees its models of the media not among [param models].
	func keep_models(models: Array[PackedScene]) -> void:
		for model: PackedScene in _models.keys():
			if model not in models:
				if _models[model] == shown and media_view:
					shown.reparent(self, false)
					media_view.free()
					media_view = null
				_models[model].free()
				_models.erase(model)

	## Shows [param model], made the first time it is used here.
	func use_model(model: PackedScene) -> void:
		if model in _models and _models[model] == shown:
			return
		if media_view:
			shown.reparent(self, false)
			media_view.free()
			media_view = null
		if model not in _models:
			_models[model] = LabelledModel.new(model)
			add_child(_models[model])
			var instance := _models[model].get_child(0) as Node3D
			instance.transform = TitlePlace.fitting(instance) * instance.transform
			_models[model].to_real_size = instance.transform.affine_inverse()
		shown = _models[model]
		for made: LabelledModel in _models.values():
			made.visible = made == shown
		var medium := ConsoleManifest.folder_of(model)
		layout = GamesLayout.new(medium)
		lit = StudioLights.rig_of(medium, &"games")
		blank = StudioLights.rig_of(medium, &"games", true)

	func hide_view() -> void:
		if media_view:
			media_view.hide()
			media_view.set_process(false)
			media_view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED

	## Where its medium is drawn: in its own view, in the main world (the launch has it outside the
	## row), or nowhere.
	enum Draw { SHOWN, OUTSIDE, HIDDEN }

	func draw_at(at: Transform3D, softness: float, weight: float, mode: Draw, order: int) -> void:
		var camera := (get_parent() as ShelfRow).camera
		if not camera:
			return
		if mode == Draw.OUTSIDE:
			if media_view and shown.get_parent() != self:
				shown.reparent(self, false)
			hide_view()
			return
		if mode == Draw.HIDDEN:
			hide_view()
			return
		if not media_view:
			media_view = MediaView.new()
			media_view.camera = camera
			add_child(media_view)
			remove_child(shown)
			media_view.show_medium(shown, lit, blank)
			_blank_weight = -1.0
		elif shown.get_parent() == self:
			shown.reparent(media_view.holder(), false)
			shown.dirty = true
		var redraw := shown.dirty or not media_view.visible
		media_view.show()
		media_view.set_process(true)
		media_view.z_index = order
		# A change below one percent relights nothing visible; the ends are still reached exactly.
		if weight != _blank_weight and (absf(weight - _blank_weight) >= 0.01 or weight in [0.0, 1.0]):
			media_view.crossfade(weight)
			_blank_weight = weight
		media_view.place(at, softness)
		if redraw:
			media_view.view().render_target_update_mode = SubViewport.UPDATE_ONCE
		shown.dirty = false


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

	## How many are alive, each with its label's viewport, for the traces.
	static var alive := 0

	## The width of the model's label face over its height.
	var label_proportion := 1.0
	## Brings the model from its size in the row to its real size, in its own frame: its root's
	## transform undone.
	var to_real_size := Transform3D.IDENTITY

	var _fade: ModelFade
	## The model's label, drawn with a material of its own.
	var _label_mesh: MeshInstance3D
	var _view: SubViewport = _LABEL_VIEW.instantiate()
	var _background: ColorRect = _view.get_node("Background")
	var _title: Label = _view.get_node("Title")
	var _platform: Label = _view.get_node("Platform")
	var _band: ColorRect = _view.get_node("Band")
	var _ring := ProgressRing.new()
	var _demo_art := ShaderMaterial.new()
	## Whether its label shows the blank drawn in its viewport, not an image.
	var _blank := false
	var dirty := true
	var _blur := 0.0

	func _init(model: PackedScene) -> void:
		alive += 1
		var instance: Node3D = model.instantiate()
		add_child(instance)
		to_real_size = instance.transform.affine_inverse()
		add_child(_view)
		var label: MeshInstance3D = instance.get_node("Label")
		var material: ShaderMaterial = label.get_surface_override_material(0).duplicate()
		label.set_surface_override_material(0, material)
		_label_mesh = label
		_fade = ModelFade.new(instance)
		var face := label.get_aabb().size
		# To a ten-thousandth: a disc's face, built round, is square.
		label_proportion = snappedf(face.x / face.y, 0.0001)
		_view.size = Vector2i(_LABEL_WIDTH, roundi(_LABEL_WIDTH / label_proportion))
		# Where the title and the platform go is the shape's: round a disc's hub, for one.
		var title := ModelShape.TITLE_AREA
		var platform := ModelShape.PLATFORM_AREA
		if label.mesh is ShapedMesh:
			var shape := (label.mesh as ShapedMesh).shape
			title = shape.title_area()
			platform = shape.platform_area()
			_ring.radius = shape.progress_ring_radius()
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
		_ring.size = size
		_ring.hide()
		_view.add_child(_ring)
		_demo_art.shader = _DEMO_ART

	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			alive -= 1

	func is_blank() -> bool:
		return _blank

	func clear_label() -> void:
		_label(&"has_label", false)
		_blank = false

	## Draws a blank of [param look] with [param title] and the platform's name; plain, with
	## neither, nor the band holding it, when [param title] is empty.
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
		# The band carries the platform's name: a plain blank has none, its ring takes the band's colour.
		var banded := look.band.a > 0.0 and not look.demo_art
		_band.visible = banded and not title.is_empty()
		_band.color = look.band
		if _band.visible:
			_platform.add_theme_color_override(&"font_color", Color.WHITE)
		_title.text = title
		_platform.text = "" if title.is_empty() else look.band_text if _band.visible else look.platform_name
		_ring.color = look.band if banded else ink
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE
		show_label(_view.get_texture(), false)

	## Shows on the blank the ring of a download [param fraction] read (below 0 when its size is
	## unknown), or none when NAN; the blank shown is drawn again.
	func ring(fraction: float) -> void:
		_ring.visible = not is_nan(fraction)
		_ring.fraction = fraction
		_redraw_ring()

	## Turns the ring of a download of unknown size by [param delta] seconds.
	func turn_ring(delta: float) -> void:
		_ring.turn = fposmod(_ring.turn + delta * TAU, TAU)
		_redraw_ring()

	func _redraw_ring() -> void:
		dirty = dirty or _blank
		_ring.queue_redraw()
		if _blank:
			_view.render_target_update_mode = SubViewport.UPDATE_ONCE

	## Shows [param label] as the model's label, an image of a real one when [param scanned]; only
	## its [param window] when given, as fractions of it, and of that, the middle of the label's
	## proportions: an image of another shape (a Famicom's label on an NES cartridge) covers the
	## label, cut, never stretched.
	func show_label(label: Texture2D, scanned: bool, window := WHOLE) -> void:
		var pixels := Vector2(label.get_size()) * window.size
		var cover := window.size
		if pixels.x > 0.0 and pixels.y > 0.0:
			var wider := pixels.x / pixels.y / label_proportion
			cover *= Vector2(minf(1.0, 1.0 / wider), minf(1.0, wider))
		var shown := Rect2(window.get_center() - cover / 2.0, cover)
		_label(&"label_texture", label)
		_label(&"label_window", Vector4(shown.position.x, shown.position.y, shown.size.x, shown.size.y))
		_label(&"scanned", scanned)
		_label(&"has_label", true)
		_blank = not scanned

	## Turns the model [param angle] radians about its own axis, its label blurred over
	## [param blur] radians as when it spins fast.
	func spin(angle: float, blur: float) -> void:
		var turned := Transform3D(Basis(Vector3.BACK, angle), Vector3.ZERO)
		dirty = dirty or transform != turned
		transform = turned
		# Told every frame while it stands launched: only a blur that changed is a look that changed.
		if blur != _blur:
			_blur = blur
			_label(&"spin_blur", blur)

	## Fades the model [param amount], from 0 (opaque) to 1 (gone).
	func fade(amount: float) -> void:
		dirty = dirty or _fade.amount != amount
		_fade.apply(amount)

	func _label(parameter: StringName, value: Variant) -> void:
		dirty = true
		_fade.set_shader_value(_label_mesh, parameter, value)
