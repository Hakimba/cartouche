# Testing

Kotlin tests run on the JVM with Kotest and JUnit, the plugin's under Robolectric. GDScript tests run headless in
Godot with GdUnit4. The guarantees they protect are in [INVARIANTS.md](INVARIANTS.md).

## What a test is

A test asserts a behaviour from the outside: a result, or an effect a user or the plugin would see. Name it after
that behaviour, in a sentence. Before you keep a test, name the defect it catches. Copy the closest existing one.

| Kind | What it does | Example |
|---|---|---|
| Example | one concrete case, checked on its typed result | `ScanTest`, "games get their reference title, regions and serials" |
| Property | a law over generated cases: a round trip, never failing, not depending on an order | `FolderWalkTest`, "every file of readable, visible folders is listed once" |
| Invariant | a property of [INVARIANTS.md](INVARIANTS.md), its id first in its name | `INV-08 …` in `ScanTest`, `test_inv_20_…` in `resting_test.gd` |
| Walk | a seeded run of presses through the real screens, each compared with a model of the screens | `live_screen_test.gd` |

- Check typed values, never messages or log text.
- A property that filters its cases also checks that enough of them reach the code under test
  (`forEveryResolvedTemplate`).
- Fake a port, never Cartouche's own code. No real clock, no sleeps, no network.
- Never assert a visual constant, a pixel, a duration or a recipe: assert what it does.
- Generators, fixtures and fakes are shared, never redefined in a test.

## Kotlin

```sh
cd kotlin && ./gradlew :core:test                                   # every core test
cd kotlin && ./gradlew :core:test --tests '*ScanTest'               # one class
cd kotlin && ./gradlew :android:testDebugUnitTest                   # every plugin test, under Robolectric
cd kotlin && ./gradlew ktlintCheck                                  # the Kotlin style
```

A class's test sits in its package (`kotlin/core/src/test/kotlin/app/cartouche/core/library/ScanTest.kt` tests
`Scan.kt`). Shared helpers are in `kotlin/core/src/testFixtures/`, one `Generators.kt`, `Fixtures.kt` and
`Fakes.kt` per package, used by both modules.

| Helper | Gives |
|---|---|
| `Generators.kt` of each package | Kotest `Arb`s of the package's values, reaching the edge cases |
| `InMemoryFolders`, `InMemoryBytes` | a folder tree and a file's bytes in memory; the bytes can stand for a file of gigabytes |
| `Shipped` | the data files of `app/data`, so tests read the real files |
| `FakeDocuments` (plugin) | a fake documents provider serving real files |
| `FakeFetch`, `FakeHttp` (plugin) | downloads without a network |
| `kotlin/core/src/test/resources/files` | the disc images the file readers decode, made by `scripts/file_fixtures.py` |
| `kotlin/core/src/test/resources/library` | libraries as released builds stored them, read by `LibraryGoldenTest` |

- **Property counts.** `PropertyCounts` draws 1000 cases for a test named `INV-…`, 100 for any other. Under
  Robolectric every property draws 1000.
- **Android versions.** A plugin test runs on one Android version (`robolectric.properties`). A class whose
  behaviour depends on the API level lists its own with `@Config(sdk = [30, 33, 34])`, as `LauncherTest` does.

## GDScript

```sh
GODOT=$GODOT scripts/test_godot.sh --changed                            # the suites of what changed since main
GODOT=$GODOT scripts/test_godot.sh res://test/screens                   # one folder
GODOT=$GODOT scripts/test_godot.sh res://test/carousel/finger_test.gd   # one file
GODOT=$GODOT scripts/test_godot.sh                                      # everything; asset checks only if they changed
GODOT=$GODOT scripts/test_godot.sh res://test                           # everything, the asset checks included
```

`scripts/test_godot.sh` downloads the pinned GdUnit4 once into `build/`, then runs one Godot process per test file,
each with its own user data folder; the files that build no scene share one process. A run fails on any failure,
error or orphan node. Always run tests through the script: it passes `--fixed-fps 60`, so a seeded walk takes the
same path on any machine.

| What | How |
|---|---|
| Logs | `build/test-godot/`, one file per test file, merged in `build/test-godot.log` |
| `--changed` | runs the suites of the leaf folders a change touches; everything when the change is a script many things depend on (the carousel's own scripts, screens, adapters, studio, locale, fonts, data, the test helpers); nothing for a change under `kotlin/` |
| The asset checks (`app/test/assets/`) | geometry and proportions of every shipped console and medium. They run when a path names them, and otherwise only when what they check changed since `main` |
| `GODOT_TESTS_JOBS`, `GODOT_TESTS_S` | how many processes run at once (4), and the seconds one file may take (900) |
| `fonts_test.gd` | compares drawn text with a reference and needs a window, so the headless run skips it. Run it alone, as below |

```sh
$GODOT --path app -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test/studio/fonts_test.gd
```

Tests live under `app/test/`, in folders that mirror `app/`. A test never reaches the real plugin, and drives time
with `step_frame`, never with real waits.

| Helper | Gives |
|---|---|
| `app/test/carousel/fixtures.gd` | `cases(seed)` (seeded random cases), `new_carousel`, `shown_carousel`, `step_frame`, `step_until`, `press`, `console_folders()`, shape generators. `Scripted`, the fake plugin: a test scripts each request's answer (`answers[Request.SCAN] = Answer.HELD` waits until `release()`; `LATER`, `FAILS`, `NEVER`) |
| `app/test/screens/fixtures.gd` | `NewDevice` (a `Scripted` device from its first launch), `past_first_launch`, `shown`, `on_form`, `wait`, `on_screen`, `press_to`, `settled`, and `alive`: whether something on screen takes the next press |
| `app/test/vectors/` | cases (label framings, the names a game keeps) that a core test and a GDScript test both read |
| `app/test/carousel/search/recorded_searches.json` | the core's own search answers, written by `RecordedSearchesTest` and read through `recorded.gd`. A query not recorded stops the test: add it to the list that test names |

### The walk

`app/test/screens/live_screen_test.gd` carries INV-20. From 0, 1, 2 or 3 consoles it draws 900 seeded presses and
finger gestures, answers of the fake device held or failing at random, and after each one compares the app with a
model of the screens: the screen, the focus, the selection, what the device was asked, and that something takes the
next press.

| File | Role | Add to it |
|---|---|---|
| `app/test/screens/screen_model.gd` | the model: `TABLE`, one row per screen and press, with the screen reached and the control focused. It reads no node | a new screen's or press's rows |
| `app/test/screens/screen_watch.gd` | the one place the walk reads the app | a new page's node name in `_PAGES` |
| `Fixtures.alive` in `app/test/screens/fixtures.gd` | what counts as taking the next press | a new busy state of the carousel |
| `app/dev/screen_agreement.gd` | whether what the carousel shows agrees with its screen once still; the debug bridge's `state` tells the same | a part only one screen shows |

`WALK_SEEDS=n` in the environment walks n seeds per start instead of one, each to its end; a failure prints its
seed and the path to replay. `KNOWN` in the test lists the findings the walk meets and goes on from: fixing one
deletes its line.

## Pictures and benchmarks

- **The same pictures.** `FrameShots` saves pictures at set frames, presses sent at set frames too; with a fixed
  frame time two runs of the same code give the same pictures. Run it before and after a change that must keep
  every pixel, and compare:

  ```sh
  $GODOT --path app --fixed-fps 60 --resolution 1280x960 -- --welcome=skip --shelf=ps2 --launch=rehearse --shots="$PWD/build/shots/before"
  ```

- **A screen as the app says it.** The debug bridge's `state` and `shot` give the screen the app is on and its
  picture ([debug-bridge.md](debug-bridge.md)).
- **Frame times and memory** on a device: [device-testing.md](device-testing.md#benchmarks).
