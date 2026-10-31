# Cartouche

A game launcher for Android handhelds that shows your games as physical discs and cartridges.
Cartouche does not emulate anything itself: it finds your games, recognises them, and starts them
in the emulators you already have.

More and more frontends are heading in this direction, but none of them ever fully won me over.
Two things kept bugging me: they don't push immersion as far as I'd like, and I believe this kind
of experience should be completely free and open source.

So I built my own. First for me, and now for anyone who wants to use it, contribute to it, or fork
it and make it theirs; I tried to keep the codebase easy to get into.

## Consoles

NES, Super Nintendo, Nintendo 64, GameCube, Wii, Game Boy, Game Boy Color, Game Boy Advance (original or SP),
PlayStation, PlayStation 2 (slim or fat), Xbox and Xbox 360. Each one is a 3D model of the real console, and its
games come on their real medium: discs, cartridges, mini-discs.

## Key features

- **Immersion first:** a carousel of 3D consoles, then each console's games on their real discs and cartridges,
  and a launch animation made for each console (and for each model of it).
- **Smart labels:** each game is recognised from its own file (a disc's serial, a cartridge's checksum), then its
  real label is downloaded from ScreenScraper and LaunchBox, in your region first. Another region or a picture of
  your own is one menu away.
- **Your library, your way:** filter by name or by region, put your consoles in the order you like on a wheel,
  rename a game or a console.
- **Controller first:** everything works with the pad, from the first launch to adding a console; touch works too.
- **Speaks your language:** seven languages, following your device's until you pick one ([Languages](#languages)).
- **Uses your emulators:** Cartouche emulates nothing. It finds the emulators you already installed and starts each
  game in the right one.
- **Light:** at rest it draws nothing, and it stays smooth with thousands of games.

## Install

Download the APK from this repository's Releases page and install it on your handheld. You need Android 11 or
later on an arm64 device with Vulkan, and the emulators of the consoles you want to play.

## Languages

English, French, German, Spanish, Italian, Portuguese (Portugal and Brazil) and Japanese. Cartouche speaks your
device's language when it has it, English otherwise; to choose another, open the settings and go down to
**Language**.

A translation reads wrong, or your language is missing? Open an issue, or change the text yourself: each language
is one file, and [docs/translating.md](docs/translating.md) says how to fix one or add one.

## How a label is found

1. **Which game it is.** Cartouche reads the file itself (a cartridge's CRC32, a disc's serial) and looks it up in
   the No-Intro and Redump lists; when the file says nothing, its name decides.
2. **Which region.** The regions of the release found (France, Europe, USA, Japan…).
3. **The images on offer.** LaunchBox's scans, found by the game's name. ScreenScraper's images, found in a table
   shipped with the app (`app/data/screenscraper/`): for every release of the reference lists, its ScreenScraper
   game and the images it has. The table is built once per version of the app, so the device never asks
   ScreenScraper which game a file is; it only downloads images, one request each. PS2 discs also have
   psxdatacenter's scans, by serial.
4. **Which image first.** An image of the game's region (its country, or the zone containing it: France → Europe)
   comes first: on a cartridge ScreenScraper's (the printed label itself), then LaunchBox's; on a disc LaunchBox's,
   then ScreenScraper's, then psxdatacenter's. Then every other image, closest region first. The first image that
   downloads is kept. A label you chose, or a picture of your own, is never replaced; a game's properties list every
   image of every source, each named by its region and source.
5. **When ScreenScraper cannot answer** (busy, closed, quota spent), the next image is taken at once and ScreenScraper
   is tried again at a later scan.

## Contributing

Ideas, feedback and pull requests are welcome: open an issue to talk about a bigger change first.

- [docs/README.md](docs/README.md): start here. The three layers of the code, the commands, and for each task
  (add a console, a screen, a setting, a sound…) the page and the files to open.
- [docs/GLOSSARY.md](docs/GLOSSARY.md): every word of the domain, as the code spells it.
- [docs/INVARIANTS.md](docs/INVARIANTS.md): the guarantees every change must keep, each enforced by tests.
- [docs/adding-a-console.md](docs/adding-a-console.md) and [docs/adding-a-medium.md](docs/adding-a-medium.md): a
  new console or a new disc or cartridge, step by step.
- [docs/testing.md](docs/testing.md): the kinds of tests and how to run each.

## Building

Requirements: Godot 4.7.2 with its export templates, JDK 17, the Android SDK (platform 36, build
tools 36.1.0, NDK 29.0.14206865 and CMake 3.22.1, which Gradle installs when missing), Python 3,
gdtoolkit 4 for `gdlint` (`pip install --user "gdtoolkit==4.*"`), and `adb` for installing on a device.

```sh
export JAVA_HOME=/path/to/jdk-17 ANDROID_HOME=/path/to/android-sdk
export GODOT=/path/to/godot     # if `godot` is not on PATH
scripts/build.sh                # docs check, lint, Kotlin and GDScript tests, Kotlin build, debug APK in build/
scripts/build.sh --install      # same, then installs and starts it on the connected device
scripts/logs.sh                 # follows the debug build's traces on the device
scripts/bench.sh                # measures the installed debug build at several library sizes
```

A build asks ScreenScraper for images with Cartouche's developer key, read from `kotlin/local.properties`
(`screenscraper.devid`, `screenscraper.devpassword`), never from the repository; see
[Credentials](docs/README.md#credentials).

## Stack

- **Android only**, from Android 11 (API 30) to Android 16 (API 36), on arm64 devices with
  Vulkan. The library, folder access and launching live in the Android plugin: on a desktop, the
  Godot project shows a demo library instead, to work on the carousel without a device.
- **App:** [Godot](https://godotengine.org) 4.7.2 (GDScript, Mobile renderer).
- **Domain and Android plugin:** Kotlin 2.1.21 with [Arrow](https://arrow-kt.io) 2.1.2,
  kotlinx.serialization 1.8.1 and kotlinx.coroutines 1.10.2. The domain is pure Kotlin, tested on
  the JVM; the plugin is a Godot Android plugin (v2).
- **Build:** Gradle 8.11.1, Android Gradle Plugin 8.6.1, JDK 17.
- **Tests:** [Kotest](https://kotest.io) 5.9.1 (property-based), [Robolectric](https://robolectric.org)
  4.16.1 on Android 11, 13 and 14, [GdUnit4](https://github.com/MikeSchulze/gdUnit4) 6.2.1 for
  GDScript, ktlint.

## Credits

Cartouche builds on these projects, and thanks their authors.

| Project | Used for | License |
|---|---|---|
| [Daijishō](https://github.com/TapiocaFox/Daijishou) | Platform and emulator definitions (`app/data/platforms/daijishou/`) | MIT |
| [libretro-database](https://github.com/libretro/libretro-database) | Redump and No-Intro game titles and serials (`app/data/titles/`), cartridge ROMs' CRC32 (`app/data/prints/`) | CC BY-SA 4.0 |
| [LaunchBox Games Database](https://gamesdb.launchbox-app.com) | Which disc and cartridge scans each game has (`app/data/art/`), and the scans, downloaded on the device | Used with the database's public dump; images stay their owners' |
| [ScreenScraper](https://www.screenscraper.fr) | Which disc and cartridge images each release has (`app/data/screenscraper/`), and the images, downloaded on the device | Data under CC BY-NC-SA 4.0; images stay their owners' |
| [PlayStation DataCenter](https://psxdatacenter.com) | PS2 disc scans by serial, downloaded on the device | Images stay their owners' |
| [Fredoka](https://github.com/hafontia/Fredoka-One) | The font of the games' labels (`app/fonts/`) | SIL Open Font License 1.1 |
| [Plus Jakarta Sans](https://github.com/tokotype/PlusJakartaSans) | The app's text (`app/fonts/plus-jakarta-sans/`) | SIL Open Font License 1.1 |
| [IBM Plex Mono](https://github.com/IBM/plex) | The app's monospaced notes, counts and kickers (`app/fonts/ibm-plex-mono/`), Reserved Font Name "Plex" | SIL Open Font License 1.1 |
| [Godot Engine](https://godotengine.org) | Engine, and the Android plugin template the plugin started from | MIT |
| [Arrow](https://arrow-kt.io) | Typed functional programming in Kotlin | Apache 2.0 |
| [XZ for Java](https://tukaani.org/xz/java.html) | LZMA decoding of CHD disc images | 0BSD |
| [kotlinx.serialization, kotlinx.coroutines](https://github.com/Kotlin) | JSON storage, background work, and its tests | Apache 2.0 |
| [Kotest](https://kotest.io) | Property-based tests | Apache 2.0 |
| [JUnit 4](https://junit.org/junit4/) | Test runner | EPL 1.0 |
| [Robolectric](https://robolectric.org) | Android tests on the JVM | MIT |
| [GdUnit4](https://github.com/MikeSchulze/gdUnit4) | GDScript tests (downloaded by `scripts/test_godot.sh`, not shipped) | MIT |
| [ktlint](https://pinterest.github.io/ktlint/) | Kotlin style | MIT |
| [Gradle](https://gradle.org) | Build, and the wrapper in `kotlin/` | Apache 2.0 |

### 3D models

The consoles' 3D models are adapted from these downloads (CC-BY-4.0, licence texts beside each model in `app/carousel/consoles/`):

- This work is based on "NES Console and Controller" (https://sketchfab.com/3d-models/nes-console-and-controller-ffd427134d5e44b4850628030aa66236) by Daz (https://sketchfab.com/Darren.Hogan) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- This work is based on "Game Boy Color" (https://sketchfab.com/3d-models/game-boy-color-03c6fe28d45244d2acd55486e3cfee19) by Wikiti (https://sketchfab.com/wikiti) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- This work is based on "Super Retro Game Console" (https://sketchfab.com/3d-models/super-retro-game-console-d672d0ac1d6a4d238314d6675f8f92b2) by ELIZION (https://sketchfab.com/ELIZION) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- This work is based on "Sony PlayStation 2" (https://sketchfab.com/3d-models/sony-playstation-2-b53f858aa1584229a7f906239fc158a2) by Dolgov (https://sketchfab.com/Dolgov12) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- This work is based on "Gameboy Advance SP" (https://sketchfab.com/3d-models/gameboy-advance-sp-18c9688eaa8f4903a940c105242df15f) by thegraphicsgeek (https://sketchfab.com/thegraphicsgeek) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

### 3D logos

The PlayStation 2, Xbox and GameCube logos are pictures rendered from these downloads (CC-BY-4.0):

- This work is based on "Playstation 2 Logo" (https://sketchfab.com/3d-models/playstation-2-logo-266d26be2a6d47d58880bb723d1faf7a) by Anthony Yanez (https://sketchfab.com/paulyanez) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- This work is based on "Xbox Logo" (https://sketchfab.com/3d-models/xbox-logo-6fedd757c2fe47b2850df4ab6e110670) by Anthony Yanez (https://sketchfab.com/paulyanez) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- This work is based on "Gamecube Logo" (https://sketchfab.com/3d-models/gamecube-logo-f08be17bd3fc4a15ae35e00055d899bb) by Anthony Yanez (https://sketchfab.com/paulyanez) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)
- This work is based on "GameCube Logo" (https://sketchfab.com/3d-models/gamecube-logo-98bbc36e66b5445da6eeb6b2eb5b36ff) by ExplainedLake (https://sketchfab.com/explainedlake98) licensed under CC-BY-4.0 (http://creativecommons.org/licenses/by/4.0/)

## License

Cartouche is free software under the [GNU GPL v3 or later](LICENSE).
