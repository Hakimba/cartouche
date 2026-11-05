# SPDX-License-Identifier: GPL-3.0-or-later
class_name RailBadge
extends Control
## The badge over a rail tile's top right corner telling how many new games its console announces (`+3`), in the
## console's gel: it pops in with a small rebound when the console gets some, and fades out once it has none.

const HEIGHT := 34.0
const FONT_PX := 19.0
## Its centre from the tile's top right corner.
const OFFSET := Vector2(-12.0, 4.0)
const POP_AFTER_S := 0.2
const POP_S := 0.35
## The size it pops from, as a part of its own.
const POP_FROM := 0.55
const OUT_S := 0.3
const _INK := Color.WHITE
const _SHADOW := Color(70.0 / 255.0, 52.0 / 255.0, 34.0 / 255.0, 0.3)

var _count := 0
## The console's gel as its manifest has it: the backdrop shown draws it ([method Palette.gel]).
var _gel := StudioTokens.NEUTRAL
var _line := StudioText.new("", StudioTokens.Face.JAKARTA_800, FONT_PX, 0.0, true)
var _style := StyleBoxFlat.new()
var _fade: Tween


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	# Over the selection frame, which the rail draws after its tiles.
	z_index = 1
	visible = false
	_style.set_corner_radius_all(ceili(HEIGHT / 2.0))
	_style.corner_detail = 12
	_style.border_width_top = 1
	_style.border_color = Color(1.0, 1.0, 1.0, 0.35)
	_style.shadow_color = _SHADOW
	_style.shadow_size = 6
	_style.shadow_offset = Vector2(0.0, 3.0)
	_style.anti_aliasing_size = 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_style.bg_color = Backdrop.palette.gel(_gel)
		queue_redraw()


## Tells [param shown] new games, in [param gel] as the backdrop draws it, over a tile whose top right corner is at
## [param corner]: from none it pops in, to none it fades out, unless [param animated] is false.
func show_count(shown: int, gel: Color, corner: Vector2, animated := true) -> void:
	_gel = gel
	_style.bg_color = Backdrop.palette.gel(gel)
	if shown == _count:
		queue_redraw()
		return
	var was := _count
	_count = shown
	if shown > 0:
		_line = StudioText.new("+%d" % shown, StudioTokens.Face.JAKARTA_800, FONT_PX, 0.0, true)
		size = Vector2(maxf(HEIGHT, _line.width + 0.56 * HEIGHT), HEIGHT)
		position = corner + OFFSET - size / 2.0
		pivot_offset = size / 2.0
		queue_redraw()
	# Another count over a badge shown only changes its text, its pop going on.
	if _fade and not (animated and was > 0 and shown > 0):
		_fade.kill()
	if not animated:
		visible = shown > 0
		modulate.a = 1.0
		scale = Vector2.ONE
	elif was == 0:
		visible = true
		modulate.a = 0.0
		scale = Vector2.ONE * POP_FROM
		_fade = create_tween().set_parallel()
		_fade.tween_property(self, ^"scale", Vector2.ONE, POP_S).set_delay(POP_AFTER_S) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_fade.tween_property(self, ^"modulate:a", 1.0, POP_S / 2.0).set_delay(POP_AFTER_S)
	elif shown == 0:
		_fade = create_tween()
		_fade.tween_property(self, ^"modulate:a", 0.0, OUT_S)
		_fade.tween_callback(hide)


## How many new games it tells.
func count() -> int:
	return _count


func _draw() -> void:
	draw_style_box(_style, Rect2(Vector2.ZERO, size))
	_line.draw(self, Vector2((size.x - _line.width) / 2.0, (size.y - _line.height) / 2.0), _INK)
