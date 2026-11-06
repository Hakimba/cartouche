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
| `app/adapters/android/android_services.gd` | `AndroidServices`, the `Android` autoload: the only code that calls the plugin. Getters return typed values. Operations are coroutines (`await Android.pick_folder()`). Everything the plugin sends arrives as JSON text, read here into `AndroidWire`'s classes. |
| `app/adapters/android/android_wire.gd` | `AndroidWire`: one class per type the plugin sends (`Game`, `Library`, `SettingsAnswer`…), generated from `Sent.kt` by `WireScriptTest` (INV-23); only a class's `# By hand` lines are edited. `AndroidServices` names each one (`AndroidServices.Game`). |
| `app/adapters/desktop/desktop_plugin.gd` | `DesktopPlugin`: stands in for the plugin on a desktop or in the editor, with the plugin's method names, answering in the same JSON text. It answers from `app/dev/demo/desktop.json`, or from a device's data with `--snapshot=DIR`, and keeps the choices made in memory. A call it has no method for gets an empty value or fails as `unavailable`. |
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
| `button_style_screen.gd`, `edge_smoothing_screen.gd`, `backdrop_screen.gd` | A choice among cards (`ChoiceScreen`, `ChoiceCard`), each card drawing its choice (`StyleCard`, `SmoothingCard`, `BackdropCard`). A background chosen shows at once, the cards staying. |
| `card_choice_screen.gd` | A setting chosen among cards built from the values the plugin takes: the preferred region of images, the language. |
| `curtain_permission.gd` | Asks for "display over other apps", which the launch curtain needs. |
| `no_console.gd` | Nothing set up yet: one thing to do, add a console. |
| `add_console.gd` | The form adding a console, and editing one (X on the ring, titled Edit, its type locked, Remove at the far left): its type, its model, its folder, its emulator and options, with a count of the games found. Built from `StepField`, `FieldButton`, `FormToggle` and `FormPill`, drawn by `FormPaint`. |
| `model_field.gd`, `model_swatches.gd` | The form's Model line, and the swatches it opens: one picture of each model of the console, rendered once per opening, the console beside them changing as the focus moves. |
| `ring_view.gd` | The form's left zone: the console alone, standing as on the ring, seen by a copy of the carousel's camera. |
| `add_ball.gd` | The "+" above the consoles. Holding up turns it into the button adding one more console. |
| `settings_menu.gd` | The settings card: the choices, the background and its animated veil, games floating, the sound level and the language, each row built from its entry in `ROWS` ([../adding-a-setting.md](../adding-a-setting.md)). Six lines show; the focus scrolls the others in, an arrow showing lines are hidden. |
| `settings_transition.gd` | The move between the screen under the settings and the settings card, on one reversible clock. |
| `confirm_removal.gd` | The confirmation of a console's removal. |
| `controls.gd` | The button style the user chose. `ButtonGlyph`, `ButtonMark`, `ButtonHint` and `GlyphButton` draw buttons in that style. |

### Adding a screen

The whole guide, gestures and tests included, is [../adding-a-screen.md](../adding-a-screen.md). In short:

1. Make the scene and its script under `app/screens/`. Put its hints in a `HintRow` and draw it with the
   Studio pieces ([studio.md](studio.md)).
2. Show it from `ScreenFlow`, and say when it is done.
3. If its focus moves with directions, add it to the `SoundEffects.MOVES` group ([../sounds.md](../sounds.md)).
4. If it ignores presses while it moves, name its guard flag in `_GUARDS` of `app/test/screens/fixtures.gd`. The
   walk of presses in `live_screen_test.gd` then checks it never leaves a dead screen (INV-20).
5. Text the user reads goes through `tr()` and into `app/locale/` ([../translating.md](../translating.md)).

## The carousel

Under `app/carousel/`. `Carousel` (`carousel.gd`) is the main scene's script: the consoles screen, the games
screen, going from one to the other, launching, the properties, and remembering the selection.

| File | Responsibility |
|---|---|
| `carousel.gd` | The screens and their input: pad, keys, touch, the system's back. One state says who holds the presses (the carousel, a press waiting for the row, the screens in front, the add form's steps), one table what the carousel takes on each screen. Where the user was is saved before going out of a console, launching or leaving the app. |
| `carousel_layout.gd` | `CarouselLayout`: the carousel's screen mechanics as pure functions (which game stands where, how a held direction repeats, `Repeat` for the row, the search ribbon and the model swatches). |
| `held_direction.gd` | `HeldDirection`: which way the carousel is held, from input events; also whether up is held, so that a stick held up tosses once. |
| `finger.gd` | `Finger`: the first finger read as a tap, a long press, a drag or a flick. A swipe moves exactly one game or console. |
| `stick_turn.gd` | `StickTurn`: the right stick or a finger turning the selected console or game. |
| `shelf_row.gd` | `ShelfRow`: the games row. It recycles a fixed pool of places, so its cost does not grow with the library. It keeps a pick drawn ahead, another game of the list shown; the labels it lands among, its own and its neighbours', are read as the row comes to rest on the games screen and again as a toss starts, so that they are among the textures `GameArt` keeps when it lands. |
| `game_toss.gd` | `GameToss`: up, or a flick up from the game, tosses it like a coin to land as the pick; its steps are one table. No press nor finger acts while it is in the air. |
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
| `console_manifest.gd` | What a console folder tells the app. |
| `console_model.gd`, `console_part.gd`, `seat_shape.gd` | `ConsoleModel`, the one contract every console meets, declared as data in its scene: its seat, way in, pose and moving parts. [../adding-a-console.md](../adding-a-console.md) describes them. |
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

### New games

Under `app/carousel/new_games/`. As the app starts and each time it comes back to the screen, `NewGames`
(`new_games.gd`) reads every console's folder again, one request a console, and keeps the library a re-read changed
until the carousel is free (no launch, move, screen in front, ring, toss or search ribbon): then each shelf keeps the
game in its middle. A library the plugin wrote again meanwhile (a name, a label, an order, a form) is asked for anew
rather than shown; one with no game left leads to "No console". The rail tile's `RailBadge` tells the new games of a console until it is entered;
`NewGameDots` (`new_game_dots.gd`) draws a glowing dot over each new game of the row until it is left.

### Properties

Under `app/carousel/properties/`. X on a game (its hint reads Edit), or a long press, opens its properties.

| File | Responsibility |
|---|---|
| `properties_screen.gd` | `PropertiesScreen`: a game's model staged under the light and the moves between its editors. |
| `disc_properties.gd` | A game's properties: its label (the images on offer, a picture of the user's own and its framing) and its name. |
| `name_editor.gd`, `gamepad_keyboard.gd` | A name typed with the stick or the d-pad. |
| `label_zone.gd`, `label_card.gd`, `label_framing.gd`, `focus_callout.gd` | The label's outline, one image on offer, the framing of a picture, the caption of the focused zone. |
| `operating_light.gd` | The light over the staged model. |

### Models and shaders

Under `app/carousel/models/`: what medium models are built from, and what consoles share (`Spindle`). `ModelShape` holds a model's
dimensions in millimetres and the rules they must keep. Each `ShapedMesh` is one part built from them, through
`MeshBuilder` and the pieces of `ShapeGeometry`. An exported app finds every part already built: the export plugin
`app/addons/cartouche_dev/shaped_mesh_export.gd` stores the arrays the code builds, so the code stays their only
source and the app does not build them at start. The cartridges that are more than a box, and the first consoles,
are `ArrayMesh` files in their folders: their scenes draw those, with no code behind them. `ModelFade` fades a model on the mobile renderer, which ignores
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
once still and names the nodes still writing; the bench's `idle` scenarios report `drawn_per_s` and the GPU's
`gpu_ms_per_s`. The one exception is the background's pixel veil, on by default: while it moves, the shown
`Cyclorama` writes its time at every frame, so a resting screen is drawn again thirty times a second, whole (Godot
redraws a viewport whole). Only the backdrop in front moves: the carousel's stops under a screen that draws its own
(adding a console, the consoles set up, the model chooser), and none moves while hidden. With the veil off, rest
draws nothing.

## Developer tools in the app

| File | Responsibility |
|---|---|
| `app/dev/diagnostics.gd` | `Diagnostics`: debug traces, the memory the engine holds (`memory`, traced at each lifecycle change and at each new peak of graphics memory), and the debug arguments (`argument`, `flag`). See [../README.md](../README.md#diagnostics-and-debug-arguments). |
| `app/dev/carousel_bench.gd` | `CarouselBench`: drives the carousel like a user for `scripts/bench.sh`, one scenario per run. |
| `app/dev/frame_shots.gd` | `FrameShots`: pictures at set frames, to prove a change keeps every pixel ([../testing.md](../testing.md#pictures-and-benchmarks)). |
| `app/dev/dev_sounds.gd` | `DevSounds`: sounds dropped by hand into the user folder, to try a launch's sounds. |
| `app/dev/bridge/` | The debug bridge, left out of release builds. See [../debug-bridge.md](../debug-bridge.md). |
| `app/addons/cartouche_android/` | Adds the plugin's AARs and dependencies to Android exports. Versions are declared once, in `kotlin/gradle/libs.versions.toml`. |
| `app/addons/cartouche_dev/` | Leaves `app/dev/bridge/` out of release exports. `scripts/check_release.sh` checks a real release pack. |

## Neighbours

- Down: [android.md](android.md), reached only through the adapter.
- Beside: [studio.md](studio.md), the look; [../sounds.md](../sounds.md), the sounds.
- Folders: [../adding-a-console.md](../adding-a-console.md), [../adding-a-medium.md](../adding-a-medium.md).
- Tests: [../testing.md](../testing.md#gdscript). The words: [../GLOSSARY.md](../GLOSSARY.md).
- Back to the entry: [../README.md](../README.md).
