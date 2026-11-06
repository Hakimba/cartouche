# SPDX-License-Identifier: GPL-3.0-or-later
@tool
@abstract
class_name GlbConsoleShape
extends GlbShape
## What the launch reads of a console drawn from a glb ([GlbConsole]), in millimetres, in the model's axes: where a
## seated medium stands. [SeatShape] gives it as data; a shape of its own computes it from its measures.


## Where a seated medium stands, in the model's space: the medium's own origin and axes (see
## [method ConsoleModel.seat]).
@abstract func seat() -> Transform3D
