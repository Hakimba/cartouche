# SPDX-License-Identifier: GPL-3.0-or-later
class_name GamesLayout
extends RefCounted
## The games row's poses in the fitted design frame. MediaView owns the arc and pose interpolation.

const _DISC := [Vector3(0.0, 0.15, 0.0), Vector3(-13.4, 21.0, 0.2)]
const _HANDHELD := [Vector3(0.028, 0.243, -0.015), Vector3(-12.1, 18.5, 0.0)]
const _HOME := [Vector3(0.028, 0.319, -0.042), Vector3(-16.0, 22.3, 0.0)]
const _NES := [Vector3(0.046, 0.257, -0.03), Vector3(-17.3, 20.4, 0.0)]
const _CARTS := {
	"nes_cart": _NES, "famicom_cart": _NES,
	"snes_pal_cart": _HOME, "snes_us_cart": _HOME, "sfc_cart": _HOME, "n64_cart": _HOME,
	"gb_cart": _HANDHELD, "gbc_cart": _HANDHELD, "gba_cart": _HANDHELD,
}

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


func _init(medium: String) -> void:
	var cart := medium in _CARTS
	var pose: Array = _CARTS.get(medium, _DISC)
	var angles: Vector3 = pose[1]
	var position: Vector3 = pose[0]
	chosen = Transform3D(Basis.from_euler(angles * PI / 180.0).scaled(Vector3.ONE * (0.85 if cart else 0.78)), position)
	side = Vector2(1.25, 0.02) if cart else Vector2(0.96, -0.25)
	side_size = 0.66 if cart else 0.56


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
