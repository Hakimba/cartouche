# SPDX-License-Identifier: GPL-3.0-or-later
extends Node

var folder := ""
var model: Node3D
var lights: StudioLights
var camera: Camera3D
## The start the model stands at, the file's until a tune gives another.
var start: Plinth.Start
var _plinth: Plinth
var _view: SubViewport
var _spin := Node3D.new()
var _stand := Node3D.new()


func show_console(plinth: Plinth) -> void:
	folder = plinth.console()
	_plinth = plinth
	var view := SubViewport.new()
	_view = view
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = plinth.get_viewport().msaa_3d
	view.size = Vector2i((StudioTokens.TURNTABLE.size * StudioTokens.window_scale(plinth.get_window())).ceil())
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var environment := WorldEnvironment.new()
	environment.environment = StudioLights.environment_of(plinth)
	view.add_child(environment)
	camera = Camera3D.new()
	camera.fov = 29.5
	camera.near = 0.05
	camera.far = 50.0
	view.add_child(camera)
	var scene := load(ConsoleManifest.of(plinth.console()).scene) as PackedScene
	model = scene.instantiate() as Node3D
	_spin.add_child(_stand)
	_stand.add_child(model)
	view.add_child(_spin)
	start = Plinth.start_of(plinth.console())
	lights = StudioLights.new(view, StudioLights.rig_of(plinth.console(), &"plinth"),
		Plinth.stand_at(_spin, _stand, model, start), environment.environment)
	camera.look_at_from_position(Plinth._CAMERA, Plinth._CAMERA_TARGET)
	(plinth.get_node("Turntable") as TextureRect).texture = view.get_texture()


## Lit again from the light file as it now reads.
func relight() -> void:
	var environment := lights._environment
	lights.dispose()
	lights = StudioLights.new(_view, StudioLights.rig_of(_plinth.console(), &"plinth"), Plinth.stand_at(_spin, _stand, model, start),
		environment)


## Stands the model at [param to] as the plinth's picture would show it.
func place(to: Plinth.Start) -> void:
	start = to
	lights.place(Plinth.stand_at(_spin, _stand, model, to))


func _process(_delta: float) -> void:
	if _plinth.console() != folder:
		queue_free()
	else:
		_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS if _plinth.is_visible_in_tree() else SubViewport.UPDATE_DISABLED
