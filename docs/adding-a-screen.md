# Adding a screen or a gesture

A screen in front of the carousel (a page, a form, a chooser, a confirmation), a gesture on the carousel (a
press, a flick, a finger gesture), or a change of what one does. Screens are GDScript only; a rule of the domain or
a stored value goes in the core first ([adding-a-setting.md](adding-a-setting.md)).

Open an issue with a sketch first: where the screen sits, what each button does, how you leave it. Every screen:

- is drawn in front of the existing screens, with the Studio pieces ([architecture.md](architecture.md#studio));
- works wholly with the pad, the focus always visible; every finger gesture also has a button, and what a button
  does a finger can do too (a tap on a card or a button, a drag along a ring, a tap beside a level);
- has targets large enough for a thumb, and nothing at a screen edge;
- reuses what exists: `ChoiceScreen` and `CardChoiceScreen` choose a value among cards, `AddConsole` is the one
  form adding and editing a console.

## A page in front of the carousel

1. **Scene and script** under `app/screens/`. Its button hints go in a `HintRow`; a finger lifted on a hint shown
   whole presses its button (`ButtonHint`), so a press only a hint offers is in a finger's reach too. Its places are px of the
   1280 × 960 frame, anchored as [Screens of every shape](#screens-of-every-shape) says.
2. **Extend `Page`** (`app/screens/page.gd`). `_open(request)` fills the page and gives one control the focus; it
   runs each time the page shows, so everything the page changes on itself (hints, focus, fades) is set again
   there. The page answers with `done.emit(result)`.
3. **Show it** from `ScreenFlow` (`app/screens/screen_flow.gd`) with `await _present(page, request)`, which returns
   the page's answer. `ScreenFlow` decides which page shows when; a page never shows another.
4. **Guard it.** A page takes no press while something it started runs: wrap that work in
   `Page.busy_while(work)` (`ScreenFlow` holds the presses of a page `ENTERING` or `BUSY`). Every phase that stops
   presses must end on every path, or the screen is dead. A settings' choice page saving its value is held so by
   `ScreenFlow._save_held`, and B lets it go once the save has lasted two seconds, the save going on; a game's
   properties hold theirs the same way while the plugin answers (`DiscProperties._asking`).
5. **Input** goes through InputMap actions (`app/project.godot`), never raw keys or buttons. A confirms, B goes
   back.
6. **Focus sounds.** If the focus moves with directions, add the page to the `SoundEffects.MOVES` group
   ([sounds.md](sounds.md)).
7. **Text** through `tr()`, in every language ([translating.md](translating.md#add-a-text-to-the-app)).
8. **Traces.** `Diagnostics.trace("<area>", "<detail>")` at each step someone reading a log needs.
9. **Rest.** Once still, nothing writes to the renderer: stop every tween and every `_process` that changes
   nothing; what moves on its own joins the `paced` group ([architecture.md](architecture.md#resting)).

## A gesture on the carousel

`carousel.gd` carries out what `CarouselState.command` says a press means; its rules are tried in order. Finger
gestures are read by `carousel_touch.gd` and `finger.gd`, a held direction by `held_direction.gd`.

1. Add a `Command` to `CarouselState`, its rule in `command` where it belongs in the order, and its line in
   `_handle_input` of `carousel.gd`.
2. Add its row to `carousel_state_test.gd`.
3. Show its hint (a `ButtonHint` in `carousel.tscn`) only when the gesture applies.
4. Give it its cue ([sounds.md](sounds.md#adding-a-sound-to-a-gesture)).
5. If it starts something in flight that blocks presses, name that busy state in `Fixtures.alive`
   (`app/test/screens/fixtures.gd`).

A finger never launches a game; only A does (INV-22).

## Tests

| Test | Checks | Add |
|---|---|---|
| `app/test/screens/live_screen_test.gd` | no dead screen and never the wrong one (INV-20) | the rows and names [the walk](testing.md#the-walk) needs |
| `app/test/screens/at_rest_test.gd` | once still, a screen writes nothing to the renderer | one test for the new screen |
| `app/test/carousel/touch_test.gd`, `finger_test.gd` | fingers, and that none launches a game | the new finger gesture |
| `app/test/audio/gestures_test.gd` | what each gesture plays | the new gesture |
| `app/test/locale/locale_test.gd` | every text is in every language | nothing: it finds new texts itself |
| the feature's own test | what the screen does | one behaviour per test; if it backs INV-20, list it in that row of [INVARIANTS.md](INVARIANTS.md) |

```sh
GODOT=$GODOT scripts/test_godot.sh res://test/screens
$GODOT --path app -- --welcome=skip          # then every way into the screen and out, pad and mouse as a finger
```

To script the check, drive the build with the [debug bridge](debug-bridge.md): `go` plays a route of presses,
`state` says which screen shows, `shot` takes a picture. Put a screenshot or a clip in the pull request, new words
in [GLOSSARY.md](GLOSSARY.md), and a line in `CHANGELOG.md` under Unreleased.

## Screens of every shape

Cartouche is drawn in px of a 1280 × 960 frame. Godot's stretch keeps that frame whole on any screen: a wider
screen is 960 px high and wider, a narrower one 1280 px wide and taller. `ScreenLayout`
(`app/studio/screen_layout.gd`) says where each part goes; nothing else reads the screen's shape.

| Place | What | How it is set out |
|---|---|---|
| The stage | the consoles and games (3D), the cards and forms, the ring, the properties | the frame, in the middle of the screen. A node is anchored on the screen's centre both ways, its offsets the frame's px minus (640, 480). The 3D camera is aimed by `StageLens.aim` |
| The top band | clock, battery, "+", the games' logo | anchored on the top: left edge, middle or right edge |
| The bottom band | the consoles rail, the hints, the search ribbon, messages | anchored on the bottom, offsets the frame's px minus 960 |

- Code placing a node from frame px uses `ScreenLayout.at(get_viewport())`: `on_stage`, `top`, `bottom`,
  `spare_width`. It never reads the viewport's size.
- A window can change shape while a screen is open. A screen that animates its parts keeps their rests with
  `Rests` (`app/studio/rests.gd`), as offsets from their anchors; a measure taken in screen px is kept on the
  stage (`from_stage`); a view copying the carousel's camera copies it again on `size_changed`, deferred.
- A camera that draws a part of the picture again (a medium's view, the ring's console, the blur behind the games)
  copies or narrows the carousel's camera with `StageLens`, never its own projection.
- On a wider screen the rows show more at the same size: `ConsoleRail._fit_width`, `ShelfRow._fit_width`.

The families of screens are data, `app/data/screen_formats.json`: each one's name, the widest shape it covers
(`up_to`, width for a height of 1; the last has none) and its values, a value left out being the 4:3 one.

| Value | Meaning |
|---|---|
| `shelf_level` | the games past the selected one's neighbours stand at the neighbours' height, so a wide screen shows them; otherwise they go on down the shelf's arc |

To add a family, add an entry. To add a value, add it to `ScreenLayout.Format` with the 4:3 default, read it where
it applies, and add a line to this table.

Check every screen you touched in a near-square (1240 × 1080), a 4:3, a 16:9 and a 21:9 window: `--resolution
1920x1080` before `--`, or the debug bridge's `window {size}`. `app/test/studio/screen_layout_test.gd` lays out a
screen of each family.
