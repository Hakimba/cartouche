# SPDX-License-Identifier: GPL-3.0-or-later
class_name StageLens
extends RefCounted
## The cameras that draw the frame's 3D. The carousel's camera is set out for the 4:3 frame (its field of view spans
## the frame's height); on another screen its frustum is shifted and scaled so that the frame's 3D stands where the
## [ScreenLayout] lays the stage, the same at every depth. The cameras that draw a part of that picture again (a blur
## behind the games, a sticker, one medium, the ring's console) copy it or narrow it to their part, through here only.


## Sets [param camera] to show the frame drawn with [param design_fov] (its field of view on the 4:3 frame) on the
## stage of [param layout].
static func aim(camera: Camera3D, design_fov: float, layout: ScreenLayout) -> void:
	var frame := CarouselLayout.FRAME
	# One px of the screen, on the near plane: the frame's height there spans 960 px of the frame.
	var per_px := 2.0 * camera.near * tan(deg_to_rad(design_fov) / 2.0) / frame.y
	var shift := layout.on_stage(frame / 2.0) - layout.size / 2.0
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.set_frustum(layout.size.y * per_px, Vector2(-shift.x, shift.y) * per_px, camera.near, camera.far)


## Sets [param lens] to see what [param camera] sees, from where it stands.
static func copy(camera: Camera3D, lens: Camera3D) -> void:
	lens.global_transform = camera.global_transform
	lens.keep_aspect = camera.keep_aspect
	lens.set_frustum(camera.size, camera.frustum_offset, camera.near, camera.far)
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		lens.set_perspective(camera.fov, camera.near, camera.far)


## Sets [param lens] to see the part [param seen] (px of [param camera]'s screen) of what [param camera] sees, whole
## in its own view: a view drawn over that part of the screen matches the picture under it.
static func narrow(camera: Camera3D, lens: Camera3D, seen: Rect2) -> void:
	var top_left := camera.to_local(camera.project_position(seen.position, camera.near))
	var bottom_right := camera.to_local(camera.project_position(seen.end, camera.near))
	lens.global_transform = camera.global_transform
	lens.keep_aspect = Camera3D.KEEP_HEIGHT
	lens.set_frustum(top_left.y - bottom_right.y, Vector2(top_left.x + bottom_right.x, top_left.y + bottom_right.y) / 2.0,
		camera.near, camera.far)
