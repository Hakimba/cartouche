# SPDX-License-Identifier: GPL-3.0-or-later
class_name SmoothingCard
extends Control
## One edge smoothing to choose: a white card with a close-up of an edge drawn with it, its name and
## what it changes. Focusable; the focus is a ring.

## Confirmed while focused: this smoothing is chosen.
signal chosen(smoothing: StringName)

## Each smoothing's sample offsets from the pixel's centre: Vulkan's standard sample locations.
const SAMPLES: Dictionary[StringName, Array] = {
	&"4x": [Vector2(-0.125, -0.375), Vector2(0.375, -0.125), Vector2(-0.375, 0.125), Vector2(0.125, 0.375)],
	&"2x": [Vector2(0.25, 0.25), Vector2(-0.25, -0.25)],
	&"off": [Vector2.ZERO],
}
## The close-up: each screen pixel this many times larger, the rim leaving the horizontal by this
## many degrees (nearly flat, its steps show best).
const _PIXEL := 7
const _SLOPE_DEG := 8.0
const _RADIUS := 240.0
const _BACKGROUND := Color(0.933, 0.949, 0.965)
const _DISC := Color(0.059, 0.059, 0.078)
const _MARGIN := 15.0
const _TITLE_SIZE := 28
const _NOTE_SIZE := 18

@export var smoothing := &"4x"
@export var title := ""
@export_multiline var note := ""

var _close_up: ImageTexture
var _focus_scale := FocusScale.new()


func _ready() -> void:
	focus_mode = FOCUS_ALL
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	_focus_scale.watch(self)
	_close_up = ImageTexture.create_from_image(close_up(smoothing, Vector2i(Vector2(custom_minimum_size.x - 2.0 * _MARGIN, custom_minimum_size.y / 2.0))))


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		accept_event()
		chosen.emit(smoothing)


func _draw() -> void:
	var card := Rect2(Vector2.ZERO, size)
	draw_style_box(get_theme_stylebox(&"normal", &"Field"), card)
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Field"), card)
	draw_texture(_close_up, Vector2(_MARGIN, _MARGIN))
	var font := get_theme_font(&"font", &"FieldValue")
	var width := size.x - 2.0 * _MARGIN
	var below := _MARGIN + _close_up.get_height()
	draw_string(font, Vector2(_MARGIN, below + 48.0), tr(title), HORIZONTAL_ALIGNMENT_CENTER, width, _TITLE_SIZE, ButtonMark.INK)
	draw_multiline_string(font, Vector2(_MARGIN, below + 84.0), tr(note), HORIZONTAL_ALIGNMENT_CENTER, width, _NOTE_SIZE, 3,
		ButtonMark.INK.lerp(_BACKGROUND, 0.35))


## A close-up of the bottom of a disc's dark band over the background, [param area] large, as
## [param kind] draws it: each screen pixel, [constant _PIXEL] times larger, takes the share of its
## samples inside the disc, mixed in linear light as the multisampling resolves it.
static func close_up(kind: StringName, area: Vector2i) -> Image:
	var image := Image.create_empty(area.x, area.y, false, Image.FORMAT_RGB8)
	var pixels := Vector2i(ceili(area.x / float(_PIXEL)), ceili(area.y / float(_PIXEL)))
	var slope := deg_to_rad(_SLOPE_DEG)
	# The disc's centre above the picture, so that the picture's middle lies on its rim.
	var centre := Vector2(pixels) / 2.0 - Vector2(sin(slope), cos(slope)) * _RADIUS
	var samples: Array = SAMPLES[kind]
	var background := _BACKGROUND.srgb_to_linear()
	var disc := _DISC.srgb_to_linear()
	for y in pixels.y:
		for x in pixels.x:
			var inside := 0
			for sample: Vector2 in samples:
				if (Vector2(x + 0.5, y + 0.5) + sample).distance_to(centre) <= _RADIUS:
					inside += 1
			var shade := background.lerp(disc, inside / float(samples.size()))
			image.fill_rect(Rect2i(Vector2i(x, y) * _PIXEL, Vector2i(_PIXEL, _PIXEL)), shade.linear_to_srgb())
	return image
