# SPDX-License-Identifier: GPL-3.0-or-later
class_name Still
extends Texture2DRD
## A still picture of what a view drew, held on the graphics card alone and freed with this texture.


## The picture [param view] drew, taken once its frame is drawn (after `RenderingServer.frame_post_draw`); none when
## it drew nothing. Copied on the graphics card where the renderer has a device of its own: reading the pixels back
## would stall the frame until the GPU has drawn them, the copy needs no wait. Read back where it has none (the
## Compatibility renderer of the web export and of older desktops).
static func of(view: SubViewport) -> Texture2D:
	var device := RenderingServer.get_rendering_device()
	if not device:
		var image := view.get_texture().get_image()
		return ImageTexture.create_from_image(image) if image and not image.is_empty() else null
	var source := RenderingServer.texture_get_rd_texture(view.get_texture().get_rid())
	if not source.is_valid():
		return null
	var format := device.texture_get_format(source)
	format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT \
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var copy := device.texture_create(format, RDTextureView.new())
	device.texture_copy(source, copy, Vector3.ZERO, Vector3.ZERO, Vector3(format.width, format.height, 1), 0, 0, 0, 0)
	var still := Still.new()
	still.texture_rd_rid = copy
	return still


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and texture_rd_rid.is_valid():
		var held := texture_rd_rid
		texture_rd_rid = RID()
		var device := RenderingServer.get_rendering_device()
		if device:
			device.free_rid(held)
