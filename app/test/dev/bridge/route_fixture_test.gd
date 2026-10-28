# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Fixture := preload("res://dev/bridge/route_fixture.gd")


func test_the_adding_preview_uses_only_supported_models_and_never_calls_a_plugin() -> void:
	var fixture: AndroidServices = auto_free(Fixture.new())
	assert_bool(fixture.is_available()).is_true()
	var initial := await fixture.library()
	assert_bool(initial.ok).is_true()
	assert_array(initial.library.shelves.map(func(shelf: AndroidServices.Shelf) -> String: return shelf.platform_id)).contains_exactly(["gc", "gba"])
	assert_int(fixture.installed_players("ps2").size()).is_equal(1)
	assert_bool(fixture.installed_players("gc").is_empty()).is_true()
	var scanned := await fixture.scan_platform("ps2")
	assert_bool(scanned.ok).is_true()
	assert_int(scanned.library.shelves.size()).is_equal(3)
	assert_int((await fixture.library()).library.shelves.size()).is_equal(3)


func test_the_real_bridge_reaches_the_form_type_emulator_and_placing_start_from_its_routes() -> void:
	var tree := get_tree()
	var previous := tree.current_scene
	var initial := preload("res://carousel/carousel.tscn").instantiate() as Carousel
	(initial.get_node("%Screens") as ScreenFlow).welcome_waits = false
	tree.root.add_child(initial)
	tree.current_scene = initial
	var commands := preload("res://dev/bridge/commands.gd").new()
	tree.root.add_child(commands)
	var form: Array = [{"library": "adding", "locale": "fr"}, {"push": "ui_up", "wait": 25},
		{"press": "ui_accept", "wait": 35}, {"release": "ui_up"}]
	var answer := await commands.run({"cmd": "go", "route": form})
	assert_bool(answer["ok"]).is_true()
	var carousel := tree.current_scene as Carousel
	var shown: AddConsole = carousel._screens.get_node("AddConsole")
	assert_bool(shown.visible).is_true()
	var choose_type := form.duplicate(true)
	choose_type.append({"press": "ui_accept"})
	answer = await commands.run({"cmd": "go", "route": choose_type})
	assert_bool(answer["ok"]).is_true()
	carousel = tree.current_scene as Carousel
	shown = carousel._screens.get_node("AddConsole")
	assert_bool(shown._choice.visible).is_true()
	var filled := choose_type.duplicate(true)
	for i in 10:
		filled.append({"press": "ui_down"})
	filled.append_array([{"press": "ui_accept"}, {"press": "ui_down"}, {"press": "ui_accept"}])
	answer = await commands.run({"cmd": "go", "route": filled})
	assert_bool(answer["ok"]).is_true()
	carousel = tree.current_scene as Carousel
	shown = carousel._screens.get_node("AddConsole")
	assert_bool(shown._choice.visible).is_true()
	assert_bool(shown._choice._is_type).is_false()
	filled.append_array([{"press": "ui_accept"}, {"press": "ui_down"}, {"press": "ui_accept"}, {"press": "ui_accept"}])
	answer = await commands.run({"cmd": "go", "route": filled})
	assert_bool(answer["ok"]).is_true()
	carousel = tree.current_scene as Carousel
	assert_bool(carousel._order._placing != null).is_true()
	answer = await commands.run({"cmd": "go", "route": [{"library": "adding"}, {"push": "ui_up", "hold": true, "keep": true, "wait": 0}]})
	assert_bool(answer["ok"]).is_true()
	carousel = tree.current_scene as Carousel
	assert_bool(Input.is_action_pressed(&"ui_up")).is_true()
	await commands.run({"cmd": "step", "frames": 25})
	assert_bool(carousel._add_ball.is_open).is_true()
	assert_float(carousel._add_ball._opened).is_greater(0.8)
	await commands.run({"cmd": "tune", "target": "input", "values": {"action": "ui_up", "pressed": false}})
	assert_bool(Input.is_action_pressed(&"ui_up")).is_false()
	await commands.run({"cmd": "resume"})
	commands.free()
	tree.current_scene = previous
	carousel.free()
	TranslationServer.set_locale("en")
	await await_idle_frame()
