# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsolePart
extends Resource
## A moving part of a [GlbConsole], declared in its scene: the glb node it moves, how, and what the launch does with it.
## The model gets a float property named [member property]; setting it moves [member node] from the rest the glb gives
## it. Two parts may share a property (two flaps pushed open together): they move together, and the first one gives
## the role and the values.

## How [member node] moves with the value: turned by it in degrees about [member axis], slid by it in millimetres along
## [member axis], or glowing with it (the console's [member ConsoleModel.light_energy], [member node] a mesh).
enum Motion { TURN, SLIDE, LIGHT }

## The model's property, named after its unit (`lid_degrees`, `power_mm`); `light_energy` for a light.
@export var property: StringName
## The node it moves, from the model's root (`Model/gba_sp/lid`), its origin on the part's pivot.
@export var node: NodePath
@export var motion := Motion.TURN
## The axis it turns about or slides along, in its parent's frame, signed: the way the value grows.
@export var axis := Vector3.RIGHT
## What the launch does with it ([enum MovingPart.Role]), and its value at rest and fully moved.
@export var role := MovingPart.Role.POSE
@export var rest := 0.0
@export var open := 0.0
## The dimension of the model's shape that gives [member open] instead, when its travel is a measure of the shape
## (`power_travel`).
@export var open_from: StringName
