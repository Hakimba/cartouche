# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## The launch animation of the selected console, edited live: [method tune] plays steps that are not
## in any file at a time, with the black over the screen, and [method handles] says where the console,
## the disc and the console's moving parts stand in the picture and how far a point of the picture
## moves for one unit of each value, so that a part dragged in the picture gives the value to set.

const Views := preload("res://dev/bridge/views.gd")
## A centimetre in the animation's world units.
const _CM := 0.1
## The smallest travel of a part, in world units, that a hand can grab.
const _GRABBABLE := 0.002


## Puts the carousel in a launch of [param values] (`steps`, `choice`) on its selected console, held at
## `t` seconds, the black as [GameLaunch] draws it; resuming the engine plays it on from there. Answers
## the animation's length and moments.
static func tune(carousel: Carousel, values: Dictionary) -> Dictionary:
	if carousel != null and values.has("console"):
		var folder := str(values["console"])
		var index := -1
		for i in carousel._consoles._items.size():
			if carousel._consoles.console_at(i).folder == folder:
				index = i
		if index < 0:
			return _error("this console is not in the library")
		carousel._consoles.select(index)
	var model := _console(carousel)
	var steps: Variant = values.get("steps")
	if model == null or steps is not Array or not _number(values.get("t")) or not _number(values.get("choice", 1)):
		return _error("no console or invalid launch")
	var data := {"steps": steps, "choice": values.get("choice", 1)}
	if not LaunchAnimation.problems(data, model).is_empty():
		return _error("the console has no such part")
	var animation := LaunchAnimation.build(data, model)
	var sequence := carousel._sequence
	var launch := carousel._game_launch
	if launch.is_busy() and not (launch.is_previewing() and launch.is_inserting()):
		return _error("a launch is running")
	if animation.get_track_count() == 0 or sequence.is_processing():
		return _error("no launch animation to play")
	sequence.use(animation)
	var moments := {}
	for named: StringName in [&"consoles", &"games", &"launch", &"seated", &"black"]:
		moments[named] = LaunchAnimation.moment(animation, named, -1.0)
	var at := clampf(_float(values["t"]), 0.0, animation.length)
	# The carousel is in a launch, as the engine's time resumes it: the launch then plays on its own.
	if not launch.is_inserting():
		carousel._row.freeze()
		sequence.behind_amount = 1.0
	launch.preview(at - _float(moments[&"launch"]))
	carousel._row._arrange()
	RenderingServer.force_draw()
	var parts: Array[Dictionary] = []
	for part in model.moving_parts():
		parts.append({"property": str(part.property), "role": str(part.role), "rest": part.rest, "open": part.open})
	return {"t": at, "length": animation.length, "moments": moments, "model_hash": model.fingerprint(), "parts": parts}


## Where each grabbable thing stands in the picture, in pixels, and its screen movement, in pixels, for
## one centimetre of each value it takes (`px`, `py` for the console, `dx`, `dy`, `lift` for the disc),
## or for one unit of a part's own property.
static func handles(carousel: Carousel) -> Dictionary:
	var model := _console(carousel)
	if model == null:
		return {}
	var camera := carousel.get_viewport().get_camera_3d()
	var found := {}
	var consoles := carousel._consoles
	var at := consoles.console_position
	var console_at := func() -> Vector2: return camera.unproject_position(model.global_position)
	found["console"] = _grab(console_at, [
		func(by: float) -> void: consoles.console_position = at + Vector3(by * _CM, 0.0, 0.0),
		func(by: float) -> void: consoles.console_position = at + Vector3(0.0, by * _CM, 0.0)], consoles.arrange)
	var view := {"model": model, "camera": camera}
	var pose := Views._pose_answer(view)
	found["console"]["space"] = pose["space"]
	var sequence := carousel._sequence
	var row := carousel._row
	if sequence.disc_away > 0.0:
		var offset := sequence.disc_offset
		var lift := sequence.disc_lift
		var disc_at := func() -> Vector2: return camera.unproject_position(row.to_global(row._launch_stand.origin))
		found["disc"] = _grab(disc_at, [
			func(by: float) -> void: sequence.disc_offset = offset + Vector2(by * _CM, 0.0),
			func(by: float) -> void: sequence.disc_offset = offset + Vector2(0.0, by * _CM),
			func(by: float) -> void: sequence.disc_lift = lift + by * _CM], sequence._place_disc)
		var seat := model.global_transform * model.seat()
		var across := Basis(Quaternion(Vector3.BACK, model.approach()))
		var tilt := Basis(Vector3.RIGHT, sequence.disc_tilt.x) * Basis(Vector3.UP, sequence.disc_tilt.y)
		var above := Transform3D(tilt, across * Vector3(offset.x, offset.y, 0.0) + model.approach() * lift)
		var original_space: Dictionary = pose["space"]
		var space := original_space.duplicate(true)
		space["parent"] = Views._transform(seat)
		space["model"] = Views._transform(seat * above)
		space["centre"] = [0.0, 0.0, 0.0]
		space["across"] = Views._transform(Transform3D(across, Vector3.ZERO))
		found["disc"]["space"] = space
	var parts := {}
	for part in model.moving_parts():
		var grab := _grab_part(camera, model, part)
		if not grab.is_empty():
			parts[str(part.property)] = grab
	found["parts"] = parts
	return found


## The point [param where] gives, in pixels, and what it moves by for one centimetre of each of the
## values [param nudges] set (a nudge by 0 puts its value back); [param apply] draws a change.
static func _grab(where: Callable, nudges: Array[Callable], apply: Callable) -> Dictionary:
	var here: Vector2 = where.call()
	var moves := []
	for nudge in nudges:
		nudge.call(1.0)
		apply.call()
		var moved: Vector2 = where.call()
		moves.append([moved.x - here.x, moved.y - here.y])
		nudge.call(0.0)
	apply.call()
	return {"x": here.x, "y": here.y, "moves": moves}


## The mesh of [param model] that [param part] moves the furthest, from rest to fully moved: where it
## stands now, how far it goes on the picture for one unit of the property and the values it goes
## between; empty when nothing visible moves (a light, a hidden spring).
static func _grab_part(camera: Camera3D, model: ConsoleModel, part: MovingPart) -> Dictionary:
	var now: Variant = model.get(part.property)
	var at := _centres(model)
	model.set(part.property, part.rest)
	var rest := _centres(model)
	model.set(part.property, part.open)
	var open := _centres(model)
	model.set(part.property, now)
	var best := -1
	var far := _GRABBABLE
	for i in at.size():
		var travelled := rest[i].distance_to(open[i])
		if travelled > far:
			far = travelled
			best = i
	if best < 0 or is_equal_approx(part.rest, part.open):
		return {}
	var here := camera.unproject_position(at[best])
	var per_unit := (camera.unproject_position(open[best]) - camera.unproject_position(rest[best])) / (part.open - part.rest)
	return {"x": here.x, "y": here.y, "moves": [[per_unit.x, per_unit.y]], "limits": [minf(part.rest, part.open), maxf(part.rest, part.open)]}


static func _centres(model: Node3D) -> PackedVector3Array:
	var centres := PackedVector3Array()
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		centres.append(mesh.global_transform * mesh.get_aabb().get_center())
	return centres


static func _console(carousel: Carousel) -> ConsoleModel:
	if carousel == null or not carousel._shown or carousel._shelves.is_empty():
		return null
	return carousel._consoles.selected().model as ConsoleModel


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(_float(value))


static func _float(value: Variant) -> float:
	return value


static func _error(reason: String) -> Dictionary:
	return {"ok": false, "error": reason}


## Ends only a bridge preview; an actual launch cannot be cancelled by this command.
static func stop(carousel: Carousel) -> Dictionary:
	if carousel == null:
		return _error("no carousel")
	var launch := carousel._game_launch
	if launch.is_previewing():
		launch.end_preview()
		# A launch ends on the games screen; a preview started from another screen goes back to it.
		if carousel.screen() != Carousel.Screen.GAMES:
			carousel._sequence.use(carousel._sequence._animation)
	return {"ok": true}
