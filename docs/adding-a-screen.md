# Adding a screen or a gesture

**You are here.** This page adds a screen in front of the carousel (a page, a form, a chooser, a confirmation), or
a gesture on the carousel (a press, a flick, a finger gesture), or changes what one does. Screens are GDScript
only: they draw, read input and play sounds. If the screen needs a rule of the domain or a stored value, that part
goes in the core first ([adding-a-setting.md](adding-a-setting.md) for a stored preference). The screens that
exist are listed in [architecture/godot.md](architecture/godot.md#the-screens).

## Before you start

Open an issue with a sketch of the screen: where it sits, what each button does, how you leave it. A new screen
changes how people use the app, so it is agreed before it is coded. A few rules every screen keeps:

- It is drawn on top of the existing screens, with the shared look of [architecture/studio.md](architecture/studio.md),
  never as a new kind of interface.
- Everything works with the pad. Touch is welcome too, but every finger gesture also has a button, and the focus
  is always visible.
- Targets are large enough for a thumb, and nothing hides at a screen edge.

Reuse before you make something new: `ChoiceScreen` and `CardChoiceScreen` choose a value among cards, and
`AddConsole` is the one form for adding and editing a console.

## A screen in front of the carousel

1. **Scene and script** under `app/screens/`. Build it from the Studio pieces (`SatinPanel`, `StudioText`,
   `ButtonHint` and others). Put its button hints in a `HintRow`. Unique-name (`%`) nodes become typed `@onready`
   members. Its places are px of the 1280 × 960 frame; on a screen of another shape each part stands on the stage, the
   top band or the bottom band, anchored as [adding-a-screen-format.md](adding-a-screen-format.md) says. Check it in
   a near-square, a 16:9 and a 21:9 window.
2. **Show it** from `ScreenFlow` (`app/screens/screen_flow.gd`) with `_show`, and await the signal that says it is
   done (`chosen` on a `ChoiceScreen`, for example). `ScreenFlow` decides which screen shows when; a screen never
   shows another by itself.
3. **Input** goes through InputMap actions (`app/project.godot`), never raw keys or buttons. Every action also has
   a keyboard key, so a desktop run and `adb shell input keyevent` can drive it. A confirms and B goes back.
4. **Focus.** Exactly one control has the focus while the screen shows. If the focus moves with directions, add the
   screen to the `SoundEffects.MOVES` group so each move plays its sound ([sounds.md](sounds.md)).
5. **Guards.** A screen that ignores presses while it moves (a tween under way, a save waiting) names that flag in
   `_GUARDS` of `app/test/screens/fixtures.gd`. Every guard is cleared on every path that ends it: a screen that
   stays disabled or faded is a dead screen.
6. **Shown again.** Everything the screen changes on itself (hints, focus, fades) is set again on every path that
   shows it, not only the first time.
7. **Text** goes through `tr()`, in every language of `app/locale/` ([translating.md](translating.md#add-a-text-to-the-app)).
8. **Sound.** A new gesture gets its cue ([sounds.md](sounds.md#adding-a-sound-to-a-gesture)).
9. **Traces.** `Diagnostics.trace("<area>", "<detail>")` at each step someone reading a log needs: which screen
   showed, what was chosen. Build the detail from the values the code decided on.

## A gesture on the carousel

The carousel reads input in `carousel.gd`: `_unhandled_input`, then `_handle_input`, whose branches run in order.
Finger gestures are read by `carousel_touch.gd` and `finger.gd`; a held direction by `held_direction.gd`.

- Add the new branch where it belongs in that order, and show its hint (a `ButtonHint` in `carousel.tscn`) only when
  the gesture applies.
- Something in flight (a game tossed, a launch under way) blocks presses and fingers until it ends. Name its busy
  state in `Fixtures.alive` (`app/test/screens/fixtures.gd`) so the walk of presses knows to wait for it.
- A finger never launches a game; only A does (INV-22).

## Resting

When nothing happens, the app stops drawing ([architecture/godot.md](architecture/godot.md#resting)). A new screen
must let it: once still, nothing writes to the renderer. Stop every tween and every `_process` that changes
nothing. Anything that moves on its own joins the `paced` group of `Resting`, so it slows to a stop with the rest.

## Tests

| Test | What it checks | Add |
|---|---|---|
| `app/test/screens/live_screen_test.gd` | a seeded walk of presses and fingers never leaves a dead screen (INV-20) | your guard flag in `_GUARDS`, your busy state in `Fixtures.alive` |
| `app/test/screens/at_rest_test.gd` | once still, a screen writes nothing to the renderer | one test for the new screen |
| `app/test/carousel/touch_test.gd`, `finger_test.gd` | fingers, and that no finger launches a game (INV-22) | the new finger gesture |
| `app/test/audio/gestures_test.gd` | what each gesture plays | the new gesture |
| `app/test/locale/locale_test.gd` | every text the app writes is in every language | nothing: it finds new texts itself |
| your feature's own test | what the screen does | one behaviour per test |

`app/test/screens/fixtures.gd` gives a fake plugin (`NewDevice`) and helpers to reach a screen (`carousel_for`,
`past_first_launch`, `on_form`). Drive time with `step_frame`, never real waits ([testing.md](testing.md#gdscript)).

```sh
GODOT=$GODOT scripts/test_godot.sh res://test/screens
```

If your new test file backs INV-20, list it in that row of [INVARIANTS.md](INVARIANTS.md).

## See it working

Run the desktop build and go through every way into the screen and out of it, with the pad (or keys) and with the
mouse as a finger:

```sh
$GODOT --path app -- --welcome=skip
```

To script it, start the build with `--bridge` and drive it with the debug bridge
([debug-bridge.md](debug-bridge.md)): `go` plays a route of presses, `state` says which screen the app shows
(the screen node's name in snake case) and what each part of it shows, and `shot` takes a picture. Put a screenshot
or a short clip in your pull request.

## Docs

Add the screen to the table of [architecture/godot.md](architecture/godot.md#the-screens), new words to
[GLOSSARY.md](GLOSSARY.md), and a line to `CHANGELOG.md` under Unreleased.

## Neighbours

- [architecture/godot.md](architecture/godot.md): the screens, the carousel, resting.
- [architecture/studio.md](architecture/studio.md): the pieces every screen is built from.
- [sounds.md](sounds.md), [translating.md](translating.md): a screen's sounds and texts.
- [testing.md](testing.md#gdscript): the GDScript tests and their helpers.
- Back to the entry: [README.md](README.md).
