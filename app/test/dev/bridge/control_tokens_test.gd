# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite

const Views := preload("res://dev/bridge/views.gd")


func test_screen_tokens_leave_the_current_picture_unmodified_until_a_value_is_saved() -> void:
	assert_dict(StudioTokens.CONTROL_EDITS).is_empty()
	assert_dict(StudioTokens.CONTROL_STYLES).is_empty()


func test_a_saved_rectangle_is_restored_after_layout_without_affecting_its_neighbour() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	var edited := Control.new()
	var neighbour := Control.new()
	root.add_child(edited)
	root.add_child(neighbour)
	neighbour.position = Vector2(17.0, 23.0)
	var values := {"rect": [30.0, 40.0, 150.0, 80.0]}
	ControlTokens.apply(edited, values)
	assert_vector(edited.global_position).is_equal(Vector2(30.0, 40.0))
	edited.position = Vector2.ZERO
	ControlTokens.place(edited, values)
	assert_vector(edited.global_position).is_equal(Vector2(30.0, 40.0))
	assert_vector(neighbour.position).is_equal(Vector2(17.0, 23.0))


func test_the_saved_satin_colour_and_radius_survive_a_gel_repaint() -> void:
	var panel: SatinPanel = auto_free(SatinPanel.new())
	add_child(panel)
	ControlTokens.apply(panel, {"colour": [0.1, 0.4, 0.7, 1.0], "corner_radius": 23.0})
	panel.gel = Color.RED
	assert_int(panel._backing._material.get_shader_parameter(&"stop_count")).is_equal(1)
	assert_float(panel._backing._material.get_shader_parameter(&"radius")).is_equal(23.0)
	var colours: Array = panel._backing._material.get_shader_parameter(&"colors")
	assert_vector(colours[0]).is_equal_approx(Vector4(0.1, 0.4, 0.7, 1.0), Vector4.ONE * 0.001)


func test_a_refused_control_batch_leaves_every_control_unchanged() -> void:
	var views: Views = auto_free(Views.new())
	var root: Control = auto_free(Control.new())
	add_child(root)
	var first := Control.new()
	var second := Control.new()
	root.add_child(first)
	root.add_child(second)
	first.position = Vector2(12.0, 20.0)
	var answer: Dictionary = views.tune(root, {"target": "controls", "values": {
		str(first.get_path()): {"position": [40.0, 50.0]}, str(second.get_path()): {"size": ["bad", 2.0]}}})
	assert_bool(answer["ok"]).is_false()
	assert_vector(first.position).is_equal(Vector2(12.0, 20.0))
	assert_vector(second.size).is_equal(Vector2.ZERO)


func test_control_reset_restores_the_original_gradient_font_and_shared_style() -> void:
	var views: Views = auto_free(Views.new())
	var root: Control = auto_free(Control.new())
	add_child(root)
	var panel := SatinPanel.new()
	root.add_child(panel)
	var stops: Array = panel._backing._material.get_shader_parameter(&"colors")
	var count: int = panel._backing._material.get_shader_parameter(&"stop_count")
	var text := Label.new()
	text.text = "A label"
	text.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	root.add_child(text)
	views.tune(root, {"target": "control", "path": str(panel.get_path()), "values": {"colour": [0.8, 0.1, 0.2, 1.0], "corner_radius": 40.0}})
	views.tune(root, {"target": "control", "path": str(text.get_path()), "values": {"text_colour": [0.8, 0.1, 0.2, 1.0], "font_size": 42, "text": "Changed"}})
	views.tune(root, {"target": "controls", "values": {str(panel.get_path()): {"reset": true}, str(text.get_path()): {"reset": true}}})
	assert_int(panel._backing._material.get_shader_parameter(&"stop_count")).is_equal(count)
	assert_array(panel._backing._material.get_shader_parameter(&"colors")).is_equal(stops)
	assert_bool(panel._backing._tuning.is_empty()).is_true()
	assert_bool(text.has_theme_font_size_override(&"font_size")).is_false()
	assert_bool(text.has_theme_color_override(&"font_color")).is_false()
	assert_bool(text.has_meta(&"studio_text_colour")).is_false()
	assert_str(text.text).is_equal("A label")


func test_a_saved_edit_does_not_overwrite_a_later_tween() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	root.name = "ControlHost"
	var tokens := ControlTokens.new()
	tokens.edits = {"tween_test": {"match": "Target$", "position": [20.0, 30.0]}}
	root.add_child(tokens)
	var target := Control.new()
	target.name = "Target"
	root.add_child(target)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(target.position).is_equal(Vector2(20, 30))
	var tween := target.create_tween()
	tween.tween_property(target, ^"position", Vector2(200, 300), 0.03)
	await tween.finished
	await get_tree().create_timer(0.1).timeout
	assert_vector(target.position).is_equal_approx(Vector2(200, 300), Vector2.ONE * 0.01)


func test_a_saved_edit_does_not_target_an_automatically_named_control() -> void:
	var root: Control = auto_free(Control.new())
	add_child(root)
	root.name = "ControlHost"
	var tokens := ControlTokens.new()
	tokens.edits = {"auto_test": {"match": "@Control@", "position": [20.0, 30.0]}}
	root.add_child(tokens)
	var target := Control.new()
	root.add_child(target)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(target.position).is_equal(Vector2.ZERO)


func test_a_resized_control_does_not_fight_its_size_tween() -> void:
	var root: Control = auto_free(Control.new())
	root.name = "ControlHost"
	add_child(root)
	var tokens := ControlTokens.new()
	tokens.edits = {"size_test": {"match": "Target$", "size": [100.0, 100.0]}}
	root.add_child(tokens)
	var target := Control.new()
	target.name = "Target"
	root.add_child(target)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(target.size).is_equal(Vector2(100, 100))
	var tween := target.create_tween()
	tween.tween_property(target, ^"size", Vector2(200, 300), 0.1)
	await tween.finished
	await get_tree().create_timer(0.1).timeout
	assert_vector(target.size).is_equal_approx(Vector2(200, 300), Vector2.ONE * 0.01)


func test_a_control_freed_before_deferred_discovery_causes_no_error() -> void:
	var root: Control = auto_free(Control.new())
	root.name = "ControlHost"
	add_child(root)
	var tokens := ControlTokens.new()
	tokens.edits = {"one": {"match": "Target$", "position": [20.0, 30.0]}}
	root.add_child(tokens)
	var target := Control.new()
	target.name = "Target"
	root.add_child(target)
	target.free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(root.get_child_count()).is_equal(1)


func test_a_resize_during_an_unrelated_tween_is_applied_after_it_finishes() -> void:
	var root: Control = auto_free(Control.new())
	root.name = "ControlHost"
	add_child(root)
	var tokens := ControlTokens.new()
	tokens.edits = {"one": {"match": "Target$", "size": [100.0, 100.0]}}
	root.add_child(tokens)
	var target := Control.new()
	target.name = "Target"
	root.add_child(target)
	var other := Control.new()
	other.name = "Other"
	root.add_child(other)
	await get_tree().process_frame
	await get_tree().process_frame
	var tween := other.create_tween()
	tween.tween_property(other, ^"position", Vector2(20, 30), 0.1)
	target.size = Vector2(200, 200)
	await tween.finished
	await get_tree().process_frame
	await get_tree().process_frame
	assert_vector(target.size).is_equal(Vector2(100, 100))


func test_reset_of_the_last_text_style_restores_the_unedited_draw_path() -> void:
	var views: Views = auto_free(Views.new())
	var root: Control = auto_free(Control.new())
	root.name = "ControlHost"
	add_child(root)
	var label := Label.new()
	label.name = "Label"
	root.add_child(label)
	views.tune(root, {"target": "control", "path": str(label.get_path()), "values": {"font_size": 30}})
	assert_bool(ControlTokens.has_text_edits()).is_true()
	views.tune(root, {"target": "control", "path": str(label.get_path()), "values": {"reset": true}})
	assert_bool(ControlTokens.has_text_edits()).is_false()
