# SPDX-License-Identifier: GPL-3.0-or-later
class_name PerfBench
extends Node3D
## A row of lit, floating, turning boxes: the shape of the carousel's rendering load.

const BOX_COUNT := 40

var _time := 0.0
var _boxes: Array[MeshInstance3D] = []

@onready var _row: Node3D = %Boxes


func _ready() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 0.9, 0.2)
	for i in BOX_COUNT:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color.from_hsv(float(i) / BOX_COUNT, 0.5, 0.9)
		material.roughness = 0.4
		material.metallic = 0.2 if i % 3 == 0 else 0.0
		var box := MeshInstance3D.new()
		box.mesh = mesh
		box.material_override = material
		box.position = Vector3((i - BOX_COUNT / 2.0) * 0.5, 0.0, -float(i % 5))
		_row.add_child(box)
		_boxes.append(box)


func _process(delta: float) -> void:
	_time += delta
	for i in _boxes.size():
		var box := _boxes[i]
		box.rotation.y = sin(_time * 0.8 + i) * 0.6
		box.position.y = sin(_time * 1.5 + i * 0.4) * 0.15
