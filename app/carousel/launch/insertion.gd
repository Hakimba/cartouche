# SPDX-License-Identifier: GPL-3.0-or-later
class_name Insertion
extends RefCounted
## How a game goes into its console when it is launched, as pure functions of the time since the
## launch was confirmed: [GameLaunch] only applies them, and tests call them headless. The game
## turns to face the player, comes forward as if taken in hand, then goes back onto the drive's
## spindle, where it clicks into place with a small rebound; the drive spins it up, and the screen
## goes black from its centre. A medium without a spindle (a cartridge) goes back the same way,
## as if pushed into a slot, and does not spin.
##
## The drive leans back by [member tilt_degrees], so that its spindle shows as the game goes onto
## it; the game moves along the spindle's axis. One insertion per medium, read from
## `appearance.json`. Distances are in world units along that axis (towards the player is
## positive), in the row's space; times in seconds.

## What [method read] cannot take from an insertion's data as written.
enum Problem { UNKNOWN_KEY, NOT_A_NUMBER, BELOW_ZERO, NOT_A_SOUND }

## The distances and times of an insertion, as `appearance.json` spells them; all but the tilt are
## zero or more.
const _NUMBERS: Array[StringName] = [&"tilt_degrees", &"face_s", &"grab_s", &"grab_distance", &"seat_s",
	&"seat_depth", &"bounce", &"bounce_s", &"spin_up_s", &"turns_per_s", &"black_after_s", &"black_s"]

var tilt_degrees := 18.0
var face_s := 0.25
var grab_s := 0.3
var grab_distance := 0.45
var seat_s := 0.28
var seat_depth := 0.5
var bounce := 0.03
var bounce_s := 0.08
var spindle := true
var spin_up_s := 0.7
var turns_per_s := 15.0
## After the game is seated, the black starts growing, and covers the screen [member black_s] later.
var black_after_s := 0.35
var black_s := 0.35
var sounds: Array[Cue] = []


## The insertion [param data] describes, an entry of `appearance.json`'s `insertions`: what is
## missing, or cannot be taken as written (see [method problems]), keeps its default, and a number
## below zero that cannot be counts as zero; sounds play in the order of their delays.
static func read(data: Dictionary) -> Insertion:
	var insertion := Insertion.new()
	for number in _NUMBERS:
		var value: Variant = data.get(number)
		if value is float or value is int:
			var read_value: float = value
			insertion.set(number, read_value if number == &"tilt_degrees" else maxf(0.0, read_value))
	var has_spindle: Variant = data.get("spindle")
	if has_spindle is bool:
		insertion.spindle = has_spindle
	var cues: Variant = data.get("sounds")
	var listed: Array = cues if cues is Array else []
	for sound: Variant in listed:
		if _is_sound(sound):
			var entry: Dictionary = sound
			insertion.sounds.append(_cue(entry))
	insertion.sounds.sort_custom(func(a: Cue, b: Cue) -> bool: return a.delay_s < b.delay_s)
	return insertion


## What [method read] does not take from [param data] as written, by key: keys it does not know,
## values of another type, numbers below zero where they cannot be, sounds without a name.
static func problems(data: Dictionary) -> Dictionary[String, Problem]:
	var found: Dictionary[String, Problem] = {}
	for key: String in data:
		var value: Variant = data[key]
		if key in _NUMBERS:
			if not (value is float or value is int):
				found[key] = Problem.NOT_A_NUMBER
				continue
			var number: float = value
			if key != "tilt_degrees" and number < 0.0:
				found[key] = Problem.BELOW_ZERO
		elif key == "spindle":
			if not value is bool:
				found[key] = Problem.NOT_A_NUMBER
		elif key == "sounds":
			var list: Array = value if value is Array else [null]
			if not list.all(_is_sound):
				found[key] = Problem.NOT_A_SOUND
		else:
			found[key] = Problem.UNKNOWN_KEY
	return found


static func _is_sound(sound: Variant) -> bool:
	if not sound is Dictionary:
		return false
	var entry: Dictionary = sound
	return entry.get("name") is String


static func _cue(sound: Dictionary) -> Cue:
	var cue := Cue.new()
	cue.name = sound["name"]
	for key: StringName in [&"delay_s", &"from_s", &"volume_db"]:
		var value: Variant = sound.get(key)
		if value is float or value is int:
			var read_value: float = value
			cue.set(key, read_value if key == &"volume_db" else maxf(0.0, read_value))
	return cue


## When the game touches the spindle: the click, and the drive starts.
func seated_s() -> float:
	return face_s + grab_s + seat_s


## When the screen is all black: the game can start.
func duration_s() -> float:
	return seated_s() + black_after_s + black_s


## How the drive stands: its spindle's axis is the basis' z, towards the player.
func drive() -> Basis:
	return Basis.from_euler(Vector3(-deg_to_rad(tilt_degrees), 0.0, 0.0))


## Where the spindle stands: the seated game's centre.
func spindle_stand() -> Transform3D:
	return Transform3D(drive(), drive().z * -seat_depth)


## Where the game stands at [param t], from how it stood when the launch was confirmed,
## [param start]; facing the drive, then on its axis, seated on its spindle and still from
## [method seated_s] plus the rebound. Its spin about its own axis is [method spin_at].
func stand_at(t: float, start: Transform3D) -> Transform3D:
	var faced := smoothstep(0.0, 1.0, _progress(t, 0.0, face_s))
	var turned := start.basis.get_rotation_quaternion().slerp(drive().get_rotation_quaternion(), faced)
	var scale := start.basis.get_scale().lerp(Vector3.ONE, faced)
	var origin := start.origin.lerp(Vector3.ZERO, faced) + drive().z * _depth_at(t)
	return Transform3D(Basis(turned).scaled_local(scale), origin)


## How far the drive has turned the game, in radians: speeding up evenly for [member spin_up_s]
## from the moment it is seated, then turning [member turns_per_s] times a second.
func spin_at(t: float) -> float:
	if not spindle:
		return 0.0
	var spun := maxf(0.0, t - seated_s())
	var ramp := minf(spun, spin_up_s)
	var full_speed := TAU * turns_per_s
	var ramped := full_speed * ramp * ramp / (2.0 * spin_up_s) if spin_up_s > 0.0 else 0.0
	return ramped + full_speed * (spun - ramp)


## How fast the game turns at [param t], in radians a second.
func spin_speed_at(t: float) -> float:
	return TAU * turns_per_s * _progress(t, seated_s(), spin_up_s) if spindle else 0.0


## How visible the spindle is at [param t], from 0 to 1: it appears while the game is taken in hand.
func spindle_at(t: float) -> float:
	return _progress(t, face_s, grab_s) if spindle else 0.0


## How much of the screen is black at [param t], from 0 to 1 (all of it): the black grows from the
## game's centre, faster and faster.
func black_at(t: float) -> float:
	return pow(_progress(t, seated_s() + black_after_s, black_s), 2.0)


## How visible the title pill and the top bar are at [param t]: they fade out as the game turns.
func controls_at(t: float) -> float:
	return 1.0 - _progress(t, 0.0, face_s)


## The game's depth at [param t]: forward, back past the start to the spindle, a small rebound.
func _depth_at(t: float) -> float:
	var grabbed := _progress(t, face_s, grab_s)
	var pushed := _progress(t, face_s + grab_s, seat_s)
	var rebound := _progress(t, seated_s(), bounce_s)
	var depth := grab_distance * (1.0 - pow(1.0 - grabbed, 2.0))
	depth = lerpf(depth, -seat_depth, pushed * pushed)
	return depth + bounce * sin(PI * rebound)


## How far [param t] is through the step starting at [param from] and lasting [param length],
## from 0 to 1; a step of no length is done as soon as it starts.
static func _progress(t: float, from: float, length: float) -> float:
	if length <= 0.0:
		return 1.0 if t >= from else 0.0
	return clampf((t - from) / length, 0.0, 1.0)


## A sound of the insertion, played [member delay_s] after the game is seated.
class Cue:
	## The file's name in [constant DevSounds.FOLDER], without its extension.
	var name := ""
	var delay_s := 0.0
	## Where in the file to start, to skip what comes before the sound.
	var from_s := 0.0
	var volume_db := 0.0
