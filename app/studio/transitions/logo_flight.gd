# SPDX-License-Identifier: GPL-3.0-or-later
class_name LogoFlight
extends Control
## Two prepared logos share a flying rectangle and crossfade into each other.

var _from := Rect2()
var _to := Rect2()
var _first := TextureRect.new()
var _last := TextureRect.new()
var _progress := 0.0:
	set(value):
		_progress = value
		var place := Rect2(_from.position.lerp(_to.position, value), _from.size.lerp(_to.size, value))
		for image: TextureRect in [_first, _last]:
			image.position = place.position
			image.size = place.size
		_first.modulate.a = 1.0 - value
		_last.modulate.a = value


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 40
	for image: TextureRect in [_first, _last]:
		image.mouse_filter = MOUSE_FILTER_IGNORE
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(image)


func play(first: TextureRect, last: TextureRect, seconds: float, delay_s := 0.0) -> Tween:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	_from = inverse * first.get_global_rect()
	_to = inverse * last.get_global_rect()
	_first.texture = first.texture
	_last.texture = last.texture
	_progress = 0.0
	var flight := create_tween()
	flight.tween_property(self, ^"_progress", 1.0, seconds).set_delay(delay_s) \
		.set_custom_interpolator(Motion.curve(StudioTokens.TR_GAMES_LOGO_S_CURVE))
	flight.tween_callback(queue_free)
	return flight
