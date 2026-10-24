# SPDX-License-Identifier: GPL-3.0-or-later
class_name SettingsTransition
extends RefCounted
## Holds the source screen's pose while the settings card drives one reversible clock.

var _sample: Callable
var _restore: Callable
var _paused: Array[Tween] = []
var _menu: SettingsMenu


func _init(menu: SettingsMenu, games: bool, row: ShelfRow, consoles: ConsoleRow,
		title: Control, pill: Control, hints: Control, search: Control,
		sequence: ConsoleSequence, console_rail: ConsoleRail, grounds: Control, games_logo: Control, tweens: Array[Tween]) -> void:
	_menu = menu
	row.settle()
	consoles.settle()
	for tween in tweens:
		if tween and tween.is_running():
			tween.pause()
			_paused.append(tween)
	var subject: Node3D = row if games else consoles
	var subject_scale := subject.scale
	var title_position := title.position
	var title_alpha := title.modulate.a
	var pill_alpha := pill.modulate.a
	var rail_alpha := console_rail.ground_alpha
	var ground_alpha := grounds.modulate.a
	var logo_alpha := games_logo.modulate.a
	var row_presence := Vector2(row.selected_presence, row.neighbours)
	_sample = func(presence: float, rail: float, chrome: float) -> void:
		var drawn := presence > 0.0 or chrome > 0.0
		row.visible = drawn
		consoles.visible = drawn
		title.visible = drawn
		pill.visible = drawn
		search.visible = drawn
		hints.visible = drawn
		subject.scale = subject_scale * lerpf(0.96, 1.0, presence)
		if games:
			row.selected_presence = row_presence.x * presence
			row.neighbours = row_presence.y * presence
		else:
			consoles.fade_to(presence)
		title.position.y = title_position.y + 51.2 * (1.0 - rail)
		title.modulate.a = title_alpha * chrome
		pill.modulate.a = pill_alpha * chrome
		hints.modulate.a = chrome
		search.modulate.a = chrome
		console_rail.ground_alpha = rail_alpha * chrome
		grounds.modulate.a = ground_alpha * chrome
		games_logo.modulate.a = logo_alpha * chrome
		if not drawn:
			sequence.behind_amount = 0.0
	_restore = func(arrived: bool) -> void:
		subject.scale = subject_scale
		title.position = title_position
		if not arrived:
			title.modulate.a = title_alpha
			console_rail.ground_alpha = rail_alpha
			grounds.modulate.a = ground_alpha
		games_logo.modulate.a = logo_alpha
		pill.modulate.a = pill_alpha
		hints.modulate.a = 1.0
		search.modulate.a = 1.0
		row.selected_presence = row_presence.x
		row.neighbours = row_presence.y
		consoles.fade_to(1.0)
	menu.transition_frame.connect(_sample)
	menu.enter()


func restore(arrived := false) -> void:
	_menu.transition_frame.disconnect(_sample)
	_restore.call(arrived)


## A new arrival supersedes the paused one when the library changed under the card.
func resume(current: Array[Tween]) -> void:
	for tween in _paused:
		if tween in current:
			tween.play()
		else:
			tween.kill()
