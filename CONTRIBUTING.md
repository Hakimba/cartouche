# Contributing to Cartouche

What a contribution must respect, how to build and check the app, and what a pull request needs. The code is
mapped in [docs/README.md](docs/README.md).

## Licence and what you may bring in

Cartouche is free software under the [GNU GPL v3 or later](LICENSE). A pull request releases your contribution
under the same licence. Every new source file starts with `SPDX-License-Identifier: GPL-3.0-or-later` in a comment.

- **Your own work only.** Never copy code, pictures, sounds, icons or layouts from another launcher or front-end,
  even an open-source one. If you studied another app, write your version from scratch.
- **3D models** under CC0, CC-BY or CC-BY-SA only. The licence text stays beside the model (`LICENSE.txt` in its
  folder, like `app/carousel/consoles/nes/LICENSE.txt`) and the author is credited in the README.
- **Third-party data** (game lists, emulator definitions) keeps its licence file next to it and is credited in the
  README.
- **No secrets.** Keys and passwords never go in the repository ([credentials](#credentials)).

## Build and check

| Tool | Version |
|---|---|
| Godot | 4.7.2, with its export templates |
| JDK | 17 |
| Android SDK | platform 36, build tools 36.1.0, NDK 29.0.14206865, CMake 3.22.1 (Gradle installs the missing ones) |
| Python | 3.10 or later |
| gdtoolkit | 4 (`pip install --user "gdtoolkit==4.*"`), for `gdlint` |
| adb | only to install on a device |

```sh
export JAVA_HOME=/path/to/jdk-17 ANDROID_HOME=/path/to/android-sdk
export GODOT=/path/to/godot                                  # if godot is not on PATH

scripts/build.sh                                             # every check and test, then build/cartouche-debug.apk
scripts/build.sh --install                                   # the same, then installs and starts it on the device
$GODOT --path app                                            # the app on your computer, on a demo library

cd kotlin && ./gradlew :core:test --tests '*ScanTest'        # one core test class
cd kotlin && ./gradlew :android:testDebugUnitTest --tests '*LauncherTest'
GODOT=$GODOT scripts/test_godot.sh --changed                 # the GDScript suites of what changed since main
GODOT=$GODOT scripts/test_godot.sh res://test/screens        # one GDScript folder or file
python3 scripts/check_docs.py                                # every path, name and link the docs cite
```

The first run is slow: Godot imports the project and Gradle downloads its dependencies. On a desktop the app
answers from a demo library in place of the Android plugin: every screen and animation plays, and a launch fails
at its end, as there is no emulator. A device is needed only for what Android does
([docs/device-testing.md](docs/device-testing.md)).

`scripts/build.sh` stops at its first failure. Its steps, in order, and where each one's output is:

| Step | On failure, read |
|---|---|
| `scripts/check_docs.py` | the `file:line` it prints. It reads only tracked files: `git add` a new file first |
| `gdlint` on every app script (`gdlintrc`) | `build/gdlint.log` |
| the engine template's checks: no class of `tools/godot/cartouche.gdbuild` named, the pipeline list whole | the message ([the engine template](docs/README.md#the-engine-template)) |
| Kotlin: `ktlint`, tests, Android lint, the plugin's build | Gradle's output, then `build/reports/` of each module in `kotlin/` |
| every GDScript test, the asset checks included | `build/test-godot.log`, each file's own log in `build/test-godot/` |
| `scripts/check_release.sh`: a release pack holds no debug bridge and starts | its output |
| a short headless run of the project | `build/run.log` |
| the APK export (`scripts/export_apk.sh`) | `build/export.log` |

More ways to find a failure: [docs/README.md](docs/README.md#when-something-fails).

### Credentials

ScreenScraper's developer key reaches a build from `kotlin/local.properties` (`screenscraper.devid`,
`screenscraper.devpassword`, `screenscraper.softname`, and for debug builds a member's `screenscraper.ssid` and
`screenscraper.sspassword`) or from the matching `SCREENSCRAPER_*` environment variables. A build without a key
gets no ScreenScraper image. Tests never use real credentials.

## Rules of the code

`gdlint`, `ktlint`, `explicitApi()` and Godot's typing warnings, set as errors, check most of the style in the build.

- **Three layers.** Domain rules live in the Kotlin core (`kotlin/core/`). The Android plugin (`kotlin/android/`)
  adapts Android to the core. GDScript (`app/`) draws, reads input and plays sound: a rule about games, files or
  launches never goes there ([docs/architecture.md](docs/architecture.md)).
- **Kotlin is typed functional code.** No `null`, `!!` or `lateinit`: absence is `Option`, failure a typed error
  (`Either` or Arrow's `Raise`). Values are immutable. A `when` over a sealed type lists every case, never `else`.
  Functions are total: bad input gives a typed error, never an exception.
- **GDScript is fully typed**, in the Godot style guide's member order. Scenes hold the UI; unique-name (`%`) nodes
  are typed `@onready` members. Input goes through InputMap actions, each with a keyboard key too. Text the user
  reads goes through `tr()`.
- **Short and plain.** The shortest code with the same behaviour, one idiom per need: search for the helper before
  you write one. No dead code.
- **Comments say why**, on code people read often. They never repeat the code.
- **Tests.** Every change comes with its tests; a fix with a test that fails without it
  ([docs/testing.md](docs/testing.md)). The guarantees of [docs/INVARIANTS.md](docs/INVARIANTS.md) are never
  weakened: if a change needs to, open an issue first.
- **Shaders** compile only when something draws with them, so headless runs miss their errors: after changing one,
  run the app and look for `"SHADER ERROR"` in its output.

## Pull requests

One change per pull request. A big change (a new screen, a new setting, a change of how something works) starts
with an issue, so it is agreed before you spend time on code. A good pull request:

- says what changes for the user, in one or two sentences, and why, and links the issue it closes;
- has tests for the new behaviour, and `scripts/build.sh` passes;
- for a visible change, shows a screenshot or a short clip of the desktop build (the demo library, never your own
  games);
- updates the docs it makes wrong, and adds a line to `CHANGELOG.md` under Unreleased when users will notice;
- touches nothing else: no reformatting or renaming the change does not need.

## Where to ask

Open an issue: a question, a bug, an idea or a design to discuss. For a bug, say what you did, what you expected,
what happened and your Android version, and attach the traces of `scripts/logs.sh` if you can.
