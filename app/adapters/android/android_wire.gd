# SPDX-License-Identifier: GPL-3.0-or-later
class_name AndroidWire
extends RefCounted
## The values [AndroidServices] reads from the plugin's answers, in the wire format of `Wire.kt`; a missing value
## is an absent key, surfaced as a `has_*` flag. [AndroidServices] names each of them (`AndroidServices.Game`).


## The texts listed under [param key] of [param item]; none when it is absent.
static func _strings(item: Dictionary, key: String) -> PackedStringArray:
	var texts: Array = item.get(key, [])
	return PackedStringArray(texts)


class Result:
	var ok: bool
	## Stable error code (`not_installed`, `permission_denied`…); empty when [member ok].
	var code: StringName
	## English detail, for logs.
	var detail: String

	func _init(payload: Dictionary) -> void:
		ok = payload.get("ok", false)
		code = payload.get("code", &"")
		detail = payload.get("detail", "")


## A folder or file reached through the system's document providers.
class Document:
	var uri: String
	var name: String
	## Whether the document has a filesystem [member path] (some emulators need one).
	var has_path: bool
	var path: String

	func _init(item: Dictionary) -> void:
		uri = item["uri"]
		name = item["name"]
		has_path = item.has("path")
		path = item.get("path", "")


## A folder granted through the system picker.
class Folder extends Document:
	## Whether the folder is on the device's storage, where [member volume] and [member folders]
	## say where, as the user reads it.
	var has_place: bool
	## `internal` or `card`.
	var volume: StringName
	## The folders from the volume down to this one; none for the volume itself.
	var folders: PackedStringArray

	func _init(item: Dictionary) -> void:
		super(item)
		has_place = item.has("place")
		var place: Dictionary = item.get("place", {})
		volume = place.get("volume", &"")
		folders = place.get("folders", PackedStringArray())


## A folder listing entry.
class Entry extends Document:
	var is_directory: bool
	var document_id: String

	func _init(item: Dictionary) -> void:
		super(item)
		is_directory = item["is_directory"]
		document_id = item["document_id"]


## A player able to open a given file, with its platform's name.
class Candidate extends Player:
	var platform_name: String

	func _init(item: Dictionary) -> void:
		super(item)
		platform_name = item["platform_name"]


class App:
	var package_name: String
	var label: String

	func _init(item: Dictionary) -> void:
		package_name = item["package"]
		label = item["label"]


class Battery:
	var has_level: bool
	var level_percent: int
	## Whether the device is plugged into a charger, charging or full.
	var plugged: bool

	func _init(payload: Dictionary) -> void:
		has_level = payload.has("level_percent")
		level_percent = payload.get("level_percent", 0)
		plugged = payload.get("plugged", false)


class Platform:
	var id: String
	var name: String
	## `dvd`, `cartridge` or `minidisc`.
	var media: String

	func _init(item: Dictionary) -> void:
		id = item["id"]
		name = item["name"]
		media = item["media"]


class Player:
	var id: String
	var name: String
	## The name without the platform the definitions put first, as the user knows the emulator.
	var emulator_name: String
	## The file extensions the player opens, when its definition says them plainly; empty otherwise.
	var extensions: PackedStringArray

	func _init(item: Dictionary) -> void:
		id = item["player_id"]
		name = item["player_name"]
		emulator_name = item.get("emulator_name", name)
		extensions = item.get("extensions", PackedStringArray())


class CatalogSummary:
	var platforms: Array[Platform] = []
	## The platforms a person may add, those with a console model, in the order of the Type chooser;
	## none from a catalog that did not name them (the desktop demo as generated).
	var offered: Array[OfferedConsole] = []
	## One line per rejected definition: `source: detail`.
	var rejected := PackedStringArray()

	func _init(payload: Dictionary) -> void:
		for item: Dictionary in payload.get("platforms", []):
			platforms.append(Platform.new(item))
		for item: Dictionary in payload.get("offered", []):
			offered.append(OfferedConsole.new(item))
		for rejection: Dictionary in payload.get("rejected", []):
			rejected.append("%s: %s" % [rejection["source"], rejection["detail"]])


## A platform of the Type chooser: its maker, shown small above its model (empty when the name has no
## maker in it), and its model name.
class OfferedConsole:
	var id: String
	var maker: String
	var model: String

	func _init(item: Dictionary) -> void:
		id = item["id"]
		maker = item.get("maker", "")
		model = item["model"]


class Placed extends Result:
	## The platform ids of all the consoles after placing, first to last; empty when not [member ok].
	var order := PackedStringArray()

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			order = payload.get("order", PackedStringArray())


class Pick extends Result:
	var folder: Folder

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			var item: Dictionary = payload["folder"]
			folder = Folder.new(item)


class FolderList extends Result:
	var folders: Array[Folder] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("folders", []):
			folders.append(Folder.new(item))


class Listing extends Result:
	var entries: Array[Entry] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("entries", []):
			entries.append(Entry.new(item))


class AppList extends Result:
	var apps: Array[App] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("apps", []):
			apps.append(App.new(item))


## The choices made for one platform.
class PlatformSetup:
	var has_folder: bool
	var folder_uri: String
	## Without a player, the first installed one is used.
	var has_player: bool
	var player_id: String
	## `grouped` (`Game (Disc 1)` and `(Disc 2)` make one game) or `separate`.
	var disc_grouping: String
	## `top_level` or `subfolders`.
	var folder_depth: String
	var variant_id: String

	func _init(item: Dictionary = {}) -> void:
		has_folder = item.has("folder_uri")
		folder_uri = item.get("folder_uri", "")
		has_player = item.has("player_id")
		player_id = item.get("player_id", "")
		disc_grouping = item.get("disc_grouping", "grouped")
		folder_depth = item.get("folder_depth", "top_level")
		variant_id = item.get("variant", "")

	func to_wire() -> Dictionary:
		var item := {"disc_grouping": disc_grouping, "folder_depth": folder_depth}
		if not variant_id.is_empty():
			item["variant"] = variant_id
		if has_folder:
			item["folder_uri"] = folder_uri
		if has_player:
			item["player_id"] = player_id
		return item


class Disc:
	## Whether the file names a disc number (`Disc 2`); single-disc games have none.
	var has_number: bool
	var number: int
	var name: String

	func _init(item: Dictionary) -> void:
		has_number = item.has("number")
		number = item.get("number", 0)
		name = item["name"]


class Game:
	var id: String
	var platform_id: String
	var title: String
	var regions := PackedStringArray()
	## The medium its platform gives a game of its regions (`sfc_cart`); empty when the platform is
	## unknown.
	var medium: String
	var languages := PackedStringArray()
	var serials := PackedStringArray()
	var has_version: bool
	var version: String
	## Whether the reference list knows the game: as the exact disc [member redump_name], or by
	## the [member serials] of its release.
	var identified: bool
	var has_redump_name: bool
	var redump_name: String
	var discs: Array[Disc] = []
	## Index into [member discs] of the disc launched last.
	var last_disc: int
	## Whether the user chose the image its label shows, by [member label_region] and
	## [member label_source].
	var has_label_region: bool
	var label_region: String
	## The source of the chosen image, as the plugin names sources (`launchbox`, `screenscraper`).
	var label_source: String
	## Whether its label shows a picture of the user's own.
	var label_own: bool
	## The title it had before the user renamed it, [member title] being the name they gave it.
	var has_original_title: bool
	var original_title: String

	## The title it has of its own, whatever name the user gave it.
	func own_title() -> String:
		return original_title if has_original_title else title

	func _init(item: Dictionary) -> void:
		id = item["id"]
		platform_id = item["platform_id"]
		title = item["title"]
		regions = AndroidWire._strings(item, "regions")
		medium = item.get("medium", "")
		languages = AndroidWire._strings(item, "languages")
		serials = AndroidWire._strings(item, "serials")
		has_version = item.has("version")
		version = item.get("version", "")
		identified = item["identified"]
		has_redump_name = item.has("redump_name")
		redump_name = item.get("redump_name", "")
		for disc: Dictionary in item["discs"]:
			discs.append(Disc.new(disc))
		last_disc = item["last_disc"]
		has_label_region = item.has("label_region")
		label_region = item.get("label_region", "")
		label_source = item.get("label_source", "")
		label_own = item.get("label_own", false)
		has_original_title = item.has("original_title")
		original_title = item.get("original_title", "")


## A sub-folder a scan did not look into.
class SkippedFolder:
	## Relative to the scanned folder, such as `Saves/memcards`.
	var path: String
	## `hidden`, `emulator_data`, `too_deep` or `unreadable`.
	var reason: String

	func _init(item: Dictionary) -> void:
		path = item["path"]
		reason = item["reason"]


## How many hidden or unsupported files a scan set aside, with the first of their names.
class IgnoredCount:
	## `hidden` or `unsupported`.
	var reason: String
	var count: int
	var examples := PackedStringArray()

	func _init(reason_name: String, item: Dictionary) -> void:
		reason = reason_name
		count = item["count"]
		examples = AndroidWire._strings(item, "examples")


## The games of one platform, in the order the carousel shows them.
class Shelf:
	var platform_id: String
	var games: Array[Game] = []
	## Index into [member games] of the game to show first.
	var selected: int

	func _init(item: Dictionary, all_games: Array[Game]) -> void:
		platform_id = item["platform"]
		for index: int in item["games"]:
			games.append(all_games[index])
		selected = item["selected"]


## What the carousel shows of a shelf, sent as JSON (see `View.toWireJson` in `Wire.kt`).
class Browse:
	## How many games the shelf has, as the plugin knows it: a view of another library is not
	## for the shelf shown.
	var count: int
	## Positions in the shelf of the games shown, in their order.
	var games := PackedInt32Array()
	## The index's groups of [member games] (none while searching).
	var groups: Array[Group] = []
	## Each key of the ribbon that leads to a game (a lowercase letter, a digit, a space), and the
	## index into [member games] it brings the carousel to.
	var keys: Dictionary[String, int] = {}

	func _init(item: Dictionary) -> void:
		count = item.get("count", 0)
		var positions: Array = item.get("games", [])
		games = PackedInt32Array(positions)
		for group: Dictionary in item.get("groups", []):
			groups.append(Group.new(group))
		var found: Dictionary = item.get("keys", {})
		for key: String in found:
			# JSON numbers are read as floats.
			var at: int = found[key]
			keys[key] = at


## The games of a view from [member start] on that share a [member label]: a letter, `#`, a region.
class Group:
	var label: String
	var start: int

	func _init(item: Dictionary) -> void:
		label = item["label"]
		start = item["start"]


## The library, sent as JSON (see `toWireJson` in `Wire.kt`).
class Library:
	var games: Array[Game] = []
	## One per platform that has games, in catalog order; none when the library has no games.
	var shelves: Array[Shelf] = []
	## Index into [member shelves] of the shelf to show first.
	var selected_shelf: int
	var console_variants: Dictionary[String, String] = {}
	var _setups: Dictionary[String, PlatformSetup] = {}
	var _not_games: Dictionary[String, Array] = {}
	var _ignored_counts: Dictionary[String, Dictionary] = {}
	var _skipped: Dictionary[String, Array] = {}

	func _init(item: Dictionary) -> void:
		var variants: Dictionary = item.get("console_variants", {})
		console_variants.assign(variants)
		var setups: Dictionary = item.get("setups", {})
		for platform_id: String in setups:
			var setup: Dictionary = setups[platform_id]
			_setups[platform_id] = PlatformSetup.new(setup)
			_setups[platform_id].variant_id = console_variants.get(platform_id, "")
		for game: Dictionary in item.get("games", []):
			games.append(Game.new(game))
		var not_games: Dictionary = item.get("not_games", {})
		_not_games.assign(not_games)
		var skipped: Dictionary = item.get("skipped_folders", {})
		_skipped.assign(skipped)
		var counts: Dictionary = item.get("ignored_counts", {})
		_ignored_counts.assign(counts)
		var found: Dictionary = item.get("shelves", {"shelves": [], "selected": 0})
		for shelf: Dictionary in found["shelves"]:
			shelves.append(Shelf.new(shelf, games))
		selected_shelf = found["selected"]

	func setup_of(platform_id: String) -> PlatformSetup:
		return _setups.get(platform_id, PlatformSetup.new())

	## The platforms set up, games or not.
	func set_up_platforms() -> PackedStringArray:
		return PackedStringArray(_setups.keys())

	func games_of(platform_id: String) -> Array[Game]:
		return games.filter(func(game: Game) -> bool: return game.platform_id == platform_id)

	## Files a player opens that were not taken for games (a BIOS, too small).
	func not_games_of(platform_id: String) -> PackedStringArray:
		return AndroidWire._strings(_not_games, platform_id)

	func ignored_counts_of(platform_id: String) -> Array[IgnoredCount]:
		var counts: Array[IgnoredCount] = []
		var by_reason: Dictionary = _ignored_counts.get(platform_id, {})
		for reason: String in by_reason:
			var count: Dictionary = by_reason[reason]
			counts.append(IgnoredCount.new(reason, count))
		return counts

	func skipped_folders_of(platform_id: String) -> Array[SkippedFolder]:
		var folders: Array[SkippedFolder] = []
		for item: Dictionary in _skipped.get(platform_id, []):
			folders.append(SkippedFolder.new(item))
		return folders


class LibraryAnswer extends Result:
	var library: Library
	## The art stored for its games, and the ids of those no source had an image of when last
	## looked for (sent by [method AndroidServices.library] only).
	var art: Array[Art] = []
	var absent: PackedStringArray
	## Why the stored library could not be read, when it could not: it then started empty.
	var has_load_problem: bool
	var load_problem: String

	func _init(payload: Dictionary) -> void:
		super(payload)
		var text: String = payload.get("library", "{}")
		var started := Time.get_ticks_usec()
		var item: Dictionary = JSON.parse_string(text)
		library = Library.new(item)
		if Diagnostics.enabled:
			var elapsed := (Time.get_ticks_usec() - started) / 1000.0
			Diagnostics.trace("library", "%d games read from %d characters in %.1f ms" % [
				library.games.size(), text.length(), elapsed])
		has_load_problem = payload.has("load_problem")
		load_problem = payload.get("load_problem", "")
		var art_text: String = payload.get("art", "[]")
		var stored: Array = JSON.parse_string(art_text)
		for found: Dictionary in stored:
			art.append(Art.new(found))
		absent = payload.get("absent", PackedStringArray())


class ScanReport:
	var files: int
	var games: int
	var identified: int
	var ignored: int
	var skipped_folders: int
	var milliseconds: int

	func _init(item: Dictionary) -> void:
		files = item.get("files", 0)
		games = item.get("games", 0)
		identified = item.get("identified", 0)
		ignored = item.get("ignored", 0)
		skipped_folders = item.get("skipped_folders", 0)
		milliseconds = item.get("milliseconds", 0)


class PreviewAnswer extends Result:
	var report: ScanReport

	func _init(payload: Dictionary) -> void:
		super(payload)
		var item: Dictionary = payload.get("report", {})
		report = ScanReport.new(item)


class SettingsAnswer extends Result:
	## Whether the first launch is still to do: no button style chosen and no platform.
	var first_launch: bool
	var has_button_style: bool
	## `xbox`, `nintendo` or `playstation`: how the buttons are drawn.
	var button_style: StringName
	## `4x`, `2x` or `off`: how smooth the 3D's edges are drawn.
	var edge_smoothing: StringName
	## Whether the selected game sways and bobs; the consoles never do.
	var games_float: bool
	## How loud the sounds play, from 0 (silenced) to [constant SoundEffects.LEVELS].
	var sound_level: int
	## The region labels' images prefer, one of [member preferred_regions]; empty for none.
	var preferred_region: String
	## The regions labels' images can prefer, as the plugin names them, the only ones it saves.
	var preferred_regions: PackedStringArray

	func _init(payload: Dictionary) -> void:
		super(payload)
		first_launch = payload.get("first_launch", false)
		has_button_style = payload.has("button_style")
		button_style = payload.get("button_style", &"")
		edge_smoothing = payload.get("edge_smoothing", &"4x")
		games_float = payload.get("games_float", false)
		sound_level = payload.get("sound_level", SoundEffects.LEVELS)
		preferred_region = payload.get("preferred_region", "")
		preferred_regions = payload.get("preferred_regions", PackedStringArray())


class ScanAnswer extends LibraryAnswer:
	var report: ScanReport

	func _init(payload: Dictionary) -> void:
		super(payload)
		var item: Dictionary = payload.get("report", {})
		report = ScanReport.new(item)


class RescrapeAnswer extends LibraryAnswer:
	## How many games the library holds.
	var games: int
	## How many of the labels looked for were found.
	var labels: int
	## Why each console that could not be scanned was not.
	var failures: PackedStringArray

	func _init(payload: Dictionary) -> void:
		super(payload)
		games = payload.get("games", 0)
		labels = payload.get("labels", 0)
		failures = payload.get("failures", PackedStringArray())


## A game's disc scan, as the plugin stored it.
class Art:
	var game_id: String
	## An absolute path to a JPEG.
	var path: String

	func _init(item: Dictionary) -> void:
		game_id = item["game_id"]
		path = item["path"]


## How looking for the games' art goes.
class ArtProgress:
	## Games of this run done, and looked for in it, done or not.
	var done: int
	var total: int
	## Why it waits: `offline`, `refused` (a server busy or failing) or `storage`; empty when it
	## does not.
	var stall: StringName

	func _init(item: Dictionary) -> void:
		done = item.get("done", 0)
		total = item.get("total", 0)
		stall = item.get("stall", &"")


class ArtChange:
	var progress: ArtProgress
	var has_found: bool
	var found: Art
	## The ids of games no source has an image of, just looked for.
	var absent: PackedStringArray

	func _init(payload: Dictionary) -> void:
		progress = ArtProgress.new(payload)
		has_found = payload.has("found")
		if has_found:
			var item: Dictionary = payload["found"]
			found = Art.new(item)
		absent = payload.get("absent", PackedStringArray())


## How far the download of a game's label has come, as `art_progress` tells it.
class LabelDownload:
	var game_id: String
	## Whether it goes on; once over, found or not, it does not.
	var running: bool
	## How much of the image is read, from 0 to 1; -1 when its size is unknown.
	var fraction: float

	func _init(item: Dictionary) -> void:
		game_id = item["game_id"]
		running = item.has("fraction")
		fraction = item.get("fraction", -1.0)


## One image a game's label can show: [member source]'s for [member region] (as the sources name
## it, empty when they name none), at [member path] once downloaded.
class LabelVariant:
	## Set when it arrives through [signal AndroidServices.label_variant_downloaded].
	var game_id: String
	var region: String
	## The source, as the plugin names it for [method AndroidServices.choose_label], and as shown.
	var source: String
	var source_name: String
	var has_path: bool
	var path: String
	## Why it could not be downloaded: `offline`, `refused`, `not_found`, `unreadable` or `storage`;
	## empty when it was, or is still to be.
	var failure: StringName

	func _init(item: Dictionary) -> void:
		game_id = item.get("game_id", "")
		region = item["region"]
		source = item["source"]
		source_name = item["source_name"]
		has_path = item.has("path")
		path = item.get("path", "")
		failure = item.get("failure", &"")


class LabelVariants extends Result:
	var variants: Array[LabelVariant] = []

	func _init(payload: Dictionary) -> void:
		super(payload)
		for item: Dictionary in payload.get("variants", []):
			variants.append(LabelVariant.new(item))


## What a game is called once renamed: [member title], and its own title when the user gave it a name.
class Renamed extends Result:
	var title: String
	var has_original_title: bool
	var original_title: String

	func _init(payload: Dictionary) -> void:
		super(payload)
		title = payload.get("title", "")
		has_original_title = payload.has("original_title")
		original_title = payload.get("original_title", "")


## A picture of the user's own being framed: the app's copy at [member path], [member size] pixels.
class LabelPicture extends Result:
	var path: String
	var size: Vector2i

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			var item: Dictionary = payload["picture"]
			path = item["path"]
			var width: int = item["width"]
			var height: int = item["height"]
			size = Vector2i(width, height)


class ArtAnswer extends Result:
	var art: Art

	func _init(payload: Dictionary) -> void:
		super(payload)
		if ok:
			var item: Dictionary = payload["art"]
			art = Art.new(item)
