# SPDX-License-Identifier: GPL-3.0-or-later
class_name Motion
extends RefCounted
## The one way the Studio screens move: a spring that presses retarget, and the named curves of their
## animations, cubic Béziers solved for y at a given x.

## The named curves: the standard ease curves and the app's own.
enum Easing { LINEAR, EASE, EASE_IN, EASE_OUT, GLIDE, SNAP, ARRIVE, RISE, POP, FOCUS, FLIP, APPEAR, SINK, IN_OUT, OUT_BACK }

## A frame longer than this moves the spring by this much only: a hitch slows it rather than throwing it.
const MAX_STEP_S := 1.0 / 30.0
## Closer than this to its target, and slower than this, the spring is still.
const STILL := 1e-3
## Each cubic Bézier curve's control points, (x1, y1, x2, y2).
const _BEZIERS: Dictionary[Easing, Vector4] = {
	Easing.EASE: Vector4(0.25, 0.1, 0.25, 1.0),
	Easing.EASE_IN: Vector4(0.42, 0.0, 1.0, 1.0),
	Easing.EASE_OUT: Vector4(0.0, 0.0, 0.58, 1.0),
	Easing.GLIDE: Vector4(0.2, 0.8, 0.2, 1.0),
	Easing.SNAP: Vector4(0.3, 1.3, 0.5, 1.0),
	Easing.ARRIVE: Vector4(0.2, 0.9, 0.25, 1.04),
	Easing.RISE: Vector4(0.2, 0.9, 0.25, 1.05),
	Easing.POP: Vector4(0.3, 1.5, 0.5, 1.0),
	Easing.FOCUS: Vector4(0.3, 1.2, 0.5, 1.0),
	Easing.FLIP: Vector4(0.3, 1.4, 0.5, 1.0),
	Easing.APPEAR: Vector4(0.2, 0.9, 0.25, 1.1),
	Easing.SINK: Vector4(0.5, 0.0, 0.7, 0.4),
}
const _NEWTON_STEPS := 8
const _PRECISION := 1e-7


## A unit mass on a spring toward [member target], stepped by semi-implicit Euler: a press moves only the
## target, so fast presses stack and the spring follows.
class Spring:
	extends RefCounted

	var stiffness: float
	var damping: float
	var position: float
	var velocity := 0.0
	var target: float

	func _init(at: float, spring_stiffness := StudioTokens.SPRING_STIFFNESS, spring_damping := StudioTokens.SPRING_DAMPING) -> void:
		position = at
		target = at
		stiffness = spring_stiffness
		damping = spring_damping

	## Moves the spring on by [param delta] seconds; true once it rests on its target.
	func step(delta: float) -> bool:
		var dt := minf(delta, MAX_STEP_S)
		velocity += (stiffness * (target - position) - damping * velocity) * dt
		position += velocity * dt
		if is_still():
			position = target
			velocity = 0.0
		return is_still()

	func is_still() -> bool:
		return absf(target - position) < STILL and absf(velocity) < STILL


## The curve [param shown] at [param t], from 0 to 1.
static func eased(shown: Easing, t: float) -> float:
	match shown:
		Easing.LINEAR:
			return t
		Easing.IN_OUT:
			return 4.0 * t * t * t if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 3.0) / 2.0
		Easing.OUT_BACK:
			return 1.0 + 2.2 * pow(t - 1.0, 3.0) + 1.2 * pow(t - 1.0, 2.0)
		_:
			return _bezier(_BEZIERS[shown], t)


## The curve [param shown] as a tween's interpolator:
## `tweener.set_custom_interpolator(Motion.curve(Motion.Easing.EASE))`.
static func curve(shown: Easing) -> Callable:
	return func(t: float) -> float: return eased(shown, t)


## The y of the cubic Bézier [param points] where its x is [param x]: Newton's method from x, then bisection
## when Newton does not converge.
static func _bezier(points: Vector4, x: float) -> float:
	if x <= 0.0 or x >= 1.0:
		return clampf(x, 0.0, 1.0)
	var u := x
	for i in _NEWTON_STEPS:
		var error := _coordinate(points.x, points.z, u) - x
		if absf(error) < _PRECISION:
			return _coordinate(points.y, points.w, u)
		var slope := _slope(points.x, points.z, u)
		if absf(slope) < 1e-6:
			break
		u -= error / slope
	var low := 0.0
	var high := 1.0
	u = x
	while high - low > _PRECISION:
		if _coordinate(points.x, points.z, u) < x:
			low = u
		else:
			high = u
		u = (low + high) / 2.0
	return _coordinate(points.y, points.w, u)


## One coordinate of the curve from 0 through [param a] and [param b] to 1, at [param u].
static func _coordinate(a: float, b: float, u: float) -> float:
	return ((1.0 - 3.0 * b + 3.0 * a) * u + (3.0 * b - 6.0 * a)) * u * u + 3.0 * a * u


static func _slope(a: float, b: float, u: float) -> float:
	return 3.0 * (1.0 - 3.0 * b + 3.0 * a) * u * u + 2.0 * (3.0 * b - 6.0 * a) * u + 3.0 * a


## A new tween of [param node], [param old] killed first: one motion at a time, the latest wins.
static func restart(node: Node, old: Tween) -> Tween:
	if old:
		old.kill()
	return node.create_tween()


## Plays [param apply] on a new tween of [param node], from 0 to 1 eased by [param easing] in [param seconds]; the
## tween is kept in [param motions] under [param key], the one it replaces killed.
static func animate(node: Node, motions: Dictionary[StringName, Tween], key: StringName, seconds: float, easing: Easing,
		apply: Callable) -> void:
	var old: Tween = motions.get(key)
	var tween := restart(node, old)
	motions[key] = tween
	tween.tween_method(func(t: float) -> void: apply.call(eased(easing, t)), 0.0, 1.0, seconds)


## A timed part of a shared transition clock, at rest before its start and after its end.
static func phase(seconds: float, start: float, duration: float, easing := Easing.LINEAR) -> float:
	return eased(easing, clampf((seconds - start) / maxf(duration, 0.001), 0.0, 1.0))
