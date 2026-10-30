# Testing

**You are here.** How Cartouche is tested: the kinds of tests, where each lives, the helpers they share and the
command that runs them. Kotlin tests run on the JVM with Kotest and JUnit, the Android ones under Robolectric.
GDScript tests run headless in Godot with GdUnit4. The guarantees they protect are in
[INVARIANTS.md](INVARIANTS.md). The code they test is described in [architecture/core.md](architecture/core.md),
[architecture/android.md](architecture/android.md) and [architecture/godot.md](architecture/godot.md).

## What a test is

A test asserts a behaviour from the outside: a result, or an effect a user or the plugin would see. Name it after
that behaviour, in a sentence. Before you keep a test, name the defect it catches.

There are four kinds. Copy the closest existing test.

| Kind | What it does | Example |
|---|---|---|
| Example | one concrete case, set up, run, checked on its typed result | `ScanTest`, "games get their reference title, regions and serials" |
| Property | a law stated over generated cases: a round trip, never failing, not depending on an order | `FolderWalkTest`, "every file of readable, visible folders is listed once" |
| Invariant | a property of [INVARIANTS.md](INVARIANTS.md), its id first in its name | `INV-08 …` in `ScanTest`, `test_inv_20_…` in `resting_test.gd` |
| Walk | a seeded run of presses through real screens, checked at each step | `live_screen_test.gd` (INV-20) |

Rules every test keeps:

- Check typed values, never messages or log text.
- A property that filters its cases also checks that enough cases reach the code under test
  (`forEveryResolvedTemplate` does it for launch templates).
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

Gradle runs the tests in parallel and caches what did not change. A repeat run with nothing changed takes seconds.

### Where Kotlin tests live

A class's test sits in the same package: `kotlin/core/src/test/kotlin/app/cartouche/core/library/ScanTest.kt`
tests `Scan.kt`. Shared helpers live in `kotlin/core/src/testFixtures/`, one `Generators.kt`, `Fixtures.kt` and
`Fakes.kt` per package, used by both modules:

| Helper | What it gives |
|---|---|
| `InMemoryFolders` | a folder tree in memory, for `FolderWalk` and scans |
| `InMemoryBytes` | a file's bytes in memory, which can stand for a file of gigabytes |
| `Generators.kt` of each package | Kotest `Arb`s of the package's values, reaching the edge cases |
| `Shipped` (core tests) | the data files of `app/data`, so tests read the real files, not copies |
| `FakeDocuments` (plugin tests) | a fake documents provider serving real files |
| `FakeFetch`, `FakeHttp` (plugin tests) | downloads without a network |

The disc images the file readers decode are in `kotlin/core/src/test/resources/files`, made by
`dev/file_fixtures.py`.

### Property counts

`PropertyCounts` (`kotlin/core/src/testFixtures/kotlin/app/cartouche/core/PropertyCounts.kt`) sets how many cases
a property draws from its test's name: 1000 for a test named `INV-…`, 100 for any other. Give an invariant test its
id first and it gets the stronger run. A Robolectric test runs in a sandbox with its own copy of Kotest, which the
listener does not reach: there every property draws Kotest's default, 1000, whatever its name.

### Android versions

Robolectric runs each plugin test on one Android version by default (`robolectric.properties`). A class whose
behaviour depends on the API level lists its own with `@Config(sdk = [30, 33, 34])`, as `LauncherTest` and
`FoldersTest` do. Add the annotation when you write code that branches on `Build.VERSION`.

## GDScript

```sh
GODOT=$GODOT dev/test_godot.sh                                      # every GDScript test
GODOT=$GODOT dev/test_godot.sh res://test/screens                   # one folder
GODOT=$GODOT dev/test_godot.sh res://test/carousel/finger_test.gd   # one file
```

`dev/test_godot.sh` downloads the pinned GdUnit4 release once into `build/`, then runs one Godot process per test
file, four at a time, largest file first. Each process has its own user data folder, so no suite sees what another
left behind. `GODOT_TESTS_JOBS` sets how many run at once, and `GODOT_TESTS_S` bounds each file's time. Each file's
log is in `build/test-godot/`, named after its path below `app/test/`, all of them merged in
`build/test-godot.log`. A run fails on any failure, error or orphan node, and on a file that ends without its
summary. Every process runs with `--fixed-fps 60`, so a seeded walk of presses takes the same path however
loaded the machine is; the editor's GdUnit panel runs without it, so run tests through the script.

Tests live under `app/test/`, in folders that mirror `app/`. Shared helpers:

| Helper | What it gives |
|---|---|
| `app/test/carousel/fixtures.gd` | `cases(seed)` (seeded random cases, so a failure always comes back), `shown_carousel`, `step_frame` and `step_until` (drive frames by hand), `press`, shape generators such as `drawn_around` |
| `app/test/screens/fixtures.gd` | `NewDevice`, an `AndroidServices` whose answers a test sets; `carousel_for`, `past_first_launch`, `on_form`; `alive`, which says something on screen takes the next press |
| `app/test/studio/views/views_fixtures.gd` | the media views and plinth, for the Studio tests |
| `app/test/dev/bridge/fixtures.gd` | a bridge and its commands, for the bridge tests |

A GDScript test never reaches the real plugin: it uses `NewDevice` or the desktop stand-in. Drive time with
`step_frame`, never with real waits.

## Invariant tests

Each invariant has tests named after its id (Kotlin `INV-07 …`, GDScript `test_inv_20_…`), so a search finds them
all:

```sh
grep -rn 'INV-07\|inv_07' kotlin app/test
```

A test that carries an invariant states it from outside, over generated cases where it can. Weakening an invariant, or the
test that carries it, is a decision to discuss in an issue first.

## Pictures and benchmarks

Some changes must keep every pixel or every frame time. Two tools measure that.

`FrameShots` (`app/dev/frame_shots.gd`) saves pictures of the carousel at set frames, presses sent at set frames
too. With Godot's fixed frame time, two runs of the same code give the same pictures:

```sh
$GODOT --path app --fixed-fps 60 --resolution 1280x960 -- --welcome=skip --shelf=ps2 --shots="$PWD/build/shots/before"
```

Run it before and after a change, once on a console with its own model and once on a platform drawn by its medium,
and compare the pictures. An optimisation must leave all of them identical.

`dev/bench.sh` measures the debug build installed on a device: cold starts, then each `CarouselBench` scenario
(`app/dev/carousel_bench.gd`) for a fixed time, at several library sizes. `--record FILE` appends each measure as
one JSON line, and `--label` names the run:

```sh
dev/build.sh --install && dev/bench.sh --record build/bench.jsonl --label my-change 150 1000
```

## Neighbours

- [INVARIANTS.md](INVARIANTS.md): what the invariant tests carry.
- [architecture/core.md](architecture/core.md), [architecture/android.md](architecture/android.md),
  [architecture/godot.md](architecture/godot.md): the code under test.
- [debug-bridge.md](debug-bridge.md): driving a running build from a test harness.
- Back to the entry: [ONBOARDING.md](ONBOARDING.md).
