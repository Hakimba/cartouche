# Cartouche

A game launcher for Android handhelds that shows your games as physical discs and cartridges.
Cartouche does not emulate anything itself: it finds your games, recognises them, and starts them
in the emulators you already have.

More and more frontends are heading in this direction, but none of them ever fully won me over.
Two things kept bugging me: they don't push immersion as far as I'd like, and I believe this kind
of experience should be completely free and open source.

So I built my own. First for me, and now for anyone who wants to use it, contribute to it, or fork
it and make it theirs; I tried to keep the codebase easy to get into.

## Status

Early development. The PlayStation 2 came first, then the NES, Super Nintendo, Nintendo 64, Game Boy,
Game Boy Color, Game Boy Advance, GameCube, Wii, PlayStation, Xbox and Xbox 360.

- **Library:** your ROM folders scanned, games identified against the Redump lists.
- **Consoles:** your consoles in 3D, each modelled after the real one, its lid, tray or slot moving;
  go into one to see its games.
- **Carousel:** games as 3D discs and cartridges, one shelf per console, 60 fps with thousands of
  games.
- **Launching:** the disc or cartridge goes into the console, each its own way, then the game starts
  in its emulator, which stays hidden until the game shows.
- **Labels:** each game's real disc or cartridge label, downloaded in the background.
- **Setting up:** everything with the controller: first launch, adding, editing and removing
  consoles, button style, and in Graphics how smooth the edges are drawn (4× unless you choose 2× or
  none, for less work on the graphics card).
- **Properties:** a game's label image (by region, or a picture of your own) and its name, a
  console's name, the consoles' order on a ring; by controller or by touch.
- **Frugal:** left alone, once its disc labels are downloaded, the screen stops moving and is drawn
  only when something changes, until the next press; little memory, and quick starts even with
  thousands of games.

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

## Building

Requirements: Godot 4.7.2 with its export templates, JDK 17, the Android SDK (platform 36, build
tools 36.1.0), and `adb` for installing on a device.

```sh
export JAVA_HOME=/path/to/jdk-17 ANDROID_HOME=/path/to/android-sdk
export GODOT=/path/to/godot   # if `godot` is not on PATH
dev/build.sh            # lint, Kotlin and GDScript tests, Kotlin build, debug APK in build/
dev/build.sh --install  # same, then installs and starts it on the connected device
dev/logs.sh             # follows the debug build's traces on the device
dev/bench.sh            # measures the installed debug build at several library sizes
```

How the code is organised: [docs/ONBOARDING.md](docs/ONBOARDING.md). Guarantees every change must
keep, each enforced by tests: [docs/INVARIANTS.md](docs/INVARIANTS.md).

## Open-source work used

Cartouche builds on these projects, and thanks their authors.

| Project | Used for | License |
|---|---|---|
| [Daijishō](https://github.com/TapiocaFox/Daijishou) | Platform and emulator definitions (`app/data/platforms/daijishou/`) | MIT |
| [libretro-database](https://github.com/libretro/libretro-database) | Redump and No-Intro game titles and serials (`app/data/titles/`) | CC BY-SA 4.0 |
| [LaunchBox Games Database](https://gamesdb.launchbox-app.com) | Which disc and cartridge scans each game has (`app/data/art/`), and the scans, downloaded on the device | Used with the database's public dump; images stay their owners' |
| [PlayStation DataCenter](https://psxdatacenter.com) | PS2 disc scans by serial, downloaded on the device | Images stay their owners' |
| [Fredoka](https://github.com/hafontia/Fredoka-One) | The app's font (`app/fonts/`) | SIL Open Font License 1.1 |
| [Godot Engine](https://godotengine.org) | Engine, and the Android plugin template the plugin started from | MIT |
| [Arrow](https://arrow-kt.io) | Typed functional programming in Kotlin | Apache 2.0 |
| [kotlinx.serialization, kotlinx.coroutines](https://github.com/Kotlin) | JSON storage, background work, and its tests | Apache 2.0 |
| [Kotest](https://kotest.io) | Property-based tests | Apache 2.0 |
| [JUnit 4](https://junit.org/junit4/) | Test runner | EPL 1.0 |
| [Robolectric](https://robolectric.org) | Android tests on the JVM | MIT |
| [GdUnit4](https://github.com/MikeSchulze/gdUnit4) | GDScript tests (downloaded by `dev/test_godot.sh`, not shipped) | MIT |
| [ktlint](https://pinterest.github.io/ktlint/) | Kotlin style | MIT |
| [Gradle](https://gradle.org) | Build, and the wrapper in `kotlin/` | Apache 2.0 |

## License

Cartouche is free software under the [GNU GPL v3 or later](LICENSE).
