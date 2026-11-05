# SPDX-License-Identifier: GPL-3.0-or-later
class_name NewGameDots
extends Control
## A small glowing dot over each game of the row not seen yet ([NewGames]), breathing slowly: it comes in a moment after
## the game is known to be new, and goes out once the user has left the game. It follows each game's place and size on
## the screen and fades with it; as the app rests ([Resting]), it stops breathing.

const SIZE_PX := 14.0
const GLOW_PX := 16.0
## How much the breathing swells the dot (a quarter of it) and its glow (six tenths of it).
const PULSE := 0.3
const PERIOD_S := 1.8
## The dot's centre from the middle of its game's top, for the game in the middle.
const OFFSET := Vector2(0.0, -18.0)
const IN_AFTER_S := 0.4
const IN_S := 0.4
const OUT_S := 0.35
const COLOR := Color("#ffae2b")
## The dot's white shine, towards its upper left: its centre and its reach, as parts of the dot's side.
const _SHINE_AT := Vector2(0.4, 0.35)
const _SHINE_REACH := 0.32

static var _disc := _radial([0.0, 0.97, 1.0], [COLOR, COLOR, Color(COLOR, 0.0)])
static var _shine := _radial([0.0, 0.85, 1.0], [Color.WHITE, Color(Color.WHITE, 0.5), Color(Color.WHITE, 0.0)])
## White fading out to its edge as the square of the distance, tinted when drawn.
static var _glow := _radial([0.0, 0.25, 0.5, 0.75, 1.0],
	[Color.WHITE, Color(Color.WHITE, 0.5625), Color(Color.WHITE, 0.25), Color(Color.WHITE, 0.0625), Color(Color.WHITE, 0.0)])

var row: ShelfRow
var new_games: NewGames
## How fast it breathes, from 1 down to 0, still ([Resting]).
var pace := 1.0
var _clock_s := 0.0
var _breath_s := 0.0
## When each game drawn new was first drawn so (s of [member _clock_s]); how strong the dot of each one left still is.
var _since: Dictionary[String, float] = {}
var _out: Dictionary[String, float] = {}
var _drawn: Array[ShelfRow.Drawn] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_to_group(Resting.PACED)
	new_games.changed.connect(set_process.bind(true))


func _process(delta: float) -> void:
	_clock_s += delta
	var had := not _drawn.is_empty()
	# A dot going out fades whether it is drawn or not, then is forgotten.
	for id: String in _out.keys():
		_out[id] -= delta / OUT_S
		if _out[id] <= 0.0:
			_out.erase(id)
	_drawn.clear()
	if not new_games.has_new() and _out.is_empty():
		_since.clear()
	elif row.is_visible_in_tree():
		_drawn = row.drawn(func(id: String) -> bool: return new_games.is_new(id) or _since.has(id) or _out.has(id))
	var changing := not _out.is_empty()
	for drawn in _drawn:
		var id := drawn.game.id
		if new_games.is_new(id):
			_out.erase(id)
			if not _since.has(id):
				_since[id] = _clock_s
			changing = changing or _clock_s - _since[id] < IN_AFTER_S + IN_S
		elif _since.has(id):
			_out[id] = _strength(id)
			_since.erase(id)
			changing = true
	if not _drawn.is_empty() and (pace > 0.0 or changing):
		_breath_s += delta * pace
		queue_redraw()
	elif had and _drawn.is_empty():
		queue_redraw()
	# Nothing to draw nor to fade: still until the marks change.
	if _drawn.is_empty() and _out.is_empty() and not new_games.has_new():
		set_process(false)


func _draw() -> void:
	var tallest := 0.0
	for drawn in _drawn:
		tallest = maxf(tallest, drawn.height)
	if tallest <= 0.0:
		return
	var breath := sin(TAU * _breath_s / PERIOD_S)
	for drawn in _drawn:
		var strength := _strength(drawn.game.id) * drawn.presence
		if strength <= 0.01:
			continue
		var k := drawn.height / tallest
		var radius := SIZE_PX * k * (1.0 + PULSE * 0.25 * breath) / 2.0
		var glow := GLOW_PX * k * (1.0 + PULSE * 0.6 * breath)
		var centre := drawn.crown + OFFSET * k
		var reach := radius + glow * 1.3
		var shown := Color(1.0, 1.0, 1.0, strength)
		draw_texture_rect(_glow, _square(centre, reach), false, Color(COLOR, strength))
		draw_texture_rect(_disc, _square(centre, radius), false, shown)
		var corner := centre - Vector2(radius, radius)
		draw_texture_rect(_shine, _square(corner + _SHINE_AT * radius * 2.0, _SHINE_REACH * radius * 2.0), false, shown)


## How strong game [param id]'s dot is, from 0 to 1.
func _strength(id: String) -> float:
	if _out.has(id):
		return _out[id]
	var since: float = _since.get(id, _clock_s)
	return clampf((_clock_s - since - IN_AFTER_S) / IN_S, 0.0, 1.0)


static func _square(centre: Vector2, half: float) -> Rect2:
	return Rect2(centre - Vector2(half, half), Vector2(half, half) * 2.0)


## A disc of [param colors] at [param offsets] from its centre (0) to its edge (1).
static func _radial(offsets: PackedFloat32Array, colors: PackedColorArray) -> GradientTexture2D:
	var texture := GradientTexture2D.new()
	texture.gradient = Gradient.new()
	texture.gradient.offsets = offsets
	texture.gradient.colors = colors
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 64
	texture.height = 64
	return texture
