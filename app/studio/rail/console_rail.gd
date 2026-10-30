# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleRail
extends Control
## The consoles screen's rail: a ring of satin tiles, one per console, centred under the posed console, in the
## logo of each; the selected one stands in a frame in its gel, with a pool of light under it. A press moves
## the spring's target by one; the tiles follow it, each at its slot's distance from the centre (the ring
## wraps both ways; a ring short enough to show whole is a strip of its tiles side by side, so no tile ever
## crosses the rail), the frame pops and the gel crossfades. The rail fades out toward both edges and each tile
## has its floor reflection. At rest nothing is drawn: the spring stops the rail's frames.

## The tiles' step, the first tile's top-left corner and the farthest slot shown, in px and slots.
const PITCH := 174.08
const TILE_LEFT := 564.48
const TILE_TOP := 711.68
const HIDDEN_BEYOND := 3.6
## The selection frame's box, border, radius and glows.
const FRAME := Rect2(553.6, 700.8, 172.8, 124.16)
const _FRAME_BORDER := 5.76
const _FRAME_RADIUS := 29.44
## The pool of light under the frame: its box, and the rim's alpha at its centre.
const POOL := Rect2(513.28, 788.48, 253.44, 64.0)
const _POOL_ALPHA := 0.32
## The frame's pop: its scale keyframes (offset, scale) over [constant POP_S], eased out as a whole.
const POP_S := 0.32
const _POP_KEYS: Array[Vector2] = [Vector2(0.0, 1.0), Vector2(0.3, 0.95), Vector2(0.65, 1.025), Vector2(1.0, 1.0)]
## What [method slot_under] says for a point off the rail.
const NO_TILE := 1 << 30
## How far the rail has sunk: 0 at rest, 1 down and gone. [method sink] and [method rise] move it.
var sunk := 0.0:
	set(value):
		sunk = value
		_apply_sink()
## How opaque the frame and its pool are (they leave with the transitions, apart from the rail).
var ground_alpha := 1.0:
	set(value):
		ground_alpha = value
		_apply_ground()

var _folders: Array[String] = []
var _spring := Motion.Spring.new(0.0)
## One tile per console, at the slot nearest the middle.
var _tiles: Array[RailTile] = []
var _mirrors: Array[RailTile] = []
var _gel := StudioTokens.NEUTRAL
var _gel_from := StudioTokens.NEUTRAL
var _gel_to := StudioTokens.NEUTRAL
var _gel_fade: Tween
## How far the gel has crossfaded from the one before to the one now.
var _gel_weight := 1.0:
	set(value):
		_gel_weight = value
		_tint(_gel_from.lerp(_gel_to, value))
var _pop_fade: Tween
var _slide_fade: Tween
var _frame := Frame.new()

@onready var _stage: Control = $Stage
@onready var _pool: TextureRect = $Stage/Pool
@onready var _cloth: CanvasGroup = $Stage/Cloth
@onready var _mirrors_root: CanvasGroup = $Stage/Mirrors


## The selection frame: a transparent satin box whose border and glows are shadows of the material (a border
## is an inset shadow without blur), drawn by the satin shader.
class Frame:
	extends Control

	var _material := ShaderMaterial.new()
	var _shown := StudioMaterial.new(StudioTokens.Look.SATIN)
	var _colors: Array[Vector4] = []
	var _reach := 0.0

	func _init() -> void:
		mouse_filter = MOUSE_FILTER_IGNORE
		position = FRAME.position
		size = FRAME.size
		pivot_offset = FRAME.size / 2.0
		_shown.stops = [0.0, 1.0]
		_shown.colors = [Color(1, 1, 1, 0), Color(1, 1, 1, 0)]
		_shown.radius = _FRAME_RADIUS
		_shown.shadows = [
			StudioMaterial.Shadow.new([Vector4(0.0, 0.0, 0.0, _FRAME_BORDER), Color(1, 1, 1, 1.0), true, true]),
			StudioMaterial.Shadow.new([Vector4(0.0, 0.0, 10.24, _FRAME_BORDER), Color(1, 1, 1, 0.25), true, true]),
			StudioMaterial.Shadow.new([Vector4(0.0, 0.0, 17.92, 0.0), Color(1, 1, 1, 0.45), false, true]),
		]
		_reach = _shown.reach()
		# Everything but the shadows' colours is set once: a gel changing frame by frame sets those alone.
		var parameters := SatinPanel.Backing.recipe(_shown)
		for parameter in parameters:
			_material.set_shader_parameter(parameter, parameters[parameter])
		_material.set_shader_parameter(&"box_position", Vector2.ZERO)
		_material.set_shader_parameter(&"box_size", FRAME.size)
		_colors.resize(_shown.shadows.size())
		_material.shader = preload("res://studio/satin_panel.gdshader")
		material = _material
		tint(StudioTokens.NEUTRAL)

	## The frame in [param gel]: the border, its glow inside it, and its glow outside.
	func tint(gel: Color) -> void:
		for i in _colors.size():
			var color := _shown.shadows[i].shown(gel)
			_colors[i] = Vector4(color.r, color.g, color.b, color.a)
		_material.set_shader_parameter(&"shadow_colors", _colors)

	func _draw() -> void:
		draw_rect(Rect2(-Vector2(_reach, _reach), FRAME.size + 2.0 * Vector2(_reach, _reach)), Color.WHITE)


## How far past slot 0 a tile [param index] is for a rail at [param along] with [param count] tiles, in
## slots: the way round the ring that is shorter, on the left when both are as short.
## A strip ([method is_strip]) is not wrapped: [param along] is then a place on it, not a turn of the ring.
static func slot(index: int, along: float, count: int) -> float:
	if is_strip(count):
		return index - along
	return fposmod(index - along + count / 2.0, count) - count / 2.0


## Whether a ring of [param count] consoles shows whole on the rail, as a strip: wrapping it would show a tile
## on both sides, or move one across the rail.
static func is_strip(count: int) -> bool:
	return count <= 2 * floori(HIDDEN_BEYOND) + 1


## Whether a tile [param slots] from the centre shows.
static func shown(slots: float) -> bool:
	return absf(slots) <= HIDDEN_BEYOND


## The frame's scale [param seconds] after a press: the keyframes, read at the progress the whole animation's
## ease-out gives.
static func pop_scale(seconds: float) -> float:
	var progress := Motion.eased(Motion.Easing.EASE_OUT, clampf(seconds / POP_S, 0.0, 1.0))
	for i in range(1, _POP_KEYS.size()):
		if progress <= _POP_KEYS[i].x:
			var from := _POP_KEYS[i - 1]
			var to := _POP_KEYS[i]
			return lerpf(from.y, to.y, (progress - from.x) / (to.x - from.x))
	return _POP_KEYS[-1].y


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_pool.position = POOL.position
	_pool.size = POOL.size
	_pool.texture = _pool_texture()
	_pool.mouse_filter = MOUSE_FILTER_IGNORE
	_stage.add_child(_frame)
	set_process(false)
	_apply_sink()
	_apply_ground()


func _process(delta: float) -> void:
	var still := _spring.step(delta)
	_place()
	if still:
		set_process(false)


## Shows the consoles in [param folders] (under res://carousel/consoles), in this order, the tile at
## [param selected] in the middle.
func show_consoles(folders: Array[String], selected: int) -> void:
	for tile in _tiles + _mirrors:
		tile.queue_free()
	_tiles.clear()
	_mirrors.clear()
	_folders = folders
	visible = not folders.is_empty()
	if folders.is_empty():
		return
	for folder in folders:
		var tile := RailTile.of(folder)
		_cloth.add_child(tile)
		_tiles.append(tile)
		_mirrors.append(tile.reflected())
		_mirrors_root.add_child(_mirrors[-1])
	_spring = Motion.Spring.new(float(selected))
	_set_gel(_gel_of(selected), false)
	_place()


## The rail's target (an unbounded index: the ring's turns count, but a strip's place is the console's) moves to
## [param target]: the tiles follow on the spring, the frame pops, the gel crossfades to the console reached.
func go_to(target: int) -> void:
	if _folders.is_empty():
		return
	Diagnostics.trace("carousel", "rail target=%d" % target)
	_spring.target = float(posmod(target, _folders.size()) if is_strip(_folders.size()) else target)
	_place()
	set_process(true)
	_set_gel(_gel_of(target))
	_pop()


## Moves the rail [constant StudioTokens.TR_GAMES_DROP_PX] down to nothing in [param duration_s], after
## [param delay_s], from where it is.
func sink(duration_s: float, delay_s := 0.0) -> Tween:
	return _slide_to(1.0, duration_s, delay_s, Motion.Easing.SINK)


## Brings the rail from [constant StudioTokens.TR_GAMES_DROP_PX] lower and clear to rest in [param duration_s], after
## [param delay_s], from where it is.
func rise(duration_s: float, delay_s := 0.0) -> Tween:
	return _slide_to(0.0, duration_s, delay_s, Motion.Easing.ARRIVE)


## How many steps from the target select the tile under [param point] (in the frame's px);
## [constant NO_TILE] for a point on none.
func slot_under(point: Vector2) -> int:
	if not is_visible_in_tree() or sunk >= 1.0:
		return NO_TILE
	for tile in _tiles:
		if tile.visible and Rect2(tile.position, RailTile.SIZE).has_point(point):
			return roundi((tile.position.x - TILE_LEFT) / PITCH + _spring.position - _spring.target)
	return NO_TILE


## Where tile [param index] stands now: its top-left corner.
func tile_at(index: int) -> Vector2:
	return _tiles[index].position


## Whether tile [param index] shows.
func is_shown(index: int) -> bool:
	return _tiles[index].visible


## The tiles, in the order of the consoles.
func tiles() -> Array[RailTile]:
	return _tiles


## The selection frame.
func frame() -> Control:
	return _frame


## The pool of light.
func pool() -> TextureRect:
	return _pool


## The spring, for those who watch it.
func spring() -> Motion.Spring:
	return _spring


## Where each tile stands for the spring's position. A platform shown by its medium has no tile.
func _place() -> void:
	for i in _tiles.size():
		var slots := slot(i, _spring.position, _tiles.size())
		var shows := shown(slots) and not _folders[i].is_empty()
		_tiles[i].visible = shows
		_mirrors[i].visible = shows
		if shows:
			var x := TILE_LEFT + slots * PITCH
			_tiles[i].position = Vector2(x, TILE_TOP)
			_mirrors[i].position = Vector2(x, TILE_TOP + 2.0 * RailTile.SIZE.y + RailTile.REFLECTION_GAP)


func _apply_sink() -> void:
	if is_node_ready():
		for group: CanvasGroup in [_cloth, _mirrors_root]:
			group.position.y = sunk * StudioTokens.TR_GAMES_DROP_PX
			group.modulate.a = 1.0 - sunk


func _apply_ground() -> void:
	if is_node_ready():
		_frame.modulate.a = ground_alpha
		_pool.modulate.a = ground_alpha


func _slide_to(value: float, duration_s: float, delay_s: float, curve: Motion.Easing) -> Tween:
	_slide_fade = Motion.restart(self, _slide_fade)
	_slide_fade.tween_property(self, ^"sunk", value, duration_s).set_delay(delay_s) \
		.set_custom_interpolator(Motion.curve(curve))
	return _slide_fade


func _pop() -> void:
	_pop_fade = Motion.restart(self, _pop_fade)
	_pop_fade.tween_method(_set_pop, 0.0, POP_S, POP_S)


func _set_pop(seconds: float) -> void:
	_frame.scale = Vector2.ONE * pop_scale(seconds)


## The gel of the console [param target] stands for on the ring.
func _gel_of(target: int) -> Color:
	var folder := _folders[posmod(target, _folders.size())]
	return ConsoleManifest.gel_of(folder)


## The frame and the pool in [param gel], crossfaded from the one shown when [param animated].
func _set_gel(gel: Color, animated := true) -> void:
	if _gel_fade:
		_gel_fade.kill()
	_gel_from = _gel
	_gel_to = gel
	if not animated or gel == _gel:
		_tint(gel)
		return
	_gel_weight = 0.0
	_gel_fade = create_tween()
	_gel_fade.tween_property(self, ^"_gel_weight", 1.0, StudioTokens.GEL_FADE_S) \
		.set_custom_interpolator(Motion.curve(Motion.Easing.EASE))


func _tint(gel: Color) -> void:
	_gel = gel
	_frame.tint(gel)
	var gradient := (_pool.texture as GradientTexture2D).gradient
	gradient.set_color(0, Color(gel, _POOL_ALPHA))
	gradient.set_color(1, Color(gel, 0.0))


## The pool: the gel's alpha at its centre fading to nothing at the edge of the ellipse that touches the
## texture's sides.
static func _pool_texture() -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 32
	return texture
