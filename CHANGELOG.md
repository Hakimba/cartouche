# Changelog

Every release of Cartouche, newest first. Versions follow [Semantic Versioning](https://semver.org); the format
follows [Keep a Changelog](https://keepachangelog.com).

## [Unreleased]

### Added
- A **Background** setting: Light, Dark (pure black, for OLED screens), Light grey, Anthracite, or Like the device,
  which follows your system's light or dark theme. Each one is shown on its card, and the one you choose shows at once
  on every screen. On the dark backgrounds the console logos take versions made for a dark ground.
- An **Animated background** switch, on by default: a veil of pixels drifts behind the screens, in colours made for
  each background, and keeps drifting while Cartouche rests. Turned off, a resting screen is drawn no more, as before.
  A second switch, **In the console's colour**, off by default, gives the veil the colour of the console shown.
- **↑ Random** on the games screen, or a flick up from the game in the middle: the game is tossed like a coin and lands
  as another game of the list shown (of the search's results, while one is on), drawn at random.

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

[0.2.0]: ../../compare/v0.1.0...v0.2.0
[0.1.0]: ../../releases/tag/v0.1.0
