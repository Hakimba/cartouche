# Invariants

The guarantees every change must keep. An invariant exists only where breaking it would lose or corrupt the
user's data, launch the wrong game, leave the app stuck or crashed, or break a security promise; everything else
is an ordinary test, or a check by hand on a device. Every test enforcing an invariant starts its name with its id,
or ids (Kotlin `` `INV-20 …` `` or `` `INV-03 INV-09 …` ``, GDScript `test_inv_20_…`), so a search for `INV-20` or
`test_inv_20…` finds them all, and a core property draws ten times the cases. `scripts/check_docs.py` fails when a
row's Tests column does not list exactly the files holding a test named after its id.
Weakening one is a decision to discuss first, never a side effect of a change.

The list reads from the outside in: what reaches the emulator, then the library on disk, then what the user
chose, then art from the network, then the screens, then the wire to Godot and the release build.

## Launch safety

| Id | Invariant | Why | Tests |
|---|---|---|---|
| INV-01 | A launch can hand the emulator only read access to the one game file chosen; a player definition, a file name or an extra can never grant anything else, and Cartouche never writes to a ROM folder. | Player definitions are third-party data, and an emulator must not reach the rest of a granted folder. | `LaunchTemplateTest`, `IntentMapperTest`, `FoldersTest` |
| INV-02 | Whatever characters a file name holds (quotes, commas, `-n …`), the launch command is the same except for that name. | A file name must not change what is launched or how. | `LaunchTemplateTest` |
| INV-03 | Reading anything external (a template, a definition file, a file name, a game file's bytes) never throws: it gives a value or a typed error, never a blank title, and never modifies the file. | Bad data is reported, not a crash, and game files are the user's. | `LaunchTemplateTest`, `CatalogTest`, `GameNameTest`, `ScanTest`, `ChdImageTest`, `FileReadingTest`, `LibraryServiceTest` |
| INV-04 | The game launched is the one shown in the middle; a game whose file is gone or whose storage is unreadable never launches (it reports `game_missing`), and a template needing a path is never launched without one. | The wrong game, or an emulator started on nothing, is the worst launch. | `LauncherTest`, `LaunchTemplateTest`, `DocumentPathsTest`; `game_search_test.gd` |
| INV-05 | Checking whether a launch can work starts and stops nothing; the launch then fails exactly as the check did. | The check runs while the user waits: it must have no effect of its own. | `LauncherTest` |
| INV-06 | A folder pick is answered exactly once (by its result, by the failure to open the picker, or as cancelled by a newer pick). | A screen waiting for a pick never hangs or gets two answers. | `PendingPickTest` |
| INV-07 | There is never more than one black curtain over the emulator, and it always comes down: after its time (10 s at most) or when Cartouche is back. | A curtain left up hides the game for good. | `CurtainTest`, `CurtainTimesTest` |

## Library scan and storage

| Id | Invariant | Why | Tests |
|---|---|---|---|
| INV-08 | Every file a scan lists ends up in exactly one place (a disc of one game, or the ignored files), whatever order the folder lists them in; every file of the folders scanned is listed once. | Nothing disappears or merges silently, and the same folder always gives the same library. | `ScanTest`, `FolderWalkTest` |
| INV-09 | A scan always ends, even with a hostile documents provider (a folder inside itself, a listing cut short, a removed SD card, more than 10 000 entries); when it fails it changes nothing. | A faulty provider cannot hang the app or empty the library. | `FolderWalkTest`, `FoldersTest`, `LibraryServiceTest` |
| INV-10 | A file is never given a wrong game, serial or art: without a certain match it gets none. | A wrong identification is worse than none. | `ScanTest`, `TitleIndexTest`, `LibraryServiceTest` |
| INV-11 | The stored library reads back identical, a library stored by an older version still loads, and an unreadable library file is set aside, never overwritten. | Restarting or updating the app never loses the library. | `LibraryFormatTest`, `LibraryStoreTest`, `LibraryServiceTest`, `LibraryTest` |
| INV-12 | A rescan keeps what the user chose for games still there, drops games whose files are gone, and touches no other platform. | Rescanning is always safe. | `LibraryTest` |
| INV-13 | Removing a platform removes everything of it (games, choices, art, folder access, counts) and nothing else. | A removal is complete and contained. | `RemovalTest`, `LibraryServiceTest`, `ArtStoreTest`, `AbsencesTest`, `FoldersTest`, `ScrapingTest`; `settings_test.gd` |
| INV-14 | Every definition and manifest shipped in `app/data` and in the console and medium folders loads without rejection. | Updating bundled data must not silently lose an emulator, a console or a medium. | `CatalogTest`; `console_folders_test.gd`, `media_folders_test.gd` |

## What the user chose is kept

| Id | Invariant | Why | Tests |
|---|---|---|---|
| INV-15 | The selection, a game's name and chosen picture, the consoles' order and chosen models, and every setting are written and read back identical, survive a rescan and a restart, and an unreadable file only means defaults. | The user's choices are data too. | `SelectionFormatTest`, `SelectionStoreTest`, `LibraryServiceTest`, `LibraryTest`, `ShelvesTest`, `SettingsFormatTest`, `CartouchePluginTest`; `console_order_test.gd`, `android_services_test.gd` |

## Art

| Id | Invariant | Why | Tests |
|---|---|---|---|
| INV-16 | A game gets only scans of its own game and platform, and a cartridge's label only from a scan of its front's shape; a picture of the user's own is never replaced by a download. | A wrong label shows on every screen, and the user's own picture is theirs. | `ArtIndexTest`, `ArtSourcesTest`, `LabelCutTest`, `CatalogTest`, `ArtImagesTest`, `ArtStoreTest`, `ScraperTest`, `ArtServiceTest` |
| INV-17 | Scraping makes one request at a time within the sources' limits, never downloads an image twice, tries again after a failure with a growing delay, resumes where it stopped, and never asks a source which game a file is. | The sources' terms are kept, and a flaky network costs nothing. | `ScrapingTest`, `ScraperTest`, `ArtSourcesTest`, `AbsencesTest`, `HttpFetchTest`, `ArtStoreTest`, `ScreenScraperTest`, `ScreenScraperFetchTest`, `VariantDownloadsTest`, `TextureTableTest`, `ArtServiceTest` |
| INV-18 | Only whole images are stored; a cut download leaves nothing; stored images (the user's own included) are found offline and never taken for orphans and deleted. | Art once there stays there. | `ArtStoreTest`, `ArtServiceTest` |
| INV-19 | Source credentials appear in a URL at request time only: in no stored file and no trace. | A member's password never leaks. | `ScreenScraperFetchTest`, `HttpFetchTest`, `ScraperTest`, `TextureTableTest` |

## Screens and input

| Id | Invariant | Why | Tests |
|---|---|---|---|
| INV-20 | No dead screen: from 0, 1, 2 or 3 consoles and after any seeded walk of pad presses (A and B at any moment) or of finger gestures, exactly one control has the focus, something visible takes the next press, the app wakes from rest on the first press, and every screen settles whole. | A screen that takes no press leaves the user stuck. | `live_screen_test.gd`, `touch_test.gd`, `screen_flow_test.gd`, `settings_test.gd`, `add_console_test.gd`, `waking_test.gd`, `resting_test.gd`, `consoles_screen_test.gd`, `console_properties_test.gd`, `disc_properties_test.gd` |
| INV-21 | After any outcome of a launch (refused, started then back, never answered) the carousel shows again as it was; input pressed meanwhile acts on nothing and starts no second launch, and a launch it gave up on starts nothing afterwards. | Coming back from a game is never a surprise. | `game_launch_test.gd`; `StartDeadlineTest`, `LateStartTest`; `android_services_test.gd`, `LauncherTest` |
| INV-22 | A finger never launches a game; only A does. | A stray tap must not start a game. | `touch_test.gd`, `finger_test.gd` |

## Wire and release

| Id | Invariant | Why | Tests |
|---|---|---|---|
| INV-23 | Everything the plugin sends to Godot is a value its JNI bridge converts: text, booleans, numbers, Dictionaries, lists of Dictionaries as `Object[]` and lists of texts as `String[]`. | Any other array, and a String inside an `Object[]`, reaches GDScript as an opaque object. | `WireTest`, `WireJsonTest` |
| INV-24 | A release build contains no debug bridge and starts none, and the bridge never writes the user's library, settings or labels. | The remote control is a development tool, never a door into the user's data. | `bridge_security_test.gd` |

