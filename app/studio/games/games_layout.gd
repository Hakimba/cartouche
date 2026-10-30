# SPDX-License-Identifier: GPL-3.0-or-later
class_name GamesLayout
extends RefCounted
## The games row's poses in the fitted frame. MediaView owns the arc and pose interpolation.

const FILE := "res://data/media_poses.json"

static var _poses: Dictionary = {}

var chosen: Transform3D
var side: Vector2
var side_size: float


## A bounded set of candidates, so a large library never adds per-frame work. MediaView orders them.
static func offsets(count: int, scroll: float) -> Dictionary[int, float]:
	var start := floori(scroll) - 3 if count > 7 else 0
	var local := MediaView.drawing_order(mini(count, 7), scroll - start)
	var shown: Dictionary[int, float] = {}
	for index in local:
		var game := posmod(start + index, count)
		shown[game] = MediaView.offset(game, scroll, count)
	return shown


## Drops the file read, so that the next layout follows a file the debug bridge reloaded.
static func forget() -> void:
	_poses.clear()


func _init(medium: String) -> void:
	if _poses.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		_poses = data["media"]
	var cart := medium.ends_with("_cart")
	var pose: Dictionary = _poses.get(medium, _poses["ps2_dvd"])
	var size: float = pose["scale"]
	var angles: Array = pose["rotation"]
	var position: Array = pose["position"]
	chosen = Transform3D(Basis.from_euler(_vector(angles) * PI / 180.0).scaled(Vector3.ONE * size), _vector(position))
	side = Vector2(1.25, 0.02) if cart else Vector2(0.96, -0.25)
	side_size = 0.66 if cart else 0.56


static func _vector(xyz: Array) -> Vector3:
	var x: float = xyz[0]
	var y: float = xyz[1]
	var z: float = xyz[2]
	return Vector3(x, y, z)


func standing(offset: float, pose_amount := 1.0, seconds := 0.0, floating := false) -> Transform3D:
	var start := chosen
	start.basis = Basis(Quaternion.IDENTITY.slerp(chosen.basis.get_rotation_quaternion(), pose_amount)) \
		.scaled(chosen.basis.get_scale())
	var at := MediaView.standing(offset, start, side, side_size)
	if floating:
		var share := (1.0 - MediaView.softness(offset)) * pose_amount
		var t := 1.6 * seconds
		at.origin.y += 0.05 * (1.0 - cos(t)) / 2.0 * share
		at.basis = Basis(Vector3.UP, deg_to_rad(sin(t / 2.0) * 7.0 * share)) * at.basis
	return at
