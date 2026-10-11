# SPDX-License-Identifier: GPL-3.0-or-later
@tool
class_name XboxShape
extends ModelShape
## The dimensions of the Xbox (2001), a tray-loading console, in millimetres, as it lies on a table:
## its top up (+Y), its front towards +Z (see [XboxGeometry]). Heights are from the table. A rounded
## body in three layers: the lower one, the strip across the front (recessed, the disc tray set in
## its left half) and the upper one; on it, the raised X reaching the four corners, the jewel at its
## crossing; between its arms, ribbed fins at the sides and sloping facets at the front and back;
## grilles on both sides. Plan positions are X to the right and Y towards the back, from the centre
## of the body.

@export var width := 320.0:
	set(value):
		width = value
		emit_changed()
@export var depth := 260.0:
	set(value):
		depth = value
		emit_changed()
@export var corner := 12.0:
	set(value):
		corner = value
		emit_changed()
@export var bevel := 2.5:
	set(value):
		bevel = value
		emit_changed()
## The body's underside, on its feet.
@export var foot_height := 4.0:
	set(value):
		foot_height = value
		emit_changed()
## Where the strip starts and ends, the top of the upper layer, and the top of the X.
@export var strip_bottom := 51.0:
	set(value):
		strip_bottom = value
		emit_changed()
@export var strip_top := 66.0:
	set(value):
		strip_top = value
		emit_changed()
@export var lip_top := 77.0:
	set(value):
		lip_top = value
		emit_changed()
@export var cross_top := 87.5:
	set(value):
		cross_top = value
		emit_changed()
## How far the strip is set back from the layers above and below it.
@export var strip_recess := 1.5:
	set(value):
		strip_recess = value
		emit_changed()
## The fins between the X's arms at each side: where they start and end along Y, at the side; how
## far from the centre the X's arms let them reach (X), and at what Y.
@export var side_wedge := Vector2(-86.0, 75.0):
	set(value):
		side_wedge = value
		emit_changed()
@export var side_wedge_apex := Vector2(68.0, 0.0):
	set(value):
		side_wedge_apex = value
		emit_changed()
## The facets between the X's arms at the front and back: their width at the edge, and how far
## they reach in from the front edge, then from the back edge.
@export var end_wedges := Vector3(64.0, 40.0, 38.0):
	set(value):
		end_wedges = value
		emit_changed()
@export var fin_pitch := 6.2:
	set(value):
		fin_pitch = value
		emit_changed()
## The jewel's dome, the dark ring around it, and how far the dome rises above the X.
@export var jewel_radius := 34.0:
	set(value):
		jewel_radius = value
		emit_changed()
@export var ring_radius := 42.0:
	set(value):
		ring_radius = value
		emit_changed()
@export var jewel_rise := 3.5:
	set(value):
		jewel_rise = value
		emit_changed()
## The tray's front, from its left edge to its right one (X).
@export var tray_span := Vector2(-128.0, 0.0):
	set(value):
		tray_span = value
		emit_changed()
@export var bezel_thickness := 5.0:
	set(value):
		bezel_thickness = value
		emit_changed()
## The discs the tray takes.
@export var disc_radius := 60.0:
	set(value):
		disc_radius = value
		emit_changed()
## Each side's grille, centred along it: its length, and from how high to how high it goes.
@export var grille_length := 204.0:
	set(value):
		grille_length = value
		emit_changed()
@export var grille_levels := Vector2(10.0, 68.0):
	set(value):
		grille_levels = value
		emit_changed()
@export var grille_pitch := 10.2:
	set(value):
		grille_pitch = value
		emit_changed()

## The gap around the tray in its slot; the tray's plate, above the slot's floor and its thickness;
## and the room left between the disc and the bezel.
const TRAY_GAP := 0.5
const PLATE_ABOVE := 1.5
const PLATE_THICKNESS := 4.0
const DISC_ROOM := 3.0
## The vents' floor drawn just above what it lies on, which it would fight; half a DVD's thickness.
const VENTS_RAISE := 0.05
const DISC_HALF_THICKNESS := 0.6
## The front's middle panel, its width and how far it stands out; the height the buttons and ports
## on the front reach, below the strip (see [XboxGeometry]).
const MODULE_SIZE := Vector2(66.0, 1.0)
const FRONT_TOP := 44.0
## The eject and power buttons on the front's middle panel, each its centre (X, height) and radius;
## how far they stand out of the panel.
const EJECT := Vector3(0.0, 34.0, 9.0)
const POWER := Vector3(0.0, 15.0, 5.0)
const BUTTON_RAISE := 0.5
## Each fin's and grille bar's share of its pitch; how far the grilles stand out of the sides.
const FIN_SHARE := 0.4
const BAR_SHARE := 0.25
const GRILLE_RAISE := 1.6


func parts() -> Array[StringName]:
	return XboxGeometry.PARTS


func surfaces() -> Array[StringName]:
	var flat: Array[StringName] = [&"vents", &"tray_window", &"drive_opening"]
	flat.append_array(XboxGeometry.LOGOS.keys())
	return flat


func body() -> Rect2:
	return Rect2(-width / 2.0, -depth / 2.0, width, depth)


## The strip's outline, set back all around.
func strip() -> Rect2:
	return body().grow(-strip_recess)


## The bezel, closing the tray's slot in the strip's front, at rest.
func bezel() -> Rect2:
	return Rect2(tray_span.x, strip().position.y, tray_span.y - tray_span.x, bezel_thickness)


## The plate behind the bezel, the disc lying in its recess near its front, part of it still in the
## slot once the tray is out; at rest.
func plate() -> Rect2:
	var length := 2.0 * (disc_radius + DISC_ROOM) + 20.0
	return Rect2(tray_span.x + 1.0, bezel().end.y, tray_span.y - tray_span.x - 2.0, length)


## Where the tray goes through the strip, open at the front.
func slot() -> Rect2:
	var tray := bezel().merge(plate()).grow(TRAY_GAP)
	return tray.grow_side(SIDE_TOP, strip_recess + 1.0)


## The front's middle panel, in plan.
func module() -> Rect2:
	return Rect2(-MODULE_SIZE.x / 2.0, body().position.y - MODULE_SIZE.y, MODULE_SIZE.x, 2.0 * MODULE_SIZE.y)


## The centre of the disc lying on the plate, at rest.
func disc_centre() -> Vector2:
	return Vector2(plate().get_center().x, plate().position.y + DISC_ROOM + disc_radius)


## How far the tray slides out: enough for its disc to clear the front, by a few millimetres.
func tray_travel() -> float:
	return disc_centre().y + depth / 2.0 + disc_radius + 3.0


## The plate's height, between the slot's floor and its roof.
func plate_levels() -> Vector2:
	return Vector2(strip_bottom + PLATE_ABOVE, strip_bottom + PLATE_ABOVE + PLATE_THICKNESS)


## The wedges between the X's arms, each a triangle in plan: the back, left, front and right ones,
## in the order the body's outline meets them, counter-clockwise.
func wedges() -> Array[PackedVector2Array]:
	var half := body().size / 2.0
	var across := end_wedges.x / 2.0
	var apex := side_wedge_apex
	return [
		PackedVector2Array([Vector2(across, half.y), Vector2(0.0, half.y - end_wedges.z), Vector2(-across, half.y)]),
		PackedVector2Array([Vector2(-half.x, side_wedge.y), Vector2(-apex.x, apex.y), Vector2(-half.x, side_wedge.x)]),
		PackedVector2Array([Vector2(-across, -half.y), Vector2(0.0, end_wedges.y - half.y), Vector2(across, -half.y)]),
		PackedVector2Array([Vector2(half.x, side_wedge.x), Vector2(apex.x, apex.y), Vector2(half.x, side_wedge.y)]),
	]


## The fins of the side wedges, in plan: from the side to a millimetre short of the X's arms, as
## many as the wedge holds; none shorter than two millimetres.
func fins() -> Array[Rect2]:
	var found: Array[Rect2] = []
	var span := side_wedge.y - side_wedge.x
	var count := floori(span / fin_pitch)
	var thick := fin_pitch * FIN_SHARE
	var reach := width / 2.0 - side_wedge_apex.x
	var outer := width / 2.0 - bevel
	for i in count:
		var y := side_wedge.x + (span - count * fin_pitch) / 2.0 + (i + 0.5) * fin_pitch
		# Short of the arm at both its edges.
		var inner := 0.0
		for edge: float in [y - thick / 2.0, y + thick / 2.0]:
			var end := side_wedge.x if edge < side_wedge_apex.y else side_wedge.y
			inner = maxf(inner, width / 2.0 - reach * (edge - end) / (side_wedge_apex.y - end) + 1.0)
		if outer - inner > 2.0:
			for side: float in [-1.0, 1.0]:
				var x := minf(side * inner, side * outer)
				found.append(Rect2(x, y - thick / 2.0, outer - inner, thick))
	return found


## Each side's grille, in its plane (Y along the side, up from the table).
func side_grille() -> Rect2:
	return Rect2(-grille_length / 2.0, grille_levels.x, grille_length, grille_levels.y - grille_levels.x)


## The bars of each side's grille, in its plane (Y along the side, up from the table): upright
## ones, and one across its middle.
func grille_bars() -> Array[Rect2]:
	var bar := grille_pitch * BAR_SHARE
	var grille := side_grille()
	var found: Array[Rect2] = [Rect2(grille.position.x, grille.get_center().y - bar / 2.0, grille.size.x, bar)]
	var count := floori(grille.size.x / grille_pitch)
	var start := grille.get_center().x - count * grille_pitch / 2.0
	for i in count + 1:
		found.append(Rect2(start + i * grille_pitch - bar / 2.0, grille.position.y, bar, grille.size.y))
	return found


## Where the tray's disc lies, in the model's space, the tray slid [param travel_mm] out: on its
## recess's floor, its axis (Z) up, its label too.
func seat(travel_mm: float) -> Transform3D:
	var centre := disc_centre()
	var height := DiscTray.floor_level(plate_levels().y) + DISC_HALF_THICKNESS
	var at := Vector3(centre.x, height, -centre.y + travel_mm) * MeshBuilder.UNITS_PER_MM
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), at)


func _arrays(part: StringName, detail: int) -> Array:
	return XboxGeometry.arrays(self, part, detail)


func _rules() -> Dictionary[StringName, bool]:
	var straight := body().grow(-corner - 0.1)
	var slot_back := slot().end.y
	return {
		&"sizes_positive": width > 0.0 and depth > 0.0 and disc_radius > 0.0 and bezel_thickness > 0.0
			and fin_pitch > 0.0 and grille_pitch > 0.0 and jewel_rise > 0.0,
		&"corner_rounds_the_bevel": bevel > 0.0 and corner > bevel + 0.1 and corner < minf(width, depth) / 2.0 - 0.1,
		&"layers_rise_holding_their_bevels": foot_height > 0.0 and strip_bottom - foot_height > 2.0 * bevel + 0.1
			and lip_top - strip_top > 2.0 * bevel + 0.1 and cross_top - lip_top > 2.0
			and strip_bottom > FRONT_TOP + 1.0,
		&"strip_recessed": strip_recess > 0.1 and strip_recess < corner - 0.1,
		&"wedges_on_the_straight_sides": side_wedge.x > straight.position.y and side_wedge.y < straight.end.y
			and end_wedges.x / 2.0 < straight.end.x and side_wedge_apex.x > 0.1
			and side_wedge_apex.x < width / 2.0 - 0.1 and side_wedge_apex.y > side_wedge.x + 0.1
			and side_wedge_apex.y < side_wedge.y - 0.1 and end_wedges.x > 0.1 and end_wedges.y > 0.1
			and end_wedges.z > 0.1,
		&"wedges_apart": _apart(wedges()),
		# A fin or more, laid out only once their pitch is known to be no hair.
		&"fins_in_the_side_wedges": fin_pitch > 1.0 and not fins().is_empty(),
		&"jewel_on_the_crossing": jewel_radius > 0.1 and jewel_radius < ring_radius - 1.0
			and wedges().all(func(wedge: PackedVector2Array) -> bool: return _clear_of(wedge, ring_radius + 1.0)),
		&"tray_in_its_slot": tray_span.x > straight.position.x and tray_span.y < straight.end.x
			and slot_back < body().end.y - corner and strip_top - strip_bottom > 2.0 * TRAY_GAP + PLATE_ABOVE
			+ PLATE_THICKNESS + 2.0,
		# Its logo too, which comes out with it.
		&"logo_on_the_bezel": strip_top - strip_bottom - 2.0 * TRAY_GAP > XboxGeometry.LOGOS[&"bezel_logo"].y + 1.0
			and bezel().size.x > XboxGeometry.LOGOS[&"bezel_logo"].x + 10.0,
		&"disc_fits_the_tray": DiscTray.fits(plate(), plate_levels(), disc_centre(), disc_radius),
		&"grilles_on_the_sides": grille_length / 2.0 < straight.end.y and grille_length > grille_pitch
			and grille_levels.x > foot_height + bevel and grille_levels.y < lip_top - bevel
			and grille_levels.y - grille_levels.x > 2.0 * grille_pitch * BAR_SHARE,
	}


## Whether no two of [param triangles] overlap.
static func _apart(triangles: Array[PackedVector2Array]) -> bool:
	for i in triangles.size():
		for j in range(i + 1, triangles.size()):
			if not Geometry2D.intersect_polygons(triangles[i], triangles[j]).is_empty():
				return false
	return true


## Whether [param triangle] keeps at least [param reach] from the centre.
static func _clear_of(triangle: PackedVector2Array, reach: float) -> bool:
	if Geometry2D.is_point_in_polygon(Vector2.ZERO, triangle):
		return false
	for i in 3:
		var nearest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, triangle[i], triangle[(i + 1) % 3])
		if nearest.length() < reach:
			return false
	return true
