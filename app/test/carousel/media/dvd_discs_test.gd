# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The silver DVDs' own looks: their data side silver wherever it is drawn (the carousel's mirror and
## a viewer's plain material, which takes the mirror's colour), and on the Xbox discs the hologram
## ring around the hub, printed on both faces of the mirror: read upright through the label side,
## mirrored on the data side, as one sheet seen from its two sides.

const SILVER_DISCS: Array[String] = ["wii_dvd", "xbox_dvd", "xbox360_dvd"]
const RINGED_DISCS: Array[String] = ["xbox_dvd", "xbox360_dvd"]
const MM := MeshBuilder.UNITS_PER_MM
## The least luminance of a silver mirror: printed black, the data side reads as a black disc.
const SILVER := 0.6
const PX_PER_MM := 8.0
## How close to the mirror a face of the ring lies, either side, in millimetres.
const ON_MM := 0.2
const EPSILON := 0.001
## Which way each face of the ring turns: the data side's copy under the mirror, facing down; the
## other over it, facing up, seen through the clear hub.
const FACES: Dictionary[NodePath, float] = {^"Hub": -1.0, ^"HubThroughLabelSide": 1.0}


func test_a_silver_disc_s_data_side_is_silver_wherever_it_is_drawn() -> void:
	for medium in SILVER_DISCS:
		var mirror := (_model(medium).get_node(^"Mirror") as MeshInstance3D).get_active_material(0) as ShaderMaterial
		for colour: StringName in [&"mirror_color", &"recorded_color"]:
			var value: Color = mirror.get_shader_parameter(colour)
			assert_float(value.get_luminance()).override_failure_message("%s: its %s not silver" % [medium,
				colour]).is_greater(SILVER)


func test_an_xbox_disc_s_hub_ring_covers_the_hub_s_edge_on_both_faces_of_its_mirror() -> void:
	for medium in RINGED_DISCS:
		var model := _model(medium)
		var disc: DiscShape = ((model.get_node(^"Label") as MeshInstance3D).mesh as ShapedMesh).shape
		var bottom := -disc.thickness / 2.0
		for face in FACES:
			var up := FACES[face]
			var ring := model.get_node(face) as MeshInstance3D
			var decal: DiscShape = (ring.mesh as ShapedMesh).shape
			var seen := "%s %s" % [medium, face]
			# From the clear hub's edge underneath out past the label's inner edge, short of the data.
			assert_float(decal.label_inner).override_failure_message(seen).is_equal_approx(disc.mirror_inner, EPSILON)
			assert_float(decal.label_outer).override_failure_message(seen).is_between(disc.label_inner,
				disc.data_inner)
			var arrays := ring.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in points.size():
				var height := (ring.transform * points[i]).z / MM - bottom
				assert_float(height * up).override_failure_message("%s off the mirror: %f mm" % [seen, height]) \
					.is_between(EPSILON, ON_MM)
				assert_float((ring.transform.basis * normals[i]).z).override_failure_message(
					"%s turned the wrong way" % seen).is_equal_approx(up, EPSILON)
			_assert_printed(ring, decal, up < 0.0, seen)


func _assert_printed(ring: MeshInstance3D, decal: DiscShape, mirrored: bool, seen: String) -> void:
	var printed := ring.get_active_material(0) as ShaderMaterial
	var image: Texture2D = printed.get_shader_parameter(&"label_texture")
	assert_bool(printed.get_shader_parameter(&"has_label")).override_failure_message(seen).is_true()
	assert_bool(image.get_image().has_mipmaps()).override_failure_message(
		"%s blurs and shimmers without its mipmaps" % seen).is_true()
	# The image spans the decal disc's square.
	assert_float(image.get_width() / (2.0 * decal.radius)).override_failure_message("%s not sharp" % seen) \
		.is_greater_equal(PX_PER_MM)
	# Seen from the side it faces, the image's width runs to the right of its height (which runs down)
	# when upright, to its left when mirrored.
	var arrays := ring.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var corners: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var points := ring.transform * vertices
	var along: Array[Vector3] = [points[corners[1]] - points[corners[0]], points[corners[2]] - points[corners[0]]]
	var turn := Transform2D(uvs[corners[1]] - uvs[corners[0]], uvs[corners[2]] - uvs[corners[0]], Vector2.ZERO) \
		.affine_inverse()
	var per_u := along[0] * turn.x.x + along[1] * turn.x.y
	var per_v := along[0] * turn.y.x + along[1] * turn.y.y
	var facing := ring.transform.basis * normals[corners[0]]
	assert_bool(per_u.cross(per_v).dot(facing) > 0.0).override_failure_message(
		"%s %s" % [seen, "upright" if mirrored else "mirrored"]).is_equal(mirrored)


func _model(medium: String) -> Node3D:
	return auto_free((load(MediumManifest.found()[medium].scene) as PackedScene).instantiate())
