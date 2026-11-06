# Adding a platform

**You are here.** A platform is a console as Cartouche's data describes it: which emulators can run its games
(its players), which files are games, what its games come on, and where their labels come from. This page adds a
platform, or fixes one whose emulators, extensions or art are wrong. It is data only: no Kotlin or GDScript changes,
unless the platform needs a new medium ([adding-a-medium.md](adding-a-medium.md)). The code that reads this data
is described in [architecture/core.md](architecture/core.md#platforms-and-launches).

A platform shows on the consoles screen, and in **Add a console**, only once it has a console model
([adding-a-console.md](adding-a-console.md)). You can still add its data first and test it on its own.

## What a platform needs

| Piece | File | Required |
|---|---|---|
| Definition and players | `app/data/platforms/daijishou/` or `app/data/platforms/cartouche/` | yes |
| Profile | `app/data/platforms/profiles.json` | yes |
| Reference list of titles | `app/data/titles/<platform>.tsv` | to identify games |
| Prints (cartridge checksums) | `app/data/prints/<platform>.tsv` | cartridge platforms |
| Art extract and texture table | `app/data/art/<platform>.tsv`, `app/data/screenscraper/<platform>.tsv` | to get labels |
| Curtain time | `app/data/launch/curtains.json` | slow emulators only |

## 1. The definition and its players

Definitions use Daijishō's file format: one JSON file per platform, with a `platform` (its `uniqueId`, its name)
and a `playerList`. A player is one way to run the platform's games, an emulator or a RetroArch core.

There are two folders:

- `app/data/platforms/daijishou/` is a copy of Daijishō's definitions (MIT). Never edit it. Its `README.md` lists
  what was left out.
- `app/data/platforms/cartouche/` holds Cartouche's own files, in the same format. Its `README.md` says why each
  one exists.

Write your file in `app/data/platforms/cartouche/`, in two cases:

- **A platform Daijishō lacks.** Pick a file name and a `uniqueId` that no Daijishō file uses.
- **A Daijishō platform that needs a fix** (a renamed console, a dead emulator, a wrong extension). Name your file
  exactly like the Daijishō one: it **replaces** it (`AndroidServices.platform_definitions()` merges the two
  folders, yours last). Keep the platform's `uniqueId` and every player's `uniqueId` and template, so the users'
  libraries and choices stay valid. `SegaGenesis.json` does this to name the console Mega Drive. The test of
  INV-14 in `CatalogTest` compares a replacement with the file it replaces.

Each player needs:

| Field | What it holds |
|---|---|
| `name` | `<shortname> - <Emulator>`, such as `switch - Eden` |
| `uniqueId` | `<platform>.<package>`, unique among all players |
| `acceptedFilenameRegex` | the game files it opens, written `^(.*)\.(?:ext|ext)$` so the extensions can be read |
| `amStartArguments` | the launch template, below |

List only files that are games. A data or content file is not a game, even when the emulator opens it (the
Switch takes `nro|nsp|xci`, never its `.nca` or `.nso` files). A file no player accepts is shown as unsupported.
Folders where emulators keep their own data are skipped by the scan (`app/data/scan/data_folders.json`).

Keep maintained emulators only. To find an emulator's package, activity and how it takes a game, the systems files
of ES-DE for Android are a good public source: they list the same facts for most emulators. Check them on a device
before you trust them.

## 2. The launch template

`amStartArguments` is a subset of the `am start` command's arguments:

```text
-n dev.eden.eden_emulator/org.yuzu.yuzu_emu.activities.EmulationActivity
-a android.nfc.action.TECH_DISCOVERED
-d {file.uri}
```

`LaunchTemplate.kt` documents the whole grammar at its top: `-n` component, `-a` action, `-d` data, `-t` type,
`-c` category, `-f` flags, the typed extras (`-e`, `--ez`, `--ei`, `--eu` and others) and the activity switches.
`{file.uri}` is the game's content URI and `{file.path}` its file path. `IntentMapper.kt` in the plugin turns the
result into an Android `Intent`.

A template is third-party data, so it never grants permissions. `--grant-*` switches and grant bits in `-f` are
refused. The only URI shared with the emulator is the game's own, read-only, through `{file.uri}` exactly
(INV-01, INV-02).

## 3. The profile

Add an entry to `app/data/platforms/profiles.json`, keyed by the platform's `uniqueId`:

```json
"gba": {
  "media": "cartridge",
  "medium": {"default": "gba_cart"},
  "minimumGameBytes": 8192,
  "screenScraperSystem": 12,
  "art": {"kind": "cartridge_front", "fronts": {"gba_cart": {"proportion": 1.74,
          "label": {"left": 0.147, "top": 0.218, "width": 0.706, "height": 0.628}}}}
}
```

| Key | What it says |
|---|---|
| `media` | the kind of medium: `dvd`, `cartridge` or `minidisc` |
| `medium` | the medium folder its games are drawn with: `default`, and optionally `ntsc_u` and `ntsc_j` for regions whose medium differs (`MediaRule.kt`) |
| `minimumGameBytes` | under this size, a file that is not identified is not a game. Pick a value under the smallest real game. |
| `screenScraperSystem` | the number ScreenScraper gives this system, in its systems list. Optional. |
| `art` | what its scans show: `disc` for a disc's face, or `cartridge_front` with the shape and label crop of each cartridge (`ArtKind.kt`). Without `art`, no label is looked for. |
| `scansBySerial` | optional: a site naming disc scans after a game's serial, and the serials' pattern (`SerialScans.kt`) |

A medium not modelled yet is listed in `AWAITING` of `app/test/carousel/media/media_folders_test.gd`, and the
games are drawn on a stand-in until it is.

## 4. Titles and prints

The reference list lets Cartouche identify a game from its file and give it its real title and region. It comes
from a DAT of [libretro-database](https://github.com/libretro/libretro-database): Redump for discs, No-Intro for
cartridges.

```sh
scripts/dat_titles.py "Sony - PlayStation 2.dat" > app/data/titles/ps2.tsv
scripts/dat_titles.py --prints "Nintendo - Game Boy Advance.dat" > app/data/prints/gba.tsv
```

A cartridge platform also gets prints: each ROM's CRC32, so a cartridge is identified by its bytes, not its name.

## 5. Art

Labels come from two sources, explained in [architecture/core.md](architecture/core.md#art):

- The LaunchBox Games Database: download its public dump (`Metadata.zip`), then extract the platform's scans:

  ```sh
  scripts/launchbox_art.py Metadata.zip "Sony Playstation 2" > app/data/art/ps2.tsv
  scripts/launchbox_art.py Metadata.zip "Nintendo Game Boy Advance" --type "Cart - Front" > app/data/art/gba.tsv
  ```

- ScreenScraper's texture table, `app/data/screenscraper/<platform>.tsv`. The project rebuilds these tables with
  its developer key for each release (`app/data/screenscraper/README.md` says what they hold). Open an issue to ask
  for a new platform's table.

## 6. Curtain time

While an emulator starts, a black curtain hides its own screens. It stays `default_ms` of
`app/data/launch/curtains.json`. If an emulator takes longer to show its game, add its package under `emulators`
with the time it needs, measured on a device (`CurtainTimes.kt`).

## Tests and checks

```sh
cd kotlin && ./gradlew :core:test --tests '*CatalogTest'                   # every shipped file loads (INV-14)
GODOT=$GODOT scripts/test_godot.sh res://test/adapters                     # the merged definitions, as the app reads them
```

`CatalogTest` loads every definition and profile, resolves every player's template against a game, and checks
that every player's extensions can be read. A template that does not parse fails the build. Add a case to
`IntentMapperTest` if your template uses a switch or an extra kind no other player uses.

Then try it on a device ([device-testing.md](device-testing.md)): launch one game with each player.

## Neighbours

- [architecture/core.md](architecture/core.md#platforms-and-launches): the code that reads this data.
- [adding-a-console.md](adding-a-console.md) and [adding-a-medium.md](adding-a-medium.md): the 3D side.
- [INVARIANTS.md](INVARIANTS.md): INV-01, INV-02, INV-14, INV-16.
- Back to the entry: [README.md](README.md).
