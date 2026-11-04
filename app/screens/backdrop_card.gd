# SPDX-License-Identifier: GPL-3.0-or-later
class_name BackdropCard
extends ChoiceCard
## One backdrop to choose ([member ChoiceCard.value], a key of [constant Backdrop.NAMES]): the backdrop drawn small as
## every screen shows it, the veil over it while it moves, and a satin panel holding a line in
## the backdrop's ink; under it, its name. "Like the device" shows the backdrop the system's theme gives now.

const _MARGIN := 14.0
const _TITLE_SIZE := 26
## The satin panel, in the full-size backdrop's pixels, and the line it holds.
const _PANEL := Rect2(260.0, 690.0, 760.0, 170.0)
const _PANEL_RADIUS := 34.0
const _LINE := "Cartouche"
const _LINE_PX := 17.0
const _FRAME := Vector2(1280.0, 960.0)

var _palette: Palette
## The backdrop shown, drawn at full size then made small.
var _frame := Control.new()
var _backdrop := Cyclorama.new()
var _panel := Control.new()
var _backing: SatinPanel.Backing
var _words := Control.new()


func _ready() -> void:
	super()
	var width := custom_minimum_size.x - 2.0 * _MARGIN
	_frame.position = Vector2(_MARGIN, _MARGIN)
	_frame.size = Vector2(width, width * _FRAME.y / _FRAME.x)
	_frame.clip_contents = true
	_frame.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_frame)
	var stage := Control.new()
	stage.size = _FRAME
	stage.scale = Vector2.ONE * width / _FRAME.x
	stage.mouse_filter = MOUSE_FILTER_IGNORE
	_frame.add_child(stage)
	stage.add_child(_backdrop)
	_panel.position = _PANEL.position
	_panel.size = _PANEL.size
	_panel.mouse_filter = MOUSE_FILTER_IGNORE
	stage.add_child(_panel)
	# Drawn at the card's own scale, over the small backdrop: a line made small with it would blur.
	_words.mouse_filter = MOUSE_FILTER_IGNORE
	_words.draw.connect(_draw_line.bind(stage.scale.x))
	add_child(_words)
	_show_palette()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready():
		_show_palette()


func _draw_sample() -> void:
	# A hairline round the small backdrop: a dark one on a dark card still has its edge.
	draw_rect(Rect2(_frame.position, _frame.size).grow(1.0), Backdrop.palette.line)
	var font := get_theme_font(&"font", &"FieldValue")
	var room := size.x - 2.0 * _MARGIN
	var name_shown := tr(Backdrop.NAMES[value])
	var px := mini(_TITLE_SIZE, floori(_TITLE_SIZE * room / font.get_string_size(name_shown, HORIZONTAL_ALIGNMENT_LEFT, -1,
		_TITLE_SIZE).x))
	var below := _MARGIN + _frame.size.y
	draw_string(font, Vector2(_MARGIN, below + (size.y - below) / 2.0 + px * 0.35), name_shown, HORIZONTAL_ALIGNMENT_CENTER,
		room, px, Backdrop.palette.ink)


## The preview in the backdrop the card stands for now: the system's theme may have changed "Like the device".
func _show_palette() -> void:
	var shown := Palette.of(Backdrop.scheme_of(value))
	if shown == _palette:
		return
	_palette = shown
	_backdrop.palette = shown
	_backing = SatinPanel.Backing.new(_panel, StudioTokens.Look.SATIN, shown)
	_backing.place(Rect2(Vector2.ZERO, _PANEL.size), _PANEL_RADIUS)
	_words.queue_redraw()


func _draw_line(scale_shown: float) -> void:
	var line := StudioText.new(_LINE, StudioTokens.Face.JAKARTA_800, _LINE_PX)
	var middle := _frame.position + (_PANEL.position + _PANEL.size / 2.0) * scale_shown
	line.draw(_words, middle - Vector2(line.width, line.height) / 2.0, _palette.ink)
