# SPDX-License-Identifier: GPL-3.0-or-later
class_name Ps2FatModel
extends GlbConsole
## The original PS2, its parts declared in its scene: its tray slides out towards the front carrying the disc, both
## buttons press in. The seat follows the tray, which data cannot say.


func seat() -> Transform3D:
	return (shape as Ps2FatShape).seat(value_of(&"tray_mm"))
