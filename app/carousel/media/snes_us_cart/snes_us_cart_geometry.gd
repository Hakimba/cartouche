# SPDX-License-Identifier: GPL-3.0-or-later
class_name SnesUsCartGeometry
extends RefCounted
## Builds the North American Super Nintendo's cartridge from its [SnesUsCartShape] as pure
## functions, so that tests check the geometry headless: its halves and its board as the European
## one's ([SnesPalCartGeometry]), the raised body laid over the front half in pieces, each a closed
## solid; the grooves and the notches dark faces laid a hair over the faces they cut.

## The mesh arrays of [param part], its corners rounded in [method ShapeGeometry.corner_steps].
static func arrays(shape: SnesUsCartShape, part: StringName, detail: int) -> Array:
	var steps := ShapeGeometry.corner_steps(detail)
	var mesh := MeshBuilder.new()
	var front := shape.thickness / 2.0
	match part:
		&"label":
			ShapeGeometry.flat(mesh, _label(shape, steps), front - shape.recess, Vector3.BACK, shape.label_box())
		&"shell":
			_shell(mesh, shape, steps)
		&"metal":
			SnesPalCartGeometry.screws(mesh, shape.screws(), shape.screw_radius, shape.wings())
			SnesPalCartGeometry.contacts(mesh, shape.tongues(), shape.centre_contacts, shape.side_contacts,
				shape.contact_pitch)
		&"dark":
			_grooves(mesh, shape)
			var off := SnesUsCartShape.DARK_OFF
			for notch in shape.notches():
				ShapeGeometry.prism(mesh, ShapeGeometry.square(Rect2(notch.position - Vector2(0.0, off),
					notch.size + Vector2(0.0, off))), -front - off, -front + shape.notch_size.z)
		&"board":
			SnesPalCartGeometry.board(mesh, shape.tongues())
	return mesh.arrays()


static func _shell(mesh: MeshBuilder, shape: SnesUsCartShape, steps: int) -> void:
	var whole := shape.outline()
	var front := shape.thickness / 2.0
	var seam := shape.slot_size.y / 2.0
	SnesPalCartGeometry.back_half(mesh, whole, shape.corner, shape.back_round, front, seam, shape.sticker_box(),
		shape.sticker_recess, steps)
	SnesPalCartGeometry.slot_layers(mesh, whole, shape.corner, shape.seam, seam,
		Vector2(shape.slot_size.x, shape.slot_depth), steps)
	var face := ShapeGeometry.rolled(mesh, shape.front_outline(), shape.corner, seam, shape.wings(),
		Vector3.ONE * shape.front_round, steps, whole)
	ShapeGeometry.flat(mesh, face, shape.wings(), Vector3.BACK, whole)
	var corner := SnesUsCartShape.BODY_CORNER
	var rolls := Vector3.ONE * shape.body_round
	var cut := shape.label_centre.x
	var upper := ShapeGeometry.rolled(mesh, shape.upper_body(), corner, shape.body_back(), front, rolls, steps,
		whole, cut)
	var label := _label(shape, steps)
	ShapeGeometry.holed(mesh, upper, [label], front, Vector3.BACK, whole, PackedFloat32Array([cut]))
	ShapeGeometry.sunk(mesh, label, front - shape.recess, front, whole, false)
	for rail in shape.rails():
		var top := ShapeGeometry.rolled(mesh, rail, corner, shape.rails_back(), front, rolls, steps, whole)
		ShapeGeometry.flat(mesh, top, front, Vector3.BACK, whole)
	var end := shape.wings() + shape.channel_depth.y
	var under := shape.wings() + shape.channel_depth.x
	for side in shape.grip_sides():
		ShapeGeometry.wedge(mesh, ShapeGeometry.square(side), shape.rails_back(),
			PackedFloat32Array([end, end, under, under]), whole)


static func _grooves(mesh: MeshBuilder, shape: SnesUsCartShape) -> void:
	var off := SnesUsCartShape.DARK_OFF
	var half := shape.width / 2.0 + off
	var back := -shape.thickness / 2.0 - off
	var sticker := shape.sticker_box().grow(SnesPalCartShape.RIM + 0.3)
	var inner := shape.body_width / 2.0 - 0.5
	for y in shape.grooves():
		var band := Vector2(y - shape.groove_width / 2.0, y + shape.groove_width / 2.0)
		var across: Array[Vector2] = [Vector2(-half, half)]
		if band.y > sticker.position.y and band.x < sticker.end.y:
			across = [Vector2(-half, sticker.position.x), Vector2(sticker.end.x, half)]
		for span in across:
			ShapeGeometry.prism(mesh, _band(span, band), back, 0.0)
		for span: Vector2 in [Vector2(-half, -inner), Vector2(inner, half)]:
			ShapeGeometry.prism(mesh, _band(span, band), -0.5, shape.wings() + off)


static func _band(across: Vector2, up: Vector2) -> PackedVector2Array:
	return ShapeGeometry.square(Rect2(across.x, up.x, across.y - across.x, up.y - up.x))


static func _label(shape: SnesUsCartShape, steps: int) -> PackedVector2Array:
	return ShapeGeometry.rounded_box(shape.label_box(), shape.label_corner, steps, shape.label_centre.x)
