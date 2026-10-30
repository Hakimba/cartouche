# SPDX-License-Identifier: GPL-3.0-or-later
class_name ScreenFlow
extends Control
## The screens in front of the carousel, over its background: on a first launch, the welcome until a
## button is pressed, the button style and image region, then the curtain
## permission when Android does not allow it yet; while no console has games, "No console" and the
## form adding one and its arrival on the carousel. Later, the settings (Y): the platforms
## set up, each to change or remove, the button style, the edges' smoothing and the region labels'
## images prefer; and the form adding
## one more console (the "+" above the consoles). One screen shows at a time, with the focus on it.
## Closes once the carousel can be used.

## A console was saved or removed in the settings: [param library] is the library now.
signal library_edited(library: AndroidServices.Library)
## The welcome, which has no top bar, is over.
signal welcome_closed
## A screen shows, over the carousel's background: the carousel shows nothing else meanwhile.
signal covering
## The form adding a console, given up, starts to go.
signal form_leaving

## Whether the first launch's welcome waits for a button; off to measure starts.
@export var welcome_waits := true

var android: AndroidServices = Android:
	set(services):
		android = services
		if is_node_ready():
			_permission.android = services
			_add_console.android = services
## Brings the added console to the hero, through the placing ring from the third console
## ([code](library, platform_id) -> bool[/code]): true once placed, false when the user goes back to the form, which
## comes back ([method bring_back_form]) as the console flies to it. Required before [method run].
var place: Callable
## Where the consoles screen shows the selected console, on the screen.
var console_point := Vector2(640, 478)
## The library as the carousel shows it, kept up to date by the screens that change it.
var library: AndroidServices.Library

## The current flow has already brought its added console to the hero position.
var arrived := false

## Whether the settings open now left no console with games at some point.
var _emptied := false
var _holding_presses := false
var _games_float := false
var _float_save := 0
## The region labels' images prefer, as stored (empty for none), and those the plugin takes.
var _preferred_region := ""
var _preferred_regions: PackedStringArray

@onready var _welcome: Welcome = %Welcome
@onready var _button_style: ButtonStyleScreen = %ButtonStyle
@onready var _edge_smoothing: EdgeSmoothingScreen = %EdgeSmoothing
@onready var _permission: CurtainPermission = %Permission
@onready var _no_console: NoConsole = %NoConsole
@onready var _add_console: AddConsole = %AddConsole
@onready var _region_screen: PreferredRegionScreen = %PreferredRegion
@onready var _pending: Label = %Saving
@onready var _settings: SettingsMenu = %Settings
@onready var _platforms: PlatformList = %Platforms
@onready var _confirm: ConfirmRemoval = %Confirm


func _ready() -> void:
	_settings.sound_level_changed.connect(_change_sound_level)
	_add_console.saving.connect(func(pending: bool) -> void:
		_pending.visible = pending
		_holding_presses = pending)


## Goes on until the library can be used, completing setup on first launch, the welcome first.
func run(settings: AndroidServices.SettingsAnswer) -> void:
	arrived = false
	_games_float = settings.games_float
	Sounds.level = settings.sound_level
	_preferred_region = settings.preferred_region
	_preferred_regions = settings.preferred_regions
	if settings.first_launch and welcome_waits:
		_welcome.show()
		await _welcome.passed()
	# Shown once: what it holds (its worm, its large glyphs) is let go.
	_welcome.queue_free()
	welcome_closed.emit()
	if settings.first_launch:
		await _choose_button_style(false, false)
		await _choose_preferred_region(true)
		await _save_button_style(Controls.style)
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
	arrived = false
	_emptied = false
	await _settings_menu()
	if not _has_games():
		await _add_first_console()
	_close()
	return _emptied


## The form adding one more console, over the carousel, until it is added and placed, or given up; whether one was.
func add_console() -> bool:
	_show(_add_console)
	_add_console.open(library.set_up_platforms())
	if not _add_console.leaving.is_connected(form_leaving.emit):
		_add_console.leaving.connect(form_leaving.emit)
	var added := false
	while not added and await _form_closed() == AddConsole.Outcome.DONE:
		library = _add_console.library
		var platform_id := _add_console.platform_id
		added = await place.call(library, platform_id)
		_holding_presses = false
	_close()
	return added


## The form shows again, filled as it was, as the console flies back to it; it takes no press until the console is back.
func bring_back_form() -> void:
	show()
	_holding_presses = true
	_add_console.resume()


## The form's presses are held while the console flies back to it.
func _input(event: InputEvent) -> void:
	if _holding_presses and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventAction
			or event is InputEventScreenTouch or event is InputEventMouseButton):
		get_viewport().set_input_as_handled()


## Whether the form is leaving while its save or scan is pending.
func is_playing() -> bool:
	return _pending.visible


func _close() -> void:
	Diagnostics.trace("screens", "closed")
	hide()
	_pending.hide()


func _has_games() -> bool:
	return not library.shelves.is_empty()


## The button style, saved once chosen; with [param can_go_back], B leaves it as it was.
func _choose_button_style(can_go_back := false, keep := true) -> void:
	_show(_button_style)
	_button_style.can_go_back = can_go_back
	_button_style.focus()
	var style: StringName = await _button_style.chosen
	if style.is_empty():
		return
	Controls.style = style
	get_tree().call_group(ButtonGlyph.GROUP, &"queue_redraw")
	if keep:
		await _save_button_style(style)


## Button style marks setup complete, so first launch saves it after the region choice.
func _save_button_style(style: StringName) -> void:
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


## The region labels' images prefer, saved once another is chosen, and shown once saved: the plugin
## looks again for the labels it changes.
func _choose_preferred_region(first_launch := false) -> void:
	_show(_region_screen)
	_region_screen.can_go_back = not first_launch
	_region_screen.open(_preferred_region, _preferred_regions)
	var region: String = await _region_screen.chosen
	if region == _preferred_region and not first_launch:
		return
	_holding_presses = true
	var saved := await android.save_preferred_region(region)
	_holding_presses = false
	if saved.ok or first_launch:
		_preferred_region = region
	if not saved.ok:
		Diagnostics.trace("screens", "preferred region not saved (%s): %s" % [saved.code, saved.detail])


## "No console" until the form adds one and it glides to the carousel. Returns at once when a console of
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
	arrived = await place.call(library, platform_id)


## "Settings" until B, or until no platform is set up any more.
func _settings_menu() -> void:
	# The form editing a platform counts its games as it opens: what that needs is prepared meanwhile.
	android.prepare_titles()
	_settings.games_float = _games_float
	_settings.sound_level = Sounds.level
	var focus := &"platforms"
	while true:
		if focus != &"games_float":
			_show(_settings)
			_settings.open(_platforms_set_up().size(), focus, _preferred_region)
		focus = await _settings.chosen
		match focus:
			&"close":
				_float_save += 1
				_settings.animate_float(_games_float)
				_settings.saving = false
				return
			&"button_style":
				await _choose_button_style(true)
			&"graphics":
				await _choose_edge_smoothing()
			&"region":
				await _choose_preferred_region()
			&"games_float":
				_choose_games_float()
			&"platforms":
				await _platform_menu()
				if library.set_up_platforms().is_empty():
					return


## The sounds at [param steps] at once, heard so, and kept.
func _change_sound_level(steps: int) -> void:
	Sounds.level = steps
	Sounds.play(SoundEffects.Cue.VOLUME)
	var saved := await android.save_sound_level(steps)
	if not saved.ok:
		Diagnostics.trace("settings", "sound level not saved (%s): %s" % [saved.code, saved.detail])


func _choose_games_float() -> void:
	_float_save += 1
	var request := _float_save
	var target := not _games_float
	Sounds.play(SoundEffects.Cue.TOGGLE if target else SoundEffects.Cue.UNTOGGLE)
	_settings.saving = true
	_settings.animate_float(target)
	var saved := await android.save_games_float(target)
	if request != _float_save:
		return
	if saved.ok:
		_games_float = target
		Diagnostics.trace("settings", "games_float=%s" % str(target))
	else:
		Diagnostics.trace("settings", "games_float not saved (%s): %s" % [saved.code, saved.detail])
	_settings.animate_float(_games_float)
	_settings.saving = false


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
## arrival on the carousel, or the consoles coming back on it).
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
