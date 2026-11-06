# Onboarding

Start here. This page tells you what Cartouche is, how its code is cut, how to build, run and test it, and which
page and files to open for the task in front of you. Every other page of `docs/` is one click from here, and each
one links back to its neighbours, so you can walk the map from any point.

## What Cartouche is

Cartouche is a game launcher for Android. It shows each console as a 3D model and each game as the disc or
cartridge it came on. It finds the games in the folders the user picks, identifies them from what their files
hold, downloads their real label scans in the background, and starts them in the emulators already installed.
It emulates nothing itself.

## Your first contribution

**The code in five lines.**

1. `kotlin/core/` is the domain: what a game, a scan, a launch and a label are, as pure Kotlin functions.
2. `kotlin/android/` is the Android plugin: files, threads, network and launches, around the core.
3. `app/` is the Godot project: it draws, reads the pad and the fingers, and plays sounds. It holds no domain rule.
4. GDScript reaches the plugin through one file, `AndroidServices`; on a desktop, `DesktopPlugin` stands in for it.
5. Consoles and media are folders of data and models; platforms and emulators are JSON files in `app/data/`.

**The one command.** `scripts/build.sh` checks the docs, lints, runs every test and builds the debug APK
([Build, run and test](#build-run-and-test)). `$GODOT --path app` runs the app on your computer with a demo
library. [CONTRIBUTING.md](../CONTRIBUTING.md) says what a pull request needs.

**Which page for which task.**

| Task | Page |
|---|---|
| Add a console, or a model of one | [adding-a-console.md](adding-a-console.md) |
| Add a disc or cartridge | [adding-a-medium.md](adding-a-medium.md) |
| Give a console its launch animation | [adding-a-console.md](adding-a-console.md) |
| Add a platform, fix an emulator or its extensions | [adding-a-platform.md](adding-a-platform.md) |
| Add a setting | [adding-a-setting.md](adding-a-setting.md) |
| Add a background | [adding-a-background.md](adding-a-background.md) |
| Add or change a screen or a gesture | [adding-a-screen.md](adding-a-screen.md) |
| Add or fix a text, or a language | [translating.md](translating.md) |
| Add a sound to a gesture | [sounds.md](sounds.md) |
| Try a build on a device | [device-testing.md](device-testing.md) |
| Find why something fails | [When something fails](#when-something-fails) |
| Publish a version (maintainers) | [releasing.md](releasing.md) |

**How tests are written.** Four kinds, each described in [testing.md](testing.md): an example (one concrete case),
a property (a law checked over generated cases, Kotest's `checkAll`), an invariant test (a guarantee of
[INVARIANTS.md](INVARIANTS.md), named after its id), and a walk (a seeded run of presses through the real screens).
Kotlin tests run on the JVM, the plugin's under Robolectric; GDScript tests run headless in Godot with GdUnit4.
Copy the closest existing test.

## The map

```text
README.md                      you are here: the entry, the commands, the "I want to…" index
├── ../CONTRIBUTING.md         licence, clean-room, style, what a pull request needs
├── GLOSSARY.md                every domain word, as the code spells it
├── INVARIANTS.md              the guarantees no change may break, and their tests
├── architecture/core.md       kotlin/core: the domain rules, pure Kotlin
├── architecture/android.md    kotlin/android: the Godot Android plugin around the core
├── architecture/godot.md      app/: screens, carousel, consoles, launches, the adapter
├── architecture/studio.md     app/studio: the look every screen shares
├── adding-a-console.md        a console's folder, its model, its launch, its tests
├── adding-a-medium.md         a disc or cartridge's folder, its model, its tests
├── adding-a-platform.md       a platform's definition, players, profile, titles and art data
├── adding-a-setting.md        a setting: its declaration in the core, its row on the card
├── adding-a-background.md     a background: its scheme, its key in three lists, its name
├── adding-a-screen.md         a screen or a gesture, its guards, hints, sounds and tests
├── adding-a-screen-format.md  screens of every shape: the stage, the bands, the families of screens
├── device-testing.md          a debug build on a device, beside your own, its traces, benchmarks
├── releasing.md               publishing a version (maintainers)
├── testing.md                 the kinds of tests, their helpers, how to run each
├── sounds.md                  the gesture-to-sound table and how a sound plays
└── debug-bridge.md            the remote control of a running debug build
```

## Three layers

The code is cut in three layers. Each one depends only on the one below it.

| Layer | Folder | Holds | Never holds |
|---|---|---|---|
| Godot shell | `app/` | scenes, input, display, animation, sound | a domain rule (what a game is, which file to launch) |
| Android plugin | `kotlin/android/` | Android APIs, files, threads, network, the only mutable state | a rule the core can state as a pure function |
| Core | `kotlin/core/` | the domain as pure functions over immutable values | Android, IO, `null` |

GDScript reaches the plugin through one file, the `AndroidServices` autoload
(`app/adapters/android/android_services.gd`). It calls the plugin's `@UsedByGodot` methods, and turns each answer
into the typed values of `AndroidWire` (`app/adapters/android/android_wire.gd`). Everything the plugin sends is one
JSON text of a type of `Sent.kt`, and `android_wire.gd` is generated from those types (INV-23): a field is added in
`Sent.kt`, never by hand in GDScript.

On a desktop or in the editor there is no plugin. `AndroidServices` then calls `DesktopPlugin`
(`app/adapters/desktop/desktop_plugin.gd`), which has the plugin's method names and answers in the same JSON, from
the demo library in `app/dev/demo/desktop.json`. The screens cannot tell the difference.

### How a press travels

Pressing A on a game asks the plugin whether it can start, then starts it. The same round trip carries every
operation: the screen awaits a coroutine of `AndroidServices`, the plugin works off Godot's thread and answers
through its `answered` signal, and the adapter hands back a typed value.

```mermaid
sequenceDiagram
    participant S as GameLaunch, app/carousel/launch
    participant A as AndroidServices, app/adapters/android
    participant P as CartouchePlugin, kotlin/android
    participant C as Catalog and LaunchTemplate, kotlin/core
    S->>A: await check_launch(game, disc)
    A->>P: checkLaunch(request id, game id and disc)
    P->>C: Catalog.launch(player, file)
    C-->>P: a Launch, or a LaunchError
    P->>P: Launcher.checkGame, emulator installed and file still there
    P-->>A: answered signal, request id and ok or an error code
    A-->>S: AndroidWire.Result
    S->>A: await launch_game(game, disc)
    A->>P: launchGame(request id, game id, disc and within_ms)
    P->>P: too late? refused, else Curtain over, Launcher.start
```

Getters (`battery`, `browse`, `title_marks`) answer at once instead. Signals that are not answers
(`art_changed`, `art_progress`, `label_variant_downloaded`, `battery_changed`) become the `AndroidServices` signals
of the same names.

## Repository layout

| Path | What it holds |
|---|---|
| `app/` | the Godot project: `project.godot`, scenes, scripts, shaders, shipped data |
| `app/data/` | data the app reads at start: platform definitions, title lists, art extracts, poses, lights |
| `app/test/` | GDScript tests (GdUnit4) |
| `kotlin/core/` | the pure domain, its tests and the shared test fixtures (`kotlin/core/src/testFixtures/`) |
| `kotlin/android/` | the Godot Android plugin and its Robolectric tests |
| `scripts/` | build, test, bench and data scripts |
| `docs/` | this map |

## Build, run and test

You need Godot 4.7.2 with its export templates, JDK 17, the Android SDK (platform 36, build tools 36.1.0,
NDK 29.0.14206865 and CMake 3.22.1, which Gradle installs when missing),
gdtoolkit 4 for `gdlint` (`pip install --user "gdtoolkit==4.*"`), Python 3, and `adb` to install on a device.

```sh
export JAVA_HOME=/path/to/jdk-17 ANDROID_HOME=/path/to/android-sdk
export GODOT=/path/to/godot          # if godot is not on PATH
scripts/build.sh                     # everything below, then the debug APK in build/
scripts/build.sh --install           # the same, then installs and starts it on the device adb sees
```

`scripts/build.sh` runs, in order: `scripts/check_docs.py`, `gdlint` on every app script, the Kotlin lint, tests,
Android lint and build, every GDScript test, `scripts/check_release.sh`, a short headless run of the project that
fails on any script error, then the APK export.

Run one part while you work:

```sh
cd kotlin && ./gradlew :core:test --tests '*ScanTest'              # one core test class
cd kotlin && ./gradlew :android:testDebugUnitTest --tests '*LauncherTest'
GODOT=$GODOT scripts/test_godot.sh res://test/carousel/search       # one GDScript folder or file
GODOT=$GODOT scripts/test_godot.sh                                  # every GDScript test
python3 scripts/check_docs.py                                       # every path and name the docs cite
```

To run the app on your computer, open `app/` in the Godot editor and press Play, or run
`$GODOT --path app`. The carousel shows the desktop demo library. Launching a game fails at the end, since no
emulator exists there, but every screen and animation plays.

On a device, `scripts/logs.sh` follows a debug build's traces, and `scripts/bench.sh` measures the installed build at
several library sizes.

### Diagnostics and debug arguments

In debug builds, `Diagnostics` (`app/dev/diagnostics.gd`) traces every input event, focus change, lifecycle
notification, plugin call and slow frame. The plugin traces intents, scans and timings the same way (`trace` in
`Wire.kt`). Add trace points with every feature.

Debug builds read arguments after `--` on a desktop (`$GODOT --path app -- --shelf=gba`), and from the
`arguments` extra on a device
(`adb shell am start -n app.cartouche/com.godot.game.GodotAppLauncher --esa arguments --shelf=gba`).

| Argument | Effect | Read by |
|---|---|---|
| `--welcome=skip` | starts without waiting on the title screen | `Carousel` |
| `--shelf=gba` | opens with that platform's console selected on the consoles screen | `Carousel` |
| `--demo-games=N` | a made-up library of N games, kept apart from the user's | `Carousel`, `DemoLibrary.kt` |
| `--demo-shelf=ps2` | puts every demo game on one console | `Carousel` |
| `--coming-consoles` | counts the consoles not fully supported yet as ready: on the demo ring, and addable | `ConsoleManifest`, `DesktopPlugin` |
| `--turntable=T` | turns the selected game at T turns a second | `Carousel` |
| `--bench=scroll` | runs one measured scenario (`scroll`, `enter`, `turn`, `launch`, `session`, others) | `CarouselBench` |
| `--msaa=N` | the 3D's antialiasing for a bench run | `CarouselBench` |
| `--shots=DIR` | saves pictures at set frames (run with `--fixed-fps 60`) | `FrameShots` |
| `--launch=rehearse` | every launch check passes and no emulator starts: the insertion plays, then the carousel returns | `AndroidServices` |
| `--snapshot=DIR` | desktop only: shows a device's library, settings and labels copied into DIR | `DesktopPlugin` |
| `--backdrop=dark` | desktop only: starts on that background (`light`, `dark`, `light_grey`, `anthracite`, `device`) | `DesktopPlugin` |
| `--new-games=gba:2` | desktop only: those consoles get a folder, and their first re-read brings that many made-up games (`0`: the folder alone) | `DesktopPlugin` |
| `--pixel-veil=off` | desktop only: starts with the background's pixel veil still | `DesktopPlugin` |
| `--bridge` | connects the debug bridge | `Diagnostics`, see [debug-bridge.md](debug-bridge.md) |
| `--art-refused` | every art server refuses | `DebugOptions.kt` |
| `--art-slow=MS` | waits MS milliseconds after each chunk of an image | `DebugOptions.kt` |
| `--launch-slow=MS` | waits MS milliseconds before a game's file is checked to start, to see a slow storage | `DebugOptions.kt` |
| `--screenscraper=quota` | ScreenScraper answers as `quota`, `wrong-key` or `wrong-account` says | `DebugOptions.kt` |

### Credentials

ScreenScraper's developer key reaches a build from `kotlin/local.properties` (`screenscraper.devid`,
`screenscraper.devpassword`, `screenscraper.softname`, and for debug builds a member's `screenscraper.ssid` and
`screenscraper.sspassword`) or from the matching `SCREENSCRAPER_*` environment variables. It is never in the
repository. A build without a key gets no ScreenScraper image. Tests never use real credentials.

## When something fails

Read the log before guessing. `scripts/build.sh` stops at its first failure, in the order given in
[Build, run and test](#build-run-and-test): fix that one, then run only that step again.

| What failed | Where to look |
|---|---|
| `scripts/check_docs.py` | the `file:line` it prints. It reads only tracked files: `git add` a new file first. |
| `gdlint` | `build/gdlint.log`: the file, the line and the rule (`gdlintrc`) |
| Kotlin lint or tests | Gradle's output, then the reports under each module's `build/reports/` in `kotlin/` |
| GDScript tests | `build/test-godot.log`, each file's own log in `build/test-godot/` |
| The short headless run | `build/run.log`: a script that does not compile |
| The export | `build/export.log` |
| The app on a device | `scripts/logs.sh` ([device-testing.md](device-testing.md#traces)) |

- **A test hangs.** The last test a log starts without ending is the one: an `await` on a signal that never comes,
  or a loop with no end. Fix why the signal never fires; raising the time limit hides the bug.
- **`android_wire.gd` is out of date.** `Sent.kt` changed: run
  `cd kotlin && ./gradlew :android:testDebugUnitTest --tests '*WireScriptTest' -Pwire.write=true` (INV-23).
- **A shader error.** Headless runs never compile shaders: run the app and look for `"SHADER ERROR"` in its output.
- **Was it already broken?** Check out `main` in a separate worktree (`git worktree add`), run the same command
  there, then remove it.

## I want to…

Find your task, open the page, then the files in the order given.

### Understand a part

| I want to understand… | Page | Open first |
|---|---|---|
| the domain words | [GLOSSARY.md](GLOSSARY.md) | |
| what may never break | [INVARIANTS.md](INVARIANTS.md) | |
| how a scan turns files into games | [architecture/core.md](architecture/core.md#library-scan-and-identification) | `Scan.kt`, `TitleIndex.kt`, `LibraryService.kt` |
| how a game is identified from its bytes | [architecture/core.md](architecture/core.md#file-facts) | `FileReading.kt`, `Iso9660.kt`, `Cartridges.kt` |
| how a label image is found | [architecture/core.md](architecture/core.md#art) | `ArtSources.kt`, `Scraper.kt`, `ArtService.kt` |
| how a launch works | [architecture/android.md](architecture/android.md#launch) | `LaunchTemplate.kt`, `Launcher.kt`, `game_launch.gd` |
| the plugin's threads and state | [architecture/android.md](architecture/android.md#the-plugin-object) | `CartouchePlugin.kt`, `Threads.kt`, `Reference.kt` |
| the main screen | [architecture/godot.md](architecture/godot.md#the-carousel) | `carousel.gd`, `shelf_row.gd`, `console_row.gd` |
| the screens in front of it | [architecture/godot.md](architecture/godot.md#the-screens) | `screen_flow.gd`, `add_console.gd`, `settings_menu.gd` |
| the shared look (materials, text, motion) | [architecture/studio.md](architecture/studio.md) | `studio_tokens.gd`, `satin_panel.gd`, `motion.gd` |
| why the app draws nothing at rest | [architecture/godot.md](architecture/godot.md#resting) | `resting.gd` |
| how the backgrounds change every screen | [architecture/studio.md](architecture/studio.md#backgrounds) | `backdrop.gd`, `palette.gd`, `cyclorama.gd` |

### Change something

| I want to change… | Page | Open first |
|---|---|---|
| an emulator or its launch template | [architecture/core.md](architecture/core.md#platforms-and-launches) | `app/data/platforms/daijishou/`, `app/data/platforms/cartouche/`, `LaunchTemplate.kt` |
| the curtain's time over an emulator | [architecture/core.md](architecture/core.md#platforms-and-launches) | `app/data/launch/curtains.json`, `CurtainTimes.kt` |
| what a scan keeps or ignores | [architecture/core.md](architecture/core.md#library-scan-and-identification) | `Scan.kt`, `FolderWalk.kt`, `app/data/scan/data_folders.json` |
| how games are identified | [architecture/core.md](architecture/core.md#library-scan-and-identification) | `TitleIndex.kt`, `GameName.kt`, `FileReading.kt` |
| where art comes from, or its order | [architecture/core.md](architecture/core.md#art) | `ArtSources.kt`, `Regions.kt`, `ArtFetching.kt` |
| the search ribbon | [architecture/core.md](architecture/core.md#shelves-and-search) | `Finder.kt`, `game_search.gd` |
| what the plugin sends to Godot | [architecture/android.md](architecture/android.md#the-wire) | `Sent.kt`, `Wire.kt`, `android_wire.gd` (generated) |
| a timing, colour or size of the design | [architecture/studio.md](architecture/studio.md#values) | `studio_tokens.gd` (generated, never edited by hand) |
| how a screen of another shape lays out (16:9, 21:9, near-square) | [adding-a-screen-format.md](adding-a-screen-format.md) | `app/data/screen_formats.json`, `screen_layout.gd`, `stage_lens.gd`, `rests.gd` |
| a game's pose on the games screen | [architecture/studio.md](architecture/studio.md#the-games-screen) | `app/data/media_poses.json`, `games_layout.gd` |
| a translation | [translating.md](translating.md) | `app/locale/` |

### Add something

| I want to add… | Page | Open first |
|---|---|---|
| a console | [adding-a-console.md](adding-a-console.md) | `scripts/new_console.py`, `app/carousel/consoles/gba_sp/`, `console_model.gd` |
| a disc or cartridge | [adding-a-medium.md](adding-a-medium.md) | `app/carousel/media/ps2_dvd/`, `medium_manifest.gd` |
| a platform (data only) | [adding-a-platform.md](adding-a-platform.md) | `app/data/platforms/profiles.json`, `scripts/dat_titles.py` |
| a screen in front of the carousel, or a gesture | [adding-a-screen.md](adding-a-screen.md) | `screen_flow.gd`, `hint_row.gd`, `app/test/screens/fixtures.gd` |
| a setting | [adding-a-setting.md](adding-a-setting.md) | `Setting.kt`, `settings_menu.gd` |
| a background | [adding-a-background.md](adding-a-background.md) | `backdrop.gd`, `Settings.kt`, `studio_tokens.gd` |
| a language | [translating.md](translating.md#add-a-language) | `app/locale/locale.gd`, `Settings.kt` |
| a sound, or a sound to a gesture | [sounds.md](sounds.md) | `scripts/audio/sounds.json`, `sound_effects.gd` |
| a test | [testing.md](testing.md) | the closest existing test |
| a debug trace | [Diagnostics and debug arguments](#diagnostics-and-debug-arguments) | `diagnostics.gd`, `Wire.kt` |

### Use a tool

| I want to… | Page | Open first |
|---|---|---|
| drive a running build from a script | [debug-bridge.md](debug-bridge.md) | `app/dev/bridge/commands.gd` |
| run without a device | [architecture/godot.md](architecture/godot.md#the-adapter) | `desktop_plugin.gd`, `app/dev/demo/desktop.json` |
| prove a change keeps every pixel | [testing.md](testing.md#pictures-and-benchmarks) | `frame_shots.gd` |
| try a build on a device without touching my own library | [device-testing.md](device-testing.md) | `app/export_presets.cfg`, `scripts/logs.sh` |
| measure on a device | [device-testing.md](device-testing.md#benchmarks) | `scripts/bench.sh`, `carousel_bench.gd` |
| look at a model beside photos | [adding-a-console.md](adding-a-console.md#tools) | `scripts/render_console.sh`, `scripts/export_console.sh` |

## Five words to know first

- A **platform** is a console as its definition file describes it (`ps2`). Its **profile** adds the media its
  games come on.
- A **player** is one way to run a platform's games: an emulator or a RetroArch core, with its launch
  **template**.
- A **game** is one entry of the library, made of one or more discs (files). It is **identified** when the
  platform's reference list knows it.
- A **shelf** is one platform's games in the carousel. The **selection** remembers where the user was.
- A **medium** is the physical object a game comes on (`ps2_dvd`, `nes_cart`), one folder and one 3D model each.

The rest is in [GLOSSARY.md](GLOSSARY.md).

## Rules of the code

- Kotlin is typed functional code. Absence is `Option`, failure a typed error through Arrow's `Raise` or
  `Either`. There is no `null`, `!!` or `lateinit`. A `when` over a sealed type lists every case, never `else`.
  `ktlint` and `explicitApi()` run in the build.
- GDScript is fully typed: the typing warnings are errors (`project.godot`). The Godot style guide's member order
  and names hold (`gdlintrc`). Scenes hold the UI, unique-name (`%`) nodes are typed `@onready` members, and input
  goes through InputMap actions. Every action also has a keyboard key, so `adb shell input keyevent` can drive the
  app. Text the user reads goes through `tr()`.
- Shortest code with the same behaviour. One idiom per need: search for the helper before you write one.
- Comments say why, on code people read often. They never restate the code.
- Every source file starts with `SPDX-License-Identifier: GPL-3.0-or-later`.
- A shader compiles only when something draws with it, so headless runs miss its errors. After changing one,
  run the app and look for `"SHADER ERROR"` in the log.
- Every guarantee of [INVARIANTS.md](INVARIANTS.md) has tests named after its id. Weakening one is a decision to
  discuss in an issue first.
