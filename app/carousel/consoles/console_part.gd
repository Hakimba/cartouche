# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsolePart
extends Resource
## A moving part of a [ConsoleModel], declared in its scene: the node it moves, how, and what the launch does with it.
## The model gets a float property named [member property]; setting it moves [member node] from the rest the scene
## gives it. Two parts may share a property (two flaps pushed open together): they move together, and the first one
## gives the role and the values.

## How [member node] moves with the value: turned by it in degrees about [member axis], slid by it in millimetres along
## [member axis], or glowing with it (the console's [member ConsoleModel.light_energy], [member node] a mesh).
enum Motion { TURN, SLIDE, LIGHT }
## What the part does in a launch: lets the medium in, open before it comes and closed once it is in
## (a lid, a tray, a door); comes on once it is in, and stays on (a power switch, a light); turns;
## moves only in a console's own steps (a reset button, a door aside); is pushed open by the medium
## and held open while it is in (spring flaps); is pressed and let go before the openings open (an
## eject or open button); is pressed as the console comes on and let go at once (a momentary power
## button, where a latching one is a power part).
enum Role { OPENING, POWER, LIGHT, SPIN, POSE, FLAP, PRESS, POWER_PRESS }

## The model's property, named after its unit (`lid_degrees`, `power_mm`); `light_energy` for a light.
@export var property: StringName
## The node it moves, from the model's root (`Model/gba_sp/lid`, `Lid`), its origin on the part's pivot.
@export var node: NodePath
@export var motion := Motion.TURN
## The axis it turns about or slides along, in its parent's frame, signed: the way the value grows.
@export var axis := Vector3.RIGHT
## What the launch does with it, and its value at rest and fully moved.
@export var role := Role.POSE
@export var rest := 0.0
@export var open := 0.0
