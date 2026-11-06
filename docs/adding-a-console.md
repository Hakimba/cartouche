# Adding a console

**You are here.** A console model is one folder under `app/carousel/consoles/`. The app finds it by its folder,
shows it on the consoles screen, and plays its launch animation when a game goes in. The consoles screen, the
ordering ring, the plinth and the launch read it ([architecture/godot.md](architecture/godot.md#consoles)). Its disc
or cartridge is a medium, with its own page: [adding-a-medium.md](adding-a-medium.md).

A console drawn from a downloaded 3D model (a glb) is data: a manifest, a scene and a shape, and no code. Its moving
parts, once it has a launch animation, are data too. Code is only for what data cannot say.

## In short

1. Prepare the model: one glb at its real size, in metres, X to the right, Y up, Z out of its front, its moving parts
   as nodes of their own with their origin on their pivot, under the triangle budget (about 10 000 for a home
   console). Its licence must allow it: CC-BY-4.0, as every model the app ships.
2. Run the scaffold:

   ```sh
   scripts/new_console.py megadrive2 --platform genesis --glb megadrive2.glb --version mk-1631 \
     --name "Mega Drive" --model-name "Model 2" --licence license.txt --variant-of megadrive
   ```

3. Fill the values it prints (the seat, the way in), `git add` the new files, import, run the tests.
4. Open a pull request. The console shows greyed, as coming, until its launch animation and its medium exist.

## What the scaffold does

`scripts/new_console.py <folder>` refuses a folder that exists, a platform that `app/data/platforms/profiles.json`
lacks, a model code that is not lower case with hyphens, a licence without its CC-BY-4.0 credit line, and a model
over its budget. It then:

- writes the folder: the glb, its textures as PNG files beside it (taken out of the glb when it embeds them), their
  import settings (`nodes/root_scale=10`: the app's unit is 10 cm; no LODs, no shadow meshes), the licence with
  what was changed (`--changes`), `console.tres`, `<folder>.tscn` and `<folder>_shape.tres`;
- adds the model to `ConsoleVariant.kt` (one entry per folder, with its platform) and, for another model of a
  platform (`--variant-of`), to its base model's `variants`, starting from the base's way in and pose;
- adds the credit line to the README's "3D models" list;
- prints the triangle count, the glb's nodes, and what is left to do.

`--budget` sets the triangle budget; without it, the count rounded up to the next thousand.

## The files of a folder

| File | Holds |
|---|---|
| `console.tres` | the manifest (`ConsoleManifest`, below) |
| `<folder>.tscn` | the scene: a `ConsoleModel` root, the glb instanced as `Model`, the way in, the pose, the moving parts |
| `<folder>_shape.tres` | a `SeatShape`: where the medium stands once in |
| `<folder>.glb`, `*.png` | the model and its textures |
| `LICENSE.txt` | the model's licence and credit line, and what was changed |
| `launch.json` | the launch steps, once animated (below) |

### The manifest

`console.tres` is a `ConsoleManifest` (`app/carousel/consoles/console_manifest.gd`):

| Field | Holds |
|---|---|
| `platform` | the platform it plays, one of `app/data/platforms/profiles.json` |
| `version` | its model code in lower case, hyphens between words (`dol-001`) |
| `is_default` | whether it is the platform's default model (one per platform) |
| `name`, `model_name` | the names shown ("Mega Drive", "Model 2") |
| `scene`, `launch` | its scene and its steps (empty for none) |
| `triangle_budget` | the most triangles the model may draw |
| `ring_size` | its size on the ordering ring; zero weighs it as the PS2 |
| `variants` | on the default model, the folders of the platform's other models |

Without `launch`, the console is not fully supported yet (`ConsoleManifest.is_coming`): it is offered greyed in "Add a
console", refused by the core (`Coming`), and shown only with the debug argument `--coming-consoles`.

### The seat, the way in and the pose

`<folder>_shape.tres` (`SeatShape`, `app/carousel/consoles/seat_shape.gd`) says where a seated medium stands, in
millimetres in the model's axes: `seat_centre`, the medium's centre, and `seat_degrees`, how it is turned from its own
axes (Godot's Euler order), every moving part at 0. The medium's own axes: a disc's centre with its label towards +Z;
a cartridge's middle, +Z out of its label, +Y towards its top edge. A disc lying flat, label up, is `(-90, 0, 0)`; a
cartridge upright, its label to the back, `(0, 180, 0)`. When a part carries the medium (a tray), `carrier` names its
property: the seat slides with it, or turns with it about `pivot` (millimetres, the model's axes), as the NES's tray
tilts its cartridge (`nes_shape.tres`).

The scene's root (`ConsoleModel`, `app/carousel/consoles/console_model.gd`) holds:

- `way_in`: the way the medium comes down to the seat, a unit vector in the seat's frame (`(0, 1, 0)` for a
  cartridge going down into a slot on top; `(0, 0, 1)` by default, for a disc coming in face first);
- `pose_degrees`: how the console faces the camera, in degrees (Godot's Euler order). Left at zero, it turns about X,
  its way in towards the camera; `(15, 0, 0)` stands a handheld as it is held, leant back; `(25, 20, 0)` shows a home
  console from above its front and to its left;
- `spindle`: the disc drive's `Spindle` (`app/carousel/models/spindle.tscn`), if a seated disc turns on one.

A test checks that every medium of the platform comes down its way in clear of the console's parts.

### Moving parts

Each moving part is a `ConsolePart` (`app/carousel/consoles/console_part.gd`) in the root's `parts`, edited in the
inspector:

| Field | Holds |
|---|---|
| `property` | the name the launch steps move it by, after its unit: `lid_degrees`, `power_mm`; `light_energy` for a light |
| `node` | the node it moves, a path from the root (`Model/…` in a glb), its origin on the pivot |
| `motion` | `TURN` (degrees about `axis`), `SLIDE` (millimetres along `axis`) or `LIGHT` (the node is a mesh that glows) |
| `axis` | the axis, in the node's parent frame, signed: the way the value grows |
| `role` | what the placeholder animation does with it (below) |
| `rest`, `open` | its value at rest and fully moved |

The part moves from the rest the scene gives its node. Two parts may share a property (two flaps pushed open together):
they move together, the first one giving the role and the values. A light's mesh needs a material that can glow: a
`solid.gdshader` override with `emission_energy` 0 in the scene (see `gba_sp.tscn`).

`app/carousel/consoles/gba_sp/gba_sp.tscn` (a lid, a switch and a light) and `app/carousel/consoles/snes/snes.tscn` (two flaps, a lever,
a knob and a button) are examples.

A part's role (`ConsolePart.Role`):

- `OPENING` (a lid, a tray, a door) opens before the medium and closes once it is in.
- `FLAP` is pushed open by the medium as it passes, and stays open.
- `PRESS` (eject, open) is pressed and let go before the openings open.
- `POWER`, `LIGHT` and `SPIN` come on at the end and stay on.
- `POWER_PRESS` (a momentary power button) is pressed as the console comes on, then let go.
- `POSE` moves only in the console's own steps.

A button stands out of the face around it at rest by `ConsoleModel.PROUD_MM` at most, and pressed it still stands
0.3 mm out of it, never sinking out of sight.

`moving_parts()`, `seat()`, `approach()` and `presented()` depend only on this data and the parts' values, never on
the model's nodes: the launch animation is built from a model that is not in the tree. A test holds it. Every console
is data: none has a script of its own.

### A console drawn without a glb

The first consoles (`ps2_slim`, `gc`, `xbox`…) have no glb: each part is a mesh file of its own
(`app/carousel/consoles/gc/meshes/body.res` and its neighbours), drawn by a node
of the scene with the shared shaders, under logo decals, and their moving parts are nodes of the scene. They meet the
same contract as a glb console. A new console comes as a glb.

## Shared files

| File | What a console needs there | Without it |
|---|---|---|
| `ConsoleVariant.kt` | one entry per folder (the scaffold adds it) | `ConsoleVariantTest` fails |
| `README.md` | its credit line (the scaffold adds it) and its name in the table of consoles | a test fails on the credit |
| `app/studio/logos/<slot>/<folder>.png` | its logo in the five slots (`between-mini`, `games-top`, `plinth-plate`, `rail-tile`, `ring-middle`) | no logo |
| `StudioTokens.GEL` in `app/studio/studio_tokens.gd` | the platform's colour | the neutral colour; `tokens_test.gd` fails |
| `app/data/turntable.json`, `app/data/studio_lights.json` | its pose on the plinth and its lights | it stands as its model is drawn, under the default light |
| `app/test/carousel/consoles/console_folders_test.gd` | `HOUSINGS` (the parts the medium lies in) | the test fails, the medium going through them |

The logos are drawn for the project, never copied. `studio_tokens.gd` is generated from the design's tokens and never
edited by hand: give the colour you suggest (a hex value) in the pull request, and the maintainers add it. The pose
and lights files are written by the maintainers' tuning tool through the [debug bridge](debug-bridge.md).

A new platform also needs its data: [architecture/core.md](architecture/core.md#adding-a-platform). A new medium
needs its folder ([adding-a-medium.md](adding-a-medium.md)); until then the platform's medium is listed as awaited
and its kind's stand-in shows.

## Launch steps

A console's launch animation is `launch.json`: `model_hash` (the fingerprint it was tuned on), `choice` (the step at
which the game is chosen) and `steps`. Each step is a whole state of the scene, reached from the previous one in `dur`
seconds along its `ease`, then held `hold` seconds. A step groups its values by what they move: `console`,
`consoles`, `parts` (the moving parts by property, in their own units), `disc`, `row`, `look`, `ui` and `fx`.
Distances are centimetres, angles degrees. A missing value takes its default, a moving part its rest
(`LaunchAnimation`). `fx.black` grows the black from the seat, and `fx.fade` darkens the whole screen.

`ConsoleModel.fingerprint()` hashes the seat, each moving part's property, role and values, and the bytes of the glb or
mesh files it is drawn from: steps tuned on another model are refused. Steps are tuned outside the app, then become the folder's
`launch.json` with `scripts/launch_steps.py`, which checks the fingerprint:

```sh
scripts/launch_steps.py <exported.json> --console ps2_slim --console-key ps2
```

Set `launch` in `console.tres` once the file exists.

## Tools

| Command | What it does |
|---|---|
| `scripts/new_console.py <folder> …` | starts a console from its glb (above) |
| `scripts/export_console.sh <folder> [out_dir]` | writes `build/models/<folder>.glb` and `build/models/<folder>.model.json` (presentation, seat, moving parts, fingerprint) for a three.js viewer |
| `scripts/render_console.sh <folder> [png] [label image]` | renders the console as the carousel lights it, from six points of view, the last one its parts fully moved, into `build/renders/<folder>.png`. Needs a display. |

The last two take a medium's folder too.

## The tests that hold it

`app/test/carousel/consoles/console_folders_test.gd` runs on every folder. It checks that the manifest loads and its
platform has a profile (INV-14), that steps move only parts the console has and were tuned on its fingerprint, that
the fingerprint follows the seat, every moving part and the files drawn, that the contract reads no node, that every
medium of its platform comes down its way in clear of its parts, that a glb has its licence and credit and that its
meshes never degenerate and face the way their normals say, and that a console without steps plays the placeholder. `ConsoleVariantTest` (Kotlin) holds the
models and the folders to each other, both ways.

```sh
godot --headless --path app --import
GODOT=$GODOT scripts/test_godot.sh res://test/carousel/consoles
(cd kotlin && ./gradlew :core:test --tests '*ConsoleVariantTest')
```

`app/test/carousel/fixtures.gd` holds what these tests share: `console_folders()`, `new_console(scene)`, `meets`
(whether triangles meet a box).

## Neighbours

- [adding-a-medium.md](adding-a-medium.md): the disc or cartridge that goes in.
- [architecture/godot.md](architecture/godot.md#consoles): the code that shows and launches consoles.
- [architecture/studio.md](architecture/studio.md): the gel, the plinth, the lights.
- [testing.md](testing.md#gdscript). Back to the entry: [README.md](README.md).
