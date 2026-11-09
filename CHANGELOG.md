# Changelog

Every release of Cartouche, newest first. Versions follow [Semantic Versioning](https://semver.org); the format
follows [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

## [0.4.1] - 2026-11-09

### Fixed
- Moving from one console to another no longer shows both of them half see-through, one inside the other: the
  console left is gone at once and the one reached slides in, whole, from the side.

## [0.4.0] - 2026-11-07

### Added
- Games copied into a console's folder show up on their own: each time Cartouche opens or comes back to the screen,
  it reads the folders again, adds the new games and takes away the ones deleted. A console that got new games carries
  a "+N" badge on the consoles screen until you go into it, and each new game a small glowing dot until you move past
  it. Adding or editing a console marks nothing as new.
- **Add a console** lists the consoles on their way, greyed, with a note: "Coming soon: not fully supported yet". They
  cannot be added until they are.
- The Mega Drive's model 2 is offered beside model 1, greyed like the consoles on their way until its launch is made.
- The PS Vita and the Nintendo DS Lite are modelled, with their logos and colours, and listed greyed as coming soon
  until their launch and their game cards are made.
- Contributors get `CONTRIBUTING.md`, a first-contribution page and a guide for each kind of addition (console,
  medium, launch animation, platform, setting, background, screen), with `scripts/new_console.py` and
  `scripts/new_medium.py` to set one up: a console without moving parts, a disc or a plain cartridge needs no code.

### Changed
- Cartouche starts about half a second sooner: the consoles and cartridges once built by code at every start are now
  ready-made models, and each console's game lists (titles, cartridge prints, label sources) are read only when that
  console needs them, off the screen's thread. They look and move exactly as before.
- A hidden diagnostics screen (Select held for two seconds) is gone.
- Adding a disc console is several times faster: a first scan reads a few kilobytes of each CHD instead of megabytes,
  three files at a time (59 PlayStation 2 games: about 0.6 s instead of 3 s).
- Cartouche asks less of the graphics card for the same picture: the games screen at rest about half as much,
  scrolling with fewer stutters, and **Add a console** draws a console's stand only where a fast scroll stops.
- While a game runs, Cartouche keeps on the graphics card only the labels of the games on screen, and a label drawn
  by Cartouche holds its picture only while it is shown, leaving more memory to the emulator. Coming back shows the
  same labels.
- Cartouche no longer declares the "All files access" permission, which it never used: games are read through the
  folders picked when a console is added.

### Fixed
- Games kept in `.zip` or `.7z` archives start with Snes9x EX+, GBC.emu, GBA.emu and NES.emu, which open them: they
  were listed on the shelf, then refused with "No emulator is installed". These emulators, the My Boy! and
  My OldBoy! apps, Nesoid and Mupen64Plus are shown under their names instead of their Android package; Dolphin also
  takes `.wia` disc images, and FPse no longer offers `.chd` images, which it cannot open.
- The console list of "+" groups the consoles under their maker: the Super Nintendo was last, after Sony's.
- A name such as "Snes9x" keeps its "x": the app's font drew a multiplication sign after a digit.
- Cartouche fits screens of every shape, from near-square handhelds to 32:9 monitors: a wider screen shows more
  consoles in the bar and more games on the shelf at the same size, a taller one keeps the bar and the hints at the
  bottom and the console in the middle, and every screen, form and launch stands where it does on a 4:3 screen.
  When every console fits in the bar, the bar stands centred and whole and the selection frame moves along it. A
  window that changes shape while a screen is open keeps that screen laid out for its new shape.
- The hints at the bottom of the games screen and the console's logo now leave with the rest while a game is launched.
- A button style that could not be saved no longer stays in use until Cartouche closes.

## [0.3.0] - 2026-11-05

### Added
- A **Background** setting: Light, Dark (pure black, for OLED screens), Light grey, Anthracite, or Like the device,
  which follows your system's light or dark theme. Each one is shown on its card, and the one you choose shows at once
  on every screen. On the dark backgrounds the console logos take versions made for a dark ground.
- An **Animated background** switch, on by default: a veil of pixels drifts behind the screens, in colours made for
  each background, and keeps drifting while Cartouche rests. Turned off, a resting screen is drawn no more, as before.
- **↑ Random** on the games screen, or a flick up from the game in the middle: the game is tossed like a coin and lands
  as another game of the list shown (of the search's results, while one is on), drawn at random, with a soft sound of
  its own as it leaves and as it lands.

### Changed
- **X Edit** on a console opens its form, the same as the one adding a console: change its folder, emulator and
  options, pick its model among swatches while the console beside them changes as it will stand on the ring, or
  remove it ([#3](../../issues/3), [#6](../../issues/6), thanks @kafka-esq and @kirillov1370). On a game the hint
  reads **Edit** too.

### Removed
- **Platforms** in the settings: each console is edited or removed from the ring.

### Fixed
- Closing the settings on the consoles screen no longer shows the games screen's **Search** hint over **Arrange**
  ([#2](../../issues/2), thanks @kafka-esq).

## [0.2.0] - 2026-10-31

### Added
- Seven languages: English, French, German, Spanish, Italian, Portuguese (Portugal and Brazil) and Japanese,
  following your device's until you pick one on the new **Language** page of the settings.
- The settings card scrolls, with arrows you can touch.

### Changed
- The README shows Cartouche at work, with short clips of each screen.

### Fixed
- Cartouche follows your device when it is turned around, in both landscape directions, so it is no longer upside
  down on a phone held in a controller that plugs in on the other side
  ([#1](../../issues/1), thanks @mrwohoo).
- A launch you gave up on, by leaving the carousel before the game started, no longer starts its game later.
- A label you chose for a game is never replaced or deleted by a download planned just before.

## [0.1.0] - 2026-10-30

The first release: a carousel of 3D consoles, each console's games on their real discs and cartridges, launched in
the emulators you already have. NES, Super Nintendo, Nintendo 64, GameCube, Wii, Game Boy, Game Boy Color,
Game Boy Advance, PlayStation, PlayStation 2, Xbox and Xbox 360; labels from ScreenScraper and LaunchBox; filters,
a wheel to order your consoles, renaming; controller and touch; English and French.

[0.4.1]: ../../compare/v0.4.0...v0.4.1
[0.4.0]: ../../compare/v0.3.0...v0.4.0
[0.3.0]: ../../compare/v0.2.0...v0.3.0
[0.2.0]: ../../compare/v0.1.0...v0.2.0
[0.1.0]: ../../releases/tag/v0.1.0
