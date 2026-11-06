# Screens of every shape

Cartouche is drawn in px of a 1280 × 960 frame, the shape of a 4:3 handheld. Godot's stretch (`canvas_items`,
`expand`) keeps that frame whole on any screen: a wider screen is 960 px high and wider, a narrower one 1280 px wide
and taller. `ScreenLayout` (`app/studio/screen_layout.gd`) says where each part of a screen goes on such a screen, and
how much more it can show. Nothing else in the app reads the screen's shape.

## Three places

| Place | What | How it is set out |
|---|---|---|
| The stage | the consoles and games (3D), the cards and forms, the ring, the properties | the frame in the middle of the screen, at its size. A node is anchored on the screen's centre both ways, its offsets the frame's px minus (640, 480). The 3D camera is aimed by `StageLens.aim`, so the 3D stands on the stage too |
| The top band | clock, battery, "+", the games' logo | anchored on the top: on the left edge, the middle or the right edge |
| The bottom band | the consoles rail, the hints, the search ribbon, messages | anchored on the bottom (`anchor_top = anchor_bottom = 1`, offsets the frame's px minus 960) |

On a 4:3 screen the three are the frame itself: nothing moves. Code that places a node from frame px uses
`ScreenLayout.at(get_viewport())`: `on_stage`, `top`, `bottom`, `spare_width`; it never reads the viewport's size
itself.

A window can change shape while a screen is open (a desktop window, a foldable, split screen). A screen that animates
its parts keeps their rests with `Rests` (`app/studio/rests.gd`), as offsets from their anchors, never as positions
read once; a measure taken in screen px (a silhouette) is kept on the stage (`from_stage`); a view that copies the
carousel's camera copies it again on `size_changed`, deferred so that the carousel's camera has followed first.

## Showing more

On a wider screen the rows show more of themselves at the same size: the consoles rail reaches half the
`spare_width` more on each side, in slots of its `PITCH` (`ConsoleRail._fit_width`), its fade toward the edges opened
as far; once every console fits, the ring becomes a still strip centred on the screen, shown whole, and the frame moves
along it. The games shelf draws further (`ShelfRow._fit_width`). A camera that draws a part of the picture again (a medium's own view, the ring's console,
the blur behind the games) copies or narrows the carousel's camera with `StageLens`, never with its own projection.

## Changing a family of screens, or adding one

The families are data, `app/data/screen_formats.json`: each one's name, the widest shape it covers (`up_to`, width for
a height of 1; the last has none) and its values. A value left out is the 4:3 one.

| Value | Meaning |
|---|---|
| `shelf_level` | the games past the selected one's neighbours stand at the neighbours' height, so that a wide screen shows them; otherwise they go on down the shelf's arc, out of the screen |

To add a family, add an entry with its `up_to` and the values that differ. To add a value, add it to
`ScreenLayout.Format` with the 4:3 default, read it where it applies, and add a line here.

## Checking

- `app/test/studio/screen_layout_test.gd` lays out a screen of each family: the stage whole, the bands on their edges,
  the 3D on the stage at every depth.
- On the desktop, a debug build's window takes any screen's shape with the debug bridge's `window {size}` command
  (see [debug-bridge.md](debug-bridge.md)), or start it with `--resolution 1920x1080` (a Godot argument, before
  `--`). Look at every screen you touched in a near-square (1240 × 1080), a 4:3, a 16:9 and a 21:9 shape.
