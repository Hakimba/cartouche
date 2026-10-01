# SPDX-License-Identifier: GPL-3.0-or-later
class_name Discovery
extends Control
## The console just added, as a small event: its picture on a sticker bursts out of a point and
## grows fast, overshoots and settles, rays and sparks around; its name comes in just after, then
## "Continue". Done once it is pressed (the games' disc images still coming behind); then it goes
## back into a point, where the consoles screen shows its console ([method collapse]).

## "Continue" was pressed.
signal finished

## "Continue" comes in once the sticker has settled, and only then can be pressed.
const _CONTINUE_DELAY_S := 0.9
const _POP_S := 0.48
const _RAYS_DELAY_S := 0.2
const _RAYS_S := 0.7
const _NAME_DELAY_S := 0.48
const _APPEAR_S := 0.32
const _RISE := 14.0
## Each spark: where on the badge (as parts of its size), and when it shows.
const _SPARKS: Array[Vector3] = [Vector3(0.08, 0.18, 0.3), Vector3(0.92, 0.22, 0.34), Vector3(1.0, 0.62, 0.38),
	Vector3(0.04, 0.7, 0.36), Vector3(0.5, -0.06, 0.32), Vector3(0.7, 1.0, 0.4)]
const _SPARK_S := 0.62
## The sticker going back: its name and rays fade, it swells a little, then shrinks to a point.
const _FADE_S := 0.12
const _SWELL := 1.08
const _SWELL_S := 0.1
const _SHRINK_S := 0.28

var _time := 0.0
## Where the sticker stands while shown, for the next discovery.
var _badge_at := Vector2.ZERO
## Where the consoles screen shows the selected console: the sticker goes back into it.
var _console_point := Vector2.ZERO

@onready var _badge: DiscoveryBadge = %Badge
@onready var _picture: TextureRect = %Picture
@onready var _sparks: Control = %Sparks
@onready var _name: Label = %Name
@onready var _continue: Button = %Continue


func _ready() -> void:
	set_process(false)
	_badge_at = _badge.position
	_sparks.draw.connect(_draw_sparks)


func _process(delta: float) -> void:
	_time += delta
	_sparks.queue_redraw()
	if _time >= _CONTINUE_DELAY_S + _APPEAR_S:
		set_process(false)
		_continue.disabled = false
		_continue.grab_focus()


## Draws [param console] for the next discovery, ahead of it: drawing it takes a frame. Once it is
## over, the sticker goes back into [param console_point], where the consoles screen shows it.
func prepare(console: Node3D, console_point: Vector2) -> void:
	_console_point = console_point
	let_go()
	# Twice the size it shows at: drawn larger, it is smooth without multisampling.
	var still := ConsoleStill.new(console, Vector2i(_picture.size * 2.0))
	_picture.add_child(still)
	_picture.texture = still.get_texture()


## Lets the console's picture go, once the discovery is over.
func let_go() -> void:
	for still in _picture.get_children():
		still.queue_free()
	_picture.texture = null


## Plays the discovery of the console [method prepare] drew, named [param console_name].
func play(console_name: String) -> void:
	_name.text = tr("{console} added").format({"console": console_name})
	_time = 0.0
	_badge.scale = Vector2.ONE * 0.02
	_badge.position = _badge_at
	_badge.modulate.a = 0.0
	_badge.rays_shown = 0.0
	var pop := create_tween()
	pop.tween_property(_badge, ^"modulate:a", 1.0, _POP_S * 0.1)
	pop.parallel().tween_property(_badge, ^"scale", Vector2.ONE * 1.16, _POP_S * 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	pop.tween_property(_badge, ^"scale", Vector2.ONE * 0.97, _POP_S * 0.23).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	pop.tween_property(_badge, ^"scale", Vector2.ONE, _POP_S * 0.22).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	create_tween().tween_property(_badge, ^"rays_shown", 1.0, _RAYS_S).set_delay(_RAYS_DELAY_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_appear(_name, _NAME_DELAY_S)
	_continue.disabled = true
	_appear(_continue, _CONTINUE_DELAY_S)
	set_process(true)
	Diagnostics.trace("first launch", "discovery of %s" % console_name)


## The sticker goes back into the point where the console will come out; returns once gone.
func collapse() -> void:
	var tween := create_tween()
	tween.tween_property(_name, ^"modulate:a", 0.0, _FADE_S)
	tween.parallel().tween_property(_continue, ^"modulate:a", 0.0, _FADE_S)
	tween.parallel().tween_property(_badge, ^"rays_shown", 0.0, _FADE_S)
	tween.tween_property(_badge, ^"scale", Vector2.ONE * _SWELL, _SWELL_S).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_badge, ^"scale", Vector2.ONE * 0.01, _SHRINK_S).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	var centred := _console_point - _badge.size / 2.0
	tween.parallel().tween_property(_badge, ^"position", centred, _SHRINK_S).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	_badge.modulate.a = 0.0


## Fades [param control] in from a little lower, after [param delay] seconds.
func _appear(control: Control, delay: float) -> void:
	var resting := control.position.y
	control.modulate.a = 0.0
	control.position.y = resting + _RISE
	var tween := create_tween().set_parallel()
	tween.tween_property(control, ^"modulate:a", 1.0, _APPEAR_S).set_delay(delay)
	tween.tween_property(control, ^"position:y", resting, _APPEAR_S).set_delay(delay).set_ease(Tween.EASE_OUT)


## The sparks: four-pointed golden stars that flash, grow then shrink, turning, each at its time.
func _draw_sparks() -> void:
	var origin := _badge.position - _sparks.position
	for spark in _SPARKS:
		var part := (_time - spark.z) / _SPARK_S
		if part <= 0.0 or part >= 1.0:
			continue
		var rising := part < 0.35
		var k := part / 0.35 if rising else (part - 0.35) / 0.65
		var colour := DiscoveryBadge.RIM
		colour.a = k if rising else 1.0 - k
		var reach := 23.0 * (lerpf(0.2, 1.2, k) if rising else lerpf(1.2, 0.4, k))
		var turn := deg_to_rad(lerpf(0.0, 40.0, k) if rising else lerpf(40.0, 90.0, k))
		var at := origin + Vector2(spark.x, spark.y) * _badge.size
		var star := PackedVector2Array()
		for i in 8:
			star.append(at + Vector2.from_angle(turn + i * PI / 4.0) * (reach if i % 2 == 0 else reach * 0.22))
		_sparks.draw_colored_polygon(star, colour)


func _on_continue_pressed() -> void:
	_continue.disabled = true
	finished.emit()
