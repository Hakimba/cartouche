# The Godot shell (`app/`)

**You are here.** The Godot project draws every screen, reads every press and plays every animation and sound. It
holds no domain rule: what a game is, which file to launch, which image to show, all come from the plugin
([android.md](android.md)) through one adapter. The shared look of every screen (materials, text, motion, the
backdrop) has its own page, [studio.md](studio.md). Consoles and media are folders with their own pages,
[../adding-a-console.md](../adding-a-console.md) and [../adding-a-medium.md](../adding-a-medium.md).

The main scene is `app/carousel/carousel.tscn`. Three autoloads start before it (`app/project.godot`):
`Diagnostics` (`app/dev/diagnostics.gd`), `Android` (`app/adapters/android/android_services.gd`) and `Sounds`
(`app/audio/sound_effects.gd`).

## The adapter

| File | Responsibility |
|---|---|
| `app/adapters/android/android_services.gd` | `AndroidServices`, the `Android` autoload: the only code that calls the plugin. Getters return typed values. Operations are coroutines (`await Android.list_folder(folder)`). |
| `app/adapters/android/android_wire.gd` | `AndroidWire`: one class per answer of the plugin (`Game`, `Library`, `SettingsAnswer`…), read from its wire Dictionary. `AndroidServices` names each one (`AndroidServices.Game`). |
| `app/adapters/desktop/desktop_plugin.gd` | `DesktopPlugin`: stands in for the plugin on a desktop or in the editor, with the plugin's method names. It answers from `app/dev/demo/desktop.json`, or from a device's data with `--snapshot=DIR`, and keeps the choices made in memory. A call it has no method for gets an empty value or fails as `unavailable`. |
| `app/adapters/android/android_buttons.gd` | `AndroidButtons`: makes A confirm and B go back as Android names the buttons, whatever Godot's controller database says. |

`desktop.json` is what the plugin would send for a demo library. `DesktopDemoTest` (Kotlin) fails when it is out
of date and writes the new one. GDScript tests fake the plugin by subclassing `AndroidServices` (see
[../testing.md](../testing.md#gdscript)).

## The screens

Under `app/screens/`. `ScreenFlow` (`screen_flow.gd`, in `screens.tscn`) shows one screen at a time in front of the
carousel, and returns once the carousel can be used. Each screen is a scene of its own that says when it is done.

| File | Responsibility |
|---|---|
| `screen_flow.gd` | Which screen shows when: the first launch, the empty library, the settings, adding one more console. Reads the settings at start and saves the user's changes through the adapter. |
| `welcome.gd` | The title screen at each start, waiting for a button while the app loads. |
| `button_style_screen.gd`, `preferred_region_screen.gd`, `edge_smoothing_screen.gd` | A choice among cards (`ChoiceScreen`, `ChoiceCard`), each card drawing its choice (`StyleCard`, `SmoothingCard`). |
| `curtain_permission.gd` | Asks for "display over other apps", which the launch curtain needs. |
| `no_console.gd` | Nothing set up yet: one thing to do, add a console. |
| `add_console.gd` | The form adding or editing a console: its type, its model, its folder, its emulator and options, with a count of the games found. Built from `StepField`, `FieldButton`, `FormToggle` and `FormPill`, drawn by `FormPaint`. |
| `add_ball.gd` | The "+" above the consoles. Holding up turns it into the button adding one more console. |
| `settings_menu.gd` | The settings card: the choices, games floating and the sound level. |
| `settings_transition.gd` | The move between the screen under the settings and the settings card, on one reversible clock. |
| `platform_list.gd`, `confirm_removal.gd` | The consoles set up, each opened in the form to edit or remove it, and the confirmation of a removal. |
| `controls.gd` | The button style the user chose. `ButtonGlyph`, `ButtonMark`, `ButtonHint` and `GlyphButton` draw buttons in that style. |

### Adding a screen

1. Make the scene and its script under `app/screens/`. Put its hints in a `HintRow` and draw it with the
   Studio pieces ([studio.md](studio.md)).
2. Show it from `ScreenFlow`, and say when it is done.
3. If its focus moves with directions, add it to the `SoundEffects.MOVES` group ([../sounds.md](../sounds.md)).
4. If it ignores presses while it moves, name its guard flag in `_GUARDS` of `app/test/screens/fixtures.gd`. The
   walk of presses in `live_screen_test.gd` then checks it never leaves a dead screen (INV-20).
5. Text the user reads goes through `tr()` and into `app/locale/`.

## The carousel

Under `app/carousel/`. `Carousel` (`carousel.gd`) is the main scene's script: the consoles screen, the games
screen, going from one to the other, launching, the properties, and remembering the selection.

| File | Responsibility |
|---|---|
| `carousel.gd` | The screens and their input: pad, keys, touch, the system's back. Where the user was is saved before going out of a console, launching or leaving the app. |
| `carousel_layout.gd` | `CarouselLayout`: the carousel's screen mechanics as pure functions (which game stands where, how a held direction repeats). |
| `held_direction.gd` | `HeldDirection`: which way the carousel is held, from input events. |
| `finger.gd` | `Finger`: the first finger read as a tap, a long press or a drag. A swipe moves exactly one game or console. |
| `stick_turn.gd` | `StickTurn`: the right stick or a finger turning the selected console or game. |
| `shelf_row.gd` | `ShelfRow`: the games row. It recycles a fixed pool of places, so its cost does not grow with the library. |
| `game_art.gd`, `image_reader.gd` | `GameArt` reads the stored label images on a worker thread, one texture sent to the GPU per frame (`ImageReader`). |
| `progress_ring.gd` | The ring filling on a blank label while its image downloads. |
| `art_bar.gd`, `battery_chip.gd` | The scraping progress beside the hints, and the battery in the top bar. |
| `appearance.gd` | `Appearance`: reads `app/data/carousel/appearance.json` and finds the console and medium folders. Loads a model only when a library needs it. |
| `resting.gd` | `Resting`: see [Resting](#resting). |

### Search

`app/carousel/search/game_search.gd` (`GameSearch`) is the ribbon that down opens under the games: the index by
letter or region, and the search as keys are typed. It asks the plugin for each view (`browse`) and shows it with
`ShelfRow`. `title_marks.gd` underlines the words found in the title. The rules live in the core's `Finder`
([core.md](core.md#shelves-and-search)).

### Consoles

Under `app/carousel/consoles/`. One folder per console model, plus the code they share.

| File | Responsibility |
|---|---|
| `console_manifest.gd`, `console_model.gd`, `moving_part.gd` | What a console folder tells the app, and the contract every console model meets. [../adding-a-console.md](../adding-a-console.md) describes them. |
| `console_row.gd` | `ConsoleRow`: the consoles screen. The selected console stands alone in its pose, and moves in and out as the selection changes. |
| `launch_animation.gd` | `LaunchAnimation`: turns a console's steps (`launch.json`) into a Godot `Animation`. A console without steps plays a placeholder made from its moving parts. |
| `console_sequence.gd` | `ConsoleSequence`: plays that animation into and out of the games screen. |
| `console_layer.gd` | `ConsoleLayer`: the consoles drawn apart and blurred behind the games. |
| `console_order.gd`, `console_wheel.gd` | The ring putting the consoles in order. `ConsoleWheel` is its rule, pure. |
| `console_sticker.gd` | The console held on the ring, drawn as a sticker. |

### Launches

Under `app/carousel/launch/`. `GameLaunch` (`game_launch.gd`) runs a launch from A to the carousel shown again:
the check, the console's launch animation or the medium's insertion, the plugin's launch, and the return.
`Insertion` (`insertion.gd`) is the insertion's motion as pure functions of time, its values per media kind in
`app/data/carousel/appearance.json`. INV-21 holds that the carousel always comes back as it was.

### Properties

Under `app/carousel/properties/`. X on a game, or a long press, opens its properties.

| File | Responsibility |
|---|---|
| `properties_screen.gd` | `PropertiesScreen`: what a game's and a console's properties share, the staging under the light and the moves between editors. |
| `disc_properties.gd` | A game's properties: its label (the images on offer, a picture of the user's own and its framing) and its name. |
| `console_properties.gd` | A console's properties: its model, and the way to the ordering ring. |
| `name_editor.gd`, `gamepad_keyboard.gd` | A name typed with the stick or the d-pad. |
| `label_zone.gd`, `label_card.gd`, `label_framing.gd`, `focus_callout.gd` | The label's outline, one image on offer, the framing of a picture, the caption of the focused zone. |
| `operating_light.gd` | The light over the staged model. |

### Models and shaders

Under `app/carousel/models/`: what console and medium models are built from. `ModelShape` holds a model's
dimensions in millimetres and the rules they must keep. Each `ShapedMesh` is one part built from them, through
`MeshBuilder` and the pieces of `ShapeGeometry`. An exported app finds every part already built: the export plugin
`app/addons/cartouche_dev/shaped_mesh_export.gd` stores the arrays the code builds, so the code stays their only
source and the app does not build them at start. `ModelFade` fades a model on the mobile renderer, which ignores
per-instance transparency: a faded model draws with the `*_fading.gdshader` copies of its shaders. Every distinct
material is a shader the GPU driver keeps, so models share `solid.gdshader`, `label.gdshader` and the few others
here rather than standard materials.

## Resting

`Resting` (`app/carousel/resting.gd`) lets the app rest when nothing happens. After a few seconds without a press,
Godot's low processor mode draws only what changes. Later, whatever moves by itself (the nodes of the group
`paced`) slows to a stop, and the screen is drawn only when something on it changes. The first press wakes
everything and acts as usual (INV-20). Anything new that moves on its own joins the `paced` group, or keeps the app
awake while it plays (`Resting.moving`). Once still, and as the app leaves the screen, `Resting` asks the plugin to
hand the memory Godot freed back to the system (`Android.release_memory`, see [android.md](android.md)).

"Draws only what changes" means: a frame is drawn when anything wrote to the renderer since the last one, even a
value equal to the one it had (a z-index, a light's place, a viewport's update mode, a float the engine keeps in
single precision). Code that runs at every frame writes only what changed. `at_rest_test.gd` checks each screen
once still and names the nodes still writing; the bench's `idle` scenarios report `drawn_per_s`.

## Developer tools in the app

| File | Responsibility |
|---|---|
| `app/dev/diagnostics.gd` | `Diagnostics`: debug traces, the memory the engine holds (`memory`, traced at each lifecycle change and at each new peak of graphics memory), and the debug arguments (`argument`, `flag`). See [../ONBOARDING.md](../ONBOARDING.md#diagnostics-and-debug-arguments). |
| `app/dev/carousel_bench.gd` | `CarouselBench`: drives the carousel like a user for `dev/bench.sh`, one scenario per run. |
| `app/dev/frame_shots.gd` | `FrameShots`: pictures at set frames, to prove a change keeps every pixel ([../testing.md](../testing.md#pictures-and-benchmarks)). |
| `app/dev/dev_sounds.gd` | `DevSounds`: sounds dropped by hand into the user folder, to try a launch's sounds. |
| `app/dev/device_check/` | The device check: one tab per device capability (storage, launch, library, pad, performance). |
| `app/dev/bridge/` | The debug bridge, left out of release builds. See [../debug-bridge.md](../debug-bridge.md). |
| `app/addons/cartouche_android/` | Adds the plugin's AARs and dependencies to Android exports. Versions are declared once, in `kotlin/gradle/libs.versions.toml`. |
| `app/addons/cartouche_dev/` | Leaves `app/dev/bridge/` out of release exports. `dev/check_release.sh` checks a real release pack. |

## Neighbours

- Down: [android.md](android.md), reached only through the adapter.
- Beside: [studio.md](studio.md), the look; [../sounds.md](../sounds.md), the sounds.
- Folders: [../adding-a-console.md](../adding-a-console.md), [../adding-a-medium.md](../adding-a-medium.md).
- Tests: [../testing.md](../testing.md#gdscript). The words: [../GLOSSARY.md](../GLOSSARY.md).
- Back to the entry: [../ONBOARDING.md](../ONBOARDING.md).
