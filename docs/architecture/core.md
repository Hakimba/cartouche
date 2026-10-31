# The core (`kotlin/core`)

**You are here.** The core holds Cartouche's domain rules: what a platform, a game, a scan, a launch and a label
are, and how one becomes the other. It is pure Kotlin. It depends on Arrow, kotlinx.serialization and XZ for
Java, never on Android, Godot or any IO. The Android plugin ([android.md](android.md)) depends on it and is its
only caller. Everything here is tested on the JVM, mostly with property tests ([../testing.md](../testing.md)).

Each package below lives under `kotlin/core/src/main/kotlin/app/cartouche/core/`. Its tests sit in the same
package under `kotlin/core/src/test/`, and its generators and fixtures under `kotlin/core/src/testFixtures/`.

## How the core is written

- Functions are total. A failure is a typed error raised through `Raise` or returned as `Either`. Absence is
  `Option`. Bad input from outside (a definition file, a file name, a game file's bytes) becomes a value or a
  typed error, never an exception (INV-03).
- Values are immutable data classes, sealed interfaces and newtypes. `Values.kt` holds the newtypes the modules
  share: `PackageName`, `ContentUri` (built with `ContentUri.parse`, so always a `content://` URI), `FilePath`,
  `FileName`. Its `String.intOrNone()` and `longOrNone()` are the one way to parse a number.
- IO goes through ports the plugin implements: `ByteSource` for a file's bytes, a `children` function for a
  folder's listing. Tests implement them in memory (`InMemoryBytes`, `InMemoryFolders`).

## Platforms and launches

Packages `platforms` and `launch`.

| File | Responsibility |
|---|---|
| `Catalog.kt` | Parses platform definition files (a `platform` and its `playerList`), answers which players can open a file (`candidates`) and how one opens a game (`launch`). |
| `MediaRule.kt` | Picks a game's medium from its region: the profile's `medium` gives a `default`, and optionally `ntsc_u` and `ntsc_j`. |
| `ArtKind.kt` | A profile's `art`: discs, or cartridge fronts with each front's proportion and label crop (`Front`, `LabelCrop`). |
| `SerialScans.kt` | A serial source: a site naming disc scans after a game's serial, for the serials of its platform's form. |
| `CurtainTimes.kt` | How long the curtain stays over each emulator, by package name (`app/data/launch/curtains.json`). |
| `LaunchTemplate.kt` | Parses a launch template (`am start` arguments, such as `-n com.example/.Main -a android.intent.action.VIEW -d {file.uri}`) once, then `resolve` fills `{file.uri}` and `{file.path}` from a `GameFile`. The file documents the grammar. |
| `LaunchSpec.kt` | What a resolved template asks of Android: component, action, data, extras and flags. A template is third-party data, so it can grant nothing but read access to the one game file (INV-01, INV-02). |
| `GameFile.kt` | The game file a launch hands over: its URI, path and name. |
| `StartDeadline.kt` | How long after a start was asked it may still begin: past it the start is refused, as the carousel has stopped waiting for it (INV-21). |

Definition files come in two sets, in the same format: `app/data/platforms/daijishou/` (third-party) and
`app/data/platforms/cartouche/` (platforms the first set lacks). Each platform also needs a profile in
`app/data/platforms/profiles.json`: its media, the size under which an unknown file is not a game, its `art`, and
its ScreenScraper system. `CatalogTest` loads every shipped file (INV-14).

### Adding a platform

A platform takes data only, unless it needs a new medium ([../adding-a-medium.md](../adding-a-medium.md)) or a
console model ([../adding-a-console.md](../adding-a-console.md)):

1. A definition in `app/data/platforms/cartouche/`, unless the Daijishō set has one.
2. A profile in `app/data/platforms/profiles.json`.
3. A reference list `app/data/titles/<platform>.tsv`, made with `scripts/dat_titles.py` from a libretro-database DAT.
   A cartridge platform also gets its prints, `app/data/prints/<platform>.tsv` (`scripts/dat_titles.py --prints`).
4. For art, an extract `app/data/art/<platform>.tsv` made with `scripts/launchbox_art.py`, and a texture table in
   `app/data/screenscraper/` (its README says how the project builds one). A platform without `art` in its profile
   gets no art.

## Library, scan and identification

Package `library`.

| File | Responsibility |
|---|---|
| `FolderWalk.kt` | Lists a folder's files, and its sub-folders' when asked, through a `children` function. Skips hidden, too deep, unreadable and emulator-data folders (`app/data/scan/data_folders.json`) and reports them. Stops with an error past its entry limit, so a hostile provider cannot hang a scan (INV-09). |
| `Scan.kt` | `Scan.of` sorts a folder's files into games (grouping the discs of one game) and ignored files, each file in exactly one place (INV-08). Also the platform's choices (`PlatformSetup`). |
| `GameName.kt` | Reads names the Redump and No-Intro way: `Title (Region) (Languages) (Disc 2)`. |
| `TitleIndex.kt` | Identifies a file from its facts (serial, print) first, then its name, against the platform's reference list. Without a certain match it gives none (INV-10). |
| `Folding.kt` | Folds a character to the lower-case Latin letters and digits names are compared on. |
| `Game.kt` | A game, its discs, its label choice (`LabelChoice`) and its display name. |
| `Library.kt` | Every platform's games and choices. Merges a rescan without losing the user's choices (INV-12), removes a platform whole (INV-13), keeps the console order and each console's chosen model. |
| `ConsoleVariant.kt` | One entry per console model folder, with its platform. `Library.withVariant` refuses an unknown model or one of another platform. |
| `LibraryFormat.kt` | Stores the library as versioned JSON and reads every earlier format (INV-11). |
| `DemoLibrary.kt` | Makes up a library of any size, the same for the same arguments, for measuring at scale. |

## File facts

Package `files`. What a game file's bytes say about which game it is.

| File | Responsibility |
|---|---|
| `FileFacts.kt` | The answer: a disc's serial, a cartridge's print (with its `Shell`), or `Silent`. |
| `ByteSource.kt` | The port every decoder reads through: a size and positional reads, no way to write. A failing read is a `ReadFailure`. |
| `FileReading.kt` | Picks the decoder by platform and extension (`FileReading.facts`), and says which files a scan reads (`reads`). |
| `Iso9660.kt` | Finds `SYSTEM.CNF` on a PlayStation or PlayStation 2 disc and the serial it boots, and a GameCube or Wii disc's game code. |
| `ChdImage.kt` | Decodes CHD version 5 images on demand: only the sectors asked for. What the file claims is bounded, so a hostile CHD reads nothing rather than everything. |
| `Cartridges.kt` | Counts a ROM's CRC32 as No-Intro does (headers left out, a zip entry as the archive records it), and reads a Game Boy cartridge's shell. |

The disc images these tests decode live in `kotlin/core/src/test/resources/files`, made by
`scripts/file_fixtures.py`.

## Shelves and search

Packages `shelves` and `search`.

| File | Responsibility |
|---|---|
| `Shelves.kt` | One shelf per platform with games, in title order, and the `Selection` restored on them. |
| `SelectionFormat.kt` | Stores the selection in its own small file, so saving it costs the same at any library size. |
| `Words.kt` | Reads a title as the search does: words of folded letters and digits, each with its place in the title for underlining. |
| `Query.kt` | What the user typed. |
| `TitleLetter.kt` | The letter a title is filed under (`#` for a digit, a sign or another script). |
| `Finder.kt` | Per shelf: the index (by title or by region, its groups and where each key leads) and the search (the games found, the keys still lit). `Finders` holds one per shelf and survives a save that changes nothing searched. |

## Art

Packages `art` and `regions`. Which images a game may get, in which order, and the state of a scraping run. The
plugin downloads and stores them ([android.md](android.md#art)).

| File | Responsibility |
|---|---|
| `Artwork.kt` | A candidate image (`Candidate`: a scan at a URL or a ScreenScraper texture), its `Identity`, and the sources' version (`ArtVersion`). |
| `ArtIndex.kt` | Reads an art extract and finds a game by title, alternate names included. Titles found alike are told apart one rule at a time, and a title still ambiguous gives no image. |
| `TextureTable.kt` | Reads a platform's ScreenScraper texture table: per release, its game and the textures it has. |
| `Regions.kt` | Orders images by how close their region is to the game's. `Regions.isOwn` says whether an image is of the game's own region. |
| `PreferredRegion.kt` | The user's preferred region, used to order the images no region of the game decides. |
| `ArtSources.kt` | Gathers a platform's sources, makes each game's request in order (`ArtSources.order`), plans a library's requests (`requests`), and lists a game's images for the chooser (`variantsOf`). |
| `LabelCut.kt` | Cuts a game's label out of a scan: a disc's face, or the label of a cartridge front of known shape. A scan of no known shape is passed over. |
| `LabelFraming.kt` | How a picture of the user's own is framed on a label: a zoom and a centre. |
| `Scraping.kt` | A run's state (waiting, under way, done, stalled, retry delay), changed only by its operations. |
| `Absences.kt` | What no source has, per sources' version, so it is not asked again. |
| `ProvisionalArt.kt` | Labels found while a better source was skipped, to look for again later. |
| `ScreenScraper.kt` | ScreenScraper's availability as its answers leave it (`ScreenScraperState`), what of it outlives a restart (`KeptClosures`), and what the member account allows (`Account`, `Limits`). |

## Settings and storage

Packages `settings` and `storage`.

| File | Responsibility |
|---|---|
| `Settings.kt` | The app's choices apart from the library: button style, edge smoothing, preferred region, games floating, sound level, language, and whether the first launch is still to do. |
| `SettingsFormat.kt` | Their stored format. |
| `DocumentPaths.kt` | Maps a document id (`1A2B-3C4D:ROMs/ps2`) to a path and to a place the user reads. |

## Neighbours

- Up: [android.md](android.md), the only caller of the core.
- The words: [../GLOSSARY.md](../GLOSSARY.md).
- The tests and their helpers: [../testing.md](../testing.md#kotlin).
- The guarantees: [../INVARIANTS.md](../INVARIANTS.md).
- Back to the entry: [../README.md](../README.md).
