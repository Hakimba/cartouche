# Changelog

Every release of Cartouche, newest first. Versions follow [Semantic Versioning](https://semver.org); the format
follows [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Added
- Games copied into a console's folder show up on their own: each time Cartouche opens or comes back to the screen,
  it reads the folders again, adds the new games and takes away the ones deleted. A console that got new games carries
  a "+N" badge on the consoles screen until you go into it, and each new game a small glowing dot until you move past
  it. Adding or editing a console marks nothing as new.
- **Add a console** lists the consoles on their way, greyed, with a note: "Coming soon: not fully supported yet". They
  cannot be added until they are.

### Fixed
- The hints at the bottom of the games screen and the console's logo now leave with the rest while a game is launched.

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

[0.3.0]: ../../compare/v0.2.0...v0.3.0
[0.2.0]: ../../compare/v0.1.0...v0.2.0
[0.1.0]: ../../releases/tag/v0.1.0
