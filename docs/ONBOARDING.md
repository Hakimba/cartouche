# Onboarding

How Cartouche is built and where to look before changing something. This document follows the
code: it only describes what exists.

## Architecture

```
┌──────────────────────────── app/ (Godot 4.7, GDScript) ─────────────────────────────┐
│  carousel/                the main screen: one shelf of games per platform          │
│  dev/device_check/        developer tool: one tab per device capability             │
│  adapters/android/        AndroidServices, the only code talking to the plugin      │
│  addons/cartouche_android bundles the Kotlin build into Android exports             │
│  data/platforms/          platform and emulator definitions (Daijishō, MIT)         │
│                           and Cartouche's own platform profiles                     │
│  data/redump/             disc titles and serials (libretro-database, CC BY-SA 4.0) │
│  data/carousel/           a model per media, label colours, the selected game's pose│
│  dev/demo/                the catalog and a demo library, to run without Android    │
│  test/                    GDScript tests (GdUnit4, fetched by dev/test_godot.sh)    │
└─────────────────────────────────────┬───────────────────────────────────────────────┘
                                      │ JNI: Dictionaries and one `answered` signal
┌──────────────────────────── kotlin/ (Gradle) ───────────────────────────────────────┐
│  android/   Godot Android plugin: folders, library file, intents, installed apps   │
│      └── depends on ──▶  core/   pure Kotlin: catalog, launches, library, shelves   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

- **`kotlin/core`** holds the domain rules as pure functions over immutable values: no Android, no
  IO, no `null`. Everything there is tested on the JVM, including property-based tests.
- **`kotlin/android`** adapts Android APIs and exposes the core to Godot. It holds the only state:
  the loaded catalog and reference lists, the library and the selection, the pending folder pick,
  and which apps are installed (until the next resume).
- **GDScript** is the UI shell: scenes, input and display, with no domain rules. The carousel's
  screen mechanics (which game stands where, how a held direction repeats) are pure functions in
  `CarouselLayout`, tested headless.

## Glossary

The same words are used in the code, the tests and this document.

- **Platform**: a console, as a Daijishō definition describes it (`ps2`). Its **profile** adds the
  **media** its games are shown as (DVD, cartridge, mini-disc) and the size under which an unknown
  file is not a game.
- **Player**: one way to run a platform's games, an emulator or a RetroArch core, with its launch
  **template** (`am start` arguments). The **catalog** holds every platform and player.
- **Game**: one entry of the library, made of one or more **discs** (files). It is **identified**
  when the platform's **reference list** (Redump titles and serials) knows it.
- **Scan**: listing a platform's folder (the **walk**), then sorting its files into games and
  **ignored files**. A file a player opens that is not taken for a game (a BIOS, too small) is kept
  as a **not-game**; hidden and unsupported files are only counted. A sub-folder the walk does not
  look into is a **skipped folder**: hidden, **emulator data** (`memcards`, `textures`…), too deep
  or unreadable.
- **Setup**: what the user chose for a platform (folder, player, disc grouping, sub-folders).
- **Library**: every platform's games, setup and last scan results, stored on the device.
- **Shelf**: one platform's games in the carousel, in title order. The **selection** remembers the
  platform shown last and each platform's selected game, and places the user back when the app
  starts.
- **Place**: one of the carousel's recycled slots, showing a game's **model** (the 3D media of
  its platform) with a **label** on it: an image of the real one, or the game's title drawn on the
  platform's label colour.
- **Shape**: the dimensions, in millimetres, a model is built from (`DiscShape`,
  `CartridgeShape`); each **part** of the model (label, mirror, shell) is a mesh built from them.
- **Pose**: how the selected game is shown, leaning back, turned and slowly swaying, so that the
  light moves over it. The right stick turns it further, as far as the user likes.
- **Launch check**: asking whether a game can start (its player's emulator is installed, its file
  still there) without starting or stopping anything, before its insertion plays.
- **Insertion**: how a game goes into its console once A is pressed, one per media: a disc turns
  to face the player, comes forward as if taken in hand, goes back onto the drive's **spindle**
  (the motor, turntable, hub and balls a disc clips onto), which spins it up; then the screen goes
  black from its centre.
- **Curtain**: a black window over every app, raised as the emulator starts and lowered once the
  emulator shows its game (a time per emulator) or the user is back, so that the emulator's own
  screens never show between the insertion's black and the game.
- **Demo library**: a made-up library of any size, in debug builds, for measuring at scale.
- **Wire format**: what crosses the JNI bridge between the plugin and GDScript.

## Components

### Core (`kotlin/core`)
- **`platforms/Catalog.kt`** parses Daijishō definition files (a `platform` and its `playerList`).
  A *player* is one way to run a platform's games: an emulator or a RetroArch core, plus its launch
  template. It also answers which players can open a file (`candidates`) and how a player opens a
  game (`launch`). Each platform also needs a profile (`data/platforms/profiles.json`): its media
  (DVD, cartridge, mini-disc) and the size under which an unknown file is not taken for a game.
  Adding a platform takes data only: a definition, a profile and, to identify its games, a
  reference list `data/redump/<platform id>.tsv` (made with `dev/redump_titles.py`).
- **`launch/LaunchTemplate.kt`**: Daijishō writes launches as `am start` arguments, such as
  `-n com.armsx2/.Main -a android.intent.action.VIEW -d {file.uri}`. The file documents the
  grammar. `parse` checks it once, then `resolve` fills `{file.uri}` and `{file.path}` in from a
  `GameFile`. Templates are third-party data: they cannot grant URI permissions, and the only
  content URI they can hand over is the game's.
- **`library/`** is the game library:
  - `GameName` reads names the Redump and No-Intro way (`Title (Region) (Languages) (Disc 2)`);
  - `TitleIndex` identifies a file by its name alone: as an exact reference disc, or as one disc of
    a release known by the serials all its versions share, or not at all (never a wrong serial);
  - `FolderWalk` lists a folder's files, and its sub-folders' when asked, through any `children`
    function: the Android plugin passes the documents provider, tests an in-memory tree. Hidden,
    too deep and unreadable sub-folders, and those named like emulator data
    (`data/scan/data_folders.json`), are skipped and reported; a walk stops with an error past
    10,000 entries, naming the folder that listed the most;
  - `Scan.of` sorts a folder's files into games (grouping multi-disc games) and ignored files;
  - `Library` holds each platform's games and choices (`PlatformSetup`), and merges a rescan
    without losing them. Hidden and unsupported files are only counted, so its size follows the
    games; `LibraryFormat` stores it as versioned JSON and reads earlier formats, which the plugin
    then saves again, upgraded.
- **`shelves/`** turns the library into what the carousel shows: `Shelves.of` makes one shelf per
  platform with games, in title order (a collator's order, then ids, so the same library always
  gives the same shelves), and restores the `Selection` on them; `SelectionFormat` stores the
  selection in its own small file, so remembering it costs the same whatever the size of the
  library.
- **`platforms/CurtainTimes.kt`** reads how long the curtain stays over each emulator
  (`data/launch/curtains.json`, milliseconds per package name, from 0 for none to 10 s): the time
  its own screens (splash, game list) take to give way to the game, measured on a device by
  recording the screen through a launch (`adb shell screenrecord`).
- **`library/DemoLibrary.kt`** makes up libraries of any size, the same for the same arguments.
- **`storage/DocumentPaths.kt`** maps document ids such as `1A2B-3C4D:ROMs/ps2` to paths such as
  `/storage/1A2B-3C4D/ROMs/ps2`.
- **`Values.kt`** holds the newtypes shared across modules: `PackageName`, `ContentUri` (built
  with `ContentUri.parse`, so it is always a `content://` URI), `FilePath`, `FileName`.

### Android plugin (`kotlin/android`)
- **`CartouchePlugin.kt`** is the only class Godot sees (the `CartoucheAndroid` singleton).
  Getters answer at once; operations answer later through the `answered` signal (threading is
  described in its header). `PendingPick` tracks the folder pick awaiting its activity result.
  In debug builds, `launchArguments` hands GDScript the `arguments` extra of the launch intent
  (`--demo-games=N`, `--bench=scroll`), and `useDemoLibrary` swaps the library for a demo one,
  stored apart from the user's.
- **`Wire.kt`** defines the Dictionary format and the stable error codes (`ErrorCode`). The
  library, with its shelves, travels as one JSON text instead: on a handheld, each Dictionary costs
  about 0.1 ms on Godot's main thread, so thousands of them freeze the screen, while Godot parses
  the JSON of a library in milliseconds. Lists follow INV-E0-16.
- **`launch/`** turns a resolved launch into a started activity:
  - `IntentMapper` builds the intent;
  - `Launcher` checks a game in the background (its emulator installed, its file still there:
    `checkGame`, which starts and stops nothing), then prepares it (the same checks, and stopping a
    lingering emulator on Android ≤ 13) and starts it on the main thread, without Android's
    transition between apps. The emulator reads the game through the intent's own read grant,
    which Android revokes once the emulator's activity is gone;
  - `Curtain` is the black window over the emulator; it needs the "display over other apps"
    permission, granted from the device check.
- **`storage/Folders.kt`** covers folders picked with the system picker: keeping read access (and
  nothing more), and listing a folder level from the documents provider for `FolderWalk`. Its
  tests run it against a fake `DocumentsProvider`. `LibraryStore` writes the library file
  atomically and sets an unreadable one aside; `SelectionStore` does the same for the selection,
  whose unreadable file is only replaced.
- **`library/LibraryService.kt`** runs scans, choices, selections and library launches on one
  thread, in the order they arrive.
- **`AndroidManifest.xml`** lists the permissions, each justified in a comment.

### Godot (`app/`)
- **The carousel** (`carousel/`, the main scene) shows the shelves. `carousel.gd` handles input,
  platforms, launches and remembering the selection (before leaving a shelf, launching, or leaving
  the app). `ShelfRow` moves the row and recycles a fixed pool of places, so its cost does not
  depend on the number of games; labels are drawn in each place's small `SubViewport`, one per
  frame. `CarouselLayout` holds the mechanics as pure functions.
- **Launches**: `GameLaunch` (`carousel/launch/`) runs a launch from A to the carousel shown again;
  `Insertion` holds the motion as pure functions of time, its timings, distances and sounds per
  media in `appearance.json` (`insertions`), tuned without code; `carousel/models/spindle.tscn` is
  the drive's spindle, `carousel/launch/blackout.gdshader` the black growing from the disc's centre.
- **Models** are data: `data/carousel/appearance.json` names a scene per media, a label colour
  per platform, the pose and the insertions. A model is any scene with a `Label` mesh whose material uses
  `carousel/models/label.gdshader` (the carousel sets `label_texture`); replacing a model is
  changing that file. Every place makes its model of each media at start, as the first instance
  of a model takes 10 to 30 ms on a handheld.
- **The shipped models are built from their shapes** (`carousel/models/*_shape.tres`): each part
  is a `ShapedMesh` naming one of the shape's `parts()`, which asks the shape for its arrays;
  `DiscGeometry` turns profiles around the disc's axis, `CartridgeGeometry` sweeps rounded
  outlines with bevels, both in millimetres through `MeshBuilder`, which scales them to world
  units, turns every face the way its normals point and squares tangents to normals. Changing a
  dimension in the inspector rebuilds the model in the editor. Impossible dimensions build
  nothing: the shape's `problems()` names the rules they break. Materials: the label's varnish,
  grain and grooves (`label.gdshader`), a disc's mirror underside, whose `light()` draws the
  rainbow streak of its grooves (`disc_mirror.gdshader`), clear plastic (`clear_plastic.gdshader`),
  and what they all reflect, a studio sky that is never drawn (`carousel/studio_sky.gdshader`).
- **`AndroidServices`** (the `Android` autoload) turns plugin answers into typed values
  (`Folder`, `Entry`, `Candidate`…) and exposes operations as coroutines, such as
  `await Android.list_folder(folder)`; see its header for running without the plugin.
- **`Diagnostics`** (autoload, `dev/diagnostics.gd`) traces every input event with the actions it
  matches, focus changes, lifecycle notifications, the plugin traffic, and frames that miss 60 fps
  (with the rendering pipelines compiled meanwhile, the usual cause), in debug builds only. The
  Kotlin side traces intents, activity results, installation checks, title indexing, scans (their
  timings, ignored files and skipped folders) and library problems the same way (`trace` in
  `Wire.kt`). Add trace points
  with every feature.
- **`CarouselBench`** (`dev/`) drives the carousel like a user for `dev/bench.sh`: held scrolling,
  platform changes or a turning game for 30 s, then one line of frame statistics; or one launch
  (`--bench=launch`), which `GameLaunch` measures itself.
- **The device check** opens from the carousel by holding Select for 2 s, in debug builds; back at
  its root returns to the carousel. It has a Library tab (folder, emulator, scan, games, ignored
  files, launch), and is built from one scene per tab over a shared `DeviceCheckPage` base, with
  signals wired in the scene files wherever they exist before `_ready`. The root forwards resume
  and back events to the visible page. Back is the `app_back` action or Android's back request:
  some handhelds send their back button as a joypad button only, the same one as Select.
- **The export plugin** adds the AARs, the core jar and the dependencies listed in
  `bin/dependencies.txt` to Android exports. Gradle writes that file, so versions are only declared
  in `kotlin/gradle/libs.versions.toml`.

## Working on the code

- Build and test commands are in the README. On a device, `dev/logs.sh` follows a debug build's
  traces; `adb exec-out screencap -p > screen.png` shows the screen. `cd kotlin && ./gradlew test`
  runs every Kotlin test; the core tests also parse the definition files shipped in `app/data`.
  `dev/test_godot.sh` runs the GDScript tests.
- `dev/bench.sh` measures a debug build on a device at several library sizes (the device's own,
  and demo ones of 150 to 5,000 games) and can record every measurement as a JSON line.
- **Without the plugin** (the editor, a desktop run), the carousel shows the demo library of
  `dev/demo/desktop.json`, with made-up label artwork: models and materials are tuned on a
  computer. The file is what the plugin would send; `DesktopDemoTest` (Kotlin) fails when it is out
  of date and writes the new one. In debug builds, images put in `user://dev-labels/`, named after
  a game's first serial (`SLES-52584.png`) or its title, are shown as its label (`DevLabels`, the
  row's `label_images`, which tests replace); sounds put in `user://dev-sounds/`, named after an
  insertion's cues (`ps2-clip.mp3`), are played as it runs (`DevSounds`). Neither is ever part of
  the repository: the insertions play silently until freely licensed sounds are chosen.
- **Without the plugin**, pressing A plays the insertion, then the launch fails: insertions are
  tuned on a computer too.
- **Debug arguments** (`--esa arguments` on the device, after `--` on a desktop):
  `--turntable=0.25` turns the selected game to show all its sides, `--shelf=gba` opens on a
  platform's shelf, `--demo-games=N` and `--bench=…` as in `dev/bench.sh`.
- **Shaders are only compiled when something is drawn**: the headless runs of `dev/build.sh` do
  not see their errors. After changing one, run the desktop demo or the device and look for
  `SHADER ERROR` in the log.
- The Vulkan pipeline cache is saved as soon as it grows (`save_chunk_size_mb` in
  `project.godot`), since Android kills apps rather than quitting them: a start then compiles no
  pipeline twice (about 100 ms per frame that needs one).
- Both toolchains treat warnings as errors: the Kotlin compiler, and the GDScript typing warnings
  (`untyped_declaration`, `unsafe_*`…) set in `project.godot`.
- Every guarantee in [INVARIANTS.md](INVARIANTS.md) has a test named after its id.

## Writing tests

Tests live next to the code they test (`XTest.kt` in the package of `X`), are named by the
behaviour they check, and are of four kinds only. Copy the closest one:

- **Example**: one concrete case, set up, run, checked on its typed result
  (`ScanTest`, "discs of one game make one game").
- **Property**: `checkAll` over generators, stating a law from outside: a round trip, never
  failing, not depending on an order, "changing X changes only Y" (`FolderWalkTest`).
- **Invariant**: a property of [INVARIANTS.md](INVARIANTS.md), its id first in the test name.
- **Android**: Robolectric, run on the oldest supported Android, a middle one and the newest
  Robolectric runs on Java 17 (`robolectric.properties`); documents providers are faked with
  `FakeDocuments`.

GDScript tests (`app/test`, GdUnit4) follow the same kinds. Their properties loop over seeded
random cases (`cases()` in `test/carousel/fixtures.gd`), so a failure always comes back.

Generators, fixtures and fakes are shared, never redefined in a test: `Generators.kt`,
`Fixtures.kt` and `Fakes.kt` of each package, in `kotlin/core/src/testFixtures` (used by both
modules) or `kotlin/android/src/test`. A port of the core (such as the walk's listing function)
is faked in memory (`InMemoryFolders`). Results are checked as typed values, never as messages;
a property that filters its cases also checks that enough of them reach the code under test
(`forEveryResolvedTemplate`). No mocks of Cartouche code, no real clock, no sleeps.

## Conventions

- **Kotlin:** typed functional style.
  - No `null` in our code: absence is `Option`, failure a typed error through Arrow's
    `Raise`/`Either`, and nullable platform values are converted once, at the boundary.
  - Exhaustive `when` over sealed types, never with `else`. Newtypes rather than bare strings.
  - `ktlint` (official style) and `explicitApi()`.
- **GDScript:** the official style guide, static typing everywhere, scenes rather than UI built in
  code, `%UniqueName` with typed `@onready`, and InputMap actions rather than raw buttons (the
  controller test page aside). `ui_accept` is redefined to add the joypad's south button, which
  Godot's default leaves out. Every action also has a keyboard key (arrows, Page Up and Page
  Down for L1 and R1, Enter, Escape): keyboards work, and `adb shell input keyevent` can drive the
  app. Text shown to users goes through `tr()`, translated in `locale/*.po`; the device check is a
  developer tool, so its text is English and not translated.
- **Both:**
  - Comments explain *why*, on code people read often; no comment restates the code.
  - Every source file starts with `SPDX-License-Identifier: GPL-3.0-or-later`.
