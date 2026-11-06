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
| `Reference.kt` | Everything `loadCatalog` loads (catalog, data folders, curtain times) as one immutable value. A platform's tables (title list, prints, art extract, texture table) are not sent by Godot: the plugin reads them from the APK's assets (Godot's export stores `res://data` there) the first time that platform needs them, on the thread asking (never Godot's), and indexes them once. |
| `DebugOptions.kt` | The launch arguments of a debug build (`--art-refused`, `--art-slow`, `--launch-slow`, `--screenscraper`), parsed once. |
| `PendingPick.kt` | A system picker awaiting its activity result. Each pick is answered exactly once (INV-06). |
| `Battery.kt` | `BatteryWatch` follows the battery broadcast from resume to pause and sends each change through `battery_changed`. |
| `InstalledApps.kt` | Whether a package is installed. |
| `NativeHeap.kt` | Hands the memory Godot and the graphics driver freed back to the system (`mallopt(M_PURGE)` in `kotlin/android/src/main/cpp/native_heap.c`, the plugin's only C). The C allocator otherwise keeps it for reuse: about 100 MB after the start. `releaseMemory` runs it off Godot's thread, when the screen comes to rest and when the app leaves the screen (`Resting`). |

Inside `CartouchePlugin.kt`, each need has one helper. `onLibrary(requestId) { }` runs a call on the library
thread and answers it. `storedSettings`, a `StateFile`, holds the stored settings. `timed(area, describe) { }`, in
`Wire.kt`, traces how long a step took. A new method uses them rather than its own threading or error handling.

## The wire

| File | Responsibility |
|---|---|
| `Sent.kt` | Every type the plugin sends to Godot (`Sent.Library`, `Sent.SettingsAnswer`…), and how each is made from the core's values. |
| `Wire.kt` | The JSON every value crosses as (`wireJson`), an answer's envelope (`answered`), the failure codes (`Code`), `trace` (one debug log line) and `timed`. |

Every getter, answer and signal crosses as one JSON text: Godot parses one text far faster than thousands of
Dictionaries, and only texts cross the JNI bridge (INV-23). An answer is `{"request_id", "ok", …its fields}`, a
failure `{"request_id", "ok": false, "code", "detail"}`, and a library call adds the library's `"revision"`. Keys
are the properties' names in snake_case, an enum crosses as its `@SerialName` (the stored name too), and an
`Option` is an absent key until it has a value. `app/adapters/android/android_wire.gd` is generated from these types
by `WireScriptTest`, with `has_<key>` beside each `Option`; only the members a class has by hand, below its
`# By hand` line, are edited there. After changing `Sent.kt`:
`cd kotlin && ./gradlew :android:testDebugUnitTest --tests '*WireScriptTest' -Pwire.write=true`.

## Storage

Package `storage`. Every file the plugin writes goes through `AtomicText.kt`: an interrupted write leaves the
previous file, never half of the new one.

| File | Responsibility |
|---|---|
| `Folders.kt` | Folders picked with the system picker: keeping read access (nothing more), listing a level for `FolderWalk`, and reading a file's facts (a scan reads three files at once, `LibraryService.readAll`). |
| `DocumentBytes.kt` | A document opened read-only as the core's `ByteSource`. |
| `FactsStore.kt` | What each platform's files told, with the size and date they had then, so a rescan reads only new or changed files. |
| `LibraryStore.kt` | The library file. An unreadable one is set aside, not lost (INV-11). |
| `StateFile.kt` | A small state in its own file (the selection, the settings, the games not seen yet, what art and ScreenScraper remember), read once and written only when it changes. |

## Library

`LibraryService.kt` (package `library`) runs scans, counts (`preview`, a scan that saves nothing), choices, removals,
selections and launch lookups, one at a time on the library thread. A scan reads the facts of new or changed
files, keeps them in `FactsStore`, and hands them to `Scan.of`. Each library it keeps is published with its
`Finders`, built in the background, so `browse` and `titleMarks` answer a typed key within the frame. Setting up
or removing a platform gives up the folder access no platform uses any more. A re-read (`reread`, asked by
`refreshPlatform` one console at a time as the app comes to the screen) is a scan that writes the library only when
it changed, answers it only when its games changed, and marks the games it brought (`Arrivals`), none while the
console's new setup awaits its scan; `enterConsole` and `leaveGame` clear those marks, a removal or a scan drops those
of the games gone. Every library call answers the library's `revision`, one more at each write: Godot shows a library
a re-read sent only when no answer told a newer one since, else it asks `currentLibrary`.

## Launch

Package `launch`.

| File | Responsibility |
|---|---|
| `IntentMapper.kt` | Builds the intent from a resolved `LaunchSpec`, with read access to the game file only (INV-01). |
| `Launcher.kt` | `checkGame` checks the emulator is installed and the file still there, and starts nothing (INV-05). `prepareGame` repeats the checks and stops a lingering emulator on older Android versions, unless the start is already too late. `start` starts the activity on the main thread. |
| `LateStart.kt` | `startInTime`: runs the start only before its `StartDeadline`, else answers `too_late` with nothing started (INV-21). |
| `Curtain.kt` | The black window over every app while the emulator starts, lowered after its time or when Cartouche is back (INV-07). It needs the "display over other apps" permission. |

A launch goes `checkLaunch` (the core's `Catalog.launch`, then `Launcher.checkGame`), then `launchGame` (refused as `too_late`
once `within_ms` has passed since it was asked, else the curtain, then `Launcher.start`). [../README.md](../README.md#how-a-press-travels) draws the round trip.

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

A setting is declared once in the core (`Setting.kt`); `saveSetting` stores any declared one, checked against its
declaration, and `Sent.SettingsAnswer` sends them all. The steps: [../adding-a-setting.md](../adding-a-setting.md).

## Neighbours

- Down: [core.md](core.md), the rules this package calls.
- Up: [godot.md](godot.md), whose adapter is the only caller.
- Tests, Robolectric and the fakes: [../testing.md](../testing.md#kotlin).
- The words: [../GLOSSARY.md](../GLOSSARY.md). Back to the entry: [../README.md](../README.md).
