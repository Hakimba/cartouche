# The Studio look (`app/studio`)

**You are here.** Studio is the look every screen shares: each screen is a small lit photo studio, its pieces in
two materials (opaque satin, translucent frost) under the same light, its text in Plus Jakarta Sans and IBM Plex
Mono. This page lists the one piece to use for each need. It depends only on Godot. The screens, the carousel and
the properties ([godot.md](godot.md)) all draw with it.

Use the piece listed here rather than a new one: one idiom per need keeps every screen alike.

## Values

`StudioTokens` (`app/studio/studio_tokens.gd`) holds every colour, size, font role and timing the design uses. It
is generated from the design's tokens and never edited by hand: the file carries the hash of its own text, and
`tokens_test.gd` fails on a hand edit. Ask in an issue for a value to change.

- `StudioTokens.GEL` gives each console folder its colour (its gel). `ConsoleManifest.gel_of(folder)` reads it, a
  missing entry giving the neutral colour. `tokens_test.gd` checks every supported console has one.
- `StudioTokens.LIVE` lists the timings that are `static var`s, read each time a tween starts, so the debug bridge
  can try other values on a running app ([../debug-bridge.md](../debug-bridge.md)).
- `StudioTokens.CONTROL_EDITS` and `CONTROL_STYLES` hold saved per-control overrides, which `ControlTokens`
  (`control_tokens.gd`) applies when a matching control appears. With no record it does nothing.

## Pieces

| Need | Use | File |
|---|---|---|
| A material behind a container | `SatinPanel`, its `look` a `StudioMaterial.Look` (`SATIN`, `FROST`, `KEY`, `PLUS`, `FOCUS`) | `satin_panel.gd`, `studio_material.gd` |
| A material behind pieces a control draws itself | `SatinPanel.Backing`, placed on a box | `satin_panel.gd` |
| A material on Godot's own buttons, fields, cards | `SatinStyle`, the same material as a StyleBox (`SatinStyle.apply_to`) | `satin_style.gd` |
| The focus card | the theme's focus StyleBox, its ring in the gel | `app/studio/focus.tres`, `app/carousel/carousel_theme.tres` |
| The backdrop | `Cyclorama`: a baked picture of the wall and floor, the key light over it. Nothing moves, so nothing redraws. | `cyclorama.gd` |
| Button hints | `ButtonHint` children of the one `HintRow`, never a row of their own | `hint_row.gd`, `app/screens/button_hint.gd` |
| A line of text at the design's exact width | `StudioText.of(role, text)`, then `fit(room)` and `draw(canvas, at, color)` | `studio_text.gd` |
| A theme label or button in a tracked role | `StudioLabel`, `StudioNameButton`, through `TrackedText` | `studio_label.gd`, `studio_name_button.gd`, `tracked_text.gd` |
| One line on a frost pill | `StudioPill` | `studio_pill.gd` |
| A console's logo | `LogoView.show_logo(LogoView.Slot.RAIL_TILE, folder)`, one picture made per slot | `logo_view.gd` |
| A console's still picture | `Plinth.request_still(folder, done)`: rendered once per model in a throw-away viewport, kept for the app's life | `app/studio/views/plinth.gd` |
| Lights designed for a model and screen | `StudioLights.rig_of(model, screen)`, read from `app/data/studio_lights.json` | `app/studio/views/studio_lights.gd` |

Godot's theme labels draw at whole sizes and whole-pixel spacing, so a long tracked line drifts from the design.
Text that must keep the design's width (a title, a note, a count) draws through `StudioText`.

## Motion

`Motion` (`motion.gd`) is the one way Studio screens move.

- `Motion.Spring`: presses move its `target`, and `step(delta)` follows until it rests.
- `Motion.curve(Motion.Easing.EASE)` is a tween's `set_custom_interpolator`. `Motion.eased` gives a curve's value.
  Use these rather than Godot's own transition types.
- `Motion.restart(node, old)` kills a running tween and makes the next. `Motion.animate` plays one named motion of
  a set.
- `Motion.phase` gives where a step of a longer move stands at a time.

## Screens built on these pieces

| Folder | What it holds |
|---|---|
| `app/studio/rail/` | `ConsoleRail` and `RailTile`: the ring of console logos under the posed console on the consoles screen. |
| `app/studio/ring/` | `RingFit`, the ordering ring's size rule, pure; `Placing`, the state machine of placing a console just added among the others, pure. |
| `app/studio/chooser/` | `StudioChooser`: the console and emulator choosers of the add-console form, the chosen console on its plinth. |
| `app/studio/transitions/` | `FormEntry` (the "+" button to the form), `ConsoleArrival` (a console flying from the form to its place), `LogoFlight` (two logos crossfading in flight). |
| `app/studio/views/` | `MediaView` (one medium of the games row, softened by its distance from the centre), `Plinth`, `StudioLights`. |
| `app/studio/games/` | See below. |

### The games screen

`GamesLayout` (`app/studio/games/games_layout.gd`) gives the games row's poses. The selected game's pose per medium
is data, `app/data/media_poses.json`. `TitlePlace` measures where the title goes from the medium's own vertices,
and `GameTitlePill` draws the title, with the ribbon's matches underlined. `ShelfRow`
([godot.md](godot.md#the-carousel)) recycles the places, each drawing its game through one `MediaView`.

### Poses and lights are data

Three data files hold what is tuned by eye rather than computed. A missing entry gives a default.

- `app/data/turntable.json`: each console's start pose on the plinth.
- `app/data/studio_lights.json`: the lights designed for each model and screen.
- `app/data/media_poses.json`: each medium's pose on the games screen.

The first two say they are generated: they are written by a tuning tool through the debug bridge, not by hand.

## Tests

`dev/test_godot.sh res://test/studio` runs this folder's tests. `fonts_test.gd` compares the drawn text with a
reference and needs a window, so the headless run skips it. Run it alone:

```sh
$GODOT --path app -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test/studio/fonts_test.gd
```

## Neighbours

- [godot.md](godot.md): the screens and the carousel that draw with these pieces.
- [../debug-bridge.md](../debug-bridge.md): trying other timings and poses on a running app.
- [../testing.md](../testing.md#gdscript). Back to the entry: [../ONBOARDING.md](../ONBOARDING.md).
