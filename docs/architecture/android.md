# The Android plugin (`kotlin/android`)

**You are here.** The plugin is a Godot Android plugin (v2). It adapts Android to the core: it opens folders and
files through the documents provider, starts emulators, downloads art, stores the library, and runs all of it off
Godot's thread. It holds the app's only mutable state. It depends on the core ([core.md](core.md)) for every
rule. On the Godot side, only `AndroidServices` (`app/adapters/android/android_services.gd`) calls it
([godot.md](godot.md#the-adapter)).

Files below live under `kotlin/android/src/main/kotlin/app/cartouche/android/`, their tests under
`kotlin/android/src/test/kotlin/app/cartouche/android/`. `kotlin/android/src/main/AndroidManifest.xml` lists the
permissions, each with the reason in a comment.

## The plugin object

| File | Responsibility |
|---|---|
| `CartouchePlugin.kt` | The only class Godot sees (the `CartoucheAndroid` singleton). Its `@UsedByGodot` methods are the whole API. Getters answer at once. Operations take a request id and answer it once through the `answered` signal. |
| `Threads.kt` | The coroutine scope and the dispatchers: one library thread that runs library work in arrival order, a low-priority planning thread, and the variant downloads. Tests pass their own through the internal constructor. |
| `Reference.kt` | Everything `loadCatalog` loads (catalog, title lists, prints, data folders, curtain times, art extracts, texture tables) as one immutable value, with its indexes built on first use. |
| `DebugOptions.kt` | The launch arguments of a debug build (`--art-refused`, `--art-slow`, `--screenscraper`), parsed once. |
| `PendingPick.kt` | A system picker awaiting its activity result. Each pick is answered exactly once (INV-06). |
| `Battery.kt` | `BatteryWatch` follows the battery broadcast from resume to pause and sends each change through `battery_changed`. |
| `InstalledApps.kt` | Whether a package is installed, and the apps with a launcher entry. |

Inside `CartouchePlugin.kt`, each need has one helper. `onLibrary(requestId) { }` runs a call on the library
thread and answers it. `save(note) { change }` changes the stored settings. `timed(area, describe) { }`, in
`Wire.kt`, traces how long a step took. A new method uses them rather than its own threading or error handling.

## The wire

| File | Responsibility |
|---|---|
| `Wire.kt` | The Dictionary format of every answer, the stable error codes (`ErrorCode`), `trace` (one debug log line) and `timed`. |
| `WireJson.kt` | The library and its shelves as one JSON text. Godot parses one text far faster than thousands of Dictionaries. |

A field's wire name comes from its `@SerialName`, so the stored and the sent names cannot drift. `WireTest` checks
that only values the JNI bridge converts are sent (INV-23). The Godot side of the format is
`app/adapters/android/android_wire.gd`, one class per answer.

## Storage

Package `storage`. Every file the plugin writes goes through `AtomicText.kt`: an interrupted write leaves the
previous file, never half of the new one.

| File | Responsibility |
|---|---|
| `Folders.kt` | Folders picked with the system picker: keeping read access (nothing more), listing a level for `FolderWalk`, and reading a file's facts. |
| `DocumentBytes.kt` | A document opened read-only as the core's `ByteSource`. |
| `FactsStore.kt` | What each platform's files told, with the size and date they had then, so a rescan reads only new or changed files. |
| `LibraryStore.kt` | The library file. An unreadable one is set aside, not lost (INV-11). |
| `SelectionStore.kt`, `SettingsStore.kt` | The selection and the settings, each in its own file. |

## Library

`LibraryService.kt` (package `library`) runs scans, counts (`preview`, a scan that saves nothing), choices, removals,
selections and launch lookups, one at a time on the library thread. A scan reads the facts of new or changed
files, keeps them in `FactsStore`, and hands them to `Scan.of`. Each library it keeps is published with its
`Finders`, built in the background, so `browse` and `titleMarks` answer a typed key within the frame. Setting up
or removing a platform gives up the folder access no platform uses any more.

## Launch

Package `launch`.

| File | Responsibility |
|---|---|
| `IntentMapper.kt` | Builds the intent from a resolved `LaunchSpec`, with read access to the game file only (INV-01). |
| `Launcher.kt` | `checkGame` checks the emulator is installed and the file still there, and starts nothing (INV-05). `prepareGame` repeats the checks and stops a lingering emulator on older Android versions. `start` starts the activity on the main thread. |
| `Curtain.kt` | The black window over every app while the emulator starts, lowered after its time or when Cartouche is back (INV-07). It needs the "display over other apps" permission. |

A launch goes `checkLaunch` (the core's `Catalog.launch`, then `Launcher.checkGame`), then `launchGame` (the curtain,
then `Launcher.start`). [../ONBOARDING.md](../ONBOARDING.md#how-a-press-travels) draws the round trip.

## Art

Package `art`. The core decides which images a game may get and in which order ([core.md](core.md#art)). This
package downloads, cuts and stores them.

| File | Responsibility |
|---|---|
| `ArtService.kt` | Coordinates art for the plugin: starts runs after the library is read, after each scan and after a removal, applies the preferred region, the label choices and the variant downloads. Its pieces share one `Fetch`, so every download counts on the same limits. |
| `Scraper.kt` | A run: hands its requests to a few workers, stops while a game is played, resumes when the network is back or after a growing delay, and tells Godot through `art_changed` and `art_progress`. `artFocus` puts the games on screen first. |
| `Fetch.kt` | The download port (`Fetch`) and its HTTP side (`Http`, `JavaHttp`, `HttpFetch`), with download progress (`Paced`). |
| `ArtFetching.kt` | Builds the app's `Fetch`, the debug switches applied. |
| `ScreenScraperFetch.kt` | The one gate every ScreenScraper request goes through: its limits, its back-off, and the credentials built into the app (`Credentials.fromBuild`), never stored or traced (INV-19). |
| `ArtImages.kt` | Cuts a downloaded image to its label (`LabelCut`) and encodes it. |
| `ArtStore.kt` | One stored image per game, written whole or not at all (INV-18), plus the variants shown in the properties and the marks of provisional labels. |
| `VariantDownloads.kt` | Downloads a game's other images when its properties show them, sent through `label_variant_downloaded`. |
| `LabelChoices.kt` | Records the user's choice of image and adopts it as the game's label. |
| `OwnPictures.kt` | A picture of the user's own: picked with the system picker, then cut to its framing. Never replaced by a download (INV-16). |

## Adding a setting

A setting crosses every layer. Follow `soundLevel` (the sound level) through these files:

1. `kotlin/core/src/main/kotlin/app/cartouche/core/settings/Settings.kt`: the field and its default.
   `SettingsFormat.kt` stores it with the rest.
2. `CartouchePlugin.kt`: a `@UsedByGodot` method such as `saveSoundLevel` that validates and calls `save(note) { change }`.
3. `Wire.kt`: the field in `Settings.toWire`.
4. `app/adapters/android/android_wire.gd`: the field in `SettingsAnswer`.
5. `app/adapters/android/android_services.gd`: the coroutine, such as `save_sound_level`.
6. `app/adapters/desktop/desktop_plugin.gd`: the default in its settings and the same method, so the desktop run
   keeps working.
7. The screen: `app/screens/settings_menu.gd` shows it, `app/screens/screen_flow.gd` reads it at start and saves it.
8. Tests: `SettingsTest` and `CartouchePluginTest` (written and read back, INV-15), `settings_test.gd`.

## Neighbours

- Down: [core.md](core.md), the rules this package calls.
- Up: [godot.md](godot.md), whose adapter is the only caller.
- Tests, Robolectric and the fakes: [../testing.md](../testing.md#kotlin).
- The words: [../GLOSSARY.md](../GLOSSARY.md). Back to the entry: [../ONBOARDING.md](../ONBOARDING.md).
