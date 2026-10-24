# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name NesShape
extends GlbShape
## What the launch reads of the NES (its glb, `nes.glb`), in millimetres, in the model's axes: X to the
## right, Y up from the table, Z towards the front, from the body's middle.

## The door open, in degrees, its lid standing up under its face tipped back (measured on a photo of
## the console being loaded).
const DOOR_OPEN := 65.0
## How far the power button latches in and the reset button goes in pressed, in millimetres.
const BUTTON_IN := 2.5

## The cartridges the slot takes: their width, length and thickness.
@export var cartridge := Vector3(119.0, 133.0, 19.0):
	set(value):
		cartridge = value
		emit_changed()
## How far the tray's front is tilted up to take a cartridge, in degrees.
@export var tray_tilt := 10.0:
	set(value):
		tray_tilt = value
		emit_changed()
## Where the tray turns, at a seated cartridge's back end (the glb's `tray` node, which a test holds it to).
@export var tray_pivot := Vector3(-20.05, 46.7718, -31.5):
	set(value):
		tray_pivot = value
		emit_changed()


## The tray tilted [param degrees] up about its pivot, in the model's space.
func tray(degrees: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -deg_to_rad(degrees)), tray_pivot * MeshBuilder.UNITS_PER_MM)


## Where a seated cartridge's centre is, in the model's space, the tray tilted [param degrees]: its label up,
## its top edge towards the front.
func seat(degrees: float) -> Transform3D:
	var centre := Vector3(0.0, 0.0, cartridge.y / 2.0) * MeshBuilder.UNITS_PER_MM
	return tray(degrees) * Transform3D(Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP), centre)
