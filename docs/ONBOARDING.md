# Onboarding

How Cartouche is built and where to look before changing something. This document follows the
code: it only describes what exists.

## Architecture

```
┌──────────────────────────── app/ (Godot 4.7, GDScript) ─────────────────────────────┐
│  carousel/                the main screen: one shelf of games per platform          │
│  dev/device_check/        developer tool: one tab per device capability             │
│  adapters/android/        AndroidServices, the only code talking to the plugin      │
│  addons/cartouche_android bundles the Kotlin build into Android exports             │
│  data/platforms/          platform and emulator definitions (Daijishō, MIT)         │
│                           and Cartouche's own definitions and platform profiles     │
│  data/titles/             game titles and serials (libretro-database, CC BY-SA 4.0) │
│  data/carousel/           each kind's medium, label colours, the selected game's pose│
│  dev/demo/                the catalog and a demo library, to run without Android    │
│  test/                    GDScript tests (GdUnit4, fetched by dev/test_godot.sh)    │
└─────────────────────────────────────┬───────────────────────────────────────────────┘
                                      │ JNI: Dictionaries and one `answered` signal
┌──────────────────────────── kotlin/ (Gradle) ───────────────────────────────────────┐
│  android/   Godot Android plugin: folders, library file, intents, installed apps   │
│      └── depends on ──▶  core/   pure Kotlin: catalog, launches, library, shelves   │
└─────────────────────────────────────────────────────────────────────────────────────┘
```

- **`kotlin/core`** holds the domain rules as pure functions over immutable values: no Android, no
  IO, no `null`. Everything there is tested on the JVM, including property-based tests.
- **`kotlin/android`** adapts Android APIs and exposes the core to Godot. It holds the only state:
  the loaded catalog, reference lists and art extracts, the library and the selection, the pending
  folder pick, the scraping run, and which apps are installed (until the next resume).
- **GDScript** is the UI shell: scenes, input and display, with no domain rules. The carousel's
  screen mechanics (which game stands where, how a held direction repeats) are pure functions in
  `CarouselLayout`, tested headless.

## Glossary

The same words are used in the code, the tests and this document.

- **Platform**: a console, as a Daijishō definition describes it (`ps2`). Its **profile** adds the
  **media** its games are shown as (DVD, cartridge, mini-disc) and the size under which an unknown
  file is not a game.
- **Player**: one way to run a platform's games, an emulator or a RetroArch core, with its launch
  **template** (`am start` arguments). The **catalog** holds every platform and player.
- **Game**: one entry of the library, made of one or more **discs** (files). It is **identified**
  when the platform's **reference list** (Redump's or No-Intro's titles and serials) knows it.
- **Scan**: listing a platform's folder (the **walk**), then sorting its files into games and
  **ignored files**. A file a player opens that is not taken for a game (a BIOS, too small) is kept
  as a **not-game**; hidden and unsupported files are only counted. A sub-folder the walk does not
  look into is a **skipped folder**: hidden, **emulator data** (`memcards`, `textures`…), too deep
  or unreadable.
- **Setup**: what the user chose for a platform (folder, player, disc grouping, sub-folders).
- **Library**: every platform's games, setup and last scan results, stored on the device.
- **Shelf**: one platform's games in the carousel, in title order. The **selection** remembers the
  platform shown last and each platform's selected game, and places the user back when the app
  starts.
- **Ribbon**: the row of keys (A to Z, 0 to 9, a space) that down opens under the games. With
  nothing typed it is the shelf's **index**, by letter or by region, the carousel jumping to each
  **group**; a key typed starts a **search**: the carousel keeps the games **found**, those whose
  title has, for each word typed, another word starting with it, in any order. A key is **lit**
  when typing it still finds a game. What is found can be **kept** while browsing it (the
  **filter** shown at the top). L1 and R1 **leap** to the next group, or once keys are typed to
  the next lit key.
- **Place**: one of the carousel's recycled slots, showing a game's **model** (the 3D media of
  its platform) with a **label** on it: an image of the real one, or the game's title drawn on the
  platform's label colour.
- **Shape**: the dimensions, in millimetres, a model is built from (`DiscShape`, `NesCartShape`);
  each **part** of the model (label, mirror, shell) is a mesh built from them.
- **Medium**: the physical object a game comes in, each its own folder and model (`ps2_dvd`,
  `snes_pal_cart`), the one a game's platform gives it (`Game.medium`); its **kind** (`media`:
  `dvd`, `minidisc`, `cartridge`) gives its insertion and the medium shown for one without a
  folder.
- **Pose**: how the selected game or console is shown, leaning back, turned and slowly swaying, so
  that the light moves over it. The right stick turns it further, as far as the user likes.
- **Rest**: the app left alone (`Resting`; its first press always wakes it and acts, INV-E8-01):
  from 2 s in Godot's low processor mode, its loop running about 30 times a second (the engine's
  frame rate is never capped: lifting a cap leaves frames slow for about a second), then
  **still** from 6.2 s, drawn only when something on screen changes, until the next press. What moves
  by itself (the backdrop's dots, the pose's float and sway, the welcome's worm) joins the group
  `paced` and goes at its **pace**, from 1 awake down to 0 still.
- **Consoles screen**: the first screen, one **console** per platform with games (its 3D model,
  or its media until it has one), in a row laid out like the games'. **Going in** (A) and **going
  out** (B) play the console's **launch animation** between it and the platform's **games screen**
  (its shelf).
- **Console folder**: everything of one console (`carousel/consoles/<id>/`): its **manifest**
  (`console.tres`, a `ConsoleManifest`: the platform it plays, which **version** it is and whether
  the **default** one, its names, its scene, its launch steps, its triangle budget), its shape, its
  scene and its model. The app finds the consoles by their folders.
- **Moving part**: a part of a console that moves (a lid, a tray, a light), a float property of
  its model named after what moves and its unit (`lid_degrees`, `open_mm`, `power_mm`, a light's
  `light_energy`, its emission energy), with a **role** (opening, flap, press, power,
  power press, light, spin, pose) and its values at rest and fully moved (`MovingPart`): a
  **flap** is pushed open by the medium; a **press** is a button pressed and let go before the
  openings open (eject, open); a **power press** a power button pressed and let go as the console
  comes on, where a latching one is a power part. A button pressed goes in as far as it really
  does, or less, so that it still stands out of the face around it (`ConsoleModel.press_travel`).
- **Proud**: how far a moving part that is not an opening (a button, a knob, a switch) stands out
  of the console at rest, `ConsoleModel.PROUD_MM` at most.
- **Logo**: a mark printed or moulded on a console, an image of the folder drawn on a face of its
  own (see "Adding a console").
- **Seat**: where a medium stands once in its console, in the model's space, following the part
  that **carries** it (the part whose opening moves the seat); its frame is the medium's own, as
  its model has it (a disc: its centre, axis Z towards the label; a cartridge: the middle of its
  outline, half way through its body, +Z out of the label, +Y towards its top edge). The
  **approach** is the way the medium comes down to it, a unit vector in the seat's frame
  (`ConsoleModel.seat`, `approach`).
- **Presented**: how a console is turned to face the camera on the consoles screen and through the
  placeholder; by default about X only, its way in towards the camera (`ConsoleModel.presented`).
- **Placeholder**: the launch animation of a console without steps of its own, made from its
  moving parts' roles, the medium coming down from its own length (and 7 cm more) along the way in
  (`LaunchAnimation.placeholder`, `lift`).
- **Fingerprint**: a hash of what launch steps are tuned on (a console's dimensions and its moving
  parts' values), carried by its `launch.json` as `model_hash` (`ConsoleModel.fingerprint`).
- **Launch animation**: a console's moves from the consoles screen to a launched game, written as
  **steps**: each a whole state of the scene (console, its parts, disc, rows, blur, controls, black),
  reached from the previous one in `dur` seconds along its `ease`, then held `hold` seconds. Its
  **moments** name where it comes to the games screen, the launch, the disc seated, the black.
  The steps file is the contract between the tuning tool and the app: `model_hash` (the console's
  fingerprint they were tuned on), `choice` (the step the game is chosen at) and `steps`, each a
  group per part (`console`, `consoles`, `parts`, `disc`, `row`, `look`, `ui`, `fx`), distances in
  centimetres, angles in degrees, the blur in pixels of the screen, `parts` the console's moving
  parts by property in their own units; a missing value takes its default, a moving part its rest
  (`LaunchAnimation`). The disc's `lift` is measured along the approach, its `dx` and `dy` across it.
  `fx.black` grows the black as a disc from the seat, `fx.fade` darkens the whole screen; either at 1
  is the black.
- **Launch check**: asking whether a game can start (its player's emulator is installed, its file
  still there) without starting or stopping anything, before its insertion plays.
- **Insertion**: how a game goes into its console once A is pressed, for a platform whose console
  has no launch animation, one per media: a disc turns
  to face the player, comes forward as if taken in hand, goes back onto the drive's **spindle**
  (the motor, turntable, hub and balls a disc clips onto), which spins it up; then the screen goes
  black from its centre.
- **Curtain**: a black window over every app, raised as the emulator starts and lowered once the
  emulator shows its game (a time per emulator) or the user is back, so that the emulator's own
  screens never show between the insertion's black and the game.
- **Art**: a game's label image, always a **scan** of its real medium (never its box's cover): a
  disc's printed face, whole, or a cartridge's front, of which only the **label** is kept, cut where
  the **label crop** of the **front** of the scan's shape says (where the medium's model has its label;
  `art` in its platform's profile, the
  **kind** of its scans: `ArtKind`; a scan of no front's shape, as a photo taken at an angle, is
  passed over); a
  game without one is drawn as a **blank** of its console (for the PS2, a silver disc with a dark
  band) with its title. The **art extract** (`app/data/art/<platform>.tsv`) lists, per game of the
  LaunchBox Games Database, its scans by region; a platform's **serial source** (`scansBySerial` in
  its profile, psxdatacenter for the PS2, with the form of the platform's serials) names scans
  after a game's serial.
- **Label choice**: which image a game's label shows: **automatic** (the closest region's, as
  scraping finds it), a **region** the user chose among the game's **images by region** (the first
  scan of each region its extract has, closest first), or a **picture of their own**, picked with
  the system's picker and **framed** on the label (`LabelFraming`: a zoom and a centre, standing for a
  rectangle of the picture of the label's proportions), which no scraping replaces.
- **Display name**: a name the user gave a game or a console (`DisplayName`, typed on the
  properties' gamepad keyboard), shown in place of its own; identification and art keep using a
  game's title, and its shelf its title's order.
- **Tap, long press, drag, swipe**: what a finger does: `Finger` reads a tap (a short press that
  barely moves), a long press (one held still) and a drag (one that moved past the slop); the
  carousel reads a drag on the consoles screen, or beside the game in the middle, as a swipe,
  which moves exactly one, however long or fast.
- **Console order**: the order the user put the consoles in on the **ring** (down on the consoles
  screen, or "Change place" in a console's properties), which the consoles screen follows
  (`Library.consoleOrder`); consoles never put anywhere follow in catalog order.
- **Properties**: a game's screen opened with X from the games screen: its disc **staged** (out of
  the row, in the middle, still and facing the camera) under the **operating light** (the room
  darkened round it, a pool of light on it), its **zones** (its label, its name) picked
  with up and down; A on the label opens its images by region, the disc showing each at once, and
  the card of the user's own picture, which opens the system's picker and then the **framing**; A on
  the name opens a keyboard played with the stick (`GamepadKeyboard`).
- **Scraping**: looking for the art of the games that have none, in the background. A **run** hands
  out **requests** (a game and where to look, best first); a **stall** (offline, a server refusing,
  no room to store) stops it until the network is back or a delay passes. Games no source has are
  remembered as **absent** until the extract changes.
- **Screens**: what shows in front of the carousel, over its background alone: the **welcome** at each
  start, a title screen that waits for a button while the app loads; on the **first launch** (no
  controller set up and no platform), the **button style** (how buttons are drawn: Nintendo, Xbox or
  PlayStation) and the **curtain permission**; while no console has games, **no console** and the
  **form** adding one, whose **count** (the compatible games of the chosen folder) is a scan that
  saves nothing; then the **discovery** of the console added. Y opens the **settings** over the
  consoles screen or the games screen: the **platforms** set up, each opened in the same form to
  **edit** it (saved and scanned again) or **remove** it after a confirmation, the button style, and
  **Graphics**: the edges' smoothing (4×, 2× or none), each card showing a close-up of an edge drawn
  with it.
  Above the console, a **"+" ball**: holding up turns it into "Add a platform" (its strokes
  spreading into the button's outline), and A adds one more console, the consoles screen coming back
  on it.
- **Settings**: the app's own choices, apart from the library: the button style and the edges'
  smoothing (`EdgeSmoothing`: the 3D's multisampling, 4× unless the user chooses less).
- **Removing a platform**: its choices, games, selection, art and folder access go (INV-E6-03);
  the game files stay.
- **Demo library**: a made-up library of any size, in debug builds, for measuring at scale.
- **Wire format**: what crosses the JNI bridge between the plugin and GDScript.

## Components

### Core (`kotlin/core`)
- **`platforms/Catalog.kt`** parses Daijishō definition files (a `platform` and its `playerList`):
  Daijishō's own (`data/platforms/daijishou/`) and, in the same format, Cartouche's for platforms
  Daijishō has none of (`data/platforms/cartouche/`, the Xbox and the Xbox 360).
  A *player* is one way to run a platform's games: an emulator or a RetroArch core, plus its launch
  template. It also answers which players can open a file (`candidates`) and how a player opens a
  game (`launch`). Each platform also needs a profile (`data/platforms/profiles.json`): its media
  (DVD, cartridge, mini-disc), the exact medium of its games and the size under which an unknown
  file is not taken for a game. The medium follows the game's region (`platforms/MediaRule.kt`):
  `medium` declares a `default`, for PAL games and those of no known region, and optionally
  `ntsc_u` and `ntsc_j` (`{"default": "nes_cart", "ntsc_j": "famicom_cart"}`); a game sold in
  several takes PAL first, then NTSC-U, then NTSC-J. Each game is sent to Godot with its medium. For
  now each console shows its own cartridge alone (`{"default": "nes_cart"}`): the regional ones
  (Famicom, Super Famicom, North American Super Nintendo) come with the consoles' variants.
  Adding a platform takes data only: a definition, a profile and, to identify its games, a
  reference list `data/titles/<platform id>.tsv` (made with `dev/dat_titles.py`); for its art, an
  extract `data/art/<platform id>.tsv` and the profile's `art`: `{"kind": "disc"}`, or
  `{"kind": "cartridge_front", "fronts": {medium: {"proportion", "label": {"left", "top",
  "width", "height"}}}}`: for each shape of cartridge its scans show (every medium of the platform,
  and the regional ones its scans may be of), the front's width over its height as the scans show
  it, and where the label sits on it, in fractions of it; the label's proportions are the model's
  label face's (a test holds them within 2 %). A platform without `art` has no art looked for.
- **`launch/LaunchTemplate.kt`**: Daijishō writes launches as `am start` arguments, such as
  `-n com.armsx2/.Main -a android.intent.action.VIEW -d {file.uri}`. The file documents the
  grammar. `parse` checks it once, then `resolve` fills `{file.uri}` and `{file.path}` in from a
  `GameFile`. Templates are third-party data: they cannot grant URI permissions, and the only
  content URI they can hand over is the game's.
- **`library/`** is the game library:
  - `GameName` reads names the Redump and No-Intro way (`Title (Region) (Languages) (Disc 2)`);
  - `TitleIndex` identifies a file by its name alone: as an exact reference disc, or as one disc of
    a release known by the serials all its versions share, or not at all (never a wrong serial). It
    files each reference disc by its title alone (`GameName.filing`) and reads a disc's whole name
    only when a file could be that disc;
  - `FolderWalk` lists a folder's files, and its sub-folders' when asked, through any `children`
    function: the Android plugin passes the documents provider, tests an in-memory tree. Hidden,
    too deep and unreadable sub-folders, and those named like emulator data
    (`data/scan/data_folders.json`), are skipped and reported; a walk stops with an error past
    10,000 entries, naming the folder that listed the most;
  - `Scan.of` sorts a folder's files into games (grouping multi-disc games) and ignored files;
  - `Library` holds each platform's games and choices (`PlatformSetup`), and merges a rescan
    without losing them. Hidden and unsupported files are only counted, so its size follows the
    games; `LibraryFormat` stores it as versioned JSON and reads earlier formats, which the plugin
    then saves again, upgraded.
- **`shelves/`** turns the library into what the carousel shows: `Shelves.of` makes one shelf per
  platform with games, in title order (a collator's order, then ids, so the same library always
  gives the same shelves), and restores the `Selection` on them; `SelectionFormat` stores the
  selection in its own small file, so remembering it costs the same whatever the size of the
  library.
- **`search/`** finds the games of a shelf: `Words` reads a title the way the search does (its
  words in lowercase Latin letters and digits, accents and "the" left out, each with where it is in
  the title, in characters, for underlining), `Query` what is typed, and `Finder`, made once per
  shelf, answers the index (by title or by region: the order, the groups, where each key sends the
  carousel) and the search (the games found in shelf order, and each lit key with the first game it
  finds), each title filed under its first letter (`TitleLetter`; under **#** for a digit, a sign
  or another script); it keeps what it found for the words typed lately, so that typing on (or erasing) only
  narrows it. `Finders` makes them for a whole library at once, and stays the same across a save that
  changes nothing searched (a launch, a label chosen).
- **`platforms/CurtainTimes.kt`** reads how long the curtain stays over each emulator
  (`data/launch/curtains.json`, milliseconds per package name, from 0 for none to 10 s): the time
  its own screens (splash, game list) take to give way to the game, measured on a device by
  recording the screen through a launch (`adb shell screenrecord`).
- **`art/`** decides where a game's art comes from: `ArtIndex` reads an art extract and finds a
  game by title (case, accents, punctuation and spaces aside; a title naming several games finds
  none), `regions/Regions` orders scans by how close their region is to the game's (NTSC-U, PAL,
  NTSC-J groups), `scansOf` names a serial source's scans (only serials of its platform's form),
  `LabelCut.on` cuts a game's label out of a scan: its disc's whole face, or on a cartridge's front
  the label of the front of the scan's shape (the scan's proportion within 6 % of the front's, the
  game's own medium's first), in whole pixels inside it, none for a scan of no front's shape;
  `ArtSources.of` gathers a platform's sources from the catalog and its own extract only;
  `ArtSources.requestFor` makes a game's request (the scan of the region chosen for its label, the
  extract's, then the serial source's, with its `LabelCut`). The profile's data (`ArtKind`,
  `Front`, `LabelCrop`, `SerialScans`) lives in `platforms/`, the rules in `art/`: `art` depends
  on `platforms`, never the reverse
  and lists its images by region (`variantsOf`); `ArtSources.requests` plans a library's: only its
  games still wanting art in their sources' version (`ArtIndex.versionOf`, the extract's first
  line), so that no extract is indexed when none does. `Scraping` is a run's state (waiting,
  under way, done, stall, retry delay), changed only by its operations; `AbsentArt` stores the games
  no source has, with the version of the sources they were looked for in.
- **`library/DemoLibrary.kt`** makes up libraries of any size, the same for the same arguments.
- **`storage/DocumentPaths.kt`** maps document ids such as `1A2B-3C4D:ROMs/ps2` to paths such as
  `/storage/1A2B-3C4D/ROMs/ps2`, and to a **place** the user reads (the SD card, then `ROMs`, `ps2`).
- **`settings/`** holds the app's `Settings` (the button style, the edges' smoothing), whether the first launch is still
  to do, and their stored format.
- **`Values.kt`** holds the newtypes shared across modules: `PackageName`, `ContentUri` (built
  with `ContentUri.parse`, so it is always a `content://` URI), `FilePath`, `FileName`.

### Android plugin (`kotlin/android`)
- **`CartouchePlugin.kt`** is the only class Godot sees (the `CartoucheAndroid` singleton).
  Getters answer at once; operations answer later through the `answered` signal (threading is
  described in its header). `PendingPick` tracks the folder pick awaiting its activity result.
  In debug builds, `launchArguments` hands GDScript the `arguments` extra of the launch intent
  (`--demo-games=N`, `--bench=scroll`), and `useDemoLibrary` swaps the library for a demo one,
  stored apart from the user's.
- **`Battery.kt`**: `BatteryWatch` follows the system's battery broadcast from each resume to the
  next pause and tells each new state (level, plugged in) through `battery_changed`, on Godot's
  render thread, where the plugin's signals are registered; `BatteryState.now` answers `battery()`.
- **`Wire.kt`** defines the Dictionary format and the stable error codes (`ErrorCode`). The
  library, with its shelves, travels as one JSON text instead: on a handheld, each Dictionary costs
  about 0.1 ms on Godot's main thread, so thousands of them freeze the screen, while Godot parses
  the JSON of a library in milliseconds. Lists follow INV-E0-16.
- **`launch/`** turns a resolved launch into a started activity:
  - `IntentMapper` builds the intent;
  - `Launcher` checks a game in the background (its emulator installed, its file still there:
    `checkGame`, which starts and stops nothing), then prepares it (the same checks, and stopping a
    lingering emulator on Android ≤ 13) and starts it on the main thread, without Android's
    transition between apps. The emulator reads the game through the intent's own read grant,
    which Android revokes once the emulator's activity is gone;
  - `Curtain` is the black window over the emulator; it needs the "display over other apps"
    permission, granted from the device check.
- **`storage/Folders.kt`** covers folders picked with the system picker: keeping read access (and
  nothing more), and listing a folder level from the documents provider for `FolderWalk`. Its
  tests run it against a fake `DocumentsProvider`. `LibraryStore` writes the library file
  atomically and sets an unreadable one aside; `SelectionStore` and `SettingsStore` do the same
  for the selection and the settings, whose unreadable files are only replaced.
- **`library/LibraryService.kt`** runs scans, counts (`preview`: the scan's own walk and sorting,
  nothing saved), choices, removals, selections and library launches on one thread, in the order
  they arrive. Setting a platform up or removing one gives up the access to folders no platform
  uses any more. Each library it keeps is published with its `Finders` (`@Volatile`), made in the
  background once the call that kept it is over, on a thread of low priority; the plugin's `browse`
  and `titleMarks` read them at once from Godot's thread: a key typed is answered
  within the frame, as JSON (`View.toWireJson`), with the shelf's size so that a view of another
  library is set aside.
- **`art/`** runs scraping: `Scraper` hands a run's requests to four workers, which download
  through the `Fetch` port (`HttpFetch` in the app, `FakeFetch` in tests), cut the scan to its
  label (`ArtImages`: to its disc, on a square, or to the label `LabelCut` gives, at its own
  proportions; 1,024 pixels at most, JPEG; a scan of no known shape passed over for the next)
  and store it (`ArtStore`: one file per game, named after a hash of its id, written atomically).
  It stops while the app is paused (a game is played), resumes on the network callback or after a
  growing delay, and tells Godot through the `art_changed` signal. It starts after the library is
  read, after each scan and after a removal, never for a demo library; each time, the images of
  games no longer in the library are deleted first (`ArtStore.keepOnly`). A game's images by region
  are downloaded when its properties show them (`VariantDownloads`, three at a time, each once
  while under way, told through the `label_variant_downloaded` signal) and kept apart
  (`ArtStore.saveVariant`, the latest 48); choosing one (`chooseLabel`) records the choice, then
  copies the image as the game's (`ArtStore.adopt`), giving the choice up if it cannot. An image
  chosen while the game's art is being looked for stays (`ArtStore.saveIfAbsent`). A picture of the
  user's own (`OwnPictures`) is picked with the system's document picker (`pickLabelPicture`),
  copied upright and at most 2,048 pixels long while it is framed, then cut to its framed rectangle
  (of the label's proportions, which Godot sends) at 1,024 pixels on its longer side and kept as the game's image (`keepOwnLabel`, through `LabelChoices`).
- **`AndroidManifest.xml`** lists the permissions, each justified in a comment.

### Godot (`app/`)
- **The screens** (`screens/`): `ScreenFlow`, in the carousel's scene, shows one screen at a time
  in front of it and returns once the carousel can be used; each screen is a scene of its own that
  says when it is done. The settings (`SettingsMenu`, `PlatformList`, `ConfirmRemoval`) reuse the
  form adding a console (`AddConsole`) to edit one. `Controls` holds the button style that
  `ButtonGlyph`, `ButtonHint` and `ButtonMark` draw; the edges' smoothing is the root viewport's
  `msaa_3d`, set at start from the settings and by `EdgeSmoothingScreen`. The theme
  (`carousel/carousel_theme.tres`) holds the buttons, fields, toggles and focus ring of every
  screen; the font is Fredoka throughout (`fonts/`, two weights of its variable font). The app's
  icon is `icon.svg` (the name in Fredoka SemiBold with the titles' white outline, on the
  carousel's dotted backdrop); `icons/` holds the launcher layers rendered from it, which
  `export_presets.cfg` names: the full icon, the adaptive background and foreground (the tile
  scaled so the launcher's visible two thirds show all of it), and the monochrome letters.
- **Controller buttons** (`adapters/android/android_buttons.gd`): on Android, A confirms and B goes
  back as Android names them, following the device's own setting when it has one. Godot's bundled
  controller database maps some devices by position instead (A is then the bottom button), so
  `AndroidButtons` drops each controller's mapping at start and on connection.
- **The carousel** (`carousel/`, the main scene) shows the consoles screen and the games screen.
  `carousel.gd` handles the screens, input, platforms, launches and remembering the selection
  (before going out of a console, launching, or leaving the app); the right stick turns the
  console or the game only on their screens (`StickTurn`). By touch, `Finger` reads the first
  finger as a tap, a long press or a drag (the design's thresholds, times passed in, so it is
  tested alone); the carousel takes the touches over its screens (`_gui_input`): a tap or a long
  press on the console or game in the middle, a swipe (anywhere on the consoles screen, beside the
  game on the games screen) moves exactly one console or game (`Carousel._drag`, past 80 pixels,
  whatever its length or speed), a drag on the game, or over the properties, turns it
  (`StickTurn.touch`, back to the front once let go). Buttons, cards and keys answer taps as
  clicks (Godot emulates the mouse from touch); the label zone and the framing read their own
  finger; the ring reads its own in `_input`, before the controls over it. The system's back
  (`NOTIFICATION_WM_GO_BACK_REQUEST`) is sent as B. `ShelfRow` moves the row and recycles a fixed pool of places, so its cost does not
  depend on the number of games; titles are drawn in each place's small `SubViewport`, one per
  frame, until a game's art is read (`GameArt`: on a worker thread, one texture sent to the GPU a
  frame, the latest 24 kept); a game without a scan gets its shelf's blank (`LabelLook`, colours
  and band from `appearance.json`). `CarouselLayout` holds the mechanics as pure functions.
  `GameSearch` (`carousel/search/`) is the ribbon: the carousel hands it ↓, L1, R1 and, while
  what is found is kept, B; open, it takes every press. It asks the plugin for each view and shows
  it with `ShelfRow.show_games` (the same models, another list) and `ShelfRow.jump`; the pill
  underlines the words typed (`TitleMarks`), the hints tell where L1 and R1 lead. Without the
  plugin (a desktop run) nothing is found, and the index is empty.
  Scraping's progress is a bar at the bottom right, beside the hints, where a message shows too: it moves to each count, greys with the reason while
  the run waits, fades once full, hides for a launch's message, and shows and fades with the pill
  in a launch animation. `Appearance` reads `appearance.json` once and finds the medium and the
  console folders; a medium's scene is loaded when a library holding a game of it shows, a
  console's the first time its console or its launch animation is asked for (the animation is made
  from a model never put in the tree: one for a console with steps of its own, else one per medium
  its games come in, all of a shelf's made as it is selected, never on A), and a manifest with
  problems, or a platform's second default, is traced and left out. What it loads stays; the
  labels' viewports are what weighs (debug builds trace how many are alive, and the time a shelf
  takes to prepare, each time one is selected).
- **Consoles** (`carousel/consoles/`): `ConsoleRow` lays the consoles out as `ShelfRow` lays the
  games, endless as they are (`CarouselLayout`, `Pose`), the selected one standing as the launch
  animation has it.
  `LaunchAnimation` turns a console's steps (its folder's `launch.json`; `data/launch/media.json`
  for the platforms shown by their media) into a Godot `Animation`, its tracks on the carousel's
  nodes and on the console's moving parts (`Consoles/<platform>:<property>`: each console is named after
  its platform), its moments as metadata; `ConsoleSequence` has the `AnimationPlayer` sample it at
  the times it is given, puts the chosen disc between the row and the console's seat, and draws the
  consoles apart while they blur behind the games (`ConsoleLayer`: a second view of the consoles
  alone, blurred by `console_layer.gdshader`), the backdrop's dots blurred as much in their own shader
  (`background.gdshader`'s `blur`), and the consoles leaving as the games come (`Carousel` caps
  `behind_amount` by the games' `neighbours`). The PS2 slim (`ps2_slim/`) is a `Ps2SlimModel`: its
  `Ps2SlimShape` gives its body, lid, well and strip (`Ps2SlimGeometry`, on `ShapeGeometry`'s
  rounded blocks, shared with the cartridge), its lid turns about its hinge, the drive's
  `Spindle` sits in its well. Their plain
  parts use `carousel/models/solid.gdshader`, colours and finishes as its parameters, rather than
  standard materials: every distinct material is a shader (and its fading copy) that the graphics
  driver keeps in memory, several megabytes each on a handheld.
- **Console order** (`carousel/consoles/`): `ConsoleOrder` puts the consoles in order on a ring:
  `ConsoleRow.wheel` takes them from the row to it, each sliding to its slot; `ConsoleWheel` is the
  ring's rule (no end, the console held trading places as it goes, B giving the old order back),
  pure and tested alone. The ring's dashed track is drawn on a layer of the backdrop (a
  `CanvasLayer` at or under the environment's `background_canvas_max_layer`), which the 3D view
  draws behind it: the consoles stand in front of the track. `ConsoleSticker` draws the console held as a sticker: alone in a view of
  its own (render layer `ConsoleLayer.STICKER`, which the carousel's camera leaves out; the sun
  lights that layer too), drawn again only when it moves, then outlined and shadowed by
  `sticker.gdshader` only round it.
- **Properties** (`carousel/properties/`): `PropertiesScreen` holds what a game's and a console's
  properties share (the staging under the light, the three-part moves, the name's fitting);
  `NameEditor` is the name's field and keyboard (`GamepadKeyboard`), used by both.
  `ConsoleProperties` stages the selected console (`ConsoleRow.stage`), its name with a callout on
  its right, and "Change place" (or Y), which leaves for `ConsoleOrder`. `DiscProperties` stages the selected disc
  (`ShelfRow.stage` and `staged`, the neighbours fading), shows its zones
  (`LabelZone`, a black ring drawn as it has the focus, `FocusCallout` naming it with an arrow) and
  its images by region (`LabelCard`, `label_thumbnail.gdshader`) and frames a picture of the user's
  own (`LabelFraming`, the same rule as the core's `LabelFraming`, at the proportions of the model's
  label face, shown through the label shader's `label_window` without cutting the picture). Any
  image shows on a label through `label_window` covering its face, centred: one of another shape
  (a Famicom's label on an NES cartridge) is cut, never stretched; each move from one screen to the
  next plays in three parts (`Move`: what leaves, the 3D moving from one `Staging` to the next, what
  comes), no press counting meanwhile. Images are read by an `ImageReader` (a worker thread, one
  texture a frame), as `GameArt` reads the games' art. `OperatingLight` (`operating_light.gdshader`)
  draws the light between the backdrop and the 3D.
- **Launches**: `GameLaunch` (`carousel/launch/`) runs a launch from A to the carousel shown again,
  playing the console's launch animation, or else its media's insertion;
  `Insertion` holds the motion as pure functions of time, its timings, distances and sounds per
  media in `appearance.json` (`insertions`), tuned without code; `carousel/models/spindle.tscn` is
  the drive's spindle, `carousel/launch/blackout.gdshader` the black growing from the disc's centre.
- **Media** are folders (`carousel/media/<medium>/`, see "Adding a medium"): each game is shown on
  the model of its medium (`Game.medium`, `ps2_dvd`, `sfc_cart`), or, without a folder of its own,
  the one its kind falls back to (`kind_media` in `data/carousel/appearance.json`, which also holds
  a label colour per platform, the pose and the insertions, per kind). A model is any scene with a
  `Label` mesh whose material uses `carousel/models/label.gdshader` (the carousel sets
  `label_texture`). As a shelf is selected, every place makes its model of each medium of its
  games, if not made yet, as the first instance of a model takes 10 to 30 ms on a handheld; a place
  keeps them until the library has no game of that medium; the media of no game are never loaded.
- **The shipped models are built from their shapes** (`carousel/media/*/*_shape.tres`): each part
  is a `ShapedMesh` naming one of the shape's `parts()`, which asks the shape for its arrays;
  `DiscGeometry` turns profiles around the disc's axis, a cartridge's geometry sweeps rounded
  outlines with bevels (`ShapeGeometry`), both in millimetres through `MeshBuilder`, which scales them to world
  units, turns every face the way its normals point and squares tangents to normals. Changing a
  dimension in the inspector rebuilds the model in the editor. Impossible dimensions build
  nothing: the shape's `problems()` names the rules they break. Materials: the label's varnish,
  grain and grooves (`label.gdshader`), a disc's mirror underside, whose `light()` draws the
  rainbow streak of its grooves (`disc_mirror.gdshader`), clear plastic (`clear_plastic.gdshader`),
  and what they all reflect, a studio sky that is never drawn (`carousel/studio_sky.gdshader`).
- **`AndroidServices`** (the `Android` autoload) turns plugin answers into typed values
  (`Folder`, `Entry`, `Candidate`…) and exposes operations as coroutines, such as
  `await Android.list_folder(folder)`; see its header for running without the plugin.
- **`Diagnostics`** (autoload, `dev/diagnostics.gd`) traces every input event with the actions it
  matches, focus changes, lifecycle notifications, the plugin traffic, and frames that miss their rate (60 a second, 30 at rest)
  (with the rendering pipelines compiled meanwhile, the usual cause), in debug builds only. The
  Kotlin side traces intents, activity results, installation checks, title indexing, scans (their
  timings, ignored files and skipped folders) and library problems the same way (`trace` in
  `Wire.kt`). Add trace points
  with every feature.
- **`CarouselBench`** (`dev/`) drives the carousel like a user for `dev/bench.sh`: held scrolling,
  platform changes, a turning game, the properties, the ring, swipes, or nothing at all on the games
  screen, the consoles screen or under the settings (`idle`, `idle_consoles`, `settings`) for 30 s,
  then one line of frame statistics, draw calls and the main loop's and the drawing's CPU time per
  frame; or one launch (`--bench=launch`), which `GameLaunch` measures itself. The scenarios with
  presses keep the app awake (`Resting.stays_awake`), so that their frames are the motion's; `idle`,
  `idle_consoles` and `settings` are measured once it rests, still. `--msaa=N` sets the 3D's
  antialiasing for a run.
- **`FrameShots`** (`dev/`, `--shots=DIR` with Godot's `--fixed-fps 60` on a computer) saves pictures
  of the carousel at set frames, presses (and a push of the stick) sent at set frames too, many of
  them half-way through an animation: with time fixed per frame, two runs of the same code give the
  same pixels. Run it on a console with its own model and on one drawn by its medium (`--shelf=…`):
  an optimisation must leave every picture of both identical.
- **The device check** opens from the carousel by holding Select for 2 s, in debug builds; back at
  its root returns to the carousel. It has a Library tab (folder, emulator, scan, games, ignored
  files, launch), and is built from one scene per tab over a shared `DeviceCheckPage` base, with
  signals wired in the scene files wherever they exist before `_ready`. The root forwards resume
  and back events to the visible page. Back is the `app_back` action or Android's back request:
  some handhelds send their back button as a joypad button only, the same one as Select.
- **The export plugin** adds the AARs, the core jar and the dependencies listed in
  `bin/dependencies.txt` to Android exports. Gradle writes that file, so versions are only declared
  in `kotlin/gradle/libs.versions.toml`.

## Working on the code

- Build and test commands are in the README. On a device, `dev/logs.sh` follows a debug build's
  traces; `adb exec-out screencap -p > screen.png` shows the screen. `cd kotlin && ./gradlew test`
  runs every Kotlin test; the core tests also parse the definition files shipped in `app/data`.
  `dev/test_godot.sh` runs the GDScript tests.
- `dev/bench.sh` measures a debug build on a device at several library sizes (the device's own,
  and demo ones of 150 to 5,000 games) and can record every measurement as a JSON line, labelled
  (`--label`) to follow a series of changes. Besides times and frames, it measures what each
  scenario costs in energy: the app's processor time per second and, where the GPU tells it (Adreno),
  how busy the GPU is and at which clock. Every scenario starts on the PS2's games; the device's own
  art is set aside while the scans are downloaded again, then put back as it was.
- **Keeping it frugal**: left alone, the app rests (`Resting`): from 2 s Godot's low-processor
  mode draws only what changes, its loop running about 30 times a second; from 5 s what moves by
  itself (the nodes of the `paced` group, each at its `pace`: the backdrop's dots, the rows' float
  and sway, the welcome's worm) slows to a stop, and nothing more is drawn. Anything that moves on its own must join that group,
  or keep the app awake while it plays (`Resting.moving`: labels downloading, a launch, the way into
  or out of a console, a discovery); other animations (a message) play on at rest, drawn as they
  change. The screens in front hide the
  carousel under them; on the games screen the consoles behind are not drawn, brought back
  as a game goes into its console or to go out; the media's models are loaded and made ready as a
  library with consoles of those media is shown, never the others (`Appearance.model_of`); the
  battery's bolt is drawn (`BatteryChip`) rather than written with the
  system's emoji font, and the plugin tells each change of the battery as it comes (`Battery.kt`).
  Awake, the work per frame is what costs energy. What nobody sees is not redone: the consoles
  behind the games are arranged only in the frames `ConsoleSequence` moves them in, and their blurred
  view is drawn again only then; the games' row skips its layout while it is wholly faded; the
  consoles' and games' transforms, the lid, the properties' light and the focus bubble are set only
  when they change. What a start does not need waits: the title lists are indexed only once the
  settings or the form adding a console open (filed by their titles alone, a disc's whole name read
  only when a file could be it), the art index only when a game may still find art, and the library is
  asked for as the carousel's scene starts.
- **Without the plugin** (the editor, a desktop run), the carousel shows the demo library of
  `dev/demo/desktop.json`, with made-up label artwork: models and materials are tuned on a
  computer. The file is what the plugin would send; `DesktopDemoTest` (Kotlin) fails when it is out
  of date and writes the new one. In debug builds, sounds put in `user://dev-sounds/`, named after
  an insertion's cues (`ps2-clip.mp3`), are played as it runs (`DevSounds`). They are never part of
  the repository: the insertions play silently until freely licensed sounds are chosen.
- **Art data**: `dev/launchbox_art.py` makes a platform's extract from the LaunchBox Games
  Database dump (`Metadata.zip`, published daily), of disc scans by default, of cartridge fronts
  with `--type "Cart - Front"`; `dev/dat_titles.py` does the same for the reference lists, from
  libretro-database's Redump and No-Intro DATs. Images are never part of the repository: they are downloaded on the device.
- **Without the plugin**, A goes into a console, then plays the launch, which then fails: launch
  animations and insertions are tuned on a computer too. A launch animation's steps can be tuned
  apart from the app and exported as they are; `dev/launch_steps.py` keeps what the app plays.
- **Fading a model** goes through `ModelFade`: Godot's per-instance transparency does not show on
  the mobile renderer, so a model is drawn with its own opaque materials while it is not faded, and
  with transparent copies of them while it is (our shaders' fading variants, `*_fading.gdshader`,
  by their `fade` instance uniform; standard materials by their albedo's alpha), their depth still
  written so that a faded model hides what is behind it. A shader shared by both variants lives in
  its `.gdshaderinc`.
- **Debug arguments** (`--esa arguments` on the device, after `--` on a desktop):
  `--turntable=0.25` turns the selected game to show all its sides, `--shelf=gba` opens on a
  platform's shelf, `--art-refused` makes every art server refuse (to see the message and the
  retries), `--demo-games=N` (all on one console with `--demo-shelf=ps2`, for a shelf of fan
  size) and `--bench=…` as in `dev/bench.sh`, `--shots=DIR` (`FrameShots`).
- **Shaders are only compiled when something is drawn**: the headless runs of `dev/build.sh` do
  not see their errors. After changing one, run the desktop demo or the device and look for
  `SHADER ERROR` in the log.
- The Vulkan pipeline cache is saved as soon as it grows (`save_chunk_size_mb` in
  `project.godot`), since Android kills apps rather than quitting them: a start then compiles no
  pipeline twice (about 100 ms per frame that needs one).
- Both toolchains treat warnings as errors: the Kotlin compiler, and the GDScript typing warnings
  (`untyped_declaration`, `unsafe_*`…) set in `project.godot`.
- Every guarantee in [INVARIANTS.md](INVARIANTS.md) has a test named after its id.

## Adding a console

A console is one folder, `app/carousel/consoles/<id>/` (`ps2_slim/` is the example); adding one
touches no other file.

- **The contract** (`ConsoleModel`) is all the carousel and the launch know of a console: its
  `shape` (a `ModelShape`, its dimensions in millimetres and its named rules), its
  `moving_parts()` (each a float property of the model named after its unit, such as `tray_cm`,
  with a role and its values at rest and fully moved, at rest on a new model; the role is what the
  placeholder does with it: an `OPENING` (lid, tray, door) opens before the medium and closes once
  it is in, a `FLAP` is pushed open by the medium as it comes over the seat and stays open, a
  `PRESS` (eject, open) is pressed and let go before the openings open, `POWER`, `LIGHT` and
  `SPIN` come on at the end and stay on, a `POWER_PRESS` (a momentary power button) is pressed as
  the console comes on and let go at once, a `POSE` (reset, a door aside) moves only in the console's own steps), its `seat()` (where
  the medium stands, in the model's space, following the part that carries it, in the medium's own
  frame: see **Seat**), its `approach()` (the way in, a unit vector in the seat's frame, `+Z` by
  default), its `presented()` (how it faces the camera in the placeholder), `hold(angle)` (the
  medium turning, when the console turns it), `fade(amount)` and `set_shader_value(mesh, parameter,
  value)`, the one way a part changes a material: on the mesh's own material
  and on the copy it fades through, before the model is ready or after (a material a part changes
  is `resource_local_to_scene`, on the mesh instance, so that two consoles of a kind light apart).
  A console's light is the contract's own `light_energy`, the glow of its scene's `%Light` mesh:
  a console with one lists it among its moving parts as a `LIGHT`.
  `moving_parts()`, `seat()`,
  `approach()` and `presented()` depend only on the shape and the parts' properties, never on the
  model's nodes: the launch animation is made from a model that is not ready.
- **The files**: `<id>_shape.gd` (`<Id>Shape extends ModelShape`, its rules refusing what cannot
  be built, its `_arrays` its geometry's: `mesh_arrays` builds nothing from dimensions its rules
  refuse), `<id>_geometry.gd` (its parts as pure functions, on `ShapeGeometry` and
  `MeshBuilder`: rounded outlines, pills and circles included (`rounded`, `circle`,
  `square_around`, a box `centred` on a point, a D-pad's `cross`), any polygon's corners rounded (`filleted`), blocks and slabs
  with their bevels (`block`, `slab`, `rounded_sides`, `profile`) or their edges `rolled` by a
  radius per side, square-edged `prism`s and
  `wedge`s under a sloping roof, `boxes_on` a face (ports, vents), solids `swept` through outlines
  (their tips a `TIP` wide), faces `flat` or `laid` on a
  curved surface, a face `holed` around recesses (laid in pieces between vertical lines through
  them) and each recess `sunk` (its walls, its floor), a built part `moved` into place or pieces of one laid out in another plane
  (`MeshBuilder.basis`, `ShapeGeometry.PLAN` and `SIDE`), and the checks rules make: a rounded box
  within another (`fits`), points inside an outline (`inside`), a box `within` another and two
  that `overlap` (both with an area: Rect2 cannot tell a box turned inside out), boxes within an
  area and apart (`apart`); what a second folder needs goes there, never copied, as `DiscTray`, the disc
  drive's tray both Xboxes slide out: its recess, hub and the opening behind it), `<id>_shape.tres` (the measured dimensions), `<id>.tscn` (`ShapedMesh` parts, so
  that they follow the shape: every part, the smallest detail too, is built from the shape where
  it stands, no node placed by hand but a moving part's pivot, which the model sets from the shape;
  on the existing shaders, `ShaderMaterial`s only: a new shader would compile the first time the
  console shows; a node per moving part, its origin the part's pivot), `<id>_model.gd`
  (`<Id>Model extends ConsoleModel`), `console.tres` (the manifest) and, once animated,
  `launch.json`. Without it the console plays the placeholder.
- **A logo** is drawn by us as an SVG in the folder (never copied from a file), imported with
  `mipmaps/generate` on, uncompressed, at an `svg/scale` that gives it 8 pixels a millimetre at
  least, its background the colour of the surface it lies on. Its face is
  `ShapeGeometry.decal(mesh, box, z)` (a hair over the surface, its UV square the image, upright),
  a part of its own; its material the label shader with `label_texture` the SVG, `has_label` on,
  `grain` 0 and its `roughness` and `varnish` the surface's. It fades with the console, as any
  label does.
- **The manifest** names the platform (one of `data/platforms/profiles.json`, whose profile gives
  its games' medium), the version (its model code in lower case, hyphens between its words:
  `dol-001`) and whether it is the default one (one per platform), the names
  shown, the scene, the steps (empty for none) and the most triangles the model may be drawn with.
- **The three.js viewer**: `dev/export_console.sh <id> [out_dir]` writes `<id>.glb` (the model, its
  moving parts as named nodes) and `<id>.model.json` (how it is presented, its seat and way in, and
  per moving part its role, values and unit, every node it moves and every material parameter it
  sets with their values at rest and fully moved, and the seat once it is fully moved; and its
  `hash`, the console's fingerprint) into `build/models` unless told otherwise. Steps tuned there
  carry that hash as `model_hash`, and become the folder's `launch.json` with `dev/launch_steps.py
  <export> --console <id> --console-key <key>`, which refuses them once the model has changed.
- **Beside photos of the real one**: `dev/render_console.sh <id> [png] [label image]` renders the console as the
  carousel lights it, from the front, three quarters, side, back and top, and three quarters with
  every part fully moved, into one picture (`build/renders/<id>.png` unless told otherwise). It
  needs a display; its window never takes the keyboard.
- **The tests that hold it** (`test/carousel/consoles/console_folders_test.gd`) run on every
  folder: its manifest is whole, its platform has a profile, its moving parts are those the test
  lists for it, each in its role (`ROLES`: adding or changing one is a choice made there too), at
  rest on a new model, its steps move only them and were tuned on the model as it is (INV-E10-01); any dimensions
  its rules accept build closed parts turned outwards, its openings lie within its bounds at rest
  and its other moving parts stand out of them by `ConsoleModel.PROUD_MM` at most, pass through
  nothing as the placeholder moves them (its rebound included, the others held as it holds them
  then), still show pressed, and once open leave the medium's way in free but for the part
  carrying it, its logos (the folder's images) on its faces facing out, the others are refused
  (INV-E10-02: each folder draws its own shapes, seeded from its name, so that a folder added
  changes no other's cases, a share of each dimension near the shipped one, as a size and as a
  place, and some far from it or nought, and builds three of those drawn far at least); each of its
  parts is placed by the shape, no node but a moving part's pivot moved
  (`test_INV_E10_02_a_console_s_parts_are_placed_by_its_shape_no_node_but_a_moving_part_s_pivot_moved`),
  each moving part moves part of it, a pressed button into it, and is moved only when its value
  changes; without steps it plays the placeholder (INV-E10-03); its contract reads no node, its
  model is within its triangle budget and drawn with the shaders the carousel already has, its
  clear plastic clear, its lights showing on it alone, faded or not, and its logos sharp and not
  mirrored. What is crossed (a part's way, a logo's face) is checked in millimetres: in world
  units a small triangle seems flat to Godot and is never met.
  A console's own looks (where its lid sits, how its tray slides) go in a test of its own, as
  `ps2_slim_test.gd` does for the PS2, with how it draws its shapes; what any console's test needs
  is shared in `test/carousel/fixtures.gd`, never copied: a `new_console` of a scene, one `built`
  from other dimensions, dimensions `drawn_around` the shipped ones until its rules accept them and
  a property's shapes `accepted` (each accepted, nine in ten at least different, or the generator
  is stuck), a shape `assert_refused` by the rule a break names and `assert_found_refused` for the
  shapes a property once found, how far a part goes (`open_of`), a part's box in its console
  (`box_of`), the `bounds` of points, whether triangles meet a box (`meets`; beside the PS2's
  `ps2_slim()`, which the carousel's own tests use). Dimensions the shared test finds its rules
  accept but cannot be built are refused by a tightened rule, never by a looser test, and kept as a
  fixed case of the folder's own impossible-dimensions test.

## Adding a medium

A medium is one folder, `app/carousel/media/<medium>/`, named as `data/platforms/profiles.json`
names it in a platform's `medium` (`ps2_dvd`, `snes_pal_cart`; `ps2_dvd/` is the example); adding
one touches no other file but the list of media still to be made in its test.

- **The contract** is all the row, the labels, the launch and the consoles know of a medium: a
  scene whose root holds its parts (`ShapedMesh`es of one `ModelShape`, its dimensions in
  millimetres and its named rules), one of them a `Label` drawn with the label shader, its face's
  UV square the label's image; the shape's `title_area()` and `platform_area()` say where a game
  without a scan has its title and its platform's name drawn. It stands in its own frame, the one
  a console's seat takes (see **Seat**); its root's scale is its size in the row only (the Game
  Boy line's cartridges 1.75, to read as large as a disc): on its way into a console it grows or
  shrinks to its real size, at which it is seated and the placeholder lifts it (`medium_box`).
- **The files**: `medium.tres` (the manifest: its kind, `dvd`, `minidisc` or `cartridge`, as the
  platforms declaring it have it, which gives its insertion; its scene; the most triangles it may
  be drawn with), `<medium>_shape.tres` (the measured dimensions), `<medium>.tscn` (the scene, on
  the existing shaders), and a shape and a geometry of its own (`<medium>_shape.gd`,
  `<medium>_geometry.gd`, as a console's) only when the shared ones cannot express it: discs are
  one family (`DiscShape`, `DiscGeometry`: a hub, a stacking ring, a label, a mirror recorded
  between its data radii), cartridges their own, built on `ShapeGeometry`'s pieces (see "Adding a
  console"): a face `holed` around a label's recess, a grip, a screw's hole, each `sunk`; edges
  `rolled`; rings `joined`; what is printed or moulded on a back laid out turned round
  (`ShapeGeometry.BEHIND`, `behind`). A family shared by several media lives in
  `carousel/models/`, never in one of their folders: `GbCartShape` and `GbCartGeometry` (the Game
  Boy's cartridge, the Game Boy Advance's built on its pieces), `NesCartShape` and
  `NesCartGeometry` (the Famicom's outline), `SnesPalCartShape` and `SnesPalCartGeometry` (the
  North American cartridge's halves and board). A medium that looks exactly as another, as the
  Game Boy Color's or the Super Famicom's cartridge, names the other's scene in its manifest.
- **Recesses seen from the carousel**: there is no solid subtraction. A label's recess, a grip, a
  screw's hole are faces laid around a hole and sunk into it; a slit, a groove or a notch too
  narrow to show its walls at the carousel's distance is a dark face a hair over the surface it
  cuts (`SnesUsCartGeometry`'s grooves, `SnesPalCartGeometry`'s slits).
- **Without a folder**, a medium is shown as the one its kind falls back to (`kind_media` in
  `appearance.json`), as are the games of no medium and those of a medium of another kind; a
  folder with problems is traced and left out.
- **The tests that hold it** (`test/carousel/media/media_folders_test.gd`) run on every folder: its
  manifest is whole and its medium declared by platforms of its kind (INV-E10-07), any dimensions
  its rules accept build its parts closed together, turned outwards, its label on the medium, the
  others are refused and build nothing (drawn around the shipped ones as a console's, seeded from
  its name), its title and platform's name centred on its label's face, its model within its
  budget; every medium a console's platform declares has its folder or is still listed to be made
  (INV-E10-05), and comes down that console's way in at its real size, its own mesh clear of every
  part but those it lies in, drawn solid (`HOUSINGS`: none for a console whose slot is a real
  cavity down to its connector, as the Game Boys', see `ShapeGeometry.connector`), and its box clear
  of the openings (`test/carousel/consoles/console_folders_test.gd`); the media where a colour is their look
  keep it (the PlayStation's black disc, every other disc silver underneath, the Game Boy Color's
  cartridge the Game Boy's grey one, the Nintendo 64's gold contacts). The disc family has its own
  tests (`test/carousel/model_geometry_test.gd`). A medium's own looks go in a test of its own, with
  how it draws its shapes.
- **Beside photos of the real one**: `dev/render_console.sh <medium> [png] [label image]` and
  `dev/export_console.sh <medium>` take a medium's folder as they take a console's (its last view
  from below, its label blank or the image given; its kind, label areas and dimensions' hash in its
  `.model.json`).

## Writing tests

Tests live next to the code they test (`XTest.kt` in the package of `X`), are named by the
behaviour they check, and are of four kinds only. Copy the closest one:

- **Example**: one concrete case, set up, run, checked on its typed result
  (`ScanTest`, "discs of one game make one game").
- **Property**: `checkAll` over generators, stating a law from outside: a round trip, never
  failing, not depending on an order, "changing X changes only Y" (`FolderWalkTest`).
- **Invariant**: a property of [INVARIANTS.md](INVARIANTS.md), its id first in the test name.
- **Android**: Robolectric, run on the oldest supported Android, a middle one and the newest
  Robolectric runs on Java 17 (`robolectric.properties`); documents providers are faked with
  `FakeDocuments`.

GDScript tests (`app/test`, GdUnit4) follow the same kinds. Their properties loop over seeded
random cases (`cases()` in `test/carousel/fixtures.gd`), so a failure always comes back.

Generators, fixtures and fakes are shared, never redefined in a test: `Generators.kt`,
`Fixtures.kt` and `Fakes.kt` of each package, in `kotlin/core/src/testFixtures` (used by both
modules) or `kotlin/android/src/test`. A port of the core (such as the walk's listing function)
is faked in memory (`InMemoryFolders`). Results are checked as typed values, never as messages;
a property that filters its cases also checks that enough of them reach the code under test
(`forEveryResolvedTemplate`). No mocks of Cartouche code, no real clock, no sleeps.

## Conventions

- **Kotlin:** typed functional style.
  - No `null` in our code: absence is `Option`, failure a typed error through Arrow's
    `Raise`/`Either`, and nullable platform values are converted once, at the boundary.
  - Exhaustive `when` over sealed types, never with `else`. Newtypes rather than bare strings.
  - `ktlint` (official style) and `explicitApi()`.
- **GDScript:** the official style guide, static typing everywhere, scenes rather than UI built in
  code, `%UniqueName` with typed `@onready`, and InputMap actions rather than raw buttons (the
  controller test page aside). `ui_accept` is redefined to add the joypad's south button, which
  Godot's default leaves out. Every action also has a keyboard key (arrows, Enter for A,
  Backspace for B, Escape for Select): keyboards work, and `adb shell input keyevent` can drive the
  app. Text shown to users goes through `tr()`, translated in `locale/*.po`; the device check is a
  developer tool, so its text is English and not translated.
- **Both:**
  - Comments explain *why*, on code people read often; no comment restates the code.
  - Every source file starts with `SPDX-License-Identifier: GPL-3.0-or-later`.
