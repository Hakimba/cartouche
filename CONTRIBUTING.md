# Contributing to Cartouche

Thank you for wanting to help. This page says what a contribution must respect, how to build and test the app, and
what a good pull request looks like. The code itself is explained in [docs/README.md](docs/README.md): start there
once you have built the app.

## Licence

Cartouche is free software under the [GNU GPL v3 or later](LICENSE). By sending a pull request, you agree that
your contribution is released under the same licence. Every new source file starts with the line
`SPDX-License-Identifier: GPL-3.0-or-later` in a comment.

## What you may bring in

- **Your own work only.** Never copy code, pictures, sounds, icons or layouts from another launcher or front-end,
  even an open-source one. Ideas are welcome; their code and assets are not. If you studied another app, write
  your version from scratch.
- **3D models** must be under CC0, CC-BY or CC-BY-SA. Keep the licence text beside the model
  (`LICENSE.txt` in its console or medium folder, like `app/carousel/consoles/nes/LICENSE.txt`), and credit the
  author in the README's credits. Models under a "non-commercial" or "no derivatives" licence cannot be used.
- **Data** from a third party (game lists, emulator definitions) keeps its licence file next to it, and is credited
  in the README.
- **No secrets.** API keys and passwords never go in the repository (see
  [Credentials](docs/README.md#credentials)).

## Build and run

You need:

| Tool | Version |
|---|---|
| Godot | 4.7.2, with its export templates |
| JDK | 17 |
| Android SDK | platform 36, build tools 36.1.0, NDK 29.0.14206865, CMake 3.22.1 (Gradle installs the missing ones) |
| Python | 3.10 or later |
| gdtoolkit | 4 (`pip install --user "gdtoolkit==4.*"`), for `gdlint` |
| adb | only to install on a device |

Then, from the repository's root:

```sh
export JAVA_HOME=/path/to/jdk-17 ANDROID_HOME=/path/to/android-sdk
export GODOT=/path/to/godot     # if godot is not on PATH
scripts/build.sh                # every check and test, then the debug APK in build/
```

The first run takes a while: Godot imports the project and Gradle downloads its dependencies.

You do not need a device to work on most of the app. On a desktop, the Godot project answers from a demo library
instead of the Android plugin, and every screen and animation plays:

```sh
$GODOT --path app                                    # the app, with the demo library
$GODOT --path app -- --welcome=skip --shelf=gba      # skip the title screen, start on the Game Boy Advance
$GODOT --path app -- --launch=rehearse               # a launch plays to the end, then comes back
```

You can also open `app/` in the Godot editor and press Play. The arguments after `--` are debug arguments; the
full list is in [docs/README.md](docs/README.md#diagnostics-and-debug-arguments).

To try a build on an Android device, read [docs/device-testing.md](docs/device-testing.md) first.

## Tests

Every change comes with its tests, and every test passes before a pull request is merged. A bug fix comes with a
test that fails without the fix. [docs/testing.md](docs/testing.md) explains each kind of test and its helpers.

```sh
scripts/build.sh                                          # everything, once before you send your pull request
cd kotlin && ./gradlew :core:test --tests '*ScanTest'     # one Kotlin test class while you work
GODOT=$GODOT scripts/test_godot.sh res://test/screens     # one GDScript test folder
python3 scripts/check_docs.py                             # every path and name the docs cite still exists
```

`scripts/check_docs.py` reads only the files git tracks: run `git add` on a new file before you run it.

The guarantees in [docs/INVARIANTS.md](docs/INVARIANTS.md) are never weakened. If your change needs to weaken one,
open an issue first.

## Style

The build checks most of the style for you: `gdlint` for GDScript (`gdlintrc`), `ktlint` for Kotlin
(`.editorconfig`), and the Godot project treats typing warnings as errors.

- **The three layers.** Domain rules live in the Kotlin core (`kotlin/core/`). The Android plugin
  (`kotlin/android/`) adapts Android to the core. GDScript (`app/`) only draws, reads input and plays sound. A
  rule about games, files or launches never goes in GDScript.
- **Kotlin is typed functional code.** No `null`, `!!` or `lateinit`: absence is `Option`, failure a typed error
  (`Either` or Arrow's `Raise`). Values are immutable. A `when` over a sealed type lists every case, never `else`.
  Functions are total: bad input gives a typed error, never an exception.
- **GDScript is fully typed.** Every variable, parameter and return has a type. Members follow the Godot style
  guide's order. Text the user reads goes through `tr()`.
- **Short and plain.** The shortest code with the same behaviour. Before writing a helper, search for the one that
  already exists. No dead code.
- **Comments say why**, on code people read often. They never repeat what the code says.

[docs/README.md](docs/README.md#rules-of-the-code) has the full list.

## Pull requests

**One change per pull request.** A new console, a fix, a translation: each its own pull request. A big change
(a new screen, a new setting, a change of how something works) starts with an issue, so we agree on it before you
spend time on code.

A good pull request:

- says what changes for the user, in one or two sentences, and why;
- links the issue it closes;
- has tests for the new behaviour, and `scripts/build.sh` passes;
- for a visible change, shows a screenshot or a short clip of the desktop build (the demo library, never your own
  games);
- updates the docs it makes wrong (`scripts/check_docs.py` finds the stale paths and names), and adds a line to
  `CHANGELOG.md` under `[Unreleased]` when users will notice the change;
- touches nothing else: no reformatting or renaming of code the change does not need.

## Where to ask

Open an issue on this repository: a question, a bug, an idea or a design you want to discuss. For a bug, say what
you did, what you expected, what happened, your Android version, and attach the traces of `scripts/logs.sh` if you
can.
