# SPDX-License-Identifier: GPL-3.0-or-later
extends GdUnitTestSuite
## The Famicom cartridge's own looks: its label's recess closed all round on its front, its foot
## narrower than its shoulders, the foot's end open over the connector.

const Fixtures := preload("res://test/carousel/fixtures.gd")
const SHAPES := 40
const EPSILON := 0.001
const FAR := 1000.0


func test_impossible_famicom_cart_dimensions_are_refused_by_the_rule_they_break_and_build_nothing() -> void:
	var random := Fixtures.cases(110)
	var breaks: Array[Array] = [
		[&"sizes_positive", func(cart: FamicomCartShape) -> void: cart.recess = 0.0],
		[&"bevel_fits", func(cart: FamicomCartShape) -> void: cart.bevel = cart.corner],
		[&"bevel_fits", func(cart: FamicomCartShape) -> void: cart.recess = cart.depth - 2.0 * cart.bevel],
		[&"foot_fits", func(cart: FamicomCartShape) -> void: cart.foot.x = cart.width],
		[&"foot_fits", func(cart: FamicomCartShape) -> void: cart.opening.y = cart.depth],
		[&"label_on_body", func(cart: FamicomCartShape) -> void: cart.label_centre.y = cart.body().position.y],
		[&"label_on_body", func(cart: FamicomCartShape) -> void: cart.label_corner = cart.label_size.y / 2.0],
		[&"label_over_straight_edges", func(cart: FamicomCartShape) -> void: cart.label_centre.x = cart.foot.x / 2.0],
	]
	var shapes := Fixtures.accepted(self, SHAPES, _cart.bind(random))
	for i in shapes.size():
		Fixtures.assert_refused(self, shapes[i], breaks[i % breaks.size()])


func test_the_label_s_recess_is_closed_all_round_by_the_front_s_face() -> void:
	var random := Fixtures.cases(111)
	for shape: FamicomCartShape in Fixtures.accepted(self, SHAPES, _cart.bind(random)):
		var detail := random.randi_range(16, 64)
		var shell := shape.mesh_arrays(&"shell", detail)
		var label := shape.label_box()
		var front := shape.depth / 2.0
		var on_label := label.position + label.size * Vector2(0.43, 0.61)
		assert_float(Fixtures.hit(shape.mesh_arrays(&"label", detail), Vector3(on_label.x, on_label.y, FAR),
			Vector3.FORWARD).z).is_equal_approx(front - shape.recess, EPSILON)
		# Just past each side of the recess, the face.
		var past := FamicomCartShape.RIM / 2.0
		for beside: Vector2 in [Vector2(label.position.x - past, on_label.y), Vector2(label.end.x + past, on_label.y),
				Vector2(on_label.x, label.position.y - past), Vector2(on_label.x, label.end.y + past)]:
			assert_float(Fixtures.hit(shell, Vector3(beside.x, beside.y, FAR), Vector3.FORWARD).z) \
				.is_equal_approx(front, EPSILON)


func test_the_foot_is_narrower_than_the_shoulders_and_its_end_open() -> void:
	var random := Fixtures.cases(112)
	for shape: FamicomCartShape in Fixtures.accepted(self, SHAPES, _cart.bind(random)):
		var detail := random.randi_range(16, 64)
		var shell := shape.mesh_arrays(&"shell", detail)
		var bottom := -shape.height / 2.0
		var foot := Fixtures.hit(shell, Vector3(FAR, bottom + shape.foot.y / 2.0, 0.0), Vector3.LEFT)
		assert_float(foot.x).is_equal_approx(shape.foot.x / 2.0, EPSILON)
		var body := Fixtures.hit(shell, Vector3(FAR, shape.body().get_center().y, 0.0), Vector3.LEFT)
		assert_float(body.x).is_equal_approx(shape.width / 2.0, EPSILON)
		var dark := shape.mesh_arrays(&"opening", detail)
		var end := Fixtures.hit(dark, Vector3(0.13 * shape.opening.x, -FAR, 0.07 * shape.opening.y), Vector3.UP)
		assert_float(end.y).is_less(bottom)
		assert_bool(Fixtures.hit(dark, Vector3(shape.opening.x / 2.0 + EPSILON, -FAR, 0.0), Vector3.UP) \
			.is_finite()).is_false()


## A cartridge [param random] draws around the shipped one, its rules accepting it.
static func _cart(random: RandomNumberGenerator) -> FamicomCartShape:
	return Fixtures.drawn_around(FamicomCartShape.new(), random, Vector2(0.85, 1.15), 0, 0.5)
