# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted
## A headless run has no renderer: [method install] puts a blank picture, drawn a frame later, where a
## console's still would be rendered, [method restore] puts the real drawing back.


static func install() -> void:
	if DisplayServer.get_name() == "headless":
		Plinth._drawer = func(_folder: String) -> ImageTexture:
			await (Engine.get_main_loop() as SceneTree).process_frame
			return ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))


static func restore() -> void:
	Plinth._drawer = Plinth._render
