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
		sequence: ConsoleSequence, console_rail: ConsoleRail, games_logo: Control, tweens: Array[Tween]) -> void:
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
	var rail_shown := console_rail.visible
	var logo_alpha := games_logo.modulate.a
	# The games screen's hints, laid where the consoles screen has its own: shown on the games screen only.
	var hints_alpha := 1.0 if games else 0.0
	# The models are cut, never faded: a faded 3D model shows its insides. What stands around them goes and comes with
	# them, never left alone on the backdrop.
	_sample = func(presence: float, rail: float, chrome: float, cut: bool) -> void:
		var shown := 0.0 if cut else chrome
		var drawn := not cut and (presence > 0.0 or chrome > 0.0)
		row.visible = not cut
		consoles.visible = not cut
		console_rail.visible = rail_shown and not cut
		title.visible = drawn
		pill.visible = drawn
		search.visible = drawn
		hints.visible = drawn
		subject.scale = subject_scale * lerpf(StudioTokens.TR_SETTINGS_RECEDE, 1.0, presence)
		title.position.y = title_position.y + StudioTokens.TR_SETTINGS_DROP_PX * (1.0 - rail)
		title.modulate.a = title_alpha * shown
		pill.modulate.a = pill_alpha * shown
		hints.modulate.a = hints_alpha * shown
		search.modulate.a = shown
		console_rail.ground_alpha = rail_alpha * shown
		games_logo.modulate.a = logo_alpha * shown
		if not drawn:
			sequence.behind_amount = 0.0
	_restore = func(arrived: bool) -> void:
		subject.scale = subject_scale
		title.position = title_position
		console_rail.visible = rail_shown
		if not arrived:
			title.modulate.a = title_alpha
			console_rail.ground_alpha = rail_alpha
		games_logo.modulate.a = logo_alpha
		pill.modulate.a = pill_alpha
		hints.modulate.a = hints_alpha
		search.modulate.a = 1.0
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
