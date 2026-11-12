# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The screens over the consoles ring ("+", Edit, the ring putting them in order), opened and closed, watched frame by
## frame: a console is never drawn half transparent (faded per surface, it shows its insides; seen through a form
## fading, or faded as a picture, it shows as a pale ghost), and the card flying between "+" and the form never shows
## empty. Closing a form, its console is gone at once, the form leaves alone, and only once it is gone does the ring
## come in, its console whole, easing from just under its size to it.

const Fixtures := preload("res://test/screens/fixtures.gd")

## What went wrong, frame by frame, while watched.
var _seen: Array[String] = []
var _carousel: Carousel
## Whether the form showed on the frame before.
var _form_was_shown := false


func _shown() -> void:
	var device := Fixtures.past_first_launch(self, {"gba": 2, "ps2": 3})
	device.players_everywhere = true
	_carousel = await Fixtures.shown(self, device)
	await Fixtures.wait(self, func() -> bool: return _carousel._consoles.arrival == 1.0)
	get_tree().process_frame.connect(_look)


func after_test() -> void:
	if get_tree().process_frame.is_connected(_look):
		get_tree().process_frame.disconnect(_look)
	_seen.clear()
	_form_was_shown = false


## How opaque [param item] is drawn, its own modulate and those above it multiplied.
static func _alpha(item: CanvasItem) -> float:
	var alpha := item.self_modulate.a
	var at: Node = item
	while at is CanvasItem:
		alpha *= (at as CanvasItem).modulate.a
		at = at.get_parent()
	return alpha


func _look() -> void:
	var row := _carousel._consoles
	var form: AddConsole = _carousel.get_node("%Screens/AddConsole")
	var backdrop := form.get_node(^"Backdrop") as CanvasItem
	var veiling := _alpha(backdrop)
	if row.is_visible_in_tree() and form.is_visible_in_tree() and veiling > 0.0:
		_seen.append("the ring's console seen through the form at %.2f" % veiling)
	var console := form.get_node(^"%Console") as CanvasItem
	var drawn := _alpha(console)
	if console.is_visible_in_tree() and drawn > 0.0 and drawn < 1.0:
		_seen.append("the form's console drawn at %.2f" % drawn)
	var entry := _carousel._form_entry
	if entry and entry._card.is_visible_in_tree() and entry._line.text.is_empty():
		_seen.append("the flying card is empty")
	if form.is_visible_in_tree() and form.phase == Page.Phase.LEAVING:
		if console.is_visible_in_tree() and drawn > 0.0:
			_seen.append("the form's console still shown as the form leaves")
		var back := {"console": row.is_visible_in_tree(), "rail": _carousel._rail.is_visible_in_tree(),
			"title": _carousel._console_title.is_visible_in_tree()}
		for part: String in back:
			if back[part]:
				_seen.append("the ring's %s back under the form leaving" % part)
	if _form_was_shown and not form.is_visible_in_tree() and row.arrival >= 1.0:
		_seen.append("the ring's console back at once, not arriving")
	# Coming back, as after the settings: from just under its size to it, never from a point nor past it.
	if row.is_visible_in_tree() and (row.arrival > 1.0 or row.arrival < StudioTokens.TR_SETTINGS_RECEDE - 0.001):
		_seen.append("the ring's console at %.2f of its size" % row.arrival)
	_form_was_shown = form.is_visible_in_tree()


func _closed() -> void:
	await Fixtures.wait(self, func() -> bool:
		return Fixtures.shown_screen(_carousel) == null and _carousel.screen() == Carousel.Screen.CONSOLES \
			and not _carousel._order.is_open())
	await get_tree().create_timer(0.3).timeout
	assert_bool(_carousel._consoles.is_visible_in_tree()).is_true()
	assert_array(_seen).is_empty()


func test_the_add_form_comes_and_goes_without_a_console_seen_through_it_nor_an_empty_card() -> void:
	await _shown()
	await Fixtures.open_add_console(self, _carousel)
	await get_tree().create_timer(0.6).timeout
	assert_bool(_carousel._consoles.is_visible_in_tree()).is_false()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _closed()


func test_the_edit_form_comes_and_goes_with_its_console_opaque_and_the_ring_s_never_seen_through_it() -> void:
	await _shown()
	await Fixtures.joypad(self, JOY_BUTTON_X)
	assert_bool(await Fixtures.on(self, _carousel, "AddConsole")).is_true()
	await get_tree().create_timer(0.6).timeout
	assert_bool((_carousel.get_node("%Screens/AddConsole/%Console") as Control).is_visible_in_tree()).is_true()
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _closed()


func test_the_ring_putting_consoles_in_order_opens_and_closes_with_every_console_opaque() -> void:
	await _shown()
	await Fixtures.action(self, &"ui_down")
	await Fixtures.wait(self, func() -> bool: return _carousel._order.is_open())
	await Fixtures.settled_consoles(self, _carousel)
	await Fixtures.joypad(self, JOY_BUTTON_B)
	await _closed()
