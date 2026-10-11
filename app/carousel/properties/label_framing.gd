# SPDX-License-Identifier: GPL-3.0-or-later
class_name LabelFraming
extends RefCounted
## How the user frames a picture of their own on a label whose width is [member proportion] times
## its height (1 on a disc): [member zoom] times closer than the largest rectangle of the label's
## proportions that fits in it (1 to [constant MAX_ZOOM]), centred at [member centre], fractions of
## its width and height. The plugin cuts the label with the same rule (`LabelFraming` in the core),
## so the rectangle shown while framing is the one kept.

const MAX_ZOOM := 6.0
const MIN_PROPORTION := 0.2
const MAX_PROPORTION := 5.0

var zoom := 1.0
var centre := Vector2(0.5, 0.5)
var proportion := 1.0


func _init(label_proportion := 1.0) -> void:
	proportion = label_proportion


## The rectangle of a picture [param picture] pixels the label shows: of the label's proportions
## within a pixel, whole, inside it.
func framed(picture: Vector2i) -> Rect2i:
	var bounds := picture.maxi(1)
	var shape := clampf(proportion, MIN_PROPORTION, MAX_PROPORTION)
	var closer := clampf(zoom, 1.0, MAX_ZOOM)
	var fit := Vector2(bounds.y * shape, bounds.y) if float(bounds.x) / bounds.y > shape \
		else Vector2(bounds.x, bounds.x / shape)
	var side := Vector2i(clampi(int(fit.x / closer), 1, bounds.x), clampi(int(fit.y / closer), 1, bounds.y))
	var start := Vector2i(
		clampi(int(centre.x * bounds.x - side.x / 2.0), 0, bounds.x - side.x),
		clampi(int(centre.y * bounds.y - side.y / 2.0), 0, bounds.y - side.y))
	return Rect2i(start, side)


## [method framed] as fractions of the picture, as the label's shader shows a part of a texture.
func window(picture: Vector2i) -> Rect2:
	var shown := framed(picture)
	return Rect2(Vector2(shown.position) / Vector2(picture), Vector2(shown.size) / Vector2(picture))


## Moves the picture under the label by [param by], in label widths, and brings the centre back
## where the rectangle fits.
func move(by: Vector2, picture: Vector2i) -> void:
	centre += by * float(framed(picture).size.x) / Vector2(picture)
	_fit(picture)


## Frames [param factor] times closer (further below 1), within 1 and [constant MAX_ZOOM].
func zoom_by(factor: float, picture: Vector2i) -> void:
	zoom = clampf(zoom * factor, 1.0, MAX_ZOOM)
	_fit(picture)


## The centre moved in as little as the rectangle needs to fit, so that moving back reacts at once.
func _fit(picture: Vector2i) -> void:
	var half := Vector2(framed(picture).size) / 2.0 / Vector2(picture)
	centre = centre.clamp(half, Vector2.ONE - half)
