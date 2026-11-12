# The debug bridge

A remote control for debugging and automation. A local client (a test harness, a screenshot script, a tuning
page) drives a running debug build over a WebSocket: it takes pictures, presses buttons, and changes lights,
poses, launch steps and timings live. It lives in `app/dev/bridge/`; nothing in the app depends on it, and a
release build holds none of it and starts none (INV-24, `app/test/dev/bridge/bridge_security_test.gd`).

- **Connecting.** A debug build started with `--bridge` connects to `ws://127.0.0.1:5201`; `--bridge-port=<n>`
  picks another port, so several builds can run side by side, each with its own packs folder under `user://dev/`.
  On a device, `adb reverse tcp:5201 tcp:5201` forwards the address to your computer.

  ```sh
  $GODOT --path app -- --bridge --bridge-port=5202
  ```

- **Protocol.** The first message, `hello`, carries the OS, the screen size and `protocol` (`PROTOCOL` in
  `app/dev/bridge/bridge.gd`), raised whenever a command or an answer changes shape.
- **Messages.** A request is a JSON object with `id`, `cmd` and the command's arguments; the answer keeps `id` and
  `cmd`, with `ok` or an `error`. Commands run in order (`app/dev/bridge/commands.gd`).
- **Privates.** The bridge may read private members of the app's classes. It is the one exception to the rule, and
  holds only because the bridge is debug-only.
- **Nothing is written.** Every change stays in memory. The bridge never writes the user's library, settings or
  labels; it writes only its own packs, under `user://dev/`.

## Commands

| Command | What it does |
|---|---|
| `state` | the route, screen, focus, selected console and game, frame timing, the video memory the engine holds (`video_mb`), pause state, the lights shown (`rig`); on the carousel, what it shows (below) |
| `shot` | a picture of the screen: `size`, `w` and `h`, followed by one binary PNG or JPEG message |
| `go {route}` | reloads the scene and plays the route's steps (`press`, `push`, `release`, `wait` in frames). A last step marked `hold` pauses on the first frame of what it started; a last `push` with `keep` holds its action. Fails if the scene does not settle. With `library: "adding"` it answers from `app/dev/bridge/route_fixture.gd`: two consoles, then the form adding a PS2 and placing it |
| `step {frames}` | while paused, advances processes, animation players and tweens one frame at a time |
| `pause`, `resume` | hold or release the tree, engine time and viewport input |
| `lifecycle {event, arrive}` | desktop only: `event` `pause` or `resume` sends the notification Android sends as the app is put aside or brought back. `arrive` (`gba:2`, as `--new-games`) has the next re-read of those consoles bring games. Answers `reading` |
| `scrub {t}` | samples the selected console's launch animation at a time and holds it |
| `reload {files}` | loads resources through an overlay pack, forgets their caches, reloads the scene and replays the route. Refuses scripts, fonts and files read only at start |
| `restart {files}` | prepares resources read only at start for the next start; the client restarts the process. Refuses scripts |
| `tune` | changes a value live (below) |
| `pick {x, y}` | the visible controls under a point, topmost first, and the console or medium under it |
| `sound {data, format, gain_db}` | plays base64 `wav` or `ogg` bytes once |
| `sounds {map}` | plays sounds as the app's input actions and screens happen |
| `snapshot` | the plugin's library and settings answers and the consoles' chosen models |
| `window {size}` | desktop: the window takes the shape of a `[width, height]` screen |

On the carousel, `state` also tells what shows of the parts each screen owns, by `app/dev/screen_agreement.gd`,
the rule the INV-20 walk asserts each time it settles:

| Field | Holds |
|---|---|
| `parts` | `still` (no screen in front, no move, launch or toss under way), `consoles` (`front` or `behind`), `consoles_behind_drawn`, whether `rail`, `console_title`, `games_logo`, `title_pill` and `games_hints` show, and `ribbon_open` |
| `disagreement` | what shows that the screen does not have, once still: empty when they agree |
| `badges` | the new games each console's rail tile announces, in the ring's order |
| `new_games` | `reading` (folders read again) and `waiting` (a library read again, not shown yet) |

| `tune` target | What it changes |
|---|---|
| a light index, `room` | a shown light, or the room's ambient energy |
| `pose` | the shown model's pose. An empty `values` only reads it, with what a pose editor needs to draw handles |
| `control`, `controls` | a Control's position, size, rotation, corner radius, colour or font size, one or a batch. `values: {"reset": true}` restores it |
| `turntable` | stands the plinth's live model at a start pose |
| `launch` | holds the carousel in a launch of the given steps at a time; `stop` ends the preview |
| `motion` | one of the timings `StudioTokens.LIVE` lists, until the app starts again |
| `speed` | the engine speed. `resume` and `go` reset it |
| `input` | holds or releases an input action |

Data files read once and cached (lights, turntable poses, plinth pictures, media poses) are listed in
`commands.gd`, which clears them on a live change. The plugin's catalog inputs and the platforms' tables load once:
they are outside live editing.

## A device's data on the desktop

`--snapshot=<directory>` makes `DesktopPlugin` read `snapshot.json` from that directory: a device's library,
settings and models as the `snapshot` command wrote them, with label images under the directory's files/art
folder. Changes stay in memory; the snapshot is never written. One not in that shape is refused with a `snapshot:`
trace.
