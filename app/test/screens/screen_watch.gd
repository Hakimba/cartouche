# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## What the app says of itself at one moment, read for the model of screen_model.gd: the one place the walk of
## live_screen_test.gd reads the carousel, its screens and the fake device. A page, a step or a busy state the app
## gains is added here, with its rows in the model's table.

const Fixtures := preload("res://test/screens/fixtures.gd")
const ScreenModel := preload("res://test/screens/screen_model.gd")
## The pages of the screens flow the model has, by node name.
const _PAGES: Dictionary[String, ScreenModel.At] = {
	"NoConsole": ScreenModel.At.NO_CONSOLE, "AddConsole": ScreenModel.At.FORM, "Confirm": ScreenModel.At.CONFIRM,
	"Settings": ScreenModel.At.SETTINGS, "ButtonStyle": ScreenModel.At.SETTINGS_PAGE,
	"EdgeSmoothing": ScreenModel.At.SETTINGS_PAGE, "Backdrop": ScreenModel.At.SETTINGS_PAGE,
	"PreferredRegion": ScreenModel.At.SETTINGS_PAGE, "Language": ScreenModel.At.SETTINGS_PAGE,
}
const _STEPS: Dictionary[DiscProperties.Step, ScreenModel.At] = {
	DiscProperties.Step.PROPERTIES: ScreenModel.At.PROPERTIES, DiscProperties.Step.LABELS: ScreenModel.At.LABELS,
	DiscProperties.Step.FRAMING: ScreenModel.At.FRAMING, DiscProperties.Step.NAMING: ScreenModel.At.NAMING,
}
## The placing's states that take presses.
const _CHOOSING: Array[Placing.State] = [Placing.State.ARRIVING, Placing.State.CHOOSING]


## What [param carousel] says of itself now, and what [param device] was asked so far.
static func read(carousel: Carousel, device: Fixtures.NewDevice) -> ScreenModel.Seen:
	var seen := ScreenModel.Seen.new()
	seen.screen = Fixtures.ScreenAgreement.screen_name(carousel)
	var focused := carousel.get_viewport().gui_get_focus_owner()
	seen.focus = str(focused.name) if focused != null else ""
	seen.device = with_games(device)
	seen.launches = device.launches
	seen.orders = device.orders.size()
	seen.removals = device.removed.size()
	seen.placings = device.placed.size()
	seen.scans = device.scans
	seen.ms = carousel.clock.call()
	for shelf in carousel._shelves:
		seen.consoles.append(shelf.platform_id)
	if not seen.consoles.is_empty():
		seen.console = seen.consoles[carousel._shelf]
		seen.games = carousel._shelves[carousel._shelf].games.size()
		if carousel._row.has_games():
			seen.game = carousel._row.selected_game().id
	seen.ball = carousel._add_ball.is_open
	var order := carousel._order
	var page := Fixtures.shown_screen(carousel)
	# The ring placing a console takes its presses while the form still fades behind it.
	if order.is_placing():
		seen.at = ScreenModel.At.PLACING
		seen.gap = order.placing_gap()
		seen.phase = ScreenModel.Phase.LIVE if order.placing_state() in _CHOOSING else ScreenModel.Phase.MOVING
	elif page != null:
		_read_page(page, focused, seen)
	else:
		_read_carousel(carousel, seen)
	return seen


## The consoles [param device] holds with games, by platform id, in its order: those a library it sends shows.
static func with_games(device: Fixtures.NewDevice) -> Array[String]:
	var found: Array[String] = []
	for platform_id in device.consoles:
		if device.consoles[platform_id] > 0:
			found.append(platform_id)
	return found


## A page of the screens flow in front: it takes presses when it holds none, its card does not move, and one of its
## controls, able to act, has the focus.
static func _read_page(page: Control, focused: Control, seen: ScreenModel.Seen) -> void:
	var shown := str(page.name)
	seen.known = _PAGES.has(shown)
	if not seen.known:
		return
	seen.at = _PAGES[shown]
	seen.page = shown.to_snake_case()
	var form := page as AddConsole
	if form != null:
		seen.editing = form.is_editing()
		seen.type = form.platform_id
		seen.has_folder = form.setup().has_folder_uri
		if (form.get_node("%Choice") as StudioChooser).visible:
			seen.at = ScreenModel.At.FORM_LIST
		elif (form.get_node("%Models") as ModelSwatches).is_open():
			seen.at = ScreenModel.At.FORM_MODELS
	var menu := page as SettingsMenu
	if menu != null and not menu.held.pending() and menu.state != SettingsMenu.State.OPEN:
		seen.phase = ScreenModel.Phase.MOVING
	elif page.call(&"holds_presses"):
		seen.phase = ScreenModel.Phase.HELD
	elif focused != null and page.is_ancestor_of(focused) and focused.is_visible_in_tree() and focused.can_process():
		seen.phase = ScreenModel.Phase.LIVE


## The carousel in front: it takes presses but under the screens flow, into or out of a console, during a launch or
## a toss, while the ring or the properties move.
static func _read_carousel(carousel: Carousel, seen: ScreenModel.Seen) -> void:
	var order := carousel._order
	var properties := carousel._properties
	var moving := not carousel.is_shown() or carousel._game_launch.is_busy() or carousel._toss.is_busy()
	match carousel.screen():
		Carousel.Screen.CONSOLES:
			seen.at = ScreenModel.At.CONSOLES
		Carousel.Screen.LEAVING:
			seen.at = ScreenModel.At.CONSOLES
			moving = true
		Carousel.Screen.ENTERING:
			seen.at = ScreenModel.At.GAMES
			moving = true
		Carousel.Screen.GAMES:
			seen.at = ScreenModel.At.SEARCH if carousel._search.is_open() else ScreenModel.At.GAMES
		Carousel.Screen.PROPERTIES:
			var step: ScreenModel.At = _STEPS.get(properties._step, ScreenModel.At.GAMES)
			seen.at = step
			moving = moving or properties._holding()
		Carousel.Screen.CONSOLE_EDIT:
			seen.at = ScreenModel.At.FORM
			moving = true
		Carousel.Screen.ORDER:
			seen.at = ScreenModel.At.ORDER_HOLDING if order._wheel.is_holding() else ScreenModel.At.ORDER
			seen.ring = order._wheel.order.duplicate()
			seen.cursor = order._wheel.selected()
			moving = moving or order.is_busy()
	seen.phase = ScreenModel.Phase.MOVING if moving else ScreenModel.Phase.LIVE
