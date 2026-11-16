# Adding a console

A console model is one folder under `app/carousel/consoles/`: a manifest, a scene, a shape and a glb. It is data
only: no console has a script of its own. Its disc or cartridge is a medium ([adding-a-medium.md](adding-a-medium.md));
its emulators and game lists are its platform ([adding-a-platform.md](adding-a-platform.md)).

## Steps

1. **Prepare the model.** One glb at its real size, in metres, X to the right, Y up, Z out of its front; each
   moving part a node of its own with its origin on its pivot; under the triangle budget (about 10 000 for a home
   console). Its licence must be CC-BY-4.0, as every model shipped.
2. **Run the scaffold.**

   ```sh
   scripts/new_console.py megadrive2 --platform genesis --glb megadrive2.glb --version mk-1631 \
     --name "Mega Drive" --model-name "Model 2" --licence license.txt --variant-of megadrive
   ```

   It refuses a folder that exists, a platform `app/data/platforms/profiles.json` lacks, a licence without its
   CC-BY-4.0 credit line and a model over its budget (`--budget`; by default the count rounded up to the next
   thousand). It writes the folder (the glb, its textures as PNG files, their import settings, the licence with
   `--changes`, the three files below), adds the model to `ConsoleVariant.kt` and, with `--variant-of`, to its base
   model's `variants`, adds the credit line to the README, and prints what is left to do.
3. **Fill the seat, the way in and the pose** it prints ([below](#the-seat-the-way-in-and-the-pose)).
4. **Add the shared files** ([below](#shared-files)): the console's name in the README's table, its logos.
5. **Check.** `git add` the new files, then:

   ```sh
   $GODOT --headless --path app --import
   GODOT=$GODOT scripts/test_godot.sh res://test/carousel/consoles res://test/assets
   cd kotlin && ./gradlew :core:test --tests '*ConsoleVariantTest'
   python3 scripts/check_docs.py
   ```

   `scripts/render_console.sh <folder>` renders it as the carousel lights it, from six points of view, into
   `build/renders/<folder>.png` (it needs a display). `scripts/export_console.sh <folder>` writes its glb and its
   contract as JSON under `build/models/`, for a viewer.
6. **Open a pull request.** The console shows greyed, as coming, until it has its [launch steps](#launch-steps)
   and its medium.

## The files of a folder

| File | Holds |
|---|---|
| `console.tres` | the manifest (`ConsoleManifest`) |
| `<folder>.tscn` | the scene: a `ConsoleModel` root, the glb instanced as `Model`, the way in, the pose, the moving parts |
| `<folder>_shape.tres` | a `SeatShape`: where the medium stands once in |
| `<folder>.glb`, `*.png` | the model and its textures |
| `LICENSE.txt` | the model's licence and credit line, and what was changed |
| `launch.json` | the launch steps, once animated |

The manifest's fields:

| Field | Holds |
|---|---|
| `platform` | the platform it plays, a key of `app/data/platforms/profiles.json` |
| `version` | its model code in lower case, hyphens between words (`dol-001`) |
| `is_default` | whether it is the platform's default model (one per platform) |
| `name`, `model_name` | the names shown ("Mega Drive", "Model 2") |
| `scene`, `launch` | its scene and its steps. Without `launch` the console is coming (`ConsoleManifest.is_coming`): offered greyed in "Add a console", refused by the core (`Coming`), shown only with `--coming-consoles` |
| `triangle_budget` | the most triangles the model may draw |
| `ring_size` | its size on the ordering ring; zero weighs it as the PS2 |
| `variants` | on the default model, the folders of the platform's other models |

### The seat, the way in and the pose

`<folder>_shape.tres` (`SeatShape`), in millimetres in the model's axes, every moving part at rest:

| Field | Holds |
|---|---|
| `seat_centre` | the seated medium's centre |
| `seat_degrees` | how it is turned from its own axes (Godot's Euler order). A disc's axes: its centre, label towards +Z. A cartridge's: its middle, +Z out of its label, +Y towards its top edge. A disc lying flat, label up, is `(-90, 0, 0)`; a cartridge upright, label to the back, `(0, 180, 0)` |
| `carrier`, `pivot` | the property of the part that carries the medium (a tray): the seat slides with it, or turns with it about `pivot` (`nes_shape.tres`) |
| `housings` | the parts the medium lies in (`body` on most glb consoles): the asset checks let the medium come down through those only |

The scene's root (`ConsoleModel`):

| Field | Holds |
|---|---|
| `way_in` | the way the medium comes down to the seat, a unit vector in the seat's frame: `(0, 1, 0)` for a cartridge going down into a slot on top; `(0, 0, 1)` by default, a disc coming in face first |
| `pose_degrees` | how the console faces the camera. At zero it turns its way in towards the camera; `(15, 0, 0)` leans a handheld back as it is held; `(25, 20, 0)` shows a home console from above its front and to its left |
| `spindle` | the drive's `Spindle` (`app/carousel/models/spindle.tscn`), if a seated disc turns on one |

### Moving parts

Each one is a `ConsolePart` in the root's `parts`, edited in the inspector. Examples:
`app/carousel/consoles/gba_sp/gba_sp.tscn` (a lid, a switch, a light), `app/carousel/consoles/snes/snes.tscn` (two
flaps, a lever, a knob, a button).

| Field | Holds |
|---|---|
| `property` | the name the launch steps move it by, after its unit: `lid_degrees`, `power_mm`; `light_energy` for a light. Two parts sharing a property move together |
| `node` | the node it moves, a path from the root (`Model/…` in a glb), its origin on the pivot |
| `motion` | `TURN` (degrees about `axis`), `SLIDE` (millimetres along `axis`) or `LIGHT` (a mesh that glows: it needs a `solid.gdshader` override with `emission_energy` 0, as in `gba_sp.tscn`) |
| `axis` | the axis in the node's parent frame, signed: the way the value grows |
| `rest`, `open` | its value at rest and fully moved |
| `role` | what the placeholder animation does with it |

| `ConsolePart.Role` | In the placeholder |
|---|---|
| `OPENING` (a lid, a tray, a door) | opens before the medium and closes once it is in |
| `FLAP` | is pushed open by the medium as it passes, and stays open |
| `PRESS` (eject, open) | is pressed and let go before the openings open |
| `POWER`, `LIGHT`, `SPIN` | come on at the end and stay on |
| `POWER_PRESS` | is pressed as the console comes on, then let go |
| `POSE` | moves only in the console's own steps |

A button stands out of the face around it by `ConsoleModel.PROUD_MM` at most at rest, and still 0.3 mm pressed.

The first consoles (`ps2_slim`, `gc`, `xbox`…) have no glb: each part is a mesh file
(`app/carousel/consoles/gc/meshes/body.res`) drawn by a node of the scene. They meet the same contract. A new
console comes as a glb.

## Shared files

| File | What a console needs there | Without it |
|---|---|---|
| `ConsoleVariant.kt` | one entry per folder (the scaffold adds it) | `ConsoleVariantTest` fails |
| `README.md` | its credit line (the scaffold adds it) and its name in the table of consoles | `scripts/check_docs.py` fails on the credit |
| `app/studio/logos/<slot>/<folder>.png` | its logo in the five slots (`between-mini`, `games-top`, `plinth-plate`, `rail-tile`, `ring-middle`), its official logo from Wikimedia Commons (public domain as too simple for copyright), credited in the README | `scripts/check_docs.py` fails |
| `StudioTokens.GEL` | the platform's colour. The file is generated: give the hex value in the pull request | `tokens_test.gd` fails |
| `app/data/turntable.json`, `app/data/studio_lights.json` | its pose on the plinth and its lights, written by the maintainers' tuning tool through the [debug bridge](debug-bridge.md) | it stands as drawn, under the default light |
| `app/carousel/consoles/<folder>/plinth.png`, `plinth_2x.png` | its picture on the plinth of the **Add a console** and Edit forms, drawn by `scripts/bake_plinths.sh` (needs a display); draw it again when the model, its pose or its plinth lights change, and commit it with `scripts/plinths.json` | `scripts/build.sh` fails (`scripts/plinths.py check`) |

## Launch steps

A console's launch animation is `launch.json`:

| Key | Holds |
|---|---|
| `model_hash` | the fingerprint the steps were tuned on. `ConsoleModel.fingerprint()` hashes the seat, each moving part's property, role and values, and the bytes of the files drawn: steps tuned on another model are refused |
| `choice` | the step at which the game is chosen |
| `steps` | each one a whole state of the scene, reached from the previous one in `dur` seconds along its `ease`, then held `hold` seconds. Its values are grouped by what they move: `console`, `parts` (by property, in their own units), `disc`, `row`, `look`, `ui`, `fx` (`fx.black` grows the black from the seat, `fx.fade` darkens the screen). Centimetres and degrees. A missing value takes its default, a moving part its rest |

Steps are tuned outside the app, then become the folder's file, the fingerprint checked:

```sh
scripts/launch_steps.py <exported.json> --console ps2_slim --console-key ps2
```

Then set `launch` in `console.tres`. A console without steps plays a placeholder made from its parts' roles.

## What the tests hold

| Test | Holds |
|---|---|
| `app/test/carousel/consoles/console_folders_test.gd` | every folder: the manifest loads and its platform has a profile (INV-14); steps move only parts the console has and were tuned on its fingerprint; the contract (`moving_parts()`, `seat()`, `approach()`, `presented()`) reads no node; a console without steps plays the placeholder; the model stays under its triangle budget |
| `app/test/assets/console_assets_test.gd` | every medium of the platform comes down its way in clear of the console's parts, takes its seat and turns on its spindle; a glb's meshes never degenerate and face the way their normals say |
| `ConsoleVariantTest` | the core's models and the folders match, both ways |
| `scripts/check_docs.py` | a glb has its licence and credit, a console its logo in every slot |
