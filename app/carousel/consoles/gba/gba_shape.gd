# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name GbaShape
extends ModelShape
## The dimensions of the Game Boy Advance, a landscape handheld, in millimetres, as it stands: its
## screen towards +Z, its top edge up (+Y), X to the right, from the centre of its outline (see
## [GbaGeometry]). Two shells meet at a seam: their outline is flat along the middle of the top,
## drops at the shoulders, rounds at the ends and bows down along the bottom. A hump stands out of
## the back, deepest at its top, where the cartridge slot opens: it stops the cartridge's head below
## the shells' top, so that the seated cartridge's head, standing on it, fills the step up to their
## top line and is all that shows of the cartridge from behind. Grey parts cover the back shell's
## edge at each end, flush with the outline, so that the front hides them: the L or R button over
## the top corner, the panel under it down the end and round the bottom corner. The controls lie on
## the front face, placed from the end of their side (`x` from that end, `y` from the centre); the
## power switch, the volume wheel and the headphone jack lie along the bottom, the link port along
## the top.

## The seam's groove, as wide as deep; the round of the shells' back edges.
const SEAM_GROOVE := 0.4
const BACK_BEVEL := 1.5
## How far along the top the shoulders' drop runs before it eases off, and the share of the drop it
## takes there.
const SHOULDER_RUN := 14.0
const SHOULDER_SHARE := 0.75
## The hump's corners, the round of its edges, and how far above the bottom it stops.
const HUMP_CORNER := 6.0
const HUMP_BEVEL := 2.5
const HUMP_GAP := 0.5
## How the bottom bows: flatter in the middle than a parabola.
const BELLY_POWER := 2.3
## The screen's lens and its corners, bottom and top; the plate with the maker's name above it.
const BEZEL_CORNERS := Vector2(11.0, 5.0)
const BEZEL_CENTRE := Vector2(0.0, -1.0)
const SCREEN_CENTRE := Vector2(0.0, 4.2)
const LOGO := Vector2(18.7, 4.2)
const LOGO_BELOW_TOP := 5.3
## The controls, from the end of their side: the D-pad and its span and arms; A, B, and their
## diameter; Start, Select below it, their diameter and the slanted plates beside them; the power
## light; the speaker's slits.
const DPAD := Vector2(17.65, 6.4)
const DPAD_SPAN := 19.2
const DPAD_ARM := 6.5
const BUTTON_A := Vector2(11.25, 8.4)
const BUTTON_B := Vector2(24.35, 3.7)
const BUTTON := 9.2
const START := Vector2(27.25, -13.2)
const SELECT_BELOW := 8.2
const SMALL_BUTTON := 4.4
const PLATE := Vector2(12.0, 4.5)
const PLATE_FROM_BUTTON := Vector2(-8.4, 1.3)
const PLATE_DEGREES := -22.0
const LED := Vector2(24.35, 26.2)
const LED_SIZE := 2.6
const SPEAKER := Vector2(21.25, -16.7)
const SLITS := 6
const SLIT := Vector2(15.0, 1.3)
const SLIT_PITCH := 2.9
const SLIT_DEGREES := 12.0
## How far the keys stand out of the face.
const KEY_HEIGHT := 2.5
## Along the bottom: the power switch's recess and its knob, and the margin left at each end; the
## volume wheel's slot; the headphone jack. Each from the end of its side.
const SWITCH_FROM_END := 20.65
const SWITCH_RECESS := Vector2(12.8, 3.4)
const SWITCH_KNOB := Vector2(6.0, 2.4)
const SWITCH_MARGIN := 0.5
const VOLUME_FROM_END := 15.85
const VOLUME := Vector2(11.0, 3.4)
const JACK_FROM_END := 28.35
const JACK := 3.6
## The link port on the top, right of the middle.
const LINK_X := 7.0
const LINK := Vector2(8.0, 3.0)
## The connector at the slot's foot, in from the slot's walls by this.
const CONNECTOR_PLAY := 0.3
## How far the cartridge's head stands out of its body on its label's side, to the back: the
## cartridge is centred on its body, so it is seated half that nearer the face, all of it in the slot.
const CARTRIDGE_HEAD := 2.65
## Each shoulder button: how far along the top it runs from the end, and down the end from its top;
## the gap between it and the panel under it. How far the grey parts reach into the shells from the
## outline: past the round of the back's edge, they show on the back as a thin band.
const SHOULDER_LENGTH := 24.2
const SHOULDER_DROP := 15.5
const PANEL_GAP := 2.0
const GREY_DEPTH := 2.5
## The least room between two points of an outline, where a screw's column crosses it.
const _APART := 0.3
## On the hump's back, from the centre as seen from behind: the battery cover, its corners, how far
## it stands out, its parting gap; its latch's tongue up the middle of its top, how wide and how far
## up, the notch sunk under it; the panel sunk in it with the moulded words' image, its corners, how
## deep they are sunk. The sticker above it, its notch round the latch.
const BATTERY_COVER := Rect2(-35.85, -34.0, 71.7, 40.3)
const COVER_CORNER := 3.0
const COVER_RAISE := 0.4
const COVER_GAP := 0.4
const LATCH := Vector2(14.0, 4.5)
const LATCH_NOTCH := Rect2(-5.0, 2.6, 10.0, 2.2)
const PANEL := Rect2(-19.4, -21.0, 38.8, 11.9)
const PANEL_CORNER := 1.0
const PANEL_SINK := 0.25
const COVER_MARK := Vector2(36.0, 7.4)
const LABEL := Rect2(-36.7, 8.2, 73.4, 14.5)
## The screws in the shells' back: the upper ones', the lower ones', each from its end and below the
## top; their holes' radius and depth, their heads' radius and height.
const SCREWS: Array[Vector2] = [Vector2(24.45, 12.3), Vector2(5.3, 58.2)]
const SCREW_RADIUS := 2.3
const SCREW_SINK := 2.5
const SCREW_HEAD := Vector2(1.8, 0.8)
## The marks printed and moulded on the front, by part: the size of each one's image (the folder's
## gba_<part>.svg), the Start and Select ones along their plates. The logo is on the lens.
const MARKS: Dictionary[StringName, Vector2] = {
	&"lens_logo": Vector2(42.0, 4.8), &"nintendo": Vector2(17.2, 2.6), &"power_label": Vector2(9.4, 3.0),
	&"start_label": Vector2(8.6, 3.2), &"select_label": Vector2(8.6, 3.2), &"a_label": Vector2(4.2, 4.2),
	&"b_label": Vector2(4.2, 4.2),
}
## Where the marks' centres are: the logo over the lens's bottom, the power light's from the light,
## the Start and Select ones along their plates, towards the buttons.
const LOGO_OVER_BEZEL := 7.75
const POWER_FROM_LED := Vector2(7.8, 0.05)
const LABEL_ALONG_PLATE := 0.6

## The outline, grey ends included.
@export var width := 144.5:
	set(value):
		width = value
		emit_changed()
@export var height := 82.0:
	set(value):
		height = value
		emit_changed()
## From the face to the back of the hump, at the slot.
@export var depth := 25.0:
	set(value):
		depth = value
		emit_changed()
## Both shells, at their edges; the front one alone.
@export var body_depth := 14.0:
	set(value):
		body_depth = value
		emit_changed()
@export var front_depth := 7.0:
	set(value):
		front_depth = value
		emit_changed()
## The round of the ends' corners, and of the face's edge.
@export var corner := 9.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 3.0:
	set(value):
		bevel = value
		emit_changed()
## Where the top's flat middle ends, from the centre, and how far the top drops by the ends.
@export var shoulder := Vector2(33.0, 10.0):
	set(value):
		shoulder = value
		emit_changed()
## How far the bottom rises from its middle to the ends' corners.
@export var belly := 11.5:
	set(value):
		belly = value
		emit_changed()
## The hump's width, and its depth from the face at its bottom.
@export var hump_width := 84.0:
	set(value):
		hump_width = value
		emit_changed()
@export var hump_depth := 20.5:
	set(value):
		hump_depth = value
		emit_changed()
@export var bezel_size := Vector2(76.0, 62.5):
	set(value):
		bezel_size = value
		emit_changed()
@export var screen_size := Vector2(61.2, 40.8):
	set(value):
		screen_size = value
		emit_changed()
## The slot's opening along the top. Across, it runs from the hump's rounded back edge, the wall
## behind it, to the shells' back, its front wall.
@export var slot_width := 62.0:
	set(value):
		slot_width = value
		emit_changed()
## The cartridge the slot takes, its width, height and thickness: it goes all the way in, its top
## level with the console's.
@export var cartridge := Vector3(57.5, 33.0, 7.9):
	set(value):
		cartridge = value
		emit_changed()
## How far down the cartridge's head reaches from its top: it stays above the slot.
@export var cartridge_head := 6.7:
	set(value):
		cartridge_head = value
		emit_changed()


func parts() -> Array[StringName]:
	return GbaGeometry.PARTS


func surfaces() -> Array[StringName]:
	var found: Array[StringName] = [&"screen", &"wells", &"link_port", &"bottom_ports", &"label", &"cover_mark"]
	found.append_array(MARKS.keys())
	return found


func half() -> float:
	return width / 2.0


## The face, the back of the shells, the seam's middle and the back of the hump at the top, as Z.
func face() -> float:
	return depth / 2.0


func back() -> float:
	return face() - body_depth


func seam() -> float:
	return face() - front_depth


func hump_back() -> float:
	return face() - depth


## The hump's top, the slot's opening, the seated cartridge's head standing on it.
func hump_top() -> float:
	return height / 2.0 - cartridge_head


## How far forward the hump's back comes for each millimetre down from its top.
func hump_lean() -> float:
	return (depth - hump_depth) / (hump_top() + height / 2.0 - HUMP_GAP)


## The outline's top at [param x], within the ends' corners.
func top_at(x: float) -> float:
	var along := absf(x) - shoulder.x
	if along <= 0.0:
		return height / 2.0
	if along < SHOULDER_RUN:
		return height / 2.0 - SHOULDER_SHARE * shoulder.y * (1.0 - cos(PI * along / SHOULDER_RUN)) / 2.0
	var rest := (along - SHOULDER_RUN) / (half() - corner - shoulder.x - SHOULDER_RUN)
	return height / 2.0 - shoulder.y * (SHOULDER_SHARE + (1.0 - SHOULDER_SHARE) * minf(rest, 1.0))


## The outline's bottom at [param x], and how steep it is there.
func bottom_at(x: float) -> float:
	return -height / 2.0 + belly * pow(absf(x) / (half() - corner), BELLY_POWER)


func bottom_slope(x: float) -> float:
	var reach := half() - corner
	return signf(x) * BELLY_POWER * belly * pow(absf(x) / reach, BELLY_POWER - 1.0) / reach


## The outline [param inset] inwards, counter-clockwise: its top and bottom follow [method top_at]
## and [method bottom_at] (the bottom [param bottom_gap] higher) out to [param reach] from the
## centre, where corners of [param rounding] join them to straight ends. [param steps] per corner,
## four times as many along the top and the bottom.
func outline(reach: float, rounding: float, inset: float, bottom_gap: float, steps: int,
		stops := PackedFloat32Array(), lowest_top := INF) -> PackedVector2Array:
	return _inset(_outline_points(reach, rounding, bottom_gap, steps, stops, lowest_top), inset)


## The grey part at the right end, [param inset] inwards, as a line along the outline,
## counter-clockwise: the shoulder button (`button`) from its foot on the end over the top corner to
## its inner end on the top, or the panel from the bottom, round the corner, up the end to its top.
## The same [param steps] give as many points at any inset.
func grey_end(button: bool, inset: float, steps: int) -> PackedVector2Array:
	var inner_end := half() - SHOULDER_LENGTH
	var points := ShapeGeometry.crossed(_outline_points(half(), corner, 0.0, steps), inner_end)
	# The end runs straight from the last point of the lower corner (index `steps`) up to the upper one.
	var split := top_at(half()) - SHOULDER_DROP
	for y: float in [split + PANEL_GAP / 2.0, split - PANEL_GAP / 2.0]:
		points.insert(steps + 1, Vector2(points[steps].x, y))
	var top := ShapeGeometry.cuts(points, inner_end)[1]
	var moved := _inset(points, inset)
	return ShapeGeometry.between(moved, steps + 2, top) if button else ShapeGeometry.between(moved, 0, steps + 1)


## The outline's points before any inset, counter-clockwise from the bottom of the right end's
## lower corner (see [method outline]); the top has one at each of [param stops] and their mirrors
## (within the corners), where something on it starts or ends; the top no higher than
## [param lowest_top].
func _outline_points(reach: float, rounding: float, bottom_gap: float, steps: int,
		stops := PackedFloat32Array(), lowest_top := INF) -> PackedVector2Array:
	var points := PackedVector2Array()
	var inner := reach - rounding
	var edge := 4 * steps
	var top_corners := minf(top_at(inner), lowest_top) - rounding
	var corners: Array[Vector2] = [Vector2(inner, bottom_at(inner) + bottom_gap + rounding),
		Vector2(inner, top_corners), Vector2(-inner, top_corners),
		Vector2(-inner, bottom_at(inner) + bottom_gap + rounding)]
	for quarter in 4:
		for step in steps + 1:
			var angle := PI / 2.0 * (quarter - 1 + float(step) / steps)
			points.append(corners[quarter] + Vector2.from_angle(angle) * rounding)
		if quarter % 2 == 1:
			var top := quarter == 1
			var along := PackedFloat32Array()
			for i in range(1, edge):
				along.append(inner * (1.0 - 2.0 * i / edge) * (1.0 if top else -1.0))
			if top:
				# Each stop takes the place of the point nearest it: two points a hair apart would fold
				# the outline as it is inset.
				for stop in stops:
					for x: float in [stop, -stop]:
						along[clampi(roundi((1.0 - x / inner) * edge / 2.0) - 1, 0, along.size() - 1)] = x
			for x in along:
				points.append(Vector2(x, minf(top_at(x), lowest_top) if top else bottom_at(x) + bottom_gap))
	return points


## The shells' outline [param inset] inwards, with a point where their back's face, inside its round
## edge, crosses each of the screws' columns (see [method screws]): as far along its side as that
## point is along the face's, so that no outline folds, however far in. A point that would land
## within [constant _APART] of one of its side's ends takes that end's place, no sliver between them.
func body_outline(inset: float, steps: int) -> PackedVector2Array:
	var points := _outline_points(half(), corner, 0.0, steps)
	var at_back := _inset(points, BACK_BEVEL)
	var found := _inset(points, inset)
	# From the last side, so that the indexes of the sides still to cross stay where they were.
	for i in range(points.size() - 1, -1, -1):
		var next := (i + 1) % points.size()
		for x in screw_lines():
			if (at_back[i].x - x) * (at_back[next].x - x) >= 0.0:
				continue
			var share := (x - at_back[i].x) / (at_back[next].x - at_back[i].x)
			var at := found[i].lerp(found[next], share)
			var side := at_back[i].distance_to(at_back[next])
			if share * side < _APART:
				found[i] = at
			elif (1.0 - share) * side < _APART:
				found[next] = at
			else:
				found.insert(i + 1, at)
	return found


## The screws' centres in the shells' back, the same seen from behind, and their columns, from the
## left.
func screws() -> PackedVector2Array:
	var found := PackedVector2Array()
	for screw in SCREWS:
		var x := half() - screw.x
		found.append_array([Vector2(-x, height / 2.0 - screw.y), Vector2(x, height / 2.0 - screw.y)])
	return found


func screw_lines() -> PackedFloat32Array:
	var lines := PackedFloat32Array()
	for screw in screws():
		lines.append(screw.x)
	lines.sort()
	return lines


## The battery cover's outline, its latch's tongue up the middle of its top, [param margin] outside
## it, counter-clockwise from the bottom left, with a point on the middle line.
func cover(margin: float, steps: int) -> PackedVector2Array:
	var box := BATTERY_COVER.grow(margin)
	var tongue := Rect2(-LATCH.x / 2.0 - margin, box.end.y, LATCH.x + 2.0 * margin, LATCH.y)
	var convex := COVER_CORNER + margin
	var tip := 1.0 + margin
	var concave := 1.0 - margin
	return ShapeGeometry.crossed(ShapeGeometry.filleted(PackedVector2Array([box.position,
			Vector2(box.end.x, box.position.y), box.end, Vector2(tongue.end.x, box.end.y), tongue.end,
			Vector2(tongue.position.x, tongue.end.y), tongue.position, Vector2(box.position.x, box.end.y)]),
		PackedFloat32Array([convex, convex, convex, concave, tip, tip, concave, convex]), steps), 0.0)


## The front face's flat part, inside the round of its edge.
func flat_face(steps: int) -> PackedVector2Array:
	return outline(half(), corner, bevel, 0.0, steps)


## The place of a control [param from_end] its side's end (`right`) or the left one's.
func on_face(from_end: Vector2, right: bool) -> Vector2:
	return Vector2((half() - from_end.x) * (1.0 if right else -1.0), from_end.y)


func bezel() -> Rect2:
	return ShapeGeometry.centred(BEZEL_CENTRE, bezel_size)


func screen() -> Rect2:
	return ShapeGeometry.centred(SCREEN_CENTRE, screen_size)


func logo() -> Rect2:
	return Rect2(Vector2(-LOGO.x / 2.0, height / 2.0 - LOGO_BELOW_TOP - LOGO.y / 2.0), LOGO)


## Each round control's box: A, B, Start, Select and the power light.
func round_controls() -> Array[Rect2]:
	var select := START - Vector2(0.0, SELECT_BELOW)
	return [ShapeGeometry.square_around(on_face(BUTTON_A, true), BUTTON / 2.0),
		ShapeGeometry.square_around(on_face(BUTTON_B, true), BUTTON / 2.0),
		ShapeGeometry.square_around(on_face(START, false), SMALL_BUTTON / 2.0),
		ShapeGeometry.square_around(on_face(select, false), SMALL_BUTTON / 2.0),
		ShapeGeometry.square_around(on_face(LED, true), LED_SIZE / 2.0)]


## The slanted plates beside Start and Select, as outlines.
func plates(steps: int) -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	var pill := ShapeGeometry.rounded_box(Rect2(-PLATE / 2.0, PLATE), PLATE.y / 2.0 - 0.01, steps)
	for below: float in [0.0, SELECT_BELOW]:
		found.append(_plate(below) * pill)
	return found


## Where the mark [param part] lies on the front: its centre, turned along its plate for Start's and
## Select's.
func mark(part: StringName) -> Transform2D:
	var controls := round_controls()
	match part:
		&"lens_logo":
			return Transform2D(0.0, Vector2(bezel().get_center().x, bezel().position.y + LOGO_OVER_BEZEL))
		&"nintendo":
			return Transform2D(0.0, logo().get_center())
		&"power_label":
			return Transform2D(0.0, controls[4].get_center() + POWER_FROM_LED)
		&"start_label", &"select_label":
			return _plate(0.0 if part == &"start_label" else SELECT_BELOW) * Transform2D(0.0,
				Vector2(LABEL_ALONG_PLATE, 0.0))
	return Transform2D(0.0, controls[0 if part == &"a_label" else 1].get_center())


func slits() -> Array[PackedVector2Array]:
	var found: Array[PackedVector2Array] = []
	var centre := on_face(SPEAKER, true)
	for i in SLITS:
		var at := centre + Vector2(0.0, (0.5 * (SLITS - 1) - i) * SLIT_PITCH)
		found.append(Transform2D(deg_to_rad(SLIT_DEGREES), at) * ShapeGeometry.square(Rect2(-SLIT / 2.0, SLIT)))
	return found


## The D-pad's two bars, across and upright.
func dpad_bars() -> Array[Rect2]:
	var centre := on_face(DPAD, false)
	return [ShapeGeometry.centred(centre, Vector2(DPAD_SPAN, DPAD_ARM)),
		ShapeGeometry.centred(centre, Vector2(DPAD_ARM, DPAD_SPAN))]


## The slot's opening on the top, in plan: X across, Y towards the back.
func slot() -> Rect2:
	return Rect2(-slot_width / 2.0, -back(), slot_width, back() - hump_back() - HUMP_BEVEL)


## The foot of the slot, under the connector.
func slot_floor() -> float:
	return height / 2.0 - cartridge.y - ShapeGeometry.CONNECTOR_HEIGHT


## The connector at the slot's foot, in plan.
func connector() -> Rect2:
	return slot().grow(-CONNECTOR_PLAY)


## The link port's opening on the top, in plan, on the front shell.
func link_port() -> Rect2:
	var centre := Vector2(LINK_X, -(seam() + SEAM_GROOVE + face() - bevel) / 2.0)
	return ShapeGeometry.centred(centre, LINK)


## Where a seated cartridge stands, in the model's space: down in the slot, its label to the back.
func seat() -> Transform3D:
	var centre := Vector3(0.0, height / 2.0 - cartridge.y / 2.0,
		-slot().get_center().y + CARTRIDGE_HEAD / 2.0)
	return Transform3D(Basis(Vector3.UP, PI), centre * MeshBuilder.UNITS_PER_MM)


## The power switch's recess, the volume wheel's slot and the headphone jack, each as its frame on
## the bottom and its outline in it.
func bottom_ports(steps: int) -> Array[Array]:
	var pill := func(size: Vector2) -> PackedVector2Array:
		return ShapeGeometry.rounded_box(Rect2(-size / 2.0, size), minf(size.x, size.y) / 2.0 - 0.01, steps)
	return [[_bottom(-(half() - SWITCH_FROM_END)), pill.call(SWITCH_RECESS)],
		[_bottom(half() - VOLUME_FROM_END), pill.call(VOLUME)],
		[_bottom(half() - JACK_FROM_END), pill.call(Vector2.ONE * JACK)]]


## Where the power switch's knob stands off, in the model's space: at the end of its recess
## towards the console's end, sliding along the bottom towards the middle to come on.
func switch_rest() -> Transform3D:
	var frame := _bottom(-(half() - SWITCH_FROM_END))
	var at := frame * Vector3(-switch_travel() / 2.0, 0.0, 0.0)
	return Transform3D(frame.basis, at * MeshBuilder.UNITS_PER_MM)


func switch_travel() -> float:
	return SWITCH_RECESS.x - SWITCH_KNOB.x - 2.0 * SWITCH_MARGIN


## The frame of the hump's back, in the model's space, its middle at the height of the centre: X to
## the right as seen from behind, Y up along it, Z out of it.
func back_frame() -> Transform3D:
	var up := Vector3(0.0, 1.0, -hump_lean()).normalized()
	return Transform3D(Basis(Vector3.LEFT, up, Vector3.LEFT.cross(up)),
		Vector3(0.0, 0.0, hump_back() + hump_lean() * hump_top()) * MeshBuilder.UNITS_PER_MM)


## Where the shoulder button on the right (`right`) or the left turns, in the model's space: the foot
## of its inner end, so that its outer end goes down when pressed.
func shoulder_pivot(right: bool) -> Vector3:
	var foot := grey_end(true, GREY_DEPTH, 3)[-1]
	return Vector3(foot.x * (1.0 if right else -1.0), foot.y, (back() + seam()) / 2.0) * MeshBuilder.UNITS_PER_MM


func _arrays(part: StringName, detail: int) -> Array:
	return GbaGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var steps := 3
	var flat := flat_face(steps)
	var lens := bezel()
	var controls: Array[Rect2] = round_controls()
	controls.append_array(dpad_bars())
	for loop: PackedVector2Array in plates(steps) + slits():
		controls.append(ShapeGeometry.bounds(loop))
	var controls_fit := controls.all(func(control: Rect2) -> bool:
		return ShapeGeometry.inside(ShapeGeometry.square(control), flat) \
			and not ShapeGeometry.overlap(control, lens.grow(1.0)))
	var hump_back_face := outline(hump_width / 2.0, HUMP_CORNER, HUMP_BEVEL, HUMP_GAP, steps, [], hump_top())
	var deepest := maxf(maxf(bevel, BACK_BEVEL), GREY_DEPTH)
	var split := top_at(half()) - SHOULDER_DROP
	return {
		&"sizes_positive": width > 0.0 and height > 0.0 and depth > 0.0 and front_depth > 0.0
			and shoulder.x > 0.0 and shoulder.y > 0.0 and belly >= 0.0 and bevel > 0.0
			and cartridge.x > 0.0 and cartridge.y > 0.0 and cartridge.z > 0.0 and cartridge_head > 0.0,
		# Each inset outline is a simple loop: the corners and the shoulders' hollows are rounder
		# than the deepest inset.
		&"outline_holds_its_edges": corner > deepest + 0.5
			and pow(SHOULDER_RUN / PI, 2.0) / (SHOULDER_SHARE / 2.0 * shoulder.y) > deepest + 0.5
			and half() - corner - shoulder.x - SHOULDER_RUN > 1.0
			and belly + shoulder.y + 2.0 * corner < height - 2.0,
		&"shells_in_depth": front_depth - SEAM_GROOVE > bevel + 0.1
			and body_depth - front_depth - SEAM_GROOVE > BACK_BEVEL + 0.1,
		&"hump_on_the_back": hump_depth > body_depth + 1.0 and hump_depth < depth
			and depth - body_depth + BACK_BEVEL > HUMP_BEVEL + 0.1
			and hump_width / 2.0 < half() - corner - 1.0 and hump_width > 2.0 * HUMP_CORNER + 1.0
			and hump_top() - HUMP_CORNER > bottom_at(hump_width / 2.0) + HUMP_GAP + HUMP_CORNER + 1.0,
		&"bezel_on_the_face": ShapeGeometry.inside(ShapeGeometry.rounded(lens.grow(1.0), BEZEL_CORNERS.x + 1.0,
			BEZEL_CORNERS.y + 1.0, steps), flat),
		&"screen_in_the_bezel": ShapeGeometry.within(screen(), lens.grow(-1.5)),
		&"logo_above_the_bezel": ShapeGeometry.inside(ShapeGeometry.square(logo()), flat)
			and not ShapeGeometry.overlap(logo().grow(1.0), lens),
		&"controls_on_the_face": controls_fit,
		&"slot_in_the_hump_top": slot_width / 2.0 + 1.0 < minf(shoulder.x, hump_width / 2.0 - HUMP_CORNER),
		&"slot_takes_the_cartridge": slot_width > cartridge.x + 2.0 and slot().size.y > cartridge.z + 0.4,
		# Its body goes down the slot to the connector, its head stays above: the slot's back wall
		# keeps inside the hump as the hump's back leans forward down the console, and its foot above
		# the hump's bottom.
		&"cartridge_stands_in_the_slot": cartridge_head < cartridge.y / 2.0
			and hump_lean() * (hump_top() - slot_floor()) < HUMP_BEVEL - 0.3
			and slot_floor() > bottom_at(slot_width / 2.0) + HUMP_GAP + 1.0
			and ShapeGeometry.holds_connector(connector()),
		&"ports_on_the_bottom": corner + 0.5 < minf(SWITCH_FROM_END - SWITCH_RECESS.x / 2.0,
				VOLUME_FROM_END - VOLUME.x / 2.0)
			and seam() - SEAM_GROOVE - back() - BACK_BEVEL > maxf(JACK, SWITCH_RECESS.y) + 0.2,
		&"link_port_on_the_top": LINK_X + LINK.x / 2.0 + 1.0 < shoulder.x
			and face() - bevel - seam() - SEAM_GROOVE > LINK.y + 0.2,
		&"cover_and_label_on_the_back": ShapeGeometry.inside(cover(0.0, steps), hump_back_face)
			and ShapeGeometry.inside(ShapeGeometry.square(LABEL.grow(1.0)), hump_back_face)
			and not LABEL.intersects(BATTERY_COVER),
		&"screws_in_the_back": _screws_fit(steps),
		# The shoulder button ends on the top between the hump and the corner, and its gap with the
		# panel lies on the straight of the end.
		&"grey_ends_fit": hump_width / 2.0 + 1.0 < half() - SHOULDER_LENGTH and corner + 1.0 < SHOULDER_LENGTH
			and split - PANEL_GAP / 2.0 > bottom_at(half() - corner) + corner + 0.5
			and split + PANEL_GAP / 2.0 < top_at(half()) - corner - 0.5,
	}


## Whether each screw's hole lies on the back's face, clear of the hump and of the grey parts' band.
func _screws_fit(steps: int) -> bool:
	var clear := outline(half() - GREY_DEPTH, corner - GREY_DEPTH, 0.0, 0.0, steps)
	var on_back := outline(half(), corner, BACK_BEVEL, 0.0, steps)
	for screw in screws():
		var hole := ShapeGeometry.circle(screw, SCREW_RADIUS + 0.3, 16)
		if not ShapeGeometry.inside(hole, clear) or not ShapeGeometry.inside(hole, on_back) \
				or absf(screw.x) - SCREW_RADIUS < hump_width / 2.0 + 1.0:
			return false
	return true


## [param points] moved [param inset] inwards, along each point's normal.
static func _inset(points: PackedVector2Array, inset: float) -> PackedVector2Array:
	if inset == 0.0:
		return points
	var moved := PackedVector2Array()
	var count := points.size()
	for i in count:
		var along := points[(i + 1) % count] - points[i - 1]
		moved.append(points[i] - Vector2(along.y, -along.x).normalized() * inset)
	return moved


## The frame of the bottom at [param x], in the middle of the back shell's flat part, where the
## ports lie: X along the bottom, Y towards the face, Z out of the console.
func _bottom(x: float) -> Transform3D:
	var along := Vector3(1.0, bottom_slope(x), 0.0).normalized()
	var depth_in := (back() + BACK_BEVEL + seam() - SEAM_GROOVE) / 2.0
	return Transform3D(Basis(along, Vector3.BACK, along.cross(Vector3.BACK)), Vector3(x, bottom_at(x), depth_in))


## The frame of the plate [param below] Start's: its centre, turned as it slants.
func _plate(below: float) -> Transform2D:
	return Transform2D(deg_to_rad(PLATE_DEGREES), on_face(START + PLATE_FROM_BUTTON - Vector2(0.0, below), false))
