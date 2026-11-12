# SPDX-License-Identifier: GPL-3.0-or-later
class_name ShelfPlace
extends Node3D
## One game's place in the games row ([ShelfRow], which knows which game it shows), showing the model of its game's
## medium. Each medium's model is kept once made, until the library has no game of it, so that another game or
## shelf only shows another one.

## Where its medium is drawn: in its own view, in the main world (the launch has it outside the
## row), or nowhere.
enum Draw { SHOWN, OUTSIDE, HIDDEN }

var shown: LabelledModel
## Which of the row's arrangements last showed a game here: an older one than the latest, the place is free.
var arranged := 0
var layout: GamesLayout
var lit: StudioLights.Rig
var blank: StudioLights.Rig
## One view per place, kept while the place lives: a place is reused by the games of the row, not
## made again at each move.
var media_view: MediaView
var _models: Dictionary[PackedScene, LabelledModel] = {}
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
		var instance := _models[model].instance
		instance.transform = TitlePlace.fitting(instance) * instance.transform
		_models[model].to_real_size = instance.transform.affine_inverse()
	shown = _models[model]
	for made: LabelledModel in _models.values():
		made.visible = made == shown
		if not made.visible:
			made.clear_label()
	var medium := ConsoleManifest.folder_of(model)
	layout = GamesLayout.new(medium)
	lit = StudioLights.rig_of(medium, &"games")
	blank = StudioLights.rig_of(medium, &"games", true)


## Told at every frame the place is not drawn: only a view still drawn is sent to the renderer. [param keep], a
## free place keeps its view's pictures for the game coming in next ([method MediaView.put_away]).
func hide_view(keep := false) -> void:
	if media_view:
		media_view.put_away(keep)
		media_view.set_process(false)
		if media_view.view().render_target_update_mode != SubViewport.UPDATE_DISABLED:
			media_view.view().render_target_update_mode = SubViewport.UPDATE_DISABLED


## [param presence], from 0 (gone) to 1, fades its picture as a whole: a model faded part by part would show its insides.
func draw_at(at: Transform3D, softness: float, weight: float, mode: Draw, order: int, presence := 1.0) -> void:
	var camera := (get_parent() as ShelfRow).camera
	if not camera:
		return
	# Gone, the model itself goes: it stands in the world the consoles are drawn in too.
	var seen := presence > 0.0 or mode == Draw.OUTSIDE
	if shown.visible != seen:
		shown.visible = seen
		shown.dirty = true
	if mode == Draw.OUTSIDE:
		if media_view and shown.get_parent() != self:
			shown.reparent(self, false)
		# Its pictures kept: made again as it comes back, the view would show a frame of nothing.
		hide_view(true)
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
	# Its picture is premultiplied: faded by its alpha alone, its colours would stay and glow white.
	if media_view.modulate.a != presence:
		media_view.modulate = Color(presence, presence, presence, presence)
	# Set again, even unchanged, it would draw the whole screen again.
	if media_view.z_index != order:
		media_view.z_index = order
	# A change below one percent relights nothing visible; the ends are still reached exactly.
	if weight != _blank_weight and (absf(weight - _blank_weight) >= 0.01 or weight in [0.0, 1.0]):
		media_view.crossfade(weight)
		_blank_weight = weight
	media_view.place(at, softness)
	if redraw:
		media_view.view().render_target_update_mode = SubViewport.UPDATE_ONCE
	shown.dirty = false
