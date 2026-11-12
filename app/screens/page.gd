# SPDX-License-Identifier: GPL-3.0-or-later
@abstract
class_name Page
extends Control
## One page of [ScreenFlow]. It is opened only by [method present]: filled and focused by its own [method _open], then
## waited for until it answers ([signal done]). [member phase] says who has its presses meanwhile.

## The page answers; each page says what [param result] is.
signal done(result: Variant)
signal phase_changed

## Who has the presses of the page in front; a page hidden keeps the phase it had (most stay LIVE once answered).
enum Phase {
	## Never opened, or, for the form, gone with the console it added until it is opened again.
	AWAY,
	## Coming back in: [ScreenFlow] holds its presses until it is back.
	ENTERING,
	## Taking its presses.
	LIVE,
	## Something it started is under way: [ScreenFlow] holds its presses until it ends.
	BUSY,
	## Going: it acts on none of its presses.
	LEAVING,
}

var phase := Phase.AWAY:
	set(value):
		if value != phase:
			phase = value
			phase_changed.emit()


## Opens the page for [param request] (what its [method _open] takes), taking its presses, and returns its answer.
func present(request: Variant = null) -> Variant:
	phase = Phase.LIVE
	_open(request)
	var focused := get_viewport().gui_get_focus_owner()
	assert(focused != null and is_ancestor_of(focused), "%s opened without a focus" % name)
	return await done


## Runs [param work] with the presses held; returns once it ends, the page taking them again unless it moved on
## meanwhile, or once something let the page go first ([member phase] LIVE again), the work going on.
func busy_while(work: Callable) -> void:
	phase = Phase.BUSY
	_hold_while(work)
	if phase == Phase.BUSY:
		await phase_changed


func _hold_while(work: Callable) -> void:
	await work.call()
	if phase == Phase.BUSY:
		phase = Phase.LIVE


## Whether the page, in front, takes no press now.
func holds_presses() -> bool:
	return phase != Phase.LIVE


## Fills the page for [param request] and gives one of its controls the focus.
@abstract func _open(request: Variant) -> void
