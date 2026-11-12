# SPDX-License-Identifier: GPL-3.0-or-later
class_name PlinthBake
extends Node
## Draws every console's plinth pictures ([constant Plinth.PICTURES]) into its folder, then quits: started with
## `--bake-plinths` by `scripts/bake_plinths.sh`. Each model stands in a view of its own world, lit and framed as
## [method Plinth.build_view] sets it, in the room of the running app, at the default edge smoothing.


func _ready() -> void:
	for console in ConsoleManifest.found():
		var folder := ConsoleManifest.folder_of(console)
		for times: float in Plinth.PICTURES:
			var rig := Plinth.build_view(folder, load(console.scene) as PackedScene, self, self)
			rig.view.size = Vector2i((StudioTokens.TURNTABLE.size * times).ceil())
			rig.view.render_target_update_mode = SubViewport.UPDATE_ONCE
			# The view's canvas is empty: clearing to nothing gives the same picture without copying it in.
			rig.environment.environment.background_mode = Environment.BG_CLEAR_COLOR
			await RenderingServer.frame_post_draw
			var path := ProjectSettings.globalize_path(Plinth.picture_of(folder, times))
			var saved := rig.view.get_texture().get_image().save_png(path)
			print("plinth picture of %s at %s: %s" % [folder, times, "written" if saved == OK else "not written (%d)" % saved])
			rig.view.queue_free()
			await get_tree().process_frame
	get_tree().quit()
