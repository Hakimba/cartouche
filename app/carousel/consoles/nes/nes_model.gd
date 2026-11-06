# SPDX-License-Identifier: GPL-3.0-or-later
class_name NesModel
extends GlbConsole
## The NES, its parts declared in its scene: its door lifts up and back, its tray tilts up about its back to take the
## cartridge and is pressed down level once it is in. The seat follows the tray, which data cannot say.


func seat() -> Transform3D:
	return (shape as NesShape).seat(value_of(&"tray_degrees"))
