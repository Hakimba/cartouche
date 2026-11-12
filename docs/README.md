# Developer guide

Cartouche is a game launcher for Android: it shows each console as a 3D model and each game as the disc or
cartridge it came on, finds the games in the folders the user picks, identifies them from their files, downloads
their label scans, and starts them in the emulators installed. It emulates nothing.

Build and check commands, the rules of the code and what a pull request needs are in
[CONTRIBUTING.md](../CONTRIBUTING.md). This page maps the rest.

## Pages

| I want to… | Page |
|---|---|
| understand the code: the three layers, where state lives, each package | [architecture.md](architecture.md) |
| know a word of the domain | [GLOSSARY.md](GLOSSARY.md) |
| know what may never break | [INVARIANTS.md](INVARIANTS.md) |
| write or run a test | [testing.md](testing.md) |
| add a console, a model of one, or its launch animation | [adding-a-console.md](adding-a-console.md) |
| add a disc or cartridge | [adding-a-medium.md](adding-a-medium.md) |
| add a platform, or fix an emulator, its extensions or its art | [adding-a-platform.md](adding-a-platform.md) |
| add a setting | [adding-a-setting.md](adding-a-setting.md) |
| add a background | [adding-a-background.md](adding-a-background.md) |
| add or change a screen or a gesture, on screens of every shape | [adding-a-screen.md](adding-a-screen.md) |
| add or fix a text, or a language | [translating.md](translating.md) |
| add a sound to a gesture | [sounds.md](sounds.md) |
| try a build on a device, measure it | [device-testing.md](device-testing.md) |
| drive a running build from a script | [debug-bridge.md](debug-bridge.md) |
| publish a version (maintainers) | [releasing.md](releasing.md) |

## Repository layout

| Path | Holds |
|---|---|
| `app/` | the Godot project: scenes, scripts, shaders |
| `app/data/` | data read at start: platform definitions, title lists, art extracts, poses, lights |
| `app/test/` | GDScript tests (GdUnit4) |
| `kotlin/core/` | the pure domain, its tests and the shared test fixtures (`kotlin/core/src/testFixtures/`) |
| `kotlin/android/` | the Godot Android plugin and its Robolectric tests |
| `scripts/` | build, test, bench and data scripts |
| `tools/godot/` | the patches and options of [the engine template](#the-engine-template) |

## Diagnostics and debug arguments

In debug builds, `Diagnostics` (`app/dev/diagnostics.gd`) traces input events, focus changes, lifecycle
notifications, plugin calls and slow frames; the plugin traces intents, scans and timings (`trace` in `Wire.kt`).
Add trace points with every feature: `Diagnostics.trace("<area>", "<detail>")`.

Debug builds read arguments after `--` on a desktop (`$GODOT --path app -- --shelf=gba`), and on a device from the
`arguments` extra, comma-separated
(`adb shell am start -n app.cartouche/com.godot.game.GodotAppLauncher --esa arguments --welcome=skip,--shelf=gba`).

| Argument | Effect |
|---|---|
| `--welcome=skip` | starts without waiting on the title screen |
| `--shelf=gba` | opens with that platform's console selected |
| `--demo-games=N` | a made-up library of N games, kept apart from the user's (`DemoLibrary.kt`) |
| `--demo-shelf=ps2` | puts every demo game on one console |
| `--coming-consoles` | counts the consoles not fully supported yet as ready: on the demo ring, and addable |
| `--turntable=T` | turns the selected game at T turns a second |
| `--bench=scroll` | runs one measured scenario of `CarouselBench` (`scroll`, `enter`, `turn`, `launch`, `session`…) |
| `--msaa=N` | the 3D's antialiasing for a bench run |
| `--shots=DIR` | saves pictures at set frames (`FrameShots`; run with `--fixed-fps 60`) |
| `--launch=rehearse` | every launch check passes and no emulator starts: the insertion plays, then the carousel returns |
| `--bridge`, `--bridge-port=N` | connects the [debug bridge](debug-bridge.md) |
| `--art-refused` | every art server refuses (`DebugOptions.kt`, as the next three) |
| `--art-slow=MS` | waits MS milliseconds after each chunk of an image |
| `--launch-slow=MS` | waits MS milliseconds before a game's file is checked to start |
| `--screenscraper=quota` | ScreenScraper answers as `quota`, `wrong-key` or `wrong-account` says |
| `--snapshot=DIR` | desktop only: shows a device's library, settings and labels copied into DIR |
| `--backdrop=dark` | desktop only: starts on that background (`light`, `dark`, `light_grey`, `anthracite`, `device`) |
| `--pixel-veil=off` | desktop only: starts with the background's pixel veil still |
| `--new-games=gba:2` | desktop only: those consoles get a folder, and their first re-read brings that many made-up games (`0`: the folder alone) |
| `--library-unreadable` | desktop only: starts as after a damaged library file, with no console and the message saying so |

## The engine template

`scripts/export_apk.sh debug|release APK` exports with Cartouche's own Android template when it is built, else
with Godot's official one, and prints which. The official engine ignores the settings below, so the same project
runs on either: without the template the app is the same, with more graphics memory, a larger APK and no R8.

| Command | Does |
|---|---|
| `scripts/godot_template.sh build` | builds the template: Godot 4.7.2, the six patches, the options below. About an hour; needs `scons` and the NDK. Nothing else runs it |
| `scripts/godot_template.sh fingerprint` | the hash of the engine version and of every file of `tools/godot/`. The build is kept under that name in `~/.cache/cartouche/godot/`; when it changes, exports use the official template until the next build |
| `scripts/godot_template.sh zip` | the cached template's path; fails when there is none |

| File | What it does |
|---|---|
| `tools/godot/patches/0001-vma-block-size-setting.diff` | a project setting for smaller Vulkan memory blocks, so less graphics memory stays reserved (`app/project.godot` sets 32 MiB) |
| `tools/godot/patches/0002-ubershaders-setting.diff` | a project setting turning ubershaders off: a pipeline is compiled when first drawn, and the driver keeps far less memory |
| `tools/godot/patches/0003-r8-minification.diff`, `tools/godot/patches/0004-r8-keep-names.diff` | R8 shrinks the release build's Java and Kotlin code, without renaming |
| `tools/godot/patches/0005-specialized-pipelines.diff` | two project settings: the list of pipelines compiled in the background as soon as a model is loaded, and a switch printing each pipeline drawn |
| `tools/godot/patches/0006-blend-splits-of-shadowless-lights.diff` | a directional light without a shadow gives its pipelines the same key in every run |
| `tools/godot/scons_options.txt` | link-time optimisation, and the engine parts the app never uses left out (physics, navigation, XR, networking, video, CSG…) |
| `tools/godot/cartouche.gdbuild` | the node and resource classes left out |

Two things to keep in step with the app:

1. **A new node or resource type.** Its class must not be in `tools/godot/cartouche.gdbuild`, nor come from a
   module `tools/godot/scons_options.txt` switches off. `scripts/build.sh` fails on a listed class the app names.
2. **The pipeline list.** With ubershaders off, a pipeline not listed is compiled when first drawn: one slow frame,
   no other effect. `app/project.godot` lists the pipelines a session draws. Record it again after adding or
   changing a model, a material, a light rig, a viewport or a screen that draws 3D:
   1. in `app/project.godot`, set print_specialized_pipelines=true under rendering/shader_compiler/ubershaders;
   2. export, install fresh, play every console and every screen, and save `adb logcat -d -s godot` to a file;
   3. `scripts/specialized_pipelines.py write LOG`, then set the switch back.

   `scripts/specialized_pipelines.py check LOG` fails when a log holds a pipeline the list lacks, `show LOG` decodes
   them, and `scripts/build.sh` fails when the list is empty or cut while ubershaders are off.

## When something fails

Read the log first: [CONTRIBUTING.md](../CONTRIBUTING.md#build-and-check) says which log each build step writes.

| Symptom | What to do |
|---|---|
| A test hangs | The last test a log starts without ending is the one: an `await` on a signal that never comes, or a loop with no end. Fix why; raising the time limit hides the bug |
| `android_wire.gd` is out of date | `Sent.kt` changed: `cd kotlin && ./gradlew :android:testDebugUnitTest --tests '*WireScriptTest' -Pwire.write=true` |
| A shader error | Headless runs never compile shaders: run the app and look for `"SHADER ERROR"` |
| The export, or the app, fails on Cartouche's template only | Move `~/.cache/cartouche/godot` aside and export again: if the official template works, the cause is in `tools/godot/` |
| The app misbehaves on a device | `scripts/logs.sh` ([device-testing.md](device-testing.md#traces)) |
| Was it already broken? | Check out `main` in a separate worktree (`git worktree add`), run the same command there, then remove it |
