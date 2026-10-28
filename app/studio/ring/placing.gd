# SPDX-License-Identifier: GPL-3.0-or-later
class_name Placing
extends RefCounted
## Placing a console just added on the ring of the others. The state machine of the flow (which press each state takes
## and which it ignores, what each timed state moves on to) and the ring's geometry while a gap is chosen. The ring
## holds the [member others] already there ("m" below); the gap [member gap] is the one after console g of them, between
## g and (g + 1) mod m. Pure: [ConsoleOrder] plays it.

## Where the flow stands. A press only counts in the states that name it below.
enum State {
	## Nothing yet: the form.
	FORM,
	## The console springs from the plinth to the middle of the ring: ← → move the gap, A flies the console from where it is,
	## B goes back to the form.
	ARRIVING,
	## The same, the console in the middle.
	CHOOSING,
	## The console flies into its gap, then bounces, then a pause, then the morph: every press is ignored.
	FLYING,
	LANDING,
	MORPHING,
	## The consoles screen shows, on the new console.
	DONE,
	## The console flies back to the form: every press is ignored.
	BACK,
}
enum Press { LEFT, RIGHT, A, B }
## What a press asks the screen to do.
enum Action { IGNORED, MOVE, FLY, LEAVE }

## How long the flight back plays (seconds); the other timed states (the console's arrival, its flight, its bounce, the
## pause after it, the morph) are the design's, in [StudioTokens].
static var BACK_S: float:
	get: return StudioTokens.TR_PLACE_BACK_S
## The gap the ring opens (radians), how much bigger the new console stands in the middle and where its silhouette's
## centre stands there, in px of the 1280 × 960 frame (4 cqw above the ring's centre).
const OPENING := 0.34
const MIDDLE_GROWTH := 1.5
const MIDDLE := Vector2(640.0, 419.84)
## The plinth the console comes from (and goes back to): its silhouette's centre in px and its picture's width in cqw.
const PLINTH := Vector2(263.68, 588.8)
const PLINTH_WIDTH := 40.0
## How high (px) the console is lifted along its arrival, its flight and its flight back, at the most.
static var ARRIVE_LIFT: float:
	get: return StudioTokens.TR_PLACE_ARC_PX
const FLY_LIFT := 64.0
const BOUNCE := 0.12
## The room the middle's text keeps under the console (px).
const TEXT_GAP := 20.48

## The consoles on the ring, by platform id, in the order shown.
var others: Array[String]
## The gap g chosen, 0 to m - 1.
var gap: int
var state := State.FORM


## A flow placing a console among [param ring_ids], the platform ids of the others shown on the ring, in their order.
## The gap first opens at the end of the order: after the last of them.
func _init(ring_ids: Array[String]) -> void:
	others = ring_ids.duplicate()
	gap = maxi(others.size() - 1, 0)


func m() -> int:
	return others.size()


## Ajouter: the console comes to the middle of the ring.
func start() -> void:
	if state == State.FORM:
		state = State.ARRIVING


## What [param press] does in the state the flow is in.
func press(pressed: Press) -> Action:
	if state != State.ARRIVING and state != State.CHOOSING:
		return Action.IGNORED
	if pressed == Press.A:
		state = State.FLYING
		return Action.FLY
	if pressed == Press.B:
		state = State.BACK
		return Action.LEAVE
	# A ring of one has one order: nothing to move.
	if m() < 2:
		return Action.IGNORED
	gap = posmod(gap + (1 if pressed == Press.RIGHT else -1), m())
	return Action.MOVE


## The plugin refused the placing as the console landed: it flies back to the form, as on B.
func refuse() -> void:
	if state == State.LANDING:
		state = State.BACK


## The state that is playing ends: the next one begins. A state that waits for a press, or has nothing after it, stays.
func done() -> void:
	match state:
		State.ARRIVING:
			state = State.CHOOSING
		State.FLYING:
			state = State.LANDING
		State.LANDING:
			state = State.MORPHING
		State.MORPHING:
			state = State.DONE
		State.BACK:
			state = State.FORM


## The gap as [method Library.withConsoleAt] counts it among all [param others_shown], the platform ids of every
## console but the new one in the order shown, those without a model included: the console goes after the console of
## the ring the gap follows.
func shown_gap(others_shown: Array[String]) -> int:
	return others_shown.find(others[gap]) + 1 if not others.is_empty() else others_shown.size()


## The angles the [param count] consoles of the ring stand at (radians, in their order) with the gap after console
## [param after] open. 0 is the bottom of the ring and angles grow counter-clockwise on the screen: the first gap faces the
## user. One console alone stands at the top and leaves the whole bottom to the gap.
static func angles(count: int, after: int) -> PackedFloat64Array:
	if count == 1:
		return PackedFloat64Array([PI])
	var shown := opened(count, after)
	var turn := -gap_mid(opened(count, count - 1), count - 1)
	for k in count:
		shown[k] += turn
	return shown


## The ring of [param count] consoles with the gap after console [param after] opened, balanced on the even places so that
## they part both ways as the gap moves.
static func opened(count: int, after: int) -> PackedFloat64Array:
	var step := (TAU - OPENING) / count
	var raw := PackedFloat64Array()
	var at := 0.0
	var shift := 0.0
	for k in count:
		raw.append(at)
		shift += at - k * TAU / count
		at += step + (OPENING if k == after else 0.0)
	shift /= count
	for k in count:
		raw[k] -= shift
	return raw


## The angle of the middle of the gap after console [param after] of [param ring]: halfway round from it to the next.
static func gap_mid(ring: PackedFloat64Array, after: int) -> float:
	return ring[after] + fposmod(ring[(after + 1) % ring.size()] - ring[after], TAU) / 2.0


## Where the arrow stands (radians) with the gap after console [param after] open among [param count] consoles: the
## middle of the gap, never on a console. One console alone: the bottom.
static func arrow_angle(count: int, after: int) -> float:
	return 0.0 if count == 1 else gap_mid(angles(count, after), after)


## The ring once the new console is in the gap after console [param after] of [param count]: the [param count] + 1
## consoles on even angles, turned so that the new console stands where the arrow was. Console k of the ring is at
## index k, the new one at index [param after] + 1.
static func landed(count: int, after: int) -> PackedFloat64Array:
	var total := count + 1
	var turn := arrow_angle(count, after) - (after + 1) * TAU / total
	var even := PackedFloat64Array()
	for k in total:
		even.append(turn + k * TAU / total)
	return even


## Where the new console flies from, to, and by which arc, as it comes: [param progress] from 0 to 1, its place on
## the straight way eased in and out, lifted by sin(pi e) of [param lift] on the linear progress e.
static func flight(from: Vector2, to: Vector2, progress: float, lift: float) -> Vector2:
	var at := from.lerp(to, Motion.eased(Motion.Easing.IN_OUT, progress))
	at.y -= sin(PI * progress) * lift
	return at


## How much larger the console stands [param progress] (0 to 1) through its bounce: 1 + .12 sin(pi b).
static func bounce(progress: float) -> float:
	return 1.0 + BOUNCE * sin(PI * progress)
