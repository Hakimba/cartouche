# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree
## Renders the console of a folder under app/carousel/consoles, or the medium of one under
## app/carousel/media, as the carousel lights it, from six points of view, into one contact sheet (run
## by scripts/render_console.sh): front, three quarters, side, back, top, and three quarters with every
## part of a console fully moved, or a medium from below; to set a model beside photos of the real
## one. A medium shows the label image given after the PNG's path, if any, as it shows a game's scan.

const _VIEW := Vector2i(640, 480)
const _COLUMNS := 3


## A point of view: the direction the camera looks from, the console at rest or fully moved.
class View:
	var name: String
	var from: Vector3
	var moved: bool

	func _init(view_name: String, direction: Vector3, is_moved := false) -> void:
		name = view_name
		from = direction
		moved = is_moved


static func _views(console: bool) -> Array[View]:
	return [
		View.new("front", Vector3(0, 0.15, 1)),
		View.new("three quarters", Vector3(-0.8, 0.6, 1)),
		View.new("side", Vector3(1, 0.15, 0)),
		View.new("back", Vector3(0, 0.15, -1)),
		View.new("top", Vector3(0, 1, 0.001)),
		View.new("moved", Vector3(-0.8, 0.6, 1), true) if console else View.new("bottom", Vector3(0, -1, 0.001)),
	]


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() not in [2, 3]:
		_fail("usage: render_console.gd -- <folder> <png> [label image]")
		return
	var console := ConsoleManifest.of(arguments[0])
	var medium: MediumManifest = MediumManifest.found().get(arguments[0])
	if not console and not medium:
		_fail("no console nor medium folder %s" % arguments[0])
		return
	var model: Node3D = (load(console.scene if console else medium.scene) as PackedScene).instantiate()
	if medium and arguments.size() == 3:
		var label: ShaderMaterial = (model.get_node(^"Label") as MeshInstance3D).get_surface_override_material(0)
		label.set_shader_parameter(&"label_texture", ImageTexture.create_from_image(Image.load_from_file(arguments[2])))
		label.set_shader_parameter(&"scanned", true)
		label.set_shader_parameter(&"has_label", true)
	root.size = _VIEW
	root.add_child(_studio())
	root.add_child(model)
	var camera := Camera3D.new()
	camera.fov = 32.0
	root.add_child(camera)
	await process_frame
	var views := _views(console != null)
	var sheet := Image.create(_VIEW.x * _COLUMNS, _VIEW.y * ceili(views.size() / float(_COLUMNS)), false,
		Image.FORMAT_RGBA8)
	for index in views.size():
		var view := views[index]
		if model is ConsoleModel:
			var moving: ConsoleModel = model
			for part in moving.moving_parts():
				moving.set(part.property, part.open if view.moved else part.rest)
		await process_frame
		_aim(camera, _bounds(model), view.from)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var shot := root.get_texture().get_image()
		shot.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, _VIEW),
			Vector2i(index % _COLUMNS, floori(index / float(_COLUMNS))) * _VIEW)
	var saved := sheet.save_png(arguments[1])
	if saved != OK:
		_fail("%s: %s" % [arguments[1], error_string(saved)])
		return
	print("%s written (%s)" % [arguments[1], ", ".join(views.map(func(v: View) -> String: return v.name))])
	quit()


## The carousel's light, as carousel.tscn has it: its environment, here against its studio sky, and
## its sun. Read from the scene's nodes, not made from it: its scripts need the app around them.
static func _studio() -> Node3D:
	var state := (load("res://carousel/carousel.tscn") as PackedScene).get_state()
	var studio := Node3D.new()
	for node in state.get_node_count():
		if state.get_node_type(node) not in [&"WorldEnvironment", &"DirectionalLight3D"]:
			continue
		var made: Node = ClassDB.instantiate(state.get_node_type(node))
		for property in state.get_node_property_count(node):
			made.set(state.get_node_property_name(node, property), state.get_node_property_value(node, property))
		if made is WorldEnvironment:
			var world: WorldEnvironment = made
			world.environment = world.environment.duplicate()
			world.environment.background_mode = Environment.BG_SKY
		studio.add_child(made)
	return studio


static func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var found := false
	for geometry: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not geometry.is_visible_in_tree():
			continue
		var part := geometry.global_transform * geometry.get_aabb()
		box = part if not found else box.merge(part)
		found = true
	return box


## Points [param camera] at [param box] from [param from], far enough for it to fill most of the view.
static func _aim(camera: Camera3D, box: AABB, from: Vector3) -> void:
	var radius := box.size.length() / 2.0
	var distance := radius / sin(deg_to_rad(camera.fov / 2.0)) * 1.05
	var centre := box.get_center()
	camera.look_at_from_position(centre + from.normalized() * distance, centre,
		Vector3.FORWARD if absf(from.normalized().y) > 0.99 else Vector3.UP)


func _fail(message: String) -> void:
	printerr(message)
	quit(1)
