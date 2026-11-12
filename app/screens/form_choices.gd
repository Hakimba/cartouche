# SPDX-License-Identifier: GPL-3.0-or-later
class_name FormChoices
extends RefCounted
## What the form adding a console ([AddConsole]) holds chosen, and what follows from it alone: the choices as the
## plugin takes them, what the note under the fields says, whether the games can be counted. No node, no plugin.

## What the note says: to install an emulator, nothing, the files the emulator accepts, or how many games were found.
enum Note { INSTALL, NOTHING, ACCEPTED, COUNTED }

var players: Array[AndroidServices.Player] = []
## Index of the chosen player in [member players]; -1 until one is chosen.
var player := -1
var folder: AndroidServices.Folder
var has_folder := false
## Games found in the folder with the current choices; -1 until counted.
var games := -1
## Whether the user changed any choice but the model.
var touched := false


## The id of the player chosen, empty when none is.
func player_id() -> String:
	return players[player].id if player >= 0 else ""


## Whether the games can be counted: a folder and a player are chosen.
func can_count() -> bool:
	return has_folder and player >= 0


## What the note says for the platform [param platform_id] (empty: none chosen yet).
func note(platform_id: String) -> Note:
	if platform_id and players.is_empty():
		return Note.INSTALL
	if player < 0:
		return Note.NOTHING
	return Note.ACCEPTED if games < 0 else Note.COUNTED


## The choices as the plugin takes them: the games of the sub-folders too when [param subfolders], the discs of one
## game together when [param discs], the console's model in [param variant_id].
func setup(subfolders: bool, discs: bool, variant_id: String) -> AndroidServices.PlatformSetup:
	var choices := AndroidServices.PlatformSetup.new()
	choices.has_folder_uri = has_folder
	choices.folder_uri = folder.uri if has_folder else ""
	choices.has_player_id = player >= 0
	choices.player_id = player_id()
	choices.folder_depth = "subfolders" if subfolders else "top_level"
	choices.variant_id = variant_id
	choices.disc_grouping = "grouped" if discs else "separate"
	return choices
