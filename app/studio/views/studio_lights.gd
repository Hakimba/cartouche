# SPDX-License-Identifier: GPL-3.0-or-later
class_name StudioLights
extends RefCounted
## The lights designed for each model and screen (`data/studio_lights.json`, [method rig_of]), built
## under a view's world about the model's box centre. A (model, screen) the file does not list keeps the default light:
## the Sun and the room of the carousel.

const FILE := "res://data/studio_lights.json"
## Where a source of the games screen shines: on the chosen medium or on its neighbours (a source of
## another screen names neither).
const CHOSEN := &"chosen"
const SIDES := &"sides"

## The room's colour of the carousel's environment, for a view with none to copy.
const _ROOM_COLOUR := Color(0.85, 0.86, 0.9)

static var _data: Dictionary = {}

## The model's lights, built by [method _init]; their energy follows [method tune].
var _lights: Array[Light3D] = []
var _rig: Rig
var _environment: Environment
## Where the lights were last placed: placed again unchanged, every light would be sent to the renderer.
var _centre := Vector3(NAN, NAN, NAN)


## One light of a rig: a sun (its rays go along [member target]), a lamp at [member position], or a
## spot at [member position] aimed at [member target]; positions from the model's box centre.
class Source:
	extends RefCounted

	var kind: StringName
	var position: Vector3
	var target: Vector3
	var energy: float
	var colour: Color
	var reach: float
	var angle: float
	var softness: float
	var shadow: bool
	var on: StringName

	static func read(data: Dictionary) -> Source:
		var source := Source.new()
		var kind_named: String = data["kind"]
		var at: PackedFloat32Array = data["position"]
		var aim: PackedFloat32Array = data["target"]
		var rgb: PackedFloat32Array = data["colour"]
		var on_named: String = data.get("on", "")
		source.kind = StringName(kind_named)
		source.position = StudioLights._vector(at)
		source.target = StudioLights._vector(aim)
		source.energy = data["energy"]
		source.colour = Color(rgb[0], rgb[1], rgb[2])
		source.reach = data["range"]
		source.angle = data["angle"]
		source.softness = data["softness"]
		source.shadow = data["shadow"]
		source.on = StringName(on_named)
		return source

	## This source with its energy scaled by [param by].
	func scaled(by: float) -> Source:
		var copy := Source.new()
		copy.kind = kind
		copy.position = position
		copy.target = target
		copy.energy = energy * by
		copy.colour = colour
		copy.reach = reach
		copy.angle = angle
		copy.softness = softness
		copy.shadow = shadow
		copy.on = on
		return copy


## A model's light in a screen: its sources and the room's light (the environment's ambient energy).
class Rig:
	extends RefCounted

	var room: float
	var sources: Array[Source] = []

	static func read(data: Dictionary) -> Rig:
		var rig := Rig.new()
		rig.room = data["room"]
		for source: Dictionary in data["sources"]:
			rig.sources.append(Source.read(source))
		return rig


## The light of [param model] (a console's folder or a medium) in [param screen] (`consoles`,
## `plinth`, `games`, `properties`), its one for a game without a picture when [param blank]: the one designed for
## it, else the default one.
static func rig_of(model: String, screen: StringName, blank := false) -> Rig:
	var models: Dictionary = _file()["blank" if blank else "lights"]
	var screens: Dictionary = models.get(model, {})
	var rig: Dictionary = screens.get(screen, _file()["today"])
	return Rig.read(rig)


## The app's environment for a view of its own world: a copy of the one [param node]'s world has (its
## sky shared), whose room light the view's lights set; a plain room of the default colour where there is
## none.
static func environment_of(node: Node) -> Environment:
	var shown := node.get_viewport().find_world_3d().environment
	if shown:
		return shown.duplicate()
	var room := Environment.new()
	room.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	room.ambient_light_color = _ROOM_COLOUR
	return room


## [param rig] as it lights a medium [param s] places from the games row's centre (0 at the centre,
## 1 from the next place on): the chosen medium's sources scaled by 1 - s, its neighbours' by s, the
## others whole, so that a medium moving between places is lit by both by its share of each.
static func shared(rig: Rig, s: float) -> Rig:
	var out := Rig.new()
	out.room = rig.room
	for source in rig.sources:
		var share: float = {CHOSEN: 1.0 - s, SIDES: s}.get(source.on, 1.0)
		out.sources.append(source.scaled(share))
	return out


## [param from] crossfaded to [param to] by [param weight]: every source of both, scaled by its
## light's share, and the room between, so that the views keep the same lights through the fade.
static func mixed(from: Rig, to: Rig, weight: float) -> Rig:
	var out := Rig.new()
	out.room = lerpf(from.room, to.room, weight)
	for source in from.sources:
		out.sources.append(source.scaled(1.0 - weight))
	for source in to.sources:
		out.sources.append(source.scaled(weight))
	return out


## The lights of [param rig] built under [param parent], about [param centre] (the model's box
## centre in the world), and the room's light given to [param environment].
func _init(parent: Node, rig: Rig, centre: Vector3, environment: Environment) -> void:
	_environment = environment
	for source in rig.sources:
		var light: Light3D = OmniLight3D.new() if source.kind == &"lamp" \
			else SpotLight3D.new() if source.kind == &"spot" else DirectionalLight3D.new()
		light.light_color = source.colour
		# The app's choice: no light draws a highlight.
		light.light_specular = 0.0
		light.shadow_enabled = source.shadow
		if light is OmniLight3D:
			(light as OmniLight3D).omni_range = source.reach
		elif light is SpotLight3D:
			var spot := light as SpotLight3D
			spot.spot_range = source.reach
			spot.spot_angle = source.angle
			spot.spot_angle_attenuation = source.softness
		parent.add_child(light)
		_lights.append(light)
	_rig = rig
	place(centre)
	tune(rig)


## The lights moved with their model's box centre, [param centre].
func place(centre: Vector3) -> void:
	if centre == _centre:
		return
	_centre = centre
	for i in _lights.size():
		var source := _rig.sources[i]
		var light := _lights[i]
		if light is DirectionalLight3D:
			light.basis = StudioLights._aimed(source.target)
		else:
			light.position = centre + source.position
			if light is SpotLight3D:
				light.basis = StudioLights._aimed(source.target - source.position)


## The energies and the room of [param rig], a scaled copy of the built one ([method shared] of it):
## the same sources in the same order.
func tune(rig: Rig) -> void:
	assert(rig.sources.size() == _lights.size(), "a light tuned by another rig than the one it was built from")
	for i in _lights.size():
		_lights[i].light_energy = rig.sources[i].energy
		_lights[i].visible = rig.sources[i].energy > 0.0
	_environment.ambient_light_energy = rig.room


## Takes the lights away, for a rig built again in their place.
func dispose() -> void:
	for light in _lights:
		light.queue_free()
	_lights.clear()


## The lights built, in the rig's order.
func lights() -> Array[Light3D]:
	return _lights


## A basis whose -Z, where a light shines, points along [param direction], as `Basis.looking_at`
## aims it; straight up or down it keeps another up.
static func _aimed(direction: Vector3) -> Basis:
	var along := direction.normalized()
	return Basis.looking_at(along, Vector3.UP if absf(along.y) < 0.99 else Vector3.BACK)


static func _vector(xyz: PackedFloat32Array) -> Vector3:
	return Vector3(xyz[0], xyz[1], xyz[2])


## Drops the file read, so that the next rig follows a file the debug bridge reloaded.
static func forget() -> void:
	_data.clear()


static func _file() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	return _data
