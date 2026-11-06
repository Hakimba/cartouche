# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleModel
extends Node3D
## A console as the consoles screen shows it and a game goes into it: all the carousel and the launch know of one.
## Each console is a folder of its own (see docs/adding-a-console.md), its scene's root a model of this kind, declared
## as data: its meshes (a glb instanced as `Model`, or mesh files of its own), its [member shape] (where the medium
## seats), the way the medium comes in, how it is presented, and its moving [member parts].
##
## The parts that move are float properties of the model, its [method moving_parts]: the launch animation's steps move
## them by name, and a console without steps of its own plays the placeholder ([method LaunchAnimation.placeholder])
## their roles make.
##
## [method moving_parts], [method seat], [method approach] and [method presented] depend only on this data and the
## parts' values, never on the model's nodes: the launch animation is made from a model that is not ready, nor in the
## tree.

## How far, in millimetres, a moving part may stand out of the console's static parts at rest,
## unless it opens or carries the medium (those lie within them): a button, a knob, a switch. The
## NES's buttons stand 6 mm out of its front, the most of the real ones.
const PROUD_MM := 7.0

@export var shape: SeatShape
## The parts that move, in the order the launch lists them.
@export var parts: Array[ConsolePart] = []
## The way the medium goes in ([method approach]), a unit vector in the seat's frame.
@export var way_in := Vector3.BACK
## How the console is turned to face the camera, in degrees (Godot's Euler order, YXZ): a handheld stands leant back
## towards it (15, 0, 0); a home console is seen from above its front and to its left, as on a shelf (25, 20, 0). Left
## at zero, it is turned about X only, its way in towards the camera.
@export var pose_degrees := Vector3.ZERO
## The disc drive's spindle a seated disc turns on, if any ([method hold]).
@export var spindle: Spindle

## How bright the console's light is, from off (0): the glow of its `LIGHT` parts' meshes.
var light_energy := 0.0:
	set(value):
		# Given each frame by the launch animation: set on the light only when it changes.
		if value != light_energy and is_node_ready():
			for light in _lights():
				set_shader_value(light, &"emission_energy", value)
		light_energy = value

var _fade: ModelFade
## Each part's value once set, by property; a part not set yet is at its rest.
var _values: Dictionary[StringName, float] = {}
## Where each turning or sliding part's node rests, its rotation or its position, as the scene gives it.
var _rests: Dictionary[ConsolePart, Vector3] = {}


func _ready() -> void:
	Diagnostics.trace("console", "model=%s" % scene_file_path.get_file().get_basename())
	_fade = ModelFade.new(self)
	for light in _lights():
		set_shader_value(light, &"emission_energy", light_energy)
	for part in parts:
		if part.motion != ConsolePart.Motion.LIGHT:
			var moved := get_node(part.node) as Node3D
			_rests[part] = moved.rotation if part.motion == ConsolePart.Motion.TURN else moved.position
			_place(part)


## The parts that move, at their rest values on a new model: the first part of each property, which gives its role
## and values.
func moving_parts() -> Array[ConsolePart]:
	var found: Array[ConsolePart] = []
	for part in parts:
		if found.all(func(listed: ConsolePart) -> bool: return listed.property != part.property):
			found.append(part)
	return found


## Where a seated medium stands, in the model's space, wherever the part carrying it has moved to:
## the medium's own origin and axes, as its model in `carousel/models/` has them (a disc: its
## centre, its axis Z, the label towards +Z; a cartridge: the middle of its outline, half way
## through its body, +Z out of its label, +Y towards its top edge).
func seat() -> Transform3D:
	var at := shape.seat()
	var carrier := _first(shape.carrier) if shape.carrier else null
	if not carrier:
		return at
	var by := value_of(carrier.property)
	if carrier.motion == ConsolePart.Motion.SLIDE:
		return Transform3D(at.basis, _along(shape.seat_centre, carrier.axis, by) * MeshBuilder.UNITS_PER_MM)
	var pivot := shape.pivot * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(carrier.axis, deg_to_rad(by)), pivot) * Transform3D(Basis(), -pivot) * at


## The way a medium goes in, a unit vector in the seat's frame: it comes down to the seat along
## it, from the way it points.
func approach() -> Vector3:
	return way_in


## How the console is turned to face the camera, as the placeholder stands it on the consoles
## screen and through the launch ([member pose_degrees]).
func presented() -> Basis:
	if pose_degrees != Vector3.ZERO:
		return Basis.from_euler(pose_degrees * PI / 180.0)
	var way := seat().basis * approach()
	return Basis(Vector3.RIGHT, atan2(way.y, way.z))


## The medium is in: turned [param angle] radians about its axis, as the console turns it.
func hold(angle: float) -> void:
	if spindle:
		spindle.turn(angle)


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


## The value of moving part [param property], as the launch last set it.
func value_of(property: StringName) -> float:
	return _values.get(property, _first(property).rest)


## What steps are tuned on, hashed: the seat, each moving part's property, role and values at rest and fully moved,
## and the bytes of the files the console is drawn from (its glb or its mesh files): another export of them is
## another model. A console's `launch.json` carries the one its steps were tuned on (`model_hash`).
func fingerprint() -> String:
	var moving := moving_parts().map(func(part: ConsolePart) -> Array:
		return [part.property, part.role, part.rest, part.open])
	var files := PackedStringArray()
	for node in find_children("*", "Node3D", true, false):
		var drawn := node as MeshInstance3D
		var file := drawn.mesh.resource_path if drawn and drawn.mesh else node.scene_file_path
		if file.get_extension() in ["glb", "res"] and file not in files:
			files.append(file)
	var seated := [shape.seat_centre, shape.seat_degrees, shape.carrier, shape.pivot]
	return var_to_str([seated, moving, Array(files).map(FileAccess.get_sha256)]).sha256_text()


func _get(property: StringName) -> Variant:
	return value_of(property) if _first(property) else null


func _set(property: StringName, value: Variant) -> bool:
	if not _first(property):
		return false
	# Given each frame by the launch animation: the nodes are moved only when it changes.
	if value != value_of(property):
		_values[property] = value
		if is_node_ready():
			for part in parts:
				if part.property == property:
					_place(part)
	return true


## The meshes that glow when the light is on: the nodes of its `LIGHT` parts.
func _lights() -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for part in parts:
		if part.motion == ConsolePart.Motion.LIGHT:
			found.append(get_node(part.node) as MeshInstance3D)
	return found


## The first part moved by [param property], whose role and values it has; none for another property, or for the
## light, a property of every console.
func _first(property: StringName) -> ConsolePart:
	for part in parts:
		if part.property == property and part.motion != ConsolePart.Motion.LIGHT:
			return part
	return null


## Moves [param part]'s node from its rest by its value, worked out in double precision, as its rest is kept.
func _place(part: ConsolePart) -> void:
	var moved := get_node(part.node) as Node3D
	var by := value_of(part.property)
	if part.motion == ConsolePart.Motion.TURN:
		moved.rotation = _along(_rests[part], part.axis, deg_to_rad(by))
	else:
		moved.position = _along(_rests[part], part.axis, by * MeshBuilder.UNITS_PER_MM)


static func _along(rest: Vector3, axis: Vector3, distance: float) -> Vector3:
	return Vector3(rest.x + axis.x * distance, rest.y + axis.y * distance, rest.z + axis.z * distance)
