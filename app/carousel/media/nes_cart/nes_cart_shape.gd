# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name NesCartShape
extends ModelShape
## The dimensions of a 72-pin NES Game Pak, in millimetres, the label facing +Z and the connector's
## stub at the bottom (see [NesCartGeometry]). Its front: a grip channel on the left, ridged, carved
## at its top into a pocket where the fingers pull the cartridge out, open at the top edge, ridged
## on its floor, and the same pocket on the back; the label's recess, open at the top edge; a
## triangle under it. Its back: three screws, the warning sticker, and a plate on the stub with its
## moulded lettering. Two notches in the top edge at its corners; the stub's end open over the
## connector. Positions are from the centre of the outline.

## How much rounder than the bevel the corners where a recess meets an edge are: a corner as round
## as the bevel would fold.
const _MOUTH := 0.1

@export var width := 119.0:
	set(value):
		width = value
		emit_changed()
@export var height := 133.0:
	set(value):
		height = value
		emit_changed()
@export var depth := 19.0:
	set(value):
		depth = value
		emit_changed()
## The connector's stub under the shoulders: its width and height.
@export var stub := Vector2(105.3, 24.5):
	set(value):
		stub = value
		emit_changed()
@export var corner := 0.8:
	set(value):
		corner = value
		emit_changed()
## How round the front's and the back's edges are.
@export var bevel := 0.4:
	set(value):
		bevel = value
		emit_changed()
## Each notch in the top edge: how far in from its side, its width and its depth.
@export var notch := Vector3(3.7, 7.5, 0.9):
	set(value):
		notch = value
		emit_changed()
## The grip channel: its centre's X and its width, top to bottom, and how deep its floor is.
@export var channel := Vector2(-28.45, 25.5):
	set(value):
		channel = value
		emit_changed()
@export var channel_depth := 1.0:
	set(value):
		channel_depth = value
		emit_changed()
## The pocket at the top of the channel, and the same one on the back: how far down it goes, how
## deep under the face its floor lies, the bars on its floor, and its bottom corners.
@export var pocket := 17.3:
	set(value):
		pocket = value
		emit_changed()
@export var pocket_depth := 3.4:
	set(value):
		pocket_depth = value
		emit_changed()
@export var pocket_bar_count := 4:
	set(value):
		pocket_bar_count = value
		emit_changed()
@export var pocket_corner := 1.0:
	set(value):
		pocket_corner = value
		emit_changed()
## The channel's bars under the pocket: how far down the first one starts, how many, one every
## [member bar_pitch], each [member bar_height] high; the pocket's are as high, spread over it, the
## lowest at its foot.
@export var first_bar := 19.5:
	set(value):
		first_bar = value
		emit_changed()
@export var bar_count := 20:
	set(value):
		bar_count = value
		emit_changed()
@export var bar_pitch := 5.0:
	set(value):
		bar_pitch = value
		emit_changed()
@export var bar_height := 2.5:
	set(value):
		bar_height = value
		emit_changed()
## How far the bars stand out of the floor, and the gap between their ends and the channel's sides.
@export var bar_rise := 0.8:
	set(value):
		bar_rise = value
		emit_changed()
@export var bar_gap := 0.5:
	set(value):
		bar_gap = value
		emit_changed()
## The smooth tab at the channel's foot: its height, its gap over the bottom edge, its corners; it
## stands out as the bars do.
@export var tab := Vector3(12.5, 0.7, 1.5):
	set(value):
		tab = value
		emit_changed()
## The label's recess, open at the top edge: its size, its centre's X, its bottom corners, its depth.
@export var label_size := Vector2(56.2, 90.5):
	set(value):
		label_size = value
		emit_changed()
@export var label_x := 15.9:
	set(value):
		label_x = value
		emit_changed()
@export var label_corner := 1.5:
	set(value):
		label_corner = value
		emit_changed()
@export var recess := 0.5:
	set(value):
		recess = value
		emit_changed()
## The triangle pointing down under the label: its width and height, its centre, how far it stands
## out.
@export var triangle_size := Vector2(10.1, 8.9):
	set(value):
		triangle_size = value
		emit_changed()
@export var triangle_centre := Vector2(0.1, -36.45):
	set(value):
		triangle_centre = value
		emit_changed()
@export var triangle_rise := 0.3:
	set(value):
		triangle_rise = value
		emit_changed()
## The screws on the back: their hole's and their head's diameters; the one at the top, then the two
## low ones, the right one seen from the front, the other mirrored.
@export var screw := Vector2(5.0, 3.6):
	set(value):
		screw = value
		emit_changed()
@export var screw_top := Vector2(0.0, 8.9):
	set(value):
		screw_top = value
		emit_changed()
@export var screw_low := Vector2(52.7, -33.5):
	set(value):
		screw_low = value
		emit_changed()
## The warning sticker on the back: its size, its centre (seen from the front), how thick it is.
@export var sticker_size := Vector2(80.5, 32.3):
	set(value):
		sticker_size = value
		emit_changed()
@export var sticker_centre := Vector2(0.0, -13.4):
	set(value):
		sticker_centre = value
		emit_changed()
@export var sticker_thickness := 0.15:
	set(value):
		sticker_thickness = value
		emit_changed()
## The plate on the stub's back: its size, its centre, how far it stands out.
@export var plate_size := Vector2(51.0, 16.0):
	set(value):
		plate_size = value
		emit_changed()
@export var plate_centre := Vector2(0.0, -48.5):
	set(value):
		plate_centre = value
		emit_changed()
@export var plate_rise := 0.3:
	set(value):
		plate_rise = value
		emit_changed()
## The opening in the stub's end over the connector: its width and its height through the depth.
@export var opening := Vector2(95.0, 9.0):
	set(value):
		opening = value
		emit_changed()


## The radius of the corners where a recess or a notch meets an edge.
func mouth() -> float:
	return bevel + _MOUTH


## How far in from the front and from the back the shell's middle is: as deep as the pocket's floor.
func relief() -> float:
	return pocket_depth


func channel_box() -> Rect2:
	return Rect2(channel.x - channel.y / 2.0, -height / 2.0, channel.y, height)


func label_box() -> Rect2:
	return Rect2(label_x - label_size.x / 2.0, height / 2.0 - label_size.y, label_size.x, label_size.y)


## The notches in the top edge, right then left: each its right X, its left X and its depth.
func notches() -> Array[Vector3]:
	var right := width / 2.0 - notch.x
	return [Vector3(right, right - notch.y, notch.z), Vector3(notch.y - right, -right, notch.z)]


## Where the bars lie in the channel, across, and the terraces' height each.
func bar_span() -> Vector2:
	return Vector2(channel.x - channel.y / 2.0 + bar_gap, channel.y - 2.0 * bar_gap)


func pocket_pitch() -> float:
	return pocket / pocket_bar_count


## The channel's bars under the pocket.
func bars() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var span := bar_span()
	for k in bar_count:
		found.append(Rect2(span.x, height / 2.0 - first_bar - bar_height - k * bar_pitch, span.y, bar_height))
	return found


func tab_box() -> Rect2:
	var span := bar_span()
	return Rect2(span.x, tab.y - height / 2.0, span.y, tab.x)


func triangle() -> PackedVector2Array:
	var half := triangle_size / 2.0
	return PackedVector2Array([triangle_centre - Vector2(0.0, half.y), triangle_centre + half,
		triangle_centre + Vector2(-half.x, half.y)])


func screws() -> PackedVector2Array:
	return PackedVector2Array([screw_top, screw_low, Vector2(-screw_low.x, screw_low.y)])


## The pocket's bars, top to bottom, the lowest at its foot.
func pocket_bars() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var span := bar_span()
	for i in pocket_bar_count:
		found.append(Rect2(span.x, height / 2.0 - (i + 1) * pocket_pitch(), span.y, bar_height))
	return found


func sticker_box() -> Rect2:
	return ShapeGeometry.centred(sticker_centre, sticker_size)


func plate_box() -> Rect2:
	return ShapeGeometry.centred(plate_centre, plate_size)


func parts() -> Array[StringName]:
	return NesCartGeometry.PARTS


func _arrays(part: StringName, detail: int) -> Array:
	return NesCartGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var top := height / 2.0
	var bottom := -height / 2.0
	var shoulders := bottom + stub.y
	var tips := mouth()
	var piece := tips + _MOUTH
	var channel_at := channel_box()
	var label := label_box()
	var notched := notches()
	var below_label := Rect2(channel_at.end.x, bottom, stub.x / 2.0 - channel_at.end.x, label.position.y - bottom)
	var back: Array[Rect2] = [Rect2(channel_at.position.x, top - pocket, channel.y, pocket), plate_box(),
		sticker_box()]
	for at in screws():
		back.append(ShapeGeometry.square_around(at, screw.x / 2.0))
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and channel_depth > 0.0 and recess > 0.0
			and bar_rise > 0.0 and bar_gap >= 0.0 and triangle_rise > 0.0 and plate_rise > 0.0
			and sticker_thickness > 0.0 and screw.y > 0.0 and screw.y < screw.x,
		# The edges rounded within the corners, the front's and the back's reliefs within the depth.
		&"bevel_fits": bevel > 0.0 and corner > tips and bevel < relief() and depth > 2.0 * relief(),
		&"stub_fits": stub.y >= corner and shoulders + 2.0 * corner <= top - notch.z
			and width / 2.0 - stub.x / 2.0 >= corner and opening.x > 0.0 and opening.y > 0.0
			and opening.x < stub.x - 2.0 * corner and opening.y < depth - 2.0 * relief(),
		# Along the top edge, left to right, each piece wide enough for its rounded corners and a
		# straight stretch between them: shrunk by the bevel, roundings that meet would cross.
		&"top_edge_in_order": _apart(PackedFloat32Array([-width / 2.0, notched[1].y, notched[1].x,
			channel_at.position.x, channel_at.end.x, label.position.x, label.end.x, notched[0].y,
			notched[0].x, width / 2.0]), PackedFloat32Array([corner + piece, 2.0 * piece, 2.0 * piece,
			2.0 * piece, 2.0 * piece, maxf(2.0 * piece, 2.0 * label_corner), 2.0 * piece, 2.0 * piece,
			corner + piece])),
		&"notches_fit": notch.z >= tips,
		&"channel_over_the_stub": channel_at.position.x + stub.x / 2.0 >= corner + tips
			and stub.x / 2.0 - channel_at.end.x >= corner + tips,
		&"label_above_the_shoulders": label_corner >= 0.0 and label_size.y >= tips + label_corner
			and label.position.y - label_corner > shoulders + corner,
		# The bars apart in the pocket and under it, between the pocket and the tab.
		&"bars_fit": pocket_bar_count >= 1 and bar_count >= 1 and bar_height > 0.0 and bar_pitch > bar_height
			and bar_height < pocket_pitch() and pocket >= tips and 2.0 * bar_gap < channel.y
			and first_bar >= pocket and first_bar + (bar_count - 1) * bar_pitch + bar_height < height - tab.x - tab.y,
		# The pocket carved below the channel's floor, its bottom corners round within its width and height.
		&"pocket_carved": pocket_depth > channel_depth and pocket_corner >= 0.0
			and 2.0 * pocket_corner < channel.y and pocket_corner + tips < pocket,
		&"tab_fits": tab.x > 2.0 * tab.z and tab.y > 0.0 and tab.z >= 0.0 and 2.0 * tab.z < bar_span().y,
		&"triangle_under_the_label": ShapeGeometry.within(ShapeGeometry.bounds(triangle()).grow(bevel), below_label)
			and triangle_size.x > 0.0 and triangle_size.y > 0.0,
		# The screws, the plate and the back's pocket apart on the back, each within its outline.
		&"back_apart": ShapeGeometry.apart(back, Rect2(-width / 2.0, bottom, width, height), maxf(bevel, 0.0))
			and ShapeGeometry.within(plate_box().grow(bevel), Rect2(-stub.x / 2.0, bottom, stub.x, top - bottom))
			and Array(screws()).all(func(at: Vector2) -> bool: return ShapeGeometry.within(
				ShapeGeometry.square_around(at, screw.x / 2.0 + bevel),
				Rect2(-width / 2.0, shoulders, width, top - notch.z - shoulders))),
	}


static func _apart(edges: PackedFloat32Array, gaps: PackedFloat32Array) -> bool:
	return range(gaps.size()).all(func(i: int) -> bool: return edges[i + 1] - edges[i] >= gaps[i])
