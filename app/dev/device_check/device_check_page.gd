# SPDX-License-Identifier: GPL-3.0-or-later
@abstract
class_name DeviceCheckPage
extends Control
## A tab of the device check. The root forwards lifecycle and back events to the visible page.

## A line for the log, in BBCode: escape outside text with [method plain].
signal logged(text: String)


## Called when the page is shown and when the app resumes; also gives focus to the page.
func refresh() -> void:
	pass


## Handles a back request; returns whether the page consumed it.
func go_back() -> bool:
	return false


## [param text] with its BBCode brackets escaped, for names coming from files or apps.
static func plain(text: String) -> String:
	return text.replace("[", "[lb]")
