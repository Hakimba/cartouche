# Adding a background

**You are here.** A background is drawn behind every screen and chosen on the settings card (Y, Background):
Light, Dark, Light grey, Anthracite, or Like the device. Each one is a scheme of the design's values: its colours,
its materials, the project theme's items it changes, its wall, its pixel veil and the properties' light. How a
drawing follows the background is in [architecture/studio.md](architecture/studio.md#backgrounds).

## The contract

A background has one key, in snake case, the same in three lists that `backdrop_test.gd` ties, in the same order:

| List | What it gives | Where |
|---|---|---|
| `Backdrop` enum of the core | the name stored and sent (its `@SerialName`) | `kotlin/core/src/main/kotlin/app/cartouche/core/settings/Settings.kt` |
| `StudioTokens.Scheme` and `StudioTokens.SCHEMES` | its values, at the same index | `app/studio/studio_tokens.gd` (generated) |
| `Backdrop.NAMES` | its name on screen | `app/studio/backdrop.gd` |

`device` is the one key without a scheme: it draws Light or Dark as the system's theme is.

A scheme's values, as `Palette` (`app/studio/palette.gd`) reads them:

| Values | What they draw |
|---|---|
| `ink`, `mute`, `line`, `neutral` and the other colours | text, lines, the gel of no console, switches, arrows, shadows |
| `looks` | the materials (satin, frost, key, plus, focus, plinth), as `LOOKS` gives Light's |
| `theme` | the project theme's items it changes (buttons, labels, pills, bars) |
| `clear`, `room_light` | the viewport's clear colour, the consoles' room light |
| `dark_logos` | whether logos take their picture made for a dark background |
| `wall`, `wall_low`, `wall_high` | the wall: `studio` (the baked studio), `mapped` (its lightness mapped from the low to the high colour) or `black` (`cyclorama.gd`) |
| `veil_base`, `veil_colours`, `veil_spread` | the pixel veil: the wall's mean colour, one to three colours, `pixels` (one colour per pixel) or `waves` (`pixel_veil.gdshader`) |
| `operating_*` | the properties' operating light |

## Steps

1. **Its values.** `studio_tokens.gd` is generated from the design's tokens and never edited by hand (a test fails
   on a hand edit). Start from the closest scheme of `SCHEMES`, change what differs, and propose the values in an
   issue or a pull request: the file is generated again with them. Another wall than `studio`, `mapped` or `black`
   needs shader work, to discuss first.
2. **The core.** One entry in the `Backdrop` enum, its `@SerialName` the key, in the same place as its scheme. Run
   `cd kotlin && ./gradlew :core:test :android:testDebugUnitTest`, then copy the `desktop.json` that `DesktopDemoTest`
   writes in the `kotlin/android` build folder to `app/dev/demo/desktop.json`: the desktop's settings now offer it.
3. **Its name.** One entry in `Backdrop.NAMES`, and the name in every `.po` file
   ([translating.md](translating.md#add-a-text-to-the-app)). The Background page shows a card for every entry,
   drawn in its own scheme (`backdrop_card.gd`).
4. **Logos.** With `dark_logos`, a console whose logo has a picture made for a dark background shows it.
5. **Check.** `scripts/test_godot.sh res://test/studio res://test/screens` (`backdrop_test.gd` ties the three
   lists, `tokens_test.gd` the generated file). Then run the app on the desktop with `--backdrop=<key>` and look
   at the consoles, a shelf, the settings and a game's properties, with the pixel veil moving and still
   (`--pixel-veil=off`).

## Neighbours

- Backgrounds, palettes and the theme: [architecture/studio.md](architecture/studio.md#backgrounds).
- The settings card: [adding-a-setting.md](adding-a-setting.md).
