# Adding a platform

A platform is a console as Cartouche's data describes it: which emulators run its games (its players), which
files are games, what its games come on, and where their labels come from. Adding or fixing one is data only,
unless it needs a new medium ([adding-a-medium.md](adding-a-medium.md)). It shows in the app once it has a console
model ([adding-a-console.md](adding-a-console.md)).

| Step | File | Needed |
|---|---|---|
| [1. Definition and players](#1-the-definition-and-its-players) | `app/data/platforms/daijishou/` or `app/data/platforms/cartouche/` | always |
| [2. Profile](#2-the-profile) | `app/data/platforms/profiles.json` | always |
| [3. Titles and prints](#3-titles-and-prints) | `app/data/titles/<platform>.tsv`, `app/data/prints/<platform>.tsv` | to identify games; prints for cartridges |
| [4. Art](#4-art) | `app/data/art/<platform>.tsv`, `app/data/screenscraper/<platform>.tsv` | to get labels |
| [5. Curtain time](#5-curtain-time) | `app/data/launch/curtains.json` | slow emulators only |
| [6. Check](#6-check) | | always |

## 1. The definition and its players

One JSON file per platform: a `platform` (its `uniqueId`, its name) and a `playerList`.

- `app/data/platforms/daijishou/` is a copy of Daijishō's definitions (MIT). Never edit it; its `README.md` lists
  what was left out.
- `app/data/platforms/cartouche/` holds Cartouche's own files in the same format; its `README.md` says why each
  exists. Write yours there:
  - **a platform the first folder lacks:** a file name and a `uniqueId` no other file uses;
  - **a fix of a platform itself** (a renamed console, a dead emulator): a file named exactly like the one it
    replaces (`AndroidServices.platform_definitions()` merges the two folders, yours last), as `SegaGenesis.json`
    does. Keep the platform's `uniqueId` and every player's `uniqueId` and template, so libraries stay valid;
    `CatalogTest` compares the two files.
- A player right but for its name or the files it opens is corrected in the profile instead (`players`, step 2).

Each player:

| Field | Holds |
|---|---|
| `name` | `<shortname> - <Emulator>`, such as `switch - Eden` |
| `uniqueId` | `<platform>.<package>`, unique among all players |
| `acceptedFilenameRegex` | the game files it opens, written `^(.*)\.(?:ext|ext)$` so the extensions can be read. Games only: never a data file, even one the emulator opens (the Switch takes `nro|nsp|xci`, never `.nca`) |
| `amStartArguments` | the launch template: a subset of `am start`'s arguments |

```text
-n dev.eden.eden_emulator/org.yuzu.yuzu_emu.activities.EmulationActivity
-a android.nfc.action.TECH_DISCOVERED
-d {file.uri}
```

- `LaunchTemplate.kt` documents the grammar at its top: `-n`, `-a`, `-d`, `-t`, `-c`, `-f`, the typed extras
  (`-e`, `--ez`, `--ei`, `--eu`…) and the activity switches. `{file.uri}` is the game's content URI, `{file.path}`
  its path.
- A template never grants permissions: `--grant-*` switches and grant bits in `-f` are refused. The only URI shared
  is the game's own, read-only, through `{file.uri}` exactly (INV-01, INV-02).
- Keep maintained emulators only, and check each package, activity and argument on a device.
- Folders where emulators keep their own data are skipped by the scan (`app/data/scan/data_folders.json`).

## 2. The profile

One entry of `app/data/platforms/profiles.json`, keyed by the platform's `uniqueId`:

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

| Key | Says |
|---|---|
| `media` | the kind of medium: `dvd`, `cartridge` or `minidisc` |
| `medium` | the medium folder its games are drawn with: `default`, and optionally `ntsc_u` and `ntsc_j` (`MediaRule.kt`). One not modelled yet is listed in `AWAITING` of `app/test/assets/media_assets_test.gd` and drawn on a stand-in |
| `minimumGameBytes` | under this size, a file not identified is not a game. Pick a value under the smallest real game |
| `minimumBytesByExtension` | optional: a lower floor for a format small by nature or an index file, beside the platform's own, such as `{"wad": 65536, "m3u": 0}` on the Wii under its 16 MB disc floor (see *Each file format* below). Use it only for a format a listed player opens as a game; the extension is written lower-case, without its dot, and matches in any case; a negative floor, or an extension given twice in any case, refuses the profiles file |
| `screenScraperSystem` | optional: the number ScreenScraper gives this system |
| `art` | what its scans show: `disc`, or `cartridge_front` with each cartridge's shape and label crop (`ArtKind.kt`). Without it no label is looked for |
| `scansBySerial` | optional: a site naming disc scans after a game's serial, and the serials' pattern (`SerialScans.kt`) |
| `players` | optional: by player `uniqueId`, the `name` shown and the file `extensions` it opens, in place of the definition's (`PlayerFix`). Only what a device test proved: launch each format, archives included |

### Each file format

Go through every extension a player of the platform opens, and decide what the scan must do with it:

| Kind of file | Examples | Size floor | How the scan groups it | Test |
|---|---|---|---|---|
| Whole game image or ROM | `iso`, `gba`, `sfc` | `minimumGameBytes`, under the smallest real game | one game per file; copies and other formats stay separate | a small one dropped |
| Compressed image | `chd`, `cso`, `rvz` | the platform's | as an image | kept |
| Archive | `zip`, `7z` | the platform's | one game per archive | kept |
| Small by nature | Wii `wad` | its own, in `minimumBytesByExtension` | one game per file | a small one kept, an image that small dropped |
| Index file | `cue`, `ccd`, `toc`, `m3u` | `0`, in `minimumBytesByExtension` | the index is the game; tracks no player opens are set aside; `Game (Disc 1)`, `(Disc 2)` make one game and stand for the `m3u` of their name | one game, its tracks set aside, no double |
| Homebrew or not a game | `dol`, `elf`, `prx`, `json` | the platform's: never lowered | none | none |

An index file is lowered only where its tracks are not games themselves: no player opens them, or the platform's
`acceptedFilenameRegex` leaves them out (`(?<!bin)$` on the PlayStation). Where a player also opens the tracks' format
(`bin` on the Mega Drive), every track would show as a game beside it. Add a scan test on the shipped
profile for each case (`ScanTest`), and launch one game of each format on a device before saying it works.

## 3. Titles and prints

The reference list identifies a game from its file and gives it its real title and region. It comes from a DAT of
[libretro-database](https://github.com/libretro/libretro-database): Redump for discs, No-Intro for cartridges. A
cartridge platform also gets prints, each ROM's CRC32.

```sh
scripts/dat_titles.py "Sony - PlayStation 2.dat" > app/data/titles/ps2.tsv
scripts/dat_titles.py --prints "Nintendo - Game Boy Advance.dat" > app/data/prints/gba.tsv
```

## 4. Art

- **LaunchBox.** Download the Games Database's public dump (`Metadata.zip`), then extract the platform's scans:

  ```sh
  scripts/launchbox_art.py Metadata.zip "Sony Playstation 2" > app/data/art/ps2.tsv
  scripts/launchbox_art.py Metadata.zip "Nintendo Game Boy Advance" --type "Cart - Front" > app/data/art/gba.tsv
  ```

- **ScreenScraper.** The texture table `app/data/screenscraper/<platform>.tsv` is rebuilt by the project with its
  developer key for each release (`app/data/screenscraper/README.md`). Open an issue to ask for a new platform's.

## 5. Curtain time

While an emulator starts, a black curtain hides its own screens for `default_ms` of
`app/data/launch/curtains.json`. If an emulator takes longer to show its game, add its package under `emulators`
with the time measured on a device: 2.5 s at most (`CurtainTimes.LONGEST`), a longer time is refused.

## 6. Check

```sh
cd kotlin && ./gradlew :core:test --tests '*CatalogTest'      # every shipped file loads (INV-14)
GODOT=$GODOT scripts/test_godot.sh res://test/adapters        # the merged definitions, as the app reads them
```

`CatalogTest` loads every definition and profile, resolves every player's template against a game, and checks
every player's extensions can be read. Add a case to `IntentMapperTest` if a template uses a switch or an extra
kind no other player uses. Then launch one game with each player on a device
([device-testing.md](device-testing.md)).
