# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Exports a console or a medium for a three.js viewer, where a console's launch steps are tuned
## (run by scripts/export_console.sh): its model as `<folder>.glb`, every moving part a named node turning
## or sliding about its own origin, our shaders drawn as plain PBR materials there; and
## `<folder>.model.json`, what the viewer moves and checks. For a console: how it is presented, its
## seat and way in, its moving parts (each with its role, its values at rest and fully moved, its
## unit, every node it moves and every material parameter it sets, at rest and fully moved, and the
## seat once it is fully moved), and its fingerprint ([method ConsoleModel.fingerprint]): steps tuned
## on it carry it, and scripts/launch_steps.py refuses them once the model has changed. For a medium: its
## kind, where its title and platform's name are drawn on its label, and its dimensions' hash.

## Our shaders' colour, by the first of these parameters they have.
const _COLOURS: Array[StringName] = [&"albedo", &"tint", &"mirror_color", &"blank_color"]
## The standard material's property each of our shaders' parameters stands for.
const _PBR: Dictionary[StringName, StringName] = {
	&"roughness": &"roughness", &"metallic": &"metallic", &"emission": &"emission",
	&"emission_energy": &"emission_energy_multiplier",
}


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() != 2:
		_fail("usage: export_console.gd -- <folder> <out_dir>")
		return
	var folder := arguments[0]
	var out_dir := arguments[1]
	var console := ConsoleManifest.of(folder)
	var medium: MediumManifest = MediumManifest.found().get(folder)
	if not console and not medium:
		_fail("no console nor medium folder %s" % folder)
		return
	var model: Node3D = (load(console.scene if console else medium.scene) as PackedScene).instantiate()
	root.add_child(model)
	# Ready once the tree has run a frame: its parts move only then.
	await process_frame
	var description := {"id": folder, "mm_per_unit": 1.0 / MeshBuilder.UNITS_PER_MM}
	if model is ConsoleModel:
		var shown: ConsoleModel = model
		description.merge({
			"name": "%s %s" % [console.name, console.model_name],
			"presented": _pose(Transform3D(shown.presented())),
			"seat": _pose(shown.seat()),
			"approach": _vector(shown.approach()),
			"moving_parts": _moving_parts(shown),
			"hash": shown.fingerprint(),
		})
	else:
		var shape := ((model.get_node(^"Label") as MeshInstance3D).mesh as ShapedMesh).shape
		description.merge({
			"media": medium.media,
			"title_area": _rect(shape.title_area()),
			"platform_area": _rect(shape.platform_area()),
			"hash": var_to_str(shape.dimensions()).sha256_text(),
		})
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		geometry.mesh = _plain(geometry)
		for surface in geometry.get_surface_override_material_count():
			geometry.set_surface_override_material(surface, null)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	DirAccess.make_dir_recursive_absolute(out_dir)
	var glb := out_dir.path_join(folder + ".glb")
	var exported := document.append_from_scene(model, state)
	if exported == OK:
		exported = document.write_to_filesystem(state, glb)
	if exported != OK:
		_fail("%s: %s" % [glb, error_string(exported)])
		return
	var json := FileAccess.open(out_dir.path_join(folder + ".model.json"), FileAccess.WRITE)
	json.store_string(JSON.stringify(description, "  ") + "\n")
	json.close()
	print("%s and %s.model.json written" % [glb, folder])
	model.free()
	quit()


## Each part of [param model] that moves, the others at rest: its role, its values and its unit
## (the last word of its property's name, `lid_degrees`), and what it changes from rest to fully
## moved: each node it moves (its pose in its parent at both), each material parameter it sets (its
## value at both), and the seat once it is fully moved. Every part has every key, a light that moves
## no node an empty `nodes`.
static func _moving_parts(model: ConsoleModel) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for part in model.moving_parts():
		var resting := _state(model)
		model.set(part.property, part.open)
		var moved := _state(model)
		var nodes: Array[Dictionary] = []
		var materials: Array[Dictionary] = []
		for key: Array in resting:
			if var_to_str(moved[key]) == var_to_str(resting[key]):
				continue
			var change := {"node": key[0], "at_rest": resting[key], "moved": moved[key]}
			if key.size() == 1:
				nodes.append(change)
			else:
				materials.append(change.merged({"surface": key[1], "parameter": key[2]}))
		found.append({
			"property": part.property, "role": MovingPart.Role.find_key(part.role), "rest": part.rest,
			"open": part.open, "unit": part.property.get_slice("_", part.property.get_slice_count("_") - 1),
			"nodes": nodes, "materials": materials, "seat": _pose(model.seat()),
		})
		model.set(part.property, part.rest)
	return found


## What a part of [param model] can change: each node's pose in its parent and whether it shows, by
## `[node]`, and each parameter of its meshes' shader materials, by `[node, surface, parameter]`.
static func _state(model: ConsoleModel) -> Dictionary[Array, Variant]:
	var found: Dictionary[Array, Variant] = {}
	for node: Node3D in model.find_children("*", "Node3D", true, false):
		var path := str(model.get_path_to(node))
		found[[path]] = _pose(node.transform).merged({"visible": node.visible})
		var geometry := node as MeshInstance3D
		for surface in geometry.mesh.get_surface_count() if geometry and geometry.mesh else 0:
			var shaded := geometry.get_active_material(surface) as ShaderMaterial
			for uniform: Dictionary in shaded.shader.get_shader_uniform_list() if shaded and shaded.shader else []:
				var name: StringName = uniform["name"]
				found[[path, surface, name]] = _json(shaded.get_shader_parameter(name))
	return found


static func _pose(transform: Transform3D) -> Dictionary:
	var turned := transform.basis.get_rotation_quaternion()
	return {"position": _vector(transform.origin), "rotation": [turned.x, turned.y, turned.z, turned.w],
		"scale": _vector(transform.basis.get_scale())}


static func _vector(vector: Vector3) -> Array[float]:
	return [vector.x, vector.y, vector.z]


## [param rect] as its position and size, as fractions of the label's image.
static func _rect(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


## [param value] as JSON writes it: a colour or a vector as its numbers, a texture by its path.
static func _json(value: Variant) -> Variant:
	if value is Color:
		var colour: Color = value
		return [colour.r, colour.g, colour.b, colour.a]
	if value is Vector3:
		var vector: Vector3 = value
		return _vector(vector)
	if value is Resource:
		var resource: Resource = value
		return resource.resource_path
	return value


## [param geometry]'s mesh as plain arrays, each surface drawn as our shader would be, roughly, by a
## standard material: the viewer knows nothing of our shaders. Without vertex colours: only the clear
## plastic reads them (as its rim), and a viewer would multiply every colour by them.
static func _plain(geometry: MeshInstance3D) -> ArrayMesh:
	var plain := ArrayMesh.new()
	for surface in geometry.mesh.get_surface_count():
		var arrays := geometry.mesh.surface_get_arrays(surface)
		arrays[Mesh.ARRAY_COLOR] = null
		plain.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var own := geometry.get_active_material(surface)
		if own is ShaderMaterial:
			var shaded: ShaderMaterial = own
			own = _standard(shaded)
		plain.surface_set_material(surface, own)
	return plain


## [param shaded] as a standard material: its colour (its label's image once shown), roughness,
## metal and light, where the material gives them (headless, Godot knows no shader's defaults: the
## standard ones stand for them).
static func _standard(shaded: ShaderMaterial) -> StandardMaterial3D:
	var standard := StandardMaterial3D.new()
	for uniform in _COLOURS:
		var colour: Variant = shaded.get_shader_parameter(uniform)
		if colour is Vector3:
			var rgb: Vector3 = colour
			colour = Color(rgb.x, rgb.y, rgb.z)
		if colour is Color:
			standard.albedo_color = colour
			break
	for uniform in _PBR:
		var value: Variant = shaded.get_shader_parameter(uniform)
		if value != null:
			standard.set(_PBR[uniform], value)
	standard.emission_enabled = standard.emission.get_luminance() > 0.0
	if shaded.get_shader_parameter(&"has_label"):
		standard.albedo_color = Color.WHITE
		standard.albedo_texture = shaded.get_shader_parameter(&"label_texture")
	var opacity: Variant = shaded.get_shader_parameter(&"opacity")
	if opacity is float:
		standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		standard.albedo_color.a = opacity
	return standard


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
