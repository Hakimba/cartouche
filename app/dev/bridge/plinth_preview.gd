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
var _spin: Node3D
var _stand: Node3D


func show_console(plinth: Plinth) -> void:
	folder = plinth.console()
	_plinth = plinth
	var scene := load(ConsoleManifest.of(folder).scene) as PackedScene
	var rig := Plinth.build_view(folder, scene, plinth, self)
	_view = rig.view
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	model = rig.model
	camera = rig.camera
	lights = rig.lights
	start = rig.start
	_spin = rig.spin
	_stand = rig.stand
	(plinth.get_node("Turntable") as TextureRect).texture = _view.get_texture()


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
