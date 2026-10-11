# SPDX-License-Identifier: GPL-3.0-or-later
@abstract
class_name ConsoleModel
extends Node3D
## A console as the consoles screen shows it and a game goes into it: all the carousel and the
## launch know of one. Each console is a folder of its own (see ONBOARDING, "Adding a console"),
## its scene's root a model of this kind, built from its [member shape].
##
## The parts that move are float properties of the model, its [method moving_parts]: the launch
## animation's steps move them by name, and a console without steps of its own plays the
## placeholder ([method LaunchAnimation.placeholder]) their roles make.
##
## [method moving_parts], [method seat], [method approach] and [method presented] depend only on
## [member shape] and the parts' properties, never on the model's nodes: the launch animation is
## made from a model that is not ready, nor in the tree.

## How far, in millimetres, a moving part may stand out of the console's static parts at rest,
## unless it opens or carries the medium (those lie within them): a button, a knob, a switch. The
## NES's buttons stand 6 mm out of its front, the most of the real ones.
const PROUD_MM := 7.0
## How far a pressed button still stands out of the face around it, in millimetres: it never sinks
## into it out of sight.
const PRESSED_SHOWS_MM := 0.3

@export var shape: ModelShape

## How bright the console's light is, from off (0): the glow of its scene's `%Light` mesh, on a
## console whose moving parts have a [enum MovingPart.Role] `LIGHT` one by this name.
var light_energy := 0.0:
	set(value):
		# Given each frame by the launch animation: set on the light only when it changes.
		if value != light_energy and is_node_ready():
			set_shader_value(_light(), &"emission_energy", value)
		light_energy = value

var _fade: ModelFade


## How far a button standing [param raise] millimetres out of the face around it goes in when
## pressed: its real [param travel], or less, so that it still stands [constant PRESSED_SHOWS_MM]
## out of it.
static func press_travel(raise: float, travel: float) -> float:
	return minf(travel, raise - PRESSED_SHOWS_MM)


# Every class of a model gets its notifications, whatever its own _ready does.
func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		_fade = ModelFade.new(self)
		if has_node(^"%Light"):
			set_shader_value(_light(), &"emission_energy", light_energy)


## The parts that move, each a float property of this model, at its rest value on a new model.
@abstract func moving_parts() -> Array[MovingPart]


## Where a seated medium stands, in the model's space, wherever the part carrying it has moved to:
## the medium's own origin and axes, as its model in `carousel/models/` has them (a disc: its
## centre, its axis Z, the label towards +Z; a cartridge: the middle of its outline, half way
## through its body, +Z out of its label, +Y towards its top edge).
@abstract func seat() -> Transform3D


## The way a medium goes in, a unit vector in the seat's frame: it comes down to the seat along
## it, from the way it points.
func approach() -> Vector3:
	return Vector3.BACK


## How the console is turned to face the camera, as the placeholder stands it on the consoles
## screen and through the launch: by default, about X only, its way in towards the camera.
func presented() -> Basis:
	var way_in := seat().basis * approach()
	return Basis(Vector3.RIGHT, atan2(way_in.y, way_in.z))


## The medium is in: turned [param _angle] radians about its axis, as the console turns it.
func hold(_angle: float) -> void:
	pass


## Fades the console [param amount], from 0 (opaque) to 1 (gone).
func fade(amount: float) -> void:
	_fade.apply(amount)


## Sets the shader [param parameter] of what [param geometry] is drawn with to [param value], on its
## own materials and on the copies it fades through (see [ModelFade]): a light coming on. Before the
## model is ready, on its own materials, which the copies are then made from.
func set_shader_value(geometry: MeshInstance3D, parameter: StringName, value: Variant) -> void:
	if _fade:
		_fade.set_shader_value(geometry, parameter, value)
		return
	for index in geometry.mesh.get_surface_count():
		var material: ShaderMaterial = geometry.get_active_material(index)
		material.set_shader_parameter(parameter, value)


## What steps are tuned on, hashed: the shape's dimensions and each moving part's property, role and
## values at rest and fully moved. A console's `launch.json` carries the one its steps were tuned
## on (`model_hash`).
func fingerprint() -> String:
	var parts := moving_parts().map(func(part: MovingPart) -> Array:
		return [part.property, part.role, part.rest, part.open])
	return var_to_str([shape.dimensions(), parts]).sha256_text()


func _light() -> MeshInstance3D:
	return get_node(^"%Light")
