# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## What the views' tests and their scene share.


## The value [param property] of the node [param node_name] in the scene at [param path], read without
## running it; none when the scene does not set it.
static func property(path: String, node_name: StringName, property_name: StringName) -> Variant:
	var state := (load(path) as PackedScene).get_state()
	for node in state.get_node_count():
		if state.get_node_name(node) == node_name:
			for i in state.get_node_property_count(node):
				if state.get_node_property_name(node, i) == property_name:
					return state.get_node_property_value(node, i)
	return null


## The carousel's own environment.
static func app_environment() -> Environment:
	return property("res://carousel/carousel.tscn", &"Environment", &"environment")
