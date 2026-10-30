# The debug bridge

**You are here.** The bridge is a remote control for debugging and automation. A local client (a test harness, a
screenshot script, a tuning page) drives a running debug build over a WebSocket: it takes pictures, presses
buttons, and changes lights, poses, launch steps and timings live. It lives in `app/dev/bridge/`, depends on the
app's classes, and nothing in the app depends on it. A release build holds none of it and starts none (INV-24).

## Connecting

A debug build started with `--bridge` connects to `ws://127.0.0.1:5201`. `--bridge-port=<n>` picks another port,
so several clients can run side by side on a desktop, each with its own packs folder under `user://dev/`. Without
the flag the app adds no bridge node and opens no connection.

```sh
$GODOT --path app -- --bridge --bridge-port=5202
```

The bridge's first message, `hello`, carries the OS, the screen size and `protocol` (`PROTOCOL` in
`app/dev/bridge/bridge.gd`). The protocol number goes up whenever a command or an answer changes shape, so a client
can refuse an app it does not know.

`Diagnostics` loads the bridge by path. The export filter (`app/addons/cartouche_dev/export_filter.gd`) leaves
`app/dev/bridge/` out of release exports, and `dev/check_release.sh` inspects a real release pack to prove it.

The bridge may read private members of the app's classes (the carousel's screen, a launch's stage, a view's
tweens). That is the one exception to the rule that no class reaches into another's privates, and it holds only
because the bridge is debug-only.

## Messages

A request is a JSON object with `id`, `cmd` and the command's arguments. The answer keeps `id` and `cmd`, with `ok`
or an `error`. `shot` answers with `size`, `w` and `h`, followed by one binary PNG or JPEG message. Commands run in
order, including the ones that wait for frames. `app/dev/bridge/commands.gd` dispatches them.

| Command | What it does |
|---|---|
| `state` | the route, screen, focus, selected console and game, frame timing, pause state, and the lights shown (`rig`) |
| `shot` | a picture of the screen |
| `go {route}` | reloads the scene and plays the route's steps (`press`, `push`, `release`, `wait` in frames), faster than recorded except while a direction is held. A last step marked `hold` pauses on the first frame of what it started. A last `push` with `keep` holds its action. Fails if the scene does not settle. |
| `step {frames}` | while paused, advances processes, animation players and tweens one frame at a time |
| `pause`, `resume` | hold or release the tree, engine time and viewport input |
| `scrub {t}` | samples the selected console's launch animation at a time and holds it |
| `reload {files}` | loads resources through an overlay pack, forgets their caches, reloads the scene and replays the route |
| `restart {files}` | prepares resources read only at start for the next start (a start pack in the instance's folder). The client restarts the process. |
| `tune` | changes a value live: see below |
| `pick {x, y}` | the visible controls under a point, topmost first, and the console or medium under it |
| `sound {data, format, gain_db}` | plays base64 `wav` or `ogg` bytes once |
| `sounds {map}` | plays sounds as the app's input actions and screens happen, without changing what the app does |
| `snapshot` | the plugin's library and settings answers and the consoles' chosen models |

`reload` and `restart` refuse scripts: the engine compiles every script a scene names before any of it runs, so no
pack can replace one. `reload` also refuses fonts and files read only at start.

### Tune targets

| `target` | What it changes |
|---|---|
| a light index, `room` | a shown light (in the rig's model-centred coordinates), or the room's ambient energy |
| `pose` | the shown model's pose. An empty `values` only reads it, with the camera and transforms a pose editor needs to draw handles. |
| `control`, `controls` | a Control's position, size, rotation, corner radius, colour or font size, one or a batch. A batch checks every target before changing any. `values: {"reset": true}` restores the control as it was. |
| `turntable` | stands the plinth's live model at a start pose |
| `launch` | holds the carousel in a launch of the given steps at a time. With `handles`, also where each moving piece stands on screen. `stop` ends the preview. |
| `motion` | one of the timings `StudioTokens.LIVE` lists, until the app starts again |
| `speed` | the engine speed. `resume` and `go` reset it. |
| `input` | holds or releases an input action |

Every change stays in memory. The bridge never writes the user's library, settings or labels (INV-24). It writes
only its own packs, under `user://dev/`.

## Running on a device's data

On a desktop debug build, `--snapshot=<directory>` makes `DesktopPlugin` read `snapshot.json` from that directory: the
library, settings and models of a device, with label images under the directory's files/art folder. Changes to
settings and models stay in memory, and the snapshot is never written.

## Caches

Some data files are read once and cached. `commands.gd` lists the ones a live change must clear: lights,
turntable poses, plinth pictures, media poses. Console and medium manifests are Godot resources, replaced before
the scene reloads. The plugin's catalog inputs load once at start and are outside live editing.

## Previewing the add-console route

A `go` route with `library: "adding"` answers from `app/dev/bridge/route_fixture.gd` instead of the plugin: two
consoles, then the real form adding a PS2 and placing it on the ring. Everything stays in memory.

## Tests

`app/test/dev/bridge/bridge_security_test.gd` carries INV-24: the export filter drops every bridge file in a release
build, no bridge starts without the flag or outside debug, and `reload`, `restart` and `snapshot` write only beneath
the dev folder.

## Neighbours

- [architecture/godot.md](architecture/godot.md#developer-tools-in-the-app): the other tools in the app.
- [architecture/studio.md](architecture/studio.md): the timings, poses and lights the bridge tunes.
- [testing.md](testing.md): the tests a harness on the bridge complements.
- Back to the entry: [ONBOARDING.md](ONBOARDING.md).
