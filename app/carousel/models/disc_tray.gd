# SPDX-License-Identifier: GPL-3.0-or-later
class_name DiscTray
extends RefCounted
## A disc drive's tray and the opening it slides out of, as pure functions over a [MeshBuilder],
## for the consoles whose disc lies on a tray. The tray is laid out in plan (X right, Y towards the
## back, Z up, see [constant ShapeGeometry.PLAN]) from its plate's outline, its foot and top, and
## the centre of the disc lying on it: the rails along its sides at its foot, the recess the disc
## lies in with a finger notch on either side, the deeper step a small disc lies in, and the window
## through to the drive's turntable, whose hub and clamp ring stand in it. Each level of the plate
## is a solid of its own, overlapping the next, cut in quarters so that each piece is one outline.

## How far the rails stand out of the tray's sides, and how high they are.
const RAIL := Vector2(1.0, 1.0)
## The recess: its room round the disc, how deep its floor lies under the tray's top; the small
## disc's step, its radius a share of the disc's (80 mm to 120 mm), how deep under the recess's floor.
const RECESS_ROOM := 1.0
const RECESS_DEPTH := 1.2
const STEP_SHARE := 0.675
const STEP_DEPTH := 0.8
## The finger notches, each centred on the recess's edge this far behind its side, and the plastic
## kept round the recess and the notches inside the tray's sides.
const NOTCH_RADIUS := 7.0
const NOTCH_ANGLE := PI / 6.0
const WALL := 0.6
## The window: round the turntable, and the laser's slot behind it, its width and how far back it
## reaches, a share of the disc's radius.
const WINDOW_RADIUS := 16.0
const LASER := Vector2(30.0, 0.55)
## The turntable's radius; the clamp ring's radii and thickness, the disc lying on it; the centring
## cone's radius at its foot and at its top, and how far it rises through the disc's hole above the
## recess's floor.
const TURNTABLE := 13.5
const CLAMP := Vector3(9.0, 12.5, 0.35)
const CONE := Vector3(7.2, 5.6, 1.8)
## The opening's lip: how deep it is, the room it leaves round the tray going through it, and above
## the tray's top for the hub and the disc.
const LIP := 1.5
const LIP_GAP := 1.0
const LIP_ROOM := 3.0
## What lies on a face is drawn this far above it, which it would fight.
const RAISE := 0.05


## The height a disc lying on a tray whose top is at [param top] rests at: its recess's floor.
static func floor_level(top: float) -> float:
	return top - RECESS_DEPTH


## Whether a disc of [param radius] about [param centre] fits the tray [param area], from its foot
## to its top ([param levels]): the levels deep enough, the recess and its notches inside the walls,
## the window inside the step, the hub inside the window.
static func fits(area: Rect2, levels: Vector2, centre: Vector2, radius: float) -> bool:
	var inside := _body(area).grow(-WALL)
	var reach := radius + RECESS_ROOM
	var step := STEP_SHARE * radius - 1.0
	return levels.y - levels.x > RAIL.y + RECESS_DEPTH + STEP_DEPTH + 0.5 \
		and ShapeGeometry.within(ShapeGeometry.square_around(centre, reach), inside) \
		and [-1.0, 1.0].all(func(side: float) -> bool:
			return ShapeGeometry.within(ShapeGeometry.square_around(_notch(centre, reach, side), NOTCH_RADIUS), inside)) \
		and WINDOW_RADIUS < step and Vector2(LASER.x / 2.0, LASER.y * radius).length() < step \
		and TURNTABLE < WINDOW_RADIUS - 1.0 and CLAMP.y < TURNTABLE and CONE.x < CLAMP.x


## Adds the tray's plate [param area] from its foot to its top ([param levels]), a disc of
## [param radius] lying on it about [param centre]: its rails under it all, then each level round
## what is sunk in it, the window, the step and the notches, the recess.
static func plate(mesh: MeshBuilder, area: Rect2, levels: Vector2, centre: Vector2, radius: float,
		steps: int) -> void:
	var count := 16 * steps
	var reach := radius + RECESS_ROOM
	var ledge := floor_level(levels.y)
	var recess := ShapeGeometry.circle(centre, reach, count)
	var deep: Array[PackedVector2Array] = [ShapeGeometry.circle(centre, STEP_SHARE * radius, count)]
	for side: float in [-1.0, 1.0]:
		var notch := ShapeGeometry.circle(_notch(centre, reach, side), NOTCH_RADIUS, 8 * steps)
		recess = Geometry2D.merge_polygons(recess, notch)[0]
		deep.append(notch)
	# Across the disc's centre and the notches': every hole meets the lines its quarters are cut along.
	var cut := Vector2(centre.x, _notch(centre, reach, 1.0).y)
	var body := _body(area)
	ShapeGeometry.prism(mesh, ShapeGeometry.square(area), levels.x, levels.x + RAIL.y)
	_around(mesh, body, [window(centre, radius, steps)], cut, levels.x, ledge - STEP_DEPTH)
	_around(mesh, body, deep, cut, levels.x, ledge)
	_around(mesh, body, [recess], cut, levels.x, levels.y)


## The window through the tray about [param centre], a disc of [param radius] on it: round the
## turntable, the laser's slot going back from it.
static func window(centre: Vector2, radius: float, steps: int) -> PackedVector2Array:
	var laser := Rect2(centre.x - LASER.x / 2.0, centre.y, LASER.x, LASER.y * radius)
	return _ccw(Geometry2D.merge_polygons(ShapeGeometry.circle(centre, WINDOW_RADIUS, 8 * steps),
		ShapeGeometry.square(laser))[0])


## Adds the drive's dark inside seen through the window of the tray whose foot is at [param foot].
static func window_floor(mesh: MeshBuilder, centre: Vector2, radius: float, foot: float, steps: int) -> void:
	var loop := window(centre, radius, steps)
	ShapeGeometry.flat(mesh, loop, foot + RAIL.y + RAISE, Vector3.BACK, ShapeGeometry.bounds(loop))


## Adds the turntable standing in the window about [param centre], the tray's foot and top
## [param levels], and its centring cone rising through the disc's hole.
static func hub(mesh: MeshBuilder, centre: Vector2, levels: Vector2, steps: int) -> void:
	var count := 8 * steps
	var seat := floor_level(levels.y) - CLAMP.z
	ShapeGeometry.prism(mesh, ShapeGeometry.circle(centre, TURNTABLE, count), levels.x + RAIL.y, seat)
	var rings: Array[PackedVector3Array] = []
	for level: Vector2 in [Vector2(CONE.x, seat), Vector2(CONE.y, seat + CLAMP.z + CONE.z)]:
		var ring := PackedVector3Array()
		for point in ShapeGeometry.circle(centre, level.x, count):
			ring.append(Vector3(point.x, point.y, level.y))
		rings.append(ring)
	ShapeGeometry.swept(mesh, rings, ShapeGeometry.square_around(centre, CONE.x))


## Adds the clamp ring on the turntable about [param centre], the disc lying on it at the recess's
## floor under the tray's top [param top].
static func clamp_ring(mesh: MeshBuilder, centre: Vector2, top: float, steps: int) -> void:
	var count := 8 * steps
	var ledge := floor_level(top)
	var rings: Array[PackedVector3Array] = []
	for level: float in [ledge - CLAMP.z, ledge]:
		var ring := PackedVector3Array()
		for point in ShapeGeometry.circle(centre, CLAMP.y, count):
			ring.append(Vector3(point.x, point.y, level))
		rings.append(ring)
	ShapeGeometry.swept(mesh, rings, ShapeGeometry.square_around(centre, CLAMP.y),
		ShapeGeometry.circle(centre, CLAMP.x, count))


## Adds the drive's opening behind a tray's slot, in a model's space (X right, Y up, Z towards the
## front): its walls along [param mouth] (counter-clockwise, seen from the front) from
## [param front] back to its floor at [param back], and its lip at its front, round [param tray]
## (the tray seen from the front, from its foot to its top) going through it, room left above it.
static func opening(mesh: MeshBuilder, mouth: PackedVector2Array, tray: Rect2, front: float, back: float) -> void:
	var uv := ShapeGeometry.bounds(mouth)
	ShapeGeometry.sunk(mesh, mouth, back, front, uv)
	# Open down to under the mouth: the lip is one outline, round the top and the ends.
	var clear := Rect2(tray.position.x - LIP_GAP, uv.position.y - 1.0, tray.size.x + 2.0 * LIP_GAP,
		tray.end.y + LIP_ROOM - uv.position.y + 1.0)
	for lip in Geometry2D.clip_polygons(mouth, ShapeGeometry.square(clear)):
		ShapeGeometry.prism(mesh, _ccw(lip), front - LIP, front, uv)


## The tray's middle, above its rails: as long as its plate, narrower by its rails.
static func _body(area: Rect2) -> Rect2:
	return area.grow_individual(-RAIL.x, 0.0, -RAIL.x, 0.0)


## The centre of the finger notch on [param side] (-1 left, 1 right) of the recess of [param reach]
## about [param centre].
static func _notch(centre: Vector2, reach: float, side: float) -> Vector2:
	return centre + Vector2(side * cos(NOTCH_ANGLE), sin(NOTCH_ANGLE)) * reach


## Adds the solid of [param area] from [param low] to [param high] round [param holes], cut in the
## quarters the lines through [param cut] make, each piece one outline: every hole meets one of them.
static func _around(mesh: MeshBuilder, area: Rect2, holes: Array[PackedVector2Array], cut: Vector2, low: float,
		high: float) -> void:
	var xs: Array[float] = [area.position.x, cut.x, area.end.x]
	var ys: Array[float] = [area.position.y, cut.y, area.end.y]
	for i in 2:
		for j in 2:
			var pieces: Array[PackedVector2Array] = [ShapeGeometry.square(Rect2(xs[i], ys[j], xs[i + 1] - xs[i],
				ys[j + 1] - ys[j]))]
			for hole in holes:
				var left: Array[PackedVector2Array] = []
				for piece in pieces:
					left.append_array(Geometry2D.clip_polygons(piece, hole))
				pieces = left
			for piece in pieces:
				ShapeGeometry.prism(mesh, _ccw(piece), low, high, area)


## [param loop] counter-clockwise, its points closer than a hundredth of a millimetre made one.
static func _ccw(loop: PackedVector2Array) -> PackedVector2Array:
	var found := PackedVector2Array()
	for point in loop:
		if found.is_empty() or point.distance_to(found[-1]) > 0.01:
			found.append(point)
	if found[0].distance_to(found[-1]) <= 0.01:
		found.remove_at(found.size() - 1)
	if Geometry2D.is_polygon_clockwise(found):
		found.reverse()
	return found
