# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelFraming
extends RefCounted
## How the user frames a picture of their own on a label: [member zoom] times closer than the
## largest square that fits in it (1 to [constant MAX_ZOOM]), centred at [member centre], fractions
## of its width and height. The plugin cuts the label with the same rule (`LabelFraming` in the core),
## so the square shown while framing is the one kept.

const MAX_ZOOM := 6.0

var zoom := 1.0
var centre := Vector2(0.5, 0.5)


## The square of a picture [param picture] pixels the label shows: whole, inside it.
func square(picture: Vector2i) -> Rect2i:
	var bounds := picture.maxi(1)
	var short := mini(bounds.x, bounds.y)
	var side := clampi(int(short / clampf(zoom, 1.0, MAX_ZOOM)), 1, short)
	var start := Vector2i(
		clampi(int(centre.x * bounds.x - side / 2.0), 0, bounds.x - side),
		clampi(int(centre.y * bounds.y - side / 2.0), 0, bounds.y - side))
	return Rect2i(start, Vector2i(side, side))


## [method square] as fractions of the picture, as the label's shader shows a part of a texture.
func window(picture: Vector2i) -> Rect2:
	var shown := square(picture)
	return Rect2(Vector2(shown.position) / Vector2(picture), Vector2(shown.size) / Vector2(picture))


## Moves the picture under the label by [param by], in label widths, and brings the centre back
## where the square fits.
func move(by: Vector2, picture: Vector2i) -> void:
	var side := float(square(picture).size.x)
	centre += by * side / Vector2(picture)
	_fit(picture)


## Frames [param factor] times closer (further below 1), within 1 and [constant MAX_ZOOM].
func zoom_by(factor: float, picture: Vector2i) -> void:
	zoom = clampf(zoom * factor, 1.0, MAX_ZOOM)
	_fit(picture)


## The centre moved in as little as the square needs to fit, so that moving back reacts at once.
func _fit(picture: Vector2i) -> void:
	var half := Vector2.ONE * square(picture).size.x / 2.0 / Vector2(picture)
	centre = centre.clamp(half, Vector2.ONE - half)
