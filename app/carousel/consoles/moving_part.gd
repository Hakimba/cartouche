# SPDX-License-Identifier: GPL-3.0-or-later
class_name MovingPart
extends RefCounted
## A part of a console that moves: a float [member property] of its [ConsoleModel] (such as
## `lid_degrees`), what it does, and its value at [member rest] and fully moved ([member open]).

## What the part does in a launch: lets the medium in, open before it comes and closed once it is in
## (a lid, a tray, a door); comes on once it is in, and stays on (a power switch, a light); turns;
## moves only in a console's own steps (a reset button, a door aside); is pushed open by the medium
## and held open while it is in (spring flaps); is pressed and let go before the openings open (an
## eject or open button); is pressed as the console comes on and let go at once (a momentary power
## button, where a latching one is a power part).
enum Role { OPENING, POWER, LIGHT, SPIN, POSE, FLAP, PRESS, POWER_PRESS }

var property: StringName
var role: Role
var rest: float
var open: float


func _init(moved: StringName, does: Role, at_rest: float, fully_moved: float) -> void:
	property = moved
	role = does
	rest = at_rest
	open = fully_moved
