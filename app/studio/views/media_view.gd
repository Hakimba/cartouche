# SPDX-License-Identifier: GPL-3.0-or-later
class_name MediaView
extends TextureRect
## One medium of the games row drawn alone and softened by its distance from the row's centre: it stands
## in a small transparent view of its own world, seen through the app's [member camera] over exactly the
## part of the screen it covers and the reach of its blur and shadow, lit by its light shared by place
## ([method StudioLights.shared]), and shown here through `media_soft.gdshader`. The row places each of
## its games with [method standing], draws those [method drawn_at] in [method drawing_order], and calls
## [method place] at every frame of a move and once more at rest.

## A medium further from the centre than this, in places, is not drawn.
const DRAWN_WITHIN := 2.2
## The view's size goes by steps of this many pixels: a medium moving across the row does not resize it
## at each frame; it takes its own size again once it settles.
const _STEP_PX := 32
const _SHADOW_COLOUR := Color(70.0 / 255.0, 52.0 / 255.0, 34.0 / 255.0)

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
var _view := SubViewport.new()
var _camera := Camera3D.new()
var _environment := WorldEnvironment.new()
var _framed := false
var _settled := false
var _canvas_size := Vector2.ZERO
var _pixel_scale := 0.0
var _at := Transform3D()
var _softness := 0.0
## The view's size while it is hidden, its pictures freed.
var _hidden_size := Vector2i.ZERO


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


## Whether a medium [param d] places from the centre is drawn.
static func drawn_at(d: float) -> bool:
	return absf(d) < DRAWN_WITHIN


## The games of a row of [param n] standing at [param at] that are drawn, the farthest first.
static func drawing_order(n: int, at: float) -> Array[int]:
	var drawn: Array[int] = []
	for j in n:
		if drawn_at(offset(j, at, n)):
			drawn.append(j)
	drawn.sort_custom(func(a: int, b: int) -> bool: return absf(offset(a, at, n)) > absf(offset(b, at, n)))
	return drawn


## Where a game [param d] places from the centre stands, between the chosen game's [param chosen] (its
## place, pose and size) and a neighbour's, straight, at [param side] (x, y) one place away, its size
## [param side_size]: across, on an arc, its pose easing into the straight one and its size into the
## neighbours' over the first place.
static func standing(d: float, chosen: Transform3D, side: Vector2, side_size: float) -> Transform3D:
	var a := softness(d)
	var start := chosen.origin
	var at := Vector3(start.x * (1.0 - a) + side.x * d, start.y + (side.y - start.y) * d * d, start.z * (1.0 - a))
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
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_camera.projection = Camera3D.PROJECTION_FRUSTUM
	_view.add_child(_camera)
	_view.add_child(_environment)
	_view.add_child(_holder)
	add_child(_view)
	var soft := ShaderMaterial.new()
	soft.shader = preload("res://studio/views/media_soft.gdshader")
	material = soft


func _ready() -> void:
	# It watches the edge smoothing once it shows a medium.
	set_process(_shown)
	_environment.environment = StudioLights.environment_of(self)
	texture = _view.get_texture()


func _notification(what: int) -> void:
	# Hidden, the view frees its pictures (tens of MB for the five of a row) and, shown, draws itself
	# again at the size it had: a medium is drawn exactly as if it had kept them.
	if what == NOTIFICATION_VISIBILITY_CHANGED and _framed and visible == (_hidden_size != Vector2i.ZERO):
		if visible:
			_view.size = _hidden_size
			_hidden_size = Vector2i.ZERO
			redraw()
		else:
			_hidden_size = _view.size
			_view.size = Vector2i.ZERO


func _process(_delta: float) -> void:
	if _view.msaa_3d != get_viewport().msaa_3d:
		_view.msaa_3d = get_viewport().msaa_3d
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE


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
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE


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
	var shader := material as ShaderMaterial
	shader.set_shader_parameter(&"blur", at_s.blur * scale_by)
	shader.set_shader_parameter(&"shadow_y", at_s.shadow_y * scale_by)
	shader.set_shader_parameter(&"shadow_blur", at_s.shadow_blur * scale_by)
	shader.set_shader_parameter(&"shadow_colour", Color(_SHADOW_COLOUR, at_s.shadow_alpha))
	shader.set_shader_parameter(&"saturation", at_s.saturation)


## The view, for its size and how it is drawn.
func view() -> SubViewport:
	return _view


## The medium shown, under the node the row stands it with.
func holder() -> Node3D:
	return _holder


## The lights built, the light with a picture's sources then the one without's.
func lights() -> Array[Light3D]:
	return _lights.lights()


## The environment of its own world, whose room light its lights set.
func environment() -> Environment:
	return _environment.environment


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
	var box := _on_screen()
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
		_view.size = fitted
	size = Vector2(fitted) / scale_by
	global_position = wanted.get_center() - size / 2.0
	var shown := camera.get_viewport().get_visible_rect().size
	var height := 2.0 * camera.near * tan(deg_to_rad(camera.fov) / 2.0)
	var centre := global_position + size / 2.0
	_camera.global_transform = camera.global_transform
	_camera.near = camera.near
	_camera.far = camera.far
	_camera.size = height * size.y / shown.y
	_camera.frustum_offset = Vector2(centre.x - shown.x / 2.0, shown.y / 2.0 - centre.y) * height / shown.y
	_view.msaa_3d = get_viewport().msaa_3d
	# Off the screen, it is not drawn at all.
	if Rect2(Vector2.ZERO, shown).intersects(get_global_rect()):
		_view.render_target_update_mode = SubViewport.UPDATE_ONCE


## The part of the screen (the app's canvas, px) the medium covers where it stands.
func _on_screen() -> Rect2:
	var seen := Rect2(camera.unproject_position(_at * _box.get_endpoint(0)), Vector2.ZERO)
	for i in range(1, 8):
		seen = seen.expand(camera.unproject_position(_at * _box.get_endpoint(i)))
	return seen
