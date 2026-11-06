# SPDX-License-Identifier: GPL-3.0-or-later
# Generated from kotlin/android/src/main/kotlin/app/cartouche/android/Sent.kt by WireScriptTest; only the lines a class
# has by hand are edited here. After changing Sent.kt:
# kotlin/gradlew -p kotlin :android:testDebugUnitTest --tests '*WireScriptTest' -Pwire.write=true
class_name AndroidWire
extends RefCounted
## The values the plugin sends, as JSON text ([AndroidServices] reads them): a class per type of `Sent.kt`, a field
## per property under its key. A value that may be missing is an absent key, surfaced as a `has_*` flag.


## The texts listed under [param key] of [param item]; none when it is absent.
static func _strings(item: Dictionary, key: String) -> PackedStringArray:
	var texts: Array = item.get(key, [])
	return PackedStringArray(texts)


static func _ints(item: Dictionary, key: String) -> PackedInt32Array:
	var numbers: Array = item.get(key, [])
	return PackedInt32Array(numbers)


## An operation's answer: [member ok], or the [member code] of its failure.
class Result:
	var ok: bool
	## One of `cancelled`, `no_activity`, `invalid_request`, `unknown_player`, `unsupported_file`, `invalid_template`,
	## `not_installed`, `no_player`, `game_missing`, `too_late`, `unknown_platform`, `unknown_variant`,
	## `coming_console`, `not_in_library`, `gap_out_of_range`, `unknown_game`, `no_folder`, `activity_not_found`,
	## `permission_denied`, `folder_unavailable`, `too_many_files`, `no_image`, `unreadable_image`, `unexpected`;
	## `unavailable` without the plugin, `rehearsed` for a launch rehearsed.
	var code: StringName
	## English, for logs.
	var detail: String

	func _init(item: Dictionary = {}) -> void:
		ok = item.get("ok", false)
		code = item.get("code", &"")
		detail = item.get("detail", "")


class CatalogSummary:
	var platforms: Array[Platform] = []
	var offered: Array[OfferedConsole] = []
	var rejected: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		for each: Dictionary in item.get("platforms", []):
			platforms.append(Platform.new(each))
		for each: Dictionary in item.get("offered", []):
			offered.append(OfferedConsole.new(each))
		rejected = AndroidWire._strings(item, "rejected")


class Platform:
	var id: String
	var name: String
	var media: StringName

	func _init(item: Dictionary = {}) -> void:
		id = item.get("id", "")
		name = item.get("name", "")
		media = item.get("media", &"")


class OfferedConsole:
	var id: String
	var model: String
	var has_maker: bool
	var maker: String
	var coming: bool

	func _init(item: Dictionary = {}) -> void:
		id = item.get("id", "")
		model = item.get("model", "")
		has_maker = item.has("maker")
		maker = item.get("maker", "")
		coming = item.get("coming", false)


class Players:
	var players: Array[Player] = []

	func _init(item: Dictionary = {}) -> void:
		for each: Dictionary in item.get("players", []):
			players.append(Player.new(each))


class Player:
	var id: String
	var name: String
	var emulator_name: String
	var has_extensions: bool
	var extensions: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		id = item.get("id", "")
		name = item.get("name", "")
		emulator_name = item.get("emulator_name", "")
		has_extensions = item.has("extensions")
		extensions = AndroidWire._strings(item, "extensions")


class Browse:
	var count: int
	var games: PackedInt32Array
	var groups: Array[Group] = []
	var keys: Dictionary[String, int] = {}

	func _init(item: Dictionary = {}) -> void:
		count = item.get("count", 0)
		games = AndroidWire._ints(item, "games")
		for each: Dictionary in item.get("groups", []):
			groups.append(Group.new(each))
		var raw_keys: Dictionary = item.get("keys", {})
		for key: String in raw_keys:
			var value: int = raw_keys[key]
			keys[key] = value


class Group:
	var label: String
	var start: int

	func _init(item: Dictionary = {}) -> void:
		label = item.get("label", "")
		start = item.get("start", 0)


class Marks:
	var marks: Array[Mark] = []

	func _init(item: Dictionary = {}) -> void:
		for each: Dictionary in item.get("marks", []):
			marks.append(Mark.new(each))


class Mark:
	var start: int
	var length: int

	func _init(item: Dictionary = {}) -> void:
		start = item.get("start", 0)
		length = item.get("length", 0)


class BackdropAnswer:
	var backdrop: StringName
	var pixel_veil: bool

	func _init(item: Dictionary = {}) -> void:
		backdrop = item.get("backdrop", &"light")
		pixel_veil = item.get("pixel_veil", true)


class Battery:
	var has_level_percent: bool
	var level_percent: int
	var plugged: bool

	func _init(item: Dictionary = {}) -> void:
		has_level_percent = item.has("level_percent")
		level_percent = item.get("level_percent", 0)
		plugged = item.get("plugged", false)


class ArtChange:
	var progress: ArtProgress
	var has_found: bool
	var found: Art
	var absent: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		var raw_progress: Dictionary = item.get("progress", {})
		progress = ArtProgress.new(raw_progress)
		has_found = item.has("found")
		if has_found:
			var raw_found: Dictionary = item["found"]
			found = Art.new(raw_found)
		absent = AndroidWire._strings(item, "absent")


class ArtProgress:
	var done: int
	var total: int
	var has_stall: bool
	var stall: StringName

	func _init(item: Dictionary = {}) -> void:
		done = item.get("done", 0)
		total = item.get("total", 0)
		has_stall = item.has("stall")
		stall = item.get("stall", &"")


class Art:
	var game_id: String
	var path: String

	func _init(item: Dictionary = {}) -> void:
		game_id = item.get("game_id", "")
		path = item.get("path", "")


class LabelDownload:
	var game_id: String
	var running: bool
	var fraction: float

	func _init(item: Dictionary = {}) -> void:
		game_id = item.get("game_id", "")
		running = item.get("running", false)
		fraction = item.get("fraction", 0.0)


class LabelVariant:
	var has_game_id: bool
	var game_id: String
	var region: String
	var source: StringName
	var source_name: String
	var has_path: bool
	var path: String
	var has_failure: bool
	var failure: StringName

	func _init(item: Dictionary = {}) -> void:
		has_game_id = item.has("game_id")
		game_id = item.get("game_id", "")
		region = item.get("region", "")
		source = item.get("source", &"")
		source_name = item.get("source_name", "")
		has_path = item.has("path")
		path = item.get("path", "")
		has_failure = item.has("failure")
		failure = item.get("failure", &"")


class Pick extends Result:
	var folder: Folder

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_folder: Dictionary = item.get("folder", {})
		folder = Folder.new(raw_folder)


class Folder:
	var uri: String
	var name: String
	var has_path: bool
	var path: String
	var has_volume: bool
	var volume: StringName
	var folders: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		uri = item.get("uri", "")
		name = item.get("name", "")
		has_path = item.has("path")
		path = item.get("path", "")
		has_volume = item.has("volume")
		volume = item.get("volume", &"")
		folders = AndroidWire._strings(item, "folders")


class FolderList extends Result:
	var folders: Array[Folder] = []

	func _init(item: Dictionary = {}) -> void:
		super(item)
		for each: Dictionary in item.get("folders", []):
			folders.append(Folder.new(each))


class Placed extends Result:
	var order: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		super(item)
		order = AndroidWire._strings(item, "order")


class LibraryAnswer extends Result:
	var library: Library
	var art: Array[Art] = []
	var absent: PackedStringArray
	var has_arrivals: bool
	var arrivals: Arrivals
	var has_load_problem: bool
	var load_problem: String

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_library: Dictionary = item.get("library", {})
		library = Library.new(raw_library)
		for each: Dictionary in item.get("art", []):
			art.append(Art.new(each))
		absent = AndroidWire._strings(item, "absent")
		has_arrivals = item.has("arrivals")
		if has_arrivals:
			var raw_arrivals: Dictionary = item["arrivals"]
			arrivals = Arrivals.new(raw_arrivals)
		has_load_problem = item.has("load_problem")
		load_problem = item.get("load_problem", "")


class Library:
	var revision: int
	var setups: Dictionary[String, PlatformSetup] = {}
	var games: Array[Game] = []
	var not_games: Dictionary[String, PackedStringArray] = {}
	var ignored_counts: Dictionary[String, Array] = {}
	var skipped_folders: Dictionary[String, Array] = {}
	var console_variants: Dictionary[String, String] = {}
	var shelves: Array[Shelf] = []
	var selected_shelf: int
	# By hand, up to _init: kept as is by WireScriptTest.

	## The platforms the consoles' ring shows, those with games. One set up whose games are all gone is not among them:
	## the form adding a console sets it up again.
	func on_ring() -> PackedStringArray:
		return PackedStringArray(shelves.map(func(shelf: Shelf) -> String: return shelf.platform_id))

	## The platforms whose folder is read again as the app comes to the screen: those with a folder.
	func with_folders() -> PackedStringArray:
		return PackedStringArray(setups.keys().filter(func(platform_id: String) -> bool:
			return setups[platform_id].has_folder_uri))

	func setup_of(platform_id: String) -> PlatformSetup:
		return setups.get(platform_id, PlatformSetup.new())

	func games_of(platform_id: String) -> Array[Game]:
		return games.filter(func(game: Game) -> bool: return game.platform_id == platform_id)

	## Files a player opens that were not taken for games (a BIOS, too small).
	func not_games_of(platform_id: String) -> PackedStringArray:
		return not_games.get(platform_id, PackedStringArray())

	func ignored_counts_of(platform_id: String) -> Array[IgnoredCount]:
		var listed: Array = ignored_counts.get(platform_id, [])
		var counts: Array[IgnoredCount] = []
		counts.assign(listed)
		return counts

	func skipped_folders_of(platform_id: String) -> Array[SkippedFolder]:
		var listed: Array = skipped_folders.get(platform_id, [])
		var folders: Array[SkippedFolder] = []
		folders.assign(listed)
		return folders

	## Each shelf's games, from its indexes into [member games].
	func _finish(_item: Dictionary) -> void:
		for shelf in shelves:
			for at in shelf.game_indexes:
				shelf.games.append(games[at])

	func _init(item: Dictionary = {}) -> void:
		revision = item.get("revision", 0)
		var raw_setups: Dictionary = item.get("setups", {})
		for key: String in raw_setups:
			var value: Dictionary = raw_setups[key]
			setups[key] = PlatformSetup.new(value)
		for each: Dictionary in item.get("games", []):
			games.append(Game.new(each))
		var raw_not_games: Dictionary = item.get("not_games", {})
		for key: String in raw_not_games:
			not_games[key] = AndroidWire._strings(raw_not_games, key)
		var raw_ignored_counts: Dictionary = item.get("ignored_counts", {})
		for key: String in raw_ignored_counts:
			var list: Array[IgnoredCount] = []
			for each: Dictionary in raw_ignored_counts[key]:
				list.append(IgnoredCount.new(each))
			ignored_counts[key] = list
		var raw_skipped_folders: Dictionary = item.get("skipped_folders", {})
		for key: String in raw_skipped_folders:
			var list: Array[SkippedFolder] = []
			for each: Dictionary in raw_skipped_folders[key]:
				list.append(SkippedFolder.new(each))
			skipped_folders[key] = list
		var raw_console_variants: Dictionary = item.get("console_variants", {})
		for key: String in raw_console_variants:
			var value: String = raw_console_variants[key]
			console_variants[key] = value
		for each: Dictionary in item.get("shelves", []):
			shelves.append(Shelf.new(each))
		selected_shelf = item.get("selected_shelf", 0)
		_finish(item)


class PlatformSetup:
	var disc_grouping: StringName
	var folder_depth: StringName
	var has_folder_uri: bool
	var folder_uri: String
	var has_player_id: bool
	var player_id: String
	var has_variant_id: bool
	var variant_id: String
	# By hand, up to _init: kept as is by WireScriptTest.

	## The choices as [method AndroidServices.set_up_platform] sends them: a model chosen is sent without its flag.
	func to_wire() -> Dictionary:
		var item := {"disc_grouping": String(disc_grouping), "folder_depth": String(folder_depth)}
		if not variant_id.is_empty():
			item["variant_id"] = variant_id
		if has_folder_uri:
			item["folder_uri"] = folder_uri
		if has_player_id:
			item["player_id"] = player_id
		return item

	func _init(item: Dictionary = {}) -> void:
		disc_grouping = item.get("disc_grouping", &"grouped")
		folder_depth = item.get("folder_depth", &"top_level")
		has_folder_uri = item.has("folder_uri")
		folder_uri = item.get("folder_uri", "")
		has_player_id = item.has("player_id")
		player_id = item.get("player_id", "")
		has_variant_id = item.has("variant_id")
		variant_id = item.get("variant_id", "")


class Game:
	var id: String
	var platform_id: String
	var title: String
	var has_original_title: bool
	var original_title: String
	var regions: PackedStringArray
	var has_medium: bool
	var medium: String
	var languages: PackedStringArray
	var serials: PackedStringArray
	var discs: Array[Disc] = []
	var last_disc: int
	var identified: bool
	var has_version: bool
	var version: String
	var has_redump_name: bool
	var redump_name: String
	var has_label_region: bool
	var label_region: String
	var has_label_source: bool
	var label_source: StringName
	var label_own: bool
	# By hand, up to _init: kept as is by WireScriptTest.

	## The title it has of its own, whatever name the user gave it.
	func own_title() -> String:
		return original_title if has_original_title else title

	func _init(item: Dictionary = {}) -> void:
		id = item.get("id", "")
		platform_id = item.get("platform_id", "")
		title = item.get("title", "")
		has_original_title = item.has("original_title")
		original_title = item.get("original_title", "")
		regions = AndroidWire._strings(item, "regions")
		has_medium = item.has("medium")
		medium = item.get("medium", "")
		languages = AndroidWire._strings(item, "languages")
		serials = AndroidWire._strings(item, "serials")
		for each: Dictionary in item.get("discs", []):
			discs.append(Disc.new(each))
		last_disc = item.get("last_disc", 0)
		identified = item.get("identified", false)
		has_version = item.has("version")
		version = item.get("version", "")
		has_redump_name = item.has("redump_name")
		redump_name = item.get("redump_name", "")
		has_label_region = item.has("label_region")
		label_region = item.get("label_region", "")
		has_label_source = item.has("label_source")
		label_source = item.get("label_source", &"")
		label_own = item.get("label_own", false)


class Disc:
	var name: String
	var has_number: bool
	var number: int

	func _init(item: Dictionary = {}) -> void:
		name = item.get("name", "")
		has_number = item.has("number")
		number = item.get("number", 0)


class IgnoredCount:
	var reason: StringName
	var count: int
	var examples: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		reason = item.get("reason", &"")
		count = item.get("count", 0)
		examples = AndroidWire._strings(item, "examples")


class SkippedFolder:
	var path: String
	var reason: StringName

	func _init(item: Dictionary = {}) -> void:
		path = item.get("path", "")
		reason = item.get("reason", &"")


class Shelf:
	var platform_id: String
	var game_indexes: PackedInt32Array
	var selected: int
	# By hand, up to _init: kept as is by WireScriptTest.
	## The games of [member game_indexes], in the carousel's order.
	var games: Array[Game] = []

	func _init(item: Dictionary = {}) -> void:
		platform_id = item.get("platform_id", "")
		game_indexes = AndroidWire._ints(item, "game_indexes")
		selected = item.get("selected", 0)


class Arrivals:
	var unseen: PackedStringArray
	var announced: Dictionary[String, PackedStringArray] = {}

	func _init(item: Dictionary = {}) -> void:
		unseen = AndroidWire._strings(item, "unseen")
		var raw_announced: Dictionary = item.get("announced", {})
		for key: String in raw_announced:
			announced[key] = AndroidWire._strings(raw_announced, key)


class RefreshAnswer extends Result:
	var arrivals: Arrivals
	var has_library: bool
	var library: Library

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_arrivals: Dictionary = item.get("arrivals", {})
		arrivals = Arrivals.new(raw_arrivals)
		has_library = item.has("library")
		if has_library:
			var raw_library: Dictionary = item["library"]
			library = Library.new(raw_library)


class ArrivalsAnswer extends Result:
	var arrivals: Arrivals

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_arrivals: Dictionary = item.get("arrivals", {})
		arrivals = Arrivals.new(raw_arrivals)


class ScanAnswer extends Result:
	var library: Library
	var report: ScanReport
	var arrivals: Arrivals

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_library: Dictionary = item.get("library", {})
		library = Library.new(raw_library)
		var raw_report: Dictionary = item.get("report", {})
		report = ScanReport.new(raw_report)
		var raw_arrivals: Dictionary = item.get("arrivals", {})
		arrivals = Arrivals.new(raw_arrivals)


class ScanReport:
	var files: int
	var games: int
	var identified: int
	var ignored: int
	var skipped_folders: int
	var milliseconds: int

	func _init(item: Dictionary = {}) -> void:
		files = item.get("files", 0)
		games = item.get("games", 0)
		identified = item.get("identified", 0)
		ignored = item.get("ignored", 0)
		skipped_folders = item.get("skipped_folders", 0)
		milliseconds = item.get("milliseconds", 0)


class PreviewAnswer extends Result:
	var report: ScanReport

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_report: Dictionary = item.get("report", {})
		report = ScanReport.new(raw_report)


class RescrapeAnswer extends Result:
	var library: Library
	var games: int
	var labels: int
	var failures: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_library: Dictionary = item.get("library", {})
		library = Library.new(raw_library)
		games = item.get("games", 0)
		labels = item.get("labels", 0)
		failures = AndroidWire._strings(item, "failures")


class SettingsAnswer extends Result:
	var first_launch: bool
	var has_button_style: bool
	var button_style: StringName
	var edge_smoothing: StringName
	var has_preferred_region: bool
	var preferred_region: StringName
	var games_float: bool
	var sound_level: int
	var has_language: bool
	var language: StringName
	var backdrop: StringName
	var pixel_veil: bool
	var button_styles: PackedStringArray
	var edge_smoothings: PackedStringArray
	var preferred_regions: PackedStringArray
	var languages: PackedStringArray
	var backdrops: PackedStringArray

	func _init(item: Dictionary = {}) -> void:
		super(item)
		first_launch = item.get("first_launch", false)
		has_button_style = item.has("button_style")
		button_style = item.get("button_style", &"")
		edge_smoothing = item.get("edge_smoothing", &"4x")
		has_preferred_region = item.has("preferred_region")
		preferred_region = item.get("preferred_region", &"")
		games_float = item.get("games_float", false)
		sound_level = item.get("sound_level", 10)
		has_language = item.has("language")
		language = item.get("language", &"")
		backdrop = item.get("backdrop", &"light")
		pixel_veil = item.get("pixel_veil", true)
		button_styles = AndroidWire._strings(item, "button_styles")
		edge_smoothings = AndroidWire._strings(item, "edge_smoothings")
		preferred_regions = AndroidWire._strings(item, "preferred_regions")
		languages = AndroidWire._strings(item, "languages")
		backdrops = AndroidWire._strings(item, "backdrops")


class LabelVariants extends Result:
	var variants: Array[LabelVariant] = []

	func _init(item: Dictionary = {}) -> void:
		super(item)
		for each: Dictionary in item.get("variants", []):
			variants.append(LabelVariant.new(each))


class Renamed extends Result:
	var title: String
	var has_original_title: bool
	var original_title: String

	func _init(item: Dictionary = {}) -> void:
		super(item)
		title = item.get("title", "")
		has_original_title = item.has("original_title")
		original_title = item.get("original_title", "")


class LabelPicture extends Result:
	var path: String
	var width: int
	var height: int
	# By hand, up to _init: kept as is by WireScriptTest.
	var size: Vector2i

	func _finish(_item: Dictionary) -> void:
		size = Vector2i(width, height)

	func _init(item: Dictionary = {}) -> void:
		super(item)
		path = item.get("path", "")
		width = item.get("width", 0)
		height = item.get("height", 0)
		_finish(item)


class ArtAnswer extends Result:
	var art: Art

	func _init(item: Dictionary = {}) -> void:
		super(item)
		var raw_art: Dictionary = item.get("art", {})
		art = Art.new(raw_art)
