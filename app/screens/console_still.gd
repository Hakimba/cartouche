# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleStill
extends SubViewport
## A console drawn once, still, on a transparent background, seen from above and to the side as
## a picture of it: its texture shows it. The console is framed whatever its size.

const _FIELD_OF_VIEW := 24.0
## The camera's height and side angles, in degrees.
const _ELEVATION := 38.0
const _AZIMUTH := 24.0


## Draws [param console] at [param pixels].
func _init(console: Node3D, pixels: Vector2i) -> void:
	own_world_3d = true
	transparent_bg = true
	size = pixels
	render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(console)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.77, 0.8)
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var camera := Camera3D.new()
	camera.fov = _FIELD_OF_VIEW
	add_child(camera)
	console.ready.connect(_frame.bind(console, camera), CONNECT_ONE_SHOT)


func _frame(console: Node3D, camera: Camera3D) -> void:
	var bounds := _bounds(console)
	var radius := bounds.size.length() / 2.0
	var distance := radius / sin(deg_to_rad(_FIELD_OF_VIEW) / 2.0) * 1.02
	var direction := Vector3.BACK.rotated(Vector3.RIGHT, -deg_to_rad(_ELEVATION)).rotated(Vector3.UP, deg_to_rad(_AZIMUTH))
	camera.look_at_from_position(bounds.get_center() + direction * distance, bounds.get_center())


## The box holding every mesh of [param root], in the world.
static func _bounds(root: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var box := mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds
