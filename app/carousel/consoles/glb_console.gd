# SPDX-License-Identifier: GPL-3.0-or-later
class_name GlbConsole
extends ConsoleModel
## A console drawn from a glb, declared as data in its scene: the glb instanced as `Model`, its [GlbConsoleShape]
## (where the medium seats), the way the medium comes in, how it is presented, and its moving [member parts]. A console
## needs a script of its own only for what data cannot say (the NES's seat follows its tray): it extends this one.

## How the console is turned to face the camera: about X only, its way in towards the camera
## ([method ConsoleModel.presented]); standing as a handheld is held ([method ConsoleModel.standing]); or as a home
## console on a shelf ([method ConsoleModel.three_quarter]).
enum Pose { WAY_IN, STANDING, THREE_QUARTER }

## The parts that move, in the order the launch lists them.
@export var parts: Array[ConsolePart] = []
## The way the medium goes in ([method ConsoleModel.approach]), a unit vector in the seat's frame.
@export var way_in := Vector3.BACK
@export var pose := Pose.WAY_IN

## Each part's value once set, by property; a part not set yet is at its rest.
var _values: Dictionary[StringName, float] = {}
## Where each turning or sliding part's node rests, its rotation or its position, as the glb gives it.
var _rests: Dictionary[ConsolePart, Vector3] = {}


func _ready() -> void:
	Diagnostics.trace("console", "model=%s glb" % scene_file_path.get_file().get_basename())
	for part in parts:
		if part.motion != ConsolePart.Motion.LIGHT:
			var moved := get_node(part.node) as Node3D
			_rests[part] = moved.rotation if part.motion == ConsolePart.Motion.TURN else moved.position
			_place(part)


func moving_parts() -> Array[MovingPart]:
	var found: Array[MovingPart] = []
	for part in parts:
		if found.all(func(listed: MovingPart) -> bool: return listed.property != part.property):
			var travel: float = shape.get(part.open_from) if part.open_from else part.open
			found.append(MovingPart.new(part.property, part.role, part.rest, travel))
	return found


func seat() -> Transform3D:
	return (shape as GlbConsoleShape).seat()


func approach() -> Vector3:
	return way_in


func presented() -> Basis:
	match pose:
		Pose.STANDING:
			return standing()
		Pose.THREE_QUARTER:
			return three_quarter()
	return super()


## The value of moving part [param property], as the launch last set it.
func value_of(property: StringName) -> float:
	return _values.get(property, _first(property).rest)


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


func _lights() -> Array[MeshInstance3D]:
	var found := super()
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


## Moves [param part]'s node from its rest by its value, worked out in double precision, as the glb's rest is kept.
func _place(part: ConsolePart) -> void:
	var moved := get_node(part.node) as Node3D
	var by := value_of(part.property)
	if part.motion == ConsolePart.Motion.TURN:
		moved.rotation = _along(_rests[part], part.axis, deg_to_rad(by))
	else:
		moved.position = _along(_rests[part], part.axis, by * MeshBuilder.UNITS_PER_MM)


static func _along(rest: Vector3, axis: Vector3, distance: float) -> Vector3:
	return Vector3(rest.x + axis.x * distance, rest.y + axis.y * distance, rest.z + axis.z * distance)
