# SPDX-License-Identifier: GPL-3.0-or-later
class_name ScreenFlow
extends Control
## The screens in front of the carousel, over its background: the welcome at each start, while the
## library loads, until a button is pressed; on a first launch the button style, then the curtain
## permission when Android does not allow it yet; while no console has games, "No console" and the
## form adding one, then the discovery of the console added. Later, the settings (Y): the platforms
## set up, each to change or remove, the button style and the edges' smoothing; and the form adding
## one more console (the "+" above the consoles). One screen shows at a time, with the focus on it.
## Closes once the carousel can be used.

## The first console was added: [param library] is the library with its games.
signal library_changed(library: AndroidServices.Library)
## One more console was added from the consoles screen, [param platform_id]: [param library] has
## its games.
signal console_added(library: AndroidServices.Library, platform_id: String)
## A console was saved or removed in the settings: [param library] is the library now.
signal library_edited(library: AndroidServices.Library)
## The welcome, which has no top bar, is over.
signal welcome_closed
## A screen shows, over the carousel's background: the carousel shows nothing else meanwhile.
signal covering

## Seconds the discovery plays before the carousel is set up behind it.
const _LIBRARY_AFTER_S := 1.15

## Whether the welcome waits for a button; off to measure starts.
@export var welcome_waits := true

var android: AndroidServices = Android:
	set(services):
		android = services
		if is_node_ready():
			_permission.android = services
			_add_console.android = services
## The consoles' names, as the carousel shows them.
var appearance: Appearance
## The console of a platform (by id) as the carousel shows it: a [Node3D], its model or medium.
var console_of: Callable
## Where the consoles screen shows the selected console, on the screen.
var console_point := Vector2(640, 478)
## The library as the carousel shows it, kept up to date by the screens that change it.
var library: AndroidServices.Library

## Whether the settings open now left no console with games at some point.
var _emptied := false

@onready var _welcome: Welcome = %Welcome
@onready var _button_style: ButtonStyleScreen = %ButtonStyle
@onready var _edge_smoothing: EdgeSmoothingScreen = %EdgeSmoothing
@onready var _permission: CurtainPermission = %Permission
@onready var _no_console: NoConsole = %NoConsole
@onready var _add_console: AddConsole = %AddConsole
@onready var _discovery: Discovery = %Discovery
@onready var _settings: SettingsMenu = %Settings
@onready var _platforms: PlatformList = %Platforms
@onready var _confirm: ConfirmRemoval = %Confirm


## Goes on from the welcome as [param settings] and [member library] say; returns once the
## carousel can be used.
func run(settings: AndroidServices.SettingsAnswer) -> void:
	if welcome_waits:
		await _welcome.passed()
	# Shown once per start: what it holds (its worm, its large glyphs) is let go.
	_welcome.queue_free()
	welcome_closed.emit()
	if settings.first_launch:
		await _choose_button_style()
		if not android.curtain_allowed():
			_show(_permission)
			_permission.focus()
			await _permission.done
	if not _has_games():
		await _add_first_console()
	_close()


## The settings over the carousel, until B closes them; then, when no console has games any more,
## "No console" until one is added. Returns whether the carousel must come in again: it was left
## with no console meanwhile.
func open_settings() -> bool:
	_emptied = false
	await _settings_menu()
	if not _has_games():
		await _add_first_console()
	_close()
	return _emptied


## The form adding one more console, over the carousel, until it is added or given up.
func add_console() -> void:
	_show(_add_console)
	_add_console.open(library.set_up_platforms())
	if await _form_closed() == AddConsole.Outcome.DONE:
		library = _add_console.library
		console_added.emit(library, _add_console.platform_id)
	_close()


## Whether a screen plays an animation of its own: the discovery of a console added.
func is_playing() -> bool:
	return visible and _discovery.is_processing()


func _close() -> void:
	Diagnostics.trace("screens", "closed")
	hide()
	_discovery.let_go()


func _has_games() -> bool:
	return not library.shelves.is_empty()


## The button style, saved once chosen; with [param can_go_back], B leaves it as it was.
func _choose_button_style(can_go_back := false) -> void:
	_show(_button_style)
	_button_style.can_go_back = can_go_back
	_button_style.focus()
	var style: StringName = await _button_style.chosen
	if style.is_empty():
		return
	Controls.style = style
	get_tree().call_group(ButtonGlyph.GROUP, &"queue_redraw")
	var saved := await android.save_button_style(style)
	if not saved.ok:
		Diagnostics.trace("screens", "button style not saved (%s): %s" % [saved.code, saved.detail])


## The edges' smoothing, drawn and saved once chosen; B leaves it as it was.
func _choose_edge_smoothing() -> void:
	_show(_edge_smoothing)
	_edge_smoothing.focus()
	var smoothing: StringName = await _edge_smoothing.chosen
	if smoothing.is_empty():
		return
	get_viewport().msaa_3d = EdgeSmoothingScreen.MSAA[smoothing]
	var saved := await android.save_edge_smoothing(smoothing)
	if not saved.ok:
		Diagnostics.trace("screens", "edge smoothing not saved (%s): %s" % [saved.code, saved.detail])


## "No console" until the form adds one, then its discovery. Returns at once when a console of
## the settings finds games.
func _add_first_console() -> void:
	while true:
		_show(_no_console)
		_no_console.focus()
		if await _no_console.chosen == &"settings":
			await _settings_menu()
			if _has_games():
				return
			continue
		_show(_add_console)
		_add_console.open(library.set_up_platforms())
		if await _form_closed() == AddConsole.Outcome.DONE:
			break
	library = _add_console.library
	var platform_id := _add_console.platform_id
	var console: Node3D = console_of.call(platform_id)
	_discovery.prepare(console, console_point)
	# Drawn behind the form, before the discovery starts: its first frames must not wait for it.
	await get_tree().process_frame
	await get_tree().process_frame
	_show(_discovery)
	var manifest := appearance.console_of(platform_id)
	_discovery.play(manifest.name if manifest else _add_console.platform_name())
	# Once the sticker has settled: setting the carousel up behind it takes a few frames, which the
	# burst must not miss.
	await get_tree().create_timer(_LIBRARY_AFTER_S).timeout
	library_changed.emit(library)
	await _discovery.finished
	await _discovery.collapse()


## "Settings" until B, or until no platform is set up any more.
func _settings_menu() -> void:
	# The form editing a platform counts its games as it opens: what that needs is prepared meanwhile.
	android.prepare_titles()
	var focus := &"platforms"
	while true:
		_show(_settings)
		_settings.open(_platforms_set_up().size(), focus)
		focus = await _settings.chosen
		match focus:
			&"close":
				return
			&"button_style":
				await _choose_button_style(true)
			&"graphics":
				await _choose_edge_smoothing()
			&"platforms":
				await _platform_menu()
				if library.set_up_platforms().is_empty():
					return


## "Platforms" until B, or until none is left.
func _platform_menu() -> void:
	var at := 0
	while true:
		var platforms := _platforms_set_up()
		if platforms.is_empty():
			return
		_show(_platforms)
		_platforms.open(platforms, at)
		at = await _platforms.chosen
		if at < 0:
			return
		await _edit_platform(platforms[at])


## The platforms set up, in catalog order.
func _platforms_set_up() -> Array[AndroidServices.Platform]:
	var ids := library.set_up_platforms()
	return android.catalog.platforms.filter(func(platform: AndroidServices.Platform) -> bool:
		return platform.id in ids)


## The form editing [param platform], until it is saved, given up, or the console removed.
func _edit_platform(platform: AndroidServices.Platform) -> void:
	var setup := library.setup_of(platform.id)
	var folder := await _folder_of(setup)
	var others := PackedStringArray(Array(library.set_up_platforms()).filter(func(id: String) -> bool:
		return id != platform.id))
	_show(_add_console)
	_add_console.edit(platform.id, setup, folder, others)
	while await _form_closed() == AddConsole.Outcome.REMOVE:
		_show(_confirm)
		_confirm.open(platform.name, library.games_of(platform.id).size(), folder.volume if folder.has_place else &"")
		if await _confirm.answered:
			var removed := await android.remove_platform(platform.id)
			if removed.ok:
				_edited(removed.library)
				return
			Diagnostics.trace("screens", "%s not removed (%s): %s" % [platform.id, removed.code, removed.detail])
			_show(_add_console)
			_add_console.back_from_removal(true)
		else:
			_show(_add_console)
			_add_console.back_from_removal(false)


## How the form closed, once what it saved is taken: a console added is shown by the caller (its
## discovery, or the consoles coming back on it).
func _form_closed() -> AddConsole.Outcome:
	var outcome: AddConsole.Outcome = await _add_console.closed
	if _add_console.library != null and (outcome != AddConsole.Outcome.DONE or _add_console.is_editing()):
		_edited(_add_console.library)
	return outcome


## The folder of [param setup] as Android describes it, or as its address names it when its
## access is gone or cannot be listed now.
func _folder_of(setup: AndroidServices.PlatformSetup) -> AndroidServices.Folder:
	var kept := await android.persisted_folders()
	for folder in kept.folders:
		if folder.uri == setup.folder_uri:
			return folder
	return AndroidServices.Folder.new({"uri": setup.folder_uri, "name": setup.folder_uri.uri_decode().get_file()})


func _edited(changed: AndroidServices.Library) -> void:
	library = changed
	_emptied = _emptied or not _has_games()
	library_edited.emit(changed)


func _show(screen: Control) -> void:
	for child: Control in get_children():
		child.visible = child == screen
	show()
	covering.emit()
	Diagnostics.trace("screens", "showing %s" % screen.name)
