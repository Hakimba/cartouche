# Adding a console

**You are here.** A console model is one folder under `app/carousel/consoles/`. The carousel finds it by its
folder, shows it on the consoles screen, and plays its launch animation when a game goes in. A console depends on
the model code in `app/carousel/models/` and on its platform's profile. The consoles screen, the ordering ring,
the plinth and the launch read it ([architecture/godot.md](architecture/godot.md#consoles)). Its disc or cartridge
is a medium, with its own page: [adding-a-medium.md](adding-a-medium.md).

Copy the closest folder: `app/carousel/consoles/ps2_slim/` for a model built in code, `app/carousel/consoles/nes/`
for one drawn from a glb.

## The contract

`ConsoleModel` (`app/carousel/consoles/console_model.gd`) is all the carousel and the launch know of a console.
A console's `<folder>_model.gd` extends it.

| Member | What it gives |
|---|---|
| `shape` | its `ModelShape`: dimensions in millimetres and the named rules they keep |
| `moving_parts()` | each moving part: a float property of the model named after its unit (`lid_degrees`, `open_mm`), its role, its values at rest and fully moved (`MovingPart`) |
| `seat()` | where the medium stands once in, following the part that carries it, in the medium's own frame |
| `approach()` | the way in, a unit vector in the seat's frame |
| `presented()` | how the console turns to face the camera |
| `hold(angle)` | turns the medium, for a console that turns it |
| `fade(amount)` | fades the whole model, through `ModelFade` |
| `set_shader_value(mesh, parameter, value)` | the one way a part changes a material, faded or not |
| `light_energy`, `_lights()` | the console's light, and the meshes that glow with it |
| `fingerprint()` | a hash of the dimensions and moving parts its launch steps were tuned on |

`moving_parts()`, `seat()`, `approach()` and `presented()` depend only on the shape and the parts' properties,
never on the model's nodes: the launch animation is built from a model that is not in the tree.

A moving part's role (`MovingPart.Role`) says what the placeholder animation does with it:

- `OPENING` (a lid, a tray, a door) opens before the medium and closes once it is in.
- `FLAP` is pushed open by the medium as it passes, and stays open.
- `PRESS` (eject, open) is pressed and let go before the openings open.
- `POWER`, `LIGHT` and `SPIN` come on at the end and stay on.
- `POWER_PRESS` (a momentary power button) is pressed as the console comes on, then let go.
- `POSE` moves only in the console's own steps.

A button stands out of the face around it at rest by `ConsoleModel.PROUD_MM` at most, and pressed it goes in as
far as `ConsoleModel.press_travel` allows.

## The files of a folder

| File | Holds |
|---|---|
| `console.tres` | the manifest (`ConsoleManifest`, see below) |
| `<folder>.tscn` | the scene: `ShapedMesh` parts on the existing shaders (`ShaderMaterial`s only), one node per moving part with its origin on the part's pivot |
| `<folder>_model.gd` | `<Name>Model extends ConsoleModel`: the moving parts, seat and approach |
| `<folder>_shape.gd`, `<folder>_shape.tres` | `<Name>Shape extends ModelShape`: the rules refusing dimensions that cannot be built, and the measured dimensions |
| `<folder>_geometry.gd` | the parts as pure functions, built from `ShapeGeometry` and `MeshBuilder` pieces |
| `launch.json` | the launch steps, once animated; without it the console plays the placeholder |
| `*.svg` | its logos and printed marks |

Every part, the smallest detail included, is built from the shape where it stands. No node is placed by hand
except a moving part's pivot, which the model sets from the shape. Changing a dimension in the inspector rebuilds
the model in the editor. Dimensions the rules refuse build nothing, and `problems()` names the rules they break.

What a second console needs from `<folder>_geometry.gd` moves to `app/carousel/models/`, never copied. `DiscTray`
(`disc_tray.gd`) is one: the disc drive tray both Xboxes slide out.

A new shader compiles the first time the console shows, and costs memory on the GPU. Use the existing ones:
`solid.gdshader`, `label.gdshader`, `clear_plastic.gdshader` in `app/carousel/models/`.

### A console drawn from a glb

A downloaded CC-BY model goes in the folder as `<folder>.glb` with its textures as PNG files beside it, its
`LICENSE.txt`, and its credit line in the README's "3D models" list. A test fails without the licence or the
credit. Its scene instances the glb as `Model`, and its model moves the glb's nodes by name. Its shape extends
`GlbShape`: it builds no mesh and holds only what the launch reads (the seat, the parts' travel). The model
overrides `_lights()` to name the glowing meshes. Import the glb at `nodes/root_scale=10` (the app's unit is
10 cm), with no LODs, no shadow meshes and no embedded images.

### Logos

A logo is an SVG drawn for the project, never copied from a file. Import it with mipmaps on and uncompressed, at
an SVG scale that keeps it sharp. Its face is `ShapeGeometry.decal`, a part of its own, drawn with the label
shader (`label_texture` the SVG, `has_label` on), so it fades with the console.

## The manifest

`console.tres` is a `ConsoleManifest` (`app/carousel/consoles/console_manifest.gd`):

| Field | Holds |
|---|---|
| `platform` | the platform it plays, one of `app/data/platforms/profiles.json` |
| `version` | its model code in lower case, hyphens between words (`dol-001`) |
| `is_default` | whether it is the platform's default model (one per platform) |
| `name`, `model_name` | the names shown |
| `scene`, `launch` | its scene and its steps (empty for none) |
| `triangle_budget` | the most triangles the model may draw |
| `ring_size` | its size on the ordering ring |
| `variants` | on the default model, the folders of the platform's other models |

## Shared files a new console needs

A folder is not the whole story. These shared files also need an entry:

1. `kotlin/core/src/main/kotlin/app/cartouche/core/library/ConsoleVariant.kt`: one enum entry per folder, with its
   platform. Without it the model cannot be chosen and kept.
2. `StudioTokens.GEL` in `app/studio/studio_tokens.gd`: the console's colour. The file is generated, so ask for the
   entry in an issue. Without it the console takes the neutral colour, and `tokens_test.gd` fails.
3. `app/data/turntable.json` and `app/data/studio_lights.json`: its pose on the plinth and its lights, written by
   the tuning tool through the [debug bridge](debug-bridge.md). Without them it takes the default pose and light.
4. A new platform also needs its data: see
   [architecture/core.md](architecture/core.md#adding-a-platform). A new medium needs its folder
   ([adding-a-medium.md](adding-a-medium.md)).
5. Optional: its games in `app/dev/demo/desktop.json`, for the desktop demo (regenerated by `DesktopDemoTest`).

## Launch steps

A console's launch animation is `launch.json`: `model_hash` (the fingerprint it was tuned on), `choice` (the step
at which the game is chosen) and `steps`. Each step is a whole state of the scene, reached from the previous one
in `dur` seconds along its `ease`, then held `hold` seconds. A step groups its values by what they move:
`console`, `consoles`, `parts` (the moving parts by property, in their own units), `disc`, `row`, `look`, `ui` and
`fx`. Distances are centimetres, angles degrees. A missing value takes its default, a moving part its rest
(`LaunchAnimation`). `fx.black` grows the black from the seat, and `fx.fade` darkens the whole screen.

Steps are tuned outside the app, then become the folder's `launch.json` with `dev/launch_steps.py`, which refuses
them once the model's fingerprint has changed:

```sh
dev/launch_steps.py <exported.json> --console ps2_slim --console-key ps2
```

## Tools

| Command | What it does |
|---|---|
| `dev/export_console.sh <folder> [out_dir]` | writes `build/models/<folder>.glb` and `build/models/<folder>.model.json` (presentation, seat, moving parts, fingerprint) for a three.js viewer, or into `out_dir` |
| `dev/render_console.sh <folder> [png] [label image]` | renders the console as the carousel lights it, from six points of view, into `build/renders/<folder>.png` by default. Needs a display. |

Both take a medium's folder too.

## The tests that hold it

`app/test/carousel/consoles/console_folders_test.gd` runs on every folder. It checks that the manifest loads and
its platform has a profile (INV-14), that steps move only parts the console has, that the fingerprint follows
every dimension and moving part, that the contract reads no node, that every medium of its platform comes down its
way in clear of its parts, that a glb has its licence and credit, and that a console without steps plays the
placeholder. `HOUSINGS` lists, per console, the parts a medium may lie in.

`app/test/carousel/fixtures.gd` holds what these tests share: `new_console(scene)`, `drawn_around` (dimensions
drawn around the shipped ones until the rules accept them), `meets` (whether triangles meet a box). A console's own
looks go in a test of its own, using them. Run the folder's tests with:

```sh
GODOT=$GODOT dev/test_godot.sh res://test/carousel/consoles
```

## Neighbours

- [adding-a-medium.md](adding-a-medium.md): the disc or cartridge that goes in.
- [architecture/godot.md](architecture/godot.md#consoles): the code that shows and launches consoles.
- [architecture/studio.md](architecture/studio.md): the gel, the plinth, the lights.
- [testing.md](testing.md#gdscript). Back to the entry: [ONBOARDING.md](ONBOARDING.md).
