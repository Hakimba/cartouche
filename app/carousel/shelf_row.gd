# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShelfRow
extends Node3D
## The row of one shelf's games. A fixed pool of places is recycled as the row moves, so its cost
## does not depend on the number of games; a place keeps its game, and its drawn label, while the
## game stays in view. GamesLayout places its media; Motion.Spring follows each press.

## The game at the centre changed.
signal selection_changed(game: AndroidServices.Game)

@export var frame_origin := Vector3.ZERO

## Debug builds: turns per second of the selected game around its vertical axis, to see every side.
var turntable := 0.0
## Where label images come from; a game shows a plain blank until its image is ready, and its title
## on the blank once no source had one.
var label_images: GameArt:
	set(art):
		label_images = art
		art.loaded.connect(refresh_label)
var camera: Camera3D
var games_float := false
## Whether the games stand in a straight line on a screen whose shelf is an arc, as on the wider ones.
var games_in_line := false
var room_energy := 0.55
## How much of its pose and float the selected game has, from 0 (none) to 1.
var pose_amount := 1.0
## How fast the selected game floats and sways, from 1 down to 0, still ([Resting]).
var pace := 1.0
## How present the games beside the selected one are, and the selected one itself, from 0 (gone) to
## 1 (as the layout fades them).
var neighbours := 1.0
var selected_presence := 1.0
## Draws the pick.
var random := RandomNumberGenerator.new()
var _games: Array[AndroidServices.Game] = []
var _models: Dictionary[String, PackedScene] = {}
var _look := LabelLook.new()
## The selected game's position on the endless row (see [CarouselLayout]); the scroll follows it.
var _position := 0
var _scroll := 0.0
## What the last [method _process] arranged: whether the row stood out of sight, where it scrolled, the labels' edits.
var _arranged_out := false
var _arranged_scroll := 0.0
var _arranged_edits := 0
var _spring := Motion.Spring.new(0.0)
var _title_tops: Dictionary[PackedScene, Vector3] = {}
## The direction held (-1 or 1), 0 when none.
var _held := 0
var _repeat := CarouselLayout.Repeat.new()
var _clock_s := 0.0
## How far the selected game's float and sway have gone, in seconds at full pace.
var _pose_s := 0.0
var _stick := Vector2.ZERO
var _selected_in_row := Transform3D.IDENTITY
var _turn := StickTurn.new()
var _places: Array[ShelfPlace] = []
## How many places from the centre the row draws its games ([method _fit_width]).
var _within := MediaView.DRAWN_WITHIN
## Whether the games past the neighbours stand at their height ([member ScreenLayout.Format.shelf_level]).
var _level := false
var _placed: Dictionary[int, ShelfPlace] = {}
## Places waiting for their label, drawn one per frame so that a fast move never stalls.
var _unlabelled: Array[ShelfPlace] = []
## The games gone out of view while their label was read, as the row's indices: their read stops once the row is far.
var _reads_left: Dictionary[int, bool] = {}
## How the selected game stands ([method stand]): posed in the row until told otherwise.
var _stand := SelectedStand.new()
## How many times the row was arranged: a place not shown in the latest arrangement is free.
var _arrangements := 0
## Whether the selected game shows another label than its own (see [method preview_label]): its own
## image arriving meanwhile waits.
var _previewing := false
## The games whose label downloads, by id: how much of it is read, from 0 to 1, or below 0 when its
## size is unknown (see [method downloading]).
var _downloads: Dictionary[String, float] = {}
## A game other than the selected one, drawn at random as the row shows its games and once it is selected, -1 with
## fewer than two (see [method read_pick]).
var _pick := -1


func is_settling() -> bool:
	return not is_equal_approx(_scroll, float(_position))


## Stops a row between steps at its selected position before another screen opens.
func settle() -> void:
	_scroll = float(_position)
	_spring = Motion.Spring.new(_scroll)
	arrange()


func _ready() -> void:
	get_viewport().size_changed.connect(func() -> void:
		_fit_width()
		if not _games.is_empty():
			arrange())
	_fit_width()
	add_to_group(Resting.PACED)
	# Nothing moves before a shelf is shown.
	set_process(false)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		for place in _places:
			place.hide_view()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		# The game launched kept its view's pictures for its way back: away, they go.
		if _stand.mode == SelectedStand.Mode.OUTSIDE and _selected_place():
			_selected_place().hide_view()
		if label_images:
			_keep_needed_labels()


func _process(delta: float) -> void:
	_clock_s += delta
	_pose_s += delta * pace
	if _held != 0 and _repeat.due(delta):
		step(_held)
	_spring.target = _position
	_spring.step(delta)
	_scroll = _spring.position
	if not _games.is_empty():
		if _stand.amount > 0.0 and _stick.is_zero_approx():
			_turn.release()
		_turn.follow(_stick, selected_index(), delta)
	# Out of sight and still, the arrangement stands: only a label read since (it sets the room's light) changes it.
	var out := not is_visible_in_tree() or (selected_presence <= 0.0 and neighbours <= 0.0 and _stand.amount <= 0.0
			and _stand.mode != SelectedStand.Mode.OUTSIDE)
	var still := out and _arranged_out and _scroll == _arranged_scroll and _held == 0 and _spring.is_still() \
			and LabelledModel.label_edits == _arranged_edits
	if not still:
		arrange()
	_arranged_out = out
	_arranged_scroll = _scroll
	_arranged_edits = LabelledModel.label_edits
	if not _unlabelled.is_empty():
		var place: ShelfPlace = _unlabelled.pop_front()
		if game_at(place) >= 0:
			_label(place)
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
	var kept: Dictionary[String, ShelfPlace] = {}
	for game: int in _placed:
		kept[_games[game].id] = _placed[game]
	_games = games
	_reads_left.clear()
	_position = selected
	_scroll = selected
	_spring = Motion.Spring.new(selected)
	_turn = StickTurn.new()
	_held = 0
	_placed.clear()
	_fit_width()
	for game: int in GamesLayout.offsets(_games.size(), _scroll, _within):
		var place: ShelfPlace = kept.get(_games[game].id)
		if place:
			_placed[game] = place
	_unlabelled = _unlabelled.filter(func(place: ShelfPlace) -> bool: return game_at(place) >= 0)
	_draw_pick()
	arrange()


## Brings the game at [param index] to the centre at once, the row sliding in from [param slide]
## places before it, towards [param direction] (-1 or 1).
func jump(index: int, direction: int, slide: float) -> void:
	var ahead := posmod(index - _position, _games.size())
	_position = _on_row(_position + (ahead if ahead * 2 <= _games.size() else ahead - _games.size()))
	_scroll = _position - direction * slide
	_spring = Motion.Spring.new(_scroll)
	_turn.release()
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "jump to %d" % selected_index())
	_selected()


## Whether the row has a pick: two games or more.
func has_pick() -> bool:
	return _pick >= 0


## The game [method select_pick] selects.
func pick() -> AndroidServices.Game:
	return _games[_pick]


## Starts reading the labels the pick lands among, its own and its neighbours', unless kept or being read: asked as
## the row comes to rest and as a toss starts, they are kept still when [method select_pick] shows them.
func read_pick() -> void:
	if has_pick():
		for side: int in [0, -1, 1]:
			label_images.request(_games[posmod(_pick + side, _games.size())])


## Selects the pick in place, the row standing still: the game in the middle becomes it, among its own
## neighbours, its label shown at once rather than in turn.
func select_pick() -> void:
	jump(_pick, 1, 0.0)
	arrange()
	var place := _placed[selected_index()]
	if _unlabelled.has(place):
		_unlabelled.erase(place)
		_label(place)


## The selected game, then the [param reach] games on each side of it, nearest first, each once.
func games_around(reach: int) -> Array[AndroidServices.Game]:
	var around: Array[AndroidServices.Game] = [selected_game()]
	for offset in range(1, reach + 1):
		for side: int in [offset, -offset]:
			var game := _games[posmod(_position + side, _games.size())]
			if game not in around:
				around.append(game)
	return around


## Whether a game of the row stands in the carousel's own world, out of its view (launched, its properties), where
## the carousel's camera draws it.
func stands_outside() -> bool:
	return is_visible_in_tree() and _places.any(func(place: ShelfPlace) -> bool:
		return place.visible and place.shown != null and place.shown.get_parent() == place)


## Whether the shelf has games; the other methods need one.
func has_games() -> bool:
	return not _games.is_empty()


func selected_game() -> AndroidServices.Game:
	return _games[selected_index()]


## The medium the selected game is shown as: its own, or its kind's when it has no folder.
func selected_medium() -> String:
	return ConsoleManifest.folder_of(_models[selected_game().medium])


## The selected game's position on the endless row: its index, plus the laps made.
func selected_position() -> int:
	return _position


func selected_index() -> int:
	return posmod(_position, _games.size())


## Index of the game [param place] shows, -1 when the place is free.
func game_at(place: ShelfPlace) -> int:
	var game: Variant = _placed.find_key(place)
	return game if game is int else -1


## Steps once towards [param direction] (-1 or 1), then again and again, faster, until
## [method release].
func hold(direction: int) -> void:
	step(direction)
	_held = direction
	_repeat.start()


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
		arrange()


## Stands the selected game as [param selected] says, until told otherwise; a new [SelectedStand] poses it in the
## row again. Its drivers, the toss, a launch and the properties, never overlap ([CarouselState] lets one of them
## run at a time), so one value holds what each of them tells.
func stand(selected: SelectedStand) -> void:
	var back := _stand.mode == SelectedStand.Mode.OUTSIDE and selected.mode != SelectedStand.Mode.OUTSIDE
	_stand = selected
	if back:
		var place := _selected_place()
		if place:
			# What its drive turned it by stays on the model: undone as it comes back.
			place.shown.spin(0.0, 0.0)


## What [method stand] was last told.
func standing() -> SelectedStand:
	return _stand


## How the selected game stands now, in the row's space.
func selected_stand() -> Transform3D:
	var place := _selected_place()
	return place.transform if place else Transform3D.IDENTITY


## Where the row poses the selected game now, in its space, wherever its drive has it stand meanwhile.
func selected_in_row() -> Transform3D:
	return _selected_in_row


## Shows [param label], an image of a real label, on the selected game instead of its own, until
## [method show_own_label]; only its [param window] when given, as fractions of it.
func preview_label(label: Texture2D, window := LabelledModel.WHOLE) -> void:
	var place := _selected_place()
	if place:
		_previewing = true
		place.shown.show_label(label, window)


## How the selected game's model is brought from its size in the row to its real size, in its own
## frame: as it stands on a console's seat.
func selected_real_size() -> Transform3D:
	var place := _selected_place()
	return place.shown.to_real_size if place else Transform3D.IDENTITY


## The width of the selected game's label over its height: of the model of its medium.
func selected_label_proportion() -> float:
	var place := _selected_place()
	return place.shown.label_proportion if place else 1.0


## The selected game's labelled model, still whole in its place, for its properties: the row only finds it. They
## measure it where it stands, then take its model out themselves ([method LabelledModel.lend]) until
## [method LabelledModel.take_back]. None when the game has no place or its model is out already.
func lend_selected() -> LabelledModel:
	var place := _selected_place()
	return place.shown if place and not place.shown.is_lent() else null


## The selected game shows its own label again, after [method preview_label].
func show_own_label() -> void:
	_previewing = false
	var place := _selected_place()
	if place:
		_label(place)


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
	for index: int in _placed:
		var place := _placed[index]
		if _previewing and index == selected_index():
			continue
		var game := _games[index]
		if game.id != game_id or place in _unlabelled:
			continue
		if not _show_image(place, game) and label_images.is_absent(game):
			_draw_blank(place, game)


## As the app leaves the screen, a game running: only the labels in view, and those the pick lands among, keep their
## picture; the places' other labels let theirs go, and so do the views of the places not drawn. Each is read or drawn
## again once the row comes to it.
func _keep_needed_labels() -> void:
	var needed: Array[AndroidServices.Game] = []
	for game: int in _placed:
		needed.append(_games[game])
	if has_pick():
		for side: int in [0, -1, 1]:
			needed.append(_games[posmod(_pick + side, _games.size())])
	for place in _places:
		var free := game_at(place) < 0
		if free or not is_visible_in_tree():
			place.hide_view()
		if free and place.shown:
			place.shown.clear_label()
	label_images.keep_textures(needed)
	Diagnostics.trace("memory", "label views: %d alive, %d holding a blank; media views: %d holding pictures" % [
		LabelledModel.alive, LabelledModel.held_views, MediaView.holding])


## Shows its game's image on [param place], or its blank until the image is read.
func _label(place: ShelfPlace) -> void:
	var game := _games[game_at(place)]
	if not _show_image(place, game):
		_draw_blank(place, game)


## Shows [param game]'s image on [param place] when it is read; otherwise asks for it and is false.
func _show_image(place: ShelfPlace, game: AndroidServices.Game) -> bool:
	if label_images.has_texture(game):
		place.shown.show_label(label_images.texture(game))
		return true
	label_images.request(game)
	return false


## Draws [param game]'s blank on [param place]: plain until no source had an image of it, then
## with its title; made-up artwork, never looked for, always has it. Its download's ring shows on it.
func _draw_blank(place: ShelfPlace, game: AndroidServices.Game) -> void:
	place.shown.ring(_download(game.id))
	place.shown.draw_label(game.title if _look.demo_art or label_images.is_absent(game) else "", _look)


func _show_ring(game_id: String) -> void:
	for game: int in _placed:
		var place := _placed[game]
		if _games[game].id == game_id and place not in _unlabelled:
			place.shown.ring(_download(game_id))


func _turn_rings(delta: float) -> void:
	for game: int in _placed:
		var place := _placed[game]
		if _download(_games[game].id) < 0.0 and place not in _unlabelled:
			place.shown.turn_ring(delta)


## How much of [param game_id]'s label is read, as [method downloading] was told; NAN when none
## downloads.
func _download(game_id: String) -> float:
	return _downloads.get(game_id, NAN)


## Stops the label reads of the games the row went far from, the pick and its neighbours aside: on a long scroll each
## would only be decoded and sent to the GPU to be dropped before the row came back to it.
func _stop_far_reads(shown: Dictionary[int, float]) -> void:
	for game: int in _reads_left.keys():
		if game in shown or not label_images.is_reading(_games[game]) or has_pick() and _away(_pick, game) <= 1 \
				or label_images.cancel_far(_games[game], _away(selected_index(), game)):
			_reads_left.erase(game)


## How many games apart [param from] and [param game] stand on the endless row, the shorter way.
func _away(from: int, game: int) -> int:
	return mini(posmod(game - from, _games.size()), posmod(from - game, _games.size()))


## [param at] as the row counts it: any whole number round the ring, the first or the second of two games
## side by side ([method GamesLayout.offsets]), so that either way from one leads to the other.
func _on_row(at: int) -> int:
	return posmod(at, 2) if _games.size() == 2 else at


## One step towards [param direction] (-1 or 1); a direction held stays held.
func step(direction: int) -> void:
	if _games.size() < 2:
		return
	Sounds.play(SoundEffects.Cue.GAME)
	_position = _on_row(_position + direction)
	_turn.release()
	if Diagnostics.enabled:
		Diagnostics.trace("carousel", "step %d to %d (held for %d steps)" % [direction, selected_index(), _repeat.steps])
	_selected()


func _selected() -> void:
	if selected_index() == _pick:
		_draw_pick()
	selection_changed.emit(selected_game())


func _draw_pick() -> void:
	var count := _games.size()
	_pick = posmod(selected_index() + random.randi_range(1, count - 1), count) if count > 1 else -1


## Stands and draws the games as the row's values have it now, rather than at its next frame.
func arrange() -> void:
	var shown := GamesLayout.offsets(_games.size(), _scroll, _within)
	for game: int in _placed.keys():
		if game not in shown:
			_placed.erase(game)
			if label_images.is_reading(_games[game]):
				_reads_left[game] = true
	_stop_far_reads(shown)
	for game: int in shown:
		if game not in _placed:
			var place := _free_place()
			place.use_model(_models[_games[game].medium])
			place.shown.clear_label()
			_placed[game] = place
			if place not in _unlabelled:
				_unlabelled.append(place)
	_arrangements += 1
	var blank_weight := 0.0
	for game: int in shown:
		var place := _placed[game]
		place.visible = true
		place.arranged = _arrangements
		if place.shown.is_blank():
			blank_weight += 1.0 - MediaView.softness(shown[game])
	var focused := _selected_place()
	if focused:
		room_energy = lerpf(focused.lit.room, focused.blank.room, blank_weight)
	var stood_outside := _stand.mode == SelectedStand.Mode.OUTSIDE
	var gone := selected_presence <= 0.0 and neighbours <= 0.0 and _stand.amount <= 0.0 and not stood_outside
	var order := 0
	# A free place keeps its view's pictures for the game coming in only while the row moves: at rest, none comes.
	var moving := _held != 0 or not _spring.is_still()
	for place in _places:
		if place.arranged != _arrangements:
			place.visible = false
			place.hide_view(moving)
	for game: int in shown:
		var place := _placed[game]
		if gone:
			place.shown.visible = false
			place.hide_view()
			continue
		var offset: float = shown[game]
		var centred := 1.0 - MediaView.softness(offset)
		var turn := Basis(Vector3.UP, TAU * turntable * _clock_s * centred) * _turn.of(game)
		var placed := place.layout.standing(offset, pose_amount, _pose_s, games_float, _level or games_in_line)
		placed.origin += frame_origin
		placed.basis *= turn
		if game == selected_index():
			_selected_in_row = placed
		var outside := (stood_outside or _stand.amount > 0.0) and game == selected_index()
		if stood_outside and game == selected_index():
			placed = _stand.at
			place.shown.spin(_stand.spin, _stand.blur)
		elif _stand.amount > 0.0 and game == selected_index():
			placed = placed.interpolate_with(Transform3D(_stand.at.basis * turn, _stand.at.origin), _stand.amount)
		elif game == selected_index():
			var squash := Vector3(1.0 + _stand.squash / 2.0, 1.0 - _stand.squash, 1.0 + _stand.squash / 2.0)
			placed = Transform3D(Basis.from_scale(squash) * Basis(Vector3.RIGHT, _stand.flip) * placed.basis,
				placed.origin + Vector3.UP * _stand.lift)
		if place.transform != placed:
			place.transform = placed
		var presence := selected_presence if game == selected_index() else neighbours
		var mode := ShelfPlace.Draw.OUTSIDE if outside else ShelfPlace.Draw.SHOWN if is_visible_in_tree() else ShelfPlace.Draw.HIDDEN
		place.draw_at(global_transform * placed, MediaView.softness(offset), blank_weight, mode, order - _places.size(),
			presence)
		order += 1


## The games drawn in the row (not one lent out, launched or hidden) whose id [param wanted] takes, each with where it
## stands on the screen.
func drawn(wanted: Callable) -> Array[Drawn]:
	var found: Array[Drawn] = []
	for game: int in _placed:
		var view := _placed[game].media_view
		if view and view.visible and wanted.call(_games[game].id):
			found.append(Drawn.new(_games[game], view, selected_presence if game == selected_index() else neighbours))
	return found


## The title's resting top through the screen camera, cached per fitted model with the canvas size
## it was measured for (x, y, then the top). While the properties lend the model out it cannot be
## measured again: the last top stands.
func title_top() -> float:
	var frame := camera.get_viewport().get_visible_rect().size if camera else CarouselLayout.FRAME
	var model := _models[selected_game().medium]
	var place := _selected_place()
	var kept: Vector3 = _title_tops.get(model, Vector3(NAN, NAN, 0.0))
	var instance := place.shown.instance if place and not place.shown.is_lent() else null
	if Vector2(kept.x, kept.y) != frame and instance:
		var layout := GamesLayout.new(ConsoleManifest.folder_of(model))
		var top := TitlePlace.top(TitlePlace.vertices(instance), layout.chosen,
			camera.global_transform if camera else TitlePlace.CAMERA, CarouselLayout.FRAME, camera.fov if camera else 32.0)
		kept = Vector3(frame.x, frame.y, ScreenLayout.of(frame).on_stage(Vector2(0.0, top)).y)
		_title_tops[model] = kept
	return kept.z


## The row draws its games as far as the screen's width shows them, with a place for every game it can show at once
## ([method GamesLayout.offsets]).
func _fit_width() -> void:
	_within = MediaView.DRAWN_WITHIN
	_level = ScreenLayout.at(get_viewport()).format.shelf_level
	if camera and not _games.is_empty():
		var side := GamesLayout.new(ConsoleManifest.folder_of(_models[_games[0].medium])).side.x
		var depth := camera.global_position.z - global_position.z
		var layout := ScreenLayout.at(get_viewport())
		var place_px := side * CarouselLayout.FRAME.y / (2.0 * depth * tan(deg_to_rad(camera.fov) / 2.0))
		_within += layout.spare_width() / 2.0 / place_px
	Diagnostics.trace("carousel", "shelf drawn within %.2f places, %d games" % [_within, _games.size()])
	while _places.size() < floori(2.0 * _within) + 1:
		var place := ShelfPlace.new()
		add_child(place)
		_places.append(place)


## The place of the selected game; none while it has none.
func _selected_place() -> ShelfPlace:
	return _placed.get(selected_index())


func _free_place() -> ShelfPlace:
	for place in _places:
		if game_at(place) < 0:
			return place
	# Unreachable: there are as many places as games shown at once.
	push_error("ShelfRow: no free place")
	return _places[0]


## A game drawn in the row: the middle of its top on the screen (px of the canvas), its height there, and how present it
## is, from 0 (gone) to 1.
class Drawn:
	var game: AndroidServices.Game
	var crown: Vector2
	var height: float
	var presence: float

	func _init(drawn_game: AndroidServices.Game, view: MediaView, drawn_presence: float) -> void:
		game = drawn_game
		crown = view.crown()
		height = view.on_screen().size.y
		presence = drawn_presence


## How the selected game is shown: leaning back and turned as told, it sways slowly so that the
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
