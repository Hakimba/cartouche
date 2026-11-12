# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## What Cartouche shows after each press, as its validated scenarios say it: one table of screens and presses
## ([constant TABLE]), walked beside the real app by live_screen_test.gd. Nothing here reads a node: what the app says
## of itself comes in as a [Seen] (screen_watch.gd writes it), what the fake device answers as [member slow] and
## [member failing].

enum At {
	NO_CONSOLE, CONSOLES, GAMES, SEARCH, PROPERTIES, LABELS, FRAMING, NAMING, ORDER, ORDER_HOLDING, FORM, FORM_LIST,
	FORM_MODELS, CONFIRM, PLACING, SETTINGS, SETTINGS_PAGE,
}
## UP is up pressed and LET_UP up let go (the "+" ball lives between the two); the last seven are fingers on the
## console or the game in the middle, beside it, held on it, flicked up from it, then dragged left or right.
enum Press { LEFT, RIGHT, UP, LET_UP, DOWN, A, B, X, Y, START, TAP, TAP_LEFT, TAP_RIGHT, LONG, FLICK, DRAG_LEFT, DRAG_RIGHT }
## What the app says of the surface in front as a press is sent: it takes presses, something it plays is under way,
## or it holds them for an answer.
enum Phase { LIVE, MOVING, HELD }
## What the model knows is under way: a travel a press turns round ([constant TURNS]), or anything else.
enum Way { NONE, OTHER, PROPERTIES_OPENING, PROPERTIES_CLOSING, SETTINGS_OPENING, SETTINGS_CLOSING }
## What a row does besides reaching its state.
enum Do {
	GO, OPEN_FORM, OPEN_EDIT, OPEN_SETTINGS, STEP_CONSOLE, BALL_OPEN, BALL_CLOSE, ACCEPT_CONSOLE, ENTER, OPEN_ORDER,
	STEP_GAME, LAUNCH, TOSS, OPEN_PROPERTIES, CLOSE_PROPERTIES, CHOOSE_LABEL, KEEP_NAME, RING_STEP, TAKE, CARRY,
	PUT_DOWN, LET_GO, CLOSE_RING, OPEN_LIST, PICK_FOLDER, CANCEL, SAVE, GIVE_UP, CHOOSE_IN_LIST, REMOVE, MOVE_GAP, FLY,
	OPEN_PAGE, CLOSE_PAGE, CLOSE_SETTINGS, CHOOSE_ON_PAGE, TURN_SWITCH,
}

const SAME := -1
## A game the app chose out of the model's sight.
const UNKNOWN := -1
## [state, press, focus needed, what it does, state reached, focus there, source]. Sources: W a validated scenario,
## Z a step of the screens' timing model, C the code alone.
const TABLE: Array[Array] = [
	[At.NO_CONSOLE, Press.A, "Add", Do.OPEN_FORM, At.FORM, "Type", "W e6-supprimer-console 6"],
	[At.NO_CONSOLE, Press.Y, "", Do.OPEN_SETTINGS, At.SETTINGS, "ButtonStyle", "W e6-supprimer-console 1"],

	[At.CONSOLES, Press.LEFT, "", Do.STEP_CONSOLE, SAME, "", "W e6-ajouter-autre-console 3"],
	[At.CONSOLES, Press.RIGHT, "", Do.STEP_CONSOLE, SAME, "", "W e6-ajouter-autre-console 3"],
	[At.CONSOLES, Press.UP, "", Do.BALL_OPEN, SAME, "", "W e6-ajouter-autre-console 3"],
	[At.CONSOLES, Press.LET_UP, "", Do.BALL_CLOSE, SAME, "", "W e6-ajouter-autre-console 3"],
	[At.CONSOLES, Press.A, "", Do.ACCEPT_CONSOLE, At.GAMES, "", "W e6-ajouter-autre-console 3-4"],
	[At.CONSOLES, Press.X, "", Do.OPEN_EDIT, At.FORM, "Emulator", "W console-edit 1"],
	[At.CONSOLES, Press.DOWN, "", Do.OPEN_ORDER, At.ORDER, "", "W story ranger"],
	[At.CONSOLES, Press.Y, "", Do.OPEN_SETTINGS, At.SETTINGS, "ButtonStyle", "W e6-supprimer-console 1"],
	[At.CONSOLES, Press.TAP, "", Do.ENTER, At.GAMES, "", "W story toucher"],
	[At.CONSOLES, Press.TAP_LEFT, "", Do.STEP_CONSOLE, SAME, "", "C CarouselTouch._tap"],
	[At.CONSOLES, Press.TAP_RIGHT, "", Do.STEP_CONSOLE, SAME, "", "C CarouselTouch._tap"],
	[At.CONSOLES, Press.LONG, "", Do.OPEN_EDIT, At.FORM, "Emulator", "Z YouHoldYourFinger"],

	[At.GAMES, Press.LEFT, "", Do.STEP_GAME, SAME, "", "Z PressCarousel"],
	[At.GAMES, Press.RIGHT, "", Do.STEP_GAME, SAME, "", "Z PressCarousel"],
	[At.GAMES, Press.A, "", Do.LAUNCH, SAME, "", "Z Launch"],
	[At.GAMES, Press.UP, "", Do.TOSS, SAME, "", "W random-pick 1"],
	[At.GAMES, Press.DOWN, "", Do.GO, At.SEARCH, "", "Z PressCarousel"],
	[At.GAMES, Press.B, "", Do.GO, At.CONSOLES, "", "Z Leave"],
	[At.GAMES, Press.X, "", Do.OPEN_PROPERTIES, At.PROPERTIES, "Zone", "W story image-region"],
	[At.GAMES, Press.Y, "", Do.OPEN_SETTINGS, At.SETTINGS, "ButtonStyle", "W story lissage-bords"],
	[At.GAMES, Press.TAP_LEFT, "", Do.STEP_GAME, SAME, "", "C CarouselTouch._step_beside"],
	[At.GAMES, Press.TAP_RIGHT, "", Do.STEP_GAME, SAME, "", "C CarouselTouch._step_beside"],
	[At.GAMES, Press.LONG, "", Do.OPEN_PROPERTIES, At.PROPERTIES, "Zone", "W story toucher"],
	[At.GAMES, Press.FLICK, "", Do.TOSS, SAME, "", "C CarouselTouch._flick"],

	[At.SEARCH, Press.UP, "", Do.GO, At.GAMES, "", "C GameSearch.take"],
	[At.SEARCH, Press.START, "", Do.GO, At.GAMES, "", "C GameSearch.take"],
	[At.SEARCH, Press.B, "", Do.GO, At.GAMES, "", "C GameSearch.take"],

	[At.PROPERTIES, Press.A, "Zone", Do.GO, At.LABELS, "", "W story image-region"],
	[At.PROPERTIES, Press.A, "Name", Do.GO, At.NAMING, "", "W story nom-jeu"],
	[At.PROPERTIES, Press.B, "", Do.CLOSE_PROPERTIES, At.GAMES, "", "W story image-region"],
	[At.LABELS, Press.A, "", Do.CHOOSE_LABEL, At.PROPERTIES, "", "W story image-region"],
	[At.LABELS, Press.B, "", Do.GO, At.PROPERTIES, "Zone", "C DiscProperties._unhandled_input"],
	[At.FRAMING, Press.A, "", Do.GO, At.PROPERTIES, "Zone", "W story image-perso"],
	[At.FRAMING, Press.B, "", Do.GO, At.LABELS, "", "C DiscProperties._unhandled_input"],
	[At.NAMING, Press.START, "", Do.KEEP_NAME, At.PROPERTIES, "Name", "W story nom-jeu"],
	[At.NAMING, Press.B, "", Do.GO, At.PROPERTIES, "Name", "C DiscProperties._unhandled_input"],

	[At.ORDER, Press.LEFT, "", Do.RING_STEP, SAME, "", "W story ranger"],
	[At.ORDER, Press.RIGHT, "", Do.RING_STEP, SAME, "", "W story ranger"],
	[At.ORDER, Press.A, "", Do.TAKE, At.ORDER_HOLDING, "", "W story ranger"],
	[At.ORDER, Press.B, "", Do.CLOSE_RING, At.CONSOLES, "", "W story ranger"],
	[At.ORDER_HOLDING, Press.LEFT, "", Do.CARRY, SAME, "", "W story ranger-deplacer"],
	[At.ORDER_HOLDING, Press.RIGHT, "", Do.CARRY, SAME, "", "W story ranger-deplacer"],
	[At.ORDER_HOLDING, Press.A, "", Do.PUT_DOWN, At.ORDER, "", "W story ranger"],
	[At.ORDER_HOLDING, Press.B, "", Do.LET_GO, At.ORDER, "", "Z PressRing"],

	[At.FORM, Press.A, "Type", Do.OPEN_LIST, At.FORM_LIST, "", "W e6-ajouter-autre-console 4"],
	[At.FORM, Press.A, "Emulator", Do.OPEN_LIST, At.FORM_LIST, "", "W e6-ajouter-autre-console 4"],
	[At.FORM, Press.A, "Folder", Do.PICK_FOLDER, SAME, "", "Z folder-pick YouPressFolder"],
	[At.FORM, Press.A, "Model", Do.GO, At.FORM_MODELS, "", "W console-edit 4"],
	[At.FORM, Press.A, "Cancel", Do.CANCEL, SAME, "", "W e6-supprimer-console 4-5"],
	[At.FORM, Press.A, "Add", Do.SAVE, SAME, "", "W e6-ajouter-autre-console 5"],
	[At.FORM, Press.B, "", Do.GIVE_UP, SAME, "", "W e6-supprimer-console 4"],
	[At.FORM_LIST, Press.A, "", Do.CHOOSE_IN_LIST, At.FORM, "", "Z PressChooser"],
	[At.FORM_LIST, Press.B, "", Do.GO, At.FORM, "", "Z PressChooser"],
	[At.FORM_MODELS, Press.A, "", Do.GO, At.FORM, "Model", "W console-edit 4"],
	[At.FORM_MODELS, Press.B, "", Do.GO, At.FORM, "Model", "Z PressFlow models"],
	[At.CONFIRM, Press.A, "Cancel", Do.GO, At.FORM, "Cancel", "W e6-supprimer-console 5"],
	[At.CONFIRM, Press.A, "Remove", Do.REMOVE, SAME, "", "W e6-supprimer-console 5"],
	[At.CONFIRM, Press.B, "", Do.GO, At.FORM, "Cancel", "W e6-supprimer-console 5"],
	[At.PLACING, Press.LEFT, "", Do.MOVE_GAP, SAME, "", "C Placing.press"],
	[At.PLACING, Press.RIGHT, "", Do.MOVE_GAP, SAME, "", "C Placing.press"],
	[At.PLACING, Press.A, "", Do.FLY, At.CONSOLES, "", "C Placing.press"],
	[At.PLACING, Press.B, "", Do.GO, At.FORM, "Add", "C Placing.press"],
	[At.PLACING, Press.DRAG_LEFT, "", Do.MOVE_GAP, SAME, "", "C ConsoleOrder._input"],
	[At.PLACING, Press.DRAG_RIGHT, "", Do.MOVE_GAP, SAME, "", "C ConsoleOrder._input"],
	[At.PLACING, Press.TAP, "", Do.FLY, At.CONSOLES, "", "C ConsoleOrder._input"],
	[At.PLACING, Press.TAP_LEFT, "", Do.FLY, At.CONSOLES, "", "C ConsoleOrder._input"],
	[At.PLACING, Press.TAP_RIGHT, "", Do.FLY, At.CONSOLES, "", "C ConsoleOrder._input"],

	[At.SETTINGS, Press.A, "ButtonStyle", Do.OPEN_PAGE, At.SETTINGS_PAGE, "", "W e6-supprimer-console 2"],
	[At.SETTINGS, Press.A, "Graphics", Do.OPEN_PAGE, At.SETTINGS_PAGE, "", "W story lissage-bords"],
	[At.SETTINGS, Press.A, "Backdrop", Do.OPEN_PAGE, At.SETTINGS_PAGE, "", "Z PressFlow settings"],
	[At.SETTINGS, Press.A, "Region", Do.OPEN_PAGE, At.SETTINGS_PAGE, "", "Z PressFlow settings"],
	[At.SETTINGS, Press.A, "Language", Do.OPEN_PAGE, At.SETTINGS_PAGE, "", "C ScreenFlow._settings_menu"],
	[At.SETTINGS, Press.A, "PixelVeil", Do.TURN_SWITCH, SAME, "PixelVeil", "C ScreenFlow._turn_switch"],
	[At.SETTINGS, Press.A, "GamesFloat", Do.TURN_SWITCH, SAME, "GamesFloat", "C ScreenFlow._turn_switch"],
	[At.SETTINGS, Press.A, "GamesInLine", Do.TURN_SWITCH, SAME, "GamesInLine", "C ScreenFlow._turn_switch"],
	[At.SETTINGS, Press.B, "", Do.CLOSE_SETTINGS, SAME, "", "W e6-supprimer-console 2"],
	[At.SETTINGS_PAGE, Press.A, "", Do.CHOOSE_ON_PAGE, At.SETTINGS, "", "W story lissage-bords"],
	[At.SETTINGS_PAGE, Press.B, "", Do.CLOSE_PAGE, At.SETTINGS, "", "W e6-supprimer-console 2"],
]
## [what is under way, press, what is under way then, source]: the only presses taken while something moves.
const TURNS: Array[Array] = [
	[Way.PROPERTIES_OPENING, Press.B, Way.PROPERTIES_CLOSING, "Z PressProps"],
	[Way.PROPERTIES_CLOSING, Press.X, Way.PROPERTIES_OPENING, "C DiscProperties._input"],
	[Way.SETTINGS_OPENING, Press.B, Way.SETTINGS_CLOSING, "Z PressFlow settings"],
	[Way.SETTINGS_CLOSING, Press.Y, Way.SETTINGS_OPENING, "Z PressFlow settings"],
]
## The screen the app names in each state (`state.screen` of the debug bridge); none while a console is placed (the
## form fades behind the ring), the page's own on a settings page.
const SCREENS: Dictionary[At, String] = {
	At.NO_CONSOLE: "no_console", At.CONSOLES: "consoles", At.GAMES: "games", At.SEARCH: "games",
	At.PROPERTIES: "properties", At.LABELS: "properties", At.FRAMING: "properties", At.NAMING: "properties",
	At.ORDER: "order", At.ORDER_HOLDING: "order", At.FORM: "add_console", At.FORM_LIST: "add_console",
	At.FORM_MODELS: "add_console", At.CONFIRM: "confirm", At.PLACING: "", At.SETTINGS: "settings", At.SETTINGS_PAGE: "",
}
## The settings' rows that open a page, and that page.
const PAGES: Dictionary[String, String] = {
	"ButtonStyle": "button_style", "Graphics": "edge_smoothing", "Backdrop": "backdrop", "Region": "preferred_region",
	"Language": "language",
}
const _FORMS: Array[At] = [At.FORM, At.FORM_LIST, At.FORM_MODELS]
const _WITH_A_GAME: Array[At] = [At.GAMES, At.SEARCH, At.PROPERTIES, At.LABELS, At.FRAMING, At.NAMING]
const _DIRECTIONS: Array[Press] = [Press.LEFT, Press.RIGHT, Press.UP, Press.DOWN]

var at := At.CONSOLES
var way := Way.NONE
## The consoles shown, by platform id, in the ring's order, and the one selected.
var consoles: Array[String] = []
var console := 0
## The selected game of each console, as its place on its shelf; the first for a console not here.
var game: Dictionary[String, int] = {}
## The console whose toss is to land, empty for none: the game it lands on is the app's to say. A toss that landed
## while the games no longer showed (a re-read sent them back to the consoles) leaves that console's game unknown,
## [constant UNKNOWN], until the app shows it again.
var tossed := ""
var ball := false
## The order ring: its order as shown, the cursor, and the order as it was when a console was taken.
var ring: Array[String] = []
var cursor := 0
var taken: Array[String] = []
## The placing: the console placed, the others, and the gap chosen (after which of them).
var placed := ""
var others: Array[String] = []
var gap := 0
## The consoles as they were while a console flies to its gap, empty when none flies: the plugin may refuse the
## placing as the console lands (ConsoleOrder._landed, Placing.refuse), its folder emptied meanwhile.
var flying: Array[String] = []
## The form: whether it edits a console, shows a folder, is as it opened (nothing chosen), stored its console; which
## filling it is on; the console being saved.
var editing := false
var folder := false
var fresh := false
var stored := false
var filling := 0
var saving := ""
## Where the form or the settings go back to; the settings page shown.
var back := At.CONSOLES
var page := ""
## The control that must have the focus, empty when any may.
var focus := ""
## The states the app may be on, for a press whose answer is the app's to say (a list, a label, a name).
var may: Array[At] = []
## The held answer the screen waits for, none when empty.
var waiting := &""
## The save of the settings held, none when empty: the page it holds (empty for the card) and when it started, by the
## app's clock. B lets the presses go once it has lasted ScreenFlow.HeldSave.ESCAPE_MS; its answer, whenever it comes,
## frees the card.
var held_save := &""
var held_page := ""
var held_since := 0
## The requests the fake device holds, and those it fails: its own arrays, shared.
var slow: Array[StringName] = []
var failing: Array[StringName] = []
## What the device must have been asked.
var launches := 0
var orders := 0
var picks := 0
var removals := 0
var placings := 0
## The filling a folder pick still unanswered was asked in, -1 for none: its folder shows only in that filling.
var pick_filling := -1
## Whether the folders were read again and what they hold may still be to show.
var due := false


## Starts on the consoles of [param ids] (platform ids, in order), on the first; on "No console" with none.
func start(ids: Array[String]) -> void:
	consoles = ids.duplicate()
	at = At.NO_CONSOLE if consoles.is_empty() else At.CONSOLES


## The screen the app must name now.
func screen() -> String:
	return page if at == At.SETTINGS_PAGE else SCREENS[at]


## Takes [param pressed], sent as the app said [param seen] of itself; of [param after], read once the press was
## sent, only what the device holds and was asked counts. Returns the source of the row applied, empty when the
## press changes nothing.
func press(pressed: Press, seen: Seen, after: Seen) -> String:
	if pressed in _DIRECTIONS:
		focus = ""
	if seen.phase == Phase.MOVING:
		for turn: Array in TURNS:
			if turn[0] == way and turn[1] == pressed:
				var turned: Way = turn[2]
				var told: String = turn[3]
				_turn(turned)
				return told
	if pressed == Press.B and seen.phase == Phase.HELD and at in [At.SETTINGS, At.SETTINGS_PAGE] \
			and not held_save.is_empty() and seen.ms - held_since >= ScreenFlow.HeldSave.ESCAPE_MS:
		return _let_go_of_save()
	if seen.phase != Phase.LIVE or waiting != &"":
		return ""
	for row: Array in TABLE:
		var needed: String = row[2]
		if row[0] == at and row[1] == pressed and (needed.is_empty() or needed == seen.focus):
			var what: Do = row[3]
			var to: int = row[4]
			var focused: String = row[5]
			var source: String = row[6]
			focus = focused
			_act(what, to, pressed, seen, after)
			return source
	return ""


## The held answer to [param request] is released; [param device] is the consoles the device then holds with games.
func answered(request: StringName, device: Array[String]) -> void:
	if request == &"pick_folder" and pick_filling >= 0:
		var own := pick_filling == filling
		pick_filling = -1
		if at in _FORMS and request not in failing and own:
			folder = true
	elif request == held_save:
		held_save = &""
		if request == waiting:
			waiting = &""
			# A backdrop answered stays on its cards; the other pages go back to the card.
			if page != "backdrop":
				at = At.SETTINGS
				focus = _row_of(page)
	elif request == waiting:
		waiting = &""
		if request == &"scan":
			if request not in failing:
				_saved(device)
		else:
			_ordered()


## The app is put aside: the ball closes.
func paused() -> void:
	ball = false


## The app is back: its folders are read again; a form in front reads its emulators and counts its games again, its
## "Add" greyed meanwhile (the focus goes to the folder: AddConsole._show_count), and back to "Add" if it had it and
## games are counted: the focus is the app's to say.
func resumed() -> void:
	due = true
	if at in _FORMS:
		focus = ""


## What the app, taking presses, shows that the model does not have: empty when they agree, led by the id of a known
## finding when it is one. What the model leaves to the app (where a toss landed, what a list answered, a re-read
## shown) is taken from it here.
func check(seen: Seen) -> String:
	way = Way.NONE
	if not flying.is_empty():
		_landed(seen)
	if due and seen.consoles == seen.device:
		_reread(seen)
	if seen.at in may:
		at = seen.at
	may.clear()
	if not seen.known:
		return "the app shows %s, a screen the model does not have" % seen.screen
	if at == seen.at and (at == At.SETTINGS or waiting == held_save) and not held_save.is_empty():
		return "the settings take presses while the save %s is under way" % held_save
	if seen.at != at:
		return "the app is on %s, the model on %s" % [At.keys()[seen.at], At.keys()[at]]
	if at == At.SETTINGS_PAGE and seen.page != page:
		return "the settings page is %s, the model's %s" % [seen.page, page]
	if at in _FORMS:
		if seen.editing != editing:
			return "the form %s a console, the model's %s" % ["edits" if seen.editing else "adds", "edits" if editing else "adds"]
		if fresh and not seen.type.is_empty():
			return "the form opened with %s chosen" % seen.type
		if seen.has_folder != folder:
			folder = seen.has_folder
			return "the form shows %s folder, the model's the other way" % ("a" if seen.has_folder else "no")
	if not focus.is_empty() and seen.focus != focus:
		return "the focus is on %s, the model's on %s" % [seen.focus, focus]
	if not due:
		if seen.consoles != consoles:
			return "the consoles are %s, the model's %s" % [seen.consoles, consoles]
		if not consoles.is_empty() and seen.console != consoles[console]:
			return "the console is %s, the model's %s" % [seen.console, consoles[console]]
	if not tossed.is_empty() and (at not in _WITH_A_GAME or tossed != seen.console):
		game[tossed] = UNKNOWN
		tossed = ""
	if at in _WITH_A_GAME:
		var shown := seen.game.get_slice("/", 1).to_int()
		if tossed == seen.console:
			tossed = ""
			if shown == _game_of(seen.console):
				return "the toss landed on the game tossed, %s" % seen.game
			game[seen.console] = shown
		elif _game_of(seen.console) == UNKNOWN:
			game[seen.console] = shown
		elif seen.game != "%s/%d" % [seen.console, _game_of(seen.console)]:
			return "the game is %s, the model's %s/%d" % [seen.game, seen.console, _game_of(seen.console)]
	if at == At.CONSOLES and seen.ball != ball:
		return "the ball is %s, the model's %s" % ["open" if seen.ball else "closed", "open" if ball else "closed"]
	if at in [At.ORDER, At.ORDER_HOLDING] and (seen.ring != ring or seen.cursor != ring[cursor]):
		return "the ring is %s on %s, the model's %s on %s" % [seen.ring, seen.cursor, ring, ring[cursor]]
	if at == At.PLACING and seen.gap != gap:
		return "the gap is %d, the model's %d" % [seen.gap, gap]
	if seen.picks != picks:
		var counted := picks
		picks = seen.picks
		return "%d folder picks asked, the model's %d" % [seen.picks, counted]
	var asked: Dictionary[String, Vector2i] = {
		"launches": Vector2i(seen.launches, launches), "orders": Vector2i(seen.orders, orders),
		"removals": Vector2i(seen.removals, removals), "placings": Vector2i(seen.placings, placings),
	}
	for what in asked:
		if asked[what].x != asked[what].y:
			return "%d %s asked of the device, the model's %d" % [asked[what].x, what, asked[what].y]
	return ""


func _act(what: Do, to: int, pressed: Press, seen: Seen, after: Seen) -> void:
	var step := -1 if pressed in [Press.LEFT, Press.TAP_LEFT, Press.DRAG_LEFT] else 1
	var device := after.device
	match what:
		Do.GO:
			_go(to)
		Do.OPEN_FORM:
			_open_form()
		Do.OPEN_EDIT:
			back = At.CONSOLES
			_go(At.FORM)
			editing = true
			folder = true
			fresh = false
			stored = false
			filling += 1
			ball = false
		Do.OPEN_SETTINGS:
			back = at
			at = At.SETTINGS
			way = Way.SETTINGS_OPENING
			ball = false
		Do.STEP_CONSOLE:
			ball = false
			if consoles.size() > 1:
				console = posmod(console + step, consoles.size())
		Do.BALL_OPEN:
			ball = true
		Do.BALL_CLOSE:
			ball = false
		Do.ACCEPT_CONSOLE:
			if ball:
				focus = "Type"
				_open_form()
			else:
				_go(At.GAMES)
		Do.ENTER:
			ball = false
			_go(At.GAMES)
		Do.OPEN_ORDER:
			if consoles.size() > 1:
				_go(At.ORDER)
				ball = false
				ring = consoles.duplicate()
				cursor = console
		Do.STEP_GAME:
			# A library read again may show as the press lands (its read ends on a thread, in the machine's time): the
			# step is taken on either shelf, the game the app's to say.
			if after.console == seen.console and after.games != seen.games:
				game[seen.console] = UNKNOWN
			elif seen.games > 1:
				game[seen.console] = posmod(_game_of(seen.console) + step, seen.games)
		Do.LAUNCH:
			launches += 1
			way = Way.OTHER
		Do.TOSS:
			if seen.games > 1:
				tossed = seen.console
				way = Way.OTHER
		Do.OPEN_PROPERTIES:
			at = At.PROPERTIES
			way = Way.PROPERTIES_OPENING
		Do.CLOSE_PROPERTIES:
			at = At.GAMES
			way = Way.PROPERTIES_CLOSING
		Do.CHOOSE_LABEL:
			may = [At.LABELS, At.PROPERTIES, At.FRAMING]
			way = Way.OTHER
		Do.KEEP_NAME:
			_go(At.PROPERTIES)
			if &"rename_game" in failing:
				may = [At.PROPERTIES, At.NAMING]
				focus = ""
		Do.RING_STEP:
			cursor = posmod(cursor + step, ring.size())
		Do.TAKE:
			taken = ring.duplicate()
			at = At.ORDER_HOLDING
		Do.CARRY:
			var next := posmod(cursor + step, ring.size())
			var passed := ring[next]
			ring[next] = ring[cursor]
			ring[cursor] = passed
			cursor = next
		Do.PUT_DOWN:
			at = At.ORDER
			if ring != taken:
				orders += 1
				if &"order_consoles" in slow:
					waiting = &"order_consoles"
				else:
					_ordered()
		Do.LET_GO:
			var held := ring[cursor]
			ring = taken.duplicate()
			cursor = ring.find(held)
			at = At.ORDER
		Do.CLOSE_RING:
			console = consoles.find(ring[cursor])
			_go(At.CONSOLES)
		Do.OPEN_LIST:
			fresh = false
			may = [At.FORM, At.FORM_LIST]
		Do.PICK_FOLDER:
			# One picker at a time: pressed again before the first answers, the field asks nothing.
			if pick_filling >= 0:
				return
			picks += 1
			if &"pick_folder" in slow:
				pick_filling = filling
			elif &"pick_folder" not in failing:
				folder = true
		Do.CANCEL:
			if editing:
				at = At.CONFIRM
				focus = "Cancel"
			else:
				_give_up(device)
		Do.SAVE:
			if &"set_up" in failing:
				return
			stored = true
			saving = seen.type
			# No scan asked: only the model of a console edited changed, saved as it is.
			# A held scan fails or not when it is answered: [method answered] decides.
			if after.scans == seen.scans:
				_saved(device)
			elif &"scan" in slow:
				waiting = &"scan"
				way = Way.OTHER
			elif &"scan" in failing:
				return
			else:
				_saved(device)
		Do.GIVE_UP:
			_give_up(device)
		Do.CHOOSE_IN_LIST:
			may = [At.FORM, At.FORM_LIST]
		Do.REMOVE:
			if &"remove" in failing:
				at = At.FORM
				focus = "Cancel"
			else:
				removals += 1
				editing = false
				_show(device, "")
				_go(At.NO_CONSOLE if consoles.is_empty() else At.CONSOLES)
		Do.MOVE_GAP:
			if others.size() > 1:
				gap = posmod(gap + step, others.size())
		Do.FLY:
			placings += 1
			flying = consoles.duplicate()
			consoles = others.duplicate()
			consoles.insert(gap + 1, placed)
			console = consoles.find(placed)
			_go(At.CONSOLES)
		Do.OPEN_PAGE:
			page = PAGES[seen.focus]
			at = At.SETTINGS_PAGE
		Do.CLOSE_PAGE:
			at = At.SETTINGS
			focus = _row_of(page)
		Do.CLOSE_SETTINGS:
			at = back
			way = Way.SETTINGS_CLOSING
		Do.CHOOSE_ON_PAGE:
			# A backdrop chosen stays on its cards; the others go back to the card once saved, kept or not.
			var save := StringName("save_" + page)
			if save in slow:
				_hold_save(save, page, seen)
				waiting = save
			elif page != "backdrop":
				at = At.SETTINGS
				focus = _row_of(page)
		Do.TURN_SWITCH:
			var save := StringName("save_" + seen.focus.to_snake_case())
			if save in slow:
				_hold_save(save, "", seen)


func _hold_save(save: StringName, holding: String, seen: Seen) -> void:
	held_save = save
	held_page = holding
	held_since = seen.ms


## B, once the save held has lasted its two seconds: the page it holds goes back to the card, the card closes; the save
## goes on.
func _let_go_of_save() -> String:
	if at == At.SETTINGS_PAGE and waiting == held_save:
		waiting = &""
		at = At.SETTINGS
		focus = _row_of(page)
		return "C ScreenFlow._input"
	at = back
	way = Way.SETTINGS_CLOSING
	focus = ""
	return "C SettingsMenu._input"


func _go(to: int) -> void:
	at = to as At
	way = Way.OTHER


func _turn(to: Way) -> void:
	way = to
	# A travel turned round: the focus its opening asked for is not due any more; the properties ask it again.
	focus = ""
	match to:
		Way.PROPERTIES_OPENING:
			at = At.PROPERTIES
			focus = "Zone"
		Way.PROPERTIES_CLOSING:
			at = At.GAMES
		Way.SETTINGS_OPENING:
			at = At.SETTINGS
		Way.SETTINGS_CLOSING:
			at = back


func _open_form() -> void:
	back = at
	_go(At.FORM)
	editing = false
	folder = false
	fresh = true
	stored = false
	filling += 1
	ball = false


## The form is given up: the library it stored, if any, shows; on the console edited, else on the first.
func _give_up(device: Array[String]) -> void:
	var edited := consoles[console] if editing else ""
	if stored:
		_show(device, edited)
	_go(At.CONSOLES if editing else back)
	editing = false


## The console saved shows: edited, or one of two at most, the consoles screen on it; from the third, the ring
## places it, the gap after the last of the others.
func _saved(device: Array[String]) -> void:
	_show(device, saving)
	if editing or consoles.size() <= 2:
		editing = false
		_go(At.CONSOLES)
		return
	_go(At.PLACING)
	placed = saving
	others = consoles.duplicate()
	others.erase(placed)
	gap = others.size() - 1


## The console flown has landed: refused, a console the device holds no game of or a gap past the consoles the device
## still holds games of (a folder emptied meanwhile), it flew back to the form as on B (Placing.refuse), the ring as it
## was.
func _landed(seen: Seen) -> void:
	var others_held := seen.device.size() - (1 if placed in seen.device else 0)
	if (placed not in seen.device or gap + 1 > others_held) and seen.at == At.FORM:
		consoles = flying
		console = consoles.find(placed)
		at = At.FORM
		focus = "Add"
	flying = []


## The order asked is kept, or, refused, the ring goes back to the order before, the cursor on the same console.
func _ordered() -> void:
	if &"order_consoles" in failing:
		var held := ring[cursor]
		ring = consoles.duplicate()
		cursor = ring.find(held)
		return
	var shown := consoles[console]
	consoles = ring.duplicate()
	console = consoles.find(shown)


## The library an answer brought shows: the consoles of [param device], on [param selected] when it is one of them,
## else on the first, every shelf on its first game.
func _show(device: Array[String], selected: String) -> void:
	consoles = device.duplicate()
	console = maxi(consoles.find(selected), 0)
	game.clear()
	tossed = ""


## The folders read again show: the same console when it still has games, else the first, the consoles screen then.
func _reread(seen: Seen) -> void:
	due = false
	if seen.consoles == consoles:
		return
	var shown := consoles[console] if not consoles.is_empty() else ""
	consoles = seen.consoles.duplicate()
	console = maxi(consoles.find(shown), 0)
	if shown not in consoles and at in [At.GAMES, At.SEARCH]:
		at = At.CONSOLES


func _game_of(platform_id: String) -> int:
	var index: int = game.get(platform_id, 0)
	return index


func _row_of(shown: String) -> String:
	var row: String = PAGES.find_key(shown)
	return row


## What the app says of itself at one moment (screen_watch.gd), and what the fake device was asked so far.
class Seen:
	var phase := Phase.MOVING
	var at := At.CONSOLES
	## False when the app shows a screen [enum At] does not have (the first launch's).
	var known := true
	## The screen the app names, and the settings page shown.
	var screen := ""
	var page := ""
	## The name of the control that has the focus, empty for none.
	var focus := ""
	## The consoles shown, and those the device holds with games, by platform id.
	var consoles: Array[String] = []
	var device: Array[String] = []
	## The selected console (platform id), its selected game (id) and how many games it has.
	var console := ""
	var game := ""
	var games := 0
	var ball := false
	var ring: Array[String] = []
	var cursor := ""
	var gap := -1
	var editing := false
	var type := ""
	var has_folder := false
	var launches := 0
	var orders := 0
	var picks := 0
	var removals := 0
	var placings := 0
	var scans := 0
	## The app's clock, in milliseconds.
	var ms := 0
