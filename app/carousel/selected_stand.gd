# SPDX-License-Identifier: GPL-3.0-or-later
class_name SelectedStand
extends RefCounted
## How the selected game of the games row stands, told whole by whoever drives it ([method ShelfRow.stand]): posed in
## the row (a new one), tossed there ([GameToss]), staged out of it between its properties' editors
## ([DiscProperties]), or outside it, where a launch or the properties' travel puts it ([GameLaunch],
## [ConsoleSequence]). Its drivers build a new one for each change and tell it whole; the row writes none of its
## fields and hands out the one it was told ([method ShelfRow.standing]), which nobody writes either.

## Where the selected game is: in the row's care, between its place there and a staging, or where [member at] says.
## The row tells only [constant OUTSIDE] apart: a game not outside stands by [member amount], whatever its mode.
enum Mode { ROW, STAGED, OUTSIDE }

var mode := Mode.ROW
## Staged, where it stands once wholly out of the row, before the stick's turn; outside, where it stands. In the
## row's space.
var at := Transform3D.IDENTITY
## How far it has left the row for a still staging, from 0 to 1: staged, it stands that far between its place and
## [member at]; above 0, the stick's turn goes back to the front once let go.
var amount := 0.0
## Outside: turned this many radians about its own axis, its label blurred over this many, as its drive spins it.
var spin := 0.0
var blur := 0.0
## In the row ([GameToss]): lifted (world units), flipped about the horizontal axis (radians), and squashed (above 0)
## or stretched (below 0) by that part of its height.
var lift := 0.0
var flip := 0.0
var squash := 0.0


static func tossed(lifted: float, flipped: float, squashed: float) -> SelectedStand:
	var stand := SelectedStand.new()
	stand.lift = lifted
	stand.flip = flipped
	stand.squash = squashed
	return stand


static func staged(stands_at: Transform3D, out_of_row: float) -> SelectedStand:
	var stand := SelectedStand.new()
	stand.mode = Mode.STAGED
	stand.at = stands_at
	stand.amount = out_of_row
	return stand


static func outside(stands_at: Transform3D, spun := 0.0, blurred := 0.0, out_of_row := 0.0) -> SelectedStand:
	var stand := SelectedStand.new()
	stand.mode = Mode.OUTSIDE
	stand.at = stands_at
	stand.spin = spun
	stand.blur = blurred
	stand.amount = out_of_row
	return stand
