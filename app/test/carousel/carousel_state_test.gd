# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## [CarouselState] on every screen, under every holder, whatever is under way, for every button: no scene, no node.

const Screen := Carousel.Screen
const Holder := Carousel.Holder
const Front := CarouselState.Front
const Busy := CarouselState.Busy
const Take := CarouselState.Take
const Fact := CarouselState.Fact
const Command := CarouselState.Command
const WHOLE: Array[Screen] = [Screen.CONSOLES, Screen.GAMES]
## The holders under which the carousel shows.
const SHOWN: Array[Holder] = [Holder.CAROUSEL]
const ACTIONS: Array[StringName] = [&"ui_accept", &"screen_back", &"open_properties", &"open_settings", &"ui_up",
	&"ui_down", &"carousel_left", &"carousel_right", &"previous_letter"]
const EVERY_FACT := 256


func test_the_carousel_takes_what_each_rule_says_on_every_screen_under_every_holder_whatever_is_under_way() -> void:
	var wrong: Array[String] = []
	for screen: Screen in Screen.values():
		for holder: Holder in Holder.values():
			for under_way in 32:
				var launching := (under_way & Busy.LAUNCHING) != 0
				var tossing := (under_way & Busy.TOSSING) != 0
				var searching := (under_way & Busy.SEARCHING) != 0
				var row_gliding := (under_way & Busy.ROW_GLIDING) != 0
				var consoles_gliding := (under_way & Busy.CONSOLES_GLIDING) != 0
				var flying := launching or tossing
				var holding := holder == Holder.CAROUSEL
				var shown := holder in SHOWN
				var expected: Dictionary[Take, bool] = {
					Take.PRESS: holding and screen in WHOLE and not flying,
					Take.FINGER: holding and (screen in WHOLE or screen == Screen.PROPERTIES) and not (flying or searching),
					Take.LIBRARY: holding and screen in WHOLE and not (flying or searching or row_gliding or consoles_gliding),
					Take.CONSOLE_STICK: shown and screen in [Screen.CONSOLES, Screen.CONSOLE_EDIT],
					Take.PICK: shown and screen == Screen.GAMES and not (row_gliding or searching or tossing),
					Take.SHELF: screen == Screen.CONSOLES and not consoles_gliding,
					Take.REST: screen not in [Screen.ENTERING, Screen.LEAVING] and not flying,
				}
				var taken := CarouselState.takes(screen, holder, under_way)
				for take: Take in expected:
					if ((taken & take) != 0) != expected[take]:
						wrong.append("%s under %s with %d under way: %s" % [Screen.keys()[screen], Holder.keys()[holder],
							under_way, Take.find_key(take)])
	assert_array(wrong).is_empty()


func test_what_is_under_way_and_what_is_known_are_told_flag_by_flag_whatever_else_is() -> void:
	for under_way in 32:
		assert_int(CarouselState.busy((under_way & Busy.LAUNCHING) != 0, (under_way & Busy.TOSSING) != 0,
			(under_way & Busy.SEARCHING) != 0, (under_way & Busy.ROW_GLIDING) != 0,
			(under_way & Busy.CONSOLES_GLIDING) != 0)).is_equal(under_way)
	for known in EVERY_FACT:
		assert_int(CarouselState.facts((known & Fact.HAS_GAMES) != 0, (known & Fact.RIBBON_OPEN) != 0,
			(known & Fact.FILTERED) != 0, (known & Fact.MOVED) != 0, (known & Fact.HELD) != 0, (known & Fact.UP_HELD) != 0,
			(known & Fact.BALL_OPEN) != 0, (known & Fact.SEVERAL) != 0)).is_equal(known)


func test_the_carousel_shows_under_the_holders_that_let_the_stick_turn_the_console_and_no_other() -> void:
	for holder: Holder in Holder.values():
		assert_bool(CarouselState.shows(holder)).is_equal(holder in SHOWN)
		assert_bool((CarouselState.takes(Screen.CONSOLES, holder, 0) & Take.CONSOLE_STICK) != 0).is_equal(holder in SHOWN)


func test_what_stands_in_front_agrees_with_what_each_screen_takes() -> void:
	for screen: Screen in Screen.values():
		var taken := CarouselState.takes(screen, Holder.CAROUSEL, 0)
		var front := CarouselState.front(screen)
		var named: String = Screen.keys()[screen]
		assert_bool(front == Front.CONSOLES).override_failure_message(named).is_equal((taken & Take.CONSOLE_STICK) != 0)
		assert_bool(front == Front.MOVING).override_failure_message(named).is_equal((taken & Take.REST) == 0)
		if (taken & Take.PICK) != 0 or taken == (Take.FINGER | Take.REST):
			assert_bool(front == Front.GAMES).override_failure_message(named).is_true()
		if front == Front.GAMES:
			assert_int(taken & (Take.CONSOLE_STICK | Take.SHELF)).override_failure_message(named).is_equal(0)


func test_the_consoles_stand_in_front_on_their_screen_and_their_edit_and_the_games_on_theirs_and_their_properties() -> void:
	for screen: Screen in Screen.values():
		var named: String = Screen.keys()[screen]
		assert_bool(CarouselState.front(screen) == Front.CONSOLES).override_failure_message(named) \
			.is_equal(screen in [Screen.CONSOLES, Screen.CONSOLE_EDIT])
		assert_bool(CarouselState.front(screen) == Front.GAMES).override_failure_message(named) \
			.is_equal(screen in [Screen.GAMES, Screen.PROPERTIES])


func test_every_screen_leads_somewhere_is_reached_from_the_consoles_and_a_move_between_the_two_has_one_end() -> void:
	var screens: Array = Screen.values()
	var reached: Array[Screen] = [Screen.CONSOLES]
	var at := 0
	while at < reached.size():
		for next: Screen in screens:
			if CarouselState.follows(reached[at], next) and next not in reached:
				reached.append(next)
		at += 1
	assert_int(reached.size()).is_equal(screens.size())
	for screen: Screen in screens:
		assert_array(_after(screen)).override_failure_message("%s leads nowhere" % Screen.keys()[screen]).is_not_empty()
		assert_bool(CarouselState.follows(screen, screen)).is_false()
	assert_array(_after(Screen.CONSOLES)).is_equal([Screen.ENTERING, Screen.CONSOLE_EDIT, Screen.ORDER])
	assert_array(_after(Screen.GAMES)).is_equal([Screen.CONSOLES, Screen.LEAVING, Screen.PROPERTIES])
	assert_array(_after(Screen.ENTERING)).is_equal([Screen.GAMES])
	assert_array(_after(Screen.LEAVING)).is_equal([Screen.CONSOLES])
	for back: Screen in [Screen.PROPERTIES, Screen.CONSOLE_EDIT, Screen.ORDER]:
		assert_int(_after(back).size()).is_equal(1)
		var came_from: Screen = _after(back)[0]
		assert_bool(CarouselState.follows(came_from, back)).is_true()


func test_no_press_means_anything_for_an_echo_while_the_carousel_takes_none_with_no_game_or_off_its_two_screens() -> void:
	var echo := InputEventKey.new()
	echo.pressed = true
	echo.echo = true
	var wrong: Array[String] = []
	for screen: Screen in Screen.values():
		for known in EVERY_FACT:
			if CarouselState.command(screen, Take.PRESS, known, echo) != Command.NONE:
				wrong.append("an echo on %s knowing %d" % [Screen.keys()[screen], known])
			for event in _events():
				var none_taken := CarouselState.command(screen, Take.FINGER | Take.LIBRARY, known, event)
				var no_game := CarouselState.command(screen, Take.PRESS, known & ~Fact.HAS_GAMES, event)
				var elsewhere := CarouselState.command(screen, Take.PRESS, known, event)
				if none_taken != Command.NONE or no_game != Command.NONE or (screen not in WHOLE and elsewhere != Command.NONE):
					wrong.append("%s on %s knowing %d" % [event.as_text(), Screen.keys()[screen], known])
	assert_array(wrong).is_empty()


func test_every_event_is_the_ribbon_s_while_it_is_open_on_the_games_and_never_on_the_consoles() -> void:
	var wrong: Array[String] = []
	for known in EVERY_FACT:
		if (known & Fact.HAS_GAMES) == 0 or (known & Fact.RIBBON_OPEN) == 0:
			continue
		for event in _events():
			if CarouselState.command(Screen.GAMES, Take.PRESS, known, event) != Command.TO_SEARCH \
					or CarouselState.command(Screen.CONSOLES, Take.PRESS, known, event) == Command.TO_SEARCH:
				wrong.append("%s knowing %d" % [event.as_text(), known])
	assert_array(wrong).is_empty()


func test_only_A_on_the_games_launches_and_a_button_let_go_does_nothing_but_let_go_of_up_or_of_a_direction() -> void:
	var wrong: Array[String] = []
	var let_go_of: Array[Command] = [Command.NONE, Command.TO_SEARCH, Command.STEP_CONSOLE, Command.HOLD_ROW,
		Command.RELEASE_ROW, Command.OPEN_BALL, Command.CLOSE_BALL]
	for screen: Screen in WHOLE:
		for known in EVERY_FACT:
			for event in _events():
				var meant := CarouselState.command(screen, Take.PRESS, known, event)
				var a_on_the_games := screen == Screen.GAMES and event.is_action_pressed(&"ui_accept") \
					and (known & (Fact.MOVED | Fact.RIBBON_OPEN)) == 0 and (known & Fact.HAS_GAMES) != 0
				if (meant == Command.LAUNCH) != a_on_the_games or (not event.is_pressed() and meant not in let_go_of):
					wrong.append("%s on %s knowing %d: %s" % [event.as_text(), Screen.keys()[screen], known,
						Command.keys()[meant]])
	assert_array(wrong).is_empty()


func test_each_button_means_what_its_screen_says_and_the_first_rule_that_matches_wins() -> void:
	var games := Fact.HAS_GAMES
	var several := Fact.HAS_GAMES | Fact.SEVERAL
	var held := Fact.MOVED | Fact.HELD
	# screen, action, pressed, what is known, the command.
	var cases: Array[Array] = [
		[Screen.CONSOLES, &"ui_accept", true, games, Command.ENTER],
		[Screen.CONSOLES, &"ui_accept", true, games | Fact.BALL_OPEN, Command.ADD_CONSOLE],
		[Screen.CONSOLES, &"open_properties", true, games, Command.EDIT_CONSOLE],
		[Screen.CONSOLES, &"open_settings", true, games, Command.SETTINGS],
		[Screen.CONSOLES, &"ui_down", true, several, Command.ORDER],
		[Screen.CONSOLES, &"ui_down", true, games, Command.NONE],
		[Screen.CONSOLES, &"ui_up", true, games | Fact.UP_HELD, Command.OPEN_BALL],
		[Screen.CONSOLES, &"ui_up", false, games, Command.CLOSE_BALL],
		[Screen.CONSOLES, &"ui_up", false, games | Fact.UP_HELD, Command.OPEN_BALL],
		[Screen.CONSOLES, &"carousel_right", true, games | held, Command.STEP_CONSOLE],
		[Screen.CONSOLES, &"carousel_right", false, games | Fact.MOVED, Command.NONE],
		[Screen.CONSOLES, &"screen_back", true, several, Command.NONE],
		[Screen.GAMES, &"ui_accept", true, games, Command.LAUNCH],
		[Screen.GAMES, &"screen_back", true, games, Command.LEAVE],
		[Screen.GAMES, &"screen_back", true, games | Fact.FILTERED, Command.CLEAR_FILTER],
		[Screen.GAMES, &"open_properties", true, games, Command.PROPERTIES],
		[Screen.GAMES, &"open_settings", true, games, Command.SETTINGS],
		[Screen.GAMES, &"ui_up", true, games | Fact.UP_HELD, Command.TOSS],
		[Screen.GAMES, &"ui_down", true, games, Command.OPEN_SEARCH],
		[Screen.GAMES, &"carousel_left", true, games | held, Command.HOLD_ROW],
		[Screen.GAMES, &"carousel_left", false, games | Fact.MOVED, Command.RELEASE_ROW],
		[Screen.GAMES, &"ui_accept", false, games, Command.NONE],
		# The order of the rules.
		[Screen.GAMES, &"open_settings", true, games | Fact.RIBBON_OPEN, Command.TO_SEARCH],
		[Screen.CONSOLES, &"ui_accept", true, games | Fact.RIBBON_OPEN, Command.ENTER],
		[Screen.CONSOLES, &"open_settings", true, games | held, Command.SETTINGS],
		[Screen.CONSOLES, &"ui_accept", true, games | held, Command.STEP_CONSOLE],
		[Screen.CONSOLES, &"ui_up", true, games | held | Fact.UP_HELD, Command.STEP_CONSOLE],
		[Screen.CONSOLES, &"ui_up", true, games | Fact.MOVED | Fact.UP_HELD, Command.OPEN_BALL],
		[Screen.GAMES, &"open_settings", true, games | held, Command.SETTINGS],
		[Screen.GAMES, &"ui_accept", true, games | Fact.MOVED, Command.RELEASE_ROW],
	]
	for row in cases:
		var screen: Screen = row[0]
		var action: StringName = row[1]
		var pressed: bool = row[2]
		var known: int = row[3]
		var expected: Command = row[4]
		assert_int(CarouselState.command(screen, Take.PRESS, known, _event(action, pressed))) \
			.override_failure_message("%s %s on %s knowing %d is not %s" % [action, "pressed" if pressed else "let go",
				Screen.keys()[screen], known, Command.keys()[expected]]).is_equal(expected)


## The screens that may follow [param screen].
func _after(screen: Screen) -> Array:
	return Screen.values().filter(func(next: Screen) -> bool: return CarouselState.follows(screen, next))


## Every action of [constant ACTIONS], pressed then let go.
func _events() -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	for action in ACTIONS:
		for pressed: bool in [true, false]:
			events.append(_event(action, pressed))
	return events


func _event(action: StringName, pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	return event
