# SPDX-License-Identifier: GPL-3.0-or-later
class_name ConsoleArrival
extends Node
## A console flies from the form's plinth to its hero position without an ordering choice.

signal _over

const DURATION_S := 0.42

var _playing := false
var _motion: Tween


## True once landed; false when the row leaves before the flight ends.
func play(row: ConsoleRow) -> bool:
	var target := row.silhouette(row.selected_index()).get_center() * CarouselLayout.FRAME - Vector2(0.0, ConsoleRow.RAISE_PX)
	var stand := row.begin_arrival(Placing.PLINTH, Placing.PLINTH_WIDTH / 100.0)
	_playing = true
	row.tree_exiting.connect(_stop, CONNECT_ONE_SHOT)
	_motion = create_tween().bind_node(row)
	_motion.tween_method(func(progress: float) -> void:
		stand.centre = Placing.flight(Placing.PLINTH, target, progress, Placing.ARRIVE_LIFT)
		stand.size = lerpf(Placing.PLINTH_WIDTH / 100.0, 1.0, Motion.eased(Motion.Easing.GLIDE, progress))
		row.arrange(), 0.0, 1.0, DURATION_S)
	_motion.finished.connect(_over.emit, CONNECT_ONE_SHOT)
	await _over
	var completed := _playing
	if completed:
		row.tree_exiting.disconnect(_stop)
		row.end_arrival()
	_playing = false
	_motion = null
	return completed


func is_playing() -> bool:
	return _playing


func _exit_tree() -> void:
	_stop()


func _stop() -> void:
	if _motion:
		_motion.kill()
	if _playing:
		_playing = false
		_over.emit()
