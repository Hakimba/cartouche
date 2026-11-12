# Adding a background

A background is drawn behind every screen and chosen on the settings card (Y, Background). It is one scheme of
the design's values. How a drawing follows the background: [architecture.md](architecture.md#studio).

A background has one key, in snake case, the same in three lists, in the same order (`backdrop_test.gd` ties them).
`device` is the one key without a scheme: it draws Light or Dark as the system's theme is.

| List | Gives | Where |
|---|---|---|
| the `Backdrop` enum of the core | the name stored and sent (its `@SerialName`) | `kotlin/core/src/main/kotlin/app/cartouche/core/settings/Settings.kt` |
| `StudioTokens.Scheme` and `StudioTokens.SCHEMES` | its values | `app/studio/studio_tokens.gd` (generated) |
| `Backdrop.NAMES` | its name on screen | `app/studio/backdrop.gd` |

## Steps

1. **Its values.** `studio_tokens.gd` is generated and never edited by hand. Start from the closest scheme of
   `SCHEMES`, change what differs, and propose the values in an issue or a pull request: the file is generated
   again with them. Another wall than `studio`, `mapped` or `black` needs shader work, to discuss first.

   | Values, as `Palette` reads them | Draw |
   |---|---|
   | `ink`, `mute`, `line`, `neutral` and the other colours | text, lines, the gel of no console, switches, arrows, shadows |
   | `looks` | the materials (satin, frost, key, plus, focus, plinth) |
   | `theme` | the project theme's items it changes |
   | `clear`, `room_light` | the viewport's clear colour, the consoles' room light |
   | `dark_logos` | whether a console's logo takes its `<console>.dark.png`, made for a dark ground |
   | `wall`, `wall_low`, `wall_high` | the wall: `studio` (the baked studio), `mapped` (its lightness mapped between two colours) or `black` |
   | `veil_base`, `veil_colours`, `veil_spread` | the pixel veil: the wall's mean colour, one to three colours, `pixels` or `waves` |
   | `operating_*` | the properties' operating light |

2. **The core.** One entry in the `Backdrop` enum, its `@SerialName` the key, in the same place as its scheme. Run
   `cd kotlin && ./gradlew :core:test :android:testDebugUnitTest`, then copy the `desktop.json` that
   `DesktopDemoTest` writes in the `kotlin/android` build folder to `app/dev/demo/desktop.json`.
3. **Its name.** One entry in `Backdrop.NAMES`, and the name in every `.po` file
   ([translating.md](translating.md#add-a-text-to-the-app)). The Background page shows a card per entry, drawn in
   its own scheme.
4. **Check.** `GODOT=$GODOT scripts/test_godot.sh res://test/studio res://test/screens`, then run the app with
   `--backdrop=<key>` and look at the consoles, a shelf, the settings and a game's properties, the pixel veil
   moving and still (`--pixel-veil=off`).
