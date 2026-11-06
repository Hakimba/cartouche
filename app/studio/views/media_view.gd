# SPDX-License-Identifier: GPL-3.0-or-later
class_name MediaView
extends TextureRect
## One medium of the games row drawn alone and softened by its distance from the row's centre: it stands
## in a small transparent view of its own world, seen through the app's [member camera] over exactly the
## part of the screen it covers and the reach of its blur and shadow, lit by its light shared by place
## ([method StudioLights.shared]), softened by `media_soft.gdshader` into a picture of its own each time it
## is drawn, and shown here as that picture, so that a frame drawn while it stands still (a veil frame, a
## neighbour moving) does not soften it again. The row places each of
## its games with [method standing], draws those [method drawn_at] in [method drawing_order], and calls
## [method place] at every frame of a move and once more at rest.

## A medium further from the centre than this, in places, is not drawn.
const DRAWN_WITHIN := 2.2
## The view's size goes by steps of this many pixels: a medium moving across the row does not resize it
## at each frame; it takes its own size again once it settles.
const _STEP_PX := 32
## The taps of the softening's two Gaussians, as many as `media_soft.gdshader` has room for: few for the medium's
## pixel of blur, many for its shadow, so that no edge shows its copies.
const _MEDIUM_TAPS := 16
const _SHADOW_TAPS := 48
## The taps spread over this many standard deviations.
const _REACH := 2.5
## Each tap of a blur turned this far (radians) from the last: they spread evenly over a disc ([method spiral]).
const _GOLDEN_ANGLE := 2.39996

## How many views hold their pictures (sized), for the traces.
static var holding := 0
static var _taps_of: Dictionary[int, PackedVector3Array] = {}

## The app's camera, whose view of the medium this one copies.
var camera: Camera3D

var _shown := false
## Its light with a picture and without one, built once crossfaded, and the share of the one without.
var _lit: StudioLights.Rig
var _blank: StudioLights.Rig
var _blank_weight := 0.0
var _lights: StudioLights
var _holder := Node3D.new()
## The medium's box, in its holder's space.
var _box := AABB()
## The medium's own 3D view, drawn just before its softened picture is, and that picture, drawn on request.
var _view := SubViewport.new()
var _soft_view := SubViewport.new()
var _soft := TextureRect.new()
var _camera := Camera3D.new()
var _environment := WorldEnvironment.new()
var _framed := false
var _settled := false
var _canvas_size := Vector2.ZERO
var _pixel_scale := 0.0
var _at := Transform3D()
var _softness := 0.0
## The view's size while it is put away, its pictures freed.
var _hidden_size := Vector2i.ZERO
## Whether its views are sized: they hold their pictures on the graphics card, drawn or not.
var _holds := false


## The look of a medium of softness [param s]: its blur and shadow (px at 1280) and saturation.
class Look:
	extends RefCounted

	var blur: float
	var shadow_y: float
	var shadow_blur: float
	var shadow_alpha: float
	var saturation: float


## How far from the row's centre game [param j] of [param n] stands, in places (signed), when the row
## stands at [param at] (its spring's value): the shorter way round.
static func offset(j: int, at: float, n: int) -> float:
	return fposmod(j - at + n / 2.0, n) - n / 2.0


## The softness of a medium [param d] places from the centre: 0 at the centre, rising over the first
## place, 1 from there on. Its pose and its size ease by the same amount.
static func softness(d: float) -> float:
	return minf(absf(d), 1.0)


## Whether a medium [param d] places from the centre is drawn, on a row drawn [param within] places from it.
static func drawn_at(d: float, within := DRAWN_WITHIN) -> bool:
	return absf(d) < within


## The games of a row of [param n] standing at [param at] that are drawn [param within] places from the centre, the
## farthest first.
static func drawing_order(n: int, at: float, within := DRAWN_WITHIN) -> Array[int]:
	var drawn: Array[int] = []
	for j in n:
		if drawn_at(offset(j, at, n), within):
			drawn.append(j)
	drawn.sort_custom(func(a: int, b: int) -> bool: return absf(offset(a, at, n)) > absf(offset(b, at, n)))
	return drawn


## Where a game [param d] places from the centre stands, between the chosen game's [param chosen] (its
## place, pose and size) and a neighbour's, straight, at [param side] (x, y) one place away, its size
## [param side_size]: across, on an arc, its pose easing into the straight one and its size into the
## neighbours' over the first place. On a [param level] row the arc ends at the neighbours: those past them stand at
## their height, so that a wide screen shows them.
static func standing(d: float, chosen: Transform3D, side: Vector2, side_size: float, level := false) -> Transform3D:
	var a := softness(d)
	var start := chosen.origin
	var drop := minf(d * d, 1.0) if level else d * d
	var at := Vector3(start.x * (1.0 - a) + side.x * d, start.y + (side.y - start.y) * drop, start.z * (1.0 - a))
	var turned := chosen.basis.get_rotation_quaternion().slerp(Quaternion.IDENTITY, a)
	return Transform3D(Basis(turned).scaled(Vector3.ONE * lerpf(chosen.basis.get_scale().x, side_size, a)), at)


## The look at softness [param s], each value between the chosen medium's and a neighbour's.
static func look(s: float) -> Look:
	var shadow := StudioTokens.CHOSEN_SHADOW.lerp(StudioTokens.SIDE_SHADOW, s)
	var out := Look.new()
	out.blur = StudioTokens.SOFT_BLUR * s
	out.shadow_y = shadow.x
	out.shadow_blur = shadow.y
	out.shadow_alpha = shadow.z
	out.saturation = lerpf(1.0, StudioTokens.SOFT_SATURATION, s)
	return out


## [param count] points spread evenly over the unit disc, each turned from the last by the golden angle: where the
## blurs of `media_soft.gdshader` and `console_layer.gdshader` take their taps.
static func spiral(count: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in count:
		var angle := i * _GOLDEN_ANGLE
		out.append(Vector2(cos(angle), sin(angle)) * sqrt((i + 0.5) / count))
	return out


## The [param count] taps of a Gaussian, on the [method spiral] over a disc of [constant _REACH] standard deviations:
## each one's offset in standard deviations, and its share of the weights.
static func taps(count: int) -> PackedVector3Array:
	if count in _taps_of:
		return _taps_of[count]
	var out := PackedVector3Array()
	var weights := 0.0
	for at in spiral(count):
		var tap := at * _REACH
		var weight := exp(-0.5 * tap.dot(tap))
		out.append(Vector3(tap.x, tap.y, weight))
		weights += weight
	for i in count:
		out[i] = Vector3(out[i].x, out[i].y, out[i].z / weights)
	_taps_of[count] = out
	return out


## How far past the medium's box its look reaches (px at 1280: left, top, right, bottom), the most over
## every softness: three standard deviations of its blur, and of its shadow's past its offset.
static func reach() -> Vector4:
	var out := Vector4.ONE * 3.0 * StudioTokens.SOFT_BLUR
	# Every value is linear in s: the most is at one end.
	for s: float in [0.0, 1.0]:
		var at := look(s)
		var spread := 1.5 * at.shadow_blur
		out = out.max(Vector4(spread, spread - at.shadow_y, spread, spread + at.shadow_y))
	return out


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	expand_mode = EXPAND_IGNORE_SIZE
	_view.own_world_3d = true
	_view.transparent_bg = true
	# No pictures until it is framed.
	_view.size = Vector2i.ZERO
	_soft_view.size = Vector2i.ZERO
	# Inside the softened picture's view, it is drawn exactly when that one is, and before it.
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_view.add_child(_camera)
	_view.add_child(_environment)
	_view.add_child(_holder)
	_soft_view.disable_3d = true
	_soft_view.transparent_bg = true
	_soft_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_soft.set_anchors_preset(PRESET_FULL_RECT)
	_soft.expand_mode = EXPAND_IGNORE_SIZE
	var soft := ShaderMaterial.new()
	soft.shader = preload("res://studio/views/media_soft.gdshader")
	soft.set_shader_parameter(&"medium_taps", taps(_MEDIUM_TAPS))
	soft.set_shader_parameter(&"shadow_taps", taps(_SHADOW_TAPS))
	_soft.material = soft
	_soft_view.add_child(_soft)
	_soft_view.add_child(_view)
	add_child(_soft_view)
	# The softened picture is premultiplied.
	var shown := CanvasItemMaterial.new()
	shown.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	material = shown


func _ready() -> void:
	# It watches the edge smoothing once it shows a medium.
	set_process(_shown)
	_environment.environment = StudioLights.environment_of(self)
	# Its world has no canvas: cleared, not copied from an empty one.
	_environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	_soft.texture = _view.get_texture()
	texture = _soft_view.get_texture()


func _notification(what: int) -> void:
	# Put away without its pictures, shown again it draws itself at the size it had: a medium is drawn exactly as
	# if it had kept them.
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible and _hidden_size != Vector2i.ZERO:
		_resize(_hidden_size)
		_hidden_size = Vector2i.ZERO
		Diagnostics.trace("media", "view pictures made again: %s, %d views hold theirs" % [_view.size, holding])
		redraw()
	elif what == NOTIFICATION_THEME_CHANGED and _framed:
		_shade()
		redraw()
	elif what == NOTIFICATION_PREDELETE and _holds:
		holding -= 1


func _process(_delta: float) -> void:
	if _view.msaa_3d != get_viewport().msaa_3d:
		_view.msaa_3d = get_viewport().msaa_3d
		_soft_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## Shows [param model] (a medium's scene, made for this view) in a view of its own world, lit by
## [param lit] (its games light, [method StudioLights.rig_of]), or by [param blank] (the one for a game
## without a picture) as [method crossfade] says.
func show_medium(model: Node3D, lit: StudioLights.Rig, blank: StudioLights.Rig) -> void:
	_hold(model, lit, blank)
	_lights = StudioLights.new(_view, StudioLights.mixed(lit, blank, 0.0), Vector3.ZERO, _environment.environment)
	set_process(true)


## Lit again by [param lit] and [param blank] (the light file reloaded), whatever their number of lights.
func relight(lit: StudioLights.Rig, blank: StudioLights.Rig) -> void:
	_lights.dispose()
	_lit = lit
	_blank = blank
	_lights = StudioLights.new(_view, StudioLights.mixed(lit, blank, 0.0), Vector3.ZERO, _environment.environment)
	_light()
	redraw()


## The share of the light for a game without a picture, from 0 (the light with one) to 1, as the focus
## comes to such a game or leaves it; the medium is drawn again in it, moving or not.
func crossfade(blank_weight: float) -> void:
	_blank_weight = blank_weight
	if _shown:
		_light()
	redraw()


## Draws the medium again where it stands: what it looks like changed (its light, its label), not its place.
func redraw() -> void:
	if _shown:
		_soft_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## Hides the view. [param keep], its pictures are kept for the next medium its place shows: a scrolling row puts
## a place away and shows it again for the game coming in, a step later. Otherwise they are freed (tens of MB for
## the five of a row) until it is shown again.
func put_away(keep: bool) -> void:
	if keep and visible and _framed:
		Diagnostics.trace("media", "view put away, pictures kept: %s, %d views hold theirs" % [_view.size, holding])
	hide()
	if not keep and _framed and _hidden_size == Vector2i.ZERO:
		_hidden_size = _view.size
		_resize(Vector2i.ZERO)
		Diagnostics.trace("media", "view pictures freed: %s, %d views hold theirs" % [_hidden_size, holding])


## Stands the medium at [param at] in the world, as the row places it, with softness [param s]
## ([method softness]), and draws it again; the same place twice, it has settled, and its view takes
## its own size. Nothing before a medium is shown.
func place(at: Transform3D, s: float) -> void:
	if not _shown:
		return
	var scale_by := StudioTokens.window_scale(get_window())
	var canvas_changed := _canvas_size != camera.get_viewport().get_visible_rect().size or _pixel_scale != scale_by
	if at == _at and s == _softness and _framed and not canvas_changed:
		if not _settled:
			_frame(true)
			_settled = true
		return
	_settled = false
	var lit_again := not _framed or s != _softness
	_at = at
	_softness = s
	_holder.global_transform = at
	if lit_again:
		_light()
	else:
		_lights.place(_at * _box.get_center())
	_frame(false)
	if not lit_again and not canvas_changed:
		return
	var at_s := look(s)
	var shader := _soft.material as ShaderMaterial
	shader.set_shader_parameter(&"blur", at_s.blur * scale_by)
	shader.set_shader_parameter(&"shadow_y", at_s.shadow_y * scale_by)
	shader.set_shader_parameter(&"shadow_blur", at_s.shadow_blur * scale_by)
	shader.set_shader_parameter(&"saturation", at_s.saturation)
	_shade()


## The view drawn on request (the medium, then its softened picture), for its size and how it is drawn.
func view() -> SubViewport:
	return _soft_view


## The medium shown, under the node the row stands it with.
func holder() -> Node3D:
	return _holder


## The lights built, the light with a picture's sources then the one without's.
func lights() -> Array[Light3D]:
	return _lights.lights()


## The environment of its own world, whose room light its lights set.
func environment() -> Environment:
	return _environment.environment


## The shadow in the backdrop's warm colour, as dark as the medium's softness has it.
func _shade() -> void:
	(_soft.material as ShaderMaterial).set_shader_parameter(&"shadow_colour",
		Color(Backdrop.palette.warm_shadow, look(_softness).shadow_alpha))


func _hold(model: Node3D, lit: StudioLights.Rig, blank: StudioLights.Rig) -> void:
	assert(not _shown, "a media view shows one medium")
	_holder.add_child(model)
	_box = Plinth.bounds(model, _holder)
	_lit = lit
	_blank = blank
	_shown = true


func _light() -> void:
	_lights.tune(StudioLights.shared(StudioLights.mixed(_lit, _blank, _blank_weight), _softness))
	_lights.place(_at * _box.get_center())


## This view over the part of the screen the medium covers and the reach of its look, drawn again; its
## size grows while it moves and, once [param settled], becomes its own again.
func _frame(settled: bool) -> void:
	var box := on_screen()
	var margin := reach()
	var wanted := Rect2(box.position - Vector2(margin.x, margin.y), box.size + Vector2(margin.x + margin.z, margin.y + margin.w))
	var scale_by := StudioTokens.window_scale(get_window())
	var pixels := Vector2i((wanted.size * scale_by / _STEP_PX).ceil()) * _STEP_PX
	var fitted := pixels if settled or not _framed else _view.size.max(pixels)
	if settled and fitted == _view.size:
		return
	_framed = true
	_canvas_size = camera.get_viewport().get_visible_rect().size
	_pixel_scale = scale_by
	if _view.size != fitted:
		_resize(fitted)
	size = Vector2(fitted) / scale_by
	# Controls are drawn on whole pixels: the view stands on one and its camera carries the rest, so a
	# medium moving by less than a pixel a frame (a float, a sway) moves smoothly instead of by steps.
	global_position = ((wanted.get_center() - size / 2.0) * scale_by).round() / scale_by
	var shown := camera.get_viewport().get_visible_rect().size
	StageLens.narrow(camera, _camera, get_global_rect())
	_view.msaa_3d = get_viewport().msaa_3d
	# Off the screen, it is not drawn at all.
	if Rect2(Vector2.ZERO, shown).intersects(get_global_rect()):
		_soft_view.render_target_update_mode = SubViewport.UPDATE_ONCE


func _resize(pixels: Vector2i) -> void:
	if _holds != (pixels != Vector2i.ZERO):
		_holds = not _holds
		holding += 1 if _holds else -1
	_view.size = pixels
	_soft_view.size = pixels


## Where the middle of the medium's top stands on the screen (the app's canvas, px).
func crown() -> Vector2:
	return camera.unproject_position(_at * Vector3(_box.get_center().x, _box.end.y, _box.get_center().z))


## The part of the screen (the app's canvas, px) the medium covers where it stands.
func on_screen() -> Rect2:
	var seen := Rect2(camera.unproject_position(_at * _box.get_endpoint(0)), Vector2.ZERO)
	for i in range(1, 8):
		seen = seen.expand(camera.unproject_position(_at * _box.get_endpoint(i)))
	return seen
