# Glossary

**You are here.** The domain words, in alphabetical order. The code, the tests and the docs use them with these
meanings, so a word here is also the word to search for. Each entry names the type or file that holds it and the
page that explains it. Start from [README.md](README.md) if you have not.

- **Absent**: a game no art source has, remembered per sources' version so it is not asked again (`Absences`).
  See [architecture/core.md](architecture/core.md#art).
- **Approach**: the way a medium comes down to its seat in a console, a unit vector in the seat's frame
  (`ConsoleModel.approach`). See [adding-a-console.md](adding-a-console.md).
- **Art**: a game's label image. Always a scan of its real disc or cartridge, never its box. A disc's art is its
  printed face. A cartridge's art is the label cut from a scan of its front (`LabelCut`).
- **Art extract**: `app/data/art/<platform>.tsv`, one line per game of the LaunchBox Games Database with its names
  and scans by region (`ArtIndex`).
- **Blank**: how a game without art is drawn, its console's plain label. Once no source can have its art, the
  blank shows its title.
- **Button style**: how button marks are drawn: Nintendo, Xbox or PlayStation (`Controls`). A setting.
- **Candidate**: one image a game may get, a scan at a URL or a ScreenScraper texture, named by its `Identity`.
- **Catalog**: every platform and player the definition files describe (`Catalog`).
- **Console**: a platform's 3D model on the consoles screen, or its medium when it has no model yet.
- **Console folder**: everything of one console model, `app/carousel/consoles/<folder>/`: its manifest, scene,
  model, shape and launch steps. See [adding-a-console.md](adding-a-console.md).
- **Console order**: the order the user put the consoles in on the ring (`Library.consoleOrder`). Consoles never
  placed follow in catalog order.
- **Consoles screen**: the first screen, one console per platform with games (`ConsoleRow`).
- **Cue**: one gesture as it sounds (`SoundEffects.Cue`), played with `Sounds.play`. See [sounds.md](sounds.md).
- **Curtain**: a black window over every app while an emulator starts, so its own screens never show (`Curtain.kt`).
- **Cyclorama**: the backdrop of every screen, a paper wall curving into a floor (`Cyclorama`).
- **Demo library**: a made-up library of any size, in debug builds (`DemoLibrary`, `--demo-games=N`), or the desktop
  demo of `app/dev/demo/desktop.json`.
- **Desktop stand-in**: `DesktopPlugin`, which answers in the plugin's place on a computer.
- **Display name**: a name the user typed for a game, shown instead of its title. Identification, art and shelf
  order keep the title (`DisplayName`).
- **Edge smoothing**: the 3D's multisampling: 4×, 2× or none (`EdgeSmoothing`). A setting.
- **Facts**: what a game file's bytes say about which game it is: a serial, a print, or nothing (`FileFacts`). See
  [architecture/core.md](architecture/core.md#file-facts).
- **Fingerprint**: a hash of what launch steps are tuned on (a console's dimensions and moving parts), carried in
  `launch.json` as `model_hash` (`ConsoleModel.fingerprint`).
- **Frost**: the translucent Studio material, for pieces over the backdrop: the top bar's pills and the hint row.
- **Game**: one entry of the library, one or more discs (files) (`Game`).
- **Games screen**: one platform's shelf of games, the selected one in the middle (`ShelfRow`).
- **Gel**: a console's colour, in which the backdrop's glows, the focus ring and tinted pieces are drawn
  (`StudioTokens.GEL`).
- **Hint row**: the one row of button hints of every screen (`HintRow`).
- **Identified**: a game the platform's reference list knows, from its facts first, else from its name
  (`TitleIndex`).
- **Ignored file**: a file a scan does not take for a game. A file a player opens but that is too small or a BIOS
  is kept as a not-game. Hidden and unsupported files are only counted (`IgnoredFile`, `IgnoredCount`).
- **Index**: the ribbon with nothing typed: the shelf by letter or by region (`Finder`).
- **Insertion**: how a game goes into a console that has no launch animation, one motion per media kind
  (`Insertion`).
- **Kind**: a medium's family (`dvd`, `minidisc`, `cartridge`), which gives its insertion and the medium shown for
  one without a folder (`MediumManifest`).
- **Label choice**: which image a game's label shows: automatic, an image the user chose among the game's images,
  or a picture of the user's own, framed on the label (`LabelChoice`, `LabelFraming`).
- **Launch animation**: a console's moves from the consoles screen to a launched game, written as steps in its
  folder's `launch.json` (`LaunchAnimation`). See [adding-a-console.md](adding-a-console.md#launch-steps).
- **Launch check**: asking whether a game can start (its emulator installed, its file still there) without starting
  or stopping anything (`Launcher.checkGame`).
- **Library**: every platform's games, choices and last scan results, stored on the device (`Library`).
- **Lit key**: a key of the ribbon that would still find a game if typed.
- **Logo**: a console's mark in a fixed slot of a screen (`LogoView`), or one printed on its model (an SVG of its
  folder).
- **Manifest**: a console's `console.tres` (`ConsoleManifest`) or a medium's `medium.tres` (`MediumManifest`).
- **Medium**: the physical object a game comes on, one folder and model each (`ps2_dvd`, `nes_cart`), chosen by its
  platform's profile and its region (`MediaRule`). See [adding-a-medium.md](adding-a-medium.md).
- **Model variant**: one of several models of a platform (the slim and the original PS2). The user's choice is kept
  per platform (`ConsoleVariant`, `Library.withVariant`).
- **Moving part**: a part of a console that moves (a lid, a tray, a light), a float property of its model with a
  role and its values at rest and fully moved (`MovingPart`).
- **Pace**: how fast what moves by itself goes, from 1 awake down to 0 at rest. Nodes that move by themselves join
  the group `paced` (`Resting`).
- **Place**: one of the games row's recycled slots (`ShelfRow`).
- **Placeholder**: the launch animation of a console without steps, made from its moving parts' roles
  (`LaunchAnimation`).
- **Placing**: putting a console just added among the others on the ring (`Placing`).
- **Platform**: a console as its definition file describes it (`ps2`), with its players.
- **Player**: one way to run a platform's games, an emulator or a RetroArch core, with its launch template.
- **Pose**: how the selected game or console stands to show itself. The right stick turns it further.
- **Preferred region**: the region whose images come first when the game's own region decides nothing
  (`PreferredRegion`). A setting.
- **Presented**: how a console turns to face the camera (`ConsoleModel.presented`).
- **Print**: a cartridge ROM's CRC32 as No-Intro counts it, listed in `app/data/prints/<platform>.tsv`.
- **Profile**: what Cartouche adds to a platform's definition: its media, the smallest game file, its art kind,
  its ScreenScraper system (`app/data/platforms/profiles.json`).
- **Progress ring**: the ring filling on a blank label while its image downloads (`ProgressRing`).
- **Properties**: the screen X opens on a game (its label and name, `DiscProperties`) or a console (its model and
  place, `ConsoleProperties`).
- **Proud**: how far a button or switch of a console stands out of it at rest (`ConsoleModel.PROUD_MM` at most).
- **Provisional**: a label found while ScreenScraper was skipped, looked for again later (`ProvisionalArt`).
- **Reference list**: a platform's Redump or No-Intro titles and serials, `app/data/titles/<platform>.tsv`.
- **Rest**: the app left alone: it draws only what changes, then nothing until the next press (`Resting`). The
  first press always wakes it and acts.
- **Ribbon**: the row of keys down opens under the games, for the index and the search (`GameSearch`).
- **Ring**: the consoles in order on an ellipse, to reorder them or place a new one (`ConsoleOrder`, `RingFit`).
- **Run**: one pass of scraping over the games still wanting art (`Scraping`, `Scraper.kt`).
- **Satin**: the opaque Studio material: cards, buttons, fields, the focused card.
- **Scan**: listing a platform's folder (the walk), then sorting its files into games and ignored files (`Scan`).
- **ScreenScraper state**: open, slowed, closed for the run, closed until the next day, or off for a refused key,
  as ScreenScraper's answers leave it (`ScreenScraperState`).
- **Search**: the ribbon once keys are typed: the games whose title has a word starting with each word typed
  (`Finder`).
- **Seat**: where a medium stands once in its console, following the part that carries it (`ConsoleModel.seat`).
- **Selection**: the platform shown last and each platform's selected game, restored at start (`Selection`).
- **Serial**: the id a disc boots (`SLES_524.95`), read from its `SYSTEM.CNF`, or a GameCube or Wii game code.
- **Serial source**: a site naming disc scans after a game's serial (`SerialScans`).
- **Settings**: the app's choices apart from the library: button style, edge smoothing, preferred region, games
  floating, sound level (`Settings`).
- **Setup**: what the user chose for a platform: folder, player, disc grouping, sub-folders (`PlatformSetup`).
- **Shape**: the dimensions in millimetres a model is built from, and the rules they keep (`ModelShape`).
- **Shelf**: one platform's games in title order (`Shelves`).
- **Skipped folder**: a sub-folder the walk does not look into: hidden, emulator data, too deep or unreadable.
- **Spindle**: the drive's motor and hub a disc clips onto during an insertion (`Spindle`).
- **Stall**: a run stopped until the network is back or a delay passes (offline, a server refusing, no room).
- **Studio**: the app's look: every screen a small lit photo studio (`StudioTokens`). See
  [architecture/studio.md](architecture/studio.md).
- **Tap, long press, drag, swipe**: what a finger does, read by `Finger`. A swipe moves exactly one game or console.
- **Template**: a player's launch, written as `am start` arguments (`LaunchTemplate`).
- **Texture**: an image ScreenScraper has for a release, such as its printed label.
- **Texture table**: `app/data/screenscraper/<platform>.tsv`: per release, its ScreenScraper game and textures
  (`TextureTable`).
- **Walk**: listing a folder and its sub-folders for a scan (`FolderWalk`).
- **Wire format**: what crosses the JNI bridge between the plugin and GDScript (`Wire.kt`, `AndroidWire`).

## Neighbours

[README.md](README.md) · [architecture/core.md](architecture/core.md) ·
[architecture/android.md](architecture/android.md) · [architecture/godot.md](architecture/godot.md) ·
[INVARIANTS.md](INVARIANTS.md)
