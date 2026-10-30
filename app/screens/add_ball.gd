# SPDX-License-Identifier: GPL-3.0-or-later
class_name AddBall
extends Control
## The "+" ball above the consoles: one more can be added. Opened (while up is held), it becomes a
## button, "Add a platform": the two strokes of its "+" spread apart and stretch into the button's
## outline (the horizontal one into its top and bottom edges, the vertical one into its round ends),
## the white widening with them, then the text comes in. Closed, the other way round.

const _BALL := StudioTokens.PLUS.size.x
const _BUTTON := Vector2(330.0, 46.0)
## Half the length of each stroke of the "+", its round ends left out.
const _ARM := (StudioTokens.PLUS_BAR.x - StudioTokens.PLUS_BAR.y) / 2.0
const _STROKE := StudioTokens.PLUS_BAR.y
const _TEXT_SIZE := 20
## How far into the morph the text starts to show.
const _TEXT_FROM := 0.85

## Whether it is the button, or on its way to it.
var is_open := false

## From the ball (0) to the button (1).
var _opened := 0.0:
	set(value):
		_opened = value
		queue_redraw()
var _tween: Tween
var _ball := SatinPanel.Backing.new(self, StudioTokens.Look.PLUS)


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## Turns the ball into the button.
func open() -> void:
	_morph(true)


## Turns the button back into the ball, at once when not [param animated].
func close(animated := true) -> void:
	_morph(false)
	if not animated:
		if _tween:
			_tween.kill()
		_opened = 0.0


func _morph(to_open: bool) -> void:
	if to_open == is_open:
		return
	is_open = to_open
	if to_open:
		Sounds.play(SoundEffects.Cue.ADD_BALL)
	Diagnostics.trace("carousel", "add ball %s" % ("opened" if to_open else "closed"))
	_tween = Motion.restart(self, _tween)
	_tween.tween_property(self, ^"_opened", 1.0 if to_open else 0.0, StudioTokens.TR_BALL_MORPH_S).set_ease(Tween.EASE_OUT) \
		.set_trans(Tween.TRANS_BACK if to_open else Tween.TRANS_CUBIC)


func _draw() -> void:
	var p := _opened
	# Past 1, on the rebound, the button grows a little wider and flatter; the strokes stop at 1.
	var t := minf(p, 1.0)
	var centre := size / 2.0
	var button := Vector2(_BALL, _BALL).lerp(_BUTTON, p)
	var radius := button.y / 2.0
	var straight := (button.x - button.y) / 2.0
	_ball.place(white_box(), radius)
	var ink := StudioTokens.INK
	for side: float in [-1.0, 1.0]:
		# The horizontal stroke parts into the top and bottom edges, as long as the straight sides.
		var half := lerpf(_ARM, straight, t)
		var y := side * radius * t
		_stroke(centre + Vector2(-half, y), centre + Vector2(half, y), t == 0.0)
		# The vertical stroke parts into the two ends, bending from a line into a half circle.
		var middle := centre + Vector2(side * (straight + radius) * t, 0.0)
		var sweep := PI * t
		if sweep < 0.02:
			_stroke(middle - Vector2(0, _ARM), middle + Vector2(0, _ARM))
			continue
		var bend := lerpf(2.0 * _ARM, PI * radius, t) / sweep
		var facing := 0.0 if side > 0.0 else PI
		draw_arc(middle - Vector2(side * bend, 0.0), bend, facing - sweep / 2.0, facing + sweep / 2.0, 24, ink,
			_STROKE, true)
	if p > _TEXT_FROM:
		var font := get_theme_font(&"font", &"FieldValue")
		var text := tr("Add a platform")
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _TEXT_SIZE).x
		var baseline := centre.y + (font.get_ascent(_TEXT_SIZE) - font.get_descent(_TEXT_SIZE)) / 2.0
		var shown := Color(ink, clampf((p - _TEXT_FROM) / (1.0 - _TEXT_FROM), 0.0, 1.0))
		draw_string(font, Vector2(centre.x - width / 2.0, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _TEXT_SIZE, shown)


## Where the white is drawn in the control: the ball growing flatter, then pushed wider by the strokes' ends as
## they spread.
func white_box() -> Rect2:
	var button := Vector2(_BALL, _BALL).lerp(_BUTTON, _opened)
	var white := Vector2(maxf(lerpf(_BALL, button.y, minf(_opened, 1.0)), button.x * minf(_opened, 1.0)), button.y)
	return Rect2(size / 2.0 - white / 2.0, white)


## A stroke of the "+" from [param from] to [param to] (along an axis): a bar of ink with rounded, smoothed ends.
## A [param boxed] stroke, the closed ball's flat bar, lies on whole pixels with a sharp edge; the other bar is
## turned, so it keeps its smoothed edge.
func _stroke(from: Vector2, to: Vector2, boxed := false) -> void:
	var bar := SatinStyle.Mesh2D.new()
	var box := Rect2(from.min(to), (to - from).abs()).grow(_STROKE / 2.0)
	if boxed:
		box = Rect2(box.position.round(), box.end.round() - box.position.round())
	SatinStyle.fill_rounded(bar, box, StudioTokens.PLUS_BAR_RADIUS, func(_at: Vector2) -> Color: return StudioTokens.INK,
		0.0 if boxed else 1.0)
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), bar.indices, bar.points, bar.colors)
